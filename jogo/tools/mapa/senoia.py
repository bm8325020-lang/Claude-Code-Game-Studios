# RAVEN CREEK (05/11, dono: "quero mudar completamente a cidade", prompt DEAD DISTRICT MAP MASTER): cidade pequena
# americana depois do fim do mundo, 1 x 1 km, desenhada em grade e preenchida por regras. Gera assets/mapa/cidade.json:
#   python3 tools/mapa/raven_creek.py [assets/mapa/cidade.json]
# Modelos em assets/ruinas (tools/blender/ruinas.py, cidade.py, casas_us.py); tamanhos em tools/mapa/medidas.json.
# Coordenadas locais em metros (x, z), de -488 a 488; -z = norte.
#   Downtown: grade de quarteirões na Main Street, Town Square com coreto, igreja, delegacia (POLICE), hospital,
#     lojas de tijolo com letreiro em inglês, prédios de apartamento, um quarteirão em ruínas.
#   Route 9 (norte-sul) com o Food Mart e o estacionamento; posto na Main Street; bloqueio do exército na entrada norte.
#   Bairros de casas americanas (gramado na frente, entrada de carro, cerca de tábua no quintal): norte, oeste, leste e sul.
#   Raven Creek (riacho) ao sul do centro com pontes; do outro lado: cemitério, zona industrial, helicóptero caído.
#   Raven Hill (mata) no noroeste, com a antena.
import json
import math
import random
import sys

R = random.Random(1947)
LIM = 488.0
MED = json.load(open("tools/mapa/medidas.json"))
LARG = {"primary": 10.0, "secondary": 9.0, "tertiary": 8.0, "residential": 6.5, "service": 4.0, "viela": 3.5}
CALCADA = 1.7
ruas, segs = [], []          # segs: (a, b, meia largura com calçada)
predios, muros, props, areas, faixas, frestas, bloqueios, marcos, veiculos, postes, longe = ([] for _ in range(11))
ocupado = []                 # retângulos (cx, cz, ang, w, d) já usados (lotes, praça, marcos)
zumbis = []                  # pontos extras de zumbi (cemitério, praça, favela)


def catmull(pts, passo=5.0):
    out = []
    p = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        n = max(2, int(math.dist(p1, p2) / passo))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append([round(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                     + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3), 2) for j in (0, 1)])
    out.append(list(pts[-1]))
    return out


def rua(pts, tipo, curva=True):
    p = catmull(pts) if curva else [list(q) for q in pts]
    ruas.append({"p": p, "tipo": tipo})
    meia = LARG[tipo] / 2 + (0 if tipo in ("service", "viela") else CALCADA)
    for a, b in zip(p, p[1:]):
        segs.append((a, b, meia))
    return p


def dist_seg(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    l2 = ax * ax + az * az
    t = 0 if l2 == 0 else max(0, min(1, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / l2))
    return math.dist(p, (a[0] + ax * t, a[1] + az * t))


def perto_rua(p, folga):
    return any(dist_seg(p, a, b) < m + folga for (a, b, m) in segs)


def cantos(cx, cz, ang, w, d):
    c, s = math.cos(ang), math.sin(ang)
    return [[round(cx + c * x - s * z, 2), round(cz + s * x + c * z, 2)] for (x, z) in
            ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]


def sobrepoe(a, b, folga=0.05):
    pa, pb = cantos(*a[:3], a[3] + folga, a[4] + folga), cantos(*b[:3], b[3] + folga, b[4] + folga)
    for poly in (pa, pb):
        for i in range(4):
            e = (poly[(i + 1) % 4][0] - poly[i][0], poly[(i + 1) % 4][1] - poly[i][1])
            n = (-e[1], e[0])
            sa = [n[0] * p[0] + n[1] * p[1] for p in pa]
            sb = [n[0] * p[0] + n[1] * p[1] for p in pb]
            if max(sa) < min(sb) or max(sb) < min(sa):
                return False
    return True


def ponto_em(pts, t):
    """Ponto e direção a `t` metros do começo da polilinha (None se passou do fim)."""
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        l = math.dist(a, b)
        if acc + l >= t and l > 0:
            f = (t - acc) / l
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f), math.atan2(b[1] - a[1], b[0] - a[0])
        acc += l
    return None, 0.0


def comprimento(pts):
    return sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))


# ---------------- terreno ----------------
# Raven Creek (o riacho) corta a cidade de oeste a leste ao sul do centro; Raven Hill (mata) no canto noroeste.
rio = catmull([(-500, 250), (-380, 268), (-250, 246), (-120, 262), (0, 250), (130, 270), (260, 248), (380, 262), (500, 255)], 8.0)
RIO_LARG = 14.0
MORRO = {"p": [-370, -360], "raio": 100.0, "alt": 14.0}


