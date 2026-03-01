-- FIND REAL EXERCISE IDs FROM YOUR DATABASE
-- Run this first to see what exercise IDs actually exist

-- ============================================================
-- STEP 1: Check what exercise IDs exist in your exercises table
-- ============================================================
SELECT id, exercise_name, target_muscle, equipment
FROM public.exercises
ORDER BY id
LIMIT 50;

-- ============================================================
-- STEP 2: Check one existing 4-day template to see its structure
-- ============================================================
SELECT 
  slug,
  template_json->'week'->'1'->'exercises' as day1_exercises,
  template_json->'week'->'2'->'exercises' as day2_exercises,
  template_json->'week'->'3'->'exercises' as day3_exercises,
  template_json->'week'->'4'->'exercises' as day4_exercises,
  template_json->'week'->'5'->'exercises' as day5_exercises,
  template_json->'week'->'6'->'exercises' as day6_exercises,
  template_json->'week'->'7'->'exercises' as day7_exercises
FROM public.plan_templates
WHERE slug LIKE '%_4d_%'
LIMIT 1;

-- ============================================================
-- STEP 3: See the REAL exercise IDs that are currently in use
-- ============================================================
-- This extracts all unique exercise IDs from existing templates
WITH template_exercises AS (
  SELECT 
    slug,
    jsonb_array_elements_text(
      jsonb_path_query_array(template_json, '$.week.*.exercises[*]')
    ) as exercise_id
  FROM public.plan_templates
  WHERE slug LIKE '%_4d_%'
)
SELECT DISTINCT exercise_id
FROM template_exercises
ORDER BY exercise_id;

-- ============================================================
-- After running the above queries, you'll see:
-- 1. What exercise IDs exist in your exercises table
-- 2. What exercise IDs are currently in your 4-day templates
-- 3. You can then update fix_4day_exercise_variety.sql with real IDs
-- ============================================================
