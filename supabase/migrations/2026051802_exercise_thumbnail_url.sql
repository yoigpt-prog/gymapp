-- Add thumbnail_url to exercises table
ALTER TABLE public.exercises
ADD COLUMN IF NOT EXISTS thumbnail_url text;