# SENOIA (06/11, pedido do dono: "acha uma cidade real e recria igualzinha"): CIDADE=senoia troca a planta inventada
# pelas ruas e prédios reais de Senoia, Geórgia (EUA; onde gravaram Woodbury de The Walking Dead), do OpenStreetMap
# (tools/mapa/osm/senoia.json, © colaboradores do OpenStreetMap, ODbL). 1 m = 1 m; o centro do quadrado é (0, 0).
# Os prédios que o OSM tem entram no lugar e do tamanho deles (o modelo nosso que mais se parece); o resto dos lotes
# das ruas residenciais é preenchido pelas regras de sempre (casas americanas).
import os
SENOIA = True  # Raven Creek foi apagada (06/11, dono)
OSM_LAT0, OSM_LON0 = 33.3030, -84.5541
if SENOIA:
    rio = [[-600.0, 2000.0], [600.0, 2000.0]]  # Senoia não tem riacho no quadrado: o rio fica fora do mapa
    MORRO = {"p": [2000, 2000], "raio": 10.0, "alt": 0.0}
    OSM = json.load(open("tools/mapa/osm/senoia.json"))["elements"]


def osm_xy(g):
    return (round((g["lon"] - OSM_LON0) * 111320 * math.cos(math.radians(OSM_LAT0)), 2), round(-(g["lat"] - OSM_LAT0) * 110540, 2))


def ruas_osm():
    """Ruas reais: cada trecho dentro do mapa vira rua do tipo dela (calçada, faixa, postes como as outras)."""
    tipos = {"primary": "primary", "secondary": "secondary", "tertiary": "tertiary", "unclassified": "residential",
             "residential": "residential", "living_street": "residential", "service": "service"}
    for e in OSM:
        t = e.get("tags", {}).get("highway")
        if t not in tipos or "geometry" not in e:
            continue
        trecho = []
        for q in [osm_xy(g) for g in e["geometry"]] + [None]:
            if q is not None and abs(q[0]) < LIM and abs(q[1]) < LIM:
                if not trecho or math.dist(trecho[-1], q) > 1.0:
                    trecho.append(q)
                continue
            if len(trecho) >= 2 and comprimento(trecho) > 15:
                rua(trecho, tipos[t], False)
            trecho = []


def predios_osm():
    """Prédios reais do OSM no lugar deles: casa -> casa americana, comércio -> sobrado de loja, igreja -> igreja."""
    feitos = 0
    for e in OSM:
        t = e.get("tags", {}).get("building")
        if not t or "geometry" not in e:
            continue
        pts = [osm_xy(g) for g in e["geometry"]]
        cx, cz = sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts)
        if abs(cx) > LIM - 10 or abs(cz) > LIM - 10:
            continue
        # lado maior = largura da fachada; a frente olha para a rua mais perto
        lados = [(math.dist(a, b), a, b) for a, b in zip(pts, pts[1:])]
        comp_l, a, b = max(lados)
        perto = min(segs, key=lambda sg: dist_seg((cx, cz), sg[0], sg[1]))
        ax, az = perto[1][0] - perto[0][0], perto[1][1] - perto[0][1]
        l2 = ax * ax + az * az or 1.0
        k = max(0, min(1, ((cx - perto[0][0]) * ax + (cz - perto[0][1]) * az) / l2))
        fx, fz = perto[0][0] + ax * k - cx, perto[0][1] + az * k - cz
        n = math.hypot(fx, fz) or 1.0
        frente = (fx / n, fz / n)
        area_m2 = abs(sum(p1[0] * p2[1] - p2[0] * p1[1] for p1, p2 in zip(pts, pts[1:]))) / 2
        if t == "church":
            modelo = "igreja"
        elif t in ("commercial", "retail") or (t == "yes" and zona(cx, cz) == "centro"):
            modelo = min(SOBRADOS, key=lambda m: abs(MED[m][0] * MED[m][1] - area_m2))
        elif t == "apartments":
            modelo = R.choice(APTOS)
        elif t in ("garage", "shed", "roof"):
            continue
        else:
            modelo = min(CASAS, key=lambda m: abs(tam(m)[0] * tam(m)[1] - area_m2) + R.random() * 20)
        w, d = tam(modelo)
        ang = math.atan2(frente[1], frente[0]) - math.pi / 2
        if not livre(cx, cz, ang, w, d):
            continue
        ox, oz = desloc(modelo)
        c, s_ = math.cos(ang), math.sin(ang)
        z = zona(cx, cz)
        predios.append({"p": cantos(cx, cz, ang, w, d), "tipo": "house" if modelo in CASA_US else "commercial", "andares": 0,
                        "altura": 0, "nome": "", "uso": z, "modelo": modelo,
                        "c": [round(cx - (c * ox - s_ * oz), 2), round(cz - (s_ * ox + c * oz), 2)],
                        "frente": [round(frente[0], 4), round(frente[1], 4)]})
        reserva(cx, cz, w, d, ang)
        feitos += 1
    return feitos


