-- Fix user_meal_plan schema by adding potential missing columns
-- This is non-destructive (uses IF NOT EXISTS)

ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS calories int;

-- Ensure other columns from generate_meal_plan.sql also exist
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS week_number int;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS day_number int;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS global_day int;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS meal_type text;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS meal_id text;
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS duration_weeks int;

-- Add meal_order for deterministic sorting
ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS meal_order int;

-- Re-apply the index just in case
CREATE INDEX IF NOT EXISTS idx_user_meal_plan_user_day 
    ON public.user_meal_plan(user_id, global_day);
