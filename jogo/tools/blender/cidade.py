# Cidade nova (31/10, dono: "uma puta de uma cidade completamente diferente; pode demorar horas"): prédios de cidade
# brasileira de interior no fim do mundo, modelados por código no Blender com as mesmas regras de tools/blender/ruinas.py
# (frente em -Y = +Z no Godot, "-col" / "-colonly", materiais só pelo nome, sombra de canto nos vértices).
#   ~/.local/blender/blender -b -P tools/blender/cidade.py -- assets/ruinas [nomes...]
# Sobrados de comércio com porta de aço, marquise e letreiro (FARMÁCIA, PADARIA...), prédios de apartamento, igreja
# matriz, hospital e supermercado (raids, com pontos marcados), barracos de morro, e peças de rua (poste com fiação,
# ponto de ônibus, orelhão, banca, coreto, pórtico da entrada, caçamba, traves). Pichação nas paredes.
# Depois: $G --headless --path . --import e tools/mapa/mede_ruinas.gd (tamanhos para a planta, tools/mapa/cidade_v2.py).
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ruinas  # noqa: E402
from ruinas import (bpy, math, Vector, rnd, mat, caixa, junta, morde, parede, piso, escada, limpa, exporta, entulho, revestimento,  # noqa: E402
                    estante, balcao, mesa, cama, criado, bagunca, marca, marca_porta, tabuas, PE, ESP, PORTA_L, PORTA_A,
                    JAN_BASE, JAN_TOPO, JAN_L, CORES)

SAIDA = ruinas.SAIDA
CORES.update({
    "reboco_rosa": (0.8, 0.55, 0.55), "reboco_verde": (0.55, 0.7, 0.55), "reboco_laranja": (0.85, 0.6, 0.35),
    "reboco_azul": (0.5, 0.62, 0.78), "reboco_amarelo": (0.88, 0.78, 0.45), "reboco_creme": (0.85, 0.8, 0.68),
    "reboco_lilas": (0.65, 0.58, 0.75), "tijolo_cru": (0.7, 0.42, 0.28), "fibra_azul": (0.12, 0.3, 0.6),
    "aco": (0.55, 0.56, 0.56), "placa_vermelha": (0.7, 0.1, 0.08), "placa_azul": (0.1, 0.25, 0.6),
    "placa_amarela": (0.9, 0.75, 0.1), "placa_verde": (0.1, 0.5, 0.25), "placa_branca": (0.85, 0.85, 0.82),
    "placa_laranja": (0.9, 0.45, 0.1), "placa_preta": (0.08, 0.08, 0.08), "placa_rosa": (0.85, 0.4, 0.6),
    "letra_branca": (0.95, 0.95, 0.92), "letra_preta": (0.05, 0.05, 0.05), "letra_vermelha": (0.75, 0.05, 0.05),
    "letra_amarela": (0.95, 0.8, 0.1), "tinta_preta": (0.04, 0.04, 0.04), "tinta_vermelha": (0.5, 0.03, 0.03),
    "pintura_creme": (0.93, 0.88, 0.75), "pintura_verde": (0.72, 0.85, 0.75), "pintura_azul": (0.7, 0.8, 0.9),
    "pintura_rosa": (0.92, 0.78, 0.78), "pintura_amarela": (0.95, 0.88, 0.6), "pintura_branca": (0.92, 0.92, 0.9),
    "barra_verde": (0.45, 0.6, 0.5), "barra_azul": (0.4, 0.5, 0.65), "barra_vinho": (0.55, 0.3, 0.3),
    "ceramica_bege": (0.85, 0.78, 0.65), "ceramica_cinza": (0.7, 0.7, 0.7), "ceramica_vermelha": (0.65, 0.3, 0.25),
    "grade": (0.12, 0.12, 0.12), "casca": (0.25, 0.2, 0.15), "folha": (0.2, 0.32, 0.15), "folha_palmeira": (0.3, 0.42, 0.2), "piso_igreja": (0.6, 0.55, 0.5), "terra": (0.4, 0.3, 0.2), "faixa": (0.9, 0.9, 0.88),
})
REBOCOS = ["reboco_rosa", "reboco_verde", "reboco_laranja", "reboco_azul", "reboco_amarelo", "reboco_creme", "reboco_lilas",
           "parede"]
PINTURAS = ["pintura_creme", "pintura_verde", "pintura_azul", "pintura_rosa", "pintura_amarela", "pintura_branca"]
BARRAS = ["azulejo", "barra_verde", "barra_azul", "barra_vinho"]
CERAMICAS = ["ceramica_bege", "ceramica_cinza", "ceramica_vermelha"]
PICHO = ["SOCORRO", "NÃO ENTRE", "ELES OUVEM", "DEUS NOS AJUDE", "FUJAM", "INFECTADOS", "SEM COMIDA", "MORTOS AQUI",
         "ABRIGO NA ESCOLA", "NÃO ABRA", "FIM", "SÓ À NOITE"]


# ----- peças -----

