#!/usr/bin/env python3
"""Rights and bibliographic review gate for import rows."""
import argparse,csv,json
from datetime import date
REQUIRED=['rights_status','access_status','decision','reviewer','reviewed_at']
ALLOWED={'rights_status':{'public_domain','licensed','reading_only','permission_required','unknown','prohibited'},'access_status':{'metadata_only','open_access','controlled','restricted','unknown'},'decision':{'approve_metadata_only','approve_reading','approve_distribution','reject','hold'}}
def publishable(r):
 expires=r.get('expires_at','').strip()
 if expires:
  try:
   if date.fromisoformat(expires)<date.today(): return False
  except ValueError: return False
 if r.get('decision')=='approve_distribution': return r.get('rights_status') in {'public_domain','licensed'} and bool(r.get('license_name')) and bool(r.get('license_url')) and bool(r.get('license_text')) and bool(r.get('reviewer')) and bool(r.get('reviewed_at'))
 if r.get('decision')=='approve_reading': return r.get('rights_status') in {'public_domain','licensed','reading_only'} and bool(r.get('license_url')) and bool(r.get('reviewer')) and bool(r.get('reviewed_at'))
 return r.get('decision')=='approve_metadata_only' and bool(r.get('reviewer')) and bool(r.get('reviewed_at'))
def main():
 p=argparse.ArgumentParser();p.add_argument('input');p.add_argument('--out',required=True);a=p.parse_args();rows=list(csv.DictReader(open(a.input,encoding='utf-8-sig')));results=[]
 for i,r in enumerate(rows,2):
  missing=[k for k in REQUIRED if not r.get(k)]
  if r.get('decision')=='approve_distribution': missing += [k for k in ['license_name','license_url','license_text'] if not r.get(k)]
  if r.get('decision')=='approve_reading' and not r.get('license_url'): missing.append('license_url')
  invalid=[k for k,v in ALLOWED.items() if r.get(k) and r[k] not in v]
  ok=not missing and not invalid and publishable(r)
  results.append({'row':i,'record_id':r.get('record_id'),'status':'approved_for_requested_scope' if ok else 'blocked_pending_review','missing':missing,'invalid':invalid,'publishable':ok})
 with open(a.out,'w',encoding='utf-8') as f:json.dump({'rows':results,'approved':sum(x['publishable'] for x in results),'blocked':sum(not x['publishable'] for x in results),'rule':'No full-text distribution without documented rights evidence and named human review.'},f,ensure_ascii=False,indent=2)
 print(json.dumps({'rows':len(rows),'approved':sum(x['publishable'] for x in results),'blocked':sum(not x['publishable'] for x in results)},ensure_ascii=False))
if __name__=='__main__':main()
