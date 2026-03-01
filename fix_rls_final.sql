-- 1. Ensure Schema Access (Critical for RLS to work)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Ensure Table Access (The "Door" to the table)
GRANT SELECT ON TABLE public.exercises TO anon, authenticated, service_role;

-- 3. Enable RLS (The "Lock")
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- 4. Clean up OLD policies (The "Old Keys")
DROP POLICY IF EXISTS "exercises_read_all" ON public.exercises;
DROP POLICY IF EXISTS "Public read exercises" ON public.exercises;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.exercises;
DROP POLICY IF EXISTS "read_exercises" ON public.exercises;
DROP POLICY IF EXISTS "allow_select" ON public.exercises;

-- 5. Create NEW Policy (The "New Key" that fits everyone)
CREATE POLICY "exercises_read_all"
ON public.exercises
FOR SELECT
TO public -- "public" role includes anon and authenticated
USING (true);

-- 6. Refresh Cache
NOTIFY pgrst, 'reload config';
