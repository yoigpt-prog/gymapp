-- 1. Create or Update Table
CREATE TABLE IF NOT EXISTS public.user_meal_plan (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    duration_weeks int NOT NULL,
    global_day int NOT NULL,       -- 1 to (duration_weeks * 7)
    week_number int NOT NULL,      -- 1 to duration_weeks
    day_number int NOT NULL,       -- 1 to 7
    meal_type text NOT NULL,       -- breakfast, lunch, etc.
    meal_id text NOT NULL,         -- ID from meals table
    calories int,
    created_at timestamptz DEFAULT now()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_meal_plan_user_day 
    ON public.user_meal_plan(user_id, global_day);

-- Enable RLS
ALTER TABLE public.user_meal_plan ENABLE ROW LEVEL SECURITY;

-- 2. Policies (Drop first to ensure clean state)
DROP POLICY IF EXISTS "Users can insert their own meal plans" ON public.user_meal_plan;
CREATE POLICY "Users can insert their own meal plans" ON public.user_meal_plan
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can select their own meal plans" ON public.user_meal_plan;
CREATE POLICY "Users can select their own meal plans" ON public.user_meal_plan
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own meal plans" ON public.user_meal_plan;
CREATE POLICY "Users can delete their own meal plans" ON public.user_meal_plan
    FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.user_meal_plan TO authenticated;


-- 3. Strict Generation Function
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
    -- Setup Variables
    v_total_days := p_duration_weeks * 7;
    
    -- Normalize Inputs (Case Insensitive)
    v_allergy_norm := lower(coalesce(p_allergy, 'none'));
    v_diet_norm := lower(coalesce(p_selected_diet, ''));
    v_goal_norm := lower(coalesce(p_goal, ''));
    
    -- Determine Meal Slots (Strict Mapping)
    IF p_meals_per_day = 2 THEN
        v_meal_types := ARRAY['breakfast', 'lunch'];
    ELSIF p_meals_per_day = 3 THEN
        v_meal_types := ARRAY['breakfast', 'lunch', 'dinner'];
    ELSIF p_meals_per_day = 4 THEN
        v_meal_types := ARRAY['breakfast', 'snack', 'lunch', 'dinner'];
    ELSIF p_meals_per_day = 5 THEN
        -- Standardizing ordering for 5 meals
        v_meal_types := ARRAY['breakfast', 'snack', 'lunch', 'snack', 'dinner'];
    ELSE
        v_meal_types := ARRAY['breakfast', 'lunch', 'dinner']; -- default
    END IF;

    -- DELETE old rows for this user strictly
    DELETE FROM public.user_meal_plan WHERE user_id = p_user_id;

    -- LOOP Days
    FOR v_global_day IN 1..v_total_days LOOP
        v_week_num := ceil(v_global_day::numeric / 7);
        v_day_num := ((v_global_day - 1) % 7) + 1;
        
        -- LOOP Meal Slots
        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            
            -- Prepare Unique Filter (Last 7 days Rolling Window)
            SELECT array_agg(meal_id) INTO v_exclude_ids
            FROM public.user_meal_plan
            WHERE user_id = p_user_id
              AND global_day > (v_global_day - 7)
              AND global_day <= v_global_day;
            
            -- RESET selection
            v_selected_meal := NULL;

            ----------------------------------------------------------------------
            -- ATTEMPT 1: STRICT (Goal + Diet + Allergy + Unique + Exact Type)
            -- Allergy condition: Check against allergens array column
            ----------------------------------------------------------------------
            SELECT * INTO v_selected_meal FROM public.meals
            WHERE LOWER(meal_type) = v_meal_type
              AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
              AND (v_diet_norm = '' OR (diet_tags @> jsonb_build_array(v_diet_norm)))
              AND (v_goal_norm = '' OR LOWER(primary_goal) = v_goal_norm)
              AND (v_exclude_ids IS NULL OR id NOT IN (SELECT unnest(v_exclude_ids)))
            ORDER BY random() LIMIT 1;

            ----------------------------------------------------------------------
            -- ATTEMPT 2: RELAX DIET (Goal + Allergy + Unique)
            ----------------------------------------------------------------------
            IF v_selected_meal IS NULL AND v_diet_norm <> '' THEN
                SELECT * INTO v_selected_meal FROM public.meals
                WHERE LOWER(meal_type) = v_meal_type
                  AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                  AND (v_goal_norm = '' OR LOWER(primary_goal) = v_goal_norm)
                  AND (v_exclude_ids IS NULL OR id NOT IN (SELECT unnest(v_exclude_ids)))
                ORDER BY random() LIMIT 1;
            END IF;

            ----------------------------------------------------------------------
            -- ATTEMPT 3: RELAX GOAL (Allergy + Unique) 
            ----------------------------------------------------------------------
            IF v_selected_meal IS NULL THEN
                SELECT * INTO v_selected_meal FROM public.meals
                WHERE LOWER(meal_type) = v_meal_type
                  AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                  AND (v_exclude_ids IS NULL OR id NOT IN (SELECT unnest(v_exclude_ids)))
                ORDER BY random() LIMIT 1;
            END IF;

            ----------------------------------------------------------------------
            -- ATTEMPT 4: RELAX UNIQUENESS (Back to Strict params but allow repeats)
            ----------------------------------------------------------------------
            IF v_selected_meal IS NULL THEN
                 SELECT * INTO v_selected_meal FROM public.meals
                 WHERE LOWER(meal_type) = v_meal_type
                   AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                   AND (v_diet_norm = '' OR (diet_tags @> jsonb_build_array(v_diet_norm)))
                   AND (v_goal_norm = '' OR LOWER(primary_goal) = v_goal_norm)
                 ORDER BY random() LIMIT 1;
            END IF;

            ----------------------------------------------------------------------
            -- ATTEMPT 5: RELAX UNIQUENESS + DIET 
            ----------------------------------------------------------------------
            IF v_selected_meal IS NULL THEN
                 SELECT * INTO v_selected_meal FROM public.meals
                 WHERE LOWER(meal_type) = v_meal_type
                   AND (v_allergy_norm = 'none' OR NOT (coalesce(allergens, '[]'::jsonb) ? v_allergy_norm))
                 ORDER BY random() LIMIT 1;
            END IF;

            -- INSERT if found
            IF v_selected_meal IS NOT NULL THEN
                INSERT INTO public.user_meal_plan (
                    user_id, duration_weeks, global_day, week_number, day_number, meal_type, meal_id, calories
                ) VALUES (
                    p_user_id, p_duration_weeks, v_global_day, v_week_num, v_day_num, v_meal_type, v_selected_meal.id, v_selected_meal.calories
                );
            ELSE
                -- Ideally raise warning, but we must continue
                RAISE WARNING 'No meal found for day %, type % (Allergy: %)', v_global_day, v_meal_type, v_allergy_norm;
            END IF;

        END LOOP; -- End Meal Slots
    END LOOP; -- End Days

    -- Return simple success JSON or generated structure
    -- We will return a basic success status, as the UI should query the table.
    RETURN jsonb_build_object('success', true, 'duration_weeks', p_duration_weeks);
END;
$$;
