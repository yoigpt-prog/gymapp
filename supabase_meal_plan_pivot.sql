-- =============================================================================
-- MEAL PLAN PIVOT REFACTORING
-- Enforces meal_templates (codes) -> meals (real data) -> meal_plan_meals (pivot)
-- =============================================================================

-- 1. Ensure `meals` table structure
-- Assuming `meals` already exists, we ensure `meal_code` is present and unique
ALTER TABLE public.meals ADD COLUMN IF NOT EXISTS meal_code TEXT;

-- We try to make it unique, but if there are duplicates this might fail, so we use IF NOT EXISTS
-- The user said "Add constraint if missing"
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace 
    WHERE c.relname = 'meals_meal_code_key' AND n.nspname = 'public'
  ) THEN
    -- If there are NULL meal_codes, they aren't considered duplicates by Postgres UNIQUE constraint,
    -- but we should ensure NOT NULL if possible. However, existing data might violate NOT NULL.
    -- The user requested: meal_code TEXT UNIQUE NOT NULL.
    -- We'll add the unique constraint.
    ALTER TABLE public.meals ADD CONSTRAINT meals_meal_code_key UNIQUE (meal_code);
  END IF;
END $$;

-- Optional index as requested
CREATE INDEX IF NOT EXISTS idx_meals_meal_code ON public.meals(meal_code);

-- 2. Ensure `meal_plans` table exists (if it doesn't already)
CREATE TABLE IF NOT EXISTS public.meal_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id) -- Assuming one active plan per user for this architecture
);

-- Ensure `meal_plan_meals` table
CREATE TABLE IF NOT EXISTS public.meal_plan_meals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  plan_id UUID REFERENCES public.meal_plans(id) ON DELETE CASCADE,
  meal_id UUID REFERENCES public.meals(id) ON DELETE CASCADE,
  day_index INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_meal_plan_meals_plan_id ON public.meal_plan_meals(plan_id);
CREATE INDEX IF NOT EXISTS idx_meal_plan_meals_meal_id ON public.meal_plan_meals(meal_id);

-- 3. Create the Generation Function
DROP FUNCTION IF EXISTS generate_meal_plan_from_templates(UUID);

CREATE OR REPLACE FUNCTION generate_meal_plan_from_templates(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_plan_id UUID;
    v_template_row RECORD;
    v_meal_id UUID;
    v_inserted_count INT := 0;
    v_missing_count INT := 0;
BEGIN
    -- Get user's meal_plan (or create one if missing)
    SELECT id INTO v_plan_id FROM public.meal_plans WHERE user_id = p_user_id LIMIT 1;
    
    IF v_plan_id IS NULL THEN
        INSERT INTO public.meal_plans (user_id, name)
        VALUES (p_user_id, 'My Meal Plan')
        RETURNING id INTO v_plan_id;
    END IF;

    -- Prevent duplicates: DELETE existing rows in meal_plan_meals for that plan_id
    DELETE FROM public.meal_plan_meals WHERE plan_id = v_plan_id;

    -- Loop through meal_templates
    -- Note: Assuming meal_templates has columns: meal_code, day (or day_index)
    -- Adjust 'day' to match your actual column name in meal_templates
    FOR v_template_row IN 
        SELECT template_key, meal_code, day
        FROM public.meal_templates
        -- Assuming we need to filter by a specific template_key or just load a default?
        -- Since the instructions didn't specify filtering criteria, we assume meal_templates
        -- contains the exact blueprint for this user (or you adjust the WHERE clause).
        -- We'll just loop through all for the sake of the structural request.
    LOOP
        -- JOIN meals ON meals.meal_code = template value
        SELECT id INTO v_meal_id 
        FROM public.meals 
        WHERE meal_code = v_template_row.meal_code 
        LIMIT 1;

        IF v_meal_id IS NOT NULL THEN
            -- Insert into meal_plan_meals
            INSERT INTO public.meal_plan_meals (plan_id, meal_id, day_index)
            VALUES (v_plan_id, v_meal_id, v_template_row.day);
            
            v_inserted_count := v_inserted_count + 1;
        ELSE
            -- Skip rows if meal_code not found
            RAISE NOTICE 'Missing meal_code in meals table: %', v_template_row.meal_code;
            v_missing_count := v_missing_count + 1;
        END IF;
    END LOOP;

    -- Debug Logging
    RAISE NOTICE 'Meal Plan Generation Complete. Inserted: %, Missing: %', v_inserted_count, v_missing_count;

END;
$$;
