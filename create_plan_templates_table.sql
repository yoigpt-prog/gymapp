-- Schema for plan_templates table
-- Run this FIRST before seeding templates

-- Create plan_templates table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.plan_templates (
    id BIGSERIAL PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    template_json JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Optional metadata columns
    name TEXT,
    description TEXT,
    target_gender TEXT,
    target_goal TEXT,
    target_location TEXT,
    days_per_week INTEGER
);

-- Create index on slug for fast lookups
CREATE INDEX IF NOT EXISTS idx_plan_templates_slug ON public.plan_templates(slug);

-- Create index on is_active for filtering
CREATE INDEX IF NOT EXISTS idx_plan_templates_active ON public.plan_templates(is_active);

-- Enable RLS (Row Level Security)
ALTER TABLE public.plan_templates ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all users to SELECT active templates
CREATE POLICY IF NOT EXISTS "Allow public read access to active templates"
ON public.plan_templates
FOR SELECT
USING (is_active = true);

-- Create policy for authenticated users to manage templates (optional - for admin)
CREATE POLICY IF NOT EXISTS "Allow authenticated users to manage templates"
ON public.plan_templates
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload config';

-- Verify table structure
\d public.plan_templates
