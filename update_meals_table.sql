/*
  Safe Update for public.meals
  
  1. Ensure table exists with UUID PK
  2. Ensure columns exist with correct types
     - calories (integer)
     - protein_g (numeric)
     - carbs_g (numeric)
     - fat_g (numeric)
     - diet_tags (jsonb)
     - goal_tags (jsonb)
     - ingredients_json (jsonb)
  3. Create indexes
  4. Enable RLS and Policy
*/

-- 1. Create table if not exists
CREATE TABLE IF NOT EXISTS public.meals (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY
);

-- 2. Add/Update columns safely
DO $$
BEGIN
    -- calories (integer)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'calories') THEN
        ALTER TABLE public.meals ADD COLUMN calories integer;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN calories TYPE integer USING calories::integer;
    END IF;

    -- protein_g (numeric)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'protein_g') THEN
        ALTER TABLE public.meals ADD COLUMN protein_g numeric;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN protein_g TYPE numeric USING protein_g::numeric;
    END IF;

    -- carbs_g (numeric)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'carbs_g') THEN
        ALTER TABLE public.meals ADD COLUMN carbs_g numeric;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN carbs_g TYPE numeric USING carbs_g::numeric;
    END IF;

    -- fat_g (numeric)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'fat_g') THEN
        ALTER TABLE public.meals ADD COLUMN fat_g numeric;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN fat_g TYPE numeric USING fat_g::numeric;
    END IF;

    -- diet_tags (jsonb)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'diet_tags') THEN
        ALTER TABLE public.meals ADD COLUMN diet_tags jsonb DEFAULT '[]'::jsonb;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN diet_tags TYPE jsonb USING diet_tags::jsonb;
    END IF;

    -- goal_tags (jsonb)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'goal_tags') THEN
        ALTER TABLE public.meals ADD COLUMN goal_tags jsonb DEFAULT '[]'::jsonb;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN goal_tags TYPE jsonb USING goal_tags::jsonb;
    END IF;

    -- ingredients_json (jsonb)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'ingredients_json') THEN
        ALTER TABLE public.meals ADD COLUMN ingredients_json jsonb DEFAULT '[]'::jsonb;
    ELSE
        ALTER TABLE public.meals ALTER COLUMN ingredients_json TYPE jsonb USING ingredients_json::jsonb;
    END IF;
    
    -- Ensure meal_type exists for indexing (assuming it should be text if not specified, but typically strictly required for the index request)
    -- Just in case it doesn't exist, we add it as text. If it exists, we assume it's indexable.
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meals' AND column_name = 'meal_type') THEN
        ALTER TABLE public.meals ADD COLUMN meal_type text;
    END IF;

END $$;

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_meals_meal_type ON public.meals(meal_type);
CREATE INDEX IF NOT EXISTS idx_meals_diet_tags ON public.meals USING gin (diet_tags);
CREATE INDEX IF NOT EXISTS idx_meals_goal_tags ON public.meals USING gin (goal_tags);

-- 4. RLS
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'meals' 
        AND policyname = 'Public read access'
    ) THEN
        CREATE POLICY "Public read access" ON public.meals FOR SELECT USING (true);
    END IF;
END $$;