def letreiro(nome, texto, c, larg, alt, m, ang=0.0, prof=0.05):
    """Texto em 3D de pé, virado para -Y girado por `ang` (cabe em larg x alt, centro em c)."""
    cu = bpy.data.curves.new(nome, "FONT")
    cu.body = texto
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.resolution_u = 2
    o = bpy.data.objects.new(nome, cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.update()
    s = min(larg / max(o.dimensions.x, 0.01), alt / max(o.dimensions.y, 0.01))
    cu.extrude = prof / (2 * s)
    o.data.materials.append(mat(m))
    o.scale = (s, s, s)
    o.rotation_euler = (math.pi / 2, 0, ang)
    o.location = c
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return bpy.context.object


def picha(nome, texto, a, b, t, z, fora, larg=2.2, afasta=ESP / 2 + 0.012):
    """Pichação na face de fora da parede a->b (fora: +1/-1 = lado direito/esquerdo de quem anda de a para b)."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    n = Vector((u.y, -u.x, 0)) * fora
    c = a + u * t + n * afasta
    ang = math.atan2(n.y, n.x) + math.pi / 2  # o texto olha para -Y; girar até olhar para n
    letreiro(nome, texto, (c.x, c.y, z), larg, 0.5, rnd.choice(["tinta_preta", "tinta_preta", "tinta_vermelha"]),
             ang, 0.004)


def cilindro(nome, c, raio, alt, m, lados=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=lados, radius=raio, depth=alt, location=(c[0], c[1], c[2] + alt / 2))
    o = bpy.context.object
    o.name = nome
    o.data.materials.append(mat(m))
    return o


def caixa_agua(nome, x, y, z):
    """Caixa d'água azul de fibra em cima da laje (com tampa)."""
    p = [cilindro("cx", (x, y, z), 0.6, 0.85, "fibra_azul"), cilindro("cx", (x, y, z + 0.85), 0.66, 0.08, "fibra_azul"),
         caixa("cx", (x, y, z - 0.08), (1.4, 1.4, 0.16), "concreto")]
    return junta(p, nome)


def ferros(nome, x, y, z, n=4):
    """Vergalhão pra cima no pilar (laje que nunca acabou)."""
    p = []
    for k in range(n):
        p.append(caixa("f", (x + (k % 2) * 0.12 - 0.06, y + (k // 2) * 0.12 - 0.06, z + 0.45), (0.02, 0.02, 0.9), "ferrugem",
                       (rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), 0)))
    return junta(p, nome)


def gradil(nome, a, b, z, alt=1.0, col=False):
    """Grade de sacada/muro: barras de 12 cm e corrimão."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    comp = (b - a).length
    ang = math.atan2(u.y, u.x)
    p = []
    t = 0.06
    while t < comp:
        c = a + u * t
        p.append(caixa("g", (c.x, c.y, z + alt / 2), (0.025, 0.025, alt), "grade"))
        t += 0.2
    c = a + u * (comp / 2)
    p.append(caixa("g", (c.x, c.y, z + alt), (comp, 0.05, 0.05), "grade", (0, 0, ang)))
    o = junta(p, nome)
    if col:
        caixa(nome + "-colonly", (c.x, c.y, z + alt / 2), (comp, 0.08, alt), "grade", (0, 0, ang))
    return o


def janela_fachada(nome, x, y, z, larg=1.2, alt=1.2, ang=0.0, tipo=None):
    """Janela só de enfeite numa parede cheia (moldura, vidro escuro/quebrado/tábuas ou veneziana)."""
    tipo = tipo or rnd.choice(["vidro", "vidro", "veneziana", "tabua", "quebrada"])
    c, s = math.cos(ang), math.sin(ang)
    def em(dx, dy):  # local (dx ao longo da parede, dy para fora) -> mundo
        return (x + c * dx - s * dy, y + s * dx + c * dy)
    p = []
    for dz, h in ((-alt / 2 - 0.05, 0.1), (alt / 2 + 0.04, 0.08)):
        q = em(0, -0.04)
        p.append(caixa("m", (q[0], q[1], z + dz), (larg + 0.2, 0.1, h), "batente", (0, 0, ang)))
    for sx in (-1, 1):
        q = em(sx * (larg / 2 + 0.04), -0.04)
        p.append(caixa("m", (q[0], q[1], z), (0.08, 0.1, alt), "batente", (0, 0, ang)))
    q = em(0, -0.01)
    if tipo == "vidro":
        p.append(caixa("v", (q[0], q[1], z), (larg, 0.02, alt), "vidro_janela", (0, 0, ang)))
    elif tipo == "quebrada":
        p.append(caixa("v", (q[0], q[1], z), (larg, 0.02, alt), "vidro", (0, 0, ang)))
        p.append(caixa("v", (q[0], q[1] , z + alt * 0.3), (larg * 0.6, 0.03, alt * 0.35), "vidro_janela", (0, 0.3, ang)))
    elif tipo == "veneziana":
        for k in range(int(alt / 0.2)):
            p.append(caixa("v", (q[0], q[1], z - alt / 2 + 0.1 + k * 0.2), (larg, 0.03, 0.16), "batente", (0.4, 0, ang)))
    else:
        p.append(caixa("v", (q[0], q[1], z), (larg, 0.02, alt), "vidro", (0, 0, ang)))
        for k in range(3):
            p.append(caixa("t", (q[0], q[1], z - alt / 3 + k * alt / 3), (larg + 0.3, 0.04, 0.16), "tabua", (0, rnd.uniform(-0.2, 0.2), ang)))
    return junta(p, nome)


def ar_cond(nome, x, y, z, ang=0.0):
    return caixa(nome, (x, y, z), (0.75, 0.32, 0.5), "branco", (0, 0, ang))


def porta_aco(nome, x, y, larg, estado):
    """Porta de aço de loja: 'aberta' (enrolada lá em cima), 'fechada' (desce até o chão, bloqueia), 'arrombada' (torta)."""
    p = [caixa("pa", (x, y + 0.2, 2.95), (larg, 0.35, 0.35), "aco")]  # rolo
    if estado == "fechada":  # desce até o chão, com a portinhola arrombada (dá para entrar abaixado... e em pé)
        pl = 1.0
        x0 = x + larg / 2 - 1.6
        for (t0, t1) in ((x - larg / 2, x0 - pl / 2), (x0 + pl / 2, x + larg / 2)):
            p.append(caixa("pa", ((t0 + t1) / 2, y + 0.05, 1.4), (t1 - t0, 0.05, 2.8), "aco"))
            for k in range(14):
                p.append(caixa("pa", ((t0 + t1) / 2, y + 0.02, 0.1 + k * 0.2), (t1 - t0, 0.03, 0.03), "metal"))
            caixa(nome + "_bloqueio%d-colonly" % int(t0 * 10), ((t0 + t1) / 2, y + 0.05, 1.4), (t1 - t0, 0.1, 2.8), "aco")
        p.append(caixa("pa", (x0, y + 0.05, 2.5), (pl, 0.05, 0.6), "aco"))
        p.append(caixa("pa", (x0 + 0.3, y - 0.35, 1.0), (pl, 0.04, 1.9), "aco", (0, 0, 0.9)))  # portinhola aberta
    elif estado == "arrombada":
        p.append(caixa("pa", (x + larg * 0.25, y - 0.6, 0.3), (larg * 0.5, 0.05, 1.6), "aco", (1.3, 0.15, 0.3)))
        p.append(caixa("pa", (x, y + 0.05, 2.45), (larg, 0.05, 0.7), "aco", (0.25, 0, 0)))
    else:
        p.append(caixa("pa", (x, y + 0.05, 2.6), (larg, 0.05, 0.4), "aco"))
    return junta(p, nome)


def laje_topo(nome, w, d, z, m, mureta=0.6, caixas=1):
    """Teto plano com mureta, caixa d'água, ferro pra cima e antena de TV."""
    hw, hd = w / 2, d / 2
    piso(nome, -hw, -hd, hw, hd, z, "concreto")
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("%s_mureta%d" % (nome, i), a, b, z, mureta, [], m, rnd.randint(0, 1), esp=0.15)
    for k in range(caixas):
        caixa_agua("%s_caixa%d" % (nome, k), rnd.uniform(-hw + 1, hw - 1), rnd.uniform(0, hd - 1), z)
    if rnd.random() < 0.6:
        ferros(nome + "_ferro", hw - 0.2, -hd + 0.2, z + mureta)
    if rnd.random() < 0.5:
        ax, ay = rnd.uniform(-hw + 0.5, hw - 0.5), rnd.uniform(-hd + 0.5, hd - 0.5)
        junta([caixa("an", (ax, ay, z + 1.2), (0.04, 0.04, 2.4), "metal"),
               caixa("an", (ax, ay, z + 2.2), (1.2, 0.03, 0.03), "metal", (0, 0, 0.5)),
               caixa("an", (ax, ay, z + 1.9), (0.9, 0.03, 0.03), "metal", (0, 0, 0.5))], nome + "_antena")


def por_dentro(nome, w, d, aberturas, cor=None, barra=None, chao=None, forro=True, alt_barra=1.2, z_forro=PE):
    """Acabamento de dentro de uma caixa w x d (paredes no contorno): reboco pintado em cima, barra de azulejo ou tinta
    embaixo, piso de cerâmica e forro. aberturas: [frente, direita, fundo, esquerda] (mesmo t das paredes)."""
    hw, hd = w / 2, d / 2
    cor = cor or rnd.choice(PINTURAS)
    barra = barra or rnd.choice(BARRAS)
    chao = chao or rnd.choice(CERAMICAS)
    lados = [((-hw, -hd), (hw, -hd), Vector((0, 1, 0))), ((hw, -hd), (hw, hd), Vector((-1, 0, 0))),
             ((hw, hd), (-hw, hd), Vector((0, -1, 0))), ((-hw, hd), (-hw, -hd), Vector((1, 0, 0)))]
    for i, (a, b, n) in enumerate(lados):
        revestimento("rev_%s_%d" % (nome, i), a, b, aberturas[i], n * (ESP / 2 + 0.011), barra, cor, alt_barra)
    caixa("piso_%s" % nome, (0, 0, 0.075), (w - ESP, d - ESP, 0.03), chao)
    if forro:
        caixa("forro_%s" % nome, (0, 0, z_forro - 0.03), (w - ESP, d - ESP, 0.03), "forro")


def sai(nome):
    exporta(nome)  # ruinas.exporta junta as peças em ext / longe / detalhe / dentro


# ----- sobrado de comércio -----
LOJAS = [  # nome, placa, letra
    ("FARMÁCIA", "placa_verde", "letra_branca"), ("PADARIA", "placa_amarela", "letra_vermelha"),
    ("AÇOUGUE", "placa_vermelha", "letra_branca"), ("BAR DO ZÉ", "placa_azul", "letra_amarela"),
    ("LOTÉRICA", "placa_azul", "letra_branca"), ("MERCADINHO", "placa_vermelha", "letra_amarela"),
    ("ÓTICA", "placa_branca", "letra_preta"), ("LANCHONETE", "placa_laranja", "letra_branca"),
    ("AUTO PEÇAS", "placa_amarela", "letra_preta"), ("CAÇA E PESCA", "placa_verde", "letra_amarela"),
    ("SALÃO", "placa_rosa", "letra_branca"), ("CELULARES", "placa_preta", "letra_amarela"),
    ("MAT. CONSTRUÇÃO", "placa_laranja", "letra_preta"), ("PAPELARIA", "placa_branca", "letra_vermelha"),
    ("PET SHOP", "placa_azul", "letra_branca"), ("BORRACHARIA", "placa_amarela", "letra_preta"),
]


def sobrado(nome, w, d, semente, loja, andares=2, porta="aberta", varanda=True):
    """Loja no térreo (porta de aço, marquise e letreiro), casa em cima (só fachada), empena de tijolo cru nos lados,
    laje com caixa d'água. Entra pela frente (ou pelos fundos se a porta de aço estiver fechada)."""
    limpa()
    rnd.seed(semente)
    texto, placa, letra = loja
    cor = rnd.choice(REBOCOS)
    hw, hd = w / 2, d / 2
    alt = PE * andares
    vao = w - 1.0
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, PE, [(hw, vao, 0, 2.8)], cor)
    parede("ext_dir", (hw, -hd), (hw, hd), 0, alt, [], "tijolo_cru")
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, PE, [(w * 0.7, PORTA_L, 0, PORTA_A), (w * 0.3, JAN_L, JAN_BASE + 0.3, JAN_TOPO)], cor)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, alt, [], "tijolo_cru")
    porta_aco("porta_aco", 0, -hd, vao, porta)
    if andares > 1:
        parede("ext_frente_cima", (-hw, -hd), (hw, -hd), PE, alt - PE, [], cor)
        parede("ext_fundo_cima", (hw, hd), (-hw, hd), PE, alt - PE, [], cor)
        piso("laje1", -hw, -hd, hw, hd, PE, "concreto")
        for k in range(1, andares):  # janelas do andar de cima (enfeite) e sacada
            z = k * PE + 1.5
            n = max(1, int(w / 3.2))
            for q in range(n):
                x = -hw + w * (q + 0.5) / n
                janela_fachada("jan_f%d_%d" % (k, q), x, -hd - ESP / 2, z, 1.3, 1.25)
                if rnd.random() < 0.3:
                    ar_cond("ar_%d_%d" % (k, q), x + 1.1, -hd - ESP / 2 - 0.17, z + 0.2)
            for q in range(2):
                janela_fachada("jan_t%d_%d" % (k, q), -hw + w * (q + 0.5) / 2, hd + ESP / 2, z, 1.0, 1.0, math.pi)
    # marquise e letreiro
    caixa("marquise", (0, -hd - 0.6, PE - 0.1), (w, 1.2, 0.14), "concreto")
    caixa("placa", (0, -hd - 0.16, PE + 0.45), (w - 0.4, 0.1, 0.8), placa)
    letreiro("letra", texto, (0, -hd - 0.22, PE + 0.45), w - 1.0, 0.55, letra)
    if texto == "FARMÁCIA":
        cruz = [caixa("cr", (hw - 0.6, -hd - 0.5, PE + 1.5), (0.7, 0.12, 0.22), "placa_verde"),
                caixa("cr", (hw - 0.6, -hd - 0.5, PE + 1.5), (0.22, 0.12, 0.7), "placa_verde")]
        junta(cruz, "cruz")
    # dentro: reboco pintado, barra (azulejo onde mexe com comida/remédio), cerâmica, forro; balcão, gôndolas, tralha
    limpo = texto in ("FARMÁCIA", "PADARIA", "AÇOUGUE", "LANCHONETE", "BAR DO ZÉ", "MERCADINHO")
    por_dentro("loja", w, d, [[(hw, vao, 0, 2.8)], [], [(w * 0.7, PORTA_L, 0, PORTA_A), (w * 0.3, JAN_L, JAN_BASE + 0.3, JAN_TOPO)], []],
               "pintura_branca" if limpo else None, "azulejo" if limpo else None, None, True, 1.6 if limpo else 1.1)
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    balcao("balcao_loja", -hw + 1.0, -hd + 2.4, 1.5708, 1.8)
    for k in range(max(1, int((d - 5) / 1.5))):
        estante("gondola_%d" % k, hw - 0.35, -hd + 2.0 + k * 1.4, -1.5708, rnd.random() < 0.2, 1.2, "metal")
    if w > 7.5:
        estante("gondola_meio", 0.3, hd - 2.6, 0, rnd.random() < 0.4, 1.4, "metal")
    bagunca("bag_loja", 0, 0, 6)
    entulho("entulho", (rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0.06), 3, 0.3, "metal")
    # teto: laje com mureta, ou telha de fibrocimento
    if rnd.random() < 0.75:
        laje_topo("teto", w, d, alt, cor)
    else:
        piso("teto", -hw, -hd, hw, hd, alt, "concreto")
        caixa("telha_fibro", (0, 0.3, alt + 0.6), (w + 0.3, d + 0.2, 0.06), "telhado", (math.atan2(1.2, d), 0, 0))
        caixa_agua("caixa_dagua", hw - 1.0, hd - 1.0, alt + 0.1)
    if rnd.random() < 0.6:
        picha("picho_fundo", rnd.choice(PICHO), (hw, hd), (-hw, hd), w / 2, 1.6, 1, min(w - 1, 3.0))
    if rnd.random() < 0.7:  # pichação na empena (de lado)
        lado = rnd.choice((-1, 1))
        a, b = ((hw, -hd), (hw, hd)) if lado > 0 else ((-hw, hd), (-hw, -hd))
        picha("picho_lado", rnd.choice(PICHO), a, b, d / 2, rnd.uniform(1.5, 4.5), 1, min(d - 2, 4.0))
    sai(nome)


