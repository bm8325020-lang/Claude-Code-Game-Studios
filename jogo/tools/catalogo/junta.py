"""Junta lista.json + medidas.json -> assets/catalogo/catalogo.json (com escala por pacote e se tem colisão).
Rodar da pasta jogo/ depois de tools/catalogo/mede.gd."""
import json
ESCALA = {"car-kit": 3.0, "city-kit-roads": 6.0, "city-kit-suburban": 7.0, "city-kit-commercial": 7.0, "city-kit-industrial": 7.0,
          "building-kit": 1.9, "modular-buildings": 4.0, "retro-urban-kit": 4.0, "fantasy-town-kit": 3.0, "furniture-kit": 2.2,
          "graveyard-kit": 2.5, "mini-market": 2.3, "nature-kit": 4.0, "space-kit": 4.0, "survival-kit": 2.5, "train-kit": 2.0,
          "factory-kit": 3.0}
lista = json.load(open("assets/catalogo/lista.json"))
med = json.load(open("assets/catalogo/medidas.json"))
out = []
for it in lista:
    if it["cena"].startswith("jogo:"):
        it.update({"esc": 1.0, "tam": [1, 1, 1], "col": False})
        out.append(it)
        continue
    m = med.get(it["id"])
    if m is None or m["tris"] > 60000:
        continue
    kit = it["id"].split("/")[3] if "/kenney/" in it["id"] else ""
    e = ESCALA.get(kit, 1.0)
    t = [round(x * e, 2) for x in m["tam"]]
    it.update({"esc": e, "tam": t, "col": max(t) >= 0.4})
    out.append(it)
json.dump(out, open("assets/catalogo/catalogo.json", "w"), ensure_ascii=False, separators=(",", ":"))
print(len(out), "no catálogo")
