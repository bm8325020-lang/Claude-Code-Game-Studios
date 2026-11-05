# Teste do compositor de interiores (sem Blender): python3 -I tools/blender/test_interiores.py
# Mil cômodos sorteados de cada tipo: nada bate, nada sai do cômodo, porta livre, caminho até cada móvel principal;
# e nos cômodos de tamanho normal o conjunto principal aparece.
import os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from interiores import Comodo, compoe

TAM = {"sala": (3.4, 5.5), "quarto": (2.8, 4.5), "quarto_crianca": (2.4, 3.6), "cozinha": (2.8, 4.8), "banheiro": (1.7, 2.8),
       "lavanderia": (1.8, 3.0), "garagem": (3.2, 6.5), "escritorio": (2.4, 3.6), "jantar": (2.8, 4.2)}
PRECISA = {"sala": {"sofa", "tv", "mesa_centro"}, "quarto": {"cama", "criado"}, "quarto_crianca": {"cama_solteiro"},
           "cozinha": {"pia", "fogao", "geladeira"}, "banheiro": {"vaso", "pia_banheiro"}, "lavanderia": {"lavadora"},
           "garagem": {"bancada"}, "escritorio": {"escrivaninha"}, "jantar": {"mesa"}}
falhas, faltou, total = 0, {}, 0
rng = random.Random(5)
for tipo, (a, b) in TAM.items():
    for n in range(1000):
        w, d = rng.uniform(a, b), rng.uniform(a, b)
        portas = [(rng.randrange(4), 0.0, 0.9)]
        pt = portas[0]
        portas[0] = (pt[0], rng.uniform(0.6, (w if pt[0] % 2 == 0 else d) - 0.6), 0.9)
        if rng.random() < 0.3:
            q = rng.randrange(4)
            if q != pt[0]:
                portas.append((q, rng.uniform(0.6, (w if q % 2 == 0 else d) - 0.6), 0.9))
        janelas = []
        for q in range(4):
            if rng.random() < 0.4 and all(p[0] != q for p in portas):
                janelas.append((q, (w if q % 2 == 0 else d) / 2, 1.1, 0.95))
        c = Comodo(0, 0, w, d, portas, janelas)
        itens, probs = compoe(tipo, c, random.Random(n))
        total += 1
        if probs:
            falhas += 1
            if falhas <= 5:
                print("FALHA", tipo, "%.2fx%.2f" % (w, d), portas, probs)
        tipos = {i["tipo"] for i in itens}
        if w >= (a + b) / 2 and d >= (a + b) / 2 and not PRECISA[tipo] <= tipos:
            faltou[tipo] = faltou.get(tipo, 0) + 1
print("cômodos:", total, "com problema:", falhas, "faltou conjunto (cômodo médio/grande):", faltou)
ok = falhas == 0 and all(v <= 30 for v in faltou.values())
print("PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
