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
# GALENA (13/11, dono: "quero um mapa completamente diferente... ruas com posicionamentos melhores"): a planta passa a ser
# Galena, Illinois (centro antigo de tijolo na Main Street em diagonal, o Galena River atravessando a cidade, igrejas nos
# morros), do OpenStreetMap (tools/mapa/osm/galena.json, ODbL). Na história a cidade continua se chamando Senoia.
CIDADE = os.environ.get("CIDADE", "floresta")
GALENA = CIDADE == "galena"
# FLORESTA (13/11, dono: "não vai ser mais cidade, só uma pequena parte; um bioma de floresta gigante com raids na
# floresta"): o pedaço de South LA em volta do cruzamento (CORTE m para cada lado) vira a cidadezinha no sudoeste
# (centro em OFF); o resto do quadrado é mata fechada com estradas de terra, um rio com ponte, um morro e os lugares
# de raid (acampamento militar, helicóptero caído, cabana do caçador, posto florestal, serraria).
FLORESTA = CIDADE == "floresta"
OFF = (-300.0, 300.0)
CORTE = 150.0
if FLORESTA:
    CIDADE = "la"
# LOS ANGELES (13/11, dono: bairro de subúrbio de LA no clima dos mods de zumbi do GTA 5, mas original): ruas e casas
# reais de South LA em volta do cruzamento da Vermont Avenue com a Slauson Avenue (tools/mapa/osm/la.json, OSM ODbL).
# Comércio nas duas avenidas, casas baixas de reboco pastel, becos (alley) atrás dos lotes, palmeiras. Sem rio nem morro.
LA = CIDADE == "la"
if LA:
    OSM_LAT0, OSM_LON0 = 33.9890, -118.2915
    OSM = json.load(open("tools/mapa/osm/la.json"))["elements"]
    rio = [[-600.0, 2000.0], [600.0, 2000.0]]
    MORRO = {"p": [2000, 2000], "raio": 10.0, "alt": 0.0}
if FLORESTA:  # rio raso cortando a mata de nordeste a oeste (passa ao norte da cidadezinha) e um morro no noroeste
    rio = catmull([(530, -280), (330, -170), (170, -40), (40, 70), (-110, 110), (-300, 105), (-530, 80)], 8.0)
    RIO_LARG = 12.0
    MORRO = {"p": [-330, -270], "raio": 110.0, "alt": 16.0}
if GALENA:
    OSM_LAT0, OSM_LON0 = 42.4160, -90.4295
    OSM = json.load(open("tools/mapa/osm/galena.json"))["elements"]
    RIO_LARG = 22.0
    rio = []
    for e in OSM:
        if e.get("tags", {}).get("waterway") == "river":
            rio = [[round((g["lon"] - OSM_LON0) * 111320 * math.cos(math.radians(OSM_LAT0)), 2), round(-(g["lat"] - OSM_LAT0) * 110540, 2)]
                   for g in e["geometry"]]
    rio = [q for q in rio if abs(q[0]) < LIM + 120 and abs(q[1]) < LIM + 120]
    MORRO = {"p": [-390, -330], "raio": 90.0, "alt": 12.0}  # o morro (bluff) do noroeste, com mata


def osm_xy(g):
    if FLORESTA:  # só o pedaço da cidade, levado para OFF; o resto fica fora do mapa (as ruas e prédios são cortados)
        x = (g["lon"] - OSM_LON0) * 111320 * math.cos(math.radians(OSM_LAT0))
        z = -(g["lat"] - OSM_LAT0) * 110540
        if abs(x) > CORTE or abs(z + 16.0) > CORTE:
            return (9999.0, 9999.0)
        return (round(x + OFF[0], 2), round(z + 16.0 + OFF[1], 2))
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
        if e["tags"].get("amenity") == "place_of_worship":
            t = "church"
        if GALENA and no_morro(osm_xy(e["geometry"][0]), 4.0):
            continue  # o morro é mata
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
            if LA and R.random() < 0.6:
                continue  # 13/11 celular: os prédios baixos de apartamento de LA ocupam metade dos lotes; ficam 40%
            modelo = R.choice(APTOS)
        elif t in ("garage", "shed", "roof"):
            continue
        elif R.random() < (0.55 if LA else 0.25):  # LA: lotes muito juntos; quase metade virou terreno vazio
            continue  # 06/11 terror: 1 em 4 casas reais do OSM não está mais lá (cidade mais vazia e silenciosa)
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
    if FLORESTA:
        if abs(x - OFF[0]) > CORTE + 5 or abs(z - OFF[1]) > CORTE + 5:
            return "parque"  # a mata (árvores do parque: coníferas)
        return "centro" if abs(x - OFF[0]) < 45 or abs(z - OFF[1]) < 45 else "casas"
    if LA:  # comércio de frente para a Vermont (x = 0) e a Slauson (z = -16)
        return "centro" if abs(x) < 45 or abs(z + 16) < 45 else "casas"
    if GALENA:  # centro = a faixa da Main Street (diagonal, do sudoeste ao nordeste)
        if no_morro((x, z), -4):
            return "parque"
        return "centro" if dist_seg((x, z), (-60.0, 180.0), (310.0, -155.0)) < 75 else "casas"
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
if GALENA:  # ponte inventada: o OSM não tem rua cruzando o rio dentro do quadrado (o leste ficava ilhado)
    rua([(184.0, 105.0), (262.0, 190.0), (338.0, 279.0)], "tertiary", False)


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
if LA:  # 13/11: palmeiras na rua e no quintal (LA); umas mortas e velhas no meio
    VEG["casas"] = [("palmeira_alta", 5), ("palmeira", 3), ("arvore", 2), ("arvore_morta", 2), ("arvore_velha", 1)]
    VEG["centro"] = [("palmeira_alta", 5), ("palmeira", 2), ("arvore_morta", 1)]
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
           "casa_us_4": (15.0, 12.0, True, False), "casa_us_5": (12.5, 10.0, True, True), "casa_us_6": (13.5, 11.5, False, True),
           # 13/11: plantas novas (casas_us.py PLANTAS): sala e cozinha juntas, escritório, espelhadas (garagem à direita)
           "casa_us_7": (14.0, 11.0, True, True), "casa_us_8": (13.0, 10.5, True, True), "casa_us_9": (15.0, 12.5, True, True),
           "casa_us_10": (12.5, 11.0, False, True)}
