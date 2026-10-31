# Casas e prédios em ruína do fim do mundo, modelados por código no Blender (pedido do dono, 30/10: "modele casas no
# Blender, estilo apocalíptico"). Rodar:
#   ~/.local/blender/blender-4.2.9-linux-x64/blender -b -P tools/blender/ruinas.py -- assets/ruinas
# Cada modelo vira um .glb com a frente virada para +Z (Godot), chão em y = 0 e centro do lote em (0, 0).
# Colisão: objetos com "-col" ganham colisão igual à malha no import do Godot; "-colonly" é só colisão (rampa da
# escada, tábuas que tapam janela). O resto (entulho pequeno, vigas, vidro) não bate. Assim não sobra parede invisível.
# Materiais só pelo nome (parede, tijolo, madeira, concreto, telhado, metal, queimado, tabua): o jogo troca pela
# textura dele (Bairro._mat_ruina). Tudo determinístico (semente por modelo).
import bpy
import bmesh
import math
import random
import sys
from mathutils import Vector

SAIDA = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/ruinas"
PE = 3.0      # pé-direito
ESP = 0.22    # espessura da parede
PORTA_L = 1.2
PORTA_A = 2.2
JAN_L = 1.1
JAN_BASE = 0.95
JAN_TOPO = 2.15

CORES = {
    "parede": (0.75, 0.72, 0.66), "tijolo": (0.55, 0.3, 0.22), "madeira": (0.45, 0.36, 0.27),
    "concreto": (0.55, 0.55, 0.53), "telhado": (0.3, 0.28, 0.27), "metal": (0.35, 0.33, 0.3),
    "queimado": (0.06, 0.05, 0.05), "tabua": (0.42, 0.33, 0.24), "pano": (0.32, 0.3, 0.28),
    "branco": (0.78, 0.77, 0.72), "papelao": (0.55, 0.45, 0.32), "lataria": (0.4, 0.15, 0.12),
    "vidro": (0.05, 0.06, 0.07), "pneu": (0.04, 0.04, 0.04), "ferrugem": (0.35, 0.18, 0.08),
    "tapete": (0.38, 0.14, 0.11), "quadro": (0.3, 0.33, 0.36),
    # 31/10: cores de tecido e de cômodo (cada casa sorteia; o Bairro troca pela textura com a mesma cor)
    "tecido_verde": (0.22, 0.3, 0.2), "tecido_vinho": (0.35, 0.1, 0.12), "tecido_mostarda": (0.6, 0.45, 0.15),
    "tecido_azul": (0.15, 0.22, 0.38), "tecido_cinza": (0.4, 0.4, 0.42), "azulejo": (0.75, 0.8, 0.8),
    "crianca_rosa": (0.85, 0.5, 0.6), "crianca_azul": (0.4, 0.6, 0.85), "lata": (0.6, 0.6, 0.62),
    "batente": (0.85, 0.83, 0.78), "papel_1": (0.7, 0.66, 0.55), "papel_2": (0.6, 0.65, 0.6), "papel_3": (0.75, 0.7, 0.62),
    "lambri": (0.45, 0.33, 0.22), "piso_tabua": (0.5, 0.38, 0.26), "piso_ladrilho": (0.6, 0.58, 0.55), "forro": (0.85, 0.84, 0.8),
    "fachada_amarela": (0.8, 0.7, 0.45), "fachada_azul": (0.5, 0.6, 0.7), "fachada_tijolo": (0.6, 0.35, 0.28),
    "fachada_madeira": (0.65, 0.62, 0.55), "fachada_vermelha": (0.7, 0.35, 0.3), "telha": (0.55, 0.25, 0.18),
    "vidro_janela": (0.35, 0.45, 0.5),
    "militar": (0.24, 0.27, 0.17), "lona": (0.38, 0.38, 0.27), "areia": (0.55, 0.48, 0.33), "vermelho": (0.6, 0.08, 0.06),
}
TECIDOS = ["tecido_verde", "tecido_vinho", "tecido_mostarda", "tecido_azul", "tecido_cinza", "pano"]
rnd = random.Random(1)
_mats = {}


def mat(n):
    if n not in _mats:
        m = bpy.data.materials.new(n)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*CORES[n], 1)
        _mats[n] = m
    return _mats[n]


def caixa(nome, centro, tam, m, rot=(0, 0, 0)):
    """Caixa com centro e tamanho em metros (Blender: x direita, y fundo, z cima)."""
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2]))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.location = centro
    o.rotation_euler = rot
    me.materials.append(mat(m))
    return o


def junta(objs, nome):
    objs = [o for o in objs if o]
    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = nome
    return o


def bolha(centro, raio, achata=1.0):
    """Pedaço irregular (para morder parede ou fazer monte de entulho)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=raio, location=centro)
    o = bpy.context.object
    for v in o.data.vertices:
        v.co *= rnd.uniform(0.65, 1.25)
        v.co.z *= achata
    return o


def morde(alvo, centro, raio):
    """Arranca um pedaço quebrado do alvo (buraco de parede com borda irregular)."""
    b = bolha(centro, raio)
    md = alvo.modifiers.new("quebra", "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.object = b
    md.solver = "EXACT"
    bpy.context.view_layer.objects.active = alvo
    bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.data.objects.remove(b, do_unlink=True)


def parede(nome, a, b, z0, alt, aberturas, m, quebras=0, cor_topo=None, esp=ESP):
    """Parede reta de a até b (x, y) com aberturas [(t, largura, base, topo)] (t = metros a partir de a).
    quebras: quantas mordidas na borda de cima. Devolve o objeto (com "-col")."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    d = b - a
    comp = d.length
    u = d.normalized()
    ang = math.atan2(u.y, u.x)
    pecas = []

    def peca(t0, t1, zb, zt):
        if t1 - t0 < 0.02 or zt - zb < 0.02:
            return
        c = a + u * ((t0 + t1) * 0.5)
        pecas.append(caixa("p", (c.x, c.y, z0 + (zb + zt) * 0.5), (t1 - t0, esp, zt - zb), m, (0, 0, ang)))

    t = 0.0
    for (tc, lg, base, topo) in sorted(aberturas):
        t0, t1 = tc - lg * 0.5, tc + lg * 0.5
        peca(t, t0, 0, alt)
        peca(t0, t1, 0, base)
        peca(t0, t1, topo, alt)
        t = t1
    peca(t, comp, 0, alt)
    o = junta(pecas, nome + ("-col" if esp > 0.05 else ""))
    if o is None:
        return None
    for _ in range(quebras):
        tc = rnd.uniform(0.15, 0.85) * comp
        c = a + u * tc
        morde(o, (c.x, c.y, z0 + alt + rnd.uniform(-0.3, 0.2)), rnd.uniform(0.7, 1.5))
    if cor_topo:
        o.data.materials.append(mat(cor_topo))
    return o


def janelas(comp, n, porta_t=None):
    """n janelas espalhadas na parede, longe da porta."""
    out = []
    for k in range(n):
        tc = comp * (k + 1) / (n + 1)
        if porta_t is not None and abs(tc - porta_t) < 1.6:
            continue
        out.append((tc, JAN_L, JAN_BASE, JAN_TOPO))
    return out


