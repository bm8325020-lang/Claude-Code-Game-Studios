"""Gera assets/catalogo/lista.json: todos os modelos que o modo construção oferece, com categoria e nome em português.
Depois: tools/catalogo/mede.gd mede cada um no Godot e escreve assets/catalogo/catalogo.json (com tamanho e escala).
Rodar da pasta jogo/:  python3 tools/catalogo/gera_lista.py <ph.json da API do Poly Haven>"""
import json, os, sys, re

RAIZ = "assets"
KENNEY = {
    "city-kit-roads": "Ruas e calçadas", "city-kit-suburban": "Casas (estilo desenho)", "city-kit-commercial": "Lojas e prédios (desenho)",
    "city-kit-industrial": "Indústria", "car-kit": "Carros (desenho)", "space-kit": "Espaço e foguetes", "furniture-kit": "Móveis (desenho)",
    "building-kit": "Peças de construção", "modular-buildings": "Peças de construção", "retro-urban-kit": "Cidade retrô",
    "survival-kit": "Sobrevivência", "graveyard-kit": "Cemitério", "nature-kit": "Natureza", "train-kit": "Trem e trilhos",
    "factory-kit": "Fábrica", "mini-market": "Mercadinho", "fantasy-town-kit": "Cidade antiga",
}
PH_CAT = [("seating", "Móveis realistas"), ("table", "Móveis realistas"), ("furniture", "Móveis realistas"), ("shelves", "Móveis realistas"),
          ("bed", "Móveis realistas"), ("lighting", "Luz e lâmpadas"), ("appliances", "Eletrodomésticos e eletrônicos"),
          ("electronics", "Eletrodomésticos e eletrônicos"), ("industrial", "Industrial (realista)"), ("tools", "Ferramentas"),
          ("weapons", "Armas (enfeite)"), ("firearms", "Armas (enfeite)"), ("containers", "Caixas, barris e latas"),
          ("food", "Comida e cozinha"), ("dishes", "Comida e cozinha"), ("structures", "Estruturas"), ("office", "Escritório"),
          ("books", "Objetos da casa"), ("decorative", "Objetos da casa"), ("vases", "Objetos da casa"), ("instrument", "Objetos da casa"),
          ("props", "Objetos da casa")]
RUINAS = {"casa_r": "Casas do jogo", "loja_r": "Lojas do jogo", "predio_r": "Prédios do jogo", "galpao_r": "Galpões do jogo",
          "delegacia": "Prédios do jogo", "carro_r": "Veículos do jogo", "van_r": "Veículos do jogo", "onibus_r": "Veículos do jogo",
          "caixa_dagua": "Marcos", "antena": "Marcos", "helicoptero": "Marcos", "quarentena": "Marcos", "posto": "Marcos",
          "barricada": "Barricadas"}


def bonito(n):
    n = re.sub(r"[_\-]+", " ", os.path.splitext(n)[0]).strip()
    return n[:1].upper() + n[1:]


itens = []
def poe(cena, cat, nome):
    itens.append({"id": cena.replace("res://", ""), "cena": cena, "cat": cat, "nome": nome})

for kit, cat in KENNEY.items():
    p = os.path.join(RAIZ, "catalogo/kenney", kit)
    for f in sorted(os.listdir(p)) if os.path.isdir(p) else []:
        if f.endswith(".glb"):
            poe("res://%s/%s" % (p, f), cat, bonito(f))
ph = json.load(open(sys.argv[1])) if len(sys.argv) > 1 else {}
for pasta in ["catalogo/polyhaven", "moveis"]:
    base = os.path.join(RAIZ, pasta)
    for d in sorted(os.listdir(base)):
        g = os.path.join(base, d, d + ".gltf")
        if not os.path.exists(g):
            continue
        cats = ph.get(d, {}).get("categories", [])
        cat = next((c for k, c in PH_CAT if k in cats), "Objetos da casa")
        poe("res://" + g, cat, bonito(d))
for f in sorted(os.listdir(os.path.join(RAIZ, "catalogo/majadroid"))):
    if f.endswith(".glb"):
        poe("res://assets/catalogo/majadroid/" + f, "Ruínas de prédios", bonito(f))
for r, _, fs in os.walk(os.path.join(RAIZ, "catalogo/atomic")):
    for f in sorted(fs):
        if f.endswith((".glb", ".gltf")):
            poe("res://" + os.path.join(r, f), "Apocalipse (estilizado)", bonito(f))
for f in sorted(os.listdir(os.path.join(RAIZ, "ruinas"))):
    if f.endswith(".glb"):
        cat = next((c for k, c in RUINAS.items() if f.startswith(k)), "Construções do jogo")
        poe("res://assets/ruinas/" + f, cat, bonito(f))
for f in sorted(os.listdir(os.path.join(RAIZ, "sketchfab"))):
    if f.endswith(".glb") and f.split(".")[0] in ("barreira_aco", "barreira_estrada", "barreiras_myjato", "cerca_a", "cerca_b", "correio",
                                                   "entulho", "objetos_rua", "predio_props", "armario", "estante"):
        poe("res://assets/sketchfab/" + f, "Rua e barricadas", bonito(f))
# peças de jogo (não são modelos: o MapaCustom cria)
for k, n in [("jogo:nascer", "Ponto de nascer (jogador)"), ("jogo:zumbi", "Ponto de zumbi (bando)"), ("jogo:bau", "Baú de loot"),
             ("jogo:bau_raro", "Baú de loot raro"), ("jogo:sala_segura", "Sala segura (lampião)"), ("jogo:carro", "Carro dirigível"),
             ("jogo:fogo", "Barril com fogo"), ("jogo:luz", "Poste de luz acesa")]:
    itens.append({"id": k, "cena": k, "cat": "Peças do jogo", "nome": n})
json.dump(itens, open(os.path.join(RAIZ, "catalogo/lista.json"), "w"), ensure_ascii=False, indent=0)
print(len(itens), "itens")