# ----- prédio de apartamentos (só de fora: térreo com portaria, varandas, caixa d'água no topo) -----

def predio_apto(nome, w, d, andares, semente, placa):
    limpa()
    rnd.seed(semente)
    cor = rnd.choice(["reboco_creme", "reboco_azul", "parede", "reboco_rosa", "reboco_amarelo"])
    hw, hd = w / 2, d / 2
    alt = andares * PE
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("ext_%d" % i, a, b, 0, alt, [], cor, 0, esp=0.3)
    marca("fechado", 0, 0)  # só de fora: o jogo não põe baú, item nem nascer dentro
    # térreo: faixa de pastilha, portaria com grade, letreiro do edifício
    caixa("base", (0, -hd - 0.02, 1.4), (w + 0.05, ESP, 2.8), "fachada_tijolo")
    gradil("portaria", (-w * 0.35, -hd - 1.6), (w * 0.35, -hd - 1.6), 0, 2.0, True)
    for s in (-1, 1):
        gradil("portaria_lado%d" % s, (s * w * 0.35, -hd - 1.6), (s * w * 0.35, -hd - 0.2), 0, 2.0, True)
    caixa("porta_predio", (0, -hd - 0.18, 1.2), (1.8, 0.06, 2.4), "vidro")
    letreiro("nome_predio", "EDIFÍCIO " + placa, (0, -hd - 0.17, 3.2), w * 0.5, 0.4, "letra_branca")
    for k in range(1, andares):
        z = k * PE + 1.4
        caixa("friso_%d" % k, (0, -hd - 0.08, k * PE), (w + 0.1, 0.25, 0.12), "concreto")
        n = max(2, int(w / 3.5))
        for q in range(n):
            x = -hw + w * (q + 0.5) / n
            if q % 2 == 0:  # varanda
                caixa("varanda_%d_%d" % (k, q), (x, -hd - 0.7, k * PE + 0.05), (2.6, 1.4, 0.15), "concreto")
                gradil("varanda_g_%d_%d" % (k, q), (x - 1.3, -hd - 1.38), (x + 1.3, -hd - 1.38), k * PE + 0.12, 1.0)
                caixa("porta_varanda_%d_%d" % (k, q), (x, -hd - 0.17, k * PE + 1.15), (1.6, 0.04, 2.1), rnd.choice(["vidro", "vidro_janela"]))
            else:
                janela_fachada("jan_%d_%d" % (k, q), x, -hd - 0.15, z, 1.4, 1.2)
                if rnd.random() < 0.5:
                    ar_cond("ar_%d_%d" % (k, q), x + 1.0, -hd - 0.35, z - 0.2)
        for s, ang in ((1, math.pi / 2), (-1, -math.pi / 2)):  # janelas dos lados e do fundo
            for q in range(max(1, int(d / 5))):
                janela_fachada("jl_%d_%d_%d" % (k, s, q), s * (hw + 0.15), -hd + d * (q + 0.5) / max(1, int(d / 5)), z, 1.0, 1.1, ang)
        for q in range(max(1, int(w / 4))):
            janela_fachada("jf_%d_%d" % (k, q), -hw + w * (q + 0.5) / max(1, int(w / 4)), hd + 0.15, z, 1.0, 1.0, math.pi)
    piso("teto", -hw, -hd, hw, hd, alt, "concreto")
    caixa("casa_maquinas", (hw * 0.4, hd * 0.3, alt + 1.4), (3.5, 3.0, 2.8), cor)
    caixa("reservatorio", (-hw * 0.4, hd * 0.3, alt + 1.8), (4.0, 3.0, 3.6), "concreto")
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("platibanda_%d" % i, a, b, alt, 1.0, [], cor, rnd.randint(0, 1), esp=0.2)
    if rnd.random() < 0.6:  # incêndio num andar: parede preta e janela estourada
        k = rnd.randint(2, andares - 1)
        caixa("queimado_%d" % k, (rnd.uniform(-hw / 2, hw / 2), -hd - 0.2, k * PE + 1.6), (3.0, 0.03, 2.4), "queimado")
    picha("picho", rnd.choice(PICHO), (-hw, -hd), (hw, -hd), w * 0.18, 1.2, 1, 2.0)
    sai(nome)


