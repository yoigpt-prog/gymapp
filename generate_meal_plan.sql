-- 1. Create the user_meal_plan table (IF NOT EXISTS)
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
    is_eaten boolean DEFAULT false, -- Track if meal is eaten
    created_at timestamptz DEFAULT now()
);

-- Index for faster lookups by user and day sorting
CREATE INDEX IF NOT EXISTS idx_user_meal_plan_user_day 
    ON public.user_meal_plan(user_id, global_day);

-- Enable RLS
ALTER TABLE public.user_meal_plan ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can insert their own meal plans" ON public.user_meal_plan;
CREATE POLICY "Users can insert their own meal plans" ON public.user_meal_plan
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can select their own meal plans" ON public.user_meal_plan;
CREATE POLICY "Users can select their own meal plans" ON public.user_meal_plan
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own meal plans" ON public.user_meal_plan;
CREATE POLICY "Users can delete their own meal plans" ON public.user_meal_plan
    FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their meal status" ON public.user_meal_plan;
CREATE POLICY "Users can update their meal status" ON public.user_meal_plan
    FOR UPDATE USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.user_meal_plan TO authenticated;


-- 2. Create the Generation Function
-- Fix conflicting function signature/return type
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(uuid, text, int, int, text, text);
DROP FUNCTION IF EXISTS generate_meal_plan_for_user(text, int, int, text, text);

CREATE OR REPLACE FUNCTION generate_meal_plan_for_user(
    -- p_user_id removed, using auth.uid()
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
    v_meal_order int; -- TRACKER
    
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
        
        v_meal_order := 0; -- Reset order for the day

        -- LOOP Meal Slots
        FOREACH v_meal_type IN ARRAY v_meal_types LOOP
            v_meal_order := v_meal_order + 1; -- Increment Order
            
            -- RESET selection
            v_selected_meal := NULL;

            ----------------------------------------------------------------------
            -- DETERMINISTIC SELECTION (Strict Filters)
            ----------------------------------------------------------------------
            -- 1. Filter by Meal Type (Broad match for 'snack' etc)
            -- 2. Filter by Allergies (Exclude)
            -- 3. Filter by Diet (Strict)
            -- 4. Filter by Goal (Strict)
            -- 5. Rotate using ROW_NUMBER() % Total Matching Meals
            
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
            
            ----------------------------------------------------------------------
            -- FALLBACK 1: RELAX GOAL (If Strict Failed)
            ----------------------------------------------------------------------
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

            ----------------------------------------------------------------------
            -- FALLBACK 2: RELAX DIET Use only Meal Type & Allergy (Safety Net)
            ----------------------------------------------------------------------
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

        END LOOP; -- End Meal Slots
    END LOOP; -- End Days

    -- 3. Construct Final JSON from DB (Same as before)
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
                        -- 'calories', calories, -- Removed from JSON Agg too if it's not in table, trusting client to fetch from 'meals' table
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
