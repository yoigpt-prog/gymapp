-- ============================================================
-- add_workout_columns_to_user_preferences.sql
-- Run this in Supabase SQL Editor.
-- Adds workout-related columns to user_preferences so the
-- generate_user_workout_plan RPC can read them.
-- ============================================================

ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS gender           text DEFAULT 'male',
  ADD COLUMN IF NOT EXISTS training_location text DEFAULT 'gym',
  ADD COLUMN IF NOT EXISTS training_days    int  DEFAULT 4;

-- Notify PostgREST to reload its schema cache immediately
NOTIFY pgrst, 'reload schema';