# ----- igreja matriz (marco: torre de 26 m) -----

def igreja(nome):
    limpa()
    rnd.seed(81)
    w, d = 14.0, 28.0
    hw, hd = w / 2, d / 2
    alt = 9.0
    m = "reboco_creme"
    # fachada com porta grande e janelas altas dos lados
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, alt, [(hw, 2.6, 0, 4.2), (2.6, 1.2, 3.0, 7.0), (w - 2.6, 1.2, 3.0, 7.0)], m)
    jl = [(t, 1.2, 3.0, 7.0) for t in (5, 10, 15, 20)]
    parede("ext_dir", (hw, -hd), (hw, hd), 0, alt, jl, m)
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, alt, [(4.0, PORTA_L, 0, PORTA_A)], m)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, alt, jl, m, 1)
    for s, (a, b) in ((1, ((hw, -hd), (hw, hd))), (-1, ((-hw, hd), (-hw, -hd)))):
        for t in (5, 10, 15, 20):  # vitral (cacos coloridos) e moldura
            pa = Vector(a) + (Vector(b) - Vector(a)).normalized() * t
            caixa("vitral_%d_%d" % (s, t), (pa.x, pa.y, 5.0), (0.03, 1.2, 4.0), rnd.choice(["placa_azul", "placa_vermelha", "placa_amarela"]))
    # frontão (triângulo) e cruz
    me = bpy.data.meshes.new("frontao")
    me.from_pydata([(-hw - 0.3, -hd - 0.15, alt), (hw + 0.3, -hd - 0.15, alt), (0, -hd - 0.15, alt + 3.2)], [], [(0, 1, 2)])
    o = bpy.data.objects.new("frontao", me)
    bpy.context.collection.objects.link(o)
    me.materials.append(mat(m))
    sol = o.modifiers.new("e", "SOLIDIFY")
    sol.thickness = 0.4
    # telhado de duas águas ao longo do comprimento (cumeeira em x = 0)
    ang = math.atan2(3.0, hw + 0.5)
    ag = math.hypot(hw + 0.5, 3.0)
    for s in (-1, 1):
        caixa("telhado_%d-col" % (s + 1), (s * (hw + 0.5) / 2, 0, alt + 1.5), (ag, d + 0.8, 0.2), "telha", (0, s * ang, 0))
    caixa("forro_igreja", (0, 0, alt - 0.05), (w - 0.4, d - 0.4, 0.1), "forro")
    caixa("piso_nave", (0, 0, 0.075), (w - 0.4, d - 0.4, 0.03), "piso_igreja")
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    # torre do sino na frente (centro), entra-se por baixo dela
    tw = 4.4
    ty = -hd - tw / 2 + 0.2
    th = 22.0
    for i, (a, b, ab) in enumerate([((-tw / 2, ty - tw / 2), (tw / 2, ty - tw / 2), [(tw / 2, 2.4, 0, 4.0)]),
                                    ((tw / 2, ty - tw / 2), (tw / 2, ty + tw / 2), []),
                                    ((-tw / 2, ty + tw / 2), (-tw / 2, ty - tw / 2), [])]):
        for j, (z0, z1, abj) in enumerate([(0, 9.0, ab), (9.0, 14.0, [(tw / 2, 0.8, 1.0, 3.0)]), (14.0, th, [(tw / 2, 1.6, th - 19.5, th - 16.0)])]):
            parede("ext_torre%d_%d" % (i, j), a, b, z0, z1 - z0, abj, m)
    sino = cilindro("sino", (0, ty, th - 4.8), 0.55, 1.0, "ferrugem", 10)
    sino.name = "sino"
    piso("torre_laje", -tw / 2, ty - tw / 2, tw / 2, ty + tw / 2, th, "concreto")
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=tw * 0.72, depth=5.0, location=(0, ty, th + 2.5), rotation=(0, 0, math.pi / 4))
    c = bpy.context.object
    c.name = "torre_ponta"
    c.data.materials.append(mat("telha"))
    junta([caixa("cz", (0, ty, th + 6.0), (0.18, 0.18, 2.2), "metal"), caixa("cz", (0, ty, th + 6.4), (1.1, 0.18, 0.18), "metal")], "cruz")
    letreiro("relogio", "XII", (0, ty - tw / 2 - 0.15, th - 8.0), 1.0, 0.4, "letra_preta")
    caixa("relogio_fundo", (0, ty - tw / 2 - 0.12, th - 8.0), (1.6, 0.06, 1.6), "placa_branca")
    # bancos (2 fileiras), altar, cruz no fundo, velas e entulho
    for k in range(8):
        for s in (-1, 1):
            y = -hd + 5.0 + k * 2.1
            caida = rnd.random() < 0.18
            p = [caixa("b", (0, 0, 0.45), (4.2, 0.45, 0.06), "madeira"), caixa("b", (0, 0.22, 0.75), (4.2, 0.05, 0.6), "madeira"),
                 caixa("b", (-2.0, 0, 0.23), (0.06, 0.45, 0.45), "madeira"), caixa("b", (2.0, 0, 0.23), (0.06, 0.45, 0.45), "madeira")]
            o = junta(p, "banco_%d_%d-col" % (k, s + 1))
            o.location = (s * 3.4, y, 0.06)
            o.rotation_euler = (1.4 if caida else 0, 0, rnd.uniform(-0.08, 0.08) + (0.4 if caida else 0))
            if caida:
                o.location.z = 0.3
    caixa("altar_base-col", (0, hd - 3.5, 0.3), (6.0, 3.0, 0.5), "concreto")
    caixa("altar-col", (0, hd - 3.2, 1.0), (2.6, 1.0, 1.0), "placa_branca")
    junta([caixa("cf", (0, hd - 0.4, 5.0), (0.3, 0.2, 4.0), "madeira"), caixa("cf", (0, hd - 0.4, 6.0), (2.0, 0.2, 0.3), "madeira")], "cruz_fundo")
    entulho("entulho", (2.0, 0.0, 0.06), 6, 0.45)
    morde(bpy.data.objects["ext_esq-col"], (-hw, 2.0, alt), 1.8)
    picha("picho_frente", "ARREPENDEI-VOS", (-hw, -hd), (hw, -hd), 3.0, 2.2, 1, 3.4)
    picha("picho_lado", rnd.choice(PICHO), (hw, -hd), (hw, hd), 12.0, 2.0, 1, 3.0)
    for k in range(6):
        marca("zumbi_%d" % k, rnd.uniform(-4, 4), rnd.uniform(-hd + 4, hd - 5))
    marca("bau_1", 0, hd - 2.0)
    marca("bau_2", -hw + 1.0, hd - 1.2)
    sai(nome)


# ----- hospital municipal (raid; heliponto no teto) -----

