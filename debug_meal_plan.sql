-- ====================================================================
-- DIAGNOSTIC QUERIES: Debug Meal Plan Issue
-- ====================================================================
-- Run these queries ONE AT A TIME in Supabase SQL Editor
-- ====================================================================

-- STEP 1: Check if you have lunch meals in the database
-- Expected: Should return rows with meal_type = 'lunch'
SELECT id, name, meal_type, calories 
FROM public.meals 
WHERE LOWER(meal_type) = 'lunch' 
LIMIT 5;

-- If this returns NO ROWS, that's your problem! You need lunch meals in the database.
-- If this returns rows, proceed to STEP 2.

-- ====================================================================

-- STEP 2: Check if the function exists
-- Expected: Should return 1 row with function details
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'generate_meal_plan_for_user';

-- If this returns NO ROWS, the function wasn't deployed correctly.
-- If this returns a row, proceed to STEP 3.

-- ====================================================================

-- STEP 3: Check current meal plan data
-- Expected: Should show what's currently in your plan
SELECT global_day, meal_type, meal_id 
FROM public.user_meal_plan 
WHERE user_id = auth.uid() 
ORDER BY global_day, meal_type;

-- This shows what meals you currently have (if any).
-- If you only see 'breakfast', that confirms the issue.

-- ====================================================================

-- STEP 4: Delete your current plan (if exists)
DELETE FROM public.user_meal_plan WHERE user_id = auth.uid();

-- Expected: Returns "DELETE X" where X is the number of rows deleted

-- ====================================================================

-- STEP 5: Get your user_id for testing
SELECT auth.uid();

-- Copy this UUID, you'll need it for manual testing

-- ====================================================================

-- STEP 6: Check quiz answers to see meals_per_day setting
-- Expected: Should show meals_per_day = 2
SELECT meals_per_day, plan_duration_days 
FROM public.user_quiz_answers 
WHERE user_id = auth.uid() 
ORDER BY created_at DESC 
LIMIT 1;

-- ====================================================================
-- NEXT STEPS BASED ON RESULTS:
-- ====================================================================
-- 
-- If STEP 1 returns NO ROWS (no lunch meals):
--   → You need to add lunch meals to your database first!
--
-- If STEP 2 returns NO ROWS (function doesn't exist):
--   → The function deployment failed, try deploying again
--
-- If STEP 6 shows meals_per_day != 2:
--   → You need to retake the quiz and select 2 meals
--
-- If all checks pass:
--   → Try regenerating the plan in your app
-- ====================================================================
