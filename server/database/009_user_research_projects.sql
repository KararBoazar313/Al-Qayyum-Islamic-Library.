-- مكتبة القيّوم | مشاريع البحث الخاصة بكل حساب
BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS research_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title varchar(500) NOT NULL,
  description text NOT NULL DEFAULT '',
  project_type varchar(40) NOT NULL DEFAULT 'research' CHECK (project_type IN ('research','study','text_edition','evidence_comparison','reading_plan')),
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','paused','completed','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE research_projects
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES users(id) ON DELETE CASCADE;

UPDATE research_projects
SET user_id = owner_user_id
WHERE user_id IS NULL;

ALTER TABLE research_projects
ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE research_projects
ADD COLUMN IF NOT EXISTS project_type varchar(40) NOT NULL DEFAULT 'research';
CREATE INDEX IF NOT EXISTS idx_research_projects_user_updated ON research_projects(user_id,updated_at DESC);
COMMIT;
