-- ============================================================
-- GymGuide – Progress Page Table Fixes
-- Run this ENTIRE script in Supabase SQL Editor
-- ============================================================

-- -------------------------------------------------------
-- 1. Add is_eaten column to user_meal_plan (if missing)
-- -------------------------------------------------------
ALTER TABLE public.user_meal_plan
  ADD COLUMN IF NOT EXISTS is_eaten BOOLEAN NOT NULL DEFAULT FALSE;

-- -------------------------------------------------------
-- 2. Add day column to user_meal_plan (if missing)
-- -------------------------------------------------------
ALTER TABLE public.user_meal_plan
  ADD COLUMN IF NOT EXISTS day INTEGER;

-- -------------------------------------------------------
-- 3. Add meal_type column to user_meal_plan (if missing)
-- -------------------------------------------------------
ALTER TABLE public.user_meal_plan
  ADD COLUMN IF NOT EXISTS meal_type TEXT;

-- -------------------------------------------------------
-- 4. Create user_weekly_weights table (if not exists)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_weekly_weights (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_number  INTEGER NOT NULL CHECK (week_number >= 1),
  weight_kg    NUMERIC(6,2) NOT NULL CHECK (weight_kg > 0),
  logged_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_number)
);

-- -------------------------------------------------------
-- 5. Enable Row Level Security on user_weekly_weights
-- -------------------------------------------------------
ALTER TABLE public.user_weekly_weights ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (so re-running is safe)
DROP POLICY IF EXISTS "Users can view own weekly weights"   ON public.user_weekly_weights;
DROP POLICY IF EXISTS "Users can insert own weekly weights" ON public.user_weekly_weights;
DROP POLICY IF EXISTS "Users can update own weekly weights" ON public.user_weekly_weights;
DROP POLICY IF EXISTS "Users can delete own weekly weights" ON public.user_weekly_weights;

CREATE POLICY "Users can view own weekly weights"
  ON public.user_weekly_weights FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own weekly weights"
  ON public.user_weekly_weights FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own weekly weights"
  ON public.user_weekly_weights FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own weekly weights"
  ON public.user_weekly_weights FOR DELETE
  USING (auth.uid() = user_id);

-- -------------------------------------------------------
-- 6. Notify PostgREST to reload schema cache
--    (required after ALTER TABLE so PGRST204 goes away)
-- -------------------------------------------------------
NOTIFY pgrst, 'reload schema';

-- -------------------------------------------------------
-- Verify — run these SELECTs to confirm columns exist
-- -------------------------------------------------------
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_meal_plan'
  AND table_schema = 'public'
ORDER BY column_name;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_weekly_weights'
  AND table_schema = 'public'
ORDER BY column_name;
