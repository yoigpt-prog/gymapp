-- Check which of our 4 required meal types exist
SELECT 
    meal_type,
    COUNT(*) as meal_count
FROM public.meals
WHERE meal_type IN ('breakfast', 'lunch', 'snack', 'dinner')
GROUP BY meal_type
ORDER BY meal_type;

-- If some are missing, show what types we DO have
SELECT DISTINCT meal_type 
FROM public.meals 
ORDER BY meal_type;
