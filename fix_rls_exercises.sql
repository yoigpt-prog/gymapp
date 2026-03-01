-- 1. Enable RLS on exercises table (if not already enabled)
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- 2. Drop the policy if it exists to avoid errors
DROP POLICY IF EXISTS "Public read exercises" ON public.exercises;

-- 3. Create the policy allowing everyone to read exercises
CREATE POLICY "Public read exercises"
ON public.exercises
FOR SELECT
USING (true);

-- 4. Verify policy creation (optional, for manual check)
-- SELECT * FROM pg_policies WHERE tablename = 'exercises';
