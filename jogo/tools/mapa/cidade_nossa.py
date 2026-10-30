# Cidade nossa (pedido do dono, 30/10: "cidade reta, cheia de rua reta, não"): traçado orgânico gerado com semente fixa,
# no mesmo formato do JSON do OpenStreetMap que o Bairro já lê (ruas e prédios), mais frestas, bloqueios e marcos.
#   python3 tools/mapa/cidade_nossa.py assets/mapa/cidade.json
# Bairros: centro (lojas e prédios colados, becos e frestas), casas (ao norte e ao sul, quintal e cerca), zona
# industrial (leste, galpões grandes) e beira (oeste, posto e mata). Ruas: avenida curva atravessando tudo, duas ruas
# de norte a sul, e ruas que crescem tortas a partir delas (algumas sem saída). Coordenadas locais em metros (x, z),
# área de -250 a 250.
import json
import math
import random
import sys

R = random.Random(30)
LIM = 240.0
LARG = {"primary": 10.0, "secondary": 8.0, "tertiary": 7.0, "residential": 6.5, "service": 5.0}
ruas = []      # {"p": [[x, z], ...], "tipo": t}
segs = []      # (a, b, meia largura)


def bairro_de(x, z):
    if abs(x) < 95 and abs(z) < 75:
        return "centro"
    if x > 120:
        return "industrial"
    if x < -150:
        return "beira"
    return "casas"


def catmull(pts, passo=6.0):
    """Curva suave passando pelos pontos de controle."""
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


def poe_rua(pts, tipo):
    ruas.append({"p": pts, "tipo": tipo})
    for a, b in zip(pts, pts[1:]):
        segs.append((a, b, LARG[tipo] / 2))