def acha_lote(modelo, uso, tipos_rua=("tertiary", "secondary", "primary", "residential")):
    """Primeiro lugar livre na beira de uma rua (raids e marcos do jogo que a cidade real não tem)."""
    w, d = tam(modelo)
    for tr in tipos_rua:
        for r in ruas:
            if r["tipo"] != tr:
                continue
            meia = LARG[tr] / 2 + CALCADA
            L_ = comprimento(r["p"])
            t = 10.0
            while t < L_ - 10:
                p, ang_r = ponto_em(r["p"], t)
                for lado in (1, -1):
                    nx, nz = -math.sin(ang_r) * lado, math.cos(ang_r) * lado
                    cx, cz = p[0] + nx * (meia + 1.0 + d / 2), p[1] + nz * (meia + 1.0 + d / 2)
                    ang = math.atan2(-nz, -nx) - math.pi / 2
                    if livre(cx, cz, ang, w, d):
                        predio(modelo, cx, cz, (-nx, -nz), uso)
                        return (cx, cz)
                t += 7.0
    return None


def perto_rio(p, folga):
    return any(dist_seg(p, a, b) < RIO_LARG / 2 + folga for a, b in zip(rio, rio[1:]))


def no_morro(p, folga=0.0):
    return math.dist(p, MORRO["p"]) < MORRO["raio"] + folga


def zona(x, z):
    if SENOIA:
        return "centro" if (-90 < x < 60 and 110 < z < 340) else "casas"
    if no_morro((x, z), -4):
        return "parque"
    if (z > 268 and x > -40) or (x > 255 and 60 < z < 268):
        return "industrial"
    if -95 < x < 155 and -180 < z < 100:
        return "centro"
    return "casas"


# ---------------- ruas (grade americana) ----------------
ruas_osm()


# ---------------- lugares marcados (reservam o chão) ----------------
def reserva(cx, cz, w, d, ang=0.0):
    ocupado.append((cx, cz, ang, w, d))


def predio(modelo, cx, cz, frente, uso, tipo="commercial"):
    """Construção num lugar escolhido: `frente` = direção (x, z) para onde a fachada olha."""
    w, d = MED[modelo]
    ang = math.atan2(frente[1], frente[0]) - math.pi / 2  # +z local do lote = frente
    reserva(cx, cz, w, d, ang)
    predios.append({"p": cantos(cx, cz, ang, w, d), "tipo": tipo, "andares": 0, "altura": 0, "nome": "", "uso": uso,
                    "modelo": modelo, "c": [round(cx, 2), round(cz, 2)], "frente": [round(frente[0], 4), round(frente[1], 4)]})


# Vegetação pronta (scripts/vegetacao.gd, Etapa D 05/11): "arvore_k" vira uma espécie da zona, com mato embaixo.
# Rng próprio: escolher a espécie não muda o sorteio do resto da cidade.
RV = random.Random(2077)
VEG = {
    "parque": [("conifera_1", 3), ("conifera_2", 3), ("conifera_3", 3), ("conifera_4", 2), ("conifera_5", 3),
               ("conifera_6", 3), ("abeto_1", 3), ("abeto_3", 2), ("pinheiro", 2), ("outono_1", 1), ("outono_2", 1),
               ("betula", 1)],
    "casas": [("arvore", 4), ("betula", 3), ("outono_1", 2), ("outono_2", 2), ("outono_3", 2), ("pinheiro", 1),
              ("abeto_1", 1), ("arvore_morta", 2), ("arvore_velha", 1)],
    "centro": [("arvore", 3), ("betula", 2), ("outono_3", 1), ("arvore_morta", 2)],
    "industrial": [("arvore_morta", 3), ("arvore_velha", 2), ("toco", 1), ("outono_2", 1), ("abeto_2", 1)],
}
SUB = {  # perto do pé da árvore
    "parque": ["pinheirinho", "abeto_baixo", "arbusto", "arbusto_2", "pedras", "pedras_2", "samambaia",
               "samambaia_baixa", "capim_alto"],
    "casas": ["moita", "arbusto", "capim", "arbusto_2"],
    "centro": ["moita", "capim_seco"],
    "industrial": ["capim_seco", "capim_seco", "moita", "pedras_2"],
}


