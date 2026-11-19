BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS manuscript_witnesses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), project_id uuid NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
 source_id uuid REFERENCES research_sources(id) ON DELETE SET NULL,
 repository varchar(300) NOT NULL DEFAULT '', shelfmark varchar(300) NOT NULL,
 manuscript_date varchar(160) NOT NULL DEFAULT '', script_description varchar(300) NOT NULL DEFAULT '',
 notes text NOT NULL DEFAULT '', created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_manuscript_witnesses_project ON manuscript_witnesses(project_id,created_at);
CREATE TABLE IF NOT EXISTS manuscript_variants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), witness_id uuid NOT NULL REFERENCES manuscript_witnesses(id) ON DELETE CASCADE,
 section_id uuid REFERENCES research_sections(id) ON DELETE SET NULL,
 locator varchar(300) NOT NULL DEFAULT '', reading text NOT NULL,
 editorial_note text NOT NULL DEFAULT '', review_status varchar(20) NOT NULL DEFAULT 'unreviewed' CHECK(review_status IN ('unreviewed','reviewed','accepted','rejected')),
 created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_manuscript_variants_witness ON manuscript_variants(witness_id,created_at);
COMMIT;
