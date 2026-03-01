-- =========================================================================
-- SQL Script: Fix Meal Plan Generation Using Template Key (No auth.uid())
-- =========================================================================

-- 1. Ensure `user_meal_plan` has the `template_key` column
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS template_key text;

-- 2. Ensure `meal_templates` table exists (if it doesn't already)
CREATE TABLE IF NOT EXISTS public.meal_templates (
    id BIGSERIAL PRIMARY KEY,
    template_key text NOT NULL,
    day int NOT NULL,
    meal_type text NOT NULL,
    meal_id uuid NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Index for fast lookup by template_key and day
CREATE INDEX IF NOT EXISTS idx_meal_templates_key_day ON public.meal_templates(template_key, day);

-- 3. Replace the Meal Plan Generation Function
-- We'll rename it slightly or ensure it takes `p_user_id`
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(uuid, text, int, text, text);

CREATE OR REPLACE FUNCTION generate_meal_plan_for_user(
    p_user_id uuid,
    p_goal text,
    p_duration_weeks int,
    p_diet text,
    p_allergies text[] -- Adjusted to handle array or you can keep text
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
    
    -- Normalized inputs
    v_allergy_norm text;
    v_diet_norm text;
    v_goal_norm text;
    
    -- Template variables
    v_template_key text;
    v_templates_found int := 0;
    v_template_row record;
    
    -- Loop / Resolve variables
    v_real_meal record;
    v_meals_resolved int := 0;
    v_inserted_count int := 0;
    v_meal_order int;
    v_allergy_check text;
    
    -- Results
    v_plan_json jsonb;
BEGIN
    -- [Validate Inputs]
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id cannot be null';
        RETURN jsonb_build_object('status', 'error', 'message', 'Missing user ID');
    END IF;

    IF p_duration_weeks IS NULL OR p_duration_weeks < 1 THEN
        p_duration_weeks := 4; -- Default
    END IF;

    v_total_days := p_duration_weeks * 7;

    -------------------------------------------------------------------
    -- STEP 1: Detect Template Key
    -------------------------------------------------------------------
    v_diet_norm := lower(trim(coalesce(p_diet, '')));
    v_goal_norm := lower(trim(coalesce(p_goal, '')));

    -- Map User Goal
    IF v_goal_norm = 'build_muscle' THEN
        v_goal_norm := 'muscle_gain';
    ELSIF v_goal_norm = 'fat_loss' THEN
        v_goal_norm := 'weight_loss';
    ELSIF v_goal_norm IN ('', 'maintain') THEN
        v_goal_norm := 'weight_loss'; -- Defaulting
    END IF;

    -- Map User Diet
    IF v_diet_norm IN ('', 'no_preference', 'none', 'any') THEN
        v_diet_norm := 'balanced';
    ELSIF v_diet_norm IN ('vegetarian', 'vegan') THEN
        v_diet_norm := 'plant_based';
    END IF;

    -- Construct the Template Key
    v_template_key := v_goal_norm || '_' || v_diet_norm;

    -------------------------------------------------------------------
    -- DEBUG LOGS: Template Detection
    -------------------------------------------------------------------
    RAISE NOTICE '[MealPlan] Template key detected: %', v_template_key;

    -------------------------------------------------------------------
    -- STEP 2: Get Template Meals
    -------------------------------------------------------------------
    SELECT COUNT(*) INTO v_templates_found 
    FROM public.meal_templates 
    WHERE template_key = v_template_key;
    
    RAISE NOTICE '[MealPlan] Templates found: % rows', v_templates_found;

    -- Fallback strategy if template not found
    IF v_templates_found = 0 THEN
        RAISE WARNING '[MealPlan] No template found for %, using fallback', v_template_key;
        v_template_key := 'muscle_gain_balanced';
        SELECT COUNT(*) INTO v_templates_found 
        FROM public.meal_templates 
        WHERE template_key = v_template_key;
        
        -- If still 0, we can't generate
        IF v_templates_found = 0 THEN
            RAISE EXCEPTION 'Critical: Even fallback template % is missing!', v_template_key;
            RETURN jsonb_build_object('status', 'error', 'message', 'No meal templates found');
        END IF;
    END IF;

    -------------------------------------------------------------------
    -- PREPARE: Plan replacement
    -------------------------------------------------------------------
    DELETE FROM public.user_meal_plan WHERE user_id = p_user_id;

    -------------------------------------------------------------------
    -- STEP 3 & 4: Resolve Real Meals and Insert User Meal Plan
    -------------------------------------------------------------------
    -- Generate for full program duration (ex: 4 weeks)
    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        
        -- Repeat template days (1-7)
        v_day_num := ((v_global_day - 1) % 7) + 1; 

        -- For each template row in this day
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
            -- Check meal validity in `meals` table
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
                                RAISE WARNING '[MealPlan] Meal % contains allergy %, skipping', v_real_meal.id, v_allergy_check;
                                v_skip_meal := true;
                                EXIT;
                            END IF;
                        END LOOP;
                        
                        IF v_skip_meal THEN
                             CONTINUE;
                        END IF;
                    END;
                END IF;
                
                -- Meal is valid
                v_meals_resolved := v_meals_resolved + 1;
                
                -- Determine order
                IF v_template_row.meal_type = 'breakfast' THEN v_meal_order := 1;
                ELSIF v_template_row.meal_type = 'lunch' THEN v_meal_order := 2;
                ELSIF v_template_row.meal_type = 'snack' THEN v_meal_order := 3;
                ELSIF v_template_row.meal_type = 'dinner' THEN v_meal_order := 4;
                ELSE v_meal_order := 5; END IF;

                -- Insert into user_meal_plan
                -- Do NOT insert duplicates (ON CONFLICT DO NOTHING)
                BEGIN
                    INSERT INTO public.user_meal_plan (
                        user_id,
                        duration_weeks,
                        global_day,
                        week_number,
                        day_number,
                        meal_type,
                        meal_id,
                        template_key,
                        is_eaten,
                        meal_order
                    ) VALUES (
                        p_user_id,
                        p_duration_weeks,
                        v_global_day,
                        v_week_num,
                        v_day_num,
                        v_template_row.meal_type,
                        v_template_row.meal_id::text,
                        v_template_key,
                        false,
                        v_meal_order
                    )
                    ON CONFLICT (user_id, week_number, day_number, meal_type) DO NOTHING;
                    
                    IF FOUND THEN
                        v_inserted_count := v_inserted_count + 1;
                    END IF;
                END;
            ELSE
                -- Meal missing
                RAISE WARNING '[MealPlan] Meal missing: %', v_template_row.meal_id;
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE '[MealPlan] Meals resolved: %', v_meals_resolved;
    RAISE NOTICE '[MealPlan] Rows inserted: %', v_inserted_count;
    
    -------------------------------------------------------------------
    -- RETURN JSON (Required by frontend RPC)
    -------------------------------------------------------------------
    RETURN jsonb_build_object(
        'status', 'success',
        'inserted_count', v_inserted_count,
        'template_key', v_template_key,
        'meals_resolved', v_meals_resolved
    );
END;
$$;


-- CORE WRAPPER CALLED BY RPC AND TRIGGER
CREATE OR REPLACE FUNCTION generate_user_meal_plan(p_user_id uuid) 
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_goal text;
    v_diet text;
    v_allergies text[];
    v_duration int := 4; -- Default duration
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID cannot be null';
        RETURN jsonb_build_object('status', 'error', 'message', 'Missing p_user_id');
    END IF;

    -- This function reads from the user_preferences table
    SELECT main_goal, diet_type, allergies
    INTO v_goal, v_diet, v_allergies
    FROM (
        -- Assuming goal_type -> main_goal, diet_group -> diet_type mappings or whatever columns are exactly in your preferences table
        -- The user described `goal_type` and `diet_group` and `allergies text[]`
        SELECT goal_type as main_goal, diet_group as diet_type, allergies
        FROM public.user_preferences
        WHERE user_id = p_user_id
        ORDER BY created_at DESC LIMIT 1
    ) pref;
    
    IF v_goal IS NULL THEN
        RAISE WARNING '[MealPlan] No preferences found for user %', p_user_id;
        RETURN jsonb_build_object('status', 'error', 'message', 'Preferences missing');
    END IF;

    -- Call internal logic function passing p_user_id explicitly
    RETURN generate_meal_plan_for_user(p_user_id, v_goal, v_duration, v_diet, v_allergies);
END;
$$;


-- TRIGGER: Automatically generate meal plan after quiz
CREATE OR REPLACE FUNCTION trigger_generate_meal_plan_after_quiz()
RETURNS trigger AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Only generate on NEW insert or if preferences changed
    v_result := generate_user_meal_plan(NEW.user_id);
    RAISE NOTICE '[MealPlan] Trigger result for user %: %', NEW.user_id, v_result;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS after_user_preferences_insert ON public.user_preferences;

-- Re-create the trigger to call the function when user_preferences is inserted
CREATE TRIGGER after_user_preferences_insert
AFTER INSERT ON public.user_preferences
FOR EACH ROW
EXECUTE FUNCTION trigger_generate_meal_plan_after_quiz();


SELECT 'TEMPLATE BASED MEAL PLAN LOGIC DEPLOYED SUCCESSFULLY.' as status;