def tabuas(nome, a, b, tc, z0, m="tabua"):
    """Tábuas pregadas tapando uma janela (visual) + uma placa só de colisão."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    ang = math.atan2(u.y, u.x)
    fora = Vector((u.y, -u.x, 0)) * (ESP * 0.5 + 0.03)
    c = a + u * tc + fora
    objs = []
    for k in range(rnd.randint(2, 4)):
        z = z0 + JAN_BASE + 0.2 + k * 0.32
        objs.append(caixa("t", (c.x, c.y, z), (JAN_L + 0.35, 0.03, 0.18), m, (0, rnd.uniform(-0.25, 0.25), ang)))
    junta(objs, nome)
    caixa(nome + "_bloqueio-colonly", (c.x, c.y, z0 + (JAN_BASE + JAN_TOPO) * 0.5), (JAN_L, 0.06, JAN_TOPO - JAN_BASE), "tabua", (0, 0, ang))


def entulho(nome, centro, n=6, raio=0.5, m="concreto"):
    objs = []
    for _ in range(n):
        p = (centro[0] + rnd.uniform(-1, 1), centro[1] + rnd.uniform(-1, 1), centro[2])
        objs.append(bolha(p, raio * rnd.uniform(0.5, 1.2), 0.45))
    for o in objs:
        o.data.materials.append(mat(m))
    for _ in range(n // 2):  # tábuas e vigas caídas no meio
        objs.append(caixa("v", (centro[0] + rnd.uniform(-1, 1), centro[1] + rnd.uniform(-1, 1), centro[2] + 0.15),
                          (rnd.uniform(1.2, 2.6), 0.12, 0.08), "madeira", (rnd.uniform(-0.3, 0.3), 0.1, rnd.uniform(0, 3.14))))
    junta(objs, nome)


def piso(nome, x0, y0, x1, y1, z, m, esp=0.18, buraco=None, col=True):
    """Laje retangular; buraco = (x0, y0, x1, y1) fica vazado (vão da escada ou laje que caiu)."""
    pecas = []
    if buraco is None:
        pecas.append(caixa("l", ((x0 + x1) / 2, (y0 + y1) / 2, z - esp / 2), (x1 - x0, y1 - y0, esp), m))
    else:
        bx0, by0, bx1, by1 = buraco
        for (a0, b0, a1, b1) in [(x0, y0, bx0, y1), (bx1, y0, x1, y1), (bx0, y0, bx1, by0), (bx0, by1, bx1, y1)]:
            if a1 - a0 > 0.02 and b1 - b0 > 0.02:
                pecas.append(caixa("l", ((a0 + a1) / 2, (b0 + b1) / 2, z - esp / 2), (a1 - a0, b1 - b0, esp), m))
    return junta(pecas, nome + ("-col" if col else ""))


def escada(nome, x, y0, y1, z0, z1, larg=1.1):
    """Escada subindo de y0 (embaixo) até y1 (em cima) na faixa x: degraus de enfeite + rampa de colisão."""
    n = max(4, int((z1 - z0) / 0.19))
    passo = (y1 - y0) / n
    deg = []
    for k in range(n):
        h = (k + 1) * (z1 - z0) / n
        deg.append(caixa("d", (x, y0 + passo * (k + 0.5), z0 + h / 2), (larg, abs(passo), h), "concreto"))
    junta(deg, nome)
    comp = math.hypot(y1 - y0, z1 - z0)
    ang = math.atan2(z1 - z0, y1 - y0)
    caixa(nome + "_rampa-colonly", (x, (y0 + y1) / 2, (z0 + z1) / 2), (larg, comp, 0.1), "concreto", (ang, 0, 0))


def telhado(nome, w, d, z, partes_caidas, m="telhado"):
    """Telhado de duas águas (cumeeira ao longo de x) em placas; algumas placas caíram (sobram as vigas)."""
    alt = 1.6
    n = max(3, int(w / 2.0))
    larg = (w + 0.6) / n
    agua = math.hypot(d / 2 + 0.4, alt)
    ang = math.atan2(alt, d / 2 + 0.4)
    pl, vg = [], []
    for k in range(n):
        x = -w / 2 - 0.3 + larg * (k + 0.5)
        for lado in (-1, 1):
            if (k, lado) in partes_caidas:
                vg.append(caixa("vg", (x, lado * d / 4, z + alt / 2), (0.1, agua, 0.14), "madeira", (lado * -ang, 0, 0)))
                continue
            pl.append(caixa("tp", (x, lado * (d / 4 + 0.1), z + alt / 2), (larg, agua, 0.1), m, (lado * -ang, 0, 0)))
    junta(pl, nome + "-col")
    junta(vg, nome + "_vigas")
    # oitões (triângulos das pontas)
    for s in (-1, 1):
        me = bpy.data.meshes.new("oitao")
        y = d / 2
        me.from_pydata([(s * w / 2, -y, z), (s * w / 2, y, z), (s * w / 2, 0, z + alt)], [], [(0, 1, 2)])
        o = bpy.data.objects.new(nome + "_oitao%d" % (s + 1), me)
        bpy.context.collection.objects.link(o)
        me.materials.append(mat("madeira"))
        sol = o.modifiers.new("esp", "SOLIDIFY")
        sol.thickness = ESP
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=sol.name)


def marca_porta(x, y):
    """Dobradiça da porta da frente (o jogo põe a Porta aqui, abrindo ao longo de +x)."""
    e = bpy.data.objects.new("porta", None)
    bpy.context.collection.objects.link(e)
    e.location = (x - PORTA_L / 2, y, 0)


def caixa_paredes(w, d, z0, alt, m, frente_porta, n_jan, quebras, tapadas, fundo_porta=True, nome="ext"):
    """Quatro paredes externas; frente em y = -d/2 (vira +Z no Godot)."""
    hw, hd = w / 2, d / 2
    lados = [  # a, b, comprimento, tem porta?
        ((-hw, -hd), (hw, -hd), w, frente_porta),
        ((hw, -hd), (hw, hd), d, False),
        ((hw, hd), (-hw, hd), w, fundo_porta),
        ((-hw, hd), (-hw, -hd), d, False),
    ]
    for i, (a, b, comp, porta) in enumerate(lados):
        ab = []
        pt = None
        if porta:
            pt = comp / 2 + (rnd.uniform(-1, 1) if comp > 6 else 0)
            ab.append((pt, PORTA_L, 0, PORTA_A))
        js = janelas(comp, n_jan if comp > 5 else 1, pt)
        ab += js
        parede("%s_%d" % (nome, i), a, b, z0, alt, ab, m, quebras[i] if i < len(quebras) else 0)
        for (tc, *_r) in js:
            if rnd.random() < tapadas:
                tabuas("%s_%d_tabua_%d" % (nome, i, int(tc * 10)), a, b, tc, z0)
        if porta and i == 0 and z0 == 0:
            marca_porta(a[0] + pt, -hd)


def divisorias(w, d, z0, m):
    """Parede interna atravessando a casa (com vão) e outra dividindo um dos lados."""
    x = rnd.uniform(-0.15, 0.15) * w
    t = rnd.uniform(1.2, d - 2.4)
    parede("int_0", (x, -d / 2 + ESP), (x, d / 2 - ESP), z0, PE, [(t, 1.0, 0, 2.1)], m)
    porta_y = -d / 2 + ESP + t
    y = rnd.uniform(-0.1, 0.25) * d
    for _ in range(20):  # a outra parede não pode encostar no vão da primeira (trancava o cômodo)
        if abs(y - porta_y) > 1.1:
            break
        y = rnd.uniform(-0.3, 0.3) * d
    x1 = w / 2 - ESP if rnd.random() < 0.5 else -w / 2 + ESP
    parede("int_1", (x, y), (x1, y), z0, PE, [(abs(x1 - x) / 2, 1.0, 0, 2.1)], m)
    return x, y, (1 if x1 > 0 else -1)


# ----- móveis (encostados nas paredes de lado, na metade da frente: os cantos do fundo ficam para baú e item) -----

def sofa(nome, x, y, ang, t="pano"):
    p = [caixa("s", (0, 0, 0.22), (2.0, 0.85, 0.3), t), caixa("s", (0, 0.33, 0.6), (2.0, 0.2, 0.6), t),
         caixa("s", (-0.92, 0, 0.45), (0.18, 0.85, 0.5), t), caixa("s", (0.92, 0, 0.45), (0.18, 0.85, 0.5), t),
         caixa("s", (0.4, -0.05, 0.42), (0.7, 0.6, 0.12), t, (0.15, 0.1, 0.3))]  # almofada largada
    _poe(junta(p, nome + "-col"), x, y, ang)


def cama(nome, x, y, ang):
    p = [caixa("c", (0, 0, 0.18), (1.1, 2.0, 0.22), "madeira"), caixa("c", (0, 0, 0.38), (1.0, 1.9, 0.2), "pano"),
         caixa("c", (0, 0.95, 0.55), (1.1, 0.08, 0.8), "madeira"), caixa("c", (0.1, -0.2, 0.5), (1.05, 1.0, 0.04), "pano", (0, 0.2, 0.15))]
    _poe(junta(p, nome + "-col"), x, y, ang)


def geladeira(nome, x, y, ang, caida):
    p = [caixa("g", (0, 0, 0.9), (0.75, 0.7, 1.8), "branco"), caixa("g", (0.36, -0.36, 1.2), (0.04, 0.03, 0.4), "metal")]
    o = junta(p, nome + "-col")
    _poe(o, x, y, ang)
    if caida:  # tombada de cara no chão
        o.rotation_euler = (-1.5708, 0, ang)
        o.location.z = 0.36
        o.location.y -= 0.6


def balcao(nome, x, y, ang, larg=2.2):
    p = [caixa("b", (0, 0, 0.44), (larg, 0.6, 0.88), "madeira"), caixa("b", (0, 0, 0.9), (larg + 0.05, 0.65, 0.04), "concreto")]
    _poe(junta(p, nome + "-col"), x, y, ang)


def estante(nome, x, y, ang, caida=False, larg=1.2, cor="madeira"):
    p = [caixa("e", (-larg / 2, 0, 0.95), (0.04, 0.4, 1.9), cor), caixa("e", (larg / 2, 0, 0.95), (0.04, 0.4, 1.9), cor),
         caixa("e", (0, 0.19, 0.95), (larg, 0.02, 1.9), cor)]
    for k in range(4):
        p.append(caixa("e", (0, 0, 0.1 + k * 0.55), (larg, 0.4, 0.03), cor))
        for q in range(rnd.randint(0, 3)):  # tralha que sobrou
            p.append(caixa("e", (rnd.uniform(-larg / 2 + 0.15, larg / 2 - 0.15), 0, 0.2 + k * 0.55), (0.2, 0.25, 0.2), "papelao"))
    o = junta(p, nome + "-col")
    _poe(o, x, y, ang)
    if caida:
        o.rotation_euler = (1.35, 0, ang)
        o.location.z = 0.25


def mesa(nome, x, y):
    p = [caixa("m", (0, 0, 0.74), (1.3, 0.8, 0.05), "madeira")]
    for sx in (-0.58, 0.58):
        for sy in (-0.33, 0.33):
            p.append(caixa("m", (sx, sy, 0.36), (0.06, 0.06, 0.72), "madeira"))
    _poe(junta(p, nome + "-col"), x, y, rnd.uniform(-0.3, 0.3))
    for k in range(2):  # cadeiras: uma em pé, uma caída
        c = [caixa("k", (0, 0, 0.45), (0.42, 0.42, 0.04), "madeira"), caixa("k", (0, 0.19, 0.7), (0.42, 0.04, 0.5), "madeira")]
        for sx in (-0.18, 0.18):
            for sy in (-0.18, 0.18):
                c.append(caixa("k", (sx, sy, 0.22), (0.04, 0.04, 0.45), "madeira"))
        o = junta(c, "%s_cadeira%d" % (nome, k))
        _poe(o, x + (0.9 if k else -0.2), y + (0.2 if k else -0.75), rnd.uniform(0, 6.28))
        if k:
            o.rotation_euler.x = 1.57
            o.location.z = 0.22


def _poe(o, x, y, ang):
    o.location = (x, y, 0.06)
    o.rotation_euler = (0, 0, ang)


def tapete(nome, x, y, larg, comp):
    """Sem colisão (é chão): tapete gasto, um canto dobrado."""
    caixa(nome, (x, y, 0.075), (larg, comp, 0.015), "tapete", (0, 0, rnd.uniform(-0.2, 0.2)))
    caixa(nome + "_dobra", (x + larg * 0.4, y - comp * 0.4, 0.1), (larg * 0.25, comp * 0.25, 0.015), "tapete", (0.5, 0, 0.3))


def quadro(nome, x, y, ang):
    """Quadro torto na parede (sem colisão): moldura e a foto apagada."""
    o = junta([caixa("q", (0, 0, 0), (0.55, 0.03, 0.42), "madeira"), caixa("q", (0, -0.02, 0), (0.45, 0.01, 0.32), "quadro")], nome)
    o.location = (x, y, rnd.uniform(1.45, 1.75))
    o.rotation_euler = (0, rnd.uniform(-0.25, 0.25), ang)


def tv(nome, x, y, ang):
    """Rack baixo com a TV velha caída de cara em cima."""
    p = [caixa("r", (0, 0, 0.25), (1.3, 0.45, 0.5), "madeira"), caixa("t", (0.1, 0.02, 0.6), (0.8, 0.5, 0.18), "metal", (0.12, 0, 0.1))]
    _poe(junta(p, nome + "-col"), x, y, ang)


def fogao(nome, x, y, ang):
    p = [caixa("f", (0, 0, 0.42), (0.6, 0.6, 0.84), "branco"), caixa("f", (0, 0, 0.86), (0.6, 0.6, 0.03), "metal"),
         caixa("f", (0, -0.31, 0.45), (0.5, 0.02, 0.4), "vidro")]
    _poe(junta(p, nome + "-col"), x, y, ang)


def armario_aereo(nome, x, y, ang, larg):
    """Armário de cozinha na parede, uma porta caída (sem colisão: fica acima da cabeça)."""
    o = junta([caixa("a", (0, 0, 0), (larg, 0.35, 0.6), "madeira"), caixa("a", (larg * 0.25, -0.3, -0.25), (larg * 0.45, 0.02, 0.55), "madeira", (0.6, 0, 0))], nome)
    o.location = (x, y, 1.75)
    o.rotation_euler = (0, 0, ang)


def guarda_roupa(nome, x, y, ang):
    p = [caixa("g", (0, 0, 1.0), (1.2, 0.55, 2.0), "madeira"), caixa("g", (0.31, -0.29, 1.0), (0.56, 0.03, 1.9), "madeira", (0, 0, -0.5)),
         caixa("g", (-0.2, -0.1, 0.12), (0.6, 0.3, 0.2), "pano")]  # porta aberta e roupa no fundo
    _poe(junta(p, nome + "-col"), x, y, ang)


def criado(nome, x, y, ang=None):
    p = [caixa("c", (0, 0, 0.27), (0.45, 0.4, 0.54), "madeira"), caixa("c", (0.05, 0, 0.62), (0.15, 0.15, 0.16), "branco")]
    _poe(junta(p, nome + "-col"), x, y, (ang if ang is not None else 0.0) + rnd.uniform(-0.2, 0.2))


def bagunca(nome, x, y, n):
    """Papéis, roupa e latas no chão (sem colisão) e umas caixas de papelão (com colisão)."""
    for k in range(n):
        caixa("%s_papel%d" % (nome, k), (x + rnd.uniform(-1.2, 1.2), y + rnd.uniform(-1.0, 1.0), 0.07),
              (rnd.uniform(0.15, 0.3), rnd.uniform(0.2, 0.3), 0.005), rnd.choice(["branco", "papelao", "pano"]), (0, 0, rnd.uniform(0, 6.28)))
    for k in range(rnd.randint(1, 2)):
        tam = rnd.uniform(0.35, 0.55)
        caixa("%s_caixa%d-col" % (nome, k), (x + rnd.uniform(-0.8, 0.8), y + rnd.uniform(-0.6, 0.6), 0.06 + tam / 2),
              (tam, tam * 0.8, tam), "papelao", (0, 0, rnd.uniform(0, 6.28)))


def poltrona(nome, x, y, ang, t):
    p = [caixa("p", (0, 0, 0.22), (0.85, 0.8, 0.3), t), caixa("p", (0, 0.32, 0.6), (0.85, 0.18, 0.6), t),
         caixa("p", (-0.36, 0, 0.45), (0.14, 0.8, 0.45), t), caixa("p", (0.36, 0, 0.45), (0.14, 0.8, 0.45), t)]
    _poe(junta(p, nome + "-col"), x, y, ang)


def pia(nome, x, y, ang):
    p = [caixa("p", (0, 0, 0.44), (1.0, 0.55, 0.88), "madeira"), caixa("p", (0, 0, 0.9), (1.05, 0.6, 0.04), "branco"),
         caixa("p", (0, -0.02, 0.87), (0.5, 0.35, 0.06), "metal")]
    _poe(junta(p, nome + "-col"), x, y, ang)


def berco(nome, x, y, ang):
    """Berço vazio com a grade quebrada (o que aconteceu aqui fica para quem vê)."""
    p = [caixa("b", (0, 0, 0.3), (0.7, 1.25, 0.05), "branco")]
    for sx in (-0.33, 0.33):
        for sy in (-0.6, 0.6):
            p.append(caixa("b", (sx, sy, 0.45), (0.05, 0.05, 0.9), "branco"))
    for k in range(9):
        if k != 4:
            p.append(caixa("b", (0.33, -0.55 + k * 0.14, 0.62), (0.03, 0.03, 0.6), "branco"))
    p.append(caixa("b", (0, 0.1, 0.36), (0.6, 0.9, 0.08), "crianca_azul"))
    _poe(junta(p, nome + "-col"), x, y, ang)
    for k in range(4):  # brinquedos no chão (sem colisão)
        caixa("%s_brinq%d" % (nome, k), (x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1), 0.11), (0.14, 0.14, 0.12),
              rnd.choice(["crianca_rosa", "crianca_azul", "tecido_mostarda"]), (0, 0, rnd.uniform(0, 6.28)))


def vaso(nome, x, y, ang):
    p = [caixa("v", (0, -0.05, 0.22), (0.4, 0.5, 0.44), "branco"), caixa("v", (0, 0.25, 0.6), (0.42, 0.18, 0.4), "branco")]
    _poe(junta(p, nome + "-col"), x, y, ang)


def banheira(nome, x, y, ang):
    p = [caixa("b", (0, 0, 0.06 + 0.25), (0.75, 1.6, 0.06), "branco"), caixa("b", (-0.35, 0, 0.3), (0.05, 1.6, 0.55), "branco"),
         caixa("b", (0.35, 0, 0.3), (0.05, 1.6, 0.55), "branco"), caixa("b", (0, -0.78, 0.3), (0.75, 0.05, 0.55), "branco"),
         caixa("b", (0, 0.78, 0.3), (0.75, 0.05, 0.55), "branco"), caixa("b", (0, 0.1, 0.36), (0.6, 1.2, 0.02), "vidro")]
    _poe(junta(p, nome + "-col"), x, y, ang)


def escrivaninha(nome, x, y, ang):
    p = [caixa("e", (0, 0, 0.74), (1.4, 0.7, 0.04), "madeira"), caixa("e", (-0.55, 0, 0.37), (0.3, 0.66, 0.72), "madeira"),
         caixa("e", (0.66, 0, 0.37), (0.04, 0.66, 0.72), "madeira"), caixa("e", (0.2, 0.1, 0.9), (0.45, 0.06, 0.3), "metal")]
    _poe(junta(p, nome + "-col"), x, y, ang)
    for k in range(5):  # papéis espalhados na mesa e no chão
        caixa("%s_papel%d" % (nome, k), (x + rnd.uniform(-0.7, 0.7), y + rnd.uniform(-0.7, 0.7), 0.07 if k > 1 else 0.77),
              (0.21, 0.29, 0.004), "branco", (0, 0, rnd.uniform(0, 6.28)))


def despensa(nome, x, y, ang):
    """Prateleira de metal com latas (a maioria levada)."""
    p = [caixa("d", (0, 0, 0.9), (1.2, 0.45, 0.03), "metal")]
    for k in range(4):
        p.append(caixa("d", (0, 0, 0.12 + k * 0.5), (1.2, 0.45, 0.03), "metal"))
        for q in range(rnd.randint(0, 4)):
            p.append(caixa("d", (rnd.uniform(-0.5, 0.5), 0, 0.2 + k * 0.5), (0.1, 0.1, 0.13), "lata"))
    for sx in (-0.58, 0.58):
        p.append(caixa("d", (sx, 0, 0.95), (0.04, 0.45, 1.9), "metal"))
    _poe(junta(p, nome + "-col"), x, y, ang)


def abajur(nome, x, y):
    """Abajur de pé tombado (sem colisão)."""
    o = junta([caixa("a", (0, 0, 0.75), (0.04, 0.04, 1.5), "metal"), caixa("a", (0, 0, 1.55), (0.38, 0.38, 0.3), "tecido_mostarda")], nome)
    o.location = (x, y, 0.1)
    o.rotation_euler = (1.45, 0, rnd.uniform(0, 6.28))


# Móveis de costas para a parede de lado (`lado` -1 = esquerda, 1 = direita), de frente para o cômodo, um atrás do outro
# entre y0 e y1. Cada item: (função(nome, x, y, ang), profundidade, largura).
def ao_longo(w, lado, y0, y1, itens, nome):
    ang = 1.5708 if lado < 0 else -1.5708
    y = y0 + 0.35
    for k, item in enumerate(itens):
        f, prof, larg = item[0], item[1], item[2]
        if y + larg > y1 - 0.35:
            break
        x = lado * (w / 2 - ESP - prof / 2 - 0.03)
        base = item[3] if len(item) > 3 else f.__name__  # o Bairro acha gavetas e troca o modelo pelo começo do nome
        f("%s_%s%d" % (base, nome, k), x, y + larg / 2, ang)
        y += larg + rnd.uniform(0.15, 0.5)


def comodo(tema, w, lado, x0, y0, y1, nome):
    """Um cômodo: parede de lado em `lado`, de x0 (parede do meio) até a borda, de y0 até y1."""
    meio_x = (x0 + lado * (w / 2 - ESP)) / 2
    meio_y = (y0 + y1) / 2
    tec = rnd.choice(TECIDOS)
    if tema == "sala":
        ao_longo(w, lado, y0, y1, [(lambda n, x, y, a: sofa(n, x, y, a, tec), 0.85, 2.0, "sofa"), (estante, 0.4, 1.2),
                                   (lambda n, x, y, a: poltrona(n, x, y, a, rnd.choice(TECIDOS)), 0.8, 0.85, "poltrona")], nome)
        tapete(nome + "_tapete", meio_x, meio_y, 1.6, 2.2)
        if abs(x0 - lado * (w / 2)) > 3.2:
            tv("tv_" + nome, meio_x + lado * -0.8, meio_y, 1.5708 if lado > 0 else -1.5708)
        if rnd.random() < 0.5:
            abajur(nome + "_abajur", meio_x, y0 + 0.8)
    elif tema == "cozinha":
        ao_longo(w, lado, y0, y1, [(balcao, 0.6, 1.8), (fogao, 0.6, 0.6), (pia, 0.6, 1.0),
                                   (lambda n, x, y, a: geladeira(n, x, y, a, rnd.random() < 0.3), 0.7, 0.75, "geladeira")], nome)
        armario_aereo("armario_" + nome, lado * (w / 2 - ESP - 0.2), (y0 + y1) / 2, 1.5708 if lado < 0 else -1.5708, min(1.8, (y1 - y0) - 1.0))
        if abs(x0 - lado * (w / 2)) > 3.0:
            mesa(nome + "_mesa", meio_x - lado * 0.4, meio_y)
    elif tema == "quarto":
        ao_longo(w, lado, y0, y1, [(criado, 0.4, 0.45), (cama, 2.0, 1.1), (guarda_roupa, 0.55, 1.2)], nome)
        tapete(nome + "_tapete", meio_x, meio_y, 1.2, 1.6)
    elif tema == "crianca":
        ao_longo(w, lado, y0, y1, [(berco, 0.7, 1.25), (criado, 0.4, 0.45), (guarda_roupa, 0.55, 1.2)], nome)
        tapete(nome + "_tapete", meio_x, meio_y, 1.4, 1.4)
    elif tema == "banheiro":
        ao_longo(w, lado, y0, y1, [(vaso, 0.65, 0.5), (pia, 0.55, 1.0), (banheira, 0.75, 1.6)], nome)
    elif tema == "escritorio":
        ao_longo(w, lado, y0, y1, [(escrivaninha, 0.7, 1.4), (estante, 0.4, 1.2), (estante, 0.4, 1.2)], nome)
    elif tema == "despensa":
        ao_longo(w, lado, y0, y1, [(despensa, 0.45, 1.2), (despensa, 0.45, 1.2)], nome)
    bagunca(nome + "_bag", meio_x, meio_y, 5)


def mobilia(w, d, paredes):
    """Cada cômodo da casa ganha um tema sorteado (31/10, dono: 'sempre o mesmo interior, e feio'): o lado inteiro vira
    sala; o lado dividido vira frente (cozinha/escritório/quarto) e fundo (quarto/criança/banheiro/despensa)."""
    x, y, lado_div = paredes
    inteiro = -lado_div
    comodo("sala", w, inteiro, x, -d / 2 + ESP, d / 2 - ESP - 1.2, "sala")  # o canto do fundo fica para o baú
    comodo(rnd.choice(["cozinha", "cozinha", "escritorio", "quarto"]), w, lado_div, x, -d / 2 + ESP, y - ESP, "frente")
    comodo(rnd.choice(["quarto", "quarto", "crianca", "banheiro", "despensa"]), w, lado_div, x, y + ESP, d / 2 - ESP - 1.2, "fundo")


def limpa():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def _adensa(o, passo=0.7):
    """Corta as faces grandes em pedaços de ~passo m (a sombra dos cantos fica nos vértices)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for _ in range(5):
        longas = [e for e in bm.edges if e.calc_length() > passo]
        if not longas:
            break
        bmesh.ops.subdivide_edges(bm, edges=longas, cuts=1, use_grid_fill=True)
    bm.to_mesh(o.data)
    bm.free()


