/*
  Safe Update for public.exercises
  
  1. Ensure table exists with UUID PK
  2. Ensure columns exist with correct types
  3. Create indexes
  4. Enable RLS and Policy
*/

-- 1. Create table if not exists
CREATE TABLE IF NOT EXISTS public.exercises (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY
);

-- 2. Add columns safely
DO $$
BEGIN
    -- is_male
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'exercises' AND column_name = 'is_male') THEN
        ALTER TABLE public.exercises ADD COLUMN is_male boolean DEFAULT false;
    ELSE
        ALTER TABLE public.exercises ALTER COLUMN is_male SET DEFAULT false;
        ALTER TABLE public.exercises ALTER COLUMN is_male TYPE boolean USING is_male::boolean;
    END IF;

    -- is_female
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'exercises' AND column_name = 'is_female') THEN
        ALTER TABLE public.exercises ADD COLUMN is_female boolean DEFAULT false;
    ELSE
        ALTER TABLE public.exercises ALTER COLUMN is_female SET DEFAULT false;
        ALTER TABLE public.exercises ALTER COLUMN is_female TYPE boolean USING is_female::boolean;
    END IF;

    -- fitness_goals (handle conversion from text if needed)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'exercises' AND column_name = 'fitness_goals') THEN
        ALTER TABLE public.exercises ADD COLUMN fitness_goals jsonb DEFAULT '[]'::jsonb;
    ELSE
        -- Safe conversion logic: generic cast to jsonb handles both Text and JSONB source types logic
        ALTER TABLE public.exercises 
        ALTER COLUMN fitness_goals TYPE jsonb 
        USING fitness_goals::jsonb;
    END IF;
END $$;

-- 3. Indexes (IF NOT EXISTS is standard in Postgres 9.5+)
CREATE INDEX IF NOT EXISTS idx_exercises_is_male ON public.exercises(is_male);
CREATE INDEX IF NOT EXISTS idx_exercises_is_female ON public.exercises(is_female);
CREATE INDEX IF NOT EXISTS idx_exercises_fitness_goals ON public.exercises USING gin (fitness_goals);

-- 4. RLS
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'exercises' 
        AND policyname = 'Public read access'
    ) THEN
        CREATE POLICY "Public read access" ON public.exercises FOR SELECT USING (true);
    END IF;
END $$;
