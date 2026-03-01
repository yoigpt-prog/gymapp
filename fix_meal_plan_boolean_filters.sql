-- ============================================
-- BOOLEAN FIX: Correct Column Mapping
-- ============================================
-- 1. Drops old function variants
-- 2. Uses boolean columns (is_vegan, contains_nuts, etc.)
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
    
    -- Normalization
    v_goal_norm text;
    v_diet_norm text;
    v_allergy_norm text;
    
    -- Boolean Filter Flags
    v_f_vegan boolean := false;
    v_f_vegetarian boolean := false;
    v_f_keto boolean := false;
    v_f_low_carb boolean := false;
    v_f_mediterranean boolean := false;
    
    v_f_nuts boolean := false;
    v_f_dairy boolean := false;
    v_f_gluten boolean := false;
    v_f_eggs boolean := false;
    v_f_soy boolean := false;
    v_f_shellfish boolean := false;
    
    v_meal_types text[] := ARRAY['breakfast', 'lunch', 'snack', 'dinner'];
    v_meal_type text;
    v_meal_order int;
    v_selected_meal record;
    v_inserted_count int := 0;
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
    
    v_goal_norm := lower(trim(coalesce(p_goal, '')));
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_allergy_norm := lower(trim(coalesce(p_allergies, '')));

    -- Map Diet
    IF v_diet_norm = 'vegan' THEN v_f_vegan := true; END IF;
    IF v_diet_norm = 'vegetarian' THEN v_f_vegetarian := true; END IF;
    IF v_diet_norm = 'keto' THEN v_f_keto := true; END IF;
    IF v_diet_norm = 'low_carb' THEN v_f_low_carb := true; END IF;
    IF v_diet_norm = 'mediterranean' THEN v_f_mediterranean := true; END IF;

    -- Map Allergy
    IF v_allergy_norm ILIKE '%nuts%' THEN v_f_nuts := true; END IF;
    IF v_allergy_norm ILIKE '%dairy%' THEN v_f_dairy := true; END IF;
    IF v_allergy_norm ILIKE '%gluten%' THEN v_f_gluten := true; END IF;
    IF v_allergy_norm ILIKE '%eggs%' THEN v_f_eggs := true; END IF;
    IF v_allergy_norm ILIKE '%soy%' THEN v_f_soy := true; END IF;
    IF v_allergy_norm ILIKE '%shellfish%' THEN v_f_shellfish := true; END IF;

    -- Cleanup old plan
    DELETE FROM public.user_meal_plan WHERE user_id = v_user_id;

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
                  AND (v_goal_norm = '' OR v_goal_norm = 'maintain' OR primary_goal::text ILIKE ('%' || v_goal_norm || '%'))
                  AND (NOT v_f_vegan OR is_vegan = true)
                  AND (NOT v_f_vegetarian OR is_vegetarian = true)
                  AND (NOT v_f_keto OR is_keto = true)
                  AND (NOT v_f_low_carb OR is_low_carb = true)
                  AND (NOT v_f_mediterranean OR is_mediterranean = true)
                  AND (NOT v_f_nuts OR contains_nuts = false)
                  AND (NOT v_f_dairy OR contains_dairy = false)
                  AND (NOT v_f_gluten OR contains_gluten = false)
                  AND (NOT v_f_eggs OR contains_eggs = false)
                  AND (NOT v_f_soy OR contains_soy = false)
                  AND (NOT v_f_shellfish OR contains_shellfish = false)
            ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;

            -- STAGE 2: Relax Goal
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as tc
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (NOT v_f_vegan OR is_vegan = true)
                      AND (NOT v_f_vegetarian OR is_vegetarian = true)
                      AND (NOT v_f_keto OR is_keto = true)
                      AND (NOT v_f_low_carb OR is_low_carb = true)
                      AND (NOT v_f_mediterranean OR is_mediterranean = true)
                      AND (NOT v_f_nuts OR contains_nuts = false)
                      AND (NOT v_f_dairy OR contains_dairy = false)
                      AND (NOT v_f_gluten OR contains_gluten = false)
                      AND (NOT v_f_eggs OR contains_eggs = false)
                      AND (NOT v_f_soy OR contains_soy = false)
                      AND (NOT v_f_shellfish OR contains_shellfish = false)
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;
            END IF;

            -- STAGE 3: Relax Diet
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM (
                    SELECT *, ROW_NUMBER() OVER (ORDER BY id) as rn, COUNT(*) OVER () as tc
                    FROM public.meals
                    WHERE meal_type::text ILIKE ('%' || v_meal_type || '%')
                      AND (NOT v_f_nuts OR contains_nuts = false)
                      AND (NOT v_f_dairy OR contains_dairy = false)
                      AND (NOT v_f_gluten OR contains_gluten = false)
                      AND (NOT v_f_eggs OR contains_eggs = false)
                      AND (NOT v_f_soy OR contains_soy = false)
                      AND (NOT v_f_shellfish OR contains_shellfish = false)
                ) sub WHERE sub.rn = ((v_global_day + v_meal_order) % sub.tc) + 1;
            END IF;

            -- STAGE 4: Final Fallback (Any meal of this type)
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

    RETURN jsonb_build_object('status', 'success', 'inserted_count', v_inserted_count);
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

SELECT 'SUCCESS: Boolean filters deployed.' as result;
