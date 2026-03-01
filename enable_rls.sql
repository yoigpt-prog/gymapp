-- 1. Enable RLS
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies to start fresh
DROP POLICY IF EXISTS exercises_read_all ON public.exercises;
DROP POLICY IF EXISTS "Public read exercises" ON public.exercises;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.exercises;
DROP POLICY IF EXISTS read_exercises ON public.exercises;

-- 3. Create the broad SELECT policy
CREATE POLICY exercises_read_all
ON public.exercises
FOR SELECT
TO anon, authenticated
USING (true);

-- 4. Explicitly GRANT permissions (RLS requires table permissions under the hood)
GRANT SELECT ON public.exercises TO anon, authenticated;

-- 5. Force schema cache reload (helps Supabase recognize changes immediately)
NOTIFY pgrst, 'reload config';
