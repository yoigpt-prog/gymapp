-- supabase_meal_history.sql
-- Create table for immutable meal snapshots

CREATE TABLE IF NOT EXISTS public.meal_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  meal_id UUID NOT NULL,
  day_index INTEGER NOT NULL,
  meal_name TEXT NOT NULL,
  calories INTEGER DEFAULT 0,
  protein INTEGER DEFAULT 0,
  carbs INTEGER DEFAULT 0,
  fat INTEGER DEFAULT 0,
  ingredients JSONB,
  eaten_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, meal_id, day_index)
);

ALTER TABLE public.meal_logs ENABLE ROW LEVEL SECURITY;

-- Drop old policy if it exists, then recreate with explicit INSERT/DELETE support
DROP POLICY IF EXISTS "Users can manage their own meal logs" ON public.meal_logs;

CREATE POLICY "Users can view their own meal logs" ON public.meal_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own meal logs" ON public.meal_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own meal logs" ON public.meal_logs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own meal logs" ON public.meal_logs
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_meal_logs_user_day ON public.meal_logs(user_id, day_index);