def sorteia(lista):
    t = RV.uniform(0, sum(p for _, p in lista))
    for nome, p in lista:
        t -= p
        if t <= 0:
            return nome
    return lista[-1][0]


def prop(m, x, z, r=0.0):
    if m.startswith("arvore_"):
        zn = zona(x, z)
        m = "veg:" + sorteia(VEG[zn])
        for k in range(RV.randint(2, 4) if zn == "parque" else RV.randint(0, 1)):
            a, d = RV.uniform(0, math.tau), RV.uniform(1.2, 4.0)
            q = (x + math.cos(a) * d, z + math.sin(a) * d)
            if not perto_rua(q, 1.5) and not perto_rio(q, 1.0) and abs(q[0]) < LIM and abs(q[1]) < LIM:
                props.append({"m": "veg:" + RV.choice(SUB[zn]), "p": [round(q[0], 2), round(q[1], 2)],
                              "r": round(RV.uniform(0, 6.28), 3)})
    props.append({"m": m, "p": [round(x, 2), round(z, 2)], "r": round(r, 3)})


def area(poly, m):
    areas.append({"p": [[round(a, 2), round(b, 2)] for a, b in poly], "m": m})


def ret(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


# ---------------- lotes ao longo das ruas ----------------
SOBRADOS = sorted([k for k in MED if k.startswith("sobrado_")], key=lambda k: int(k.split("_")[1]))
APTOS = [k for k in MED if k.startswith("apto_")]
# casa americana: (largura do corpo, fundo, garagem à esquerda, varanda na frente) = tools/blender/casas_us.py
CASA_US = {"casa_us_1": (13.0, 10.0, True, True), "casa_us_2": (14.5, 12.0, True, True), "casa_us_3": (12.0, 10.0, False, True),
           "casa_us_4": (15.0, 12.0, True, False), "casa_us_5": (12.5, 10.0, True, True), "casa_us_6": (13.5, 11.5, False, True)}
CASAS = list(CASA_US)
QUEIMADAS = ["casa_us_q1", "casa_us_q2"]  # pegaram fogo (ainda ardem no jogo): 7% dos lotes
CASA_US.update({"casa_us_q1": (13.0, 10.0, True, True), "casa_us_q2": (12.0, 10.0, False, True)})
RUINA_BLOCO = ["loja_r1", "loja_r1", "loja_r2", "loja_r2", "predio_r1"]
n_sobrado = 0
ruina_feita = False
bloco = []


def tam(modelo):
    if modelo in CASA_US:
        w, d, g, v = CASA_US[modelo]
        return w + (3.8 if g else 0.0) + 0.3, d + (2.6 if v else 0.0) + 0.3
    return tuple(MED[modelo])


def desloc(modelo):
    """Centro do retângulo da casa em relação à origem do modelo (x, z local; +z = frente)."""
    if modelo in CASA_US:
        w, d, g, v = CASA_US[modelo]
        return -(3.8 if g else 0.0) / 2, (2.6 if v else 0.0) / 2
    return 0.0, 0.0


def livre(cx, cz, ang, w, d):
    cs = cantos(cx, cz, ang, w, d)
    if any(abs(c[0]) > LIM or abs(c[1]) > LIM for c in cs):
        return False
    if any(perto_rua(c, 0.0) or perto_rio(c, 4.0) for c in cs) or perto_rua((cx, cz), 0.0):
        return False
    if any(no_morro(c, 2.0) for c in cs):
        return False
    novo = (cx, cz, ang, w, d)
    return not any(sobrepoe(novo, o) for o in ocupado if math.dist(o[:2], novo[:2]) < 60)


def cerca(cx, cz, ang, w_lote, d_lote, frente_baixa, cor):
    """Cerca do lote americano: fundo e lados de tábua (1,8 m, privacidade); na frente às vezes cerquinha baixa."""
    c, s = math.cos(ang), math.sin(ang)
    def m(x, z):
        return [round(cx + c * x - s * z, 2), round(cz + s * x + c * z, 2)]
    hw, hd = w_lote / 2, d_lote / 2
    for (a, b) in (((hw, hd - 9.0), (hw, -hd)), ((hw, -hd), (-hw, -hd)), ((-hw, -hd), (-hw, hd - 9.0))):
        muros.append({"a": m(*a), "b": m(*b), "alt": 1.8, "cor": cor})
    if frente_baixa:
        muros.append({"a": m(-hw, hd), "b": m(-hw + w_lote * 0.35, hd), "alt": 0.9, "cor": 4, "grade": False})
        muros.append({"a": m(hw - w_lote * 0.35, hd), "b": m(hw, hd), "alt": 0.9, "cor": 4, "grade": False})


def enche(pts, lado, zona_ok=None):
    """Lotes num lado da rua (lado: 1 = direita de quem anda do começo ao fim)."""
    global n_sobrado, ruina_feita, bloco
    tipo_rua = next(r["tipo"] for r in ruas if r["p"] is pts)
    L = comprimento(pts)
    t = R.uniform(1.0, 4.0)
    meia = LARG[tipo_rua] / 2 + (0 if tipo_rua in ("service", "viela") else CALCADA)
    while t < L - 4:
        p, ang_r = ponto_em(pts, t)
        if p is None:
            break
        nx, nz = -math.sin(ang_r) * lado, math.cos(ang_r) * lado
        z = zona(p[0] + nx * 10, p[1] + nz * 10)
        if z == "parque" or (zona_ok and z not in zona_ok):
            t += 4.0
            continue
        frente = (-nx, -nz)
        ang = math.atan2(frente[1], frente[0]) - math.pi / 2
        if z == "centro":
            if not ruina_feita and tipo_rua == "tertiary" and t > 30:
                bloco = list(RUINA_BLOCO)
                ruina_feita = True
            if not bloco and R.random() < 0.12 and tipo_rua != "primary":  # estacionamento entre as lojas
                larg_e = R.uniform(10, 16)
                q0 = (p[0] + nx * (meia + 0.1), p[1] + nz * (meia + 0.1))
                q1 = (q0[0] + math.cos(ang_r) * larg_e, q0[1] + math.sin(ang_r) * larg_e)
                area([q0, q1, (q1[0] + nx * 14, q1[1] + nz * 14), (q0[0] + nx * 14, q0[1] + nz * 14)], "asfalto")
                if R.random() < 0.6:
                    veiculos.append({"m": R.choice(["carro_r1", "carro_r2"]), "p": [round((q0[0] + q1[0]) / 2 + nx * 6, 2), round((q0[1] + q1[1]) / 2 + nz * 6, 2)],
                                     "r": round(ang_r + R.uniform(-0.3, 0.3), 3)})
                t += larg_e + 1.0
                continue
            modelo = bloco[0] if bloco else (R.choice(APTOS) if R.random() < 0.15 else SOBRADOS[n_sobrado % len(SOBRADOS)])
            recuo, vao = 0.15, (R.choice([0.0, 0.0, 0.0, 0.55, 2.4]) if not bloco else R.uniform(1.6, 3.0))
        elif z == "industrial":
            modelo = R.choice(["galpao_r1", "galpao_r2"])
            recuo, vao = R.uniform(6, 10), R.uniform(16, 28)
        else:
            if R.random() < 0.12:  # terreno baldio: mato e árvore no lugar da casa
                for k in range(R.randint(1, 3)):
                    q = (p[0] + nx * (meia + R.uniform(6, 20)) + math.cos(ang_r) * R.uniform(3, 15),
                         p[1] + nz * (meia + R.uniform(6, 20)) + math.sin(ang_r) * R.uniform(3, 15))
                    if not perto_rua(q, 2.0) and not perto_rio(q, 4.0) and abs(q[0]) < LIM and abs(q[1]) < LIM:
                        prop(R.choice(["arvore_1", "arvore_2", "arvore_3"]), q[0], q[1], R.uniform(0, 6.28))
                t += 18.0
                continue
            modelo = R.choice(QUEIMADAS) if R.random() < 0.07 else R.choice(CASAS)
            recuo, vao = R.uniform(7.5, 9.0), 0.0
        w, d = tam(modelo)
        casa = modelo in CASA_US
        lado_w = R.uniform(4.0, 6.5) if casa else 0.0
        w_lote = w + 2 * lado_w
        off = meia + 0.1 + recuo + d / 2
        rcx = p[0] + nx * off + math.cos(ang_r) * w_lote / 2
        rcz = p[1] + nz * off + math.sin(ang_r) * w_lote / 2
        if casa:
            d_lote = recuo + d + R.uniform(9.0, 14.0)  # quintal de trás
            lcx = p[0] + nx * (meia + 0.1 + d_lote / 2) + math.cos(ang_r) * w_lote / 2
            lcz = p[1] + nz * (meia + 0.1 + d_lote / 2) + math.sin(ang_r) * w_lote / 2
            ok = livre(lcx, lcz, ang, w_lote, d_lote)
        else:
            ok = livre(rcx, rcz, ang, w, d)
        if not ok and bloco and modelo == bloco[0]:
            modelo = SOBRADOS[n_sobrado % len(SOBRADOS)]
            w, d = tam(modelo)
            vao = 0.0
            off = meia + 0.1 + recuo + d / 2
            rcx = p[0] + nx * off + math.cos(ang_r) * w / 2
            rcz = p[1] + nz * off + math.sin(ang_r) * w / 2
            w_lote = w
            ok = livre(rcx, rcz, ang, w, d)
        if not ok:
            t += 3.0 if z != "centro" else 1.0
            continue
        ox, oz = desloc(modelo)
        c, s = math.cos(ang), math.sin(ang)
        mx, mz = rcx - (c * ox - s * oz), rcz - (s * ox + c * oz)   # origem do modelo
        tipo = {"centro": "commercial", "industrial": "industrial"}.get(z, "house")
        predios.append({"p": cantos(rcx, rcz, ang, w, d), "tipo": tipo, "andares": 0, "altura": 0, "nome": "", "uso": z,
                        "modelo": modelo, "c": [round(mx, 2), round(mz, 2)], "frente": [round(frente[0], 4), round(frente[1], 4)]})
        if modelo.startswith("sobrado_"):
            n_sobrado += 1
        if bloco and modelo == bloco[0]:
            bloco.pop(0)
        if casa:
            reserva(lcx, lcz, w_lote, d_lote, ang)
            cerca(lcx, lcz, ang, w_lote, d_lote, R.random() < 0.25, R.choice([0, 3, 4]))
            fx0 = p[0] + nx * (meia + 0.2) ; fz0 = p[1] + nz * (meia + 0.2)
            # gramado da frente (do meio-fio até a casa)
            q = [(fx0, fz0), (fx0 + math.cos(ang_r) * w_lote, fz0 + math.sin(ang_r) * w_lote)]
            q += [(q[1][0] + nx * (recuo - 0.3), q[1][1] + nz * (recuo - 0.3)), (q[0][0] + nx * (recuo - 0.3), q[0][1] + nz * (recuo - 0.3))]
            area(q, "grama")
        else:
            reserva(rcx, rcz, w, d, ang)
            if z == "centro" and 0.4 < vao < 1.0:
                fx, fz = p[0] + math.cos(ang_r) * (w + vao / 2), p[1] + math.sin(ang_r) * (w + vao / 2)
                a = (fx + nx * (meia + 0.6), fz + nz * (meia + 0.6))
                b = (fx + nx * (meia + d - 0.5), fz + nz * (meia + d - 0.5))
                frestas.append({"a": [round(a[0], 2), round(a[1], 2)], "b": [round(b[0], 2), round(b[1], 2)], "larg": vao, "_pend": True})
        t += w_lote + vao


if SENOIA:
    print("predios reais do OSM:", predios_osm())
    for modelo, uso in (("delegacia", "centro"), ("hospital", "centro"), ("mercado", "centro"), ("escola", "casas")):
        if not any(pp["modelo"] == modelo for pp in predios):
            print(modelo, acha_lote(modelo, uso))
for r in list(ruas):
    if r["tipo"] in ("primary", "secondary", "tertiary"):
        for lado in (1, -1):
            enche(r["p"], lado)
for r in list(ruas):
    if r["tipo"] in ("residential", "service"):
        for lado in (1, -1):
            enche(r["p"], lado)
frestas = [{k: v for k, v in f.items() if k != "_pend"} for f in frestas
           if sum(1 for o in ocupado if math.dist(o[:2], ((f["a"][0] + f["b"][0]) / 2, (f["a"][1] + f["b"][1]) / 2)) < 9) >= 2]
# mata em Raven Hill (floresta de coníferas: as do pacote têm poucos triângulos)
for k in range(700):
    a, r = R.uniform(0, math.tau), MORRO["raio"] * math.sqrt(R.random())
    q = (MORRO["p"][0] + math.cos(a) * r, MORRO["p"][1] + math.sin(a) * r)
    if abs(q[0]) < LIM and abs(q[1]) < LIM and math.dist(q, MORRO["p"]) > 9 and not perto_rua(q, 2.0):
        prop(R.choice(["arvore_1", "arvore_2", "arvore_2", "arvore_3"]), q[0], q[1], R.uniform(0, 6.28))


# ---------------- coisas de rua ----------------
def cruzamentos():
    """Pontos onde duas ruas de carro se encontram (para faixa de pedestre e para não pôr poste no meio)."""
    out = []
    grandes = [r for r in ruas if r["tipo"] in ("primary", "secondary", "tertiary")]
    for i, r in enumerate(grandes):
        for o in grandes[i + 1:]:
            for a, b in zip(r["p"], r["p"][1:]):
                for c, d in zip(o["p"], o["p"][1:]):
                    den = (b[0] - a[0]) * (d[1] - c[1]) - (b[1] - a[1]) * (d[0] - c[0])
                    if abs(den) < 1e-9:
                        continue
                    ta = ((c[0] - a[0]) * (d[1] - c[1]) - (c[1] - a[1]) * (d[0] - c[0])) / den
                    tb = ((c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])) / den
                    if not (-0.3 <= ta <= 1.3 and -0.3 <= tb <= 1.3):
                        continue
                    x = (a[0] + (b[0] - a[0]) * ta, a[1] + (b[1] - a[1]) * ta)
                    if dist_seg(x, a, b) < 3 and dist_seg(x, c, d) < 3 and not any(math.dist(x, q[0]) < 10 for q in out):
                        out.append((x, r, o))
    return out