ESPELHADAS = {"casa_us_8", "casa_us_9"}
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
        return (1 if modelo in ESPELHADAS else -1) * (3.8 if g else 0.0) / 2, (2.6 if v else 0.0) / 2
    return 0.0, 0.0


# Entrada (06/11, HISTORIA.md): você chega de carro pela estrada do leste. Os primeiros RURAL metros dela ficam sem
# casa (mato e árvore dos dois lados) e a placa WELCOME TO SENOIA fica no fim desse trecho.
ENTRADA = (480.0, 88.0)
ENTRADA_DIR = (-0.9967, -0.0812)   # para dentro da cidade (a estrada do leste é quase reta)
RURAL = 175.0
if FLORESTA:  # chega pela estrada do oeste, que vira a avenida da cidadezinha
    ENTRADA = (-480.0, OFF[1])
    ENTRADA_DIR = (1.0, 0.0)
    RURAL = 25.0
elif LA:  # chega pela Vermont Avenue, que entra pela borda sul
    ENTRADA = (0.0, 480.0)
    ENTRADA_DIR = (0.0, -1.0)
    RURAL = 40.0
if GALENA:  # chega pela South Main Street, que entra pela borda sul
    ENTRADA = (-122.0, 480.0)
    ENTRADA_DIR = (0.2, -0.98)
    RURAL = 60.0


def livre(cx, cz, ang, w, d):
    if math.dist((cx, cz), ENTRADA) < RURAL:
        return False
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
                    veiculos.append({"m": R.choice(["carro_r1", ("mundo:queimado", "mundo:ferrugem")[len(veiculos) % 2]]), "p": [round((q0[0] + q1[0]) / 2 + nx * 6, 2), round((q0[1] + q1[1]) / 2 + nz * 6, 2)],
                                     "r": round(ang_r + R.uniform(-0.3, 0.3), 3)})
                t += larg_e + 1.0
                continue
            modelo = bloco[0] if bloco else (R.choice(APTOS) if R.random() < 0.15 else SOBRADOS[n_sobrado % len(SOBRADOS)])
            recuo, vao = 0.15, (R.choice([0.0, 0.0, 0.0, 0.55, 2.4]) if not bloco else R.uniform(1.6, 3.0))
        elif z == "industrial":
            modelo = R.choice(["galpao_r1", "galpao_r2"])
            recuo, vao = R.uniform(6, 10), R.uniform(16, 28)
        else:
            if R.random() < 0.3:  # terreno baldio (06/11 terror: 30%, cidade mais vazia): mato e árvore no lugar da casa
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
for r in ([] if LA else list(ruas)):  # LA: o OSM já tem todos os prédios; encher lote só pesava
    if r["tipo"] in ("primary", "secondary", "tertiary"):
        for lado in (1, -1):
            enche(r["p"], lado)
for r in ([] if LA else list(ruas)):
    if r["tipo"] in ("residential", "service"):
        for lado in (1, -1):
            enche(r["p"], lado)
