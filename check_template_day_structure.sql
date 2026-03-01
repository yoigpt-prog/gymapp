-- CRITICAL: Check the EXACT structure of your template
SELECT 
  slug,
  template_json->'week'->'1' as day1_structure
FROM public.plan_templates  
WHERE slug LIKE '%_4d_%'
LIMIT 1;

-- Is it:
-- {"type": "workout", "exercises": [...]}  ← CORRECT
-- OR
-- {"1": {"type": "workout", "exercises": [...]}}  ← WRONG (nested)
