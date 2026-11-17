import 'dotenv/config';
const checks=[
 ['Node.js >=20',Number(process.versions.node.split('.')[0])>=20],
 ['DATABASE_URL configured',Boolean(process.env.DATABASE_URL)],
 ['JWT_SECRET >=32 chars',Boolean(process.env.JWT_SECRET&&process.env.JWT_SECRET.length>=32)],
 ['CORS_ORIGIN explicitly configured',Boolean(process.env.CORS_ORIGIN)],
 ['PRIVATE_STORAGE_DIR configured',Boolean(process.env.PRIVATE_STORAGE_DIR)],
 ['HTTPS public origin',/^https:\/\//.test(process.env.PUBLIC_BASE_URL||'')],
 ['PGSSL enabled for remote database',process.env.DATABASE_URL?.includes('localhost')||process.env.DATABASE_URL?.includes('127.0.0.1')||process.env.PGSSL==='true']
];
for(const [name,ok] of checks) console.log(`${ok?'PASS':'FAIL'} ${name}`);
if(checks.some(([,ok])=>!ok)){console.error('Preflight blocked: resolve every FAIL before production.');process.exitCode=1}else console.log('Preflight passed. This checks configuration only; it does not prove database or mail connectivity.');
