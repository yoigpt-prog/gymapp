-- ============================================
-- FINAL FIX: Correct Boolean Filtering Logic
-- ============================================
-- 1. Drops old function variants
-- 2. Uses Boolean columns (is_vegetarian, contains_nuts, etc.)
-- 3. Returns inserted_count for debugging
-- ============================================

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
    v_total_days int;
    v_global_day int;
    v_week_num int;
    v_day_num int;
    
    v_meal_types text[] := ARRAY['breakfast', 'lunch', 'snack', 'dinner'];
    v_meal_type text;
    v_meal_order int;
    v_selected_meal record;
    v_inserted_count int := 0;

    -- Search Flags
    v_use_diet boolean := true;
    v_use_allergy boolean := true;
    v_diet_val text := lower(trim(p_diet));
    v_allergy_val text := lower(trim(p_allergies));
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate Duration
    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        RAISE EXCEPTION 'Duration weeks must be >= 1';
    END IF;

    v_total_days := p_duration_weeks * 7;
    
    -- Cleanup old plan
    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

    -- Normalization Logic
    IF v_diet_val IS NULL OR v_diet_val = '' OR v_diet_val IN ('no preference', 'none', 'any') THEN
        v_use_diet := false;
    END IF;

    IF v_allergy_val IS NULL OR v_allergy_val = '' OR v_allergy_val = 'none' THEN
        v_use_allergy := false;
    END IF;

    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1;
        v_meal_order := 0;

        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            v_meal_order := v_meal_order + 1;
            v_selected_meal := NULL;

            -- STAGE 1: Full Match (Goal + Diet + Allergy)
            SELECT * INTO v_selected_meal FROM (
                SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as tc
                FROM public.meals
                WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                  AND (primary_goal = p_goal)
                  AND (
                    NOT v_use_diet OR
                    (v_diet_val = 'vegetarian' AND is_vegetarian = true) OR
                    (v_diet_val = 'vegan' AND is_vegan = true) OR
                    (v_diet_val = 'pescatarian' AND is_pescatarian = true) OR
                    (v_diet_val = 'mediterranean' AND is_mediterranean = true) OR
                    (v_diet_val = 'keto' AND is_keto = true) OR
                    (v_diet_val = 'low_carb' AND is_low_carb = true) OR
                    (v_diet_val = 'gluten_free' AND is_gluten_free = true)
                  )
                  AND (
                    NOT v_use_allergy OR
                    NOT (
                      (v_allergy_val ILIKE '%nuts%' AND contains_nuts = true) OR
                      (v_allergy_val ILIKE '%dairy%' AND contains_dairy = true) OR
                      (v_allergy_val ILIKE '%gluten%' AND contains_gluten = true) OR
                      (v_allergy_val ILIKE '%eggs%' AND contains_eggs = true) OR
                      (v_allergy_val ILIKE '%shellfish%' AND contains_shellfish = true)
                      -- Soy is ignored as requested
                    )
                  )
            ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;

            -- STAGE 2: Goal + Allergy (Drop Diet)
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as tc
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (primary_goal = p_goal)
                      AND (
                        NOT v_use_allergy OR
                        NOT (
                          (v_allergy_val ILIKE '%nuts%' AND contains_nuts = true) OR
                          (v_allergy_val ILIKE '%dairy%' AND contains_dairy = true) OR
                          (v_allergy_val ILIKE '%gluten%' AND contains_gluten = true) OR
                          (v_allergy_val ILIKE '%eggs%' AND contains_eggs = true) OR
                          (v_allergy_val ILIKE '%shellfish%' AND contains_shellfish = true)
                        )
                      )
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;
            END IF;

            -- STAGE 3: Allergy only (Drop Goal and Diet)
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as tc
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (
                        NOT v_use_allergy OR
                        NOT (
                          (v_allergy_val ILIKE '%nuts%' AND contains_nuts = true) OR
                          (v_allergy_val ILIKE '%dairy%' AND contains_dairy = true) OR
                          (v_allergy_val ILIKE '%gluten%' AND contains_gluten = true) OR
                          (v_allergy_val ILIKE '%eggs%' AND contains_eggs = true) OR
                          (v_allergy_val ILIKE '%shellfish%' AND contains_shellfish = true)
                        )
                      )
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;
            END IF;

            -- STAGE 4: Final Fallback (Meal Type Only - No Filters)
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as tc
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;
            END IF;

            IF v_selected_meal IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, global_day, week_number, day_number, meal_type, meal_id, is_eaten, meal_order, calories
                ) VALUES (
                    v_user_id, p_duration_weeks, v_global_day, v_week_num, v_day_num, v_meal_type, v_selected_meal.id::text, false, v_meal_order, v_selected_meal.calories
                );
                v_inserted_count := v_inserted_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'inserted_count', v_inserted_count,
        'filters_applied', jsonb_build_object(
            'goal', true,
            'diet', v_use_diet,
            'allergy', v_use_allergy
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

SELECT 'CORRECTED LOGIC DEPLOYED SUCCESSFULLY.' as result;
