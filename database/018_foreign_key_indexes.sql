-- Qayyum Library: ensure every foreign key in the private application schema
-- has a supporting index. This is additive and idempotent.
-- The application connects through its trusted server, not from the browser.
BEGIN;
DO $$
DECLARE
  r record;
  idx_name text;
  col_list text;
BEGIN
  FOR r IN
    SELECT c.conname, c.conrelid, c.conkey, t.relname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE c.contype = 'f'
      AND n.nspname = 'qayyum'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid = c.conrelid
          AND i.indisvalid
          AND i.indisready
          AND i.indnkeyatts >= cardinality(c.conkey)
          AND (i.indkey::smallint[])[0:cardinality(c.conkey)-1] = c.conkey
      )
  LOOP
    SELECT string_agg(format('%I', a.attname), ', ' ORDER BY k.ord)
      INTO col_list
    FROM unnest(r.conkey) WITH ORDINALITY k(attnum, ord)
    JOIN pg_attribute a
      ON a.attrelid = r.conrelid
     AND a.attnum = k.attnum;

    idx_name := 'idx_fk_' || left(r.relname, 24) || '_' || substr(md5(r.conname), 1, 8);
    EXECUTE format(
      'CREATE INDEX IF NOT EXISTS %I ON %I.%I (%s)',
      idx_name, 'qayyum', r.relname, col_list
    );
  END LOOP;
END
$$;
COMMIT;
