-- Create the public storage bucket for post media (images & videos).
-- Path structure: {channelID}/{UUID}.{ext}
INSERT INTO storage.buckets (id, name, public)
VALUES ('posts', 'posts', true)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload to the posts bucket.
CREATE POLICY "posts_storage_insert_authenticated"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'posts'
);

-- Anyone can read from the public posts bucket.
CREATE POLICY "posts_storage_select_public"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'posts'
);