def assa_sombra():
    """Sombra de canto (oclusão de ambiente) assada nas cores dos vértices: escurece pé de parede, cantos, debaixo de
    móvel e dentro dos cômodos. Custa zero no celular (o modo de compatibilidade não tem isso em tempo real).
    A colisão continua com a malha simples: cada "-col" vira uma cópia "-colonly" antes de adensar."""
    vis = []
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.name.endswith("-colonly"):
            continue
        if o.name.endswith("-col"):
            c = o.copy()
            c.data = o.data.copy()
            bpy.context.collection.objects.link(c)
            c.name = o.name[:-4] + "_c-colonly"
            o.name = o.name[:-4]
        _adensa(o)
        if not o.data.color_attributes:
            o.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        vis.append(o)
    if not vis:
        return
    for o in bpy.data.objects:  # a colisão (cópia por cima da malha) não pode tapar a luz
        if o.name.endswith("-colonly"):
            o.hide_render = True
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("w")
    bpy.context.scene.world.light_settings.distance = 1.6
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    bpy.ops.object.select_all(action="DESELECT")
    for o in vis:
        o.select_set(True)
    bpy.context.view_layer.objects.active = vis[0]
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    for o in vis:  # canto escuro, mas nunca preto chapado (a luz do jogo ainda soma por cima)
        for c in o.data.color_attributes[0].data:
            v = 0.42 + 0.58 * (c.color[0] ** 0.75)  # 31/10: 0.32 deixava dentro de casa escuro demais
            c.color = (v, v, v, 1.0)


def exporta(nome):
    assa_sombra()
    bpy.ops.export_scene.gltf(filepath="%s/%s.glb" % (SAIDA, nome), export_format="GLB", export_apply=True,
                              export_materials="EXPORT", export_extras=False, export_yup=True,
                              export_vertex_color="ACTIVE")


