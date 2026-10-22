# PROTOTYPE - NOT FOR PRODUCTION
# Draws the official world map as an isometric, layered souls-style diagram from map/official_map.json:
# every area is a slab at its height, joined by stairs, lifts, ladders, bridges, gates and shortcuts.
# usage: python3 tools/draw_map.py map/official_map.json out.png
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

data = json.load(open(sys.argv[1], encoding="utf-8"))
OUT = sys.argv[2]
W, H = 2200, 1800
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FR = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
KIND = {"hub": (235, 150, 60), "town": (150, 135, 115), "bridge": (120, 100, 85), "church": (175, 170, 160), "fortress": (110, 105, 100),
        "citadel": (215, 185, 110), "forest": (85, 95, 70), "graveyard": (120, 115, 110), "crypt": (80, 70, 70), "abyss": (35, 30, 40),
        "flooded": (70, 95, 110), "sewer": (95, 90, 70), "swamp": (90, 105, 60), "lake": (150, 160, 165), "volcano": (150, 55, 30)}
LINK = {"stairs": ((120, 85, 50), False), "bridge": ((150, 95, 40), False), "path": ((120, 100, 80), True), "lift": ((70, 130, 190), False),
        "ladder": ((110, 80, 50), True), "gate": ((80, 80, 90), False), "shortcut": ((80, 160, 80), True)}
NAMES = {"stairs": "Escadaria / descida", "bridge": "Ponte", "path": "Caminho", "lift": "Elevador", "ladder": "Escada / poço",
         "gate": "Portão trancado", "shortcut": "Atalho (abre por trás)"}

def iso(x, y, h):
    return ((x + y) * 150.0, (x - y) * 62.0 - h * 125.0)

areas = {a["id"]: a for a in data["areas"]}
pts = [iso(a["x"], a["y"], a["h"]) for a in data["areas"]]
minx, maxx = min(p[0] for p in pts), max(p[0] for p in pts)
miny, maxy = min(p[1] for p in pts), max(p[1] for p in pts)
s = min((W - 500) / (maxx - minx), (H - 380) / (maxy - miny))
ox, oy = 250 - minx * s, 230 - miny * s

def P(x, y, h):
    a, b = iso(x, y, h)
    return (ox + a * s, oy + b * s)

# dark parchment with a vignette
g = np.random.default_rng(3).random((40, 50)).astype(np.float32)
n = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), dtype=np.float32)[..., None] / 255
base = np.array((58, 48, 40), np.float32) * (0.85 + n * 0.3)
yy, xx = np.mgrid[0:H, 0:W]
vig = 1.0 - 0.55 * np.clip(np.hypot((xx - W / 2) / (W / 1.6), (yy - H / 2) / (H / 1.6)), 0, 1)[..., None]
im = Image.fromarray(np.clip(base * vig, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(im)
fT = ImageFont.truetype(FB, 72)
fA = ImageFont.truetype(FB, 26)
fS = ImageFont.truetype(FR, 18)
fL = ImageFont.truetype(FR, 20)

def text(x, y, t, f, fill=(235, 220, 190), stroke=(25, 18, 12)):
    w = d.textlength(t, font=f)
    d.text((x - w / 2, y), t, font=f, fill=fill, stroke_width=4, stroke_fill=stroke)

# height pillars down to the shrine's level, so depth reads at a glance
for a in data["areas"]:
    top, foot = P(a["x"], a["y"], a["h"]), P(a["x"], a["y"], 0)
    d.line([top, foot], fill=(90, 75, 60), width=2)

def slab(a):
    r = 0.42 if a["kind"] != "hub" else 0.55
    x, y, h = a["x"], a["y"], a["h"]
    top = [P(x - r, y - r, h), P(x + r, y - r, h), P(x + r, y + r, h), P(x - r, y + r, h)]
    bot = [P(x - r, y - r, h - 0.35), P(x + r, y - r, h - 0.35), P(x + r, y + r, h - 0.35), P(x - r, y + r, h - 0.35)]
    col = KIND[a["kind"]]
    dark = tuple(int(c * 0.55) for c in col)
    darker = tuple(int(c * 0.4) for c in col)
    d.polygon([top[1], top[2], bot[2], bot[1]], fill=dark, outline=(20, 15, 10))
    d.polygon([top[0], top[1], bot[1], bot[0]], fill=darker, outline=(20, 15, 10))
    d.polygon(top, fill=col, outline=(20, 15, 10))
    cx = sum(p[0] for p in top) / 4
    cy = sum(p[1] for p in top) / 4
    if a["kind"] == "hub":  # the shrine's bonfire
        d.polygon([(cx, cy - 30), (cx - 14, cy + 6), (cx + 14, cy + 6)], fill=(255, 190, 70), outline=(120, 50, 10))
    return cx, cy

centres = {}
order = sorted(data["areas"], key=lambda a: (a["x"] - a["y"], a["h"]))
# links first (under the slabs), drawn as gentle arcs
for l in data["links"]:
    a, b = areas[l["a"]], areas[l["b"]]
    p0, p1 = P(a["x"], a["y"], a["h"]), P(b["x"], b["y"], b["h"])
    col, dashed = LINK[l["type"]]
    mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 - 40)
    curve = [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * mid[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * mid[1] + t * t * p1[1]) for t in np.linspace(0, 1, 40)]
    for i in range(len(curve) - 1):
        if dashed and i % 2:
            continue
        d.line([curve[i], curve[i + 1]], fill=col, width=7 if l["type"] in ("lift", "gate", "shortcut") else 5)
for a in order:
    centres[a["id"]] = slab(a)
for l in data["links"]:  # link labels on top
    if l["label"]:
        a, b = areas[l["a"]], areas[l["b"]]
        p0, p1 = P(a["x"], a["y"], a["h"]), P(b["x"], b["y"], b["h"])
        text((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 - 34, l["label"], fS, LINK[l["type"]][0], (15, 10, 8))
for a in data["areas"]:
    cx, cy = centres[a["id"]]
    text(cx, cy + 34, a["name"].upper(), fA)
    extra = []
    if a["boss"]:
        extra.append("Chefe: " + a["boss"])
    if a["seed"]:
        extra.append("Semente: " + a["seed"])
    if extra:
        text(cx, cy + 66, "  ·  ".join(extra), fS, (220, 170, 120))

text(W / 2, 40, data["name"].upper(), fT, (240, 160, 70))
text(W / 2, 128, "mundo interligado: tudo volta para o Santuário da Chama", fL, (200, 185, 160))
lx, ly = 40, H - 300
d.rectangle([lx, ly, lx + 360, ly + 270], fill=(45, 36, 30), outline=(140, 110, 80), width=3)
for i, (k, (col, dashed)) in enumerate(LINK.items()):
    y = ly + 22 + i * 35
    for sx in range(0, 60, 12 if dashed else 60):
        d.line([lx + 20 + sx, y + 10, lx + 20 + min(sx + (6 if dashed else 60), 60), y + 10], fill=col, width=6)
    d.text((lx + 95, y), NAMES[k], font=fL, fill=(225, 210, 185))
text(W - 260, H - 120, "ALTO  ↑", fL)
text(W - 260, H - 90, "Santuário = nível 0", fS)
text(W - 260, H - 64, "BAIXO  ↓", fL)
im.save(OUT)
print("saved", OUT)
