#!/usr/bin/env python3
"""Normalize Open Library, Internet Archive, OpenITI TSV/CSV and canonical CSV into Qayyum schema."""
import argparse,csv,hashlib,json,re,sys
from pathlib import Path
FIELDS=['record_id','title_ar','title_original','title_alt','author_name','author_death_year_hijri','editor','translator','publisher','publication_place','publication_year','edition','volume_count','language','school_family','madhhab','subject_main','subject_sub','book_type','period','manuscript_or_print','isbn','oclc','openiti_uri','archive_identifier','catalogue_record_url','full_text_url','pdf_url','file_format','access_status','license','source_id','source_record_id','verification_status','duplicate_group_id','notes']
def pick(d,*keys):
 for k in keys:
  v=d.get(k)
  if v not in (None,'',[]): return v
 return ''
def arabic_text(value): return bool(re.search(r'[\u0600-\u06ff]',str(value or '')))
def norm(raw,source):
 if source=='openlibrary':
  key=pick(raw,'key'); title=pick(raw,'title'); authors=pick(raw,'author_name','authors')
  return dict(record_id=key, title_ar=title if arabic_text(title) else '', title_original=title, author_name='; '.join(authors) if isinstance(authors,list) else authors, language=';'.join((pick(raw,'language') if isinstance(pick(raw,'language'),list) else [pick(raw,'language')])), isbn=';'.join((pick(raw,'isbn') if isinstance(pick(raw,'isbn'),list) else [pick(raw,'isbn')])), catalogue_record_url=('https://openlibrary.org'+key if key.startswith('/') else ''), source_id='SRC007',source_record_id=key,verification_status='Unverified',notes='Open Library metadata; verify all claims and rights.')
 if source=='archive':
  ident=pick(raw,'identifier'); md=raw.get('metadata',raw)
  title=pick(md,'title')
  return dict(record_id=ident,title_ar=title if arabic_text(title) else '',title_original=title,author_name=pick(md,'creator'),publication_year=pick(md,'year'),language=pick(md,'language'),archive_identifier=ident,catalogue_record_url=('https://archive.org/details/'+ident if ident else ''),source_id='SRC003',source_record_id=ident,verification_status='Unverified',notes='Internet Archive metadata; item-level rights and access must be reviewed.')
 if source=='openiti':
  title=pick(raw,'title','book','book_name','title_ar'); author=pick(raw,'author','author_name')
  return dict(record_id=pick(raw,'URI','uri','id'),title_ar=title if arabic_text(title) else '',title_original=title,author_name=author,language='ar',openiti_uri=pick(raw,'URI','uri'),source_id='SRC001',source_record_id=pick(raw,'URI','uri','id'),verification_status='Unverified',notes='OpenITI record; verify version-specific license.')
 return {k:pick(raw,k) for k in FIELDS}
def main():
 p=argparse.ArgumentParser();p.add_argument('input');p.add_argument('--source',choices=['canonical','openlibrary','archive','openiti'],default='canonical');p.add_argument('--out',required=True);p.add_argument('--raw',required=True);a=p.parse_args()
 path=Path(a.input); rawbytes=path.read_bytes(); digest=hashlib.sha256(rawbytes).hexdigest(); delim='\t' if path.suffix.lower()=='.tsv' else ','
 with path.open(encoding='utf-8-sig',newline='') as f: rows=list(csv.DictReader(f,delimiter=delim))
 out=[]; errors=[]
 for i,r in enumerate(rows,2):
  n=norm(r,a.source); n['record_id']=n.get('record_id') or f'{a.source}-{i}'; n['source_record_id']=n.get('source_record_id') or n['record_id']; n['source_id']=n.get('source_id') or {'openlibrary':'SRC007','archive':'SRC003','openiti':'SRC001','canonical':'UNSPECIFIED'}[a.source]
  if not n.get('title_ar') and not n.get('title_original'): errors.append({'line':i,'error':'missing title'})
  if not n.get('author_name'): errors.append({'line':i,'warning':'missing author; do not infer'})
  n['notes']=str(n.get('notes') or '')+f' | source_sha256={digest}'
  out.append(n)
 with open(a.out,'w',encoding='utf-8-sig',newline='') as f:
  w=csv.DictWriter(f,fieldnames=FIELDS);w.writeheader();w.writerows(out)
 with open(a.raw,'w',encoding='utf-8') as f:
  for r in rows:f.write(json.dumps({'source':a.source,'raw':r,'source_file_sha256':digest},ensure_ascii=False)+'\n')
 print(json.dumps({'records':len(out),'errors':errors,'source_file_sha256':digest,'output':a.out,'raw':a.raw},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
