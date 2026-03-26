-- ==============================================================================
-- GymGuide Supabase Migration Script
-- Purpose: Migrates local SharedPreferences metrics to cloud-persisted tables
-- ==============================================================================

-- 1. Create user_favorites table
CREATE TABLE IF NOT EXISTS public.user_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, exercise_name)
);

-- Enable RLS for user_favorites
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own favorites" ON public.user_favorites
    FOR ALL USING (auth.uid() = user_id);

-- 2. Create user_workout_progress table 
-- Tracks which exercises are completely checked off per day
CREATE TABLE IF NOT EXISTS public.user_workout_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    completed_exercises TEXT[] DEFAULT '{}',
    is_completed_day BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, date)
);

-- Enable RLS for user_workout_progress
ALTER TABLE public.user_workout_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own workout progress" ON public.user_workout_progress
    FOR ALL USING (auth.uid() = user_id);

-- 3. Add robust body metric columns to user_preferences
-- (Goals and Gender were already persisted here!)
ALTER TABLE public.user_preferences 
ADD COLUMN IF NOT EXISTS height_cm NUMERIC,
ADD COLUMN IF NOT EXISTS weight_kg NUMERIC,
ADD COLUMN IF NOT EXISTS age INTEGER;
