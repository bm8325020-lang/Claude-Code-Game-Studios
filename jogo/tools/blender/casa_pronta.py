# Casa pronta (07/11, E2b, regra 7 do loop: pronto no lugar do feito à mão): pega as casas normalizadas
# (assets/mundo/casas/<nome>/<nome>.gltf, de tools/assets/normaliza.py, Sketchfab CC BY) e grava como ruína do jogo
# em assets/ruinas/<nome>.glb: tudo numa malha "ext" (o Bairro junta de longe e faz a caixa), materiais "pronto_*" (o
# Bairro não troca a textura), caixa de colisão "-colonly" e o Empty "fechado" (só por fora: sem porta nem interior).
# Cabe no lote da casa americana menor (LOTE_W x LOTE_D) e a frente fica para +Y do Blender (frente da rua no jogo).
#   ~/.local/blender/blender -b --factory-startup --python-exit-code 1 -P tools/blender/casa_pronta.py -- casa_p1 ...
import bpy, os, sys
from mathutils import Vector

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets")
LOTE_W, LOTE_D = 11.5, 9.5
GIRO = {"casa_p1": 0.0, "casa_p2": 0.0, "casa_p3": 0.0, "casa_p4": 0.0}  # graus em Z se a frente vier de lado


def atlas(o, nome, lado=1024):
    """Assa a cor de todos os materiais numa imagem só (UV nova sem sobreposição) e deixa 1 material."""
    me = o.data
    orig = me.uv_layers.active.name
    uv = me.uv_layers.new(name="atlas")
    me.uv_layers.active = uv
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    for l in me.uv_layers:
        l.active_render = l.name == orig  # as texturas de origem leem a UV antiga; o alvo do bake é a ativa (atlas)
    img = bpy.data.images.new(nome + "_atlas", lado, lado)
    for m in me.materials:
        nt = m.node_tree
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        uvn = nt.nodes.new("ShaderNodeUVMap")
        uvn.uv_map = "atlas"
        nt.links.new(uvn.outputs[0], n.inputs[0])
        nt.nodes.active = n
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.cycles.device = "CPU"
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.margin = 4
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    img.filepath_raw = os.path.join(bpy.app.tempdir, nome + "_atlas.png")
    img.file_format = "PNG"
    img.save()
    mat = bpy.data.materials.new("pronto_%s_atlas" % nome)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    me.materials.clear()
    me.materials.append(mat)
    me.uv_layers.remove(me.uv_layers[orig])
    me.uv_layers["atlas"].active_render = True
    print("ATLAS_OK", nome)


def faz(nome):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAIZ, "mundo", "casas", nome, nome + ".gltf"))
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = "ext"
    o.rotation_euler.z += GIRO.get(nome, 0.0) * 3.14159265 / 180.0
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
    tam = mx - mn
    k = min(1.0, LOTE_W / tam.x, LOTE_D / tam.y)
    o.location = Vector((-(mn.x + mx.x) / 2 * k, -(mn.y + mx.y) / 2 * k, -mn.z * k))
    o.scale = (k, k, k)
    bpy.ops.object.transform_apply(location=True, scale=True)
    if len(o.data.materials) > 3:
        atlas(o, nome)  # 07/11 (otimização): muitos materiais = muitas chamadas de desenho; assa tudo numa textura só
    for m in o.data.materials:
        if m and not m.name.startswith("pronto_"):
            m.name = "pronto_%s_%s" % (nome, m.name)
    t = tam * k
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, t.z / 2))
    c = bpy.context.active_object
    c.name = "corpo-colonly"
    c.scale = (t.x * 0.92, t.y * 0.92, t.z)
    bpy.ops.object.transform_apply(scale=True)
    f = bpy.data.objects.new("fechado", None)
    bpy.context.scene.collection.objects.link(f)
    saida = os.path.join(RAIZ, "ruinas", nome + ".glb")
    bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_extras=False, export_apply=True)
    print("CASA_PRONTA_OK", nome, "%.1f x %.1f x %.1f m" % (t.x, t.y, t.z), "%.2f MB" % (os.path.getsize(saida) / 1e6))


for n in sys.argv[sys.argv.index("--") + 1:]:
    faz(n)