def hospital(nome):
    limpa()
    rnd.seed(82)
    w, d = 30.0, 16.0
    hw, hd = w / 2, d / 2
    andares = 3
    alt = andares * PE
    m = "parede"
    jan = lambda comp, n: [(comp * (k + 0.5) / n, 1.4, 0.9, 2.2) for k in range(n)]
    ab_f = [(t, a, b, c) for (t, a, b, c) in jan(w, 8) if abs(t - hw) > 2.5] + [(hw, 3.0, 0, 2.6)]
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, PE, ab_f, m)
    parede("ext_dir", (hw, -hd), (hw, hd), 0, PE, jan(d, 3), m)
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, PE, [(t, a, b, c) for (t, a, b, c) in jan(w, 8) if abs(t - 6) > 2] + [(6.0, 2.0, 0, 2.4)], m)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, PE, jan(d, 3), m)
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("ext_cima%d" % i, a, b, PE, alt - PE, [], m, 1 if i == 3 else 0)
    # andares de cima: janelas em faixa (enfeite)
    for k in range(1, andares):
        for q in range(8):
            janela_fachada("jc_%d_%d" % (k, q), -hw + w * (q + 0.5) / 8, -hd - ESP / 2, k * PE + 1.5, 1.6, 1.2, 0, rnd.choice(["vidro", "quebrada", "vidro"]))
            janela_fachada("jt_%d_%d" % (k, q), -hw + w * (q + 0.5) / 8, hd + ESP / 2, k * PE + 1.5, 1.6, 1.2, math.pi)
    caixa("faixa_azul", (0, -hd - 0.13, PE + 0.1), (w + 0.1, 0.05, 0.35), "placa_azul")
    # dentro: corredor no meio (ao longo de x), quartos na frente e no fundo
    yc0, yc1 = -1.4, 1.4
    for s, y in ((-1, yc0), (1, yc1)):
        ab = [(t, 1.1, 0, 2.2) for t in (3.0, 9.0, 15.0, 21.0, 27.0)]
        if s < 0:
            ab = [(t, lg, b0, b1) for (t, lg, b0, b1) in ab if abs(t - 15) > 1] + [(15.0, 4.0, 0, 2.6)]
        parede("int_corr%d" % (s + 1), (-hw, y), (hw, y), 0, PE, ab, m, esp=0.15)
    for x in (-9.0, -3.0, 3.0, 9.0):
        for (y0, y1) in ((-hd, yc0), (yc1, hd)):
            if abs(x) < 4 and y0 < 0:
                continue  # recepção sem divisória
            parede("int_q%d_%d" % (int(x), int(y0)), (x, y0), (x, y1), 0, PE, [], m, esp=0.15)
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    por_dentro("hosp", w, d, [ab_f, jan(d, 3), [(t, a, b, c) for (t, a, b, c) in jan(w, 8) if abs(t - 6) > 2] + [(6.0, 2.0, 0, 2.4)],
                              jan(d, 3)], "pintura_branca", "barra_verde", "ceramica_cinza", False, 1.5)
    piso("laje1", -hw, -hd, hw, hd, PE, "forro")
    for k in range(2, andares + 1):
        piso("laje%d" % k, -hw, -hd, hw, hd, k * PE, "concreto")
    balcao("balcao_recepcao", 0, -hd + 3.0, 0, 3.0)
    for (x0, x1) in ((-hw, -9.0), (-9.0, -3.0), (3.0, 9.0), (9.0, hw)):
        for (y0, y1) in ((-hd, yc0), (yc1, hd)):
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            for q in range(2):  # leitos (o jogo troca pelo modelo de cama)
                cama("cama_h%d_%d_%d" % (int(cx), int(cy), q), cx - 1.3 + q * 2.6, cy + (1.5 if cy > 0 else -1.5) * 0.6, 0 if cy > 0 else math.pi)
            if rnd.random() < 0.5:
                estante("estante_h%d_%d" % (int(cx), int(cy)), x1 - 0.35, cy, -1.5708, rnd.random() < 0.3, 1.0, "metal")
    for k in range(4):  # macas largadas no corredor
        x = -12 + k * 7.5 + rnd.uniform(-1, 1)
        junta([caixa("mc", (0, 0, 0.75), (0.7, 1.9, 0.08), "branco"), caixa("mc", (0, 0, 0.4), (0.06, 1.6, 0.7), "metal")], "maca_%d-col" % k)
        o = bpy.data.objects["maca_%d-col" % k]
        o.location = (x, 0, 0.06)
        o.rotation_euler = (0, 0, 1.5708 + rnd.uniform(-0.5, 0.5))
    # topo: heliponto (círculo e H) e caixa d'água
    piso("teto", -hw, -hd, hw, hd, alt, "concreto")
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("mureta_%d" % i, a, b, alt, 0.8, [], m, rnd.randint(0, 1), esp=0.15)
    hx = 6.0
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=5.5, depth=0.04, location=(hx, 0, alt + 0.02))
    bpy.context.object.name = "heliponto"
    bpy.context.object.data.materials.append(mat("placa_amarela"))
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=4.9, depth=0.05, location=(hx, 0, alt + 0.03))
    bpy.context.object.name = "heliponto_dentro"
    bpy.context.object.data.materials.append(mat("concreto"))
    junta([caixa("h", (hx - 1.1, 0, alt + 0.06), (0.5, 4.0, 0.02), "faixa"), caixa("h", (hx + 1.1, 0, alt + 0.06), (0.5, 4.0, 0.02), "faixa"),
           caixa("h", (hx, 0, alt + 0.06), (2.0, 0.5, 0.02), "faixa")], "heliponto_h")
    caixa_agua("caixa_dagua", -hw + 3.0, 2.0, alt)
    caixa("casa_maquinas", (-hw + 6.5, -2.0, alt + 1.3), (3.0, 3.0, 2.6), m)
    # letreiro com cruz vermelha e marquise da entrada
    caixa("marquise", (0, -hd - 1.6, PE - 0.1), (8.0, 3.2, 0.18), "concreto")
    for s in (-1, 1):
        cilindro("pilar_%d-col" % (s + 1), (s * 3.6, -hd - 3.0, 0), 0.15, PE - 0.1, "branco", 8)
    letreiro("nome", "HOSPITAL MUNICIPAL", (0, -hd - 0.2, alt + 0.45), 14.0, 0.8, "letra_vermelha", 0, 0.1)
    caixa("cruz_a", (-9.8, -hd - 0.2, alt + 0.45), (1.2, 0.12, 0.35), "letra_vermelha")
    caixa("cruz_b", (-9.8, -hd - 0.2, alt + 0.45), (0.35, 0.12, 1.2), "letra_vermelha")
    picha("picho_1", "NÃO TEM CURA", (-hw, -hd), (hw, -hd), 6.0, 1.5, 1, 3.0)
    picha("picho_2", rnd.choice(PICHO), (hw, hd), (-hw, hd), 20.0, 1.6, 1, 3.0)
    entulho("entulho", (5.0, 0.0, 0.06), 6, 0.4)
    # raid: zumbis (alguns com arma: segurança e polícia) e baús de remédio
    k = 0
    for (x, y) in [(-12, -4), (-6, 4), (0, 0), (6, -4), (12, 4), (-12, 5), (8, 0), (-4, -5), (12, -5), (2, 5)]:
        marca("zumbi_%d" % k, x, y)
        k += 1
    marca("zumbi_arm_1", -2, -hd + 2.2)
    marca("zumbi_arm_2", 13, 0)
    for k, (x, y) in enumerate([(-13, 6.5), (13, -6.5), (-1.5, 6.5)]):
        marca("bau_%d" % (k + 1), x, y)
    sai(nome)


# ----- supermercado (raid) -----

