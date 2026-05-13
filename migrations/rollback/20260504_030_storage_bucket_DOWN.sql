-- ============================================================================
-- ROLLBACK: 20260504_030_storage_bucket.sql
-- Removes the restaurant-photos bucket + its RLS policies. DANGER: object
-- files are deleted only if you also `supabase storage rm`; this script
-- removes the bucket *record* but Supabase may retain orphan blobs.
-- ============================================================================

DROP POLICY IF EXISTS restaurant_photos_owner_write ON storage.objects;
DROP POLICY IF EXISTS restaurant_photos_public_read ON storage.objects;

-- Remove the bucket. Orphan objects must be purged separately via the
-- Supabase Studio Storage page or the Storage admin API.
DELETE FROM storage.buckets WHERE id = 'restaurant-photos';
