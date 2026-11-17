#!/usr/bin/env python3
"""Conservative duplicate candidate detector. Never merges records."""
import argparse,csv,json,re,unicodedata
from collections import defaultdict

def clean(s):
 s=unicodedata.normalize('NFKC',str(s or '')).lower();s=re.sub(r'[\u064b-\u065f\u0670ـ]','',s);s=re.sub(r'[إأآٱ]','ا',s);s=re.sub(r'[^\w\u0600-\u06ff]+',' ',s);return ' '.join(s.split())
def main():
 p=argparse.ArgumentParser();p.add_argument('csv');p.add_argument('--out',required=True);a=p.parse_args(); rows=list(csv.DictReader(open(a.csv,encoding='utf-8-sig'))); buckets=defaultdict(list)
 for i,r in enumerate(rows):
  title=clean(r.get('title_ar') or r.get('title_original')); author=clean(r.get('author_name'))
  if title:buckets[(title,author)].append(i)
 groups=[]
 for key,idx in buckets.items():
  if len(idx)>1:
   editions=[{'row':i+2,'record_id':rows[i].get('record_id'),'edition':rows[i].get('edition'),'year':rows[i].get('publication_year'),'isbn':rows[i].get('isbn')} for i in idx]
   groups.append({'normalized_title':key[0],'normalized_author':key[1],'candidates':editions,'decision':'human_review_required','merge_automatically':False})
 with open(a.out,'w',encoding='utf-8') as f:json.dump({'candidate_groups':groups,'records':len(rows),'automatic_merges':0},f,ensure_ascii=False,indent=2)
 print(json.dumps({'records':len(rows),'candidate_groups':len(groups),'automatic_merges':0},ensure_ascii=False))
if __name__=='__main__':main()
