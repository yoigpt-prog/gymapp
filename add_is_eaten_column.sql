-- Add is_eaten column to user_meal_plan table
-- This column tracks whether the user has marked a meal as eaten

ALTER TABLE public.user_meal_plan
ADD COLUMN IF NOT EXISTS is_eaten boolean DEFAULT false;

-- Add index for faster filtering by eaten status if needed
CREATE INDEX IF NOT EXISTS idx_user_meal_plan_is_eaten 
    ON public.user_meal_plan(user_id, is_eaten);

-- Grant update permission on the column
GRANT UPDATE ON public.user_meal_plan TO authenticated;

-- Add policy to allow users to update is_eaten status
DROP POLICY IF EXISTS "Users can update their meal status" ON public.user_meal_plan;
CREATE POLICY "Users can update their meal status" ON public.user_meal_plan
    FOR UPDATE USING (auth.uid() = user_id);
