-- Migration: Strict Plan Generation Support

-- 1. plan_templates: Ensure 'slug' exists
ALTER TABLE public.plan_templates ADD COLUMN IF NOT EXISTS slug text;
-- Add constraint if data is clean (optional, might fail if duplicates exist so we just add index/unique if possible)
-- CREATE UNIQUE INDEX IF NOT EXISTS plan_templates_slug_idx ON public.plan_templates (slug);

-- 2. ai_plans: Add required columns
ALTER TABLE public.ai_plans ADD COLUMN IF NOT EXISTS slug_used text;
ALTER TABLE public.ai_plans ADD COLUMN IF NOT EXISTS days_per_week int; -- User requirement
ALTER TABLE public.ai_plans ADD COLUMN IF NOT EXISTS gender text;

-- 3. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload config';
