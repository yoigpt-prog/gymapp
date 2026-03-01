-- STEP 2: Create Unique Exercises for Each Workout Day
-- This assigns different exercise IDs to each workout day

-- IMPORTANT: This assumes exercise IDs exist in your exercises table
-- Adjust the exercise ID ranges based on what's actually in your database

-- ============================================================
-- RESTORE 3-DAY TEMPLATES (Days 1, 3, 5 with unique exercises)
-- ============================================================

-- Day 1: Upper Body Push (exercises 1-8)
-- Day 3: Lower Body (exercises 9-16)  
-- Day 5: Upper Body Pull (exercises 17-24)

UPDATE public.plan_templates
SET template_json = jsonb_set(
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
)
WHERE slug LIKE '%_3d_%';

-- ============================================================
-- RESTORE 4-DAY TEMPLATES (Days 1, 3, 5, 7 with unique exercises)
-- ============================================================

-- Day 1: Chest/Triceps (exercises 25-32)
-- Day 3: Back/Biceps (exercises 33-40)
-- Day 5: Legs (exercises 41-48)
-- Day 7: Shoulders/Arms (exercises 49-56)

UPDATE public.plan_templates
SET template_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        template_json,
        '{week,1}',
        '{"type": "workout", "exercises": ["000025", "000026", "000027", "000028", "000029", "000030", "000031", "000032"]}'::jsonb
      ),
      '{week,3}',
      '{"type": "workout", "exercises": ["000033", "000034", "000035", "000036", "000037", "000038", "000039", "000040"]}'::jsonb
    ),
    '{week,5}',
    '{"type": "workout", "exercises": ["000041", "000042", "000043", "000044", "000045", "000046", "000047", "000048"]}'::jsonb
  ),
  '{week,7}',
  '{"type": "workout", "exercises": ["000049", "000050", "000051", "000052", "000053", "000054", "000055", "000056"]}'::jsonb
)
WHERE slug LIKE '%_4d_%';

-- ============================================================
-- RESTORE 5-DAY TEMPLATES (Days 1, 2, 4, 6, 7 with unique exercises)
-- ============================================================

-- Different muscle groups each day
UPDATE public.plan_templates
SET template_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          template_json,
          '{week,1}',
          '{"type": "workout", "exercises": ["000057", "000058", "000059", "000060", "000061", "000062"]}'::jsonb
        ),
        '{week,2}',
        '{"type": "workout", "exercises": ["000063", "000064", "000065", "000066", "000067", "000068"]}'::jsonb
      ),
      '{week,4}',
      '{"type": "workout", "exercises": ["000069", "000070", "000071", "000072", "000073", "000074"]}'::jsonb
    ),
    '{week,6}',
    '{"type": "workout", "exercises": ["000075", "000076", "000077", "000078", "000079", "000080"]}'::jsonb
  ),
  '{week,7}',
  '{"type": "workout", "exercises": ["000081", "000082", "000083", "000084", "000085", "000086"]}'::jsonb
)
WHERE slug LIKE '%_5d_%';

-- ============================================================
-- RESTORE 6-DAY TEMPLATES (Days 1, 2, 3, 5, 6, 7 with unique exercises)
-- ============================================================

UPDATE public.plan_templates
SET template_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            template_json,
            '{week,1}',
            '{"type": "workout", "exercises": ["000087", "000088", "000089", "000090", "000091", "000092"]}'::jsonb
          ),
          '{week,2}',
          '{"type": "workout", "exercises": ["000093", "000094", "000095", "000096", "000097", "000098"]}'::jsonb
        ),
        '{week,3}',
        '{"type": "workout", "exercises": ["000099", "000100", "000101", "000102", "000103", "000104"]}'::jsonb
      ),
      '{week,5}',
      '{"type": "workout", "exercises": ["000105", "000106", "000107", "000108", "000109", "000110"]}'::jsonb
    ),
    '{week,6}',
    '{"type": "workout", "exercises": ["000111", "000112", "000113", "000114", "000115", "000116"]}'::jsonb
  ),
  '{week,7}',
  '{"type": "workout", "exercises": ["000117", "000118", "000119", "000120", "000121", "000122"]}'::jsonb
)
WHERE slug LIKE '%_6d_%';

-- ============================================================
-- VERIFICATION
-- ============================================================

SELECT 
  slug,
  jsonb_array_length(template_json->'week'->'1'->'exercises') as day1_count,
  jsonb_array_length(template_json->'week'->'3'->'exercises') as day3_count,
  template_json->'week'->'1'->'exercises'->0 as day1_first_ex,
  template_json->'week'->'3'->'exercises'->0 as day3_first_ex
FROM public.plan_templates
WHERE slug LIKE '%_3d_%' OR slug LIKE '%_4d_%'
ORDER BY slug;
