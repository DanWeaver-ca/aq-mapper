from PIL import Image, ImageDraw, ImageFont

FONT = "/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
GLYPH = chr(0xe27d)  # filter_drama
TEAL = (0, 150, 136)  # Flutter Colors.teal #009688
S = 1024

# in-app dots shifted LEFT by 0.07: (left, top, diameter, opacity) as fractions of the glyph box
DOTS = [(0.25,0.48,0.09,0.8),(0.43,0.56,0.07,0.6),(0.55,0.44,0.08,0.45)]

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))

def render(motif, bg):
    if bg is None:
        img = Image.new("RGBA",(S,S),(0,0,0,0))
    else:
        img = Image.new("RGB",(S,S),(255,255,255))
        top,bot=(224,242,241),(255,255,255); px=img.load()
        for y in range(S):
            c=lerp(top,bot,y/S)
            for x in range(S): px[x,y]=c
        img=img.convert("RGBA")
    box=S*motif; ox=(S-box)/2; oy=(S-box)/2
    font=ImageFont.truetype(FONT,int(box))
    layer=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(layer)
    bb=d.textbbox((0,0),GLYPH,font=font); gw,gh=bb[2]-bb[0],bb[3]-bb[1]
    d.text((ox+(box-gw)/2-bb[0], oy+(box-gh)/2-bb[1]),GLYPH,font=font,fill=TEAL+(255,))
    img=Image.alpha_composite(img,layer)
    for (l,t,dia,op) in DOTS:
        dd=dia*box; x0=ox+l*box; y0=oy+t*box
        ov=Image.new("RGBA",(S,S),(0,0,0,0)); ImageDraw.Draw(ov).ellipse([x0,y0,x0+dd,y0+dd],fill=TEAL+(int(255*op),))
        img=Image.alpha_composite(img,ov)
    return img

# Full-bleed master (iOS + legacy Android): opaque gradient background, motif 0.74
render(0.74, bg=True).convert("RGB").save("assets/icon/app_icon.png")
# Adaptive foreground (Android): transparent, smaller motif (~0.58) to fit the safe zone
render(0.58, bg=None).save("assets/icon/app_icon_foreground.png")
print("wrote assets/icon/app_icon.png and app_icon_foreground.png")