CRUZ = cruzamentos()
for (x, r, o) in CRUZ:
    if zona(*x) != "centro":
        continue
    for rr, oo in ((r, o), (o, r)):
        pts = rr["p"]
        # acha o t do cruzamento nessa rua
        best, tb = 1e9, 0.0
        acc = 0.0
        for a, b in zip(pts, pts[1:]):
            dd = dist_seg(x, a, b)
            if dd < best:
                best = dd
                tb = acc + math.dist(a, x)
            acc += math.dist(a, b)
        for s in (-1, 1):
            tt = tb + s * (LARG[oo["tipo"]] / 2 + CALCADA + 2.5)
            p, a = ponto_em(pts, tt)
            if p is not None and not perto_rio(p, 6):
                faixas.append({"p": [round(p[0], 2), round(p[1], 2)], "ang": round(a, 3), "larg": LARG[rr["tipo"]]})


def corrente_postes(pts, tipo, lado):
    """Postes num lado da rua a cada ~32 m (pula cruzamento e rio); a fiação liga os vizinhos da mesma corrente."""
    cadeia = []
    L = comprimento(pts)
    t = R.uniform(4, 16)
    n = 0
    while t < L - 3:
        p, a = ponto_em(pts, t)
        nx, nz = -math.sin(a) * lado, math.cos(a) * lado
        q = (p[0] + nx * (LARG[tipo] / 2 + 1.0), p[1] + nz * (LARG[tipo] / 2 + 1.0))
        ruim = perto_rio(q, 4) or any(math.dist(q, c[0]) < 12 for c in CRUZ) or abs(q[0]) > LIM or abs(q[1]) > LIM \
            or any(sobrepoe((q[0], q[1], 0, 0.5, 0.5), o) for o in ocupado if math.dist(o[:2], q) < 30)
        if ruim:
            if len(cadeia) > 1:
                postes.append(cadeia)
            cadeia = []
        else:
            n += 1
            cadeia.append([round(q[0], 2), round(q[1], 2), round(math.atan2(-nx, -nz), 3), 1 if n % 4 == 0 else 0])  # braço da luz para a rua
        t += 32.0
    if len(cadeia) > 1:
        postes.append(cadeia)


