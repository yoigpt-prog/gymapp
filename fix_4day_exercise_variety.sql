-- FIX 4-DAY TEMPLATES - Assign Unique Exercises to Each Workout Day
-- This ensures Days 1, 3, 5, 7 have DIFFERENT exercises

-- ============================================================
-- STEP 1: Check current state (all days have same exercises)
-- ============================================================
SELECT 
  slug,
  'Day 1' as day,
  template_json->'week'->'1'->'exercises' as exercises
FROM public.plan_templates 
WHERE slug LIKE '%_4d_%'
LIMIT 1;

-- ============================================================
-- STEP 2: FIX - Assign different exercises to each workout day
-- ============================================================

-- For 4-day templates, assign unique exercise sets per day:
-- Day 1: Chest/Triceps (exercises 1-8)
-- Day 3: Back/Biceps (exercises 9-16)  
-- Day 5: Legs/Glutes (exercises 17-24)
-- Day 7: Shoulders/Arms (exercises 25-32)

UPDATE public.plan_templates
SET template_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        template_json,
        '{week,1}',
        '{"type": "workout", "exercises": ["000001", "000002", "000003", "000004", "000005", "000006", "000007", "000008"]}'::jsonb
      ),
      '{week,3}',
      '{"type": "workout", "exercises": ["000009", "000010", "000011", "000012", "000013", "000014", "000015", "000016"]}'::jsonb
    ),
    '{week,5}',
    '{"type": "workout", "exercises": ["000017", "000018", "000019", "000020", "000021", "000022", "000023", "000024"]}'::jsonb
  ),
  '{week,7}',
  '{"type": "workout", "exercises": ["000025", "000026", "000027", "000028", "000029", "000030", "000031", "000032"]}'::jsonb
)
WHERE slug LIKE '%_4d_%';

-- ============================================================
-- STEP 3: Verify the fix - Each day should have different exercises
-- ============================================================
SELECT 
  slug,
  template_json->'week'->'1'->'exercises'->0 as day1_first,
  template_json->'week'->'3'->'exercises'->0 as day3_first,
  template_json->'week'->'5'->'exercises'->0 as day5_first,
  template_json->'week'->'7'->'exercises'->0 as day7_first,
  CASE 
    WHEN template_json->'week'->'1'->'exercises'->0 = template_json->'week'->'3'->'exercises'->0 
    THEN '❌ STILL BROKEN - Same exercises'
    ELSE '✅ FIXED - Different exercises'
  END as status
FROM public.plan_templates 
WHERE slug LIKE '%_4d_%';

-- Expected result:
-- day1_first: "000001"
-- day3_first: "000009"  
-- day5_first: "000017"
-- day7_first: "000025"
-- status: ✅ FIXED

-- ============================================================
-- OPTIONAL: View full template structure after fix
-- ============================================================
SELECT 
  slug,
  jsonb_pretty(template_json->'week') as week_structure
FROM public.plan_templates 
WHERE slug LIKE '%_4d_%'
LIMIT 1;
