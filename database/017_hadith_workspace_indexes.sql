BEGIN;
SET search_path TO qayyum, public;
CREATE INDEX IF NOT EXISTS idx_hadith_collections_owner_updated
  ON hadith_collections(owner_user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_hadith_records_collection_created
  ON hadith_records(collection_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_narrators_creator_name
  ON narrators(created_by, canonical_name);
CREATE INDEX IF NOT EXISTS idx_isnad_chains_hadith_created
  ON hadith_isnad_chains(hadith_id, created_at);
COMMIT;
