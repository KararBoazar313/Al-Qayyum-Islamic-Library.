-- Link research bibliography entries to reviewed library editions.
BEGIN;
SET search_path TO qayyum, public;
ALTER TABLE research_sources
  ADD COLUMN IF NOT EXISTS edition_id uuid REFERENCES editions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_research_sources_edition ON research_sources(edition_id) WHERE edition_id IS NOT NULL;
COMMIT;
