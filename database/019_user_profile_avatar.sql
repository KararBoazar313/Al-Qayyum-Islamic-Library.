BEGIN;
SET search_path TO qayyum, public;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS avatar_mime_type VARCHAR(80);
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
COMMIT;
