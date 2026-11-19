BEGIN;
SET search_path TO qayyum, public;
CREATE TABLE IF NOT EXISTS narrators (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), canonical_name varchar(500) NOT NULL,
 kunya varchar(300) NOT NULL DEFAULT '', nisba varchar(300) NOT NULL DEFAULT '',
 birth_death_text varchar(160) NOT NULL DEFAULT '', biography text NOT NULL DEFAULT '',
 evaluation_text text NOT NULL DEFAULT '', evaluation_source text NOT NULL DEFAULT '',
 review_status varchar(20) NOT NULL DEFAULT 'unverified' CHECK(review_status IN ('unverified','under_review','verified','disputed','rejected')),
 created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_narrators_name ON narrators(canonical_name);
CREATE TABLE IF NOT EXISTS hadith_isnad_chains (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), hadith_id uuid NOT NULL REFERENCES hadith_records(id) ON DELETE CASCADE,
 chain_label varchar(300) NOT NULL DEFAULT '', notes text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hadith_isnad_hadith ON hadith_isnad_chains(hadith_id);
CREATE TABLE IF NOT EXISTS hadith_isnad_nodes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), chain_id uuid NOT NULL REFERENCES hadith_isnad_chains(id) ON DELETE CASCADE,
 sequence_no integer NOT NULL CHECK(sequence_no > 0), narrator_id uuid REFERENCES narrators(id) ON DELETE SET NULL,
 transmitted_name varchar(500) NOT NULL, transmission_term varchar(160) NOT NULL DEFAULT '',
 notes text NOT NULL DEFAULT '', UNIQUE(chain_id,sequence_no)
);
COMMIT;
