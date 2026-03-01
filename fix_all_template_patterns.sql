-- COMPLETE FIX FOR ALL TEMPLATE PATTERNS
-- Run this entire script in Supabase SQL Editor

-- ============================================================
-- 3 DAYS/WEEK: Workout on 1,3,5 | Rest on 2,4,6,7
-- ============================================================
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
      template_json->'week'->'3'  -- Copy Day 3 workout to Day 5
    ),
    '{week,6}',
    '{"type": "rest"}'::jsonb
  ),
  '{week,7}',
  '{"type": "rest"}'::jsonb
)
WHERE slug LIKE '%_3d_%';

-- ============================================================
-- 4 DAYS/WEEK: Workout on 1,3,5,7 | Rest on 2,4,6
-- ============================================================
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

-- ============================================================
-- 5 DAYS/WEEK: Workout on 1,2,4,6,7 | Rest on 3,5
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
WHERE slug LIKE '%_5d_%';

-- ============================================================
-- 6 DAYS/WEEK: Workout on 1,2,3,5,6,7 | Rest on 4
-- ============================================================
UPDATE public.plan_templates
SET template_json = jsonb_set(
  template_json,
  '{week,4}',
  '{"type": "rest"}'::jsonb
)
WHERE slug LIKE '%_6d_%';

-- ============================================================
-- VERIFICATION: Check all patterns
-- ============================================================

-- 3-day verification
SELECT '3-DAY TEMPLATES' as category, slug, 
  template_json->'week'->'1'->>'type' as day1,
  template_json->'week'->'2'->>'type' as day2,
  template_json->'week'->'3'->>'type' as day3,
  template_json->'week'->'4'->>'type' as day4,
  template_json->'week'->'5'->>'type' as day5,
  template_json->'week'->'6'->>'type' as day6,
  template_json->'week'->'7'->>'type' as day7
FROM public.plan_templates WHERE slug LIKE '%_3d_%'
UNION ALL
-- 4-day verification
SELECT '4-DAY TEMPLATES' as category, slug,
  template_json->'week'->'1'->>'type' as day1,
  template_json->'week'->'2'->>'type' as day2,
  template_json->'week'->'3'->>'type' as day3,
  template_json->'week'->'4'->>'type' as day4,
  template_json->'week'->'5'->>'type' as day5,
  template_json->'week'->'6'->>'type' as day6,
  template_json->'week'->'7'->>'type' as day7
FROM public.plan_templates WHERE slug LIKE '%_4d_%'
UNION ALL
-- 5-day verification
SELECT '5-DAY TEMPLATES' as category, slug,
  template_json->'week'->'1'->>'type' as day1,
  template_json->'week'->'2'->>'type' as day2,
  template_json->'week'->'3'->>'type' as day3,
  template_json->'week'->'4'->>'type' as day4,
  template_json->'week'->'5'->>'type' as day5,
  template_json->'week'->'6'->>'type' as day6,
  template_json->'week'->'7'->>'type' as day7
FROM public.plan_templates WHERE slug LIKE '%_5d_%'
UNION ALL
-- 6-day verification
SELECT '6-DAY TEMPLATES' as category, slug,
  template_json->'week'->'1'->>'type' as day1,
  template_json->'week'->'2'->>'type' as day2,
  template_json->'week'->'3'->>'type' as day3,
  template_json->'week'->'4'->>'type' as day4,
  template_json->'week'->'5'->>'type' as day5,
  template_json->'week'->'6'->>'type' as day6,
  template_json->'week'->'7'->>'type' as day7
FROM public.plan_templates WHERE slug LIKE '%_6d_%'
ORDER BY category, slug;
