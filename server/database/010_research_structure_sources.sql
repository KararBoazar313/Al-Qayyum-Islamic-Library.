-- Research outline, bibliography and revision history, scoped through project ownership.
BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS research_sections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), project_id uuid NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
 parent_id uuid REFERENCES research_sections(id) ON DELETE CASCADE,
 title varchar(500) NOT NULL, section_kind varchar(20) NOT NULL DEFAULT 'chapter' CHECK(section_kind IN ('chapter','section','topic')),
 sort_order integer NOT NULL DEFAULT 0, body text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_research_sections_project_order ON research_sections(project_id,sort_order,created_at);
CREATE TABLE IF NOT EXISTS research_sources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), project_id uuid NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
 source_kind varchar(30) NOT NULL DEFAULT 'book' CHECK(source_kind IN ('book','article','manuscript','website','archive','other')),
 title varchar(700) NOT NULL, author varchar(500) NOT NULL DEFAULT '', publisher varchar(500) NOT NULL DEFAULT '',
 edition varchar(300) NOT NULL DEFAULT '', volume_label varchar(100) NOT NULL DEFAULT '', page_label varchar(100) NOT NULL DEFAULT '',
 source_url text, accessed_on date, notes text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_research_sources_project ON research_sources(project_id,created_at DESC);
CREATE TABLE IF NOT EXISTS research_project_revisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), project_id uuid NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, revision_label varchar(300) NOT NULL,
 snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_research_revisions_project ON research_project_revisions(project_id,created_at DESC);
COMMIT;
