-- SIMPLE FIX FOR 3-DAY TEMPLATES: Day 5 should be WORKOUT
-- Run this in Supabase SQL Editor

-- This query will check current Day 5 status for 3-day templates
SELECT slug, 
  template_json->'week'->'5'->>'type' as day5_current_type,
  CASE 
    WHEN template_json->'week'->'5'->>'type' = 'rest' THEN '❌ WRONG - Should be workout'
    ELSE '✅ Correct'
  END as status
FROM public.plan_templates 
WHERE slug LIKE '%_3d_%';

-- FIX: Copy Day 3 workout structure to Day 5 for all 3-day templates
UPDATE public.plan_templates
SET template_json = jsonb_set(
  template_json,
  '{week,5}',
  template_json->'week'->'3'  -- Copy Day 3 workout to Day 5
)
WHERE slug LIKE '%_3d_%'
  AND template_json->'week'->'5'->>'type' = 'rest';

-- Verify the fix
SELECT slug, 
  template_json->'week'->'1'->>'type' as day1,
  template_json->'week'->'2'->>'type' as day2,
  template_json->'week'->'3'->>'type' as day3,
  template_json->'week'->'4'->>'type' as day4,
  template_json->'week'->'5'->>'type' as day5,
  template_json->'week'->'6'->>'type' as day6,
  template_json->'week'->'7'->>'type' as day7
FROM public.plan_templates 
WHERE slug LIKE '%_3d_%'
ORDER BY slug;

-- Expected result for 3-day templates:
-- day1: workout
-- day2: rest
-- day3: workout
-- day4: rest
-- day5: workout ✅
-- day6: rest
-- day7: rest
