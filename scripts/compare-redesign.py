"""QA-only density normalization and side-by-side capture; never an app asset."""
from pathlib import Path
from PIL import Image, ImageDraw
import sys

root = Path(__file__).resolve().parents[1]
evidence = root/'artifacts/ui-redesign'
current = evidence/(sys.argv[1] if len(sys.argv)>1 else 'home-populated-390x844.png')
reference = Image.open(evidence/'selected-reference.png').convert('RGB').resize((390,844),Image.Resampling.LANCZOS)
rendered = Image.open(current).convert('RGB')
assert rendered.size == (390,844)
canvas = Image.new('RGB',(804,876),'#e8ecec')
draw = ImageDraw.Draw(canvas)
draw.text((12,8),'SELECTED REFERENCE',fill='#203c3d')
draw.text((414,8),'FLUTTER IMPLEMENTATION',fill='#203c3d')
canvas.paste(reference,(0,32))
canvas.paste(rendered,(414,32))
output = evidence/('comparison-'+current.stem+'.png')
canvas.save(output)
print(output)
for label, box in [('navigation',(0,738,390,844)),('recent',(12,680,378,748)),('training',(12,380,378,464)),('primary',(12,452,378,536))]:
    left, right = reference.crop(box), rendered.crop(box)
    detail = Image.new('RGB',(left.width*2+24,left.height+28),'#e8ecec')
    detail.paste(left,(0,28))
    detail.paste(right,(left.width+24,28))
    ImageDraw.Draw(detail).text((8,7),'REFERENCE / FLUTTER: '+label,fill='#203c3d')
    detail.save(evidence/('detail-'+label+'-'+current.stem+'.png'))
