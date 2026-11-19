-- Qayyum Library: manuscript catalogue and provenance records
BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS manuscript_witnesses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title varchar(700) NOT NULL,
 author_name varchar(500),
 repository_name varchar(500) NOT NULL,
 collection_code varchar(200),
 shelfmark varchar(200),
 manuscript_date varchar(160),
 copyist_name varchar(300),
 language_code varchar(16) NOT NULL DEFAULT 'ar',
 folio_count varchar(80),
 description text,
 catalogue_url text,
 rights_status varchar(32) NOT NULL DEFAULT 'unknown_review' CHECK(rights_status IN ('public_domain','licensed_distribution','reading_only','special_permission','unknown_review','prohibited')),
 review_status varchar(24) NOT NULL DEFAULT 'pending' CHECK(review_status IN ('pending','approved','rejected')),
 created_by uuid REFERENCES users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_manuscript_witnesses_search ON manuscript_witnesses USING gin(to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(author_name,'') || ' ' || coalesce(repository_name,'') || ' ' || coalesce(shelfmark,'')));
CREATE INDEX IF NOT EXISTS idx_manuscript_witnesses_review ON manuscript_witnesses(review_status, created_at DESC);
COMMIT;
