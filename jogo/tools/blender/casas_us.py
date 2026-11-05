# Casas americanas de RAVEN CREEK (05/11, pedido do dono: "casas em modelo americano", nada de caixa lisa e pequena).
# Térrea grande (ranch) com garagem anexa, varanda coberta com guarda-corpo, revestimento de tábuas (siding), telha
# asfáltica com beiral e testeira, janelas de guilhotina com venezianas, fundação aparente, entrada de carro.
# Dentro: sala, cozinha, jantar, corredor, 2-3 quartos, banheiro, lavanderia, garagem; pisos (carpete/taco/linóleo),
# parede pintada ou papel com lambri, rodapé, forro e luminária. Móveis montados pelo compositor (interiores.py).
#   ~/.local/blender/blender -b -P tools/blender/casas_us.py -- assets/ruinas [nomes]
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ruinas  # noqa: E402
from ruinas import (bpy, math, Vector, rnd, caixa, junta, parede, piso, limpa, exporta, revestimento, batente,  # noqa: E402
                    marca_porta, sofa, poltrona, tv, estante, cama, criado, guarda_roupa, balcao, pia, fogao, geladeira,
                    vaso, banheira, box_banho, escrivaninha, _poe, PE, ESP, ESP_I, PORTA_L, PORTA_A, CORES, TECIDOS)
import interiores as I  # noqa: E402

CORES.update({
    "siding_branco": (0.9, 0.9, 0.88), "siding_azul": (0.55, 0.66, 0.78), "siding_amarelo": (0.92, 0.84, 0.58),
    "siding_cinza": (0.62, 0.64, 0.64), "siding_verde": (0.6, 0.7, 0.6), "siding_bege": (0.84, 0.78, 0.66),
    "siding_vermelho": (0.6, 0.28, 0.24),
    "shingle_cinza": (0.42, 0.42, 0.43), "shingle_marrom": (0.4, 0.3, 0.24), "shingle_preto": (0.2, 0.2, 0.21),
    "shingle_verde": (0.28, 0.36, 0.3),
    "carpete_bege": (0.78, 0.72, 0.62), "carpete_cinza": (0.6, 0.6, 0.6), "carpete_azul": (0.42, 0.5, 0.62),
    "carpete_vinho": (0.5, 0.26, 0.26), "linoleo": (0.9, 0.88, 0.84), "garagem": (0.9, 0.9, 0.88),
    "shutter_preto": (0.1, 0.1, 0.1), "shutter_verde": (0.15, 0.28, 0.2), "shutter_azul": (0.15, 0.22, 0.38),
    "shutter_vinho": (0.38, 0.12, 0.12), "fundacao": (0.55, 0.55, 0.53), "deck": (0.45, 0.35, 0.25),
})
SIDINGS = ["siding_branco", "siding_azul", "siding_amarelo", "siding_cinza", "siding_verde", "siding_bege", "siding_vermelho"]
SHINGLES = ["shingle_cinza", "shingle_marrom", "shingle_preto", "shingle_verde"]
SHUTTERS = ["shutter_preto", "shutter_verde", "shutter_azul", "shutter_vinho"]
CARPETES = ["carpete_bege", "carpete_cinza", "carpete_azul", "carpete_vinho"]
PINTURAS = ["pintura_creme", "pintura_verde", "pintura_azul", "pintura_rosa", "pintura_amarela", "pintura_branca"]
PAPEIS = ["papel_1", "papel_2", "papel_3"]
JB, JT, JL = 0.9, 2.2, 1.0          # janela de guilhotina: base, topo, largura
BEIRAL = 0.5