# ----- os modelos -----

def casa(nome, w, d, semente, tipo):
    """tipo: "inteira" (telhado com buracos), "queimada" (sem telhado, paredes pretas e mordidas), "dois" (2 andares)."""
    limpa()
    rnd.seed(semente)
    m = rnd.choice(["parede", "tijolo", "madeira"]) if tipo != "queimada" else "queimado"
    andares = 2 if tipo == "dois" else 1
    for k in range(andares):
        q = [rnd.randint(0, 1) for _ in range(4)] if tipo != "queimada" else [rnd.randint(1, 3) for _ in range(4)]
        if k == 0 and tipo != "queimada":
            q[0] = 0  # frente inteira (a porta precisa do batente)
        caixa_paredes(w, d, k * PE, PE, m, k == 0, 2 if w > 8 else 1, q, 0.45 if k == 0 else 0.2,
                      nome="ext%d" % k)
    piso("chao", -w / 2, -d / 2, w / 2, d / 2, 0.06, "madeira" if tipo != "queimada" else "concreto", 0.06)
    paredes = divisorias(w, d, 0, m if tipo != "queimada" else "queimado")
    if tipo != "queimada":
        mobilia(w, d, paredes)
    if tipo == "dois":
        bx = (w / 2 - 1.5, d / 2 - 4.2, w / 2 - ESP, d / 2 - ESP)
        piso("laje1", -w / 2, -d / 2, w / 2, d / 2, PE, "concreto", buraco=bx)
        escada("escada", w / 2 - 0.85, d / 2 - 4.0, d / 2 - 0.4, 0.06, PE)
        piso("laje2", -w / 2, -d / 2, w / 2, d / 2, 2 * PE, "concreto",
             buraco=(-w / 2 + 1, -1.0, -w / 2 + 3.5, 1.5))  # laje de cima furada
        entulho("entulho_cima", (-w / 2 + 2.2, 0.2, PE), 5, 0.4)
    if tipo == "inteira" or tipo == "dois":
        n = max(3, int(w / 2.0))
        caidas = {(rnd.randrange(n), rnd.choice((-1, 1))) for _ in range(rnd.randint(1, 3))}
        telhado("telhado", w, d, andares * PE, caidas)
        piso("forro", -w / 2, -d / 2, w / 2, d / 2, andares * PE, "madeira", 0.05, col=False,
             buraco=(-1.5, -1.5, 1.2, 1.0))
    if tipo == "queimada":
        for k in range(3):
            caixa("viga_queimada_%d" % k, (rnd.uniform(-w / 3, w / 3), rnd.uniform(-d / 3, d / 3), 1.2),
                  (rnd.uniform(3, 5), 0.18, 0.18), "queimado", (rnd.uniform(0.3, 0.6), 0, rnd.uniform(0, 3)))
    entulho("entulho", (rnd.uniform(-w / 4, w / 4), rnd.uniform(-d / 4, d / 4), 0.06), 6, 0.45)
    entulho("entulho_fora", (w / 2 + 0.8, rnd.uniform(-d / 3, d / 3), 0), 4, 0.5, "tijolo" if m == "tijolo" else "concreto")
    exporta(nome)


# ----- casa de verdade (31/10, dono: "casa tem cômodo, igual casa real; moldura de porta; fachada bonita") -----
# Planta: coluna A (sala na frente, cozinha atrás) | corredor | coluna B (quarto, banheiro, quarto). Passagens sem porta,
# só o batente. Por dentro cada cômodo tem revestimento (lambri + papel de parede, azulejo na cozinha e no banheiro),
# piso (tábua ou ladrilho) e forro. Fachada em cores/texturas sorteadas, janelas com moldura, vidro, peitoril e cortina,
# varanda com colunas em algumas, telhado de telha inteiro.

PORTA_I = 0.95      # largura da passagem interna
ESP_I = 0.12        # parede interna


def batente(nome, a, b, tc, larg, topo, esp):
    """Moldura da passagem (dois montantes e a verga), um pouco mais grossa que a parede."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    ang = math.atan2(u.y, u.x)
    pc = []
    for s in (-1, 1):
        c = a + u * (tc + s * (larg / 2 + 0.04))
        pc.append(caixa("b", (c.x, c.y, topo / 2), (0.08, esp + 0.05, topo), "batente", (0, 0, ang)))
    c = a + u * tc
    pc.append(caixa("b", (c.x, c.y, topo + 0.05), (larg + 0.16, esp + 0.05, 0.1), "batente", (0, 0, ang)))
    junta(pc, nome)


def janela_real(nome, a, b, tc, z0, dentro_sinal, tec):
    """Moldura, peitoril de fora, vidro (às vezes quebrado ou sem) e cortina por dentro (às vezes)."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    n = Vector((-u.y, u.x, 0)) * dentro_sinal  # para dentro da casa
    ang = math.atan2(u.y, u.x)
    c = a + u * tc
    zc = z0 + (JAN_BASE + JAN_TOPO) / 2
    h = JAN_TOPO - JAN_BASE
    pc = [caixa("m", (c.x, c.y, z0 + JAN_TOPO + 0.04), (JAN_L + 0.16, ESP + 0.04, 0.08), "batente", (0, 0, ang)),
          caixa("m", (c.x, c.y, z0 + JAN_BASE - 0.04), (JAN_L + 0.16, ESP + 0.04, 0.08), "batente", (0, 0, ang))]
    for s in (-1, 1):
        q = c + u * s * (JAN_L / 2 + 0.04)
        pc.append(caixa("m", (q.x, q.y, zc), (0.08, ESP + 0.04, h + 0.16), "batente", (0, 0, ang)))
    q = c + u * 0.0
    pc.append(caixa("m", (q.x, q.y, zc), (0.05, 0.06, h), "batente", (0, 0, ang)))  # travessa do meio
    junta(pc, nome + "_moldura")
    fora = c - n * (ESP / 2 + 0.08)
    caixa(nome + "_peitoril", (fora.x, fora.y, z0 + JAN_BASE - 0.1), (JAN_L + 0.3, 0.2, 0.06), "concreto", (0, 0, ang))
    r = rnd.random()
    if r < 0.55:  # vidro inteiro
        caixa(nome + "_vidro", (c.x, c.y, zc), (JAN_L, 0.015, h), "vidro_janela", (0, 0, ang))
    elif r < 0.8:  # quebrado: só um caco em cima
        caixa(nome + "_caco", (c.x, c.y, z0 + JAN_TOPO - h * 0.2), (JAN_L, 0.015, h * 0.35), "vidro_janela", (0, rnd.uniform(-0.2, 0.2), ang))
    if rnd.random() < 0.6:  # cortina por dentro, puxada para um lado
        cdn = c + n * (ESP / 2 + 0.06) + u * rnd.choice((-1, 1)) * JAN_L * 0.35
        caixa(nome + "_cortina", (cdn.x, cdn.y, zc + 0.1), (JAN_L * 0.45, 0.04, h + 0.4), tec, (0, 0, ang))


def revestimento(nome, a, b, aberturas, dentro, mat_baixo, mat_cima, alt_baixo=1.0):
    """Pele fina por dentro de uma parede (a->b), deslocada para `dentro` (vetor), com as mesmas aberturas:
    embaixo `mat_baixo` até alt_baixo (lambri/azulejo), em cima `mat_cima` (papel de parede)."""
    a = Vector((a[0], a[1], 0)) + dentro
    b = Vector((b[0], b[1], 0)) + dentro
    ab_b = [(t, lg, base, min(topo, alt_baixo + 5)) for (t, lg, base, topo) in aberturas]
    parede(nome + "_baixo", (a.x, a.y), (b.x, b.y), 0.06, alt_baixo - 0.06, [(t, lg, max(base - 0.06, 0), topo - 0.06) for (t, lg, base, topo) in ab_b],
           mat_baixo, esp=0.02)
    parede(nome + "_cima", (a.x, a.y), (b.x, b.y), alt_baixo, PE - alt_baixo,
           [(t, lg, max(base - alt_baixo, 0), topo - alt_baixo) for (t, lg, base, topo) in aberturas if topo > alt_baixo], mat_cima, esp=0.02)


def _corte(abs_list, t0, t1):
    """Aberturas de uma parede que caem no trecho [t0, t1], com t a partir de t0."""
    return [(t - t0, lg, base, topo) for (t, lg, base, topo) in abs_list if t0 + lg / 2 <= t <= t1 - lg / 2]


