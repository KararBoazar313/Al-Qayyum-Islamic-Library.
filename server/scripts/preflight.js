import 'dotenv/config';
const s3Names=['S3_ENDPOINT','S3_REGION','S3_BUCKET','S3_ACCESS_KEY_ID','S3_SECRET_ACCESS_KEY'];
const s3Count=s3Names.filter(name=>Boolean(process.env[name])).length;
const hasS3=s3Count===s3Names.length;
const hasRapidfile=Boolean(process.env.RAPIDFILE_SECRET_KEY);
const hasPersistentLocal=process.env.PRIVATE_STORAGE_PERSISTENT==='true'&&Boolean(process.env.PRIVATE_STORAGE_DIR);
const storageProviderValid=!(hasRapidfile&&s3Count>0)&&!(s3Count>0&&!hasS3);
const checks=[
 ['Node.js >=20',Number(process.versions.node.split('.')[0])>=20],
 ['DATABASE_URL configured',Boolean(process.env.DATABASE_URL)],
 ['JWT_SECRET >=32 chars',Boolean(process.env.JWT_SECRET&&process.env.JWT_SECRET.length>=32)],
 ['CORS_ORIGIN explicitly configured',Boolean(process.env.CORS_ORIGIN)],
 ['Durable private storage provider configured',storageProviderValid&&(hasS3||hasRapidfile||hasPersistentLocal)],
 ['HTTPS public origin',/^https:\/\//.test(process.env.PUBLIC_BASE_URL||'')],
 ['PGSSL enabled for remote database',process.env.DATABASE_URL?.includes('localhost')||process.env.DATABASE_URL?.includes('127.0.0.1')||process.env.PGSSL==='true']
];
for(const [name,ok] of checks) console.log(`${ok?'PASS':'FAIL'} ${name}`);
if(checks.some(([,ok])=>!ok)){console.error('Preflight blocked: resolve every FAIL before production.');process.exitCode=1}else console.log('Preflight passed. This checks configuration only; it does not prove database or mail connectivity.');
