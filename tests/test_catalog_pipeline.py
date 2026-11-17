import csv,json,subprocess,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class PipelineTests(unittest.TestCase):
 def setUp(self): self.t=tempfile.TemporaryDirectory(); self.d=Path(self.t.name)
 def tearDown(self): self.t.cleanup()
 def runpy(self,script,*args): return subprocess.run([sys.executable,str(ROOT/'tools'/script),*map(str,args)],capture_output=True,text=True,check=True)
 def readrow(self,p):
  with p.open(encoding='utf-8-sig') as f:return next(csv.DictReader(f))
 def test_openlibrary_adapter_and_provenance(self):
  src=self.d/'in.csv';src.write_text('key,title,author_name,language\n/books/OL1W,عنوان,مؤلف,ara\n',encoding='utf8');out=self.d/'out.csv';raw=self.d/'raw.jsonl'
  self.runpy('adapt_catalog_source.py',src,'--source','openlibrary','--out',out,'--raw',raw);r=self.readrow(out)
  self.assertEqual(r['source_id'],'SRC007');self.assertIn('sha256',r['notes']);self.assertTrue(raw.exists())
 def test_archive_adapter_never_assumes_rights(self):
  src=self.d/'in.csv';src.write_text('identifier,title,creator\nabc,Book,Author\n');out=self.d/'out.csv';raw=self.d/'raw'
  self.runpy('adapt_catalog_source.py',src,'--source','archive','--out',out,'--raw',raw);r=self.readrow(out)
  self.assertEqual(r['verification_status'],'Unverified');self.assertEqual(r['license'],'')
 def test_duplicate_candidates_not_merged(self):
  src=self.d/'in.csv';src.write_text('record_id,title_ar,author_name,edition,publication_year\n1,الكافي,الكليني,1,1407\n2,الكافي,الكليني,2,1407\n',encoding='utf8');out=self.d/'dups.json'
  self.runpy('match_catalog_editions.py',src,'--out',out);r=json.loads(out.read_text());self.assertEqual(r['automatic_merges'],0);self.assertEqual(len(r['candidate_groups']),1)
 def test_same_title_different_authors_not_grouped(self):
  src=self.d/'authors.csv';src.write_text('record_id,title_ar,author_name\n1,الكتاب,المؤلف الأول\n2,الكتاب,المؤلف الثاني\n',encoding='utf8');out=self.d/'dups.json'
  self.runpy('match_catalog_editions.py',src,'--out',out);self.assertEqual(json.loads(out.read_text())['candidate_groups'],[])
 def test_rights_gate_blocks_missing_proof(self):
  src=self.d/'rights.csv';src.write_text('record_id,rights_status,license_name,license_url,license_text,access_status,decision,reviewer,reviewed_at\n1,licensed,,,,open_access,approve_distribution,Admin,2026-01-01\n');out=self.d/'rights.json'
  self.runpy('review_workflow.py',src,'--out',out);self.assertFalse(json.loads(out.read_text())['rows'][0]['publishable'])
 def test_rights_gate_accepts_documented_review(self):
  src=self.d/'rights.csv';src.write_text('record_id,rights_status,license_name,license_url,license_text,access_status,decision,reviewer,reviewed_at\n1,licensed,CC BY 4.0,https://creativecommons.org/licenses/by/4.0/,License text,open_access,approve_distribution,Reviewer,2026-01-01\n');out=self.d/'rights.json'
  self.runpy('review_workflow.py',src,'--out',out);self.assertTrue(json.loads(out.read_text())['rows'][0]['publishable'])
 def test_import_batch_idempotency_duplicates_rejected(self):
  src=self.d/'batch.csv';src.write_text('record_id,title_ar,author_name,language,source_id,source_record_id,verification_status\n1,كتاب,مؤلف,ar,SRC1,x,unverified\n2,كتاب,مؤلف,ar,SRC1,x,unverified\n');out=self.d/'batch.json'
  self.runpy('import_batch.py',src,'--out',out,'--dry-run');r=json.loads(out.read_text());self.assertEqual(r['staged'],1);self.assertEqual(r['rejected'],1);self.assertFalse(r['published'])
 def test_large_batch_performance(self):
  src=self.d/'large.csv'
  with src.open('w') as f:
   f.write('record_id,title_ar,author_name,language,source_id,source_record_id,verification_status\n')
   for i in range(10000):f.write(f'{i},عنوان {i},مؤلف,ar,SRC1,{i},unverified\n')
  out=self.d/'large.json';self.runpy('import_batch.py',src,'--out',out,'--dry-run');self.assertEqual(json.loads(out.read_text())['staged'],10000)
 def test_required_fields_constant(self):
  from importlib.util import spec_from_file_location,module_from_spec
  spec=spec_from_file_location('validator',ROOT/'tools_validate_catalog.py');m=module_from_spec(spec);spec.loader.exec_module(m)
  self.assertTrue({'author_name','language','source_id','source_record_id','verification_status'}.issubset(set(m.REQUIRED)))
if __name__=='__main__':unittest.main()
