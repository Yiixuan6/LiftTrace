"""Optional QA helper; requires Pillow. Composes existing Flutter screenshots."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[1]/'artifacts'
screens=root/'screenshots'
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)

def sheet(names,filename,columns):
    width,height=216,578
    canvas=Image.new('RGB',(columns*width,((len(names)+columns-1)//columns)*height),'#eeeeee')
    draw=ImageDraw.Draw(canvas)
    for i,name in enumerate(names):
        image=Image.open(screens/(name+'.png')).convert('RGB')
        image.thumbnail((216,550))
        x,y=(i%columns)*width,(i//columns)*height
        draw.text((x+5,y+5),name,font=font,fill='#222222')
        canvas.paste(image,(x,y+28))
    canvas.save(root/filename)
    print(filename,len(names))

sheet([f'{brand}-{mode}-{page}' for page in ['home','active','appearance'] for brand in ['orange','blue','sage'] for mode in ['light','dark']], 'contact-primary.png',6)
for mode in ['light','dark']:
    names=[p.stem for p in sorted(screens.glob(f'orange-{mode}-*.png')) if not any(p.stem.endswith('-'+page) for page in ['home','active','appearance'])]
    sheet(names,f'contact-other-{mode}.png',4)
