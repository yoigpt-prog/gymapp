-- ============================================
-- DIAGNOSTICS: Why is Meal Plan Generation Empty?
-- ============================================

-- 1. Check if meals exist at all
SELECT COUNT(*) as total_meals FROM public.meals;

-- 2. Check counts by type
SELECT meal_type, COUNT(*) 
FROM public.meals 
GROUP BY meal_type;

-- 3. Check for NULLs in filter columns
SELECT 
  COUNT(*) FILTER (WHERE diet_tags IS NULL) as null_diet_tags,
  COUNT(*) FILTER (WHERE primary_goal IS NULL) as null_primary_goal,
  COUNT(*) FILTER (WHERE allergens IS NULL) as null_allergens
FROM public.meals;

-- 4. Test the EXACT MATCH logic for a sample day
-- Simulated params: goal='build_muscle', diet='', allergy='none'
SELECT meal_type, name 
FROM public.meals
WHERE meal_type::text ILIKE '%lunch%'
  AND ('none' = 'none' OR NOT (allergens::text ILIKE '%none%'))
  AND ('' = '' OR diet_tags::text ILIKE '%%')
  -- AND ('build_muscle' = '' OR primary_goal::text ILIKE '%build_muscle%') -- This is likely the fail point
LIMIT 5;

-- 5. Test the FALLBACK logic
SELECT meal_type, name 
FROM public.meals
WHERE meal_type::text ILIKE '%lunch%'
  AND ('none' = 'none' OR NOT (allergens::text ILIKE '%none%'))
  AND ('' = '' OR diet_tags::text ILIKE '%%')
LIMIT 5;
