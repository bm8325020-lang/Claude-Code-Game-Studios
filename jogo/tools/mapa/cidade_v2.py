# São Jorge (31/10, dono: "uma puta de uma cidade completamente diferente; esse mapa pra sempre"): cidade de interior
# do Brasil depois do fim do mundo, desenhada à mão e preenchida por regras. Gera assets/mapa/cidade.json:
#   python3 tools/mapa/cidade_v2.py [assets/mapa/cidade.json]
# Modelos em assets/ruinas (tools/blender/ruinas.py e cidade.py); tamanhos em tools/mapa/medidas.json (mede_ruinas.gd).
# Coordenadas locais em metros (x, z), área de -246 a 246; -z = norte.
#   Centro: Praça da Matriz (coreto, árvores, banca) com a Igreja Matriz ao norte; sobrados de comércio colados com
#     letreiro (farmácia, padaria, açougue...), prédios de apartamento, um quarteirão em ruínas com telhados ligados.
#   Raids: Delegacia (Rua Central), Hospital Municipal (heliponto), Supermercado Bom Preço (estacionamento), Igreja.
#   Morro do Urubu (noroeste): favela de barracos colados nas vielas, antena no topo.
#   Bairros de casas com muro e portão (norte e sul), Escola Estadual com campinho de terra.
#   Zona industrial (leste): galpões, caixa d'água; engavetamento na saída da rodovia.
#   Rio ao sul com 3 pontes; do outro lado: cemitério com capela, posto, helicóptero caído, quarentena do exército.
#   Ao longe, ao norte: a capital destruída (só silhueta; ao sul do muro fica a pista de teste).
import json
import math
import random
import sys

R = random.Random(2026)
LIM = 238.0
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
rio = catmull([(-262, 150), (-150, 164), (-40, 142), (60, 158), (160, 136), (262, 150)], 8.0)
RIO_LARG = 16.0
MORRO = {"p": [-168, -152], "raio": 76.0, "alt": 13.0}


def perto_rio(p, folga):
    return any(dist_seg(p, a, b) < RIO_LARG / 2 + folga for a, b in zip(rio, rio[1:]))


def no_morro(p, folga=0.0):
    return math.dist(p, MORRO["p"]) < MORRO["raio"] + folga


def zona(x, z):
    if no_morro((x, z), -4):
        return "favela"
    if z > 168:
        return "alem"
    if x > 135 and -85 < z < 140:
        return "industrial"
    if -92 < x < 100 and -84 < z < 72:
        return "centro"
    return "casas"


# ---------------- ruas ----------------
AV = rua([(-252, 4), (-200, 2), (-140, -6), (-80, -6), (-20, -2), (40, -3), (100, 0), (160, -4), (252, 2)], "primary")
CENTRAL = rua([(-6, -252), (-2, -190), (-8, -130), (-2, -72), (0, -3), (4, 60), (0, 120), (6, 160), (2, 252)], "secondary")
OESTE = rua([(-82, -100), (-74, -40), (-78, -6), (-72, 52), (-84, 110), (-80, 160), (-90, 252)], "secondary")
LESTE = rua([(78, -214), (74, -140), (78, -72), (76, -3), (80, 60), (72, 130), (84, 170), (78, 252)], "secondary")
MATRIZ = rua([(-82, -74), (-2, -72), (78, -72), (150, -76), (205, -70)], "tertiary")
SETE = rua([(-160, 55), (-72, 52), (4, 58), (80, 60), (180, 64), (252, 62)], "tertiary")
FLORES = rua([(-82, -100), (-60, -128), (-8, -130), (30, -140), (74, -138), (112, -124), (150, -128), (192, -142), (232, -134)], "tertiary")
IPES = rua([(-68, -200), (-30, -188), (-2, -192), (40, -206), (78, -200), (112, -184), (150, -190), (180, -204), (214, -196)], "residential")
rua([(150, -128), (160, -150), (146, -172), (150, -190)], "residential")
rua([(-40, -129), (-52, -150), (-36, -172), (-38, -194)], "residential")
rua([(40, -206), (30, -222), (44, -240)], "residential")          # sem saída para o norte
rua([(112, -184), (126, -210), (118, -236)], "residential")
rua([(-150, 55), (-146, 85), (-140, 116)], "residential")
RIO_RUA = rua([(-214, 112), (-140, 118), (-84, 110)], "residential")
rua([(-30, 58), (-42, 80), (-28, 104), (-34, 126)], "residential")   # sem saída até o rio
rua([(40, 60), (52, 84), (38, 106), (46, 128)], "residential")
rua([(120, 62), (108, 88), (122, 112)], "residential")
rua([(-200, 2), (-196, 40), (-206, 80), (-214, 112)], "residential")
rua([(-140, -6), (-150, -60), (-118, -86), (-82, -100)], "residential")  # contorna o mercado até o pé do morro
IND = rua([(150, -76), (160, -20), (156, 64), (166, 120), (246, 118)], "tertiary")
rua([(160, 20), (246, 24)], "service")
rua([(-86, 212), (-118, 212)], "residential")                        # Rua da Saudade (cemitério)
rua([(6, 160), (40, 200), (120, 214), (200, 206)], "residential")    # estrada do outro lado do rio
# Morro do Urubu: subida principal (rua) do pé ao topo e vielas descendo para todo lado
# (a subida é reta, na linha que tools/../test_relevo usa para subir o morro andando: 0,3 rad a partir do topo)
SUBIDA = rua([(-60, -128), (-75, -123.2), (-103.1, -131.9), (-134.6, -141.6), (-168, -152)], "residential", False)
VIELAS = []
for k, ang in enumerate([2.0, 3.0, 4.0, 5.1, 1.2]):
    pts = [MORRO["p"][:]]
    a = ang
    for i in range(1, 15):
        a += R.uniform(-0.15, 0.15)
        r = i * 5.0
        pts.append([round(MORRO["p"][0] + math.cos(a) * r, 2), round(MORRO["p"][1] + math.sin(a) * r, 2)])
    pts = [p for p in pts if abs(p[0]) < LIM - 2 and abs(p[1]) < LIM - 2]
    VIELAS.append(rua(pts, "viela", False))


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


