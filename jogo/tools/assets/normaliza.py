# Deixa um modelo baixado (assets/mundo/brutos) pronto para o jogo: tira as transformações dos nós, junta tudo numa
# malha só (uma superfície por material), base no chão e centro em x/y, altura real em metros, texturas até 1024 px.
# "pacote" = um modelo com várias plantas: vira um glb com um nó por planta ("<nome>_<k>", o jogo pega pelo nome).
#   ~/.local/blender/blender -b --factory-startup --python-exit-code 1 -P tools/assets/normaliza.py -- [nome ...]
# Sem nome: faz todos de MODELOS. Saída em assets/mundo/<pasta>/<nome>/<nome>.gltf (+ .bin + texturas .webp).
import atexit, bpy, json, math, os, shutil, sys, tempfile
from mathutils import Vector

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "mundo")
# nome no jogo: (arquivo em brutos/, pasta de saída, altura em metros, pacote[, triângulos máx. (celular)])
MODELOS = {
    "pinheiro": ("vegetation/trees/pine_tree_01.glb", "vegetation/trees", 14.0, False),  # decimado vira serrote (05/11): fica com 5,4 mil
    "arvore_velha": ("vegetation/trees/old_tree.glb", "vegetation/trees", 10.0, False, 3000),
    "betula": ("vegetation/trees/birch_tree.glb", "vegetation/trees", 13.0, False, 3000),
    "arvore": ("vegetation/trees/realistic_tree.glb", "vegetation/trees", 10.0, False, 4000),
    "arvore_rachada": ("vegetation/trees/realistic_cracked_tree_game_ready_prop.glb", "vegetation/trees", 7.0, False),
    "arvore_morta": ("vegetation/trees/low_poly_dead_tree.glb", "vegetation/trees", 7.5, False),
    "floresta": ("vegetation/trees/low_poly_forest_tree_pack.glb", "vegetation/trees", 0.0, True),
    "capim": ("vegetation/plants/realistics_grass_06.glb", "vegetation/plants", 0.55, False, 500),
    "samambaia_capim": ("vegetation/plants/fern_grass_02.glb", "vegetation/plants", 0.45, False, 450),
    "samambaia": ("vegetation/plants/realistic_beech_fern_plant_games_film.glb", "vegetation/plants", 0.6, False, 500),
    "moita": ("vegetation/plants/grass_bushes_game_ready_asset.glb", "vegetation/plants", 0.8, False),
    "carcaca": ("veiculos/abandoned_generic_sedan_2_game_ready.glb", "veiculos", 1.45, False, 6000),  # carro abandonado
    "capim_seco": ("vegetation/plants/dry_realistic_grass_lods_1.glb", "vegetation/plants", 0.6, False, 500),
    # 07/11 anti-travamento: versão de longe das árvores grandes (Planta: perto a inteira, longe esta)
    "arvore_lod": ("vegetation/trees/realistic_tree.glb", "vegetation/trees", 10.0, False, 500),
    "betula_lod": ("vegetation/trees/birch_tree.glb", "vegetation/trees", 13.0, False, 400),
    "pinheiro_lod": ("vegetation/trees/pine_tree_01.glb", "vegetation/trees", 14.0, False, 600),
    "arvore_velha_lod": ("vegetation/trees/old_tree.glb", "vegetation/trees", 10.0, False, 400),
    "arvore_morta_lod": ("vegetation/trees/low_poly_dead_tree.glb", "vegetation/trees", 7.5, False, 300),
    "arvore_rachada_lod": ("vegetation/trees/realistic_cracked_tree_game_ready_prop.glb", "vegetation/trees", 7.0, False, 300),
}
# recusados na foto (05/11): carvalho e carvalho_torto (folha de desenho animado), samambaia_moita (planta tropical),
# samambaia_alta (5 MB de textura para 40 cm). Os brutos continuam em assets/mundo/brutos.
# armas na mão do boneco (3ª pessoa): giro (graus x, y, z no Blender) que põe o cano em -Y do Blender (+Z no Godot) e a
# parte de cima em +Z; comprimento real em metros; origem no meio do comprimento, na altura do cano.
ARMAS = {
    "espingarda": ("armas/remington_shotgun_low_poly.glb", (0, 0, -90), 1.06),
    "fuzil": ("armas/low_poly_ak_74.glb", (-90, 0, 0), 0.94),
    "sniper": ("armas/low_poly_mosin_sniper.glb", (0, 0, 180), 1.23),
    "cartuchos": ("armas/low_poly_shotgun_shells.glb", (0, 0, 0), 0.12),
}
TEX_MAX = 1024
TMP = tempfile.mkdtemp()  # cópia das texturas para o exportador; apagada no fim (cada rodada deixava ~10 MB em /tmp)
atexit.register(shutil.rmtree, TMP, True)