def mercado(nome):
    limpa()
    rnd.seed(83)
    w, d = 30.0, 22.0
    hw, hd = w / 2, d / 2
    alt = 5.5
    m = "reboco_creme"
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, alt, [(hw, w - 4.0, 0.0, 3.4)], m)
    parede("ext_dir", (hw, -hd), (hw, hd), 0, alt, [], "tijolo_cru")
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, alt, [(6.0, 3.0, 0, 3.2), (w - 4.0, PORTA_L, 0, PORTA_A)], m)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, alt, [], "tijolo_cru", 1)
    # vitrine: caixilhos e vidro (portas de vidro estouradas no meio)
    pc = []
    for k in range(int((w - 4.0) / 2.6) + 1):
        x = -hw + 2.0 + k * 2.6
        pc.append(caixa("cx", (x, -hd, 1.7), (0.1, 0.15, 3.4), "metal"))
    junta(pc, "caixilhos")
    for k in range(10):
        x = -hw + 3.3 + k * 2.6
        if abs(x) < 3.0 or rnd.random() < 0.35:
            continue  # entrada e vidros quebrados
        caixa("vidro_%d-col" % k, (x, -hd, 1.7), (2.5, 0.03, 3.4), "vidro_janela")
    caixa("vidro_chao", (2.0, -hd - 1.0, 0.07), (3.0, 1.5, 0.01), "vidro_janela", (0, 0, 0.3))
    caixa("fachada_placa", (0, -hd - 0.2, alt + 0.6), (w + 0.2, 0.3, 2.4), "placa_vermelha")
    letreiro("nome", "SUPERMERCADO BOM PREÇO", (0, -hd - 0.38, alt + 0.6), w - 4.0, 1.4, "letra_amarela", 0, 0.12)
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    por_dentro("merc", w, d, [[(hw, w - 4.0, 0.0, 3.4)], [], [(6.0, 3.0, 0, 3.2), (w - 4.0, PORTA_L, 0, PORTA_A)], []],
               "pintura_branca", "barra_verde", "ceramica_bege", False, 1.4)
    piso("teto", -hw, -hd, hw, hd, alt, "concreto", buraco=(4.0, 1.0, 8.0, 5.0))
    for i, (a, b) in enumerate([((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("mureta_%d" % i, a, b, alt, 0.6, [], m, 0, esp=0.15)
    # caixas (checkout) perto da frente, gôndolas em fileiras, freezers no fundo
    for k in range(4):
        x = -hw + 4.0 + k * 3.2
        balcao("checkout_%d" % k, x, -hd + 4.0, 1.5708, 1.8)
    for fila in range(6):
        x = -hw + 5.0 + fila * 4.0
        for q in range(3):
            caida = rnd.random() < 0.15
            estante("gondola_%d_%d" % (fila, q), x, -2.0 + q * 2.6, 1.5708, caida, 2.4, "metal")
            estante("gondola_%d_%db" % (fila, q), x + 0.45, -2.0 + q * 2.6, -1.5708, False, 2.4, "metal")
    for k in range(7):
        caixa("freezer_%d-col" % k, (-hw + 3.0 + k * 3.5, hd - 0.7, 0.95), (3.0, 1.0, 1.8), "branco")
    for k in range(6):  # carrinhos
        x, y = rnd.uniform(-hw + 2, hw - 2), rnd.uniform(-hd - 6, -hd + 3)
        o = junta([caixa("c", (0, 0, 0.7), (0.55, 0.9, 0.5), "grade"), caixa("c", (0, 0, 0.25), (0.5, 0.8, 0.05), "metal")],
                  "carrinho_%d" % k)
        o.location = (x, y, 0.06)
        o.rotation_euler = (0, 0, rnd.uniform(0, 6.28))
    bagunca("bag_m1", -5, 0, 10)
    bagunca("bag_m2", 6, 3, 10)
    entulho("entulho", (-8.0, 4.0, 0.06), 6, 0.4, "papelao")
    picha("picho_1", "SAQUEADO", (hw, -hd), (hw, hd), 8.0, 2.5, 1, 4.0)
    picha("picho_2", rnd.choice(PICHO), (-hw, hd), (-hw, -hd), 10.0, 2.0, 1, 4.0)
    for k, (x, y) in enumerate([(-10, -3), (-2, 2), (6, -1), (10, 6), (-12, 7), (2, 7), (12, -6), (-6, -7)]):
        marca("zumbi_%d" % k, x, y)
    marca("zumbi_arm_1", 0, -hd + 6)
    for k, (x, y) in enumerate([(-13, 9.6), (13, 9.6), (0, 9.6)]):
        marca("bau_%d" % (k + 1), x, y)
    sai(nome)


# ----- barraco de morro (base desce 4 m para assentar no barranco) -----

def barraco(nome, w, d, semente, andares):
    limpa()
    rnd.seed(semente)
    hw, hd = w / 2, d / 2
    cor = rnd.choice(REBOCOS + ["tijolo_cru", "tijolo_cru", "tijolo_cru"])
    lado = "tijolo_cru"
    pt = w * rnd.uniform(0.3, 0.4)
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, PE, [(pt, 0.9, 0, 2.1), (w * 0.75, 0.9, 1.1, 2.0)], cor)
    parede("ext_dir", (hw, -hd), (hw, hd), 0, PE, [(d / 2, 0.8, 1.1, 1.9)], lado)
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, PE, [(w * 0.4, 0.8, 1.2, 1.9)], lado)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, PE, [], lado)
    gradil("grade_jan", (-hw + w * 0.75 - 0.5, -hd - 0.15), (-hw + w * 0.75 + 0.5, -hd - 0.15), 1.1, 0.9)
    caixa("base", (0, 0, -2.0), (w + 0.1, d + 0.1, 4.0), "tijolo_cru")  # alicerce no barranco
    for k in range(4):  # degraus da porta (descem até 1,2 m)
        caixa("degrau_%d" % k, (-hw + pt, -hd - 0.3 - k * 0.3, -0.15 - k * 0.3), (1.0, 0.3, 0.3), "concreto")
    caixa("degraus_rampa-colonly", (-hw + pt, -hd - 0.75, -0.6), (1.0, 1.9, 0.1), "concreto", (0.68, 0, 0))
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    por_dentro("barraco", w, d, [[(pt, 0.9, 0, 2.1), (w * 0.75, 0.9, 1.1, 2.0)], [(d / 2, 0.8, 1.1, 1.9)], [(w * 0.4, 0.8, 1.2, 1.9)], []],
               None, rnd.choice(BARRAS + [None]), rnd.choice(CERAMICAS + ["concreto"]), False, 1.0)
    alt = PE
    if andares > 1:
        piso("laje1", -hw, -hd, hw, hd, PE, "concreto")
        parede("ext_frente2", (-hw, -hd), (hw, -hd), PE, PE, [], cor)
        parede("ext_lados2", (hw, -hd), (hw, hd), PE, PE, [], lado)
        parede("ext_fundo2", (hw, hd), (-hw, hd), PE, PE, [], lado)
        parede("ext_esq2", (-hw, hd), (-hw, -hd), PE, PE, [], lado)
        janela_fachada("jan2", 0, -hd - ESP / 2, PE + 1.4, 1.0, 1.0, 0, rnd.choice(["vidro", "tabua", "veneziana"]))
        alt = 2 * PE
    piso("teto", -hw, -hd, hw, hd, alt, "concreto")
    caixa_agua("caixa_dagua", rnd.uniform(-hw + 0.8, hw - 0.8), rnd.uniform(-hd + 0.8, hd - 0.8), alt)
    for x, y in ((-hw + 0.15, -hd + 0.15), (hw - 0.15, -hd + 0.15), (hw - 0.15, hd - 0.15)):
        if rnd.random() < 0.6:
            ferros("ferro_%d_%d" % (int(x * 10), int(y * 10)), x, y, alt)
    if rnd.random() < 0.5:  # puxadinho de telha na frente
        caixa("toldo", (0, -hd - 0.6, 2.5), (w * 0.8, 1.3, 0.04), "telhado", (0.25, 0, 0))
    cama("cama_b", hw - 0.7, hd - 1.2, 0)
    mesa("mesa_b", -hw + 1.0, 0.0)
    criado("criado_b", hw - 0.4, -hd + 1.3, -1.5708)
    bagunca("bag_b", 0, 0, 3)
    if rnd.random() < 0.5:
        picha("picho", rnd.choice(PICHO), (-hw, hd), (-hw, -hd), d / 2, 1.6, 1, min(d - 1, 3.0))
    sai(nome)


# ----- peças de rua -----

def poste(nome, trafo):
    """Poste de concreto de 9 m com cruzeta, isoladores (e transformador). Os fios o jogo estica de poste a poste."""
    limpa()
    rnd.seed(len(nome))
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.16, radius2=0.09, depth=9.0, location=(0, 0, 4.5))
    o = bpy.context.object
    o.name = "poste-col"
    o.data.materials.append(mat("concreto"))
    p = [caixa("cz", (0, 0, 8.4), (2.2, 0.1, 0.1), "madeira")]
    for x in (-0.95, -0.35, 0.35, 0.95):
        p.append(caixa("is", (x, 0, 8.52), (0.06, 0.06, 0.16), "branco"))
    p.append(caixa("cz", (0, 0, 7.4), (1.4, 0.08, 0.08), "madeira"))
    junta(p, "cruzeta")
    if trafo:
        cilindro("trafo", (0.0, -0.45, 6.1), 0.35, 1.0, "metal", 10)
        caixa("trafo_suporte", (0, -0.25, 6.3), (0.5, 0.4, 0.08), "metal")
    else:  # luminária de rua
        junta([caixa("br", (0, -0.9, 7.8), (0.06, 1.8, 0.06), "metal", (0.2, 0, 0)),
               caixa("lu", (0, -1.75, 7.95), (0.25, 0.5, 0.12), "metal")], "luminaria")
    caixa("placa_rua", (0, 0.12, 2.6), (0.6, 0.02, 0.18), "placa_azul")
    sai(nome)


def ponto_onibus(nome):
    limpa()
    p = []
    for x in (-1.6, 1.6):
        p.append(caixa("pi", (x, 0.5, 1.2), (0.08, 0.08, 2.4), "metal"))
    junta(p, "pilares-col")
    caixa("teto-col", (0, 0.2, 2.45), (3.6, 1.6, 0.08), "aco", (0.08, 0, 0))
    caixa("fundo", (0, 0.55, 1.4), (3.4, 0.03, 1.4), "vidro_janela")
    caixa("banco-col", (0, 0.3, 0.45), (3.0, 0.4, 0.06), "madeira")
    caixa("placa", (1.9, -0.3, 2.4), (0.5, 0.03, 0.5), "placa_azul")
    letreiro("bus", "ÔNIBUS", (1.9, -0.32, 2.4), 0.45, 0.15, "letra_branca", 0, 0.01)
    sai(nome)


def orelhao(nome):
    limpa()
    caixa("poste-col", (0, 0, 1.0), (0.12, 0.12, 2.0), "metal")
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.6, location=(0, -0.2, 2.0))
    o = bpy.context.object
    o.name = "concha"
    o.scale = (1.0, 0.9, 1.15)
    o.data.materials.append(mat("letra_amarela" if rnd.random() < 0.5 else "placa_laranja"))
    for v in o.data.vertices:  # meia concha aberta para a frente
        if v.co.y < -0.15:
            v.co.y = -0.15
    caixa("fone", (0, -0.35, 1.5), (0.22, 0.12, 0.4), "metal")
    sai(nome)


