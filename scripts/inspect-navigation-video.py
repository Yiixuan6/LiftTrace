"""QA-only: decode every frame of the guarded empty-QA navigation recording."""
from pathlib import Path
import sys, json, math
from PIL import Image, ImageDraw, ImageStat, ImageChops

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root/'.tooling/videoqa'))
import imageio_ffmpeg

out = root/'artifacts/ui-redesign'
frames = imageio_ffmpeg.read_frames(str(out/'0.2.2-native-navigation.mp4'),
    output_params=['-vf','scale=304:660'])
meta = next(frames)
crops, bodies, jumps, means = [], [], [], []
previous = None
for i, data in enumerate(frames):
    frame = Image.frombytes('RGB', meta['size'], data)
    crop = frame.crop((5,580,299,650))
    means.append(sum(ImageStat.Stat(crop).mean)/3)
    if previous is not None:
        jumps.append(sum(ImageStat.Stat(ImageChops.difference(crop,previous)).mean)/3)
    previous = crop
    crops.append(crop)
    if i % max(1, round(meta['fps']*.45)) == 0:
        bodies.append((i, frame.copy()))

def contact(items, name, cols):
    w,h=items[0][1].size
    for start in range(0,len(items),cols*10):
        chunk=items[start:start+cols*10]
        sheet=Image.new('RGB',(cols*w,math.ceil(len(chunk)/cols)*(h+18)),'#dce5e5')
        draw=ImageDraw.Draw(sheet)
        for k,(index,img) in enumerate(chunk):
            x,y=(k%cols)*w,(k//cols)*(h+18)
            draw.text((x+3,y+2),f'frame {index} / {index/meta["fps"]:.2f}s',fill='#123333')
            sheet.paste(img,(x,y+18))
        sheet.save(out/f'{name}-{start//(cols*10)+1}.png')

contact(list(enumerate(crops)), '0.2.2-navigation-all-frames', 8)
contact(bodies, '0.2.2-navigation-body-samples', 5)
report={'decodedFrames':len(crops),'fps':meta['fps'],'duration':meta['duration'],
    'navigationMeanRgbMin':min(means),'navigationMeanRgbMax':max(means),
    'maximumAdjacentNavigationMeanDifference':max(jumps),
    'largeFlashCandidatesOver60':sum(x>60 for x in jumps),
    'note':'Metrics are diagnostics, not a substitute for contact-sheet inspection.'}
(out/'0.2.2-video-metrics.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