def comodo_real(tema, nome, x0, x1, y0, y1, encosto, tec):
    """Móveis do cômodo: linha encostada na parede `encosto` ('esq', 'dir', 'fundo', 'frente') + coisas no meio.
    Os nomes começam pelo móvel (o jogo troca a caixa pelo modelo realista e acha as gavetas por eles)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    lado = -1 if encosto == "esq" else 1
    xw = (x0 if encosto == "esq" else x1)
    def linha(itens, ya, yb):
        ang = 1.5708 if lado < 0 else -1.5708
        y = ya + 0.3
        for k, (base, f, prof, larg) in enumerate(itens):
            if y + larg > yb - 0.3:
                break
            f("%s_%s%d" % (base, nome, k), xw - lado * (prof / 2 + 0.05), y + larg / 2, ang)
            y += larg + rnd.uniform(0.2, 0.45)
    if tema == "sala":
        linha([("sofa", lambda n, x, y, a: sofa(n, x, y, a, tec), 0.85, 2.0), ("estante", estante, 0.4, 1.2)], y0, y1)
        caixa("mesa_centro_" + nome + "-col", (cx - lado * 0.4, cy, 0.25), (1.1, 0.6, 0.45), "madeira")
        tapete("tapete_" + nome, cx - lado * 0.3, cy, 1.8, 2.4)
        tv("tv_" + nome, x0 + x1 - xw + lado * 0.35, cy, 1.5708 if lado > 0 else -1.5708)
        poltrona("poltrona_" + nome, cx - lado * 0.4, y1 - 0.7, 3.1416, rnd.choice(TECIDOS))
    elif tema == "cozinha":
        linha([("balcao", balcao, 0.6, 1.6), ("fogao", fogao, 0.6, 0.6), ("pia", pia, 0.6, 1.0), ("geladeira", lambda n, x, y, a: geladeira(n, x, y, a, rnd.random() < 0.25), 0.7, 0.75)], y0, y1)
        mesa("mesa_" + nome, cx - lado * 0.5, cy)
    elif tema == "quarto":
        linha([("criado", criado, 0.4, 0.45), ("cama", cama, 2.0, 1.1), ("criado", criado, 0.4, 0.45)], y0, y1)
        guarda_roupa("guarda_roupa_" + nome, x0 + x1 - xw + lado * 0.33, cy, 1.5708 if lado > 0 else -1.5708)
        tapete("tapete_" + nome, cx, cy, 1.2, 1.6)
    elif tema == "crianca":
        linha([("berco", berco, 0.7, 1.25), ("criado", criado, 0.4, 0.45)], y0, y1)
        guarda_roupa("guarda_roupa_" + nome, x0 + x1 - xw + lado * 0.33, cy, 1.5708 if lado > 0 else -1.5708)
    elif tema == "banheiro":
        linha([("vaso", vaso, 0.65, 0.5), ("pia", pia, 0.55, 1.0)], y0, y1)
        banheira("banheira_" + nome, x0 + x1 - xw + lado * 0.42, cy, 1.5708 if lado > 0 else -1.5708)
    bagunca("bag_" + nome, cx, cy, 4)


def casa_real(nome, w, d, semente, varanda):
    limpa()
    rnd.seed(semente)
    fachada = rnd.choice(["fachada_amarela", "fachada_azul", "fachada_tijolo", "fachada_madeira", "fachada_vermelha", "parede"])
    tec = rnd.choice(TECIDOS)
    vr = 1.8 if varanda else 0.0           # varanda dentro do lote, na frente
    fy, by = -d / 2 + vr, d / 2            # frente e fundo do corpo da casa
    hw = w / 2
    corr = 1.2
    xa = -hw + max(3.0, (w - corr) * 0.52)   # fim da coluna A (sala/cozinha)
    xb = xa + corr                           # começo da coluna B (quartos/banheiro)
    ym = fy + (by - fy) * rnd.uniform(0.5, 0.6)  # sala | cozinha
    dB = by - fy
    q1 = fy + dB * 0.42                     # quarto 1 | banheiro
    q2 = q1 + max(1.8, dB * 0.22)           # banheiro | quarto 2
    # paredes de fora: porta da frente na sala, porta dos fundos no fim do corredor
    pf = (xa - (-hw)) / 2                    # t da porta da frente (a partir do canto esquerdo)
    ext = {}
    jan_f = [(t, JAN_L, JAN_BASE, JAN_TOPO) for t in [(xb + hw) / 2 - (-hw)] if t > 0]
    ext["frente"] = ((-hw, fy), (hw, fy), [(pf, PORTA_L, 0, PORTA_A)] + jan_f)
    ext["dir"] = ((hw, fy), (hw, by), [((q1 - fy) / 2, JAN_L, JAN_BASE, JAN_TOPO), ((q2 + by) / 2 - fy, JAN_L, JAN_BASE, JAN_TOPO)])
    ext["fundo"] = ((hw, by), (-hw, by), [(hw - (xa + xb) / 2, PORTA_I, 0, PORTA_A), (hw - (-hw + xa) / 2, JAN_L, JAN_BASE + 0.25, JAN_TOPO)])
    ext["esq"] = ((-hw, by), (-hw, fy), [((by - ym) / 2, JAN_L, JAN_BASE, JAN_TOPO), (by - (fy + ym) / 2, JAN_L, JAN_BASE, JAN_TOPO)])
    for k, (a, b, ab) in ext.items():
        parede("ext_" + k, a, b, 0, PE, ab, fachada)
    marca_porta(-hw + pf, fy)
    for k, (a, b, ab) in ext.items():  # janelas com moldura (a porta da frente o jogo põe; a dos fundos fica só o batente)
        sinal = 1  # parede percorrida no sentido horário: dentro fica à esquerda
        for (t, lg, base, topo) in ab:
            if base > 0.5:
                janela_real("jan_%s_%d" % (k, int(t * 10)), a, b, t, 0, sinal, tec)
            elif k == "fundo":
                batente("batente_fundo", a, b, t, lg, topo, ESP)
    # paredes de dentro (com a passagem e o batente)
    intern = {
        "a_meio": ((-hw, ym), (xa, ym), [((xa + hw) / 2, PORTA_I, 0, PORTA_A)]),          # sala | cozinha
        "corr_a": ((xa, fy), (xa, by), [((ym - fy) / 2, 1.6, 0, PORTA_A), ((ym + by) / 2 - fy, PORTA_I, 0, PORTA_A)]),  # sala/cozinha | corredor
        "corr_b": ((xb, fy), (xb, by), [((q1 - fy) / 2, PORTA_I, 0, PORTA_A), ((q1 + q2) / 2 - fy, PORTA_I * 0.85, 0, PORTA_A),
                                        ((q2 + by) / 2 - fy, PORTA_I, 0, PORTA_A)]),
        "b_1": ((xb, q1), (hw, q1), []),
        "b_2": ((xb, q2), (hw, q2), []),
    }
    for k, (a, b, ab) in intern.items():
        parede("int_" + k, a, b, 0, PE, ab, "parede", esp=ESP_I)
        for (t, lg, base, topo) in ab:
            batente("batente_%s_%d" % (k, int(t * 10)), a, b, t, lg, topo, ESP_I)
    # cômodos: (nome, tema, x0, x1, y0, y1, pisos, revest. de baixo, de cima)
    papel = rnd.choice(["papel_1", "papel_2", "papel_3"])
    temas_q = ["quarto", rnd.choice(["quarto", "crianca"])]
    comodos = [("sala", "sala", -hw, xa, fy, ym, "piso_tabua", "lambri", papel),
               ("cozinha", "cozinha", -hw, xa, ym, by, "piso_ladrilho", "azulejo", "papel_2"),
               ("corredor", "", xa, xb, fy, by, "piso_tabua", "lambri", papel),
               ("quarto1", temas_q[0], xb, hw, fy, q1, "piso_tabua", "lambri", rnd.choice(["papel_1", "papel_3"])),
               ("banheiro", "banheiro", xb, hw, q1, q2, "piso_ladrilho", "azulejo", "azulejo"),
               ("quarto2", temas_q[1], xb, hw, q2, by, "piso_tabua", "lambri", rnd.choice(["papel_1", "papel_2"]))]
    # paredes com aberturas, para o revestimento de cada cômodo achar as suas (linha: x=const ou y=const)
    linhas = [(a, b, ab, ESP) for (a, b, ab) in ext.values()] + [(a, b, ab, ESP_I) for (a, b, ab) in intern.values()]
    def aberturas_em(p0, p1):
        """Aberturas no trecho p0->p1 de alguma parede que passe por ele (mesma reta)."""
        for (a, b, ab, e) in linhas:
            if abs(a[0] - b[0]) < 1e-3 and abs(p0[0] - a[0]) < 1e-3 and abs(p1[0] - a[0]) < 1e-3:  # vertical
                s = 1 if b[1] > a[1] else -1
                t0, t1 = (p0[1] - a[1]) * s, (p1[1] - a[1]) * s
                if t0 > t1:
                    t0, t1 = t1, t0
                    return [(t1 - t0 - t, lg, ba, to) for (t, lg, ba, to) in _corte(ab, t0, t1)], e
                return _corte(ab, t0, t1), e
            if abs(a[1] - b[1]) < 1e-3 and abs(p0[1] - a[1]) < 1e-3 and abs(p1[1] - a[1]) < 1e-3:  # horizontal
                s = 1 if b[0] > a[0] else -1
                t0, t1 = (p0[0] - a[0]) * s, (p1[0] - a[0]) * s
                if t0 > t1:
                    t0, t1 = t1, t0
                    return [(t1 - t0 - t, lg, ba, to) for (t, lg, ba, to) in _corte(ab, t0, t1)], e
                return _corte(ab, t0, t1), e
        return [], ESP
    for (cn, tema, x0, x1, y0, y1, pi, mb, mc) in comodos:
        caixa("piso_" + cn, ((x0 + x1) / 2, (y0 + y1) / 2, 0.075), (x1 - x0, y1 - y0, 0.03), pi)
        lados = [((x0, y0), (x1, y0), Vector((0, 1, 0))), ((x1, y0), (x1, y1), Vector((-1, 0, 0))),
                 ((x1, y1), (x0, y1), Vector((0, -1, 0))), ((x0, y1), (x0, y0), Vector((1, 0, 0)))]
        for i, (p0, p1, n) in enumerate(lados):
            ab, e = aberturas_em(p0, p1)
            alt_b = 1.6 if mb == "azulejo" else 1.0
            revestimento("rev_%s_%d" % (cn, i), p0, p1, ab, n * (e / 2 + 0.011), mb, mc if mc != "azulejo" else "azulejo", alt_b)
        if tema:
            # encosta na parede de lado sem passagem (coluna A: parede de fora à esquerda; coluna B: à direita)
            comodo_real(tema, cn, x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, "esq" if x0 < xa else "dir", tec)
    # chão, forro e telhado
    piso("chao", -hw, -d / 2, hw, d / 2, 0.06, "concreto", 0.06)
    piso("forro", -hw, fy, hw, by, PE, "forro", 0.05, col=False)
    telhado("telhado", w, d, PE, set() if rnd.random() < 0.7 else {(1, 1)}, "telha")
    if varanda:  # colunas e a cobertura da varanda (o telhado já cobre); degrau
        for x in (-hw + 0.3, -hw + pf * 2 + 0.2, hw - 0.3):
            caixa("coluna_%d-col" % int(x * 10), (x, -d / 2 + 0.3, PE / 2), (0.2, 0.2, PE), "batente")
        caixa("degrau-col", (-hw + pf, -d / 2 + 0.25, 0.08), (1.6, 0.5, 0.16), "concreto")
        caixa("piso_varanda", (0, -d / 2 + vr / 2, 0.08), (w, vr, 0.04), "piso_ladrilho")
    entulho("entulho_fora", (hw + 0.8, rnd.uniform(-d / 3, d / 3), 0), 3, 0.4, "concreto")
    # celular: acabamentos (revestimentos, batentes, janelas, pisos, tapetes, bagunça) numa peça só por casa
    acab = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith(("-col", "-colonly"))
            and o.name.startswith(("rev_", "batente", "jan_", "piso_", "tapete", "bag_")) and "caixa" not in o.name]
    if acab:
        junta(acab, "acabamento")
    exporta(nome)


def escada_incendio(hw, hd, n):
    """Escada de incêndio de metal no fundo (lado de fora, y > hd), em zigue-zague até o teto (n lances de 3 m).
    Rampas de colisão nos lances, patamares em cada andar. Devolve o x onde chega no teto (para abrir a mureta)."""
    xa, xb = -hw + 0.6, -hw + 5.2
    faixas = (hd + 0.75, hd + 1.85)
    pecas = []
    for k in range(n):
        y = faixas[k % 2]
        x0, x1 = (xa, xb) if k % 2 == 0 else (xb, xa)
        z0, z1 = k * PE, (k + 1) * PE
        comp = math.hypot(x1 - x0, z1 - z0)
        ang = math.atan2(z1 - z0, x1 - x0)
        degraus = int(PE / 0.2)
        for d in range(degraus):  # degraus de chapa
            t = (d + 0.5) / degraus
            pecas.append(caixa("deg", (x0 + (x1 - x0) * t, y, z0 + (z1 - z0) * t), (0.28, 1.0, 0.04), "metal"))
        for lado in (-0.52, 0.52):  # longarinas e corrimão
            pecas.append(caixa("lg", ((x0 + x1) / 2, y + lado, (z0 + z1) / 2), (comp, 0.05, 0.16), "ferrugem", (0, -ang, 0)))
            pecas.append(caixa("cr", ((x0 + x1) / 2, y + lado, (z0 + z1) / 2 + 0.9), (comp, 0.04, 0.04), "ferrugem", (0, -ang, 0)))
        caixa("lance_%d-colonly" % k, ((x0 + x1) / 2, y, (z0 + z1) / 2 - 0.05), (comp, 1.0, 0.1), "metal", (0, -ang, 0))
        # patamar no fim do lance, pegando as duas faixas (vira para o próximo)
        caixa("patamar_%d-col" % k, (x1 + (0.55 if x1 == xb else -0.55), hd + 1.3, z1 - 0.05), (1.3, 2.4, 0.1), "metal")
    junta(pecas, "escada_incendio")
    return xb + 0.55 if n % 2 == 1 else xa - 0.55


def loja(nome, w, d, semente, andares):
    """Loja de tijolo com vitrine arrebentada e porta de aço meio aberta; teto plano com mureta quebrada."""
    limpa()
    rnd.seed(semente)
    m = "tijolo"
    hw, hd = w / 2, d / 2
    vit = min(w - 3.0, 6.0)
    parede("ext_0", (-hw, -hd), (hw, -hd), 0, PE, [(w / 2, vit, 0, 2.6)], m)
    for i, (a, b, comp) in enumerate([((hw, -hd), (hw, hd), d), ((hw, hd), (-hw, hd), w), ((-hw, hd), (-hw, -hd), d)]):
        ab = [(comp / 2, PORTA_L, 0, PORTA_A)] if i == 1 else janelas(comp, 1)
        parede("ext_%d" % (i + 1), a, b, 0, PE, ab, m, rnd.randint(0, 1))
    # porta de aço enrolada no alto da vitrine (só enfeite: dá para passar por baixo)
    caixa("porta_aco", (0, -hd - 0.12, 2.25), (vit, 0.06, 0.7), "metal")
    caixa("porta_aco_torta", (vit / 2 - 1.0, -hd - 0.25, 1.4), (1.8, 0.05, 1.3), "metal", (0.5, 0.2, 0))
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    for k, x in enumerate((-w / 4, w / 4)):  # gôndolas de metal, uma tombada
        for q in range(2):
            estante("gondola_%d_%d" % (k, q), x, -hd / 3 + q * 1.3, 0, caida=(k + q) == 1, larg=1.2, cor="metal")
    balcao("caixa", -hw + 1.2, -hd + 1.6, 0, 1.6)
    if andares == 2:
        bx = (hw - 1.5, hd - 4.2, hw - ESP, hd - ESP)
        piso("laje1", -hw, -hd, hw, hd, PE, "concreto", buraco=bx)
        escada("escada", hw - 0.85, hd - 4.0, hd - 0.4, 0.06, PE)
        caixa_paredes(w, d, PE, PE, m, False, 3, [1, 0, 1, 2], 0.3, False, "ext1")
    topo = andares * PE
    piso("teto", -hw, -hd, hw, hd, topo, "concreto",
         buraco=(rnd.uniform(-hw + 1, 0), rnd.uniform(-hd + 1, 0), rnd.uniform(1, hw - 1), rnd.uniform(1, hd - 1)))
    chega = escada_incendio(hw, hd, andares)  # sobe pelo fundo; a mureta abre onde ela chega
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("mureta_%d" % i, a, b, topo, 0.8, [(hw - chega, 1.4, 0, 0.8)] if i == 2 else [], m, 0 if i == 2 else rnd.randint(0, 2))
    caixa("placa", (0, -hd - 0.15, topo - 0.35), (vit + 1.0, 0.08, 0.6), "metal", (0, 0, rnd.uniform(-0.08, 0.08)))
    entulho("entulho", (rnd.uniform(-hw / 2, hw / 2), rnd.uniform(-hd / 2, hd / 2), 0.06), 7, 0.5)
    entulho("vidro_e_tralha", (0, -hd - 1.0, 0), 4, 0.3, "metal")
    exporta(nome)


def predio(nome, w, d, semente):
    """Prédio de 3 andares com um canto desabado (buraco grande com borda quebrada)."""
    limpa()
    rnd.seed(semente)
    m = rnd.choice(["tijolo", "parede"])
    for k in range(3):
        caixa_paredes(w, d, k * PE, PE, m, k == 0, 4, [0, 1, 1, 1] if k == 0 else [1, 1, 2, 1], 0.35 if k == 0 else 0.1,
                      k == 0, "ext%d" % k)
    piso("chao", -w / 2, -d / 2, w / 2, d / 2, 0.06, "concreto", 0.06)
    mobilia(w, d, divisorias(w, d, 0, m))
    bx = (w / 2 - 1.5, d / 2 - 4.2, w / 2 - ESP, d / 2 - ESP)
    for k in (1, 2):
        piso("laje%d" % k, -w / 2, -d / 2, w / 2, d / 2, k * PE, "concreto", buraco=bx)
        escada("escada%d" % k, w / 2 - 0.85, d / 2 - 4.0, d / 2 - 0.4, (k - 1) * PE + 0.06, k * PE)
    piso("teto", -w / 2, -d / 2, w / 2, d / 2, 3 * PE, "concreto")
    escada_incendio(w / 2, d / 2, 3)
    # canto da frente à esquerda desabou do 2º andar para cima
    for o in [o for o in bpy.data.objects if o.name.startswith(("ext1", "ext2", "laje2", "teto")) and o.type == "MESH"]:
        if o.name.endswith("-colonly"):
            continue
        morde(o, (-w / 2, -d / 2, 2 * PE + 1.5), 3.2)
    entulho("desabado", (-w / 2 + 1.0, -d / 2 - 0.8, 0), 10, 0.7)
    entulho("entulho", (rnd.uniform(-w / 4, w / 4), rnd.uniform(-d / 4, d / 4), 0.06), 6, 0.45)
    exporta(nome)


# ----- veículos e marcos (frente do veículo em +Z no Godot = -Y aqui) -----

def chanfra(o, larg=0.08):
    md = o.modifiers.new("chanfro", "BEVEL")
    md.width = larg
    md.segments = 2
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=md.name)


def cabine(nome, y0, y1, z0, z1, larg, recua, m):
    """Cabine com vidro inclinado: caixa com o topo mais curto que a base."""
    me = bpy.data.meshes.new(nome)
    hx = larg / 2
    v = [(-hx, y0, z0), (hx, y0, z0), (hx, y1, z0), (-hx, y1, z0),
         (-hx * 0.92, y0 + recua[0], z1), (hx * 0.92, y0 + recua[0], z1), (hx * 0.92, y1 - recua[1], z1), (-hx * 0.92, y1 - recua[1], z1)]
    f = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me.from_pydata(v, [], f)
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(mat(m))
    return o


def rodas(xs, ys, raio, larg, sem=()):
    out = []
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            if (i, j) in sem:  # roubaram a roda: o carro fica caído para esse lado
                continue
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=raio, depth=larg, location=(x, y, raio), rotation=(0, 1.5708, 0))
            o = bpy.context.object
            o.data.materials.append(mat("pneu"))
            out.append(o)
    return out


def carro(nome, semente, queimado=False):
    limpa()
    rnd.seed(semente)
    lat = "queimado" if queimado else "lataria"
    corpo = caixa("corpo", (0, 0, 0.62), (1.8, 4.4, 0.62), lat)
    chanfra(corpo, 0.12)
    cab = cabine("cabine", -0.9, 1.1, 0.93, 1.42, 1.72, (0.65, 0.5), "vidro" if not queimado else "queimado")
    chanfra(cab, 0.04)
    pecas = [corpo, cab]
    if not queimado:
        pecas += rodas((-0.86, 0.86), (-1.4, 1.35), 0.33, 0.24)
        caixa("capo_amassado", (0.2, -1.7, 0.98), (1.2, 0.8, 0.06), "lataria", (0.25, 0.1, 0.05))
    else:
        pecas += rodas((-0.86, 0.86), (-1.4, 1.35), 0.2, 0.2)  # só o aro
        for o in pecas[:1]:
            o.location.z -= 0.15
    junta(pecas, nome)
    caixa(nome + "_col-colonly", (0, 0, 0.75), (1.8, 4.4, 1.5), lat)
    exporta(nome)


def van(nome, semente):
    limpa()
    rnd.seed(semente)
    corpo = caixa("corpo", (0, 0.4, 1.25), (2.0, 4.6, 1.9), "lataria")
    chanfra(corpo, 0.1)
    frente = cabine("frente", -2.7, -1.85, 0.4, 2.1, 2.0, (0.55, 0.0), "lataria")
    vid = caixa("vidro", (0, -2.35, 1.75), (1.9, 0.05, 0.6), "vidro", (-0.55, 0, 0))
    pecas = [corpo, frente, vid] + rodas((-0.95, 0.95), (-2.0, 1.8), 0.36, 0.26, sem={(1, 1)})
    o = junta(pecas, nome)
    o.rotation_euler = (0, 0.06, 0)  # caída para o lado sem roda
    caixa(nome + "_col-colonly", (0, -0.1, 1.15), (2.0, 5.5, 2.3), "lataria")
    exporta(nome)


def onibus(nome, semente):
    """Ônibus escolar tombado de lado (fecha a rua)."""
    limpa()
    rnd.seed(semente)
    corpo = caixa("corpo", (0, 0, 1.4), (2.5, 10.5, 2.6), "ferrugem")
    chanfra(corpo, 0.15)
    pecas = [corpo]
    for k in range(7):
        pecas.append(caixa("jan", (1.26, -4.0 + k * 1.3, 1.9), (0.04, 1.0, 0.75), "vidro"))
    pecas += rodas((-1.2, 1.2), (-3.6, 3.4), 0.5, 0.3)
    o = junta(pecas, nome)
    o.rotation_euler = (0, 1.5708, 0)
    o.location = (1.3, 0, 1.25)
    caixa(nome + "_col-colonly", (0, 0, 1.25), (2.6, 10.6, 2.5), "ferrugem")
    exporta(nome)


def caixa_dagua(nome):
    limpa()
    pernas = []
    for sx in (-2, 2):
        for sy in (-2, 2):
            pernas.append(caixa("perna", (sx, sy, 9), (0.3, 0.3, 18), "ferrugem", (sy * 0.02, -sx * 0.02, 0)))
    for z in (5, 11):  # travessas
        for sx in (-2, 2):
            pernas.append(caixa("tr", (sx, 0, z), (0.12, 4.0, 0.12), "ferrugem"))
            pernas.append(caixa("tr", (0, sx, z), (4.0, 0.12, 0.12), "ferrugem"))
    junta(pernas, nome + "_pernas-col")
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=3.6, depth=5.0, location=(0, 0, 20.5))
    t = bpy.context.object
    t.name = nome + "_tanque"
    t.data.materials.append(mat("metal"))
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=3.8, depth=1.6, location=(0, 0, 23.8))
    c = bpy.context.object
    c.data.materials.append(mat("ferrugem"))
    morde(t, (3.4, 0, 21.5), 1.2)  # rombo
    escada("escadinha", 2.15, -0.5, 0.5, 0, 0.1, 0.4)  # só o pé da escada (enfeite)
    exporta(nome)


# ----- marcos que se veem de longe (31/10, dono: "referência de grandes jogos de zumbi no mapa") -----

def antena(nome):
    """Torre de rádio de treliça (~36 m) com luz vermelha no topo e a casinha do transmissor arrombada."""
    limpa()
    rnd.seed(61)
    alt = 36.0
    p = []
    for k in range(12):  # 12 lances, afinando
        z0 = k * 3.0
        a = 1.6 - k * 0.1
        b = 1.6 - (k + 1) * 0.1
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(caixa("m", (sx * (a + b) / 2, sy * (a + b) / 2, z0 + 1.5), (0.12, 0.12, 3.05), "ferrugem"))
        for sx in (-1, 1):
            p.append(caixa("x", (sx * a, 0, z0 + 1.5), (0.06, 2 * a * 1.4, 0.06), "ferrugem", (0.75, 0, 0)))
            p.append(caixa("x", (0, sx * a, z0 + 1.5), (2 * a * 1.4, 0.06, 0.06), "ferrugem", (0, 0.75, 0)))
    junta(p, nome + "_torre")
    caixa(nome + "_pe-col", (0, 0, 1.5), (3.4, 3.4, 3.0), "ferrugem")  # o pé (não dá para atravessar a treliça)
    caixa(nome + "_luz", (0, 0, alt + 0.4), (0.4, 0.4, 0.5), "vermelho")
    caixa(nome + "_prato", (0.9, 0, alt - 6), (0.1, 1.4, 1.4), "branco", (0, 0.3, 0))
    cas = [caixa("c", (6, 0, 1.4), (4.0, 3.0, 2.8), "concreto"), caixa("c", (6, 0, 2.9), (4.4, 3.4, 0.2), "metal")]
    junta(cas, nome + "_casinha-col")
    for k in range(6):  # cabos e entulho em volta
        caixa("%s_cabo%d" % (nome, k), (rnd.uniform(-5, 9), rnd.uniform(-5, 5), 0.08), (rnd.uniform(1, 3), 0.05, 0.05), "pneu",
              (0, 0, rnd.uniform(0, 6.28)))
    exporta(nome)


def helicoptero(nome):
    """Helicóptero militar caído de lado, cauda quebrada, pás tortas, caixas espalhadas."""
    limpa()
    rnd.seed(62)
    corpo = [caixa("h", (0, 0, 1.3), (2.4, 6.0, 2.4), "militar"), caixa("h", (0, -3.4, 1.0), (2.0, 1.2, 1.8), "vidro", (0.3, 0, 0)),
             caixa("h", (0, 1.2, 2.7), (1.4, 2.4, 0.7), "militar")]
    o = junta(corpo, nome + "_corpo-col")
    o.rotation_euler = (0, 1.2, 0.2)  # tombado de lado
    o.location = (0, 0, 0.3)
    cauda = junta([caixa("c", (0, 0, 0), (0.6, 5.0, 0.6), "militar"), caixa("c", (0, 2.4, 0.8), (0.15, 1.0, 1.6), "militar")], nome + "_cauda-col")
    cauda.location = (2.5, 7.5, 0.4)
    cauda.rotation_euler = (0, 0.3, 0.6)
    for k in range(4):  # pás tortas no chão
        caixa("%s_pa%d" % (nome, k), (rnd.uniform(-6, 6), rnd.uniform(-6, 8), 0.1), (0.35, 6.0, 0.08), "metal",
              (rnd.uniform(-0.2, 0.2), 0, rnd.uniform(0, 6.28)))
    for k in range(5):  # caixas de suprimento que voaram
        caixa("%s_caixa%d-col" % (nome, k), (rnd.uniform(-5, 5), rnd.uniform(-6, 6), 0.35), (0.9, 0.6, 0.6), "militar",
              (0, 0, rnd.uniform(0, 6.28)))
    entulho(nome + "_ent", (0, 2, 0), 10, 0.5, "queimado")
    exporta(nome)


def quarentena(nome):
    """Posto de quarentena do exército abandonado: cerca com portão, tendas, sacos de areia, guarita e caminhão."""
    limpa()
    rnd.seed(63)
    lado = 22.0
    for k, (a, b) in enumerate([((-lado / 2, -lado / 2), (lado / 2, -lado / 2)), ((lado / 2, -lado / 2), (lado / 2, lado / 2)),
                                ((lado / 2, lado / 2), (-lado / 2, lado / 2)), ((-lado / 2, lado / 2), (-lado / 2, -lado / 2))]):
        n = int(lado / 2.5)
        for i in range(n + 1):
            if k == 0 and abs(i - n / 2) < 1.6:
                continue  # portão aberto na frente
            x = a[0] + (b[0] - a[0]) * i / n
            y = a[1] + (b[1] - a[1]) * i / n
            caixa("%s_poste%d_%d" % (nome, k, i), (x, y, 1.25), (0.08, 0.08, 2.5), "metal")
        caixa("%s_tela%d-col" % (nome, k), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 1.2),
              (abs(b[0] - a[0]) + 0.05 if a[1] == b[1] else 0.04, abs(b[1] - a[1]) + 0.05 if a[0] == b[0] else 0.04, 2.4), "metal")
    for i, t in enumerate([(-6, 3), (0, 5), (6, 3), (-5, -4)]):  # tendas de lona
        tenda = [caixa("t", (0, 0, 1.0), (4.0, 3.0, 2.0), "lona"), caixa("t", (0, 0, 2.2), (4.2, 3.2, 0.4), "lona")]
        o = junta(tenda, "%s_tenda%d-col" % (nome, i))
        o.location = (t[0], t[1], 0)
        o.rotation_euler = (0, 0, rnd.uniform(-0.2, 0.2))
    for i in range(10):  # sacos de areia no portão
        caixa("%s_saco%d-col" % (nome, i), (-3.5 + i * 0.8 if i < 5 else 0.5 + (i - 5) * 0.8, -lado / 2 - 1.0, 0.25 + (i % 2) * 0.3),
              (0.75, 0.45, 0.3), "areia")
    caixa(nome + "_guarita-col", (lado / 2 - 2, -lado / 2 + 2, 1.3), (2.2, 2.2, 2.6), "militar")
    cam = [caixa("k", (0, 0, 1.0), (2.4, 6.5, 1.4), "militar"), caixa("k", (0, -2.6, 1.9), (2.3, 1.6, 1.0), "militar"),
           caixa("k", (0, 1.0, 2.2), (2.5, 4.4, 0.2), "lona")]
    o = junta(cam + rodas((-1.1, 1.1), (-2.4, 2.2), 0.45, 0.35), nome + "_caminhao-col")
    o.location = (7, -5, 0)
    o.rotation_euler = (0, 0, 0.4)
    for k in range(6):  # macas e caixas de remédio largadas
        caixa("%s_maca%d" % (nome, k), (rnd.uniform(-8, 8), rnd.uniform(-8, 8), 0.45), (0.7, 1.9, 0.08), "branco", (0, 0, rnd.uniform(0, 6.28)))
    exporta(nome)


def posto(nome):
    """Posto de gasolina abandonado: cobertura com luminoso caído, bombas, lojinha com vitrine tapada e um carro largado."""
    limpa()
    rnd.seed(64)
    junta([caixa("c", (0, 0, 5.2), (12.0, 8.0, 0.6), "branco"), caixa("c", (0, -4.05, 5.2), (12.0, 0.1, 0.7), "vermelho")],
          nome + "_cobertura")
    for sx in (-4, 4):
        caixa("%s_pilar%d-col" % (nome, sx), (sx, 0, 2.5), (0.5, 0.5, 5.0), "branco")
    for sx in (-2.5, 2.5):
        for sy in (-1.5, 1.5):
            bomba = [caixa("b", (0, 0, 0.8), (0.6, 0.4, 1.6), "vermelho"), caixa("b", (0, -0.21, 1.2), (0.4, 0.02, 0.3), "vidro")]
            o = junta(bomba, "%s_bomba%d%d-col" % (nome, int(sx), int(sy)))
            o.location = (sx, sy, 0)
    caixa(nome + "_ilha-col", (0, 0, 0.1), (7.0, 4.5, 0.2), "concreto")
    loja = [caixa("l", (0, 9.5, 1.6), (9.0, 5.0, 3.2), "parede"), caixa("l", (0, 6.99, 1.3), (6.0, 0.05, 1.8), "vidro"),
            caixa("l", (0, 9.5, 3.3), (9.4, 5.4, 0.2), "concreto")]
    junta(loja, nome + "_loja-col")
    for k in range(5):
        caixa("%s_tabua%d" % (nome, k), (rnd.uniform(-2.8, 2.8), 6.95, rnd.uniform(0.6, 2.0)), (1.6, 0.04, 0.18), "tabua",
              (0, rnd.uniform(-0.4, 0.4), 0))
    lum = [caixa("p", (0, 0, 3.5), (0.3, 0.3, 7.0), "metal"), caixa("p", (0, 0, 7.4), (2.2, 0.3, 1.6), "vermelho")]
    o = junta(lum, nome + "_luminoso")
    o.location = (-7.5, -6.0, 0)
    o.rotation_euler = (0.25, 0.1, 0)  # torto
    exporta(nome)


def taco_pregos(nome):
    """Taco de madeira (0,86 m, eixo +Z) com pregos atravessados na ponta e arame farpado enrolado."""
    limpa()
    rnd.seed(71)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.022, radius2=0.042, depth=0.78, location=(0, 0, 0.47))
    t = bpy.context.object
    t.name = nome + "_madeira"
    t.data.materials.append(mat("madeira"))
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.028, depth=0.08, location=(0, 0, 0.04))
    c = bpy.context.object
    c.data.materials.append(mat("pano"))  # empunhadura de fita
    pregos = []
    for k in range(9):
        z = rnd.uniform(0.62, 0.84)
        a = rnd.uniform(0, 6.28)
        pregos.append(caixa("p", (math.cos(a) * 0.045, math.sin(a) * 0.045, z), (0.006, 0.006, 0.09), "metal",
                            (math.sin(a) * 1.5708, -math.cos(a) * 1.5708, 0)))
    junta(pregos, nome + "_pregos")
    arame = []
    for k in range(28):  # espiral de arame com farpas
        a = k * 0.55
        z = 0.5 + k * 0.012
        r = 0.035 + (z - 0.5) * 0.02
        arame.append(caixa("a", (math.cos(a) * r, math.sin(a) * r, z), (0.05, 0.004, 0.004), "ferrugem", (0, 0, a + 1.5708)))
        if k % 3 == 0:
            arame.append(caixa("f", (math.cos(a) * (r + 0.008), math.sin(a) * (r + 0.008), z), (0.004, 0.02, 0.004), "ferrugem", (0, 0, a)))
    junta(arame, nome + "_arame")
    bpy.ops.export_scene.gltf(filepath="%s/%s.glb" % (SAIDA, nome), export_format="GLB", export_apply=True,
                              export_materials="EXPORT", export_extras=False, export_yup=True)


def galpao(nome, w, d, semente):
    """Galpão de metal alto, portão de enrolar aberto pela metade, telhado com placas faltando."""
    limpa()
    rnd.seed(semente)
    hw, hd, alt = w / 2, d / 2, 6.0
    parede("ext_0", (-hw, -hd), (hw, -hd), 0, alt, [(w / 2, 5.0, 0, 4.5), (w / 2 + 5.0, PORTA_L, 0, PORTA_A)], "metal")
    for i, (a, b, comp) in enumerate([((hw, -hd), (hw, hd), d), ((hw, hd), (-hw, hd), w), ((-hw, hd), (-hw, -hd), d)]):
        ab = [(comp / 2, PORTA_L, 0, PORTA_A)] if i == 1 else [(t, 2.0, 4.0, 5.2) for t in (comp * 0.25, comp * 0.5, comp * 0.75)]
        parede("ext_%d" % (i + 1), a, b, 0, alt, ab, "metal", rnd.randint(0, 2))
    caixa("portao", (0, -hd - 0.1, 3.6), (5.0, 0.08, 1.8), "ferrugem")
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    n = int(w / 3)
    pl = []
    for k in range(n):
        if rnd.random() < 0.3:
            continue
        pl.append(caixa("tp", (-hw + 1.5 + k * 3, 0, alt + 0.4), (3.0, d + 0.6, 0.05), "ferrugem", (0, rnd.uniform(-0.03, 0.03), 0)))
    junta(pl, "telhado")
    for k in range(3):  # caixas e tambores
        caixa("engradado-col", (rnd.uniform(-hw + 2, hw - 2), rnd.uniform(-hd + 2, hd - 4), 0.6), (1.2, 1.2, 1.2), "madeira")
    entulho("entulho", (rnd.uniform(-hw / 2, hw / 2), rnd.uniform(-hd / 2, hd / 2), 0.06), 6, 0.5)
    exporta(nome)


def marca(nome, x, y, z=0.06):
    """Ponto marcado (Empty) que o jogo lê: zumbi_k, zumbi_arm_k (com arma de fogo), bau_k."""
    e = bpy.data.objects.new(nome, None)
    bpy.context.collection.objects.link(e)
    e.location = (x, y, z)


def grade(nome, a, b, alt=2.6, vao=None):
    """Grade de cela de a até b (barras de ferro); vao = (t, largura) fica aberto (porta da cela arrombada)."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    comp = (b - a).length
    barras = []
    t = 0.06
    while t < comp:
        if not (vao and abs(t - vao[0]) < vao[1] / 2):
            c = a + u * t
            barras.append(caixa("g", (c.x, c.y, alt / 2), (0.04, 0.04, alt), "metal"))
        t += 0.16
    c = a + u * (comp / 2)
    barras.append(caixa("g", (c.x, c.y, alt - 0.05), (comp, 0.06, 0.08), "metal", (0, 0, math.atan2(u.y, u.x))))
    junta(barras, nome)
    # colisão: placas finas nos trechos fechados
    pedacos = [(0, comp)] if not vao else [(0, vao[0] - vao[1] / 2), (vao[0] + vao[1] / 2, comp)]
    for k, (t0, t1) in enumerate(pedacos):
        if t1 - t0 > 0.05:
            c = a + u * ((t0 + t1) / 2)
            caixa("%s_%d-colonly" % (nome, k), (c.x, c.y, alt / 2), (t1 - t0, 0.08, alt), "metal", (0, 0, math.atan2(u.y, u.x)))