def banca(nome):
    limpa()
    caixa("ext_banca-col", (0, 0, 1.25), (3.0, 2.0, 2.5), "placa_verde")
    caixa("toldo", (0, -1.4, 2.4), (3.2, 1.0, 0.05), "placa_vermelha", (0.3, 0, 0))
    caixa("porta_aco", (0, -1.02, 1.3), (2.6, 0.04, 2.0), "aco")
    letreiro("nome", "BANCA", (0, -1.04, 2.7), 2.0, 0.3, "letra_amarela", 0, 0.02)
    for k in range(5):
        caixa("revista_%d" % k, (rnd.uniform(-1.5, 1.5), rnd.uniform(-2.5, -1.2), 0.02), (0.22, 0.3, 0.01),
              rnd.choice(["placa_branca", "placa_vermelha", "placa_azul"]), (0, 0, rnd.uniform(0, 6.28)))
    sai(nome)


def coreto(nome):
    """Coreto octogonal da praça (marco do centro)."""
    limpa()
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=4.2, depth=1.0, location=(0, 0, 0.5))
    o = bpy.context.object
    o.name = "base-col"
    o.data.materials.append(mat("concreto"))
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        cilindro("col_%d-col" % k, (math.cos(a) * 3.8, math.sin(a) * 3.8, 1.0), 0.13, 3.0, "placa_branca", 8)
        if k != 6:
            gradil("guarda_%d" % k, (math.cos(a) * 3.8, math.sin(a) * 3.8), (math.cos(a + math.pi / 4) * 3.8, math.sin(a + math.pi / 4) * 3.8), 1.0, 0.9, True)
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=4.8, depth=2.2, location=(0, 0, 5.1), rotation=(0, 0, math.pi / 8))
    c = bpy.context.object
    c.name = "telhado"
    c.data.materials.append(mat("telha"))
    for k in range(4):  # degraus da entrada (lado k=6: -y)
        caixa("degrau_%d-col" % k, (0, -4.3 - k * 0.3, 0.85 - k * 0.25), (1.6, 0.35, 0.3), "concreto")
    caixa("rampa-colonly", (0, -4.6, 0.5), (1.6, 1.6, 0.1), "concreto", (-0.6, 0, 0))
    sai(nome)


def portico(nome):
    """Pórtico da entrada da cidade: BEM-VINDOS A SÃO JORGE."""
    limpa()
    for s in (-1, 1):
        caixa("pilar_%d-col" % (s + 1), (s * 8.5, 0, 3.5), (1.2, 1.2, 7.0), "reboco_creme")
    caixa("viga", (0, 0, 7.4), (18.2, 1.0, 1.6), "reboco_creme")
    letreiro("nome", "BEM-VINDOS A SÃO JORGE", (0, -0.52, 7.4), 15.0, 0.9, "placa_azul", 0, 0.08)
    picha("picho", "VOLTEM", (-9.1, 0.5), (9.1, 0.5), 9.1, 7.4, -1, 3.0, 0.012)
    sai(nome)


def cacamba(nome):
    """Caçamba de entulho (laranja, ferrugem)."""
    limpa()
    p = [caixa("c", (0, 0, 0.1), (1.8, 3.6, 0.12), "placa_laranja")]
    for s in (-1, 1):
        p.append(caixa("c", (s * 0.95, 0, 0.75), (0.08, 3.4, 1.3), "placa_laranja", (0, s * 0.18, 0)))
        p.append(caixa("c", (0, s * 1.85, 0.75), (1.9, 0.08, 1.3), "placa_laranja", (s * -0.35, 0, 0)))
    junta(p, "cacamba-col")
    entulho("entulho", (0, 0, 0.8), 6, 0.35, "concreto")
    sai(nome)


def traves(nome):
    """Campinho de terra: duas traves (a quadra o jogo pinta no chão)."""
    limpa()
    for s in (-1, 1):
        p = [caixa("t", (-2.5, s * 17, 1.1), (0.12, 0.12, 2.2), "placa_branca"), caixa("t", (2.5, s * 17, 1.1), (0.12, 0.12, 2.2), "placa_branca"),
             caixa("t", (0, s * 17, 2.2), (5.1, 0.12, 0.12), "placa_branca")]
        junta(p, "trave_%d-col" % (s + 1))
    caixa("terra", (0, 0, 0.02), (22.0, 36.0, 0.04), "terra")
    sai(nome)


def escola(nome):
    """Escola estadual (térreo comprido, salas com carteiras, quadra coberta ao lado): virou abrigo e caiu."""
    limpa()
    rnd.seed(84)
    w, d = 34.0, 10.0
    hw, hd = w / 2, d / 2
    m = "reboco_azul"
    jt = [2.0, 5.0, 8.5, 11.5, 22.5, 25.5, 29.0, 32.0]  # duas por sala (paredes de dentro em x = -10, -4, 4, 10)
    jf = [(t, 1.6, 1.0, 2.3) for t in jt] + [(17.0, 2.4, 0, 2.6)]
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, PE + 0.6, jf, m)
    parede("ext_dir", (hw, -hd), (hw, hd), 0, PE + 0.6, [], m)
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, PE + 0.6, [(t, 1.6, 1.0, 2.3) for t in jt], m)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, PE + 0.6, [(d / 2, PORTA_L, 0, PORTA_A)], m)
    for x in (-10.0, -4.0, 4.0, 10.0):
        parede("int_%d" % int(x), (x, -hd), (x, hd), 0, PE + 0.6, [(d - 1.5, 1.0, 0, 2.2)], "parede", esp=0.15)
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    por_dentro("escola", w, d, [jf, [], [(t, 1.6, 1.0, 2.3) for t in jt], [(d / 2, PORTA_L, 0, PORTA_A)]],
               "pintura_creme", "barra_verde", "ceramica_vermelha", True, 1.3, PE + 0.6)
    piso("teto", -hw, -hd, hw, hd, PE + 0.6, "concreto")
    caixa("telhado-col", (0, 0.4, PE + 1.3), (w + 1.0, d + 1.6, 0.08), "telha", (0.15, 0, 0))
    for (x0, x1) in ((-hw, -10), (-4, 4), (10, hw)):  # salas: carteiras e quadro
        caixa("quadro_negro_%d" % int(x0), ((x0 + x1) / 2, hd - 0.15, 1.6), (3.0, 0.05, 1.2), "tecido_verde")
        for i in range(3):
            for j in range(3):
                o = junta([caixa("c", (0, 0, 0.72), (0.6, 0.45, 0.04), "madeira"), caixa("c", (0, 0, 0.36), (0.05, 0.05, 0.72), "metal")],
                          "carteira_%d_%d_%d" % (int(x0), i, j))
                o.location = ((x0 + x1) / 2 - 1.6 + i * 1.6, -hd + 1.6 + j * 1.6, 0.06)
                o.rotation_euler = (1.4 if rnd.random() < 0.2 else 0, 0, rnd.uniform(-0.3, 0.3))
    for x in (-7.0, 7.0):  # salas do meio viraram dormitório do abrigo
        for k in range(3):
            caixa("colchao_%d_%d" % (int(x), k), (x - 1.5 + k * 1.5, rnd.uniform(-2, 2), 0.12), (0.8, 1.9, 0.12), rnd.choice(["pano", "tecido_azul"]), (0, 0, rnd.uniform(-0.3, 0.3)))
    letreiro("nome", "ESCOLA ESTADUAL", (0, -hd - 0.14, PE + 0.15), 10.0, 0.55, "letra_branca")
    picha("picho", "ABRIGO CAIU", (-hw, -hd), (hw, -hd), 8.0, 1.5, 1, 3.0)
    for k in range(6):  # sacos de areia na entrada
        caixa("saco_%d-col" % k, (-2.0 + k * 0.8, -hd - 1.6, 0.2 + (k % 2) * 0.3), (0.75, 0.4, 0.3), "areia", (0, 0, rnd.uniform(-0.2, 0.2)))
    marca_porta(1.2, -hd)
    sai(nome)


def favela_escadaria(nome):
    """Escadaria de concreto com corrimão (sobe o barranco: 10 m de comprimento, 3 m de altura)."""
    limpa()
    escada("degraus", 0, -5.0, 5.0, 0, 3.0, 1.6)
    gradil("corrimao", (-0.85, -5), (-0.85, 5), 0.0, 0.9)
    sai(nome)


