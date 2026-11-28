BEGIN;
SET search_path TO qayyum, public;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS cover_mime_type VARCHAR(80);
COMMIT;
