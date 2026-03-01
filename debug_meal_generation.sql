-- DIAGNOSTIC QUERIES (FIXED FOR JSONB)
-- Run these to debug why meal generation is failing
-- ==================================================

-- CHECK 1: Do we have any meals in the meals table?
SELECT COUNT(*) as total_meals FROM public.meals;

-- CHECK 2: What meal types are available?
SELECT DISTINCT meal_type FROM public.meals ORDER BY meal_type;

-- CHECK 3: Sample meals for each type we need
SELECT meal_type, COUNT(*) as count
FROM public.meals
WHERE meal_type ILIKE '%breakfast%' 
   OR meal_type ILIKE '%lunch%'
   OR meal_type ILIKE '%snack%'
   OR meal_type ILIKE '%dinner%'
GROUP BY meal_type;

-- CHECK 4: Sample of actual meals with their types and allergens
SELECT id, name, meal_type, allergens, diet_tags
FROM public.meals
LIMIT 10;

-- CHECK 5: Check current user authentication
SELECT auth.uid() as current_user_id;

-- CHECK 6: Count meals by type (case insensitive, using ILIKE)
SELECT 
  'breakfast' as type, COUNT(*) as count FROM public.meals WHERE meal_type::text ILIKE '%breakfast%'
UNION ALL
SELECT 
  'lunch' as type, COUNT(*) as count FROM public.meals WHERE meal_type::text ILIKE '%lunch%'
UNION ALL
SELECT 
  'snack' as type, COUNT(*) as count FROM public.meals WHERE meal_type::text ILIKE '%snack%'
UNION ALL
SELECT 
  'dinner' as type, COUNT(*) as count FROM public.meals WHERE meal_type::text ILIKE '%dinner%';

-- CHECK 7: Test a simple selection that the SQL function would do
SELECT id, name, meal_type
FROM public.meals
WHERE meal_type::text ILIKE '%breakfast%'
LIMIT 5;

-- CHECK 8: Check the actual column types
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'meals' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