if LA:  # 13/11: fileira de palmeiras na beira da calçada (a cara de LA), uma a cada ~24 m, falhando aqui e ali
    for r in ruas:
        if r["tipo"] not in ("primary", "tertiary", "residential") or zona(*r["p"][len(r["p"]) // 2]) == "parque":
            continue
        meia = LARG[r["tipo"]] / 2 + CALCADA + 0.6
        L_ = comprimento(r["p"])
        t = RV.uniform(6, 18)
        while t < L_ - 6:
            p, ang_r = ponto_em(r["p"], t)
            for lado in (1, -1):
                q = (p[0] - math.sin(ang_r) * lado * meia, p[1] + math.cos(ang_r) * lado * meia)
                if p is not None and RV.random() < 0.7 and abs(q[0]) < LIM - 2 and abs(q[1]) < LIM - 2 and not perto_rua(q, 0.3) \
                        and not any(math.dist(q, o[:2]) < max(o[3], o[4]) / 2 + 1.0 for o in ocupado if math.dist(q, o[:2]) < 25):
                    props.append({"m": "veg:" + RV.choice(["palmeira_alta", "palmeira_alta", "palmeira"]), "p": [round(q[0], 2), round(q[1], 2)],
                                  "r": round(RV.uniform(0, 6.28), 3)})
            t += RV.uniform(20, 28)
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

# acidentes (06/11, noite de terror): nos cruzamentos e no meio das ruas, 2-3 carros batidos atravessados (carcaça pronta,
# queimado, van), com zumbi em volta; a fuga da cidade parou aqui
RA = random.Random(1666)
acid = 0
for tent in range(400):
    if acid >= 26:
        break
    r = RA.choice([r for r in ruas if r["tipo"] in ("tertiary", "residential", "secondary", "primary")])
    L = comprimento(r["p"])
    if L < 40:
        continue
    p, a = ponto_em(r["p"], RA.uniform(15, L - 15))
    if p is None or math.dist(p, ENTRADA) < RURAL + 20 or any(math.dist(p, v["p"]) < 25 for v in veiculos):
        continue
    acid += 1
    for k in range(RA.randint(2, 3)):
        ang = a + RA.choice([0.0, math.pi]) + RA.uniform(-1.1, 1.1)
        q = (p[0] + math.cos(a) * (k * 3.2 - 3) + RA.uniform(-1, 1), p[1] + math.sin(a) * (k * 3.2 - 3) + RA.uniform(-1, 1))
        veiculos.append({"m": RA.choice(["mundo:carcaca", "mundo:ferrugem", "mundo:queimado", "mundo:van"]), "p": [round(q[0], 2), round(q[1], 2)],
                         "r": round(math.pi / 2 - ang, 3), "cor": [round(RA.uniform(0.1, 0.5), 2), round(RA.uniform(0.1, 0.4), 2), round(RA.uniform(0.1, 0.4), 2)]})
    zumbis.append([round(p[0] + RA.uniform(-4, 4), 2), round(p[1] + RA.uniform(-4, 4), 2)])

# estrada da entrada: árvores e mato dos dois lados, a placa e o carro de quem chega
for k in range(60):
    t = RV.uniform(5, RURAL - 10)
    lado = RV.choice((-1, 1))
    off = RV.uniform(8, 26)
    q = (ENTRADA[0] + ENTRADA_DIR[0] * t - ENTRADA_DIR[1] * lado * off, ENTRADA[1] + ENTRADA_DIR[1] * t + ENTRADA_DIR[0] * lado * off)
    if not perto_rua(q, 2.0) and abs(q[0]) < LIM and abs(q[1]) < LIM:
        props.append({"m": "veg:" + RV.choice(["palmeira_alta", "palmeira", "arvore_morta", "palmeira_alta"] if LA else ["pinheiro", "conifera_1", "conifera_3", "abeto_1", "outono_1", "betula", "arvore_morta"]),
                      "p": [round(q[0], 2), round(q[1], 2)], "r": round(RV.uniform(0, 6.28), 3)})
        for j in range(RV.randint(1, 3)):
            props.append({"m": "veg:" + RV.choice(["capim_alto", "arbusto", "arbusto_2", "capim_seco"]),
                          "p": [round(q[0] + RV.uniform(-3, 3), 2), round(q[1] + RV.uniform(-3, 3), 2)], "r": round(RV.uniform(0, 6.28), 3)})
PLACA = (ENTRADA[0] + ENTRADA_DIR[0] * (RURAL - 15), ENTRADA[1] + ENTRADA_DIR[1] * (RURAL - 15))
prop("portico", PLACA[0], PLACA[1], math.pi / 2)
entrada = {"p": [ENTRADA[0] + ENTRADA_DIR[0] * 12, ENTRADA[1] + ENTRADA_DIR[1] * 12], "dir": list(ENTRADA_DIR)}

# ---------------- a capital destruída ao longe (norte, depois do muro): só silhueta ----------------
for (x, z, b, rot) in ((-480, 640, "building_03", 0.3), (-300, 700, "building_07", 0.0), (-120, 620, "building_01", 0.5),
                       (40, 720, "building_06", 0.1), (200, 640, "building_05", 0.8), (360, 700, "building_02", 0.2),
                       (520, 620, "building_04", 0.6)):
    longe.append({"c": "res://assets/catalogo/majadroid/%s.glb" % b, "p": [x, -z], "r": rot})

# 07/11 (E2b, regra 7: pronto no lugar do feito à mão): 1 em cada 3 casas americanas comuns vira casa pronta do
# Sketchfab (fechada: só por fora; tools/blender/casa_pronta.py). Troca depois de tudo: o sorteio da cidade não muda.
PRONTAS = [] if LA else sorted(k for k in MED if k.startswith("casa_p"))  # 13/11 estilizado: só casas nossas (mesmo estilo)
n_casa = 0
for pp in predios:
    if pp["modelo"] in CASAS and PRONTAS:
        n_casa += 1
        if n_casa % 3 == 0:
            pp["modelo"] = PRONTAS[(n_casa // 3) % len(PRONTAS)]
            q = pp["p"]
            pp["c"] = [round(sum(v[0] for v in q) / len(q), 2), round(sum(v[1] for v in q) / len(q), 2)]
# ---------------- 13/11 FLORESTA: estradas de terra, lugares de raid e a mata ----------------
lugares = {"baus": [], "subidas": []}
quarentena = {"portao": [9999.0, 9999.0], "vao": 0.0, "baus": [], "soldados": []}
RF = random.Random(1311)
RAIDS_F = []
if FLORESTA:
    def clareira(c, w, d):
        reserva(c[0], c[1], w, d)
        area(ret(c[0] - w / 2, c[1] - d / 2, c[0] + w / 2, c[1] + d / 2), "terra")
    def p2(x, z):
        return [round(x, 2), round(z, 2)]
    # estradas: da cidadezinha ao meio da mata e de lá para cada lugar (curvas suaves)
    rua([(-488.0, OFF[1]), (-462.0, OFF[1])], "primary", False)
    rua([(OFF[0] + 150, OFF[1] - 40), (-80, 200), (0, 40), (30, -40)], "service")
    rua([(30, -40), (120, -150), (210, -230)], "service")             # acampamento militar
    rua([(30, -40), (180, 30), (330, 120), (360, 160)], "service")      # posto florestal
    rua([(30, -40), (-60, -150), (-140, -175), (-160, -190)], "service")  # cabana do caçador
    rua([(-80, 200), (60, 260), (180, 330), (230, 380)], "service")   # serraria
    # 1) acampamento militar abandonado: tendas, contêineres, torres e holofote
    c = (220.0, -260.0)
    clareira(c, 56.0, 44.0)
    for dx, dz in ((-16, -10), (0, -12), (16, -10), (-8, 10)):
        props.append({"m": "mundo:tenda", "p": p2(c[0] + dx, c[1] + dz), "r": 0.0})
        lugares["baus"].append(p2(c[0] + dx + 1.5, c[1] + dz + 1.0))
    for k in range(3):
        props.append({"m": "mundo:conteiner" if k != 1 else "mundo:conteiner_azul", "p": p2(c[0] + 14, c[1] + 6 + k * 3.0), "r": 0.0})
    for dx in (-26, 26):
        props.append({"m": "mundo:torre_vigia", "p": p2(c[0] + dx, c[1] - 20), "r": 0.0})
    props.append({"m": "mundo:holofote", "p": p2(c[0], c[1] + 20), "r": math.pi})
    for k in range(-5, 6):
        props.append({"m": "mundo:sacos_areia", "p": p2(c[0] + k * 3.0, c[1] + 21.0), "r": math.pi / 2})
    for k in range(10):
        zumbis.append(p2(c[0] + RF.uniform(-24, 24), c[1] + RF.uniform(-18, 18)))
    RAIDS_F.append(["ACAMPAMENTO MILITAR", p2(*c)])
    # 2) helicóptero caído no meio da mata (sem estrada: vai a pé)
    c = (-20.0, -330.0)
    clareira(c, 30.0, 30.0)
    marcos.append({"tipo": "helicoptero", "p": p2(*c), "r": 0.6})
    for k in range(6):
        zumbis.append(p2(c[0] + RF.uniform(-12, 12), c[1] + RF.uniform(-12, 12)))
    RAIDS_F.append(["HELICÓPTERO CAÍDO", p2(*c)])
    # 3) cabana do caçador (casinha nossa) com a caminhonete e baús
    c = (-175.0, -205.0)
    clareira(c, 30.0, 26.0)
    predio("casa_us_3", c[0], c[1] + 3, (0.0, 1.0), "casas", "house")
    veiculos.append({"m": "mundo:ferrugem", "p": p2(c[0] + 10, c[1] + 10), "r": 0.4, "cor": [0.35, 0.22, 0.15]})
    lugares["baus"].append(p2(c[0] - 9, c[1] + 10))
    for k in range(5):
        zumbis.append(p2(c[0] + RF.uniform(-12, 12), c[1] + RF.uniform(-10, 10)))
    RAIDS_F.append(["CABANA DO CAÇADOR", p2(*c)])
    # 4) posto florestal: torre de vigia, guarita, tenda e barricada
    c = (375.0, 175.0)
    clareira(c, 34.0, 28.0)
    props.append({"m": "mundo:torre_vigia", "p": p2(c[0] - 8, c[1] - 6), "r": 0.0})
    props.append({"m": "mundo:guarita", "p": p2(c[0] + 8, c[1] - 6), "r": 0.0})
    props.append({"m": "mundo:tenda", "p": p2(c[0] + 2, c[1] + 6), "r": math.pi / 2})
    for k in (-3, -2, -1, 1, 2, 3):
        props.append({"m": "mundo:barreira" if k % 2 else "mundo:sacos_areia", "p": p2(c[0] + k * 3.2, c[1] + 13.0), "r": 0.0})
    lugares["baus"] += [p2(c[0] + 4, c[1] + 6), p2(c[0] - 8, c[1] - 2)]
    lugares["subidas"].append([round(c[0] - 8 + 2.0, 2), round(c[1] - 6, 2), round(c[0] - 8, 2), round(c[1] - 6, 2), 6.0, 1.0, 0.0])
    for k in range(6):
        zumbis.append(p2(c[0] + RF.uniform(-14, 14), c[1] + RF.uniform(-12, 12)))
    RAIDS_F.append(["POSTO FLORESTAL", p2(*c)])
    # 5) serraria: galpão, toras (entulho), caminhões velhos
    c = (245.0, 395.0)
    clareira(c, 48.0, 36.0)
    predio("galpao_r1", c[0], c[1] + 4, (0.0, -1.0), "industrial", "industrial")
    for k in range(4):
        props.append({"m": RF.choice(["mundo:entulho", "mundo:tijolos"]), "p": p2(c[0] - 18 + k * 4.0, c[1] - 14), "r": round(RF.uniform(0, 6.28), 3)})
    for k in range(3):
        veiculos.append({"m": RF.choice(["mundo:ferrugem", "mundo:carcaca"]), "p": p2(c[0] + 14 + k * 3.5, c[1] - 12), "r": 1.57, "cor": [0.4, 0.3, 0.2]})
    lugares["baus"] += [p2(c[0] - 14, c[1] + 12), p2(c[0] + 16, c[1] + 12)]
    for k in range(8):
        zumbis.append(p2(c[0] + RF.uniform(-20, 20), c[1] + RF.uniform(-14, 14)))
    RAIDS_F.append(["SERRARIA", p2(*c)])
    # a mata: uma árvore a cada ~9 m (com sobra de mato no pé), fora da cidade, das estradas, do rio e das clareiras
    arv = 0
    for gx in range(-484, 485, 9):
        for gz in range(-484, 485, 9):
            q = (gx + RF.uniform(-3.5, 3.5), gz + RF.uniform(-3.5, 3.5))
            if zona(*q) != "parque" or perto_rua(q, 3.5) or perto_rio(q, 1.5):
                continue
            if any(abs(q[0] - o[0]) < o[3] / 2 + 2 and abs(q[1] - o[1]) < o[4] / 2 + 2 for o in ocupado if math.dist(q, o[:2]) < 60):
                continue
            prop("arvore_mata", q[0], q[1], RF.uniform(0, 6.28))
            arv += 1
    for k in range(40):  # zumbis soltos andando pela mata
        q = (RF.uniform(-470, 470), RF.uniform(-470, 470))
        if zona(*q) == "parque" and not perto_rio(q, 2.0):
            zumbis.append(p2(*q))
    print("FLORESTA: árvores", arv, "| raids", [r[0] for r in RAIDS_F])
if not FLORESTA:
    # ---------------- 07/11 (E3, regra 1): estrutura nova da cidade (sorteio próprio: o resto da cidade não muda) ----------------
    RE = random.Random(3107)
    CENTRO_C = (0.0, -16.0) if LA else (120.0, 10.0) if GALENA else (-15.0, 225.0)
    # 1) bairro incendiado: o aglomerado de casas mais longe do centro e da entrada pega fogo (mesmo tamanho -> versão queimada)
    QUEIMA = {"casa_us_7": "casa_us_q1", "casa_us_1": "casa_us_q1", "casa_us_2": "casa_us_q1", "casa_us_5": "casa_us_q1", "casa_us_3": "casa_us_q2",
              "casa_us_4": "casa_us_q2", "casa_us_6": "casa_us_q2"}  # a queimada cabe no lote da original (mesma origem)
    cands = [pp for pp in predios if pp["modelo"] in CASA_US and math.dist(pp["c"], CENTRO_C) > 220 and math.dist(pp["c"], ENTRADA) > 260]
    foco = max(cands, key=lambda pp: sum(1 for o in cands if math.dist(o["c"], pp["c"]) < 70)) if cands else None
    incendio = 0
    if foco:
        for pp in predios:
            if pp["modelo"] in QUEIMA and math.dist(pp["c"], foco["c"]) < 95:
                pp["modelo"] = QUEIMA[pp["modelo"]]
                incendio += 1
        for k in range(6):
            zumbis.append([round(foco["c"][0] + RE.uniform(-40, 40), 2), round(foco["c"][1] + RE.uniform(-40, 40), 2)])
    # 2) centro bombardeado: entulho e pilhas de tijolo na rua e nas calçadas, carros queimados
    bomba = 0
    for tent in range(900):
        if bomba >= 45:
            break
        a, d = RE.uniform(0, math.tau), 90.0 * math.sqrt(RE.random())
        q = (CENTRO_C[0] + math.cos(a) * d, CENTRO_C[1] + math.sin(a) * d)
        novo = (q[0], q[1], 0.0, 3.0, 3.0)
        if any(sobrepoe(novo, o) for o in ocupado if math.dist(o[:2], q) < 30):
            continue
        bomba += 1
        props.append({"m": RE.choice(["mundo:entulho", "mundo:entulho", "mundo:tijolos"]), "p": [round(q[0], 2), round(q[1], 2)], "r": round(RE.uniform(0, 6.28), 3)})
        if bomba % 8 == 0:
            veiculos.append({"m": "mundo:queimado", "p": [round(q[0] + 3, 2), round(q[1], 2)], "r": round(RE.uniform(0, 6.28), 3)})
    # 3) rodovia de entrada engarrafada: a fila de quem tentou fugir, na pista de saída (a de quem chega fica livre)
    lado_e = (ENTRADA_DIR[1], -ENTRADA_DIR[0])  # -lado do carro de quem chega (Bairro._entrada)
    saida_r = math.pi / 2 - math.atan2(-ENTRADA_DIR[1], -ENTRADA_DIR[0])
    fila = 0
    t = 26.0
    while t < RURAL - 25:
        q = (ENTRADA[0] + ENTRADA_DIR[0] * t + lado_e[0] * 2.7, ENTRADA[1] + ENTRADA_DIR[1] * t + lado_e[1] * 2.7)
        veiculos.append({"m": RE.choice(["mundo:carcaca", "mundo:ferrugem", "mundo:van", "mundo:carcaca"]), "p": [round(q[0], 2), round(q[1], 2)],
                         "r": round(saida_r + RE.uniform(-0.12, 0.12), 3), "cor": [round(RE.uniform(0.1, 0.6), 2), round(RE.uniform(0.1, 0.4), 2), round(RE.uniform(0.1, 0.4), 2)]})
        fila += 1
        if fila % 4 == 0:
            zumbis.append([round(q[0] + lado_e[0] * 3, 2), round(q[1] + lado_e[1] * 3, 2)])
        t += RE.uniform(6.0, 8.5)
    # 4) vala comum: num terreno vazio longe do centro, fileiras de sacos de corpo com cruz na cabeça
    vala = None
    for gx in range(-420, 421, 12):
        for gz in range(-420, 421, 12):
            if math.dist((gx, gz), CENTRO_C) > 160 and not perto_rua((gx, gz), 9.0) and livre(gx, gz, 0.0, 26.0, 16.0):
                vala = (gx, gz)
                break
        if vala:
            break
    if vala:
        reserva(vala[0], vala[1], 26.0, 16.0)
        area(ret(vala[0] - 13, vala[1] - 8, vala[0] + 13, vala[1] + 8), "terra")
        for fil in range(4):
            for k in range(7):
                x = vala[0] - 10.5 + k * 3.5
                z = vala[1] - 5.0 + fil * 3.4
                props.append({"m": "mundo:saco_corpo", "p": [round(x + RE.uniform(-0.3, 0.3), 2), round(z, 2)], "r": round(RE.uniform(-0.15, 0.15), 3)})
                if RE.random() < 0.5:
                    props.append({"m": RE.choice(["tumulo_1", "tumulo_2", "tumulo_3"]), "p": [round(x, 2), round(z - 1.4, 2)], "r": 0.0})
        for k in range(4):
            zumbis.append([round(vala[0] + RE.uniform(-12, 12), 2), round(vala[1] + RE.uniform(-7, 7), 2)])
    # 5) (E4) quarentena militar: muro de contêineres cortando a cidade em QZ (hospital e mercado ficam do lado de dentro, ao
    # norte); um portão com checkpoint na rua mais central; tendas, baús militares e soldados do lado de dentro
    QZ = 380.0
    cruza_q = []
    for r in ruas:
        for a1, b1 in zip(r["p"], r["p"][1:]):
            if (a1[1] - QZ) * (b1[1] - QZ) < 0:
                cruza_q.append(a1[0] + (b1[0] - a1[0]) * (QZ - a1[1]) / (b1[1] - a1[1]))
    portao_x = min(cruza_q, key=abs) if cruza_q else 0.0
    quarentena = {"portao": [round(portao_x, 2), QZ], "vao": 14.0, "baus": [], "soldados": []}
    x = -LIM + 4.0
    nq = 0
    while x < LIM - 4.0:
        if abs(x - portao_x) < 7.0:
            x = portao_x + 7.0
            continue
        m, w = ("mundo:conteiner", 13.2) if nq % 3 != 2 else ("mundo:conteiner_azul", 6.9)
        novo = (x + w / 2, QZ, 0.0, w, 2.6)
        if not perto_rio((x + w / 2, QZ), 3.0) and not any(sobrepoe(novo, o, 0.0) for o in ocupado if math.dist(o[:2], novo[:2]) < 30) and abs(x + w - portao_x) > 6.5:
            props.append({"m": m, "p": [round(x + w / 2, 2), QZ], "r": 0.0})
            reserva(x + w / 2, QZ, w, 2.6)
            nq += 1
            x += w
        else:
            x += 1.0
    g = (portao_x, QZ)
    for dx, m, r in ((-5.5, "mundo:guarita", 0.0), (-9.0, "mundo:holofote", 0.0), (9.0, "mundo:holofote", math.pi)):
        props.append({"m": m, "p": [round(g[0] + dx, 2), round(g[1] - 3.0, 2)], "r": r})
    for dx in (-4.0, 4.0):  # sacos de areia em L dos dois lados do portão, do lado de fora
        props.append({"m": "mundo:sacos_areia", "p": [round(g[0] + dx, 2), round(g[1] - 6.0, 2)], "r": math.pi / 2})
    for dx in (-12.0, 12.0):
        props.append({"m": "mundo:torre_vigia", "p": [round(g[0] + dx, 2), round(g[1] + 5.0, 2)], "r": 0.0})
    tendas = 0
    for tent in range(200):
        if tendas >= 4:
            break
        q = (g[0] + RE.uniform(-60, 60), g[1] + RE.uniform(14, 60))
        if livre(q[0], q[1], 0.0, 10.5, 10.0):
            reserva(q[0], q[1], 10.5, 10.0)
            props.append({"m": "mundo:tenda", "p": [round(q[0], 2), round(q[1], 2)], "r": round(RE.choice([0.0, math.pi / 2, math.pi]), 3)})
            quarentena["baus"].append([round(q[0] + 1.5, 2), round(q[1] + 1.0, 2)])
            for k in range(2):
                quarentena["soldados"].append([round(q[0] + RE.uniform(-7, 7), 2), round(q[1] + RE.uniform(-7, 7), 2)])
            tendas += 1
    print("E4: contêineres", nq, "| portão x", round(portao_x, 1), "| tendas", tendas)
    # 6) (E5) lugares novos: torre de água (sobe e vê longe), ferro-velho cercado, escola barricada, bombas de gasolina
    lugares = {"baus": [], "subidas": []}
    def acha_livre(w, d, alvo, raio, folga_rua=10.0):
        for rr in range(0, int(raio), 6):
            for k in range(max(1, rr // 3)):
                a = math.tau * k / max(1, rr // 3)
                q = (alvo[0] + math.cos(a) * rr, alvo[1] + math.sin(a) * rr)
                if livre(q[0], q[1], 0.0, w, d) and perto_rua(q, w / 2 + folga_rua) and not perto_rua(q, max(w, d) / 2 + 1.0):
                    return q
        return None
    torre = acha_livre(11.0, 11.0, (140.0, 140.0), 160)
    if torre:
        reserva(torre[0], torre[1], 11.0, 11.0)
        props.append({"m": "mundo:torre_agua", "p": [round(torre[0], 2), round(torre[1], 2)], "r": 0.0})
        lugares["subidas"].append([round(torre[0] + 5.6, 2), round(torre[1], 2), round(torre[0], 2), round(torre[1], 2), 22.0, 1.0, 0.0])
    ferro = acha_livre(34.0, 26.0, (-300.0, 330.0), 220, 14.0)
    if ferro:
        fx, fz = ferro
        reserva(fx, fz, 34.0, 26.0)
        area(ret(fx - 17, fz - 13, fx + 17, fz + 13), "terra")
        for (a1, b1) in (((-17, -13), (17, -13)), ((17, -13), (17, 13)), ((17, 13), (3, 13)), ((-3, 13), (-17, 13)), ((-17, 13), (-17, -13))):
            muros.append({"a": [round(fx + a1[0], 2), round(fz + a1[1], 2)], "b": [round(fx + b1[0], 2), round(fz + b1[1], 2)], "alt": 2.2, "cor": 0, "grade": True})
        for k in range(14):
            q = (fx + RE.uniform(-14, 14), fz + RE.uniform(-10, 9))
            veiculos.append({"m": RE.choice(["mundo:ferrugem", "mundo:queimado", "mundo:carcaca", "mundo:van"]), "p": [round(q[0], 2), round(q[1], 2)],
                             "r": round(RE.uniform(0, 6.28), 3), "cor": [round(RE.uniform(0.2, 0.6), 2), round(RE.uniform(0.15, 0.4), 2), round(RE.uniform(0.1, 0.3), 2)]})
        lugares["baus"] += [[round(fx - 12, 2), round(fz - 9, 2)], [round(fx + 12, 2), round(fz - 9, 2)]]
        for k in range(4):
            zumbis.append([round(fx + RE.uniform(-12, 12), 2), round(fz + RE.uniform(-9, 9), 2)])
    for pe in predios:
        if pe["modelo"] == "escola":  # escola virou refúgio que caiu: barreira e sacos de areia na frente, baú dentro
            ex, ez = pe["c"]
            fr = pe["frente"]
            lado = (-fr[1], fr[0])
            for k in range(-3, 4):
                if k == 0:
                    continue  # a passagem que os sobreviventes deixavam
                q = (ex + fr[0] * 9.0 + lado[0] * k * 2.0, ez + fr[1] * 9.0 + lado[1] * k * 2.0)
                props.append({"m": "mundo:barreira" if k % 2 else "mundo:sacos_areia", "p": [round(q[0], 2), round(q[1], 2)],
                              "r": round(math.atan2(lado[0], lado[1]) + (0.0 if k % 2 else math.pi / 2), 3)})
            lugares["baus"].append([round(ex + fr[0] * 6.5, 2), round(ez + fr[1] * 6.5, 2)])
            for k in range(5):
                zumbis.append([round(ex + RE.uniform(-4, 4), 2), round(ez + RE.uniform(-8, 8), 2)])
    pt = (ENTRADA[0] + ENTRADA_DIR[0] * (RURAL + 30) + ENTRADA_DIR[1] * 9, ENTRADA[1] + ENTRADA_DIR[1] * (RURAL + 30) - ENTRADA_DIR[0] * 9)
    for k in range(3):  # bombas de gasolina na beira da estrada (o prédio do posto pronto entra depois: colisão a fazer)
        props.append({"m": "mundo:bomba_gasolina", "p": [round(pt[0] + ENTRADA_DIR[0] * k * 3.0, 2), round(pt[1] + ENTRADA_DIR[1] * k * 3.0, 2)], "r": round(math.atan2(ENTRADA_DIR[0], ENTRADA_DIR[1]), 3)})
    lugares["baus"].append([round(pt[0] + ENTRADA_DIR[1] * 2.5, 2), round(pt[1] - ENTRADA_DIR[0] * 2.5, 2)])
    print("E5: torre", torre, "| ferro-velho", ferro, "| baús de lugar", len(lugares["baus"]))
    # 7) (E6, 12/11, dono: "quero mudar completamente a cidade... tudo isso e mais") lugares novos com os enfeites prontos,
    # um em cada canto da cidade (sorteio próprio: o resto não muda): pátio de contêineres (labirinto), acampamento de
    # sobreviventes que caiu, garagem de ônibus cercada e posto avançado dos Corvos (gente armada: dá para contratar na trégua)
    R6 = random.Random(1211)
    def acha6(w, d, alvos, raio=240):
        for alvo in alvos:
            q = acha_livre(w, d, alvo, raio, 16.0)
            if q:
                return q
        return None
    def p2(x, z):
        return [round(x, 2), round(z, 2)]
    patio = acha6(44.0, 30.0, [(320.0, 120.0), (330.0, -120.0), (-330.0, 60.0)])
    if patio:
        px, pz = patio
        reserva(px, pz, 44.0, 30.0)
        area(ret(px - 22, pz - 15, px + 22, pz + 15), "terra")
        for fil in range(4):  # 4 fileiras com corredor de ~4 m; cada uma com a passagem num lugar diferente
            z = pz - 10.5 + fil * 7.0
            x = px - 20.0
            falha = 1 + R6.randrange(2)
            k = 0
            while x + 6.9 <= px + 20.0:
                m, w = ("mundo:conteiner", 13.2) if R6.random() < 0.6 and x + 13.2 <= px + 20.0 else ("mundo:conteiner_azul", 6.9)
                if k == falha:
                    x += 3.4
                    if x + w > px + 20.0:
                        break
                props.append({"m": m, "p": p2(x + w / 2, z), "r": 0.0})
                x += w + 0.3
                k += 1
        props.append({"m": "mundo:torre_vigia", "p": p2(px - 19.5, pz + 13.0), "r": 0.0})
        props.append({"m": "mundo:holofote", "p": p2(px + 19.5, pz - 13.5), "r": math.pi})
        lugares["baus"] += [p2(px + 17.0, pz - 7.0), p2(px - 17.0, pz + 7.0)]
        for k in range(7):
            zumbis.append(p2(px + R6.uniform(-18, 18), pz - 7.0 + 7.0 * R6.randrange(3)))
    acamp = acha6(32.0, 26.0, [(-260.0, -160.0), (-300.0, 120.0), (120.0, -330.0)])
    if acamp:
        ax, az = acamp
        reserva(ax, az, 32.0, 26.0)
        area(ret(ax - 16, az - 13, ax + 16, az + 13), "terra")
        for dx in (-8.5, 8.5):
            props.append({"m": "mundo:tenda", "p": p2(ax + dx, az - 6.0), "r": 0.0})
            lugares["baus"].append(p2(ax + dx + 1.5, az - 5.0))
        for k in range(-4, 5):  # barricada da frente com a passagem que arrombaram
            if k == 0:
                continue
            props.append({"m": "mundo:sacos_areia" if k % 2 else "mundo:barreira", "p": p2(ax + k * 3.2, az + 11.5), "r": 0.0 if k % 2 == 0 else math.pi / 2})
        for k in range(6):  # os que não escaparam
            props.append({"m": "mundo:saco_corpo", "p": p2(ax - 8.0 + k * 3.2 + R6.uniform(-0.3, 0.3), az + 4.5), "r": round(R6.uniform(-0.2, 0.2), 3)})
        props.append({"m": "mundo:entulho", "p": p2(ax + 12.0, az + 5.0), "r": round(R6.uniform(0, 6.28), 3)})
        for k in range(8):
            zumbis.append(p2(ax + R6.uniform(-14, 14), az + R6.uniform(1.0, 9.0)))
    garagem = acha6(40.0, 24.0, [(140.0, -320.0), (-120.0, -340.0), (340.0, 280.0)])
    if garagem:
        gx, gz = garagem
        reserva(gx, gz, 40.0, 24.0)
        area(ret(gx - 20, gz - 12, gx + 20, gz + 12), "terra")
        for (a1, b1) in (((-20, -12), (20, -12)), ((20, -12), (20, 12)), ((20, 12), (4, 12)), ((-4, 12), (-20, 12)), ((-20, 12), (-20, -12))):
            muros.append({"a": p2(gx + a1[0], gz + a1[1]), "b": p2(gx + b1[0], gz + b1[1]), "alt": 2.2, "cor": 0, "grade": True})
        for k in range(5):  # ônibus lado a lado, um atravessado no fundo
            veiculos.append({"m": "mundo:onibus", "p": p2(gx - 14.0 + k * 7.0, gz - 2.0 + R6.uniform(-1.0, 1.0)), "r": round(R6.uniform(-0.06, 0.06), 3)})
        lugares["baus"].append(p2(gx + 17.0, gz - 9.5))
        for k in range(6):
            zumbis.append(p2(gx - 17.5 + k * 7.0, gz + R6.uniform(-6, 8)))
    posto_c = acha6(22.0, 18.0, [(-200.0, 300.0), (250.0, 330.0), (-340.0, -60.0)])
    if posto_c:
        cx6, cz6 = posto_c
        reserva(cx6, cz6, 22.0, 18.0)
        area(ret(cx6 - 11, cz6 - 9, cx6 + 11, cz6 + 9), "terra")
        props.append({"m": "mundo:torre_vigia", "p": p2(cx6 - 7.0, cz6 - 5.0), "r": 0.0})
        props.append({"m": "mundo:guarita", "p": p2(cx6 + 7.0, cz6 - 5.0), "r": 0.0})
        props.append({"m": "mundo:holofote", "p": p2(cx6 + 9.0, cz6 + 7.0), "r": math.pi})
        for k in (-3, -2, -1, 1, 2, 3):
            props.append({"m": "mundo:sacos_areia", "p": p2(cx6 + k * 3.0, cz6 + 8.0), "r": math.pi / 2})
        lugares["baus"].append(p2(cx6, cz6 - 6.0))
        for k in range(3):
            quarentena["soldados"].append(p2(cx6 - 4.0 + k * 4.0, cz6 + R6.uniform(-1.0, 3.0)))
    print("E6: pátio", patio, "| acampamento", acamp, "| garagem", garagem, "| posto dos Corvos", posto_c)
    print("E3: casas incendiadas", incendio, "| entulho", bomba, "| fila na rodovia", fila, "| vala comum", vala)
    print("casas prontas:", sum(1 for pp in predios if pp["modelo"].startswith("casa_p")))
out = {"origem": "Floresta com a cidadezinha de South LA (OpenStreetMap, ODbL; tools/mapa/senoia.py)" if FLORESTA else "South Los Angeles, CA (OpenStreetMap, ODbL; tools/mapa/senoia.py)" if LA else "Galena, IL (OpenStreetMap, ODbL; tools/mapa/senoia.py)" if GALENA else "Senoia, GA (OpenStreetMap, ODbL; tools/mapa/raven_creek.py CIDADE=senoia)" if SENOIA else "Raven Creek (tools/mapa/raven_creek.py)", "ruas": ruas, "predios": predios, "frestas": frestas, "bloqueios": bloqueios,
       "quarentena": quarentena, "lugares": lugares, "marcos": marcos, "muros": muros, "props": props, "areas": areas, "faixas": faixas, "postes": postes, "veiculos": veiculos,
       "zumbis": zumbis, "longe": longe, "entrada": entrada, "raids_mata": RAIDS_F,
       "terreno": {"rio": {"p": rio, "larg": RIO_LARG, "fundo": 2.2, "agua": 1.5}, "morros": [MORRO]}}
json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "assets/mapa/cidade.json", "w"))
cont = {}
for p in predios:
    k = p["modelo"].split("_")[0] if not p["modelo"].startswith("casa_us") else "casa_us"
    cont[k] = cont.get(k, 0) + 1
print("ruas", len(ruas), "predios", len(predios), cont, "muros", len(muros), "props", len(props), "postes", sum(len(c) for c in postes),
      "faixas", len(faixas), "frestas", len(frestas))
