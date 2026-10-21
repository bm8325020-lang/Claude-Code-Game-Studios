# PROTOTYPE - NOT FOR PRODUCTION
# Draws the official island map as a parchment illustration from map/official_map.json.
# usage: python3 tools/draw_map.py map/official_map.json out.png
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

data = json.load(open(sys.argv[1], encoding="utf-8"))
OUT = sys.argv[2]
W = 1600
HALF = data["size_m"] / 2
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_R = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"

def px(x, z):
    return ((x + HALF) / data["size_m"] * W, (z + HALF) / data["size_m"] * W)

BIOME = {"coast": (196, 170, 120), "village": (170, 140, 95), "dead_forest": (95, 92, 70), "swamp": (88, 100, 72),
         "castle": (140, 128, 112), "graveyard": (120, 112, 104), "canyon": (150, 110, 80), "snow": (225, 225, 220),
         "volcano": (90, 50, 40)}

rng = np.random.default_rng(5)
def noise(cells, seed):
    g = np.random.default_rng(seed).random((cells, cells)).astype(np.float32)
    return np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((W, W), Image.BICUBIC), dtype=np.float32) / 255

# land: blobs around every region plus noise for a ragged coast
ys, xs = np.mgrid[0:W, 0:W].astype(np.float32)
land = np.zeros((W, W), np.float32)
biome_idx = np.full((W, W), -1)
best = np.full((W, W), -1e9, np.float32)
regions = data["regions"]
for i, r in enumerate(regions):
    cx, cy = px(r["x"], r["z"])
    rr = r["r"] / data["size_m"] * W
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    v = 1.0 - d / (rr * (2.3 if r["id"] != "farol" else 1.4))
    land = np.maximum(land, v)
    infl = 1.0 - d / rr
    sel = infl > best
    best[sel] = infl[sel]
    biome_idx[sel] = i
n = noise(14, 2) * 0.5 + noise(40, 3) * 0.25
land = land + (n - 0.38) * 0.45
is_land = land > 0.12

paper = np.zeros((W, W, 3), np.float32)
paper[:] = (214, 196, 160)
paper *= (0.88 + noise(60, 9)[..., None] * 0.18)
sea = np.array((120, 140, 140), np.float32) * (0.9 + noise(30, 4)[..., None] * 0.15)
img = np.where(is_land[..., None], paper, sea)
for i, r in enumerate(regions):
    col = np.array(BIOME[r["biome"]], np.float32)
    m = is_land & (biome_idx == i) & (best > -0.6)
    a = np.clip((best + 0.6) * 0.9, 0, 0.75)[..., None]
    img = np.where(m[..., None], img * (1 - a) + col * a, img)
im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
# coastline ink
edge = Image.fromarray((is_land * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(3))
ink = Image.new("RGB", (W, W), (60, 45, 30))
im.paste(ink, mask=edge)
d = ImageDraw.Draw(im)

# roads: dashed
for road in data["roads"]:
    pts = [px(x, z) for x, z in road]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        L = math.hypot(x1 - x0, y1 - y0)
        steps = int(L / 14)
        for s in range(0, steps, 2):
            a, b = s / steps, min((s + 1) / steps, 1)
            d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill=(95, 60, 35), width=4)

f_big = ImageFont.truetype(FONT, 30)
f_mid = ImageFont.truetype(FONT_R, 19)
f_small = ImageFont.truetype(FONT_R, 15)
f_title = ImageFont.truetype(FONT, 60)

def label(x, y, text, font, fill=(40, 25, 15)):
    w = d.textlength(text, font=font)
    d.text((x - w / 2, y), text, font=font, fill=fill, stroke_width=3, stroke_fill=(230, 215, 180))

for b in data["bonfires"]:
    x, y = px(b["x"], b["z"])
    d.polygon([(x, y - 11), (x - 6, y + 5), (x + 6, y + 5)], fill=(230, 110, 20), outline=(90, 40, 10))
for g in data["gates"]:
    x, y = px(g["x"], g["z"])
    d.rectangle([x - 10, y - 10, x + 10, y + 10], fill=(60, 60, 70), outline=(20, 20, 20), width=2)
    d.line([x - 6, y - 10, x - 6, y + 10], fill=(160, 160, 170), width=2)
    d.line([x + 6, y - 10, x + 6, y + 10], fill=(160, 160, 170), width=2)
for r in regions:
    x, y = px(r["x"], r["z"])
    if r["boss"]:  # boss: skull-ish circle with crossed marks
        bx, by = x + 34, y + 30
        d.ellipse([bx - 12, by - 12, bx + 12, by + 12], fill=(150, 30, 20), outline=(40, 10, 5), width=2)
        d.line([bx - 6, by - 6, bx + 6, by + 6], fill=(240, 220, 200), width=3)
        d.line([bx - 6, by + 6, bx + 6, by - 6], fill=(240, 220, 200), width=3)
    if r["seed"]:
        sx, sy = x - 36, y + 30
        d.ellipse([sx - 8, sy - 12, sx + 8, sy + 12], fill=(250, 170, 40), outline=(110, 60, 10), width=2)
    label(x, y - 40, r["name"].upper(), f_big)
    label(x, y - 6, "Nível de perigo %d" % r["tier"], f_small, (90, 30, 20))

# legend, title, compass, scale
label(W / 2, 30, data["name"].upper(), f_title, (60, 25, 10))
lx, ly = 40, W - 190
d.rectangle([lx - 10, ly - 10, lx + 330, ly + 160], fill=(225, 210, 175), outline=(80, 55, 30), width=3)
d.polygon([(lx + 10, ly + 2), (lx + 4, ly + 18), (lx + 16, ly + 18)], fill=(230, 110, 20))
d.text((lx + 30, ly), "Fogueira", font=f_mid, fill=(40, 25, 15))
d.ellipse([lx + 2, ly + 38, lx + 18, ly + 54], fill=(150, 30, 20))
d.text((lx + 30, ly + 36), "Chefe", font=f_mid, fill=(40, 25, 15))
d.ellipse([lx + 4, ly + 72, lx + 16, ly + 92], fill=(250, 170, 40))
d.text((lx + 30, ly + 72), "Semente de poder", font=f_mid, fill=(40, 25, 15))
d.rectangle([lx + 2, ly + 110, lx + 18, ly + 126], fill=(60, 60, 70))
d.text((lx + 30, ly + 108), "Portão", font=f_mid, fill=(40, 25, 15))
cx, cy = W - 90, 190
d.polygon([(cx, cy - 60), (cx - 14, cy), (cx + 14, cy)], fill=(120, 30, 20))
d.polygon([(cx, cy + 60), (cx - 14, cy), (cx + 14, cy)], fill=(60, 45, 30))
label(cx, cy - 92, "N", f_big)
sx = W - 330
d.line([sx, W - 40, sx + W / 4, W - 40], fill=(40, 25, 15), width=5)
label(sx + W / 8, W - 72, "500 m", f_mid)
im.save(OUT)
print("saved", OUT)