for r in ruas:
    if r["tipo"] in ("primary", "secondary", "tertiary", "residential"):
        corrente_postes(r["p"], r["tipo"], 1 if len(postes) % 2 else -1)

# árvores nas calçadas das ruas de casa e pontos de ônibus/orelhões nas grandes
for r in ruas:
    L = comprimento(r["p"])
    if r["tipo"] == "residential":
        t = R.uniform(5, 15)
        while t < L - 5:
            p, a = ponto_em(r["p"], t)
            lado = R.choice((-1, 1))
            nx, nz = -math.sin(a) * lado, math.cos(a) * lado
            q = (p[0] + nx * (LARG["residential"] / 2 + 1.1), p[1] + nz * (LARG["residential"] / 2 + 1.1))
            if not perto_rio(q, 4) and not any(math.dist(q, c[0]) < 10 for c in CRUZ) and zona(*q) != "parque" \
                    and not any(sobrepoe((q[0], q[1], 0, 0.6, 0.6), o) for o in ocupado if math.dist(o[:2], q) < 30) \
                    and not any(math.dist(q, pp[:2]) < 3 for c in postes for pp in c):
                prop(R.choice(["arvore_1", "arvore_2", "arvore_1", "arvore_2", "arvore_3"]), q[0], q[1], R.uniform(0, 6.28))
            t += R.uniform(16, 30)
    elif r["tipo"] in ("primary", "secondary"):
        t = R.uniform(30, 60)
        while t < L - 10:
            p, a = ponto_em(r["p"], t)
            lado = R.choice((-1, 1))
            nx, nz = -math.sin(a) * lado, math.cos(a) * lado
            q = (p[0] + nx * (LARG[r["tipo"]] / 2 + 1.0), p[1] + nz * (LARG[r["tipo"]] / 2 + 1.0))
            if not perto_rio(q, 5) and not any(math.dist(q, c[0]) < 12 for c in CRUZ) and abs(q[0]) < LIM and abs(q[1]) < LIM \
                    and not any(math.dist(q, pp[:2]) < 4 for c in postes for pp in c):
                m = R.choice(["ponto_onibus", "orelhao", "ponto_onibus", "banca"])
                # o ponto de ônibus olha para a rua (frente +z do modelo para dentro da rua)
                prop(m, q[0], q[1], math.atan2(-nx, -nz) + (0 if m == "ponto_onibus" else math.pi))  # banca e orelhão para a calçada
            t += R.uniform(70, 120)

