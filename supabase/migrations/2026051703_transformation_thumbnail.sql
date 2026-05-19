-- Add thumbnail_url to transformation_requests table
ALTER TABLE public.transformation_requests
ADD COLUMN IF NOT EXISTS thumbnail_url text;

-- Add index to speed up lookups (optional but good practice if used in queries, though we usually query by share_token)
-- We don't necessarily need an index on thumbnail_url, but just defining the column is sufficient.
