-- STEP 3: Alternative - Query Existing Exercise IDs from Database
-- Use this to create smart exercise assignments based on actual data

-- Check what exercise IDs actually exist
SELECT 
  id,
  exercise_name,
  target_muscle,
  equipment,
  difficulty_level
FROM public.exercises
ORDER BY CAST(id AS INTEGER)
LIMIT 200;

-- Count exercises by muscle group to plan distributions
SELECT 
  target_muscle,
  COUNT(*) as exercise_count,
  MIN(id) as first_id,
  MAX(id) as last_id
FROM public.exercises
GROUP BY target_muscle
ORDER BY target_muscle;

-- Get exercise IDs grouped for smart template creation
-- This helps assign appropriate exercises to each day

-- Example: Get Chest exercises
SELECT id, exercise_name 
FROM public.exercises 
WHERE target_muscle ILIKE '%chest%' 
ORDER BY CAST(id AS INTEGER)
LIMIT 10;

-- Example: Get Back exercises  
SELECT id, exercise_name 
FROM public.exercises 
WHERE target_muscle ILIKE '%back%' 
ORDER BY CAST(id AS INTEGER)
LIMIT 10;

-- Example: Get Leg exercises
SELECT id, exercise_name 
FROM public.exercises 
WHERE target_muscle ILIKE '%leg%' OR target_muscle ILIKE '%quad%' OR target_muscle ILIKE '%hamstring%'
ORDER BY CAST(id AS INTEGER)
LIMIT 10;

-- Example: Get Shoulder exercises
SELECT id, exercise_name 
FROM public.exercises 
WHERE target_muscle ILIKE '%shoulder%' OR target_muscle ILIKE '%delt%'
ORDER BY CAST(id AS INTEGER)
LIMIT 10;

-- Export all exercise IDs to see the full range
SELECT 
  id,
  exercise_name,
  target_muscle,
  CASE 
    WHEN target_muscle ILIKE '%chest%' THEN 'Chest'
    WHEN target_muscle ILIKE '%back%' THEN 'Back'
    WHEN target_muscle ILIKE '%leg%' OR target_muscle ILIKE '%quad%' OR target_muscle ILIKE '%glute%' THEN 'Legs'
    WHEN target_muscle ILIKE '%shoulder%' OR target_muscle ILIKE '%delt%' THEN 'Shoulders'
    WHEN target_muscle ILIKE '%bicep%' THEN 'Biceps'
    WHEN target_muscle ILIKE '%tricep%' THEN 'Triceps'
    ELSE 'Other'
  END as muscle_group
FROM public.exercises
ORDER BY muscle_group, CAST(id AS INTEGER);