def janela_us(nome, a, b, tc, dentro_sinal, cor_veneziana, quebrada):
    """Guilhotina: moldura branca larga, travessa no meio, peitoril, venezianas dos lados por fora."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    n = Vector((-u.y, u.x, 0)) * dentro_sinal
    ang = math.atan2(u.y, u.x)
    c = a + u * tc
    zc, h = (JB + JT) / 2, JT - JB
    fora = c - n * (ESP / 2 + 0.03)
    pc = [caixa("m", (fora.x, fora.y, JT + 0.06), (JL + 0.3, 0.06, 0.14), "batente", (0, 0, ang)),
          caixa("m", (fora.x, fora.y, JB - 0.04), (JL + 0.3, 0.12, 0.06), "batente", (0, 0, ang))]
    for s in (-1, 1):
        q = fora + u * s * (JL / 2 + 0.06)
        pc.append(caixa("m", (q.x, q.y, zc), (0.12, 0.06, h + 0.2), "batente", (0, 0, ang)))
    pc.append(caixa("m", (c.x, c.y, zc), (JL, ESP * 0.6, 0.06), "batente", (0, 0, ang)))  # travessa da guilhotina
    junta(pc, nome + "_moldura")
    for s in (-1, 1):  # venezianas (persianas fixas de enfeite)
        q = fora - n * 0.02 + u * s * (JL / 2 + 0.4)
        caixa(nome + "_veneziana%d" % (s + 1), (q.x, q.y, zc), (0.45, 0.04, h + 0.05), cor_veneziana, (0, 0, ang))
    if quebrada:
        caixa(nome + "_caco", (c.x, c.y, JT - h * 0.18), (JL, 0.015, h * 0.3), "vidro_janela", (0, rnd.uniform(-0.25, 0.25), ang))
    else:
        caixa(nome + "_vidro", (c.x, c.y, zc), (JL, 0.015, h), "vidro_janela", (0, 0, ang))


def telhado_us(nome, x0, x1, y0, y1, z, cor, alt=2.2):
    """Duas águas com a cumeeira em x, beiral nos 4 lados, testeira branca e oitão de siding (o oitão fica com a
    cor da casa: siding_*)."""
    w, d = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    agua = math.hypot(d / 2 + BEIRAL, alt)
    ang = math.atan2(alt, d / 2 + BEIRAL)
    pl = []
    for s in (-1, 1):
        yc = cy + s * (d / 2 + BEIRAL) / 2
        pl.append(caixa("t", (cx, yc, z + alt / 2), (w + 2 * BEIRAL, agua, 0.12), cor, (s * -ang, 0, 0)))
    junta(pl, nome + "-col")
    tes = []
    for s in (-1, 1):  # testeira (fascia) na beira das águas
        tes.append(caixa("f", (cx, cy + s * (d / 2 + BEIRAL), z - 0.08), (w + 2 * BEIRAL, 0.04, 0.22), "batente"))
    junta(tes, nome + "_testeira")
    return alt


def oitao(nome, x, y0, y1, z, alt, m):
    me = bpy.data.meshes.new(nome)
    cy = (y0 + y1) / 2
    me.from_pydata([(x, y0, z), (x, y1, z), (x, cy, z + alt)], [], [(0, 1, 2)])
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(ruinas.mat(m))
    sol = o.modifiers.new("esp", "SOLIDIFY")
    sol.thickness = ESP
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=sol.name)
    return o


# ---------- móveis que faltavam (mesmo giro dos de ruinas.py: frente para -Y) ----------
def cama_casal(nome, x, y, ang, larg=1.6):
    p = [caixa("c", (0, 0, 0.2), (larg, 2.05, 0.25), "madeira"), caixa("c", (0, 0, 0.45), (larg - 0.1, 1.95, 0.22), "pano"),
         caixa("c", (0, 1.0, 0.65), (larg, 0.08, 1.0), "madeira"),
         caixa("c", (-larg / 4, 0.7, 0.62), (larg / 2 - 0.15, 0.4, 0.12), "branco"), caixa("c", (larg / 4, 0.7, 0.62), (larg / 2 - 0.15, 0.4, 0.12), "branco"),
         caixa("c", (0.1, -0.3, 0.58), (larg, 1.1, 0.04), rnd.choice(TECIDOS), (0, 0.12, 0.1))]
    _poe(junta(p, nome + "-col"), x, y, ang)


def comoda(nome, x, y, ang):
    p = [caixa("c", (0, 0, 0.45), (1.0, 0.5, 0.9), "madeira")]
    for k in range(3):
        p.append(caixa("c", (0, -0.26, 0.18 + k * 0.27), (0.9, 0.02, 0.22), "madeira"))
    _poe(junta(p, nome + "-col"), x, y, ang)


def mesa_us(nome, x, y, ang):
    p = [caixa("m", (0, 0, 0.74), (1.4, 0.9, 0.05), "madeira")]
    for sx in (-0.62, 0.62):
        for sy in (-0.38, 0.38):
            p.append(caixa("m", (sx, sy, 0.36), (0.06, 0.06, 0.72), "madeira"))
    _poe(junta(p, nome + "-col"), x, y, ang)


def cadeira_us(nome, x, y, ang):
    p = [caixa("k", (0, 0, 0.45), (0.42, 0.42, 0.04), "madeira"), caixa("k", (0, 0.19, 0.7), (0.42, 0.04, 0.5), "madeira")]
    for sx in (-0.18, 0.18):
        for sy in (-0.18, 0.18):
            p.append(caixa("k", (sx, sy, 0.22), (0.04, 0.04, 0.44), "madeira"))
    _poe(junta(p, nome), x, y, ang)  # cadeira sem colisão: não prende o jogador entre a mesa


def pia_banheiro(nome, x, y, ang):
    p = [caixa("p", (0, 0, 0.42), (0.6, 0.46, 0.84), "madeira"), caixa("p", (0, 0, 0.86), (0.62, 0.48, 0.04), "branco"),
         caixa("p", (0, 0.22, 1.55), (0.55, 0.02, 0.75), "vidro_janela")]  # espelho na parede
    _poe(junta(p, nome + "-col"), x, y, ang)


def maquina(nome, x, y, ang):
    p = [caixa("l", (0, 0, 0.45), (0.62, 0.62, 0.9), "branco"), caixa("l", (0, -0.32, 0.5), (0.4, 0.02, 0.4), "vidro")]
    _poe(junta(p, nome + "-col"), x, y, ang)


def bancada_ferramentas(nome, x, y, ang):
    p = [caixa("b", (0, 0, 0.9), (1.8, 0.7, 0.06), "madeira"), caixa("b", (0, 0.33, 1.5), (1.8, 0.03, 1.1), "madeira")]
    for sx in (-0.85, 0.85):
        p.append(caixa("b", (sx, 0, 0.45), (0.06, 0.6, 0.9), "madeira"))
    _poe(junta(p, nome + "-col"), x, y, ang)


def tapete_em(nome, x, y, ang, larg, prof):
    q = round(ang / (math.pi / 2)) % 2
    w, d = (larg, prof) if q == 0 else (prof, larg)
    caixa(nome, (x, y, 0.1), (w, d, 0.012), "tapete", (0, 0, rnd.uniform(-0.05, 0.05)))  # em cima do piso (topo 0,09)


def abajur_pe(nome, x, y):
    junta([caixa("a", (0, 0, 0.75), (0.04, 0.04, 1.5), "metal"), caixa("a", (0, 0, 0.05), (0.3, 0.3, 0.04), "metal"),
           caixa("a", (0, 0, 1.5), (0.38, 0.38, 0.3), "tecido_mostarda")], nome).location = (x, y, 0.06)


CONSTROI = {
    "sofa": lambda n, i: sofa(n, i["x"], i["y"], i["ang"], rnd.choice(TECIDOS)),
    "poltrona": lambda n, i: poltrona(n, i["x"], i["y"], i["ang"], rnd.choice(TECIDOS)),
    "mesa_centro": lambda n, i: _poe(junta([caixa("m", (0, 0, 0.42), (1.1, 0.6, 0.05), "madeira")] +
                                           [caixa("m", (sx, sy, 0.2), (0.05, 0.05, 0.4), "madeira") for sx in (-0.5, 0.5) for sy in (-0.25, 0.25)],
                                           n + "-col"), i["x"], i["y"], i["ang"]),
    "tv": lambda n, i: tv(n, i["x"], i["y"], i["ang"]),
    "estante": lambda n, i: estante(n, i["x"], i["y"], i["ang"]),
    "abajur": lambda n, i: abajur_pe(n, i["x"], i["y"]),
    "tapete": lambda n, i: tapete_em(n, i["x"], i["y"], i["ang"], 2.4, 1.7),
    "tapete_quarto": lambda n, i: tapete_em(n, i["x"], i["y"], i["ang"], 1.4, 1.0),
    "cama": lambda n, i: cama_casal(n, i["x"], i["y"], i["ang"]),
    "cama_solteiro": lambda n, i: cama(n, i["x"], i["y"], i["ang"]),
    "criado": lambda n, i: criado(n, i["x"], i["y"], i["ang"]),
    "guarda_roupa": lambda n, i: guarda_roupa(n, i["x"], i["y"], i["ang"]),
    "comoda": lambda n, i: comoda(n, i["x"], i["y"], i["ang"]),
    "balcao": lambda n, i: balcao(n, i["x"], i["y"], i["ang"], 0.8),
    "pia": lambda n, i: pia(n, i["x"], i["y"], i["ang"]),
    "fogao": lambda n, i: fogao(n, i["x"], i["y"], i["ang"]),
    "geladeira": lambda n, i: geladeira(n, i["x"], i["y"], i["ang"], rnd.random() < 0.15),
    "mesa": lambda n, i: mesa_us(n, i["x"], i["y"], i["ang"]),
    "cadeira": lambda n, i: cadeira_us(n, i["x"], i["y"], i["ang"]),
    "vaso": lambda n, i: vaso(n, i["x"], i["y"], i["ang"]),
    "pia_banheiro": lambda n, i: pia_banheiro(n, i["x"], i["y"], i["ang"]),
    "banheira": lambda n, i: banheira(n, i["x"], i["y"], i["ang"]),
    "chuveiro": lambda n, i: box_banho(n, i["x"], i["y"], i["ang"]),
    "lavadora": lambda n, i: maquina(n, i["x"], i["y"], i["ang"]),
    "secadora": lambda n, i: maquina(n, i["x"], i["y"], i["ang"]),
    "bancada": lambda n, i: bancada_ferramentas(n, i["x"], i["y"], i["ang"]),
    "prateleira": lambda n, i: estante(n, i["x"], i["y"], i["ang"], cor="metal"),
    "escrivaninha": lambda n, i: escrivaninha(n, i["x"], i["y"], i["ang"]),
    "aparador": lambda n, i: comoda(n, i["x"], i["y"], i["ang"]),
}
NOME = {"prateleira": "despensa", "lavadora": "lavadora", "secadora": "secadora", "aparador": "aparador"}


def mobilia(tipo, nome, c, semente):
    """Compõe o cômodo (regras) e constrói cada móvel com o nome que o jogo entende (gaveta, troca por modelo)."""
    itens, probs = I.compoe(tipo, c, random.Random(semente))
    if probs:
        print("INTERIOR_PROBLEMA", nome, tipo, probs)
    if os.environ.get("MOSTRA_COMODOS"):
        print("COMODO", nome, tipo, "%.1fx%.1f" % (c.x1 - c.x0, c.y1 - c.y0), "portas", [(p, round(t, 1)) for (p, t, lg) in c.portas],
              [(i["tipo"], round(i["x"] - c.x0, 1), round(i["y"] - c.y0, 1), round(math.degrees(i["ang"]))) for i in itens])
    for k, i in enumerate(itens):
        base = NOME.get(i["tipo"], i["tipo"])
        CONSTROI[i["tipo"]]("%s_%s%d" % (base, nome, k), i)
    return itens


def casa_us(nome, w, d, semente, garagem=True, quartos=2, varanda=True):
    """Térrea americana. Corpo w x d (frente em y = -d/2), garagem de 3,8 x 6,5 encostada à esquerda (fora de w),
    varanda de 2,2 m na frente (fora de d)."""
    limpa()
    rnd.seed(semente)
    sid, tel, ven = rnd.choice(SIDINGS), rnd.choice(SHINGLES), rnd.choice(SHUTTERS)
    hw, hd = w / 2, d / 2
    fy, by = -hd, hd
    corr = 1.2
    xb = hw - (3.8 if w < 14 else 4.1)     # coluna B (quartos/banheiro) com fundo de quarto de verdade
    xa = xb - corr                         # coluna A (sala | cozinha + lavanderia) até xa; corredor no meio
    ym = fy + d * 0.52                     # sala | cozinha
    lav = 2.3 if garagem else 0.0          # lavanderia entre a garagem e a cozinha (entra-se da garagem por ela)
    xl = -hw + lav
    dq = (by - fy)
    nq = quartos
    # coluna B: quarto(s) e banheiro: [quarto1 | banheiro | quarto2 (| quarto3)]
    ban = 2.3
    resto = dq - ban
    tam_q = resto / nq
    ys = [fy + tam_q]
    ys.append(ys[0] + ban)
    for k in range(nq - 1):
        ys.append(ys[-1] + tam_q)
    ys[-1] = by
    # ---- paredes de fora (aberturas: t, largura, base, topo) ----
    pf_t = (xa - (-hw)) / 2                       # porta da frente no meio da sala
    jan = lambda t: (t, JL, JB, JT)
    ext = {}
    ext["frente"] = ((-hw, fy), (hw, fy), [(pf_t, PORTA_L, 0, PORTA_A), jan(pf_t + 1.6 if pf_t + 1.6 < xa - (-hw) - 0.7 else pf_t - 1.6),
                                          jan((xb + hw) / 2 + hw)])
    ext["dir"] = ((hw, fy), (hw, by), [jan((ys[0] - fy) / 2)] + [jan((ys[k] + ys[k + 1]) / 2 - fy) for k in range(1, len(ys) - 1)]
                  + [(((ys[0] + ys[1]) / 2 - fy), 0.6, 1.5, 2.1)])
    xk = (xl + xa) / 2                                   # meio da cozinha
    ext["fundo"] = ((hw, by), (-hw, by), [(hw - (xa - 0.8), 0.9, 0, PORTA_A), jan(hw - (xk - 0.3))] +
                   ([(hw - (-hw + lav / 2), 0.6, 1.5, 2.1)] if garagem else []))
    yg = min(ym + 0.7, fy + 6.0)                          # porta da garagem para a lavanderia
    ext["esq"] = ((-hw, by), (-hw, fy), [(by - yg, 0.9, 0, PORTA_A)] if garagem else
                  [jan((by - ym) / 2), jan(by - (fy + ym) / 2)])
    for k, (a, b, ab) in ext.items():
        parede("ext_" + k, a, b, 0, PE, ab, sid)
        u = Vector((b[0] - a[0], b[1] - a[1], 0)).normalized()
        fo = Vector((u.y, -u.x, 0)) * (ESP / 2 + 0.02)
        parede("ext_fundacao_" + k, (a[0] + fo.x, a[1] + fo.y), (b[0] + fo.x, b[1] + fo.y), -0.1, 0.45,
               [(t, lg, 0, 0.5) for (t, lg, base, topo) in ab if base < 0.5], "fundacao", esp=0.04)
        for (t, lg, base, topo) in ab:
            if base > 0.5 and lg > 0.8:
                janela_us("jan_%s_%d" % (k, int(t * 10)), a, b, t, 1, ven, rnd.random() < 0.3)
            elif base > 0.5:
                q = Vector((a[0], a[1], (base + topo) / 2)) + u * t
                caixa("jan_%s_%d_vidro" % (k, int(t * 10)), (q.x, q.y, q.z), (lg, 0.02, topo - base), "vidro_janela",
                      (0, 0, math.atan2(u.y, u.x)))
            elif k != "frente":
                batente("batente_%s_%d" % (k, int(t * 10)), a, b, t, lg, topo, ESP)
    for (x, y) in ((-hw, fy), (hw, fy), (hw, by), (-hw, by)):  # cantoneiras brancas
        caixa("ext_canto", (x, y, PE / 2), (ESP + 0.08, ESP + 0.08, PE), "batente")
    marca_porta(-hw + pf_t, fy)
    # ---- paredes de dentro ----
    intern = {
        "a_meio": ((-hw, ym), (xa, ym), [((xk + hw), 1.4, 0, PORTA_A)]),                            # sala | cozinha (passagem larga)
        "corr_a": ((xa, fy), (xa, by), [((ym - fy) / 2, 1.0, 0, PORTA_A)]),                         # sala | corredor
        "corr_b": ((xb, fy), (xb, by), [((ys[k] + (ys[k - 1] if k else fy)) / 2 - fy, 0.85, 0, PORTA_A) for k in range(len(ys))]),
    }
    for k in range(len(ys) - 1):
        intern["b_%d" % k] = ((xb, ys[k]), (hw, ys[k]), [])
    if garagem:
        intern["lav"] = ((xl, ym), (xl, by), [((by - ym) / 2 + 0.4, 0.85, 0, PORTA_A)])           # lavanderia | cozinha
    for k, (a, b, ab) in intern.items():
        parede("int_" + k, a, b, 0, PE, ab, "parede", esp=ESP_I)
        for (t, lg, base, topo) in ab:
            batente("batente_%s_%d" % (k, int(t * 10)), a, b, t, lg, topo, ESP_I)
    # ---- cômodos: tipo, retângulo, piso, parede de cima, de baixo, altura de baixo ----
    carpete = rnd.choice(CARPETES)
    tabua = rnd.random() < 0.5
    sala_par = rnd.choice(PAPEIS) if rnd.random() < 0.3 else rnd.choice(PINTURAS)
    e2 = ESP / 2
    i2 = ESP_I / 2
    comodos = [("sala", "sala", -hw + e2, xa - i2, fy + e2, ym - i2, "piso_tabua" if tabua else carpete, sala_par, "batente", 0.1),
               ("cozinha", "cozinha", (xl + i2) if garagem else (-hw + e2), xa - i2, ym + i2, by - e2, "linoleo", rnd.choice(PINTURAS), "azulejo", 1.2),
               ("corredor", "corredor", xa + i2, xb - i2, fy + e2, by - e2, "piso_tabua", sala_par, "batente", 0.1)]
    if garagem:
        comodos.append(("lavanderia", "lavanderia", -hw + e2, xl - i2, ym + i2, by - e2, "linoleo", "pintura_branca", "batente", 0.1))
    tipos_q = ["quarto"] + ["quarto_crianca"] * (nq - 1)
    yq = [fy] + ys
    qk = 0
    for k in range(len(ys)):
        y0, y1 = yq[k] + (e2 if k == 0 else i2), yq[k + 1] - (e2 if k == len(ys) - 1 else i2)
        if k == 1:
            comodos.append(("banheiro", "banheiro", xb + i2, hw - e2, y0, y1, "linoleo", "pintura_branca", "azulejo", 1.3))
        else:
            comodos.append(("quarto%d" % (qk + 1), tipos_q[qk], xb + i2, hw - e2, y0, y1, carpete, rnd.choice(PINTURAS) if rnd.random() < 0.75 else rnd.choice(PAPEIS), "batente", 0.1))
            qk += 1
    linhas = [(a, b, ab, ESP) for (a, b, ab) in ext.values()] + [(a, b, ab, ESP_I) for (a, b, ab) in intern.values()]
    for (cn, tipo, x0, x1, y0, y1, pi, mc, mb, alt_b) in comodos:
        caixa("piso_" + cn, ((x0 + x1) / 2, (y0 + y1) / 2, 0.075), (x1 - x0, y1 - y0, 0.03), pi)
        caixa("forro_luz_" + cn, ((x0 + x1) / 2, (y0 + y1) / 2, PE - 0.08), (0.35, 0.35, 0.06), "branco")
        lados = [((x0, y0), (x1, y0), Vector((0, 1, 0))), ((x1, y0), (x1, y1), Vector((-1, 0, 0))),
                 ((x1, y1), (x0, y1), Vector((0, -1, 0))), ((x0, y1), (x0, y0), Vector((1, 0, 0)))]
        portas, janelas = [], []
        for i, (p0, p1, nrm) in enumerate(lados):
            ab = _aberturas_em(linhas, p0, p1)
            revestimento("rev_%s_%d" % (cn, i), p0, p1, ab, nrm * 0.011, mb, mc, alt_b)
            for (t, lg, base, topo) in ab:  # para o compositor: t a partir do canto de menor coordenada
                L = abs(p1[0] - p0[0]) + abs(p1[1] - p0[1])
                tt = t if i in (0, 1) else L - t
                if base < 0.5:
                    portas.append((i, tt, lg))
                else:
                    janelas.append((i, tt, lg, base))
        if tipo != "corredor":
            portas.sort(key=lambda p: -p[2])
            mobilia(tipo, cn, I.Comodo(x0, y0, x1, y1, portas, janelas), semente * 31 + len(cn))
    # ---- garagem anexa à esquerda ----
    if garagem:
        gx1, gx0 = -hw, -hw - 3.8
        gy0, gy1 = fy, fy + 6.5
        parede("ext_gar_frente", (gx0, gy0), (gx1, gy0), 0, PE - 0.3, [((gx1 - gx0) / 2, 2.8, 0, 2.3)], sid)
        parede("ext_gar_esq", (gx0, gy1), (gx0, gy0), 0, PE - 0.3, [(2.0, JL, JB, JT - 0.2)], sid)
        parede("ext_gar_fundo", (gx1, gy1), (gx0, gy1), 0, PE - 0.3, [], sid)
        aberto = rnd.random() < 0.5
        cx = (gx0 + gx1) / 2
        caixa("portao_garagem" + ("" if aberto else "-col"), (cx, gy0 - 0.02 if not aberto else gy0 + 0.6, 1.15 if not aberto else 2.35),
              (2.8, 0.06, 2.3) if not aberto else (2.8, 2.0, 0.06), "garagem")
        caixa("piso_garagem", (cx, (gy0 + gy1) / 2, 0.06), (3.8 - ESP, 6.5 - ESP, 0.02), "concreto")
        caixa("entrada_carro", (cx, gy0 - 3.5, 0.03), (3.2, 7.0, 0.04), "concreto")
        mobilia("garagem", "garagem", I.Comodo(gx0 + e2, gy0 + e2, gx1 - e2, gy1 - e2, [(0, (gx1 - gx0) / 2 - e2, 2.8)], []), semente + 7)
        telhado_us("telhado_gar", gx0, gx1, gy0, gy1, PE - 0.3, tel, 1.3)
        oitao("ext_oitao_gar", gx0, gy0, gy1, PE - 0.3, 1.3, sid)
    # ---- varanda ----
    if varanda:
        vy0 = fy - 2.2
        caixa("varanda_deck-col", (0, (vy0 + fy) / 2, 0.1), (w, 2.2, 0.2), "deck")
        caixa("varanda_degrau-col", (-hw + pf_t, vy0 - 0.3, 0.06), (1.8, 0.6, 0.12), "deck")
        pil, gc = [], []
        for x in (-hw + 0.2, -hw + pf_t - 1.1, -hw + pf_t + 1.1, hw - 0.2):
            pil.append(caixa("v", (x, vy0 + 0.2, PE / 2), (0.18, 0.18, PE), "batente"))
        junta(pil, "varanda_colunas-col")
        for (xa_, xb_) in ((-hw + 0.3, -hw + pf_t - 1.0), (-hw + pf_t + 1.0, hw - 0.3)):  # guarda-corpo, menos na escada
            if xb_ - xa_ < 0.3:
                continue
            gc.append(caixa("g", ((xa_ + xb_) / 2, vy0 + 0.2, 0.95), (xb_ - xa_, 0.08, 0.06), "batente"))
            n = int((xb_ - xa_) / 0.15)
            for k in range(n):
                gc.append(caixa("g", (xa_ + 0.075 + k * (xb_ - xa_) / n, vy0 + 0.2, 0.6), (0.04, 0.04, 0.7), "batente"))
        junta(gc, "varanda_guarda_corpo-col")
        caixa("varanda_cobertura-col", (0, (vy0 + fy) / 2 - 0.1, PE + 0.15), (w + 0.4, 2.6, 0.1), tel, (-0.18, 0, 0))
        caixa("varanda_testeira", (0, vy0 - 0.2, PE - 0.05), (w + 0.4, 0.04, 0.2), "batente")
        caixa("caixa_correio", (-hw + pf_t + 2.5, vy0 - 3.5, 0.95), (0.2, 0.45, 0.22), "metal")
        caixa("caixa_correio_poste", (-hw + pf_t + 2.5, vy0 - 3.5, 0.45), (0.06, 0.06, 0.9), "madeira")
    # ---- teto, telhado, chaminé ----
    piso("chao", -hw, fy, hw, by, 0.06, "concreto", 0.06)
    piso("forro", -hw, fy, hw, by, PE, "forro", 0.05, col=False)
    alt = telhado_us("telhado", -hw, hw, fy, by, PE, tel)
    for x in (-hw, hw):
        oitao("ext_oitao%d" % (1 if x > 0 else 0), x, fy, by, PE, alt, sid)
    if rnd.random() < 0.6:
        caixa("ext_chamine-col", (hw - 1.2, by - 2.0, PE + alt - 0.2), (0.9, 0.7, 2.2), "tijolo")
    acab = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith(("-col", "-colonly"))
            and o.name.startswith(("rev_", "piso_", "bag_", "forro_luz"))]
    if acab:
        junta(acab, "acabamento")
    exporta(nome)


def _aberturas_em(linhas, p0, p1):
    """Aberturas no trecho p0->p1 de alguma parede na mesma reta (t a partir de p0)."""
    for (a, b, ab, e) in linhas:
        vert = abs(a[0] - b[0]) < 1e-3
        if vert and abs(p0[0] - p1[0]) < 1e-3 and abs(p0[0] - a[0]) <= e / 2 + 0.02:
            s = 1 if b[1] > a[1] else -1
            t0, t1 = (p0[1] - a[1]) * s, (p1[1] - a[1]) * s
            return _cortes(ab, t0, t1)
        if not vert and abs(p0[1] - p1[1]) < 1e-3 and abs(p0[1] - a[1]) <= e / 2 + 0.02:
            s = 1 if b[0] > a[0] else -1
            t0, t1 = (p0[0] - a[0]) * s, (p1[0] - a[0]) * s
            return _cortes(ab, t0, t1)
    return []


def _cortes(ab, t0, t1):
    inv = t0 > t1
    lo, hi = min(t0, t1), max(t0, t1)
    out = []
    for (t, lg, base, topo) in ab:
        if lo + lg / 2 - 0.01 <= t <= hi - lg / 2 + 0.01:
            out.append(((hi - t) if inv else (t - lo), lg, base, topo))
    return out


if __name__ == "__main__":
    ruinas.SAIDA = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/ruinas"
    SO = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
    TODOS = [("casa_us_%d" % (k + 1), (w, d, s, g, q, v)) for k, (w, d, s, g, q, v) in enumerate([
        (13.0, 10.0, 701, True, 2, True), (14.5, 12.0, 702, True, 3, True), (12.0, 10.0, 703, False, 2, True),
        (15.0, 12.0, 704, True, 3, False), (12.5, 10.0, 705, True, 2, True), (13.5, 11.5, 706, False, 3, True)])]
    for nome, (w, d, s, g, q, v) in TODOS:
        if not SO or nome in SO:
            casa_us(nome, w, d, s, g, q, v)
    print("CASAS_US_OK")