def delegacia(nome, w, d, semente):
    """Raid: delegacia tomada. Recepção com balcão, corredor, 3 celas com grade (fundo à esquerda), arsenal (fundo à
    direita, estantes de metal), escritório; sacos de areia e placa na frente. Marca zumbis e baús para o jogo."""
    limpa()
    rnd.seed(semente)
    hw, hd = w / 2, d / 2
    m = "parede"
    # externas: frente com porta dupla e janelas gradeadas
    parede("ext_0", (-hw, -hd), (hw, -hd), 0, PE + 0.6, [(hw, 2.2, 0, 2.4), (hw - 5, JAN_L, JAN_BASE, JAN_TOPO), (hw + 5, JAN_L, JAN_BASE, JAN_TOPO)], m)
    parede("ext_1", (hw, -hd), (hw, hd), 0, PE + 0.6, janelas(d, 3), m, 1)
    parede("ext_2", (hw, hd), (-hw, hd), 0, PE + 0.6, [(w / 2 + 4, PORTA_L, 0, PORTA_A)], m)
    parede("ext_3", (-hw, hd), (-hw, -hd), 0, PE + 0.6, janelas(d, 3), m, 2)
    for x in (-5, 5):  # grades nas janelas da frente
        for k in range(6):
            caixa("grade_jan", (x - 0.45 + k * 0.18, -hd - 0.15, (JAN_BASE + JAN_TOPO) / 2), (0.03, 0.03, JAN_TOPO - JAN_BASE), "metal")
    piso("chao", -hw, -hd, hw, hd, 0.06, "concreto", 0.06)
    piso("teto", -hw, -hd, hw, hd, PE + 0.6, "concreto", buraco=(-2.0, 0.5, 1.5, 3.5))
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("mureta_%d" % i, a, b, PE + 0.6, 0.7, [], m, rnd.randint(0, 1))
    # recepção: parede com vão separando a frente (4,5 m) do resto; balcão
    yr = -hd + 4.5
    parede("int_recepcao", (-hw + ESP, yr), (hw - ESP, yr), 0, PE, [(hw - 3, 1.4, 0, 2.2), (hw + 4, 1.2, 0, 2.2)], m)
    balcao("balcao", 0, yr - 1.4, 0, 4.0)
    estante("arquivo", hw - 1.0, -hd + 0.6, 3.1416, larg=1.0, cor="metal")
    # celas: fundo à esquerda, 3 de 2,6 m com grade; a do meio arrombada
    yc = hd - 3.2
    for k in range(4):
        x = -hw + ESP + k * 2.6
        parede("cela_div_%d" % k, (x, yc), (x, hd - ESP), 0, PE, [], m)
    grade("grade_celas", (-hw + ESP, yc), (-hw + ESP + 7.8, yc), vao=(3.9, 1.0))
    for k in range(3):
        cama("catre_%d" % k, -hw + 1.5 + k * 2.6, hd - 1.3, 0)
    # arsenal: fundo à direita, parede com porta, estantes de metal e baús
    xa = hw - 5.5
    parede("int_arsenal", (xa, yc - 0.6), (xa, hd - ESP), 0, PE, [(1.4, 1.1, 0, 2.2)], m)
    parede("int_arsenal2", (xa, yc - 0.6), (hw - ESP, yc - 0.6), 0, PE, [], m)
    for k in range(3):
        estante("arma_%d" % k, xa + 1.0 + k * 1.4, hd - 0.5, 3.1416, caida=k == 1, larg=1.2, cor="metal")
    # escritório no meio: mesas e arquivos
    mesa("mesa_a", -2.5, -1.0)
    mesa("mesa_b", 2.5, 0.5)
    estante("arquivo2", -hw + 0.4, -1.0, -1.5708, caida=True, larg=1.0, cor="metal")
    entulho("entulho", (rnd.uniform(-3, 3), rnd.uniform(-2, 2), 0.06), 6, 0.4, "papelao")
    # frente: sacos de areia em meia-lua e placa
    for k in range(9):
        a = math.pi * (0.15 + 0.7 * k / 8)
        x, y = math.cos(a) * 4.2, -hd - 3.2 + math.sin(a) * -1.6
        for z in range(2 if k not in (4,) else 0):
            caixa("saco", (x, y, 0.15 + z * 0.28), (0.75, 0.4, 0.28), "pano", (0, 0, a + 1.5708 + rnd.uniform(-0.2, 0.2)))
    caixa("placa", (0, -hd - 0.12, PE + 0.15), (6.0, 0.1, 0.7), "metal")
    bpy.ops.object.text_add(location=(0, -hd - 0.18, PE + 0.15), rotation=(1.5708, 0, 0))
    t = bpy.context.object
    t.data.body = "DELEGACIA"
    t.data.size = 0.55
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.extrude = 0.02
    bpy.ops.object.convert(target="MESH")
    t.name = "letreiro"
    t.data.materials.clear()
    t.data.materials.append(mat("branco"))
    marca_porta(hw, -hd)
    # zumbis (os _arm_ atiram) e baús da raid
    pts = [(-4, -3.5, 0), (3, -3.0, 1), (-1, 0, 0), (4, 1.5, 1), (-6, 0.5, 0), (6, -1, 0), (-5.6, hd - 1.5, 0),
           (-0.4, hd - 1.5, 0), (hw - 3, hd - 1.5, 1), (hw - 2, yc - 2, 1), (0, -hd - 2.0, 0), (-3, -hd - 5, 0)]
    for k, (x, y, arm) in enumerate(pts):
        marca(("zumbi_arm_%d" if arm else "zumbi_%d") % k, x, y)
    marca("bau_0", hw - 1.2, hd - 1.6)
    marca("bau_1", xa + 1.2, yc + 0.6)
    marca("bau_2", -hw + 4.0, hd - 1.0)
    exporta(nome)


