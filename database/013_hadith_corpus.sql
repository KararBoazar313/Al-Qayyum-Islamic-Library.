BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS hadith_collections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 research_project_id uuid REFERENCES research_projects(id) ON DELETE CASCADE,
 title varchar(500) NOT NULL, school_label varchar(120) NOT NULL DEFAULT '', description text NOT NULL DEFAULT '',
 review_status varchar(20) NOT NULL DEFAULT 'private' CHECK(review_status IN ('private','submitted','approved','rejected')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hadith_collections_owner ON hadith_collections(owner_user_id,updated_at DESC);
CREATE TABLE IF NOT EXISTS hadith_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), collection_id uuid NOT NULL REFERENCES hadith_collections(id) ON DELETE CASCADE,
 record_number varchar(100) NOT NULL DEFAULT '', matn text NOT NULL,
 source_title varchar(700) NOT NULL DEFAULT '', volume_label varchar(100) NOT NULL DEFAULT '', page_label varchar(100) NOT NULL DEFAULT '',
 chapter_label varchar(300) NOT NULL DEFAULT '', grading_label varchar(120) NOT NULL DEFAULT 'غير محكوم عليه',
 researcher_note text NOT NULL DEFAULT '', review_status varchar(20) NOT NULL DEFAULT 'unreviewed' CHECK(review_status IN ('unreviewed','reviewed','approved','rejected')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hadith_records_collection ON hadith_records(collection_id,created_at DESC);
COMMIT;
