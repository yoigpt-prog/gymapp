-- ====================================================================
-- DIAGNOSTIC: Check if you have lunch meals in database
-- Run this FIRST to identify the problem
-- ====================================================================

-- Check 1: Do you have ANY lunch meals?
SELECT COUNT(*) as lunch_count
FROM public.meals 
WHERE LOWER(meal_type) = 'lunch';

-- If this returns 0, that's your problem - you need lunch meals!

-- Check 2: Show me some lunch meals (if any exist)
SELECT id, name, meal_type, calories 
FROM public.meals 
WHERE LOWER(meal_type) = 'lunch' 
LIMIT 5;

-- Check 3: What meal types DO you have?
SELECT meal_type, COUNT(*) as count
FROM public.meals
GROUP BY meal_type
ORDER BY count DESC;

-- Check 4: Is there any meal plan data for you right now?
SELECT COUNT(*) as my_plan_rows
FROM public.user_meal_plan 
WHERE user_id = auth.uid();

-- Check 5: What are your quiz settings?
SELECT meals_per_day, plan_duration_days, created_at
FROM public.user_quiz_answers 
WHERE user_id = auth.uid() 
ORDER BY created_at DESC 
LIMIT 1;