def arame(nome, x0, x1, y, z, raio=0.35):
    """Rolo de arame farpado (hélice fina) de x0 a x1."""
    voltas = int(abs(x1 - x0) / 0.25)
    pts = []
    for k in range(voltas * 12 + 1):
        t = k / 12.0
        a = t * 2 * math.pi
        pts.append((x0 + (x1 - x0) * t / voltas, y + math.cos(a) * raio, z + raio + math.sin(a) * raio))
    cu = bpy.data.curves.new(nome, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.008
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1)
    o = bpy.data.objects.new(nome, cu)
    bpy.context.collection.objects.link(o)
    cu.materials.append(mat("ferrugem"))
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return o


def barricada_sobr(nome, semente):
    """Barricada que um sobrevivente montou com o que achou (6 m, frente em +Z no jogo = -Y aqui): sofá em pé, mesa
    virada, geladeira deitada, tábuas cruzadas, pneus, sacos de areia e arame farpado na frente. Vão de 1 m na ponta."""
    limpa()
    rnd.seed(semente)
    sofa("sofa", -2.0, 0.0, 0.0)
    bpy.data.objects["sofa-col"].rotation_euler = (1.45, 0, 0.1)
    bpy.data.objects["sofa-col"].location.z = 0.45
    mesa("mesa", 0.2, 0.1)
    for o in bpy.data.objects:
        if o.name.startswith("mesa"):
            o.rotation_euler.x = 1.57
            o.location.z = 0.4
    geladeira("geladeira", 1.6, 0.2, 1.5708, True)
    for k in range(5):  # tábuas pregadas em pé
        caixa("tabua_%d" % k, (-2.6 + k * 1.1, -0.35, 0.9), (0.18, 0.04, 1.8), "tabua", (0, rnd.uniform(-0.5, 0.5), 0))
    for k in range(3):  # pneus
        bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.12, location=(rnd.uniform(-2.5, 2.0), 0.6, 0.12 + k * 0.24))
        bpy.context.object.data.materials.append(mat("pneu"))
    for k in range(6):
        caixa("saco_%d" % k, (-2.4 + k * 0.85, -0.7, 0.15 + (k % 2) * 0.28), (0.75, 0.4, 0.28), "pano", (0, 0, rnd.uniform(-0.2, 0.2)))
    arame("arame", -2.9, 1.9, -1.4, 0.0)
    caixa("bloqueio-colonly", (-0.4, 0, 0.9), (5.2, 1.4, 1.8), "madeira")
    exporta(nome)


