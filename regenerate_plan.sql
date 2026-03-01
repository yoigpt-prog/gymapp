-- DELETE OLD PLAN AND REGENERATE
-- Your templates are now correct, but the saved plan in ai_plans is from before the fix

-- Step 1: Delete the old broken plan
DELETE FROM public.ai_plans 
WHERE user_id = auth.uid();

-- Step 2: Verify it's deleted
SELECT COUNT(*) FROM public.ai_plans WHERE user_id = auth.uid();
-- Should return 0

-- After running this, go back to your app and complete the quiz again
-- This will generate a NEW plan using the corrected templates
