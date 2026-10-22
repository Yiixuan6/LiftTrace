"""Collect only synthetic in-memory images produced by the native GPU test."""
from pathlib import Path
import json
import re
import subprocess
import sys
from PIL import Image, ImageDraw, ImageStat, ImageChops

root = Path(__file__).resolve().parents[1]
adb = root / '.tooling/android-sdk/platform-tools/adb.exe'
version = re.search(r'^version:\s*([\d.]+)', (root/'pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)
out = root / 'artifacts/ui-redesign'
frames = out / f'{version}-native-frames'
frames.mkdir(exist_ok=True)
device = sys.argv[1]
names = ['home'] + [f'{n:02}-{frame}' for n in range(10) for frame in range(3)]
for name in names:
    payload = subprocess.check_output([
        str(adb), '-s', device, 'exec-out', 'run-as', 'app.lianji.training.qa',
        'cat', f'cache/liquid-navigation-qa/{name}.png',
    ])
    assert payload.startswith(b'\x89PNG\r\n\x1a\n'), 'Expected isolated test PNG'
    target = (root / f'artifacts/device-screenshots/home-{version}-android16.png'
              if name == 'home' else frames/f'{name}.png')
    target.write_bytes(payload)

navigation = Image.new('RGB', (5*304, 6*108), '#e5eaea')
pages = Image.new('RGB', (5*304, 2*678), '#e5eaea')
previous = None
differences = []
for n in range(30):
    image = Image.open(frames/f'{n//3:02}-{n%3}.png').convert('RGB').resize((304, 660))
    crop = image.crop((0, 570, 304, 660))
    x, y = (n%5)*304, (n//5)*108
    navigation.paste(crop, (x, y+18))
    ImageDraw.Draw(navigation).text((x+4, y+2), f'tap {n//3+1} sample {n%3+1}', fill='#123333')
    if previous is not None:
        differences.append(sum(ImageStat.Stat(ImageChops.difference(crop, previous)).mean)/3)
    previous = crop
    if n%3 == 1:
        i = n//3
        x, y = (i%5)*304, (i//5)*678
        pages.paste(image, (x, y+18))
        ImageDraw.Draw(pages).text((x+4, y+2), f'isolated GPU app - tap {i+1}', fill='#123333')
navigation.save(out/f'{version}-native-navigation-contact.png')
pages.save(out/f'{version}-native-pages-contact.png')
report = {
    'captureType': 'device GPU RenderRepaintBoundary, isolated in-memory app; not continuous video',
    'readsExistingDatabase': False,
    'transitions': 10,
    'screenshots': 30,
    'nominalPumpedSampleMilliseconds': [16, 96, 176],
    'maxNavigationMeanDifference': max(differences),
    'largeFlashCandidatesOver60': sum(x > 60 for x in differences),
    'limitation': 'Scheduled GPU samples can miss unsampled instants; actual user retest still matters.',
}
(out/f'{version}-native-sequence.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
