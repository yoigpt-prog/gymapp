-- ============================================================
-- AI Transformation Tables & Storage Buckets
-- ============================================================

-- transformation_requests table
CREATE TABLE IF NOT EXISTS public.transformation_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  original_image_url TEXT NOT NULL,
  result_image_url   TEXT,
  goal               TEXT NOT NULL DEFAULT 'Fit & Healthy',
  status             TEXT NOT NULL DEFAULT 'processing',
  created_at     TIMESTAMPTZ DEFAULT now(),
  updated_at     TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE public.transformation_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own requests"
  ON public.transformation_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own requests"
  ON public.transformation_requests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own requests"
  ON public.transformation_requests FOR UPDATE
  USING (auth.uid() = user_id);

-- ── Storage Buckets ─────────────────────────────────────────

-- originals bucket (private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('transformation-originals', 'transformation-originals', true)
ON CONFLICT (id) DO NOTHING;

-- results bucket (public so the app can display results)
INSERT INTO storage.buckets (id, name, public)
VALUES ('transformation-results', 'transformation-results', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS for originals
CREATE POLICY "Users can upload own originals"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'transformation-originals'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can read own originals"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'transformation-originals'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Storage RLS for results (public read, service writes)
CREATE POLICY "Anyone can read transformation results"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'transformation-results');