def limpa():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def junta(objs, nome):
    """Assa as transformações e junta as malhas numa só. Devolve o objeto (ou None)."""
    malhas = [o for o in objs if o.type == "MESH"]
    if not malhas:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in malhas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = malhas[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(malhas) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nome
    o.data.name = nome
    return o


def assenta(o, altura):
    """Base em z=0, centro em x/y=0 (pelo pé), escala para a altura (0 = mantém)."""
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    zmin = min(v.z for v in vs)
    zmax = max(v.z for v in vs)
    # centro pelo pé: média dos vértices até 10% da altura (tronco), senão a caixa toda
    pe = [v for v in vs if v.z < zmin + (zmax - zmin) * 0.1] or vs
    cx = sum(v.x for v in pe) / len(pe)
    cy = sum(v.y for v in pe) / len(pe)
    for v in o.data.vertices:
        v.co = o.matrix_world @ v.co - Vector((cx, cy, zmin))
    o.matrix_world.identity()
    if altura > 0 and zmax > zmin:
        s = altura / (zmax - zmin)
        for v in o.data.vertices:
            v.co *= s
    return zmax - zmin


def _tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def _folha(o):
    """Parte com folha em cartão: o material tem alfa ligado (a textura recorta)."""
    for m in o.data.materials:
        if m and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED" and n.inputs["Alpha"].is_linked:
                    return True
    return False


def _rareia(p, fica):
    """Versão de longe: cartão de folha não colapsa (quadrado solto); apaga ilhas ao acaso (fica = fração que sobra)
    e aumenta as que ficam para a copa continuar cheia."""
    import bmesh, random
    rnd = random.Random(7)
    bm = bmesh.new()
    bm.from_mesh(p.data)
    bm.faces.ensure_lookup_table()
    vistos, ilhas = set(), []
    for f in bm.faces:
        if f.index in vistos:
            continue
        ilha, pilha = [], [f]
        vistos.add(f.index)
        while pilha:
            g = pilha.pop()
            ilha.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in vistos:
                        vistos.add(h.index)
                        pilha.append(h)
        ilhas.append(ilha)
    escala = min(2.0, 1.0 / max(fica, 0.05) ** 0.5)
    apagar = []
    for ilha in ilhas:
        if rnd.random() > fica:
            apagar.extend(ilha)
            continue
        vs = {v for g in ilha for v in g.verts}
        c = sum((v.co for v in vs), Vector()) / len(vs)
        for v in vs:
            v.co = c + (v.co - c) * escala
    bmesh.ops.delete(bm, geom=list(set(apagar)), context="FACES")
    bm.to_mesh(p.data)
    bm.free()


def reduz(o, maximo, longe=False):
    """Decimate (colapso) separado: folhas (cartões com alfa) levam o corte grande, tronco no máximo metade.
    longe (versão *_lod): folhas rareadas (_rareia) e tronco cortado mais forte."""
    if not maximo or _tris(o) <= maximo:
        return o
    nome = o.name
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    partes = list(bpy.context.selected_objects)
    folhas = [p for p in partes if _folha(p)] or partes
    fixo = sum(_tris(p) for p in partes if p not in folhas)
    ft = sum(_tris(p) for p in folhas)
    # tronco: no máximo metade dos triângulos some (colapso forte faz caixote); folhas: o que sobrar do orçamento
    r_tronco = max(0.1 if longe else 0.5, min(1.0, maximo * 0.5 / max(fixo, 1)))
    ratio = max(0.03 if longe else 0.1, min(1.0, (maximo - fixo * r_tronco) / max(ft, 1)))
    if longe and folhas is not partes:
        for p in folhas:
            _rareia(p, ratio)
        folhas = []  # já cortadas
    for p in partes:
        if p not in folhas and longe and _folha(p):
            continue
        d = p.modifiers.new("reduz", "DECIMATE")
        d.ratio = ratio if p in folhas else r_tronco
        d.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = p
        bpy.ops.object.modifier_apply(modifier=d.name)
    bpy.ops.object.select_all(action="DESELECT")
    for p in partes:
        p.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = nome
    return o


def texturas():
    tmp = TMP
    for k, img in enumerate(list(bpy.data.images)):
        if img.size[0] == 0:  # imagem vazia: o exportador gera textura sem "source" e o Godot recusa o arquivo
            for m in bpy.data.materials:
                for n in list(m.node_tree.nodes if m.node_tree else []):
                    if n.type == "TEX_IMAGE" and n.image == img:
                        m.node_tree.nodes.remove(n)
            continue
        if max(img.size) > TEX_MAX:
            f = TEX_MAX / max(img.size)
            img.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))
        img.filepath_raw = os.path.join(tmp, "t%d.png" % k)
        img.file_format = "PNG"
        img.save()


def tamanho(dest):
    d = os.path.dirname(dest)
    return sum(os.path.getsize(os.path.join(d, f)) for f in os.listdir(d))


