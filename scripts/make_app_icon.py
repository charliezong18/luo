#!/usr/bin/env python3
"""Generate the 落 app icon: a gold 方孔圆钱 on the Dusk Desk warm near-black.
Pure PIL, no assets. Output: 1024x1024 PNG into the asset catalog."""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGB", (S, S), (20, 17, 13))          # DESIGN.md neutral #14110D
d = ImageDraw.Draw(img)

# Soft warm radial glow behind the coin so it doesn't float in flat black.
glow = Image.new("L", (S, S), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([S*0.13, S*0.13, S*0.87, S*0.87], fill=70)
glow = glow.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(Image.new("RGB", (S, S), (66, 50, 28)), img, glow)
d = ImageDraw.Draw(img)

cx = cy = S / 2
R = S * 0.335                 # coin outer radius
hole = R * 0.34               # half-side of square hole

def gold(t):                  # vertical gold gradient: lit top -> shaded bottom
    top = (232, 190, 100); bot = (140, 100, 42)
    return tuple(int(a + (b - a) * t) for a, b in zip(top, bot))

# Coin body: draw as vertical-gradient gold disc (scanlines), then punch hole.
coin = Image.new("RGBA", (S, S), (0, 0, 0, 0))
cd = ImageDraw.Draw(coin)
for y in range(int(cy - R), int(cy + R) + 1):
    dy = (y - cy) / R
    half = R * math.sqrt(max(0.0, 1 - dy * dy))
    t = (dy + 1) / 2
    cd.line([(cx - half, y), (cx + half, y)], fill=gold(t) + (255,))

# Rim shading: darker ring at the very edge (outer 郭), brighter inner ledge.
for i, (w, col) in enumerate([(S*0.016, (96, 68, 26, 255)), (S*0.008, (255, 224, 150, 200))]):
    inset = (S*0.0) if i == 0 else (S*0.020)
    cd.ellipse([cx-R+inset, cy-R+inset, cx+R-inset, cy+R-inset], outline=col, width=int(w))

# Square hole (方孔): punch transparent, then add inner rim (内郭).
hd = ImageDraw.Draw(coin)
hd.rectangle([cx-hole, cy-hole, cx+hole, cy+hole], fill=(0, 0, 0, 0))
# 内郭: raised square rim around the hole
lip = S * 0.014
hd.rectangle([cx-hole-lip*2.2, cy-hole-lip*2.2, cx+hole+lip*2.2, cy+hole+lip*2.2],
             outline=(120, 86, 34, 255), width=int(lip*1.6))
hd.rectangle([cx-hole-lip*1.1, cy-hole-lip*1.1, cx+hole+lip*1.1, cy+hole+lip*1.1],
             outline=(250, 214, 130, 230), width=int(lip*0.9))

# Specular sweep: a soft diagonal highlight band across the upper-left of the coin.
spec = Image.new("L", (S, S), 0)
sd = ImageDraw.Draw(spec)
sd.ellipse([cx-R*0.95, cy-R*1.25, cx+R*0.55, cy-R*0.05], fill=90)
spec = spec.filter(ImageFilter.GaussianBlur(70))
coin.putalpha(coin.split()[3])  # keep alpha
gold_hi = Image.new("RGBA", (S, S), (255, 236, 180, 0))
gold_hi.putalpha(spec)
coin = Image.alpha_composite(coin, gold_hi)

# Drop shadow under the coin.
sh = Image.new("L", (S, S), 0)
shd = ImageDraw.Draw(sh)
shd.ellipse([cx-R*1.02, cy-R*0.94+S*0.03, cx+R*1.02, cy+R*1.10+S*0.03], fill=110)
sh = sh.filter(ImageFilter.GaussianBlur(60))
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
shadow.putalpha(sh)
base = img.convert("RGBA")
base = Image.alpha_composite(base, shadow)
base = Image.alpha_composite(base, coin)

out = base.convert("RGB")
import os, sys
dst = os.path.expanduser("~/Developer/Luo/Luo/Assets.xcassets/AppIcon.appiconset")
os.makedirs(dst, exist_ok=True)
out.save(os.path.join(dst, "AppIcon-1024.png"))
print("saved", os.path.join(dst, "AppIcon-1024.png"))
