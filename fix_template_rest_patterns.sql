-- Fix All Template Rest Day Patterns
-- Run this in Supabase SQL Editor

-- ============================================================
-- A) 3 DAYS/WEEK: Workout on Days 1,3,5 | Rest on Days 2,4,6,7
-- ============================================================

-- First, get a sample workout day structure to copy from
-- We'll use this to ensure Day 5 has proper workout structure
DO $$
DECLARE
  template_record RECORD;
  day1_data jsonb;
  day3_data jsonb;
BEGIN
  FOR template_record IN 
    SELECT id, slug, template_json FROM public.plan_templates WHERE slug LIKE '%_3d_%'
  LOOP
    -- Get workout structure from Day 1 (which should be a workout)
    day1_data := template_record.template_json->'week'->'1';
    
    -- If Day 1 doesn't have exercises, try Day 3
    IF day1_data->>'type' = 'workout' THEN
      day3_data := day1_data; -- Use Day 1 structure for Day 5
    ELSE
      day3_data := template_record.template_json->'week'->'3';
    END IF;
    
    -- Update the template with correct pattern
    UPDATE public.plan_templates
    SET template_json = jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              template_json,
              '{week,2}',
              '{"type": "rest"}'::jsonb
            ),
            '{week,4}',
            '{"type": "rest"}'::jsonb
          ),
          '{week,5}',
          day3_data  -- Ensure Day 5 is a workout with exercise structure
        ),
        '{week,6}',
        '{"type": "rest"}'::jsonb
      ),
      '{week,7}',
      '{"type": "rest"}'::jsonb
    )
    WHERE id = template_record.id;
  END LOOP;
END $$;

-- ============================================================
-- B) 4 DAYS/WEEK: Workout on Days 1,3,5,7 | Rest on Days 2,4,6
-- ============================================================
UPDATE public.plan_templates 
SET template_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      template_json,
      '{week,2}',
      '{"type": "rest"}'::jsonb
    ),
    '{week,4}',
    '{"type": "rest"}'::jsonb
  ),
  '{week,6}',
  '{"type": "rest"}'::jsonb
)
WHERE slug LIKE '%_4d_%'
  AND template_json->'week'->'2'->>'type' != 'rest';

-- ============================================================
-- C) 5 DAYS/WEEK: Workout on Days 1,2,4,6,7 | Rest on Days 3,5
-- ============================================================
UPDATE public.plan_templates 
SET template_json = jsonb_set(
  jsonb_set(
    template_json,
    '{week,3}',
    '{"type": "rest"}'::jsonb
  ),
  '{week,5}',
  '{"type": "rest"}'::jsonb
)
WHERE slug LIKE '%_5d_%'
  AND template_json->'week'->'3'->>'type' != 'rest';

-- ============================================================
-- D) 6 DAYS/WEEK: Workout on Days 1,2,3,5,6,7 | Rest on Day 4
-- ============================================================
UPDATE public.plan_templates 
SET template_json = jsonb_set(
  template_json,
  '{week,4}',
  '{"type": "rest"}'::jsonb
)
WHERE slug LIKE '%_6d_%'
  AND template_json->'week'->'4'->>'type' != 'rest';

-- ============================================================
-- VERIFICATION: Check the patterns
-- ============================================================

-- Check 3-day templates
SELECT 
  slug,
  (template_json->'week'->'1'->>'type') as day1,
  (template_json->'week'->'2'->>'type') as day2,
  (template_json->'week'->'3'->>'type') as day3,
  (template_json->'week'->'4'->>'type') as day4,
  (template_json->'week'->'5'->>'type') as day5,
  (template_json->'week'->'6'->>'type') as day6,
  (template_json->'week'->'7'->>'type') as day7
FROM public.plan_templates 
WHERE slug LIKE '%_3d_%'
ORDER BY slug;

-- Check 4-day templates
SELECT 
  slug,
  (template_json->'week'->'1'->>'type') as day1,
  (template_json->'week'->'2'->>'type') as day2,
  (template_json->'week'->'3'->>'type') as day3,
  (template_json->'week'->'4'->>'type') as day4,
  (template_json->'week'->'5'->>'type') as day5,
  (template_json->'week'->'6'->>'type') as day6,
  (template_json->'week'->'7'->>'type') as day7
FROM public.plan_templates 
WHERE slug LIKE '%_4d_%'
ORDER BY slug;

-- Check 5-day templates
SELECT 
  slug,
  (template_json->'week'->'1'->>'type') as day1,
  (template_json->'week'->'2'->>'type') as day2,
  (template_json->'week'->'3'->>'type') as day3,
  (template_json->'week'->'4'->>'type') as day4,
  (template_json->'week'->'5'->>'type') as day5,
  (template_json->'week'->'6'->>'type') as day6,
  (template_json->'week'->'7'->>'type') as day7
FROM public.plan_templates 
WHERE slug LIKE '%_5d_%'
ORDER BY slug;

-- Check 6-day templates
SELECT 
  slug,
  (template_json->'week'->'1'->>'type') as day1,
  (template_json->'week'->'2'->>'type') as day2,
  (template_json->'week'->'3'->>'type') as day3,
  (template_json->'week'->'4'->>'type') as day4,
  (template_json->'week'->'5'->>'type') as day5,
  (template_json->'week'->'6'->>'type') as day6,
  (template_json->'week'->'7'->>'type') as day7
FROM public.plan_templates 
WHERE slug LIKE '%_6d_%'
ORDER BY slug;

-- Summary: Count templates by days/week
SELECT 
  SUBSTRING(slug FROM '_(\\d+)d_') as days_per_week,
  COUNT(*) as template_count
FROM public.plan_templates
GROUP BY SUBSTRING(slug FROM '_(\\d+)d_')
ORDER BY days_per_week;
