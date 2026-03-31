-- Adds the missing 'is_eaten' boolean state to the pivot table
ALTER TABLE public.user_meal_plan_meals 
ADD COLUMN IF NOT EXISTS is_eaten BOOLEAN DEFAULT FALSE;

-- Ensure authenticated users can update the meal status on this newly added column
GRANT UPDATE(is_eaten) ON public.user_meal_plan_meals TO authenticated;