def dist_seg(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    l2 = ax * ax + az * az
    t = 0 if l2 == 0 else max(0, min(1, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / l2))
    return math.dist(p, (a[0] + ax * t, a[1] + az * t))


def perto_rua(p, folga, ignora=None):
    return any(dist_seg(p, a, b) < m + folga for (a, b, m) in segs if ignora is None or (a, b, m) not in ignora)


def cresce(x, z, ang, tipo, comp, curva=0.1):
    """Rua torta crescendo de (x, z): para ao chegar perto de outra rua (vira um T) ou na borda; sem saída se não."""
    pts = [[x, z]]
    proprios = set()
    for _ in range(int(comp / 6)):
        ang += R.uniform(-curva, curva)
        nx, nz = pts[-1][0] + math.cos(ang) * 6, pts[-1][1] + math.sin(ang) * 6
        if abs(nx) > LIM or abs(nz) > LIM:
            break
        if len(pts) > 3 and perto_rua((nx, nz), 2.0):
            pts.append([round(nx, 2), round(nz, 2)])
            break
        pts.append([round(nx, 2), round(nz, 2)])
    if len(pts) > 4:
        poe_rua(pts, tipo)
        return pts
    return None


def ponto_em(pts, frac):
    i = min(len(pts) - 2, int(frac * (len(pts) - 1)))
    a, b = pts[i], pts[i + 1]
    return a, math.atan2(b[1] - a[1], b[0] - a[0])


# ---- traçado ----
av = catmull([(-250, -30), (-170, 5), (-80, -22), (0, 8), (80, -18), (160, 12), (250, -12)])
poe_rua(av, "primary")
oeste = catmull([(-70, -250), (-55, -150), (-85, -60), (-60, 30), (-95, 130), (-70, 250)])
leste = catmull([(55, -250), (85, -160), (45, -70), (70, 35), (35, 140), (65, 250)])
poe_rua(oeste, "secondary")
poe_rua(leste, "secondary")
anel = catmull([(-150, -120), (-90, -175), (0, -185), (95, -170), (150, -110)])
poe_rua(anel, "tertiary")
anel_n = catmull([(150, 110), (90, 170), (0, 185), (-95, 165), (-150, 105)])
poe_rua(anel_n, "tertiary")
# ruas tortas saindo das grandes (algumas viram sem saída)
for base, n in ((av, 14), (oeste, 7), (leste, 7), (anel, 5), (anel_n, 5)):
    for k in range(n):
        p, ang = ponto_em(base, R.uniform(0.08, 0.92))
        lado = R.choice((-1, 1))
        a = ang + lado * (math.pi / 2 + R.uniform(-0.45, 0.45))
        x, z = p[0] + math.cos(a) * 6, p[1] + math.sin(a) * 6
        if perto_rua((x, z), 1.0):
            continue
        cresce(p[0], p[1], a, "residential", R.uniform(50, 130), 0.13)
# zona industrial: ruas de serviço largas e mais retas
for z0 in (-120, -60, 60, 120):
    cresce(140, z0, R.uniform(-0.2, 0.2), "service", 110, 0.03)

# ---- terreno: rio raso cortando a cidade (as ruas passam por ponte) e um morro no lugar mais vazio ----
rio = catmull([(-260, 128), (-160, 142), (-60, 116), (30, 136), (120, 104), (260, 92)], 8.0)
RIO_LARG = 14.0


def perto_rio(p, folga):
    return any(dist_seg(p, a, b) < RIO_LARG / 2 + folga for a, b in zip(rio, rio[1:]))


melhor, folga_m = None, 0.0
for gx in range(-200, 201, 10):
    for gz in range(-200, 201, 10):
        f = min(min(dist_seg((gx, gz), a, b) - m for (a, b, m) in segs), min(dist_seg((gx, gz), a, b) for a, b in zip(rio, rio[1:])) - RIO_LARG)
        if f > folga_m:
            melhor, folga_m = (gx, gz), f
morros = [{"p": list(melhor), "raio": round(min(folga_m - 4.0, 60.0), 1), "alt": 9.0}] if melhor and folga_m > 30 else []


def no_morro(p, folga):
    return any(math.dist(p, m["p"]) < m["raio"] + folga for m in morros)


# ---- lotes ----
predios = []
caixas = []  # (cx, cz, ang, w, d) para conferir sobreposição


def cantos(cx, cz, ang, w, d):
    c, s = math.cos(ang), math.sin(ang)
    return [[round(cx + c * x - s * z, 2), round(cz + s * x + c * z, 2)] for (x, z) in
            ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]


def sobrepoe(a, b):
    """Teste de eixos separados entre dois retângulos girados (com 0,4 m de folga)."""
    pa, pb = cantos(*a[:3], a[3] + 0.4, a[4] + 0.4), cantos(*b[:3], b[3] + 0.4, b[4] + 0.4)
    for poly in (pa, pb):
        for i in range(4):
            e = (poly[(i + 1) % 4][0] - poly[i][0], poly[(i + 1) % 4][1] - poly[i][1])
            n = (-e[1], e[0])
            sa = [n[0] * p[0] + n[1] * p[1] for p in pa]
            sb = [n[0] * p[0] + n[1] * p[1] for p in pb]
            if max(sa) < min(sb) or max(sb) < min(sa):
                return False
    return True


TAMS = {  # bairro: (larguras, fundos, recuo da calçada, vão entre lotes, tipo)
    "centro": ((12, 16, 18), (10, 12), 2.2, (0.55, 0.55, 0.55, 3.0), "commercial"),
    "casas": ((8, 9, 10.5, 12.5), (7, 8, 9), 5.0, (3.0, 5.0, 8.0), "house"),
    "industrial": ((16, 18), (12, 12), 6.0, (6.0, 10.0), "industrial"),
    "beira": ((8, 12), (7, 10), 8.0, (12.0, 20.0), "house"),
}
frestas = []
for r in ruas:
    m = LARG[r["tipo"]] / 2
    for lado in (-1, 1):
        t = R.uniform(2, 8)
        pts = r["p"]
        comp_total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
        ant = None
        vao = 3.0
        while t < comp_total - 6:
            # ponto e direção na distância t
            acc = 0
            for a, b in zip(pts, pts[1:]):
                l = math.dist(a, b)
                if acc + l >= t:
                    f = (t - acc) / l
                    p = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
                    ang = math.atan2(b[1] - a[1], b[0] - a[0])
                    break
                acc += l
            bz = bairro_de(*p)
            ws, ds, recuo, vaos, tipo = TAMS[bz]
            w, d = R.choice(ws), R.choice(ds)
            nx, nz = -math.sin(ang) * lado, math.cos(ang) * lado  # normal para o lado do lote
            off = m + 1.7 + recuo + d / 2
            cx, cz = p[0] + nx * off, p[1] + nz * off
            ang_lote = math.atan2(nz, nx) - math.pi / 2  # frente (−z local) virada para a rua
            cx += math.cos(ang) * w / 2
            cz += math.sin(ang) * w / 2
            cx_ok = abs(cx) < LIM - 10 and abs(cz) < LIM - 10
            novo = (cx, cz, ang_lote, w, d)
            cs = cantos(*novo)
            livre = cx_ok and not any(perto_rua(c, 1.2) or perto_rio(c, 3.0) or no_morro(c, 3.0) for c in cs) and not perto_rua((cx, cz), 1.2) \
                and not any(sobrepoe(novo, o) for o in caixas if math.dist(o[:2], novo[:2]) < 30)
            vao_ant = vao
            vao = R.choice(vaos)
            if livre:
                caixas.append(novo)
                predios.append({"p": cs, "tipo": tipo, "andares": 0, "altura": 0, "nome": "", "uso": bz})
                # dois lotes colados no centro com vão estreito = fresta para passar de lado
                if ant is not None and bz == "centro" and vao_ant < 1.0 and math.dist(ant[:2], novo[:2]) < (ant[3] + w) / 2 + 1.5:
                    fx, fz = cx - math.cos(ang) * (w / 2 + vao_ant / 2), cz - math.sin(ang) * (w / 2 + vao_ant / 2)
                    frente = (fx - nx * d / 2, fz - nz * d / 2)
                    fundo = (fx + nx * d / 2, fz + nz * d / 2)
                    frestas.append({"a": [round(frente[0], 2), round(frente[1], 2)], "b": [round(fundo[0], 2), round(fundo[1], 2)],
                                    "larg": vao_ant})
                ant = novo
            else:
                ant = None
            t += w + vao

# ---- bloqueios: pilhas de carro fechando algumas ruas tortas no meio ----
bloqueios = []
for r in ruas:
    if r["tipo"] == "residential" and len(r["p"]) > 10 and R.random() < 0.3:
        p, ang = ponto_em(r["p"], R.uniform(0.35, 0.65))
        bloqueios.append({"p": [round(p[0], 2), round(p[1], 2)], "ang": round(ang + math.pi / 2, 3), "larg": LARG["residential"] + 3.4})

# ---- marcos que se veem de longe ----
marcos = [{"tipo": "caixa_dagua", "p": [-30, 110]}, {"tipo": "caixa_dagua", "p": [190, -40]},
          {"tipo": "antena", "p": [-200, -150]}]

out = {"origem": "cidade nossa (tools/mapa/cidade_nossa.py)", "ruas": ruas, "predios": predios, "frestas": frestas,
       "bloqueios": bloqueios, "marcos": marcos,
       "terreno": {"rio": {"p": rio, "larg": RIO_LARG, "fundo": 2.6, "agua": 1.7}, "morros": morros}}
json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "assets/mapa/cidade.json", "w"))
print("ruas", len(ruas), "predios", len(predios), "frestas", len(frestas), "bloqueios", len(bloqueios), "morros", morros)
