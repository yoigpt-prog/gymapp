-- ============================================================
-- STAGING ONLY — User Workout Customizations
-- File    : 20260512_add_workout_customizations.sql
-- Date    : 2026-05-12
-- PURPOSE : Add columns to track user-added and user-removed
--           exercises for a specific day in their workout plan.
-- ============================================================

ALTER TABLE user_workout_progress 
ADD COLUMN IF NOT EXISTS added_exercises JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS removed_exercises JSONB DEFAULT '[]'::jsonb;

-- Added for dynamic sets/reps
ALTER TABLE user_preferences 
ADD COLUMN IF NOT EXISTS experience_level TEXT,
ADD COLUMN IF NOT EXISTS session_duration TEXT;
