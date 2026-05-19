-- ============================================================
-- AI Feature Usage Tracker & Yearly Limits
-- ============================================================

CREATE TABLE IF NOT EXISTS public.ai_feature_usage (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature      TEXT NOT NULL,
  year         INT NOT NULL,
  usage_count  INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_user_feature_year UNIQUE (user_id, feature, year)
);

-- Index for fast lookup by user and feature
CREATE INDEX IF NOT EXISTS idx_ai_feature_usage_lookup
  ON public.ai_feature_usage (user_id, feature, year);

-- Enable RLS
ALTER TABLE public.ai_feature_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own AI usage"
  ON public.ai_feature_usage FOR SELECT
  USING (auth.uid() = user_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_ai_feature_usage_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ai_feature_usage_updated_at ON public.ai_feature_usage;
CREATE TRIGGER trg_ai_feature_usage_updated_at
  BEFORE UPDATE ON public.ai_feature_usage
  FOR EACH ROW EXECUTE FUNCTION public.set_ai_feature_usage_updated_at();

-- Safe increment function (RPC)
CREATE OR REPLACE FUNCTION public.increment_ai_feature_usage(
  p_user_id UUID,
  p_feature TEXT,
  p_year INT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.ai_feature_usage (user_id, feature, year, usage_count)
  VALUES (p_user_id, p_feature, p_year, 1)
  ON CONFLICT (user_id, feature, year)
  DO UPDATE SET
    usage_count = public.ai_feature_usage.usage_count + 1,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
