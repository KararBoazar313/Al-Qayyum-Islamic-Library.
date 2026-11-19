BEGIN;
SET search_path TO qayyum, public;
CREATE INDEX IF NOT EXISTS idx_hadith_records_review ON hadith_records(review_status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hadith_collections_project ON hadith_collections(research_project_id) WHERE research_project_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_isnad_nodes_narrator ON hadith_isnad_nodes(narrator_id) WHERE narrator_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_review_log_reviewer ON scientific_review_log(reviewer_user_id,created_at DESC);
COMMIT;