def arvore(nome, semente, seca=False):
    """Árvore de rua/praça: tronco torto e copa de bolhas (ou só galhos, seca). Colisão só no tronco."""
    limpa()
    rnd.seed(semente)
    h = rnd.uniform(3.2, 4.5)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.24, radius2=0.14, depth=h, location=(0, 0, h / 2))
    t = bpy.context.object
    t.name = "tronco-col"
    t.data.materials.append(mat("casca"))
    galhos = []
    for k in range(5 if seca else 4):
        a = k * 2.4 + rnd.uniform(-0.4, 0.4)
        g = caixa("g", (math.cos(a) * 0.6, math.sin(a) * 0.6, h - 0.3 + rnd.uniform(0, 0.8)), (0.1, 0.1, 1.9), "casca",
                  (math.sin(a) * 0.7, -math.cos(a) * 0.7, 0))
        galhos.append(g)
    junta(galhos, "galhos")
    if not seca:
        copa = []
        for k in range(6):
            a = k * 1.1
            r = rnd.uniform(1.0, 1.6)
            c = (math.cos(a) * rnd.uniform(0.6, 1.4), math.sin(a) * rnd.uniform(0.6, 1.4), h + rnd.uniform(0.3, 1.6))
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=c)
            o = bpy.context.object
            for v in o.data.vertices:
                v.co *= rnd.uniform(0.75, 1.2)
            o.data.materials.append(mat("folha"))
            copa.append(o)
        junta(copa, "copa")
    sai(nome)


def palmeira(nome, semente):
    limpa()
    rnd.seed(semente)
    h = rnd.uniform(6.5, 8.0)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.25, radius2=0.17, depth=h, location=(0, 0, h / 2))
    t = bpy.context.object
    t.name = "tronco-col"
    t.data.materials.append(mat("casca"))
    folhas = []
    for k in range(12):
        a = k * math.tau / 12 + rnd.uniform(-0.15, 0.15)
        for j, (r0, cai) in enumerate(((0.9, 0.25), (2.3, 0.75))):  # cada folha em dois pedaços: sai reta e cai na ponta
            f = caixa("f", (math.cos(a) * r0, math.sin(a) * r0, h - 0.1 - j * 0.65), (1.6, 0.7 - j * 0.25, 0.03), "folha_palmeira",
                      (0, cai, a))
            folhas.append(f)
    for k in range(4):  # cocos
        folhas.append(caixa("c", (math.cos(k * 1.6) * 0.25, math.sin(k * 1.6) * 0.25, h - 0.45), (0.22, 0.22, 0.22), "casca"))
    junta(folhas, "folhas")
    sai(nome)


def tumulo(nome, semente):
    """Túmulo de cemitério brasileiro: caixa de concreto caiado com cruz, alguns quebrados."""
    limpa()
    rnd.seed(semente)
    caixa("tumulo-col", (0, 0, 0.4), (1.0, 2.2, 0.8), rnd.choice(["placa_branca", "concreto"]))
    caixa("tampa", (0, 0, 0.84), (1.1, 2.3, 0.08), "concreto", (0, rnd.uniform(-0.05, 0.05), 0))
    junta([caixa("c", (0, 1.0, 1.4), (0.1, 0.1, 1.2), "concreto"), caixa("c", (0, 1.0, 1.65), (0.6, 0.1, 0.1), "concreto")], "cruz")
    if rnd.random() < 0.5:
        caixa("vaso", (0.3, -0.9, 0.95), (0.18, 0.18, 0.25), "ferrugem")
    sai(nome)


def capela(nome):
    """Capela do cemitério (velório): pequena, porta aberta, cruz no topo."""
    limpa()
    rnd.seed(85)
    w, d = 6.0, 8.0
    hw, hd = w / 2, d / 2
    m = "placa_branca"
    parede("ext_frente", (-hw, -hd), (hw, -hd), 0, 4.0, [(hw, 1.6, 0, 2.6)], m)
    parede("ext_dir", (hw, -hd), (hw, hd), 0, 4.0, [(d / 2, 0.8, 1.6, 3.0)], m)
    parede("ext_fundo", (hw, hd), (-hw, hd), 0, 4.0, [], m)
    parede("ext_esq", (-hw, hd), (-hw, -hd), 0, 4.0, [(d / 2, 0.8, 1.6, 3.0)], m, 1)
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    ang = math.atan2(1.6, hw + 0.4)
    for s in (-1, 1):
        caixa("telhado_%d-col" % (s + 1), (s * (hw + 0.4) / 2, 0, 4.8), (math.hypot(hw + 0.4, 1.6), d + 0.6, 0.15), "telha", (0, s * ang, 0))
    junta([caixa("c", (0, -hd, 6.2), (0.15, 0.15, 1.6), "metal"), caixa("c", (0, -hd, 6.5), (0.8, 0.15, 0.15), "metal")], "cruz")
    caixa("caixao-col", (0, 1.0, 0.5), (0.7, 2.0, 0.5), "madeira", (0, 0, 0.1))
    picha("picho", "ELES LEVANTAM", (-hw, -hd), (hw, -hd), 1.4, 1.6, 1, 1.6)
    sai(nome)


def banco_praca(nome):
    limpa()
    p = [caixa("b", (0, 0, 0.45), (1.8, 0.45, 0.05), "madeira"), caixa("b", (0, 0.22, 0.75), (1.8, 0.05, 0.4), "madeira")]
    for x in (-0.75, 0.75):
        p.append(caixa("b", (x, 0.05, 0.25), (0.08, 0.5, 0.5), "concreto"))
    junta(p, "banco-col")
    sai(nome)


if __name__ == "__main__":
    os.makedirs(SAIDA, exist_ok=True)
    SO = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
    TODOS = []
    tamanhos = [(7, 12, 2), (8, 12, 2), (6, 11, 2), (9, 13, 2), (10, 12, 3), (7, 12, 1), (8, 13, 2), (9, 12, 2),
                (6, 12, 2), (10, 14, 2), (7, 11, 3), (8, 12, 1), (9, 13, 2), (7, 12, 2), (8, 11, 2), (10, 13, 2)]
    for k, loja in enumerate(LOJAS):
        w, d, a = tamanhos[k]
        porta = ["aberta", "aberta", "fechada", "arrombada"][k % 4]
        TODOS.append(("sobrado_%d" % (k + 1), lambda k=k, loja=loja, w=w, d=d, a=a, porta=porta: sobrado("sobrado_%d" % (k + 1), w, d, 100 + k, loja, a, porta)))
    for k, (w, d, an, pl) in enumerate([(16, 14, 7, "SOLAR"), (14, 12, 5, "AURORA"), (18, 14, 9, "IPÊ"), (15, 13, 6, "PRIMAVERA")]):
        TODOS.append(("apto_%d" % (k + 1), lambda k=k, w=w, d=d, an=an, pl=pl: predio_apto("apto_%d" % (k + 1), w, d, an, 200 + k, pl)))
    for k, (w, d, a) in enumerate([(5, 6, 1), (6, 5, 2), (4.5, 5.5, 1), (5.5, 6.5, 2), (6, 6, 1), (5, 5, 2), (4.5, 6, 1), (6.5, 5.5, 2)]):
        TODOS.append(("barraco_%d" % (k + 1), lambda k=k, w=w, d=d, a=a: barraco("barraco_%d" % (k + 1), w, d, 300 + k, a)))
    TODOS += [("igreja", lambda: igreja("igreja")), ("hospital", lambda: hospital("hospital")), ("mercado", lambda: mercado("mercado")),
              ("escola", lambda: escola("escola")), ("poste", lambda: poste("poste", False)), ("poste_trafo", lambda: poste("poste_trafo", True)),
              ("ponto_onibus", lambda: ponto_onibus("ponto_onibus")), ("orelhao", lambda: orelhao("orelhao")), ("banca", lambda: banca("banca")),
              ("coreto", lambda: coreto("coreto")), ("portico", lambda: portico("portico")), ("cacamba", lambda: cacamba("cacamba")),
              ("traves", lambda: traves("traves")), ("escadaria", lambda: favela_escadaria("escadaria")),
              ("arvore_1", lambda: arvore("arvore_1", 401)), ("arvore_2", lambda: arvore("arvore_2", 402)),
              ("arvore_3", lambda: arvore("arvore_3", 403, True)), ("palmeira", lambda: palmeira("palmeira", 404)),
              ("tumulo_1", lambda: tumulo("tumulo_1", 501)), ("tumulo_2", lambda: tumulo("tumulo_2", 502)),
              ("tumulo_3", lambda: tumulo("tumulo_3", 503)), ("capela", lambda: capela("capela")), ("banco_praca", lambda: banco_praca("banco_praca"))]
    for nome, faz in TODOS:
        if not SO or nome in SO:
            faz()
    print("CIDADE_OK")