def prop(m, x, z, r=0.0):
    props.append({"m": m, "p": [round(x, 2), round(z, 2)], "r": round(r, 3)})


def area(poly, m):
    areas.append({"p": [[round(a, 2), round(b, 2)] for a, b in poly], "m": m})


def ret(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


# Praça da Matriz
PX0, PZ0, PX1, PZ1 = 7.0, -64.0, 70.0, -11.0
reserva((PX0 + PX1) / 2, (PZ0 + PZ1) / 2, PX1 - PX0, PZ1 - PZ0)
area(ret(PX0, PZ0, PX1, PZ1), "praca")
pcx, pcz = (PX0 + PX1) / 2, (PZ0 + PZ1) / 2
for (x0, z0, x1, z1) in ((PX0 + 2, PZ0 + 2, pcx - 2.5, pcz - 2.5), (pcx + 2.5, PZ0 + 2, PX1 - 2, pcz - 2.5),
                         (PX0 + 2, pcz + 2.5, pcx - 2.5, PZ1 - 2), (pcx + 2.5, pcz + 2.5, PX1 - 2, PZ1 - 2)):
    area(ret(x0, z0, x1, z1), "grama")
    for k in range(5):  # árvores e bancos em cada canteiro
        tx, tz = R.uniform(x0 + 3, x1 - 3), R.uniform(z0 + 3, z1 - 3)
        if math.dist((tx, tz), (pcx, pcz)) > 9:
            prop(R.choice(["arvore_1", "arvore_2", "arvore_1", "palmeira", "arvore_3"]), tx, tz, R.uniform(0, 6.28))
prop("coreto", pcx, pcz, 0.0)
for k in range(8):
    a = k * math.pi / 4 + math.pi / 8
    prop("banco_praca", pcx + math.cos(a) * 10.5, pcz + math.sin(a) * 10.5, math.atan2(-math.cos(a), -math.sin(a)))  # olha o coreto
prop("banca", PX0 + 4.0, PZ1 - 3.5, 0.0)
prop("orelhao", PX1 - 2.5, PZ1 - 2.0, math.pi)
prop("orelhao", PX0 + 2.0, PZ0 + 6.0, math.pi / 2)
zumbis += [[pcx + 6, pcz + 4], [pcx - 12, pcz - 10]]
# Igreja Matriz (ao norte da praça, olhando para ela)
predio("igreja", 38.0, -96.5, (0, 1), "centro")
# Hospital (Rua da Matriz, leste) com ambulâncias na frente
predio("hospital", 126.0, -97.0, (0, 1), "centro")
veiculos += [{"m": "van_r1", "p": [118.0, -84.0], "r": 1.2, "cor": [0.85, 0.85, 0.82]},
             {"m": "van_r1", "p": [131.0, -83.5], "r": 1.9, "cor": [0.85, 0.85, 0.82]}]
# Supermercado e estacionamento (avenida, oeste)
predio("mercado", -121.0, -41.0, (0, 1), "centro")
area(ret(-138.0, -29.5, -104.0, -13.5), "asfalto")
for k in range(7):
    veiculos.append({"m": R.choice(["carro_r1", "carro_r1", "carro_r2"]), "p": [round(-134.0 + k * 4.6, 2), -24.0], "r": round(R.uniform(-0.2, 0.2), 3)})
reserva(-121.0, -21.5, 34, 16)
# Delegacia (Rua Central, olhando para o leste)
predio("delegacia", -11.5, 30.0, (1, 0), "centro")
# Escola Estadual e o campinho de terra
predio("escola", 32.0, -161.0, (0, 1), "casas")
prop("traves", 95.0, -168.0, 0.0)
reserva(95.0, -168.0, 23, 37)
zumbis += [[95, -165]]
# Cemitério (do outro lado do rio, a oeste): muro, capela na entrada, túmulos em fileira
CX0, CZ0, CX1, CZ1 = -206.0, 184.0, -122.0, 238.0
reserva((CX0 + CX1) / 2, (CZ0 + CZ1) / 2, CX1 - CX0, CZ1 - CZ0)
area(ret(CX0, CZ0, CX1, CZ1), "terra")
for (a, b) in (((CX0, CZ0), (CX1, CZ0)), ((CX1, CZ1), (CX0, CZ1)), ((CX0, CZ1), (CX0, CZ0)), ((CX1, CZ0), (CX1, 209.0)), ((CX1, 215.0), (CX1, CZ1))):
    muros.append({"a": list(a), "b": list(b), "alt": 2.2, "cor": 4})
predio("capela", -132.0, 199.0, (1, 0), "alem")
for i, x in enumerate(range(int(CX0) + 5, int(CX1) - 18, 4)):
    for j, z in enumerate(range(int(CZ0) + 5, int(CZ1) - 3, 4)):
        if abs(z - 212) < 3:
            continue  # corredor do meio
        if R.random() < 0.88:
            prop(R.choice(["tumulo_1", "tumulo_2", "tumulo_3"]), x + R.uniform(-0.2, 0.2), z, (0 if R.random() < 0.9 else R.uniform(-0.4, 0.4)))
zumbis += [[-170, 212], [-150, 200], [-190, 225]]


# ---------------- marcos ----------------
def marco(tipo, x, z, ang=0.0, w=None, d=None):
    marcos.append({"tipo": tipo, "p": [x, z], "ang": ang})
    if w:
        reserva(x, z, w, d, ang)


marco("antena", MORRO["p"][0], MORRO["p"][1], 0.0, 11, 11)
marco("caixa_dagua", 214.0, 92.0, 0.0, 9, 9)
marco("caixa_dagua", -52.0, 116.0, 0.0, 9, 9)
marco("posto", -222.0, 24.0, math.pi, 16, 21)        # olha para a avenida (norte)
marco("quarentena", 205.0, -226.0, 0.0, 24, 25)
marco("helicoptero", 176.0, 228.0, 0.6, 17, 17)
prop("portico", -236.0, 3.5, math.pi / 2)
prop("portico", 238.0, 1.5, math.pi / 2)
# engavetamento na saída leste e bloqueios nas ruas de casa
bloqueios.append({"p": [226.0, 1.0], "ang": round(math.pi / 2, 3), "larg": 13.4})
for pts, f in ((IPES, 0.7), (RIO_RUA, 0.5), (FLORES, 0.85)):
    p, a = ponto_em(pts, comprimento(pts) * f)
    bloqueios.append({"p": [round(p[0], 2), round(p[1], 2)], "ang": round(a + math.pi / 2, 3), "larg": 9.9})


# ---------------- lotes ao longo das ruas ----------------
SOBRADOS = sorted([k for k in MED if k.startswith("sobrado_")], key=lambda k: int(k.split("_")[1]))
APTOS = [k for k in MED if k.startswith("apto_")]
CASAS = ["casa_r1", "casa_r2", "casa_r3", "casa_r5", "casa_r7", "casa_r8", "casa_r9", "casa_r10", "casa_r11", "casa_r12",
         "casa_r13", "casa_r14"]
CASA_TAM = {"casa_r1": (9.0, 7.0, False), "casa_r2": (11.0, 8.0, True), "casa_r3": (7.5, 9.0, True), "casa_r4": (10.0, 8.0, None),
            "casa_r5": (12.5, 9.0, True), "casa_r6": (8.0, 6.5, None), "casa_r7": (9.5, 7.5, False), "casa_r8": (10.5, 8.5, True),
            "casa_r9": (8.5, 7.0, False), "casa_r10": (11.5, 9.0, True), "casa_r11": (13.0, 9.5, True), "casa_r12": (8.0, 7.5, False),
            "casa_r13": (7.5, 6.5, False), "casa_r14": (7.0, 6.0, False)}
BARRACOS = [k for k in MED if k.startswith("barraco_")]
RUINA_BLOCO = ["loja_r1", "loja_r1", "loja_r1", "loja_r2", "loja_r2", "loja_r2", "predio_r1"]  # telhados ligados por tábua
n_sobrado = 0
ruina_feita = False
bloco = []  # quarteirão em ruínas: continua na rua seguinte até pôr todos


def tam(modelo):
    if modelo in CASA_TAM:
        return CASA_TAM[modelo][0] + 0.22, CASA_TAM[modelo][1] + 0.22
    return tuple(MED[modelo])


def livre(cx, cz, ang, w, d, favela=False):
    cs = cantos(cx, cz, ang, w, d)
    if any(abs(c[0]) > LIM or abs(c[1]) > LIM for c in cs):
        return False
    if any(perto_rua(c, 0.0) or perto_rio(c, 4.0) for c in cs) or perto_rua((cx, cz), 0.0):
        return False
    if not favela and any(no_morro(c, 2.0) for c in cs):
        return False
    if favela and not all(no_morro(c, -3.0) for c in cs):
        return False
    novo = (cx, cz, ang, w, d)
    return not any(sobrepoe(novo, o) for o in ocupado if math.dist(o[:2], novo[:2]) < 60)


def portao_muro(cx, cz, ang, w_lote, d_lote, recuo, porta_x, esq, cor, grade):
    """Muros do lote (frente com portão na porta da casa, fundo, lados). Lote em coordenadas locais: +z = rua."""
    c, s = math.cos(ang), math.sin(ang)
    def m(x, z):
        return [round(cx + c * x - s * z, 2), round(cz + s * x + c * z, 2)]
    hw, hd = w_lote / 2, d_lote / 2
    alt = 1.0 if grade else 1.7
    g0 = max(-hw + 0.3, min(hw - 2.9, porta_x - 1.3))
    for (a, b) in (((-hw, hd), (g0, hd)), ((g0 + 2.6, hd), (hw, hd)), ((hw, hd), (hw, -hd)), ((hw, -hd), (-hw, -hd))):
        if math.dist(a, b) > 0.2:
            muros.append({"a": m(*a), "b": m(*b), "alt": alt, "cor": cor, "grade": grade and a[1] == hd and b[1] == hd})
    if esq:
        muros.append({"a": m(-hw, -hd), "b": m(-hw, hd), "alt": alt, "cor": cor})


def enche(pts, lado, zona_ok=None, comeco=None):
    """Lotes num lado da rua (lado: 1 = direita de quem anda do começo ao fim)."""
    global n_sobrado, ruina_feita, bloco
    tipo_rua = None
    L = comprimento(pts)
    t = R.uniform(1.0, 4.0) if comeco is None else comeco
    ant = None  # (fim do lote anterior em t, era colado?)
    meia = None
    for r in ruas:
        if r["p"] is pts:
            tipo_rua = r["tipo"]
    meia = LARG[tipo_rua] / 2 + (0 if tipo_rua in ("service", "viela") else CALCADA)
    while t < L - 4:
        p, ang_r = ponto_em(pts, t)
        if p is None:
            break
        nx, nz = -math.sin(ang_r) * lado, math.cos(ang_r) * lado  # normal para o lado do lote
        z = zona(p[0] + nx * 10, p[1] + nz * 10)
        if zona_ok and z not in zona_ok:
            t += 4.0
            ant = None
            continue
        frente = (-nx, -nz)
        ang = math.atan2(frente[1], frente[0]) - math.pi / 2
        if z == "centro":
            if not ruina_feita and tipo_rua == "tertiary" and t > 30:
                bloco = list(RUINA_BLOCO)
                ruina_feita = True
            if bloco:
                modelo = bloco[0]
            elif R.random() < 0.18:
                modelo = R.choice(APTOS)
            else:
                modelo = SOBRADOS[n_sobrado % len(SOBRADOS)]
            w, d = tam(modelo)
            recuo, vao = 0.15, (R.choice([0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 2.4]) if not bloco else R.uniform(1.6, 3.0))
        elif z == "industrial":
            modelo = R.choice(["galpao_r1", "galpao_r2"])
            w, d = tam(modelo)
            recuo, vao = R.uniform(4, 8), R.uniform(6, 12)
        elif z == "favela":
            modelo = R.choice(BARRACOS)
            w, d = tam(modelo)
            recuo, vao = 0.3, R.uniform(0.25, 1.1)
        else:
            modelo = R.choice(CASAS) if R.random() > 0.08 else R.choice(["casa_r4", "casa_r6"])
            w, d = tam(modelo)
            recuo, vao = R.uniform(3.0, 4.5), 0.0
        lado_w = (R.uniform(1.2, 2.6) if z in ("casas", "alem") else 0.0)
        w_lote = w + 2 * lado_w
        off = meia + 0.1 + recuo + d / 2
        cx = p[0] + nx * off + math.cos(ang_r) * w_lote / 2
        cz = p[1] + nz * off + math.sin(ang_r) * w_lote / 2
        if z in ("casas", "alem"):
            d_lote = recuo + d + R.uniform(1.5, 4.0)
            lcx = p[0] + nx * (meia + 0.1 + d_lote / 2) + math.cos(ang_r) * w_lote / 2
            lcz = p[1] + nz * (meia + 0.1 + d_lote / 2) + math.sin(ang_r) * w_lote / 2
            ok = livre(lcx, lcz, ang, w_lote, d_lote)
        else:
            ok = livre(cx, cz, ang, w, d, z == "favela")
        if not ok and bloco and modelo == bloco[0]:  # a ruína grande não coube aqui: um sobrado no lugar, ela fica para depois
            modelo = SOBRADOS[n_sobrado % len(SOBRADOS)]
            w, d = tam(modelo)
            vao = 0.0
            off = meia + 0.1 + recuo + d / 2
            cx = p[0] + nx * off + math.cos(ang_r) * w / 2
            cz = p[1] + nz * off + math.sin(ang_r) * w / 2
            w_lote = w
            ok = livre(cx, cz, ang, w, d)
        if not ok:
            t += 3.0 if z not in ("centro", "favela") else 1.0
            ant = None
            continue
        tipo = {"centro": "commercial", "industrial": "industrial"}.get(z, "house")
        if modelo.startswith(("loja_", "predio_")):
            tipo = "commercial"
        predios.append({"p": cantos(cx, cz, ang, w, d), "tipo": tipo, "andares": 0, "altura": 0, "nome": "", "uso": z,
                        "modelo": modelo, "c": [round(cx, 2), round(cz, 2)], "frente": [round(frente[0], 4), round(frente[1], 4)]})
        if modelo.startswith("sobrado_"):
            n_sobrado += 1
        if bloco and modelo == bloco[0]:
            bloco.pop(0)
        if z in ("casas", "alem"):
            reserva(lcx, lcz, w_lote, d_lote, ang)
            cw = CASA_TAM[modelo]
            porta_x = 0.0 if cw[2] is None else (-cw[0] / 2 + max(3.0, (cw[0] - 1.2) * 0.52) / 2)
            # o lote olha para -z local (a rua); x local do modelo é o mesmo do lote, z invertido
            colado = ant is not None and ant[1] and abs(ant[0] - t) < 0.6
            portao_muro(lcx, lcz, ang, w_lote, d_lote, recuo, porta_x, not colado, R.randint(0, 3), R.random() < 0.3)
            ant = (t + w_lote, True)
        else:
            reserva(cx, cz, w, d, ang)
            if z == "centro" and 0.4 < vao < 1.0:  # fresta entre dois sobrados colados
                fx, fz = p[0] + math.cos(ang_r) * (w + vao / 2), p[1] + math.sin(ang_r) * (w + vao / 2)
                a = (fx + nx * (meia + 0.6), fz + nz * (meia + 0.6))
                b = (fx + nx * (meia + d - 0.5), fz + nz * (meia + d - 0.5))
                frestas.append({"a": [round(a[0], 2), round(a[1], 2)], "b": [round(b[0], 2), round(b[1], 2)], "larg": vao, "_pend": True})
            ant = (t + w_lote, False)
        t += w_lote + vao


for pts in (AV, CENTRAL, MATRIZ, SETE, LESTE, OESTE, FLORES, IPES, IND):
    for lado in (1, -1):
        enche(pts, lado)
for r in list(ruas):
    if r["tipo"] in ("residential", "service") and r["p"] not in (AV, CENTRAL, MATRIZ, SETE, LESTE, OESTE, FLORES, IPES, IND):
        for lado in (1, -1):
            enche(r["p"], lado)
# favela: barracos empacotados pelo morro (grade torta), cada um com a frente para a viela mais perto; os vãos que
# sobram viram becos
for gx in range(-80, 81, 7):
    for gz in range(-80, 81, 7):
        x, z = MORRO["p"][0] + gx + R.uniform(-1.2, 1.2), MORRO["p"][1] + gz + R.uniform(-1.2, 1.2)
        dc = math.dist((x, z), MORRO["p"])
        if dc < 14 or dc > MORRO["raio"] - 8 or R.random() < 0.12:
            continue
        best, bp = 1e9, None
        for (a, b, m) in segs:
            q = dist_seg((x, z), a, b)
            if q < best:
                ax, az = b[0] - a[0], b[1] - a[1]
                l2 = ax * ax + az * az or 1
                t = max(0, min(1, ((x - a[0]) * ax + (z - a[1]) * az) / l2))
                best, bp = q, (a[0] + ax * t, a[1] + az * t)
        f = ((bp[0] - x) / max(best, 0.01), (bp[1] - z) / max(best, 0.01))
        modelo = R.choice(BARRACOS)
        w, d = tam(modelo)
        ang = math.atan2(f[1], f[0]) - math.pi / 2
        if livre(x, z, ang, w + 0.5, d + 0.5, True):
            reserva(x, z, w, d, ang)
            predios.append({"p": cantos(x, z, ang, w, d), "tipo": "house", "andares": 0, "altura": 0, "nome": "", "uso": "favela",
                            "modelo": modelo, "c": [round(x, 2), round(z, 2)], "frente": [round(f[0], 4), round(f[1], 4)]})
# fresta só vale se o vizinho existe dos dois lados (os dois lotes foram postos)
frestas = [{k: v for k, v in f.items() if k != "_pend"} for f in frestas
           if sum(1 for o in ocupado if math.dist(o[:2], ((f["a"][0] + f["b"][0]) / 2, (f["a"][1] + f["b"][1]) / 2)) < 9) >= 2]


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
            if not perto_rio(q, 4) and not any(math.dist(q, c[0]) < 10 for c in CRUZ) and zona(*q) != "favela" \
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

# favela: mais zumbis (becos apertados)
for k in range(4):
    a = R.uniform(0, math.tau)
    r = R.uniform(15, 60)
    zumbis.append([round(MORRO["p"][0] + math.cos(a) * r, 2), round(MORRO["p"][1] + math.sin(a) * r, 2)])

# ---------------- a capital destruída ao longe (norte, depois do muro): só silhueta ----------------
for (x, z, b, rot) in ((-330, 380, "building_03", 0.3), (-210, 430, "building_07", 0.0), (-90, 360, "building_01", 0.5),
                       (20, 450, "building_06", 0.1), (130, 380, "building_05", 0.8), (240, 420, "building_02", 0.2),
                       (350, 360, "building_04", 0.6), (-420, 300, "building_05", 1.2), (430, 300, "building_03", 0.9)):
    longe.append({"c": "res://assets/catalogo/majadroid/%s.glb" % b, "p": [x, -z], "r": rot})

out = {"origem": "São Jorge (tools/mapa/cidade_v2.py)", "ruas": ruas, "predios": predios, "frestas": frestas, "bloqueios": bloqueios,
       "marcos": marcos, "muros": muros, "props": props, "areas": areas, "faixas": faixas, "postes": postes, "veiculos": veiculos,
       "zumbis": zumbis, "longe": longe,
       "terreno": {"rio": {"p": rio, "larg": RIO_LARG, "fundo": 2.6, "agua": 1.7}, "morros": [MORRO]}}
json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "assets/mapa/cidade.json", "w"))
cont = {}
for p in predios:
    k = p["modelo"].split("_")[0]
    cont[k] = cont.get(k, 0) + 1
print("ruas", len(ruas), "predios", len(predios), cont, "muros", len(muros), "props", len(props), "postes", sum(len(c) for c in postes),
      "faixas", len(faixas), "frestas", len(frestas))
