import 'dotenv/config';
import pg from 'pg';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const {Pool}=pg;
if(!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
const pool=new Pool({connectionString:process.env.DATABASE_URL,ssl:process.env.PGSSL==='true'?{rejectUnauthorized:true}:undefined});
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../database');
const files=(await fs.readdir(root)).filter(x=>/^\d{3}_.+\.sql$/.test(x)).sort();
const client=await pool.connect();
try {
  await client.query('CREATE SCHEMA IF NOT EXISTS qayyum');
  await client.query('CREATE TABLE IF NOT EXISTS qayyum.schema_migrations(version text PRIMARY KEY, filename text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())');
  for(const filename of files){
    const version=filename.slice(0,3);
    const done=await client.query('SELECT 1 FROM qayyum.schema_migrations WHERE version=$1',[version]);
    if(done.rowCount){console.log(`SKIP ${filename}`);continue}
    const raw=await fs.readFile(path.join(root,filename),'utf8');
    // Migration files are also usable manually and contain their own outer BEGIN/COMMIT.
    // Remove only those wrappers here so the migration and its ledger row commit atomically.
    const sql=raw.replace(/(^|\n)\s*BEGIN\s*;\s*/i,'$1').replace(/\n\s*COMMIT\s*;?\s*$/i,'\n');
    await client.query('BEGIN');
    try { await client.query(sql); await client.query('INSERT INTO qayyum.schema_migrations(version,filename) VALUES($1,$2)',[version,filename]); await client.query('COMMIT'); console.log(`APPLIED ${filename}`); }
    catch(error){await client.query('ROLLBACK');throw new Error(`Migration ${filename} failed: ${error.message}`,{cause:error})}
  }
  console.log(`Migration check complete (${files.length} files discovered).`);
} finally {client.release();await pool.end()}
