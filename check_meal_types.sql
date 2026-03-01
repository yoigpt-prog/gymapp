-- QUICK CHECK: What are the ACTUAL meal_type values?
-- ==================================================

-- Show all distinct meal_type values in the database
SELECT DISTINCT meal_type, COUNT(*) as count
FROM public.meals
GROUP BY meal_type
ORDER BY meal_type;

-- Show sample meals with their exact meal_type values
SELECT id, name, meal_type
FROM public.meals
ORDER BY meal_type
LIMIT 20;