# terreno baldio tomado pelo mato: árvores vivas e secas onde não tem nada
feitas = 0
for k in range(3000):
    if feitas >= 140:
        break
    q = (R.uniform(-LIM, LIM), R.uniform(-LIM, LIM))
    if perto_rua(q, 3.0) or perto_rio(q, 5.0) or no_morro(q, 2.0) \
            or any(sobrepoe((q[0], q[1], 0, 3.0, 3.0), o) for o in ocupado if math.dist(o[:2], q) < 40) \
            or any(math.dist(q, pr["p"]) < 5 for pr in props):
        continue
    feitas += 1
    prop(R.choice(["arvore_1", "arvore_2", "arvore_2", "arvore_3"]), q[0], q[1], R.uniform(0, 6.28))

# beira do riacho: capim alto, samambaia e pedras nas duas margens
for a, b in zip(rio, rio[1:]):
    L = math.dist(a, b)
    ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    for k in range(int(L / 2.5)):
        t = RV.uniform(0, L)
        lado = RV.choice((-1, 1))
        d = RIO_LARG / 2 + RV.uniform(0.3, 4.5)
        q = (a[0] + ux * t - uz * lado * d, a[1] + uz * t + ux * lado * d)
        if abs(q[0]) < LIM and abs(q[1]) < LIM and not perto_rua(q, 2.0) \
                and not any(sobrepoe((q[0], q[1], 0, 1.0, 1.0), o) for o in ocupado if math.dist(o[:2], q) < 30):
            props.append({"m": "veg:" + RV.choice(["capim_alto", "capim_alto", "samambaia", "samambaia_baixa", "capim",
                                                   "arbusto", "pedras_2"]),
                          "p": [round(q[0], 2), round(q[1], 2)], "r": round(RV.uniform(0, 6.28), 3)})

