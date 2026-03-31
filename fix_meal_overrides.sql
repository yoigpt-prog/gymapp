-- fix_meal_overrides.sql
-- Adds per-user override columns to user_meal_plan so that meal edits
-- are stored for each user individually without mutating the shared meals template table.
-- This is safe to run multiple times (IF NOT EXISTS).

ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS name_override TEXT;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS calories_override INT;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS protein_override INT;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS carbs_override INT;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS fats_override INT;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS ingredients_override JSONB;

-- Verify the columns were added
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_meal_plan'
  AND column_name LIKE '%override%'
ORDER BY column_name;
