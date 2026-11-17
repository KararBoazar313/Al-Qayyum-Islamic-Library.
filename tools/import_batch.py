#!/usr/bin/env python3
"""Transactional staging importer: validates CSV and creates deterministic dry-run plan; never publishes."""
import argparse,csv,hashlib,json
REQ={'author_name','language','source_id','source_record_id','verification_status'}
def main():
 p=argparse.ArgumentParser();p.add_argument('csv');p.add_argument('--out',required=True);p.add_argument('--dry-run',action='store_true');a=p.parse_args();data=open(a.csv,'rb').read();rows=list(csv.DictReader(data.decode('utf-8-sig').splitlines()));seen=set();items=[]
 for n,r in enumerate(rows,2):
  missing=sorted(k for k in REQ if not r.get(k))
  if not (r.get('title_ar') or r.get('title_original')): missing.append('title_ar_or_title_original')
  key=(r.get('source_id'),r.get('source_record_id'));dup=key in seen;seen.add(key)
  items.append({'line':n,'record_id':r.get('record_id'),'errors':missing+(['duplicate source identity'] if dup else []),'action':'reject' if missing or dup else 'stage_for_human_review'})
 report={'batch_sha256':hashlib.sha256(data).hexdigest(),'total':len(rows),'staged':sum(x['action']=='stage_for_human_review' for x in items),'rejected':sum(x['action']=='reject' for x in items),'dry_run':True,'published':False,'records':items}
 open(a.out,'w',encoding='utf-8').write(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:report[k] for k in ['total','staged','rejected','published']}))
if __name__=='__main__':main()
