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
}
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


def parede(nome, a, b, z0, alt, aberturas, m, quebras=0, cor_topo=None):
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
        pecas.append(caixa("p", (c.x, c.y, z0 + (zb + zt) * 0.5), (t1 - t0, ESP, zt - zb), m, (0, 0, ang)))

    t = 0.0
    for (tc, lg, base, topo) in sorted(aberturas):
        t0, t1 = tc - lg * 0.5, tc + lg * 0.5
        peca(t, t0, 0, alt)
        peca(t0, t1, 0, base)
        peca(t0, t1, topo, alt)
        t = t1
    peca(t, comp, 0, alt)
    o = junta(pecas, nome + "-col")
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
    parede("int_0", (x, -d / 2 + ESP), (x, d / 2 - ESP), z0, PE, [(rnd.uniform(1.2, d - 2.4), 1.0, 0, 2.1)], m)
    y = rnd.uniform(-0.1, 0.25) * d
    x1 = w / 2 - ESP if rnd.random() < 0.5 else -w / 2 + ESP
    parede("int_1", (x, y), (x1, y), z0, PE, [(abs(x1 - x) / 2, 1.0, 0, 2.1)], m)


# ----- móveis (encostados nas paredes de lado, na metade da frente: os cantos do fundo ficam para baú e item) -----

def sofa(nome, x, y, ang):
    p = [caixa("s", (0, 0, 0.22), (2.0, 0.85, 0.3), "pano"), caixa("s", (0, 0.33, 0.6), (2.0, 0.2, 0.6), "pano"),
         caixa("s", (-0.92, 0, 0.45), (0.18, 0.85, 0.5), "pano"), caixa("s", (0.92, 0, 0.45), (0.18, 0.85, 0.5), "pano"),
         caixa("s", (0.4, -0.05, 0.42), (0.7, 0.6, 0.12), "pano", (0.15, 0.1, 0.3))]  # almofada largada
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


def mobilia(w, d):
    """Sala na esquerda (sofá, estante, mesa) e quarto/cozinha na direita, nas paredes de lado."""
    e, dx = -w / 2 + ESP / 2, w / 2 - ESP / 2
    sofa("sofa", e + 0.5, -d / 4, -1.5708)
    if rnd.random() < 0.6:
        estante("estante", e + 0.25, -d / 2 + 1.2, -1.5708, caida=rnd.random() < 0.5)
    if w > 8:
        mesa("mesa", -w / 4, -d / 6)
    if rnd.random() < 0.5:
        cama("cama", dx - 0.6, -d / 4 + 0.2, 0)
    else:
        balcao("balcao", dx - 0.35, -d / 4, 1.5708, min(2.2, d / 2 - 1.0))
        geladeira("geladeira", dx - 0.45, -d / 2 + 0.7, 1.5708, rnd.random() < 0.4)


def limpa():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def exporta(nome):
    bpy.ops.export_scene.gltf(filepath="%s/%s.glb" % (SAIDA, nome), export_format="GLB", export_apply=True,
                              export_materials="EXPORT", export_extras=False, export_yup=True)


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
    divisorias(w, d, 0, m if tipo != "queimada" else "queimado")
    if tipo != "queimada":
        mobilia(w, d)
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
    for i, (a, b) in enumerate([((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]):
        parede("mureta_%d" % i, a, b, topo, 0.8, [], m, rnd.randint(0, 2))
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
    divisorias(w, d, 0, m)
    mobilia(w, d)
    bx = (w / 2 - 1.5, d / 2 - 4.2, w / 2 - ESP, d / 2 - ESP)
    for k in (1, 2):
        piso("laje%d" % k, -w / 2, -d / 2, w / 2, d / 2, k * PE, "concreto", buraco=bx)
        escada("escada%d" % k, w / 2 - 0.85, d / 2 - 4.0, d / 2 - 0.4, (k - 1) * PE + 0.06, k * PE)
    piso("teto", -w / 2, -d / 2, w / 2, d / 2, 3 * PE, "concreto")
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


if __name__ == "__main__":
    import os
    os.makedirs(SAIDA, exist_ok=True)
    casa("casa_r1", 9.0, 7.0, 11, "inteira")
    casa("casa_r2", 11.0, 8.0, 12, "inteira")
    casa("casa_r3", 7.5, 9.0, 13, "dois")
    casa("casa_r4", 10.0, 8.0, 14, "queimada")
    casa("casa_r5", 12.5, 9.0, 15, "inteira")
    casa("casa_r6", 8.0, 6.5, 16, "queimada")
    loja("loja_r1", 12.0, 10.0, 21, 1)
    loja("loja_r2", 16.0, 12.0, 22, 2)
    predio("predio_r1", 18.0, 12.0, 31)
    galpao("galpao_r1", 18.0, 12.0, 41)
    galpao("galpao_r2", 16.0, 12.0, 42)
    carro("carro_r1", 51)
    carro("carro_r2", 52, queimado=True)
    van("van_r1", 53)
    onibus("onibus_r1", 54)
    caixa_dagua("caixa_dagua")
    print("RUINAS_OK")
