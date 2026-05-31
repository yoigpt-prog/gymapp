-- Add quiz and premium columns to user_preferences
-- Defaults to true for existing rows because users currently in the table have already completed the quiz.
ALTER TABLE IF EXISTS public.user_preferences
ADD COLUMN IF NOT EXISTS quiz_started BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS quiz_completed BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS premium BOOLEAN DEFAULT FALSE;
