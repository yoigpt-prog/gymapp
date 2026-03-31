-- =============================================================================
-- ISOLATED USER MEALS REFACTORING
-- This script replaces the old user_meal_plan shared-links system with a
-- true copying system. Every time a meal plan is generated, 112 fresh rows
-- are created in the `meals` table, exclusively owned by the user.
-- =============================================================================

-- 1. Ensure `meals` has all required fields for user tracking
ALTER TABLE public.meals ADD COLUMN IF NOT EXISTS is_eaten BOOLEAN DEFAULT FALSE;
ALTER TABLE public.meals ADD COLUMN IF NOT EXISTS meal_order INTEGER DEFAULT 1;
ALTER TABLE public.meals ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.meals ADD COLUMN IF NOT EXISTS allergens TEXT;

-- 2. Enforce strict isolated RLS
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_ingredients ENABLE ROW LEVEL SECURITY;

-- MEAL PLANS: Users can strictly access and modify their own meal plans
DROP POLICY IF EXISTS "Users can manage their own meal plans" ON public.meal_plans;
CREATE POLICY "Users can manage their own meal plans" ON public.meal_plans
  FOR ALL USING (auth.uid() = user_id);

-- MEALS: Users can manage meals that belong to their personal meal plans
DROP POLICY IF EXISTS "Users can manage their own meals" ON public.meals;
CREATE POLICY "Users can manage their own meals" ON public.meals
  FOR ALL USING (
    plan_id IN (SELECT id FROM public.meal_plans WHERE user_id = auth.uid())
  ) WITH CHECK (
    plan_id IN (SELECT id FROM public.meal_plans WHERE user_id = auth.uid())
  );