if __name__ == "__main__":
    import os
    os.makedirs(SAIDA, exist_ok=True)
    SO = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []  # nomes depois da pasta: só esses
    TODOS = [
        ("casa_r1", lambda: casa_real("casa_r1", 9.0, 7.0, 11, False)),
        ("casa_r2", lambda: casa_real("casa_r2", 11.0, 8.0, 12, True)),
        ("casa_r3", lambda: casa_real("casa_r3", 7.5, 9.0, 13, True)),
        ("casa_r4", lambda: casa("casa_r4", 10.0, 8.0, 14, "queimada")),
        ("casa_r5", lambda: casa_real("casa_r5", 12.5, 9.0, 15, True)),
        ("casa_r6", lambda: casa("casa_r6", 8.0, 6.5, 16, "queimada")),
        # 31/10: mais casas (cada uma com cômodos sorteados), para não repetir tanto
        ("casa_r7", lambda: casa_real("casa_r7", 9.5, 7.5, 17, False)),
        ("casa_r8", lambda: casa_real("casa_r8", 10.5, 8.5, 18, True)),
        ("casa_r9", lambda: casa_real("casa_r9", 8.5, 7.0, 19, False)),
        ("casa_r10", lambda: casa_real("casa_r10", 11.5, 9.0, 20, True)),
        ("casa_r11", lambda: casa_real("casa_r11", 13.0, 9.5, 23, True)),
        ("casa_r12", lambda: casa_real("casa_r12", 8.0, 7.5, 24, False)),
        ("casa_r13", lambda: casa_real("casa_r13", 7.5, 6.5, 25, False)),  # pequenas: lotes que só cabiam a queimada
        ("casa_r14", lambda: casa_real("casa_r14", 7.0, 6.0, 26, False)),
        ("loja_r1", lambda: loja("loja_r1", 12.0, 10.0, 21, 1)),
        ("loja_r2", lambda: loja("loja_r2", 16.0, 12.0, 22, 2)),
        ("predio_r1", lambda: predio("predio_r1", 18.0, 12.0, 31)),
        ("galpao_r1", lambda: galpao("galpao_r1", 18.0, 12.0, 41)),
        ("galpao_r2", lambda: galpao("galpao_r2", 16.0, 12.0, 42)),
        ("carro_r1", lambda: carro("carro_r1", 51)),
        ("carro_r2", lambda: carro("carro_r2", 52, queimado=True)),
        ("van_r1", lambda: van("van_r1", 53)),
        ("onibus_r1", lambda: onibus("onibus_r1", 54)),
        ("caixa_dagua", lambda: caixa_dagua("caixa_dagua")),
        ("antena", lambda: antena("antena")),
        ("taco_pregos", lambda: taco_pregos("taco_pregos")),
        ("helicoptero", lambda: helicoptero("helicoptero")),
        ("quarentena", lambda: quarentena("quarentena")),
        ("posto", lambda: posto("posto")),
        ("barricada_sobr", lambda: barricada_sobr("barricada_sobr", 71)),
        ("delegacia", lambda: delegacia("delegacia", 18.0, 13.0, 61)),
    ]
    for nome, faz in TODOS:
        if not SO or nome in SO:
            faz()
    print("RUINAS_OK")
