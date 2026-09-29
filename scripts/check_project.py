from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1]
s=(root/'site/seed.js').read_text()
b=json.loads(s.split('window.BOOK_SEED=',1)[1].split(';\nwindow.BOOK_IMAGES=')[0])
assert len(b['chapters'])==35
ids=[c['id'] for c in b['chapters']]
assert len(set(ids))==35
blocks=[x for c in b['chapters'] for x in c['b']]
slots=[x[3] for x in blocks if x[0]=='m']
assert len(slots)==len(set(slots))==29
assert len(blocks)==786
assert 'Я люблю тебя.' in b['chapters'][-1]['markdown']
for a in b['assets']:
 assert (root/'site'/a['url']).is_file(),a['url']
 if a.get('stillId'):assert (root/'site'/a['stillId']).is_file(),a['stillId']
for f in ['index.html','admin.html']:
 for rel in re.findall(r'(?:src|href)="([^"#]+)"',(root/'site'/f).read_text()):
  assert (root/'site'/rel).exists(),rel
for f in ['original.css','enhanced.css']:
 for rel in re.findall(r'url\([\'\"]?([^\)\'\"]+)',(root/'site'/f).read_text()):
  if rel.startswith('assets/'):assert (root/'site'/rel).is_file(),rel
assert b['title']=='Та которую невозможно забыть'
assert sum(len(x['details']) for x in b['decorSequence'].values())==113
assert sum(len(x['bears']) for x in b['decorSequence'].values())==150
print('OK: 35 chapters, 786 blocks, 29 slots, all 263 supplied collection files and local resources.')
print('Canonical story SHA-256:',hashlib.sha256((root/'source/История.md').read_bytes()).hexdigest())
