-- ============================================================================
-- Win Time — Storage bucket pour photos restaurants
-- Date : 2026-05-04
-- ============================================================================
-- Crée le bucket `restaurant-photos` (5 MB max, JPEG/PNG/WebP) et applique les
-- RLS sur storage.objects :
--   - write : owner uniquement (path doit commencer par auth.uid())
--   - read : public (anon + authenticated)
--
-- Convention de path : `{ownerId}/logo.jpg`, `{ownerId}/banner.png`,
-- `{ownerId}/gallery/{uuid}.webp`. La 1re partie = UID du commerçant.
-- ============================================================================

-- Bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'restaurant-photos',
  'restaurant-photos',
  true,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- RLS storage.objects (déjà activée par défaut sur Supabase)
DROP POLICY IF EXISTS restaurant_photos_owner_write ON storage.objects;
DROP POLICY IF EXISTS restaurant_photos_public_read ON storage.objects;

-- Owner : peut INSERT/UPDATE/DELETE seulement dans son propre dossier
CREATE POLICY restaurant_photos_owner_write
  ON storage.objects
  FOR ALL
  TO authenticated
  USING (
    bucket_id = 'restaurant-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'restaurant-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public : tout le monde peut lire (les photos s'affichent côté Client)
CREATE POLICY restaurant_photos_public_read
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'restaurant-photos');
