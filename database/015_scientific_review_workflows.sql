BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS scientific_review_log (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reviewer_user_id uuid NOT NULL REFERENCES users(id),
 target_kind varchar(40) NOT NULL CHECK(target_kind IN ('manuscript_variant','hadith_record','narrator')),
 target_id uuid NOT NULL, decision varchar(30) NOT NULL CHECK(decision IN ('reviewed','accepted','rejected','disputed')),
 rationale text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_scientific_review_target ON scientific_review_log(target_kind,target_id,created_at DESC);
ALTER TABLE manuscript_variants ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
ALTER TABLE manuscript_variants ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES users(id);
ALTER TABLE hadith_records ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
ALTER TABLE hadith_records ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES users(id);
COMMIT;
