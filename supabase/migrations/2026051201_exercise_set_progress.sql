-- ============================================================
-- Migration: user_exercise_set_progress
-- Purpose  : Persist per-set completion for every exercise on every
--            workout day.  Works for both staging and production.
-- ============================================================

-- 1. Create the table (idempotent)
CREATE TABLE IF NOT EXISTS public.user_exercise_set_progress (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL,
  plan_id       uuid        NULL,           -- ai_plans.id (nullable for guests)
  week_number   int         NOT NULL,
  day_number    int         NOT NULL,       -- 1-based global day within the plan
  exercise_id   text        NOT NULL,       -- exercises.id (normalised, 6-digit padded)
  set_index     int         NOT NULL,       -- 0-based index
  reps          int         NOT NULL DEFAULT 10,
  is_completed  boolean     NOT NULL DEFAULT false,
  completed_at  timestamptz NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  UNIQUE (user_id, plan_id, week_number, day_number, exercise_id, set_index)
);

-- 2. Unique index that treats NULL plan_id as equal (for guest sessions)
--    Postgres UNIQUE constraint does NOT catch two NULLs, so we add a
--    partial index for the guest case.
CREATE UNIQUE INDEX IF NOT EXISTS uq_set_progress_no_plan
  ON public.user_exercise_set_progress (user_id, week_number, day_number, exercise_id, set_index)
  WHERE plan_id IS NULL;

-- 3. Row Level Security
ALTER TABLE public.user_exercise_set_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own set progress" ON public.user_exercise_set_progress;
CREATE POLICY "Users manage own set progress"
  ON public.user_exercise_set_progress
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 4. Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_progress_updated_at ON public.user_exercise_set_progress;
CREATE TRIGGER trg_set_progress_updated_at
  BEFORE UPDATE ON public.user_exercise_set_progress
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 5. Index for fast per-exercise lookups
CREATE INDEX IF NOT EXISTS idx_set_progress_lookup
  ON public.user_exercise_set_progress (user_id, week_number, day_number, exercise_id);
