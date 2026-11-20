-- Qayyum: reviewed catalog, rights, secure files, reader progress, private research, import audit.
-- PostgreSQL 16+. Run only after 001..004 in a configured test/production database.
BEGIN;
SET search_path TO qayyum, public;

CREATE TABLE IF NOT EXISTS author_identity_evidence (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), author_id UUID NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
 source_id UUID REFERENCES sources(id) ON DELETE SET NULL, evidence_text TEXT NOT NULL,
 confidence VARCHAR(20) NOT NULL DEFAULT 'unassessed' CHECK(confidence IN ('high','medium','low','disputed','unassessed')),
 reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL, reviewed_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS work_attribution_evidence (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
 author_id UUID REFERENCES authors(id) ON DELETE SET NULL, source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
 evidence_text TEXT NOT NULL, conclusion VARCHAR(24) NOT NULL DEFAULT 'unverified' CHECK(conclusion IN ('verified','attributed','disputed','anonymous','unverified')),
 reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL, reviewed_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS rights_reviews (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), file_id UUID REFERENCES digital_files(id) ON DELETE CASCADE,
 edition_id UUID REFERENCES editions(id) ON DELETE CASCADE, source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
 rights_status VARCHAR(32) NOT NULL CHECK(rights_status IN ('public_domain','licensed','reading_only','permission_required','unknown','prohibited')),
 license_name TEXT, license_url TEXT, license_text TEXT, rights_holder TEXT, access_status VARCHAR(24) NOT NULL CHECK(access_status IN ('metadata_only','open_access','controlled','restricted','unknown')),
 decision VARCHAR(32) NOT NULL DEFAULT 'hold' CHECK(decision IN ('approve_metadata_only','approve_reading','approve_distribution','reject','hold')),
 reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL, reviewed_at TIMESTAMPTZ, expires_at DATE, notes TEXT,
 CHECK(decision <> 'approve_distribution' OR (rights_status IN ('public_domain','licensed') AND license_name IS NOT NULL AND license_url IS NOT NULL AND license_text IS NOT NULL AND reviewer_id IS NOT NULL AND reviewed_at IS NOT NULL)),
 CHECK(decision <> 'approve_reading' OR (rights_status IN ('public_domain','licensed','reading_only') AND reviewer_id IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_rights_reviews_file ON rights_reviews(file_id, reviewed_at DESC);
CREATE TABLE IF NOT EXISTS private_file_objects (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), digital_file_id UUID NOT NULL UNIQUE REFERENCES digital_files(id) ON DELETE CASCADE,
 storage_key TEXT NOT NULL UNIQUE, uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL, detected_mime TEXT NOT NULL, sha256 CHAR(64) NOT NULL, size_bytes BIGINT NOT NULL CHECK(size_bytes>0),
 scan_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK(scan_status IN ('pending','clean','rejected','infected','error')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS reader_progress (
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, edition_id UUID NOT NULL REFERENCES editions(id) ON DELETE CASCADE,
 page_number INTEGER CHECK(page_number IS NULL OR page_number>0), cfi TEXT, progress_percent NUMERIC(5,2) CHECK(progress_percent BETWEEN 0 AND 100),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY(user_id,edition_id)
);
CREATE TABLE IF NOT EXISTS research_notes (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 work_id UUID REFERENCES works(id) ON DELETE SET NULL, edition_id UUID REFERENCES editions(id) ON DELETE SET NULL,
 note_kind VARCHAR(20) NOT NULL DEFAULT 'note' CHECK(note_kind IN ('note','quote','citation','research')), title TEXT, body TEXT NOT NULL,
 locator TEXT, visibility VARCHAR(16) NOT NULL DEFAULT 'private' CHECK(visibility IN ('private','shared','public')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_research_notes_owner ON research_notes(user_id,updated_at DESC);
CREATE TABLE IF NOT EXISTS import_batch_audit (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, batch_id UUID REFERENCES catalog_import_batches(id) ON DELETE CASCADE,
 actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL, event_code VARCHAR(48) NOT NULL,
 details JSONB NOT NULL DEFAULT '{}'::jsonb, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS import_idempotency (
 source_id BIGINT NOT NULL REFERENCES catalog_sources(id) ON DELETE RESTRICT, source_record_id VARCHAR(500) NOT NULL,
 payload_sha256 CHAR(64) NOT NULL, first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(), last_batch_id UUID REFERENCES catalog_import_batches(id) ON DELETE SET NULL,
 PRIMARY KEY(source_id,source_record_id)
);
CREATE INDEX IF NOT EXISTS idx_import_audit_batch ON import_batch_audit(batch_id,created_at);

-- Guard: a digital file is eligible for distribution only with a current explicit rights decision.
CREATE OR REPLACE FUNCTION qayyum.file_distribution_allowed(p_file UUID) RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
 SELECT EXISTS(SELECT 1 FROM rights_reviews r WHERE r.file_id=p_file AND r.decision='approve_distribution'
 AND r.rights_status IN ('public_domain','licensed') AND r.license_name IS NOT NULL AND r.license_url IS NOT NULL AND r.license_text IS NOT NULL
 AND r.reviewer_id IS NOT NULL AND r.reviewed_at IS NOT NULL AND (r.expires_at IS NULL OR r.expires_at>=CURRENT_DATE))
$$;
COMMIT;
