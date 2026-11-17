import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';
const root=path.resolve(import.meta.dirname||'.','..');
test('server enforces JWT secret configuration',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/JWT_SECRET.*length<32/)});
test('private uploads are quarantined and rights default to hold',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/PRIVATE_STORAGE_DIR/);assert.match(s,/unknown','unknown','hold/);assert.match(s,/private_file_objects/)});
test('notes are owner scoped and private by default',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/WHERE user_id=\$1/);assert.match(s,/visibility[\s\S]*private/)});

test('file distribution requires a recorded license URL and reviewer decision',()=>{const sql=fs.readFileSync(path.join(root,'database/005_complete_catalog_workflows.sql'),'utf8');assert.match(sql,/license_url IS NOT NULL/);assert.match(sql,/reviewer_id IS NOT NULL/);assert.match(sql,/approve_distribution/)});
test('import API stages drafts and never publishes automatically',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/batch_staged/);assert.match(s,/publicationStatus:'draft'/);assert.match(s,/published:0/)});


test('calendar suggestions require review and owner-only publication',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/api\/calendar\/events\/suggest/);assert.match(s,/owner_approval_queue/);assert.match(s,/owner_approval_required/);assert.match(s,/publication_status='published'/)});
test('notifications are user-scoped and support read state',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/FROM qayyum\.notifications WHERE user_id=\$1/);assert.match(s,/UPDATE qayyum\.notifications SET read_at/);assert.match(s,/api\/notifications\/read-all/)});
test('calendar and notification preferences are persisted per account',()=>{const s=fs.readFileSync(path.join(root,'server/src/index.js'),'utf8');assert.match(s,/user_platform_preferences/);assert.match(s,/notification_preferences/);assert.match(s,/api\/preferences\/platform/)});
