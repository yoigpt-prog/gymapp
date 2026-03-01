-- ============================================
-- CLEANUP AND REGENERATE MEAL PLAN
-- ============================================
-- Run this to clean up old meal plan data and force regeneration
-- ============================================

-- Step 1: Delete ALL existing meal plans for all users
-- (This cleans up any incompatible old data)
DELETE FROM public.user_meal_plan;

-- Step 2: Verify cleanup
SELECT COUNT(*) as remaining_rows FROM public.user_meal_plan;
-- Should return 0

-- Step 3: Check if the meal_order column exists
-- If this query fails, the column is missing and needs to be added
SELECT meal_order FROM public.user_meal_plan LIMIT 1;

-- Step 4 (OPTIONAL): Add meal_order column if missing
-- Uncomment and run if Step 3 failed:
-- ALTER TABLE public.user_meal_plan ADD COLUMN IF NOT EXISTS meal_order int;

-- ============================================
-- NOTES:
-- After running this, restart the Flutter app and complete the quiz again.
-- The meal plan will be regenerated with the new 4-meal structure.
-- ============================================