# ---------------- a capital destruída ao longe (norte, depois do muro): só silhueta ----------------
for (x, z, b, rot) in ((-480, 640, "building_03", 0.3), (-300, 700, "building_07", 0.0), (-120, 620, "building_01", 0.5),
                       (40, 720, "building_06", 0.1), (200, 640, "building_05", 0.8), (360, 700, "building_02", 0.2),
                       (520, 620, "building_04", 0.6)):
    longe.append({"c": "res://assets/catalogo/majadroid/%s.glb" % b, "p": [x, -z], "r": rot})

out = {"origem": "Senoia, GA (OpenStreetMap, ODbL; tools/mapa/raven_creek.py CIDADE=senoia)" if SENOIA else "Raven Creek (tools/mapa/raven_creek.py)", "ruas": ruas, "predios": predios, "frestas": frestas, "bloqueios": bloqueios,
       "marcos": marcos, "muros": muros, "props": props, "areas": areas, "faixas": faixas, "postes": postes, "veiculos": veiculos,
       "zumbis": zumbis, "longe": longe,
       "terreno": {"rio": {"p": rio, "larg": RIO_LARG, "fundo": 2.2, "agua": 1.5}, "morros": [MORRO]}}
json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "assets/mapa/cidade.json", "w"))
cont = {}
for p in predios:
    k = p["modelo"].split("_")[0] if not p["modelo"].startswith("casa_us") else "casa_us"
    cont[k] = cont.get(k, 0) + 1
print("ruas", len(ruas), "predios", len(predios), cont, "muros", len(muros), "props", len(props), "postes", sum(len(c) for c in postes),
      "faixas", len(faixas), "frestas", len(frestas))
