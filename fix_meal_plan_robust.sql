-- ============================================
-- ROBUST FIX: No More Empty Meal Plans
-- ============================================
-- This version adds 3-stage fallback:
-- 1. Try EXACT match (Goal + Diet + Allergy)
-- 2. Relax Goal (Diet + Allergy)
-- 3. Relax EVERYTHING (Only Allergy + Type)
-- ============================================

-- PART 1: Core Generation Logic
-- ============================================
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
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'Duration weeks is required';
    END IF;

    v_total_days := p_duration_weeks * 7;
    
    v_allergy_norm := lower(trim(coalesce(p_allergies, 'none')));
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));
    
    -- Heuristic: 'maintain' isn't usually a filter tag in DB, let's treat it as empty goal for search
    IF v_goal_norm = 'maintain' THEN
        v_goal_norm := '';
    END IF;

    RAISE NOTICE 'Robust Gen: User=%, Goal=%, Diet=%, Allergy=%', 
        v_user_id, v_goal_norm, v_diet_norm, v_allergy_norm;

    -- Standard 4 meals
    v_meal_types := ARRAY['breakfast', 'lunch', 'snack', 'dinner'];

    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1;
        v_meal_order := 0;

        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            v_meal_order := v_meal_order + 1;
            v_selected_meal := NULL;

            -- STAGE 1: FULL MATCH
            SELECT * INTO v_selected_meal FROM (
                SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as total_count
                FROM public.meals
                WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                  AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                  AND (v_diet_norm = '' OR diet_tags::text ILIKE ('%' || v_diet_norm || '%'))
                  AND (v_goal_norm = '' OR primary_goal::text ILIKE ('%' || v_goal_norm || '%'))
            ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.total_count) + 1;
            
            -- STAGE 2: RELAX GOAL (If was specified)
            IF v_selected_meal IS NULL AND v_goal_norm <> '' THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as total_count
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                      AND (v_diet_norm = '' OR diet_tags::text ILIKE ('%' || v_diet_norm || '%'))
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.total_count) + 1;
            END IF;

            -- STAGE 3: RELAX GOAL AND DIET (Final Fallback)
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as total_count
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (v_allergy_norm = 'none' OR NOT (allergens::text ILIKE ('%' || v_allergy_norm || '%')))
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.total_count) + 1;
            END IF;

            IF v_selected_meal IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, global_day, week_number, day_number, meal_type, meal_id, is_eaten, meal_order
                ) VALUES (
                    v_user_id, p_duration_weeks, v_global_day, v_week_num, v_day_num, v_meal_type, v_selected_meal.id::text, false, v_meal_order
                );
            ELSE
                RAISE WARNING 'CRITICAL: No meal found for day %, type % even with full relaxation!', v_global_day, v_meal_type;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object('status', 'success', 'days_generated', v_total_days);
END;
$$;


-- PART 2: Wrappers (Update to ensure they call the new logic)
-- ============================================
CREATE OR REPLACE FUNCTION force_generate_meal_plan_after_quiz(
    p_user_id uuid, p_goal text, p_duration_weeks int, p_diet text, p_allergies text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN generate_meal_plan_for_user(p_goal, p_duration_weeks, p_diet, p_allergies);
END;
$$;

CREATE OR REPLACE FUNCTION generate_simple_meal_plan(
    p_user_id uuid, p_duration_weeks INT, p_goal TEXT DEFAULT 'maintain', p_diet TEXT DEFAULT '', p_allergies TEXT DEFAULT 'none'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN generate_meal_plan_for_user(p_goal, p_duration_weeks, p_diet, p_allergies);
END;
$$;

SELECT 'SUCCESS: Robust generation logic deployed.' as result;
