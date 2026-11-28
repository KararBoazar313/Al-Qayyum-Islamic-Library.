import 'dotenv/config';
import pg from 'pg';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const {Pool}=pg;
if(!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

const databaseUrl=new URL(process.env.DATABASE_URL);
for(const key of ['sslmode','sslrootcert','sslcert','sslkey']) databaseUrl.searchParams.delete(key);
const pool=new Pool({
  connectionString:databaseUrl.toString(),
  ssl:process.env.PGSSL==='true'
    ? {ca:process.env.SUPABASE_CA_CERT||undefined,rejectUnauthorized:true}
    : undefined,
  connectionTimeoutMillis:10000,
  idleTimeoutMillis:30000,
  keepAlive:true,
  max:2
});

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../database');
const files=(await fs.readdir(root)).filter(x=>/^\d{3}_.+\.sql$/.test(x)).sort();

// These files belong to an older, parallel hadith/manuscript model that is not
// referenced by the current API. The collation file also collides with the
// applied manuscript-registry version 012. Keep them in source control for
// historical reference, but never apply them automatically.
const skippedLegacy=new Set([
  '012_manuscript_collation.sql',
  '013_hadith_corpus.sql',
  '014_narrators_isnad.sql',
  '015_scientific_review_workflows.sql',
  '016_research_quality_indexes.sql',
  '017_hadith_workspace_indexes.sql'
]);

const client=await pool.connect();
try {
  await client.query('CREATE SCHEMA IF NOT EXISTS qayyum');
  await client.query('CREATE TABLE IF NOT EXISTS qayyum.schema_migrations(version text PRIMARY KEY, filename text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())');

  const seenVersions=new Map();
  for(const filename of files){
    if(skippedLegacy.has(filename)){
      console.log(`SKIP legacy/unintegrated migration ${filename}`);
      continue;
    }

    const version=filename.slice(0,3);
    const previous=seenVersions.get(version);
    if(previous) throw new Error(`Duplicate migration version ${version}: ${previous} and ${filename}`);
    seenVersions.set(version,filename);

    const done=await client.query('SELECT 1 FROM qayyum.schema_migrations WHERE version=$1',[version]);
    if(done.rowCount){
      console.log(`SKIP applied migration ${filename}`);
      continue;
    }

    const raw=await fs.readFile(path.join(root,filename),'utf8');
    // Migration files are also usable manually and contain their own outer BEGIN/COMMIT.
    // Remove only those wrappers here so the migration and its ledger row commit atomically.
    const sql=raw.replace(/(^|\n)\s*BEGIN\s*;\s*/i,'$1').replace(/\n\s*COMMIT\s*;?\s*$/i,'\n');
    await client.query('BEGIN');
    try {
      await client.query(sql);
      await client.query('INSERT INTO qayyum.schema_migrations(version,filename) VALUES($1,$2)',[version,filename]);
      await client.query('COMMIT');
      console.log(`APPLIED ${filename}`);
    } catch(error) {
      await client.query('ROLLBACK');
      throw new Error(`Migration ${filename} failed: ${error.message}`,{cause:error});
    }
  }
  console.log(`Migration check complete (${files.length} files discovered).`);
} finally {
  client.release();
  await pool.end();
}