def gltf(dest):
    """.gltf + .bin + texturas WEBP na pasta do modelo (glb faria o Godot extrair cópia das texturas)."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    for fmt in ("WEBP", "AUTO"):  # WEBP não grava imagem de 1 canal (cinza): aí vai no formato original
        for f in os.listdir(os.path.dirname(dest)):
            os.remove(os.path.join(os.path.dirname(dest), f))
        bpy.ops.export_scene.gltf(filepath=dest, export_format="GLTF_SEPARATE", use_selection=True,
                                  export_animations=False, export_yup=True, export_image_format=fmt)
        with open(dest) as f:
            j = json.load(f)
        if all("source" in t or "source" in t.get("extensions", {}).get("EXT_texture_webp", {}) for t in j.get("textures", [])):
            break


def exporta(o, dest):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    gltf(dest)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    d = [round(x, 2) for x in o.dimensions]
    print("NORMALIZA_OK", os.path.relpath(dest, RAIZ), "tris=%d" % tris, "dim=%s" % d,
          "mats=%d" % len(o.data.materials), "%.1f MB" % (tamanho(dest) / 1e6))


def faz_arma(nome):
    arq, giro, comp = ARMAS[nome]
    limpa()
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAIZ, "brutos", arq))
    texturas()
    for o in list(bpy.data.objects):  # esfera de céu do Sketchfab e esqueleto: fora (a malha fica na pose parada)
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH":
            for md in list(o.modifiers):
                o.modifiers.remove(md)
            o.hide_set(False)
            o.hide_viewport = False
    o = junta(list(bpy.data.objects), nome)
    from mathutils import Euler
    m = Euler([math.radians(g) for g in giro]).to_matrix().to_4x4()
    vs = [m @ v.co for v in o.data.vertices]
    mn = Vector([min(v[i] for v in vs) for i in range(3)])
    mx = Vector([max(v[i] for v in vs) for i in range(3)])
    c = (mn + mx) / 2
    s = comp / max(mx - mn)
    for v, w in zip(o.data.vertices, vs):
        v.co = (w - c) * s
    o.data.update()
    exporta(o, os.path.join(RAIZ, "armas", nome, nome + ".gltf"))


def faz(nome):
    if nome in ARMAS:
        return faz_arma(nome)
    arq, pasta, altura, pacote = MODELOS[nome][:4]
    maximo = MODELOS[nome][4] if len(MODELOS[nome]) > 4 else 0
    limpa()
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAIZ, "brutos", arq))
    for o in list(bpy.data.objects):
        if o.animation_data:
            o.animation_data_clear()
    texturas()
    if not pacote:
        o = junta(list(bpy.data.objects), nome)
        assenta(o, altura)
        o = reduz(o, maximo, nome.endswith("_lod"))
        exporta(o, os.path.join(RAIZ, pasta, nome, nome + ".gltf"))
        return
    # pacote: desce pela raiz até o nó com vários filhos; filhos com o pé a menos de 2,5 m um do outro são a mesma
    # planta (tronco + galhos vêm separados). Uma escala só para o pacote: a mais alta fica com 14 m.
    no = [o for o in bpy.data.objects if o.parent is None][0]
    while len(no.children) == 1:
        no = no.children[0]
    grupos = []  # [(x, y, [objs])]
    for g in no.children:
        objs = [g] + list(g.children_recursive)
        ms = [o for o in objs if o.type == "MESH"]
        if not ms:
            continue
        vs = [m.matrix_world @ v.co for m in ms for v in m.data.vertices]
        zmin = min(v.z for v in vs)
        pe = [v for v in vs if v.z < zmin + 0.5] or vs
        x, y = sum(v.x for v in pe) / len(pe), sum(v.y for v in pe) / len(pe)
        for gr in grupos:
            if (gr[0] - x) ** 2 + (gr[1] - y) ** 2 < 2.5 ** 2:
                gr[2].extend(objs)
                break
        else:
            grupos.append((x, y, objs))
    feitos = []
    for k, (_, _, objs) in enumerate(grupos):
        o = junta(objs, "%s_%d" % (nome, k))
        if o:
            o["altura"] = assenta(o, 0)
            feitos.append(o)
    s = 14.0 / max(o["altura"] for o in feitos)
    # um arquivo só (as texturas do pacote são as mesmas): cada planta é um nó "<nome>_<k>" lado a lado em x
    x = 0.0
    for o in feitos:
        for v in o.data.vertices:
            v.co *= s
        o.data.update()
        print("PACOTE", o.name, "tris=%d" % sum(len(p.vertices) - 2 for p in o.data.polygons),
              "dim=%s" % [round(d, 2) for d in o.dimensions])
        o.location.x = x
        x += o.dimensions.x + 2
    bpy.ops.object.select_all(action="DESELECT")
    for o in feitos:
        o.select_set(True)
    dest = os.path.join(RAIZ, pasta, nome, nome + ".gltf")
    gltf(dest)
    print("NORMALIZA_OK", os.path.relpath(dest, RAIZ), "%d plantas" % len(feitos), "%.1f MB" % (tamanho(dest) / 1e6))


a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for nome in (a or list(MODELOS)):
    faz(nome)
