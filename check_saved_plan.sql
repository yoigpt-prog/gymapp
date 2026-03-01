-- CHECK WHAT'S ACTUALLY SAVED IN AI_PLANS
-- This will show the structure of your saved workout plan

-- Check the schedule_json structure in your saved plan
SELECT 
  user_id,
  id,
  jsonb_pretty(schedule_json) as saved_plan_structure
FROM public.ai_plans
WHERE user_id = auth.uid()
  AND plan_type = 'workout'
ORDER BY created_at DESC
LIMIT 1;

-- Check if weeks exist
SELECT 
  schedule_json->'weeks' as weeks_data
FROM public.ai_plans
WHERE user_id = auth.uid()
  AND plan_type = 'workout'
ORDER BY created_at DESC
LIMIT 1;

-- Check week 1 structure
SELECT 
  schedule_json->'weeks'->'1' as week1_data
FROM public.ai_plans
WHERE user_id = auth.uid()
  AND plan_type = 'workout'
ORDER BY created_at DESC
LIMIT 1;

-- Check week 1 day 1 specifically
SELECT 
  schedule_json->'weeks'->'1'->'days'->'1' as day1_data
FROM public.ai_plans
WHERE user_id = auth.uid()
  AND plan_type = 'workout'
ORDER BY created_at DESC
LIMIT 1;
