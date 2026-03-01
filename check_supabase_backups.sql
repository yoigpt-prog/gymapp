-- STEP 1: Check for Supabase Backup/Rollback Options
-- Run these queries to explore backup possibilities

-- Option A: Check if there's a history/audit table
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%history%' OR table_name LIKE '%audit%' OR table_name LIKE '%backup%';

-- Option B: Check for triggers that might log changes
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'plan_templates';

-- Option C: If using Supabase Time Travel (PostgreSQL Point-in-Time Recovery)
-- This would require database admin access through Supabase dashboard
-- Go to: Supabase Dashboard → Database → Backups
-- Check if "Point in Time Recovery" is enabled

-- Option D: Export current broken state before attempting fix
COPY (
  SELECT slug, template_json 
  FROM public.plan_templates 
  WHERE slug LIKE '%_3d_%' OR slug LIKE '%_4d_%'
) TO '/tmp/templates_backup_broken.json' WITH (FORMAT json);

-- Option E: Check if there are any other template tables
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (table_name LIKE '%template%' OR table_name LIKE '%plan%');