-- MEAL INGREDIENTS: Users can manage ingredients for their securely owned meals
DROP POLICY IF EXISTS "Users can manage their own meal ingredients" ON public.meal_ingredients;
CREATE POLICY "Users can manage their own meal ingredients" ON public.meal_ingredients
  FOR ALL USING (
    meal_id IN (
      SELECT m.id FROM public.meals m
      JOIN public.meal_plans p ON m.plan_id = p.id
      WHERE p.user_id = auth.uid()
    )
  ) WITH CHECK (
    meal_id IN (
      SELECT m.id FROM public.meals m
      JOIN public.meal_plans p ON m.plan_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

-- 3. Replace the Generator RPC to do Deep Copying
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(uuid, text, int, text, text[]);

CREATE OR REPLACE FUNCTION generate_meal_plan_for_user(
    p_user_id uuid,
    p_goal text,
    p_duration_weeks int,
    p_diet text,
    p_allergies text[]
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
    v_diet_norm text;
    v_goal_norm text;
    v_template_key text;
    v_templates_found int := 0;
    v_template_row record;
    v_real_meal record;
    v_meals_resolved int := 0;
    v_inserted_count int := 0;
    v_meal_order int;
    v_allergy_check text;
    
    v_plan_id uuid;
    v_new_meal_id uuid;
    v_ingredient_row record;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id cannot be null';
        RETURN jsonb_build_object('status', 'error', 'message', 'Missing user ID');
    END IF;

    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        p_duration_weeks := 4;
    END IF;

    v_total_days := p_duration_weeks * 7;

    -- [Detect Template Key]
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));

    IF v_goal_norm = 'build_muscle' THEN v_goal_norm := 'muscle_gain';
    ELSIF v_goal_norm = 'fat_loss' THEN v_goal_norm := 'weight_loss';
    ELSIF v_goal_norm IN ('', 'maintain') THEN v_goal_norm := 'weight_loss';
    END IF;

    IF v_diet_norm IN ('', 'no_preference', 'none', 'any') THEN v_diet_norm := 'balanced';
    ELSIF v_diet_norm IN ('vegetarian', 'vegan') THEN v_diet_norm := 'plant_based';
    END IF;

    v_template_key := v_goal_norm || '_' || v_diet_norm;

    SELECT COUNT(*) INTO v_templates_found 
    FROM public.meal_templates 
    WHERE template_key = v_template_key;
    
    IF v_templates_found = 0 THEN
        v_template_key := 'muscle_gain_balanced';
        SELECT COUNT(*) INTO v_templates_found 
        FROM public.meal_templates 
        WHERE template_key = v_template_key;
        
        IF v_templates_found = 0 THEN
            RETURN jsonb_build_object('status', 'error', 'message', 'No meal templates found');
        END IF;
    END IF;

    -- ───────────────────────────────────────────────────────────────────
    -- [CORE REFACTOR]: Wipe old meal plans and create a new master plan
    -- Because of ON DELETE CASCADE, this clears their old meals and ingredients!
    -- ───────────────────────────────────────────────────────────────────
    DELETE FROM public.meal_plans WHERE user_id = p_user_id;
    
    INSERT INTO public.meal_plans (user_id, name)
    VALUES (p_user_id, 'My ' || p_duration_weeks || '-Week Plan')
    RETURNING id INTO v_plan_id;

    -- [Loop and Copy Meals]
    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1; 

        FOR v_template_row IN 
            SELECT * 
            FROM public.meal_templates 
            WHERE template_key = v_template_key 
              AND day = v_day_num
            ORDER BY 
              CASE meal_type 
                WHEN 'breakfast' THEN 1 
                WHEN 'lunch' THEN 2 
                WHEN 'snack' THEN 3 
                WHEN 'dinner' THEN 4 
                ELSE 5 
              END
        LOOP
            -- Fetch the global template meal
            SELECT * INTO v_real_meal 
            FROM public.meals 
            WHERE id = v_template_row.meal_id::uuid;
            
            IF FOUND THEN
                -- Validate allergies checking against array
                IF p_allergies IS NOT NULL AND array_length(p_allergies, 1) > 0 THEN
                    DECLARE
                        v_skip_meal boolean := false;
                    BEGIN
                        FOREACH v_allergy_check IN ARRAY p_allergies LOOP
                            IF v_allergy_check <> 'none' AND v_real_meal.allergens ILIKE '%' || v_allergy_check || '%' THEN
                                v_skip_meal := true;
                                EXIT;
                            END IF;
                        END LOOP;
                        
                        IF v_skip_meal THEN CONTINUE; END IF;
                    END;
                END IF;
                
                v_meals_resolved := v_meals_resolved + 1;
                
                IF v_template_row.meal_type = 'breakfast' THEN v_meal_order := 1;
                ELSIF v_template_row.meal_type = 'lunch' THEN v_meal_order := 2;
                ELSIF v_template_row.meal_type = 'snack' THEN v_meal_order := 3;
                ELSIF v_template_row.meal_type = 'dinner' THEN v_meal_order := 4;
                ELSE v_meal_order := 5; END IF;

                -- Insert a deep copy into `meals` assigned to the `v_plan_id`
                INSERT INTO public.meals (
                    plan_id,
                    day_index,
                    meal_type,
                    name,
                    calories,
                    protein,
                    carbs,
                    fat,
                    image_url,
                    allergens,
                    is_eaten,
                    meal_order
                ) VALUES (
                    v_plan_id,
                    v_global_day,
                    v_template_row.meal_type,
                    v_real_meal.name,
                    v_real_meal.calories,
                    v_real_meal.protein,
                    v_real_meal.carbs,
                    v_real_meal.fat,
                    v_real_meal.image_url,
                    v_real_meal.allergens,
                    FALSE,
                    v_meal_order
                ) RETURNING id INTO v_new_meal_id;
                
                v_inserted_count := v_inserted_count + 1;
                
                -- Copy `meal_ingredients`
                FOR v_ingredient_row IN 
                    SELECT * FROM public.meal_ingredients WHERE meal_id = v_real_meal.id
                LOOP
                    INSERT INTO public.meal_ingredients (
                        meal_id,
                        name,
                        quantity,
                        calories
                    ) VALUES (
                        v_new_meal_id,
                        v_ingredient_row.name,
                        v_ingredient_row.quantity,
                        v_ingredient_row.calories
                    );
                END LOOP;
                
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'inserted_count', v_inserted_count,
        'template_key', v_template_key,
        'meals_resolved', v_meals_resolved
    );
END;
$$;
