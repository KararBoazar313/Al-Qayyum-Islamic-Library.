-- Qayyum Phase 1: bibliographic identity, edition metadata and private provenance.
-- Run after migrations 001-005. Provenance is retained for audit; public catalog APIs must not expose provider branding.
BEGIN;
SET search_path TO qayyum, public;

ALTER TABLE works
  ADD COLUMN IF NOT EXISTS alternate_titles TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS work_type VARCHAR(80),
  ADD COLUMN IF NOT EXISTS subject_summary TEXT,
  ADD COLUMN IF NOT EXISTS identity_review_status VARCHAR(24) NOT NULL DEFAULT 'pending'
    CHECK (identity_review_status IN ('pending','verified','disputed','rejected'));

ALTER TABLE editions
  ADD COLUMN IF NOT EXISTS publication_place VARCHAR(240),
  ADD COLUMN IF NOT EXISTS translator_name VARCHAR(300),
  ADD COLUMN IF NOT EXISTS printer_name VARCHAR(300),
  ADD COLUMN IF NOT EXISTS series_title VARCHAR(300),
  ADD COLUMN IF NOT EXISTS source_language VARCHAR(16),
  ADD COLUMN IF NOT EXISTS digital_format VARCHAR(16),
  ADD COLUMN IF NOT EXISTS digital_access_status VARCHAR(24) NOT NULL DEFAULT 'metadata_only'
    CHECK (digital_access_status IN ('metadata_only','reading_only','downloadable','restricted','unknown'));

-- Private audit trail: one work or edition may have several catalogue records.
CREATE TABLE IF NOT EXISTS work_provenance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
  edition_id UUID REFERENCES editions(id) ON DELETE CASCADE,
  catalog_source_id BIGINT REFERENCES catalog_sources(id) ON DELETE RESTRICT,
  source_record_id VARCHAR(500) NOT NULL,
  source_record_url TEXT,
  source_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_checksum CHAR(64),
  imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
  verified_at TIMESTAMPTZ,
  verification_note TEXT,
  UNIQUE(catalog_source_id, source_record_id, work_id, edition_id)
);
CREATE INDEX IF NOT EXISTS idx_work_provenance_work ON work_provenance(work_id);
CREATE INDEX IF NOT EXISTS idx_work_provenance_edition ON work_provenance(edition_id) WHERE edition_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_work_provenance_source_record ON work_provenance(catalog_source_id, source_record_id);

-- Public-facing rights/access decisions are distinct from the internal discovery source.
CREATE TABLE IF NOT EXISTS edition_access_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  edition_id UUID NOT NULL REFERENCES editions(id) ON DELETE CASCADE,
  digital_file_id UUID REFERENCES digital_files(id) ON DELETE SET NULL,
  access_mode VARCHAR(24) NOT NULL CHECK (access_mode IN ('onsite_reader','download','metadata_only','external_embed')),
  rights_review_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (access_mode <> 'external_embed' OR is_active = FALSE)
);
CREATE INDEX IF NOT EXISTS idx_edition_access_active ON edition_access_options(edition_id) WHERE is_active = TRUE;

COMMIT;
