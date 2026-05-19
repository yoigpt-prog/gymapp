-- ============================================================
-- Rate My Physique AI — Analysis Table & Storage
-- ============================================================

-- physique_analyses table
CREATE TABLE IF NOT EXISTS public.physique_analyses (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  image_url        TEXT,
  result_json      JSONB,
  status           TEXT NOT NULL DEFAULT 'processing',   -- processing | completed | failed
  error_message    TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

-- Index for fast lookup by user (most recent first)
CREATE INDEX IF NOT EXISTS idx_physique_analyses_user_id
  ON public.physique_analyses (user_id, created_at DESC);

-- RLS
ALTER TABLE public.physique_analyses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own physique analyses"
  ON public.physique_analyses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can select own physique analyses"
  ON public.physique_analyses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own physique analyses"
  ON public.physique_analyses FOR UPDATE
  USING (auth.uid() = user_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_physique_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_physique_updated_at ON public.physique_analyses;
CREATE TRIGGER trg_physique_updated_at
  BEFORE UPDATE ON public.physique_analyses
  FOR EACH ROW EXECUTE FUNCTION public.set_physique_updated_at();

-- ── Storage Bucket ────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('physique-uploads', 'physique-uploads', false)
ON CONFLICT (id) DO NOTHING;

-- Users can upload their own images
CREATE POLICY "Users can upload physique images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'physique-uploads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can read their own images
CREATE POLICY "Users can read own physique images"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'physique-uploads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can delete their own images
CREATE POLICY "Users can delete own physique images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'physique-uploads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
