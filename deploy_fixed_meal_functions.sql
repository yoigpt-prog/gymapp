-- ============================================
-- DEPLOY THIS FILE TO SUPABASE SQL EDITOR
-- ============================================
-- This script updates both meal plan generation functions
-- to use the fixed 4-meal structure
-- ============================================

-- 1. Drop old function signatures
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(text, int, int, text, text);
DROP FUNCTION IF EXISTS force_generate_meal_plan_after_quiz(uuid, text, int, int, text, text);

-- 2. Create updated generate_meal_plan_for_user (core function)
CREATE OR REPLACE FUNCTION generate_meal_plan_for_user(
    p_goal text,
    p_duration_weeks int,
    p_diet text,
    p_allergies text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_total_days int;
    v_global_day int;
    v_week_num int;
    v_day_num int;
    v_allergy_norm text;
    v_diet_norm text;
    v_goal_norm text;
    
    v_meal_types text[];
    v_meal_type text;
    v_meal_order int;
    
    v_selected_meal record;
    
    v_plan_json jsonb;
BEGIN
    -- Get User ID from Auth
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Setup Variables
    v_total_days := p_duration_weeks * 7;
    
    -- Normalize Inputs (Case Insensitive & Trimmed)
    v_allergy_norm := lower(trim(coalesce(p_allergies, 'none')));
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));
    
    RAISE NOTICE 'Generating deterministic plan for user %: Goal=%, Diet=%, Allergy=%', 
        v_user_id, v_goal_norm, v_diet_norm, v_allergy_norm;

    -- Fixed Meal Slots (Always 4 meals: Breakfast, Lunch, Snack, Dinner)
    v_meal_types := ARRAY['breakfast', 'lunch', 'snack', 'dinner'];

    -- DELETE old rows for this user
    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

    -- LOOP Days
    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1;
        
        v_meal_order := 0;

        -- LOOP Meal Slots
        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            v_meal_order := v_meal_order + 1;
            
            v_selected_meal := NULL;

            -- DETERMINISTIC SELECTION (Strict Filters)
            SELECT * INTO v_selected_meal
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (ORDER BY id) as rn,
                    COUNT(*) OVER () as total_count
                FROM public.meals
                WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                  AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                  AND (v_diet_norm = '' OR diet_tags::text ILIKE ('%' || v_diet_norm || '%'))
                  AND (v_goal_norm = '' OR primary_goal::text ILIKE ('%' || v_goal_norm || '%'))
            ) sub
            WHERE sub.rn = ((v_global_day - 1) % sub.total_count) + 1;
            
            -- FALLBACK 1: RELAX GOAL (If Strict Failed)
            IF v_selected_meal IS NULL AND v_goal_norm <> '' THEN
                 SELECT * INTO v_selected_meal
                FROM (
                    SELECT *,
                        ROW_NUMBER() OVER (ORDER BY id) as rn,
                        COUNT(*) OVER () as total_count
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                      AND (v_diet_norm = '' OR diet_tags::text ILIKE ('%' || v_diet_norm || '%'))
                ) sub
                WHERE sub.rn = ((v_global_day - 1) % sub.total_count) + 1;
            END IF;

            -- FALLBACK 2: RELAX DIET
            IF v_selected_meal IS NULL THEN
                 SELECT * INTO v_selected_meal
                FROM (
                    SELECT *,
                        ROW_NUMBER() OVER (ORDER BY id) as rn,
                        COUNT(*) OVER () as total_count
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                ) sub
                WHERE sub.rn = ((v_global_day - 1) % sub.total_count) + 1;
            END IF;

            -- INSERT if found
            IF v_selected_meal IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, global_day, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_global_day, v_week_num, v_day_num, v_meal_type, v_selected_meal.id::text, false, v_meal_order
                );
            ELSE
                RAISE WARNING 'No meal found for day %, type % (Allergy: %)', v_global_day, v_meal_type, v_allergy_norm;
            END IF;

        END LOOP;
    END LOOP;

    -- Construct Final JSON from DB
    SELECT jsonb_build_object(
        'duration_weeks', p_duration_weeks,
        'total_days', v_total_days,
        'weeks', jsonb_agg(
            jsonb_build_object(
                'week_number', week_data.week_number,
                'days', week_data.days
            ) ORDER BY week_data.week_number
        )
    ) INTO v_plan_json
    FROM (
        SELECT week_number, jsonb_agg(
            jsonb_build_object(
                'global_day', day_data.global_day,
                'day_number', day_data.day_number,
                'meals', day_data.meals
            ) ORDER BY day_data.day_number
        ) as days
        FROM (
            SELECT 
                week_number, 
                day_number, 
                global_day, 
                jsonb_agg(
                    jsonb_build_object(
                        'meal_type', meal_type,
                        'meal_id', meal_id,
                        'is_eaten', is_eaten,
                        'meal_order', meal_order
                    ) 
                    ORDER BY meal_order ASC
                ) as meals
            FROM public.user_meal_plan
            WHERE user_id = v_user_id
            GROUP BY week_number, day_number, global_day
        ) day_data
        GROUP BY week_number
    ) week_data;

    RETURN v_plan_json;
END;
$$;

-- 3. Create updated force_generate_meal_plan_after_quiz (wrapper function)
CREATE OR REPLACE FUNCTION force_generate_meal_plan_after_quiz(
    p_user_id uuid,
    p_goal text,
    p_duration_weeks int,
    p_diet text,
    p_allergies text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_auth_id uuid;
    v_result jsonb;
BEGIN
    v_auth_id := auth.uid();
    IF v_auth_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    RAISE NOTICE 'FORCE GENERATING meal plan for % (Fixed 4 meals)', v_auth_id;
    
    v_result := generate_meal_plan_for_user(
        p_goal,
        p_duration_weeks,
        p_diet,
        p_allergies
    );

    RETURN v_result;
END;
$$;
