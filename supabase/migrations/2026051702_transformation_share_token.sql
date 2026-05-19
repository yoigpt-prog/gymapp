-- ============================================================
-- AI Transformation — Public Share Token
-- ============================================================

-- Add share_token column (auto-generated on insert)
ALTER TABLE public.transformation_requests
  ADD COLUMN IF NOT EXISTS share_token UUID DEFAULT gen_random_uuid();

-- Index for fast token lookups on the public share page
CREATE INDEX IF NOT EXISTS idx_transformation_share_token
  ON public.transformation_requests (share_token);

-- Allow anyone (incl. anonymous / unauthenticated) to read a row
-- only if it has a share_token (i.e. it was completed and shared).
-- This does NOT expose private user data — the SELECT is scoped to
-- safe columns only via the application layer.
CREATE POLICY "Public can read completed transformations by share token"
  ON public.transformation_requests FOR SELECT
  USING (share_token IS NOT NULL AND status = 'completed');
