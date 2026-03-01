-- ============================================
-- SQL Script: Refactor Meal Plan Generation to Use Templates
-- ============================================
-- Replaces the dynamic meal selection logic with a template-based approach.

-- DROP OLD FUNCTIONS
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(text, int, text, text);
DROP FUNCTION IF EXISTS generate_meal_plan_for_user_final(uuid, text, int, text, text);

-- NEW CORE FUNCTION
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
    v_week_num int;
    v_day_record record;
    
    v_inserted_count int := 0;

    -- Search Flags mapped to mealsplan_templates
    v_user_goal text;
    v_resolved_diet text;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate Duration
    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'Duration weeks must be >= 1';
    END IF;

    -- Cleanup old plan
    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

    -- MAP GOAL to template goal_type
    -- Known quiz goals: fat_loss, build_muscle, maintain
    IF lower(trim(p_goal)) = 'build_muscle' THEN
        v_user_goal := 'muscle_gain';
    ELSIF lower(trim(p_goal)) = 'fat_loss' THEN
        v_user_goal := 'fat_loss';
    ELSE
        -- Defaulting maintain or others to fat_loss
        v_user_goal := 'fat_loss';
    END IF;

    -- MAP DIET to template diet_group
    -- Known quiz diets: any, none, vegetarian, vegan, pescatarian, mediterranean, keto, low_carb, gluten_free, no_preference
    v_resolved_diet := lower(trim(p_diet));
    
    IF v_resolved_diet IS NULL 
       OR v_resolved_diet = '' 
       OR v_resolved_diet = 'no_preference' 
       OR v_resolved_diet = 'none' 
       OR v_resolved_diet = 'any' THEN
        v_resolved_diet := 'balanced';
    ELSIF v_resolved_diet IN ('vegetarian', 'vegan') THEN
        v_resolved_diet := 'plant_based';
    ELSE
        -- Default to balanced for unknown diets
        v_resolved_diet := 'balanced';
    END IF;

    DECLARE
        v_template_row_count int := 0;
    BEGIN
        -- LOOP THROUGH WEEKS
        FOR v_week_num IN 1..p_duration_weeks LOOP
            v_template_row_count := 0;
            
            -- FETCH TEMPLATE ROWS FOR ALL 7 DAYS
            FOR v_day_record IN 
                SELECT *
                FROM public.mealsplan_templates
                WHERE goal_type = v_user_goal
                  AND diet_group = v_resolved_diet
                ORDER BY day_number
            LOOP
                v_template_row_count := v_template_row_count + 1;
            
            -- BREAKFAST
            IF v_day_record.breakfast_meal_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_week_num, v_day_record.day_number, 'breakfast', v_day_record.breakfast_meal_id::text, false, 1
                )
                ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                IF FOUND THEN v_inserted_count := v_inserted_count + 1; END IF;
            END IF;

            -- LUNCH
            IF v_day_record.lunch_meal_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_week_num, v_day_record.day_number, 'lunch', v_day_record.lunch_meal_id::text, false, 2
                )
                ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                IF FOUND THEN v_inserted_count := v_inserted_count + 1; END IF;
            END IF;

            -- SNACK
            IF v_day_record.snack_meal_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_week_num, v_day_record.day_number, 'snack', v_day_record.snack_meal_id::text, false, 3
                )
                ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                IF FOUND THEN v_inserted_count := v_inserted_count + 1; END IF;
            END IF;

            -- DINNER
            IF v_day_record.dinner_meal_id IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_week_num, v_day_record.day_number, 'dinner', v_day_record.dinner_meal_id::text, false, 4
                )
                ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                IF FOUND THEN v_inserted_count := v_inserted_count + 1; END IF;
            END IF;

            END LOOP;

            RAISE NOTICE 'Template rows found for week %: %', v_week_num, v_template_row_count;
        END LOOP;
    END;

    RAISE NOTICE 'Inserted rows: %', v_inserted_count;

    RETURN jsonb_build_object(
        'status', 'success',
        'inserted_count', v_inserted_count,
        'filters_applied', jsonb_build_object(
            'mapped_goal', v_user_goal,
            'mapped_diet', v_resolved_diet
        )
    );
END;
$$;

-- UPDATE RPC WRAPPERS
CREATE OR REPLACE FUNCTION generate_simple_meal_plan(
    p_user_id uuid,
    p_duration_weeks INT,
    p_goal TEXT DEFAULT 'maintain',
    p_diet TEXT DEFAULT '',
    p_allergies TEXT DEFAULT 'none'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN generate_meal_plan_for_user(p_goal, p_duration_weeks, p_diet, p_allergies);
END;
$$;

CREATE OR REPLACE FUNCTION force_generate_meal_plan_after_quiz(
    p_user_id uuid, p_goal text, p_duration_weeks int, p_diet text, p_allergies text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN generate_meal_plan_for_user(p_goal, p_duration_weeks, p_diet, p_allergies);
END;
$$;

SELECT 'TEMPLATE BASED MEAL PLAN LOGIC DEPLOYED SUCCESSFULLY.' as result;
