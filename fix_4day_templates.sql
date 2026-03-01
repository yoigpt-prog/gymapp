-- FIX FOR 4-DAY TEMPLATES: Workout on 1,3,5,7 | Rest on 2,4,6
-- Run this in Supabase SQL Editor

-- Check current 4-day template patterns
SELECT slug, 
  template_json->'week'->'1'->>'type' as day1,
  template_json->'week'->'2'->>'type' as day2,
  template_json->'week'->'3'->>'type' as day3,
  template_json->'week'->'4'->>'type' as day4,
  template_json->'week'->'5'->>'type' as day5,
  template_json->'week'->'6'->>'type' as day6,
  template_json->'week'->'7'->>'type' as day7
FROM public.plan_templates 
WHERE slug LIKE '%_4d_%'
ORDER BY slug;

-- FIX: Set correct pattern for 4-day templates
-- We need to ensure Days 3, 5, 7 are workouts and Days 2, 4, 6 are rest
UPDATE public.plan_templates
SET template_json = 
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              template_json,
              '{week,2}',
              '{"type": "rest"}'::jsonb
            ),
            '{week,3}',
            template_json->'week'->'1'  -- Copy Day 1 workout to Day 3
          ),
          '{week,4}',
          '{"type": "rest"}'::jsonb
        ),
        '{week,5}',
        template_json->'week'->'1'  -- Copy Day 1 workout to Day 5
      ),
      '{week,6}',
      '{"type": "rest"}'::jsonb
    ),
    '{week,7}',
    template_json->'week'->'1'  -- Copy Day 1 workout to Day 7
  )
WHERE slug LIKE '%_4d_%';

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
WHERE slug LIKE '%_4d_%'
ORDER BY slug;

-- Expected result for 4-day templates:
-- day1: workout ✅
-- day2: rest ✅
-- day3: workout ✅
-- day4: rest ✅
-- day5: workout ✅
-- day6: rest ✅
-- day7: workout ✅
