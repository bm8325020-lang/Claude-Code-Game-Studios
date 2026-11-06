# Imagem do minimapa (estilo GTA V: chão escuro, ruas claras, prédios cinza, água azul, mato verde) a partir da planta.
# 1 px = 1 m local do Bairro; centro da imagem = (0, 0); +x direita, +z para baixo. Rodar depois do raven_creek.py:
#   python3 -I tools/mapa/minimapa.py   ->  assets/mapa/minimapa.png
import json, os
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
N = 1024  # px (a cidade tem 1000 m; sobra borda)
LARG = {"primary": 10.0, "secondary": 9.0, "tertiary": 8.0, "residential": 6.5, "service": 4.0, "viela": 3.5}
COR = {"chao": (52, 58, 52), "grama": (60, 82, 56), "praca": (92, 92, 88), "asfalto": (78, 80, 82),
       "rua": (150, 152, 150), "borda_rua": (40, 42, 44), "predio": (98, 102, 108), "predio_borda": (66, 70, 76),
       "agua": (52, 96, 140), "mato": (46, 74, 46)}


def px(p):
    return (p[0] + N / 2, p[1] + N / 2)


def faz(dados):
    im = Image.new("RGB", (N, N), COR["chao"])
    d = ImageDraw.Draw(im)
    for m in dados.get("terreno", {}).get("morros", []):  # Raven Hill: mata
        x, z = px(m["p"])
        r = m["raio"]
        d.ellipse((x - r, z - r, x + r, z + r), fill=COR["mato"])
    for a in dados.get("areas", []):
        d.polygon([px(q) for q in a["p"]], fill=COR.get(a["m"], COR["grama"]))
    rio = dados.get("terreno", {}).get("rio")
    if rio:
        d.line([px(q) for q in rio["p"]], fill=COR["agua"], width=int(rio["larg"]), joint="curve")
    for r in dados["ruas"]:  # contorno escuro e depois a rua
        d.line([px(q) for q in r["p"]], fill=COR["borda_rua"], width=int(LARG.get(r["tipo"], 6) + 3), joint="curve")
    for r in dados["ruas"]:
        d.line([px(q) for q in r["p"]], fill=COR["rua"], width=int(LARG.get(r["tipo"], 6)), joint="curve")
    for p in dados["predios"]:
        d.polygon([px(q) for q in p["p"]], fill=COR["predio"], outline=COR["predio_borda"])
    return im.filter(ImageFilter.SMOOTH)


if __name__ == "__main__":
    with open(os.path.join(RAIZ, "assets", "mapa", "cidade.json")) as f:
        im = faz(json.load(f))
    # teste rápido: o centro da Town Square (rua) tem que sair claro e o canto (fora da cidade) escuro
    assert sum(im.getpixel((N - 2, N - 2))) < 200, "canto devia ser chão escuro"
    saida = os.path.join(RAIZ, "assets", "mapa", "minimapa.png")
    im.save(saida, optimize=True)
    print("MINIMAPA_OK", saida, os.path.getsize(saida) // 1024, "KB")
