BEGIN;
SET search_path TO qayyum, public;
ALTER TABLE research_sources
  ADD COLUMN IF NOT EXISTS catalog_work_id uuid REFERENCES works(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS catalog_edition_id uuid REFERENCES editions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_research_sources_catalog_work ON research_sources(catalog_work_id) WHERE catalog_work_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_research_sources_catalog_edition ON research_sources(catalog_edition_id) WHERE catalog_edition_id IS NOT NULL;
COMMIT;
