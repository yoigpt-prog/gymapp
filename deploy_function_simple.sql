-- ====================================================================
-- COMPLETE DEPLOYMENT SCRIPT - Copy ALL of this
-- ====================================================================

CREATE OR REPLACE FUNCTION generate_meal_plan_for_user(
    p_user_id uuid,
    p_goal text,
    p_duration_weeks int,
    p_meals_per_day int,
    p_selected_diet text,
    p_allergy text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_days int;
    v_global_day int;
    v_week_num int;
    v_day_num int;
    v_allergy_norm text;
    v_diet_norm text;
    v_goal_norm text;
    
    v_meal_types text[];
    v_meal_type text;
    
    v_selected_meal record;
    
    v_plan_json jsonb;
    v_exclude_ids text[];
BEGIN
    v_total_days := p_duration_weeks * 7;
    
    v_allergy_norm := lower(coalesce(p_allergy, 'none'));
    v_diet_norm := lower(coalesce(p_selected_diet, ''));
    v_goal_norm := lower(coalesce(p_goal, ''));
    
    IF p_meals_per_day = 2 THEN
        v_meal_types := ARRAY['breakfast', 'lunch'];
    ELSIF p_meals_per_day = 3 THEN
        v_meal_types := ARRAY['breakfast', 'lunch', 'dinner'];
    ELSIF p_meals_per_day = 4 THEN
        v_meal_types := ARRAY['breakfast', 'snack', 'lunch', 'dinner'];
    ELSIF p_meals_per_day = 5 THEN
        v_meal_types := ARRAY['breakfast', 'snack', 'lunch', 'snack', 'dinner'];
    ELSE
        v_meal_types := ARRAY['breakfast', 'lunch', 'dinner'];
    END IF;

    DELETE FROM public.user_meal_plan WHERE user_id = p_user_id;

    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1;
        
        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            
            SELECT array_agg(meal_id) INTO v_exclude_ids
            FROM public.user_meal_plan
            WHERE user_id = p_user_id
              AND global_day > (v_global_day - 7)
              AND global_day <= v_global_day;
            
            v_selected_meal := NULL;

            SELECT * INTO v_selected_meal FROM public.meals
            WHERE LOWER(meal_type) = v_meal_type
              AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
              AND (v_diet_norm = '' OR (diet_tags @> jsonb_build_array(v_diet_norm)))
              AND (v_goal_norm = '' OR LOWER(primary_goal) = v_goal_norm)
              AND (v_exclude_ids IS NULL OR id NOT IN (SELECT unnest(v_exclude_ids)))
            ORDER BY random() LIMIT 1;

            IF v_selected_meal IS NULL AND v_diet_norm <> '' THEN
                SELECT * INTO v_selected_meal FROM public.meals
                WHERE LOWER(meal_type) = v_meal_type
                  AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                  AND (v_goal_norm = '' OR LOWER(primary_goal) = v_goal_norm)
                  AND (v_exclude_ids IS NULL OR id NOT IN (SELECT unnest(v_exclude_ids)))
                ORDER BY random() LIMIT 1;
            END IF;

            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM public.meals
                WHERE LOWER(meal_type) = v_meal_type
                  AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                  AND (v_exclude_ids IS NULL OR id NOT IN (SELECT unnest(v_exclude_ids)))
                ORDER BY random() LIMIT 1;
            END IF;

            IF v_selected_meal IS NULL THEN
                 SELECT * INTO v_selected_meal FROM public.meals
                 WHERE LOWER(meal_type) = v_meal_type
                   AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                   AND (v_diet_norm = '' OR (diet_tags @> jsonb_build_array(v_diet_norm)))
                   AND (v_goal_norm = '' OR LOWER(primary_goal) = v_goal_norm)
                 ORDER BY random() LIMIT 1;
            END IF;

            IF v_selected_meal IS NULL THEN
                 SELECT * INTO v_selected_meal FROM public.meals
                 WHERE LOWER(meal_type) = v_meal_type
                   AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                 ORDER BY random() LIMIT 1;
            END IF;

            IF v_selected_meal IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, global_day, week_number, day_number, meal_type, meal_id, calories
                ) VALUES (
                    p_user_id, p_duration_weeks, v_global_day, v_week_num, v_day_num, v_meal_type, v_selected_meal.id, v_selected_meal.calories
                );
            ELSE
                RAISE WARNING 'No meal found for day %, type %', v_global_day, v_meal_type;
            END IF;

        END LOOP;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'duration_weeks', p_duration_weeks);
END;
$$;
