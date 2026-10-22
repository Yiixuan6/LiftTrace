"""Guarded native screenshots of QA tab transitions; no screenrecord needed."""
from pathlib import Path
import subprocess, re, time, xml.etree.ElementTree as ET, json
from PIL import Image, ImageDraw, ImageStat, ImageChops
root=Path(__file__).resolve().parents[1]
adb=str(root/'.tooling/android-sdk/platform-tools/adb.exe')
import sys
device=sys.argv[1]
out=root/'artifacts/ui-redesign'
version=re.search(r'^version:\s*([\d.]+)',(root/'pubspec.yaml').read_text(encoding='utf-8'),re.M).group(1)
frames_dir=out/f'{version}-native-frames'
frames_dir.mkdir(exist_ok=True)
def run(*args):
    return subprocess.check_output([adb,'-s',device,*args]).decode('utf-8',errors='replace')
def guard():
    if not re.search(r'mCurrentFocus=.*app\.lianji\.training\.qa/app\.lianji\.training\.MainActivity',run('shell','dumpsys','window')):
        raise RuntimeError('QA foreground required; screenshots aborted')
run('shell','am','start','-W','-n','app.lianji.training.qa/app.lianji.training.MainActivity')
time.sleep(1)
guard()
remote='/data/local/tmp/lianji-qa-frames.xml'
run('shell','uiautomator','dump',remote)
tree=ET.fromstring(run('shell','cat',remote))
descs=[e.get('content-desc','') for e in tree.iter('node') if e.get('package')=='app.lianji.training.qa']
assert any('已完成0次' in x for x in descs) and any('自由训练' in x for x in descs),'Empty QA home required'
coords={}
for label in ['首页','训练','统计','我的']:
    nodes=[e for e in tree.iter('node') if e.get('package')=='app.lianji.training.qa' and e.get('content-desc')==label]
    nums=max((list(map(int,re.findall(r'\d+',e.get('bounds')))) for e in nodes), key=lambda a:a[1])
    coords[label]=[str((nums[0]+nums[2])//2),str((nums[1]+nums[3])//2)]
captures=[]
try:
    for n,label in enumerate(['训练','统计','我的','首页','我的','统计','训练','首页','训练','首页']):
        guard()
        tap=subprocess.Popen([adb,'-s',device,'shell','input','tap',*coords[label]],stdout=subprocess.DEVNULL)
        time.sleep(.025)
        for f in range(3):
            guard()
            path=frames_dir/f'{n:02}-{f}.png'
            start=time.monotonic()
            with path.open('wb') as stream:
                subprocess.run([adb,'-s',device,'exec-out','screencap','-p'],stdout=stream,check=True)
            try: guard()
            except Exception:
                path.unlink(missing_ok=True)
                raise
            captures.append((label,path,round((time.monotonic()-start)*1000)))
        tap.wait(timeout=5)
    guard()
    final=root/f'artifacts/device-screenshots/home-{version}-android16.png'
    final.write_bytes(captures[-1][1].read_bytes())
finally:
    run('shell','rm','-f',remote)

sheet=Image.new('RGB',(5*304,6*108),'#dce5e5')
draw=ImageDraw.Draw(sheet)
previous=None
jumps=[]
for n,(_,path,ms) in enumerate(captures):
    image=Image.open(path).convert('RGB').resize((304,660))
    crop=image.crop((0,570,304,660))
    x,y=(n%5)*304,(n//5)*108
    sheet.paste(crop,(x,y+18))
    draw.text((x+4,y+2),f'tap {n//3+1} frame {n%3+1}, read {ms}ms',fill='#123333')
    if previous is not None:
        jumps.append(sum(ImageStat.Stat(ImageChops.difference(crop,previous)).mean)/3)
    previous=crop
sheet.save(out/f'{version}-native-navigation-contact.png')
body=Image.new('RGB',(5*304,2*678),'#dce5e5')
draw=ImageDraw.Draw(body)
for n in range(10):
    image=Image.open(captures[n*3+1][1]).convert('RGB').resize((304,660))
    x,y=(n%5)*304,(n//5)*678
    body.paste(image,(x,y+18))
    draw.text((x+4,y+2),f'tap {n+1}, frame 2',fill='#123333')
body.save(out/f'{version}-native-pages-contact.png')
report={'captureType':'native screencap sequence, not continuous video',
    'transitions':10,'screenshots':len(captures),
    'maxNavigationMeanDifference':max(jumps),'largeFlashCandidatesOver60':sum(x>60 for x in jumps),
    'limitation':'Sampling can miss flashes between captured frames; user retest still matters.'}
(out/f'{version}-native-sequence.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
