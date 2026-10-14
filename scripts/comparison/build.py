#!/usr/bin/env python3
"""Build the offline review. Pillow required; inputs are native captures, never generated UI.
Usage: python build.py --inputs /tmp/wp-all-screens-20261014
Historical input paths are capture provenance from the 2026-10-14 comparison session.
"""
from pathlib import Path
from io import BytesIO
import argparse, json, re, hashlib, shutil
from datetime import datetime
from zoneinfo import ZoneInfo
from PIL import Image, ImageCms
from catalog import CASES
p=argparse.ArgumentParser();p.add_argument('--inputs',type=Path,required=True);p.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[2]/'docs/all-screen-comparison-20261014');args=p.parse_args()
root=args.inputs;out=args.out; (out/'images').mkdir(parents=True,exist_ok=True)
ios=json.loads((root/'ios-existing.json').read_text())
# Explicit final invitation captures override exploratory/before captures.
folders=[Path('/tmp/wp-invitation-compare-20261014')/x for x in ['complete-shots','last-shots','editor-shots']]
folders+=sorted(root.glob('*-shots'),key=lambda p:p.stat().st_mtime)
for folder in folders:
    if not (folder/'manifest.json').exists():continue
    for test in json.loads((folder/'manifest.json').read_text()):
        for a in test['attachments']:
            if not a['exportedFileName'].endswith('.png'):continue
            name=a['suggestedHumanReadableName'].split('_0_')[0]
            ios[name]={'path':str(folder/a['exportedFileName']),'test':test.get('testName',test.get('testIdentifier','')), 'run':folder.name}
android={}
for folder in [Path('/tmp/wp-invitation-compare-20261014/android/files/shots'),Path('/tmp/wp-pass-parity-20261014/files/shots'),root/'android/files/shots']:
    if folder.exists():
        for f in folder.glob('*.png'): android[f.stem]={'path':str(f),'run':'current-20261014' if f.stat().st_mtime >= datetime(2026,10,14,13,26,tzinfo=ZoneInfo('Asia/Seoul')).timestamp() else 'earlier-20261014'}
cache={}
def convert(entry,platform,name):
    if not entry:return None
    path=Path(entry['path'])
    if not path.exists():return None
    dest='images/'+platform+'-'+name+'.webp'
    if dest not in cache:
        im=Image.open(path);icc=im.info.get('icc_profile');im=im.convert('RGB')
        if icc:im=ImageCms.profileToProfile(im,ImageCms.ImageCmsProfile(BytesIO(icc)),ImageCms.createProfile('sRGB'))
        original=im.size
        valid = False
        if (out/dest).exists():
            try:
                with Image.open(out/dest) as saved:
                    saved.verify()
                valid = True
            except Exception:
                valid = False
        if not valid or (out/dest).stat().st_mtime < path.stat().st_mtime:
            im.thumbnail((390,10000),Image.Resampling.LANCZOS)
            im.save(out/(dest+'.tmp'),format='WEBP',lossless=True,method=1)
            (out/(dest+'.tmp')).replace(out/dest)
        cache[dest]={'src':dest,'width':original[0],'height':original[1], 'name':name,'run':entry.get('run','earlier-20261014'),'test':entry.get('test',''),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    return cache[dest]
rows=[]
for c in CASES:
    row=c.copy();a=c['android'];i=c['ios']
    row['android']=convert(android.get(a),'android',a) if a else None
    row['ios']=convert(ios.get(i),'ios',i) if i else None
    row['capture']='양쪽 캡처' if row['android'] and row['ios'] else '한쪽 캡처' if row['android'] or row['ios'] else '미캡처'
    row['fixture']='동일 데이터' if row['same'] else '상태·데이터 차이 있음'
    row['status']='차이 확인' if row['issue'] else '대조 가능' if row['capture']=='양쪽 캡처' else '추가 검증 필요'
    if i and not row['ios']:row['note']+=' iOS 해당 상태의 유효 캡처가 아직 없다.'
    if a and not row['android']:row['note']+=' Android 해당 상태의 유효 캡처가 아직 없다.'
    rows.append(row)
# Time-series are a separate review mode, not frame-synchronized parity evidence.
motion=[]
for platform,index,prefix in [('android',android,'garden-landing-drop-'),('ios',ios,'matched-garden-flight-')]:
    frames=[]
    for key in sorted(index):
        if key.startswith(prefix):
            entry=convert(index[key],platform,key)
            if entry:frames.append(entry)
    motion.append({'platform':platform,'frames':frames})
summary={'total':len(rows),'paired':sum(r['capture']=='양쪽 캡처' for r in rows),'single':sum(r['capture']=='한쪽 캡처' for r in rows),'missing':sum(r['capture']=='미캡처' for r in rows),'sameFixture':sum(r['same'] and r['capture']=='양쪽 캡처' for r in rows),'issues':sum(r['issue'] for r in rows)}
tests=json.loads((root/'verification.json').read_text()) if (root/'verification.json').exists() else {'note':'검증 결과 수집 중'}
data={'created':'2026-10-14','androidRevision':'9a6e1c2','iosBaseRevision':'814defc','summary':summary,'cases':rows,'motion':motion,'verification':tests}
(out/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
template=Path(__file__).with_name('template.html').read_text()
(out/'index.html').write_text(template.replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\\/')))
print(json.dumps(summary,ensure_ascii=False)); print(out/'index.html')
