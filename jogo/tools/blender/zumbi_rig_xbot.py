# Põe no esqueleto do X Bot (Mixamo) um zumbi do Sketchfab que veio SEM esqueleto (ou com esqueleto que não é do
# Mixamo), em pose T. O esqueleto do X Bot é esticado até caber no corpo (altura, envergadura dos braços, quadril),
# os pesos saem de um "proxy" (cópia remalhada, fechada, do corpo inteiro: roupa e cabelo acompanham a pele) por
# calor (bone heat) e são passados de volta para a malha. Depois: até ALVO triângulos, texturas 1024 (cor) e
# 512 (resto), GLB com tudo dentro, ossos "mixamorig:Osso" no "Skeleton3D" (o que Anims.boneco espera).
#   blender -b -P tools/blender/zumbi_rig_xbot.py -- entrada.glb saida.glb [alvo_tris=14000] [frente: -y|+y]
import bpy, bmesh, os, sys, tempfile
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
ALVO = int(a[2]) if len(a) > 2 else 14000
XBOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "mixamo", "xbot.fbx")


def so(obs, ativo):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ativo


bpy.ops.wm.read_factory_settings(use_empty=True)
# 1) o zumbi: só as malhas, sem pais, sem esqueleto, transformações aplicadas (metros, Z para cima)
bpy.ops.import_scene.gltf(filepath=a[0])
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data_clear()
malhas = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "Icosphere" and len(o.data.polygons) > 0]
for o in bpy.data.objects:  # malha com esqueleto: a forma vale na pose de descanso (o modificador gira/escala os vértices)
    if o.type == "ARMATURE":
        o.data.pose_position = "REST"
bpy.context.view_layer.update()
for o in malhas:
    if o.data.shape_keys:
        o.shape_key_clear()
    if any(m.type == "ARMATURE" and m.object for m in o.modifiers):
        so([o], o)
        for m in [m for m in o.modifiers if m.type == "ARMATURE"]:
            bpy.ops.object.modifier_apply(modifier=m.name)
so(malhas, malhas[0])
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in malhas:
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.vertex_groups.clear()
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in [o for o in bpy.data.objects if o not in malhas]:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.join()
corpo = bpy.context.view_layer.objects.active
corpo.name = "Corpo"
if max(corpo.dimensions) > 10:  # veio em centímetros: passa para metros
    for v in corpo.data.vertices:
        v.co *= 0.01
vs = [corpo.matrix_world @ v.co for v in corpo.data.vertices]
if len(a) > 3 and a[3] == "+y":  # olhando para +Y: gira 180 (o Mixamo olha para -Y no Blender)
    corpo.rotation_euler.z = 3.14159265
    bpy.ops.object.transform_apply(rotation=True)
    vs = [corpo.matrix_world @ v.co for v in corpo.data.vertices]
z0 = min(v.z for v in vs)
H = max(v.z for v in vs) - z0
cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
envergadura = max(abs(v.x - cx) for v in vs)
faixa = [v for v in vs if z0 + 0.5 * H < v.z < z0 + 0.62 * H]  # cintura/quadril: centro em Y do tronco
cy = (min(v.y for v in faixa) + max(v.y for v in faixa)) / 2
for v in corpo.data.vertices:  # pés no chão, no meio
    v.co -= Vector((cx, 0, z0))
cy_corpo = cy

# 2) o esqueleto do X Bot, esticado para o corpo
bpy.ops.import_scene.fbx(filepath=XBOT)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
xb_malhas = [o for o in bpy.data.objects if o.type == "MESH" and o != corpo]
xvs = [m.matrix_world @ v.co for m in xb_malhas for v in m.data.vertices]
xz0 = min(v.z for v in xvs)
xH = max(v.z for v in xvs) - xz0
xenv = max(abs(v.x) for v in xvs)
xfaixa = [v for v in xvs if xz0 + 0.5 * xH < v.z < xz0 + 0.62 * xH]
xcy = (min(v.y for v in xfaixa) + max(v.y for v in xfaixa)) / 2
for m in xb_malhas:
    bpy.data.objects.remove(m, do_unlink=True)
so([arm], arm)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
sx, sz = envergadura / xenv, H / xH
bpy.ops.object.mode_set(mode="EDIT")
for b in arm.data.edit_bones:
    for p in ("head", "tail"):
        v = getattr(b, p)
        setattr(b, p, Vector((v.x * sx, (v.y - xcy) * sz + cy_corpo, (v.z - xz0) * sz)))
bpy.ops.object.mode_set(mode="OBJECT")
print("RIG H=%.2f env=%.2f sx=%.3f sz=%.3f" % (H, envergadura, sx, sz))

# 3) pesos: proxy fechado (voxel) com calor, passado para o corpo
proxy = corpo.copy()
proxy.data = corpo.data.copy()
bpy.context.scene.collection.objects.link(proxy)
proxy.data.remesh_voxel_size = H / 140
so([proxy], proxy)
bpy.ops.object.voxel_remesh()
dec = proxy.modifiers.new("d", "DECIMATE")
dec.ratio = min(1.0, 30000 / max(1, len(proxy.data.polygons)))
bpy.ops.object.modifier_apply(modifier="d")
so([proxy, arm], arm)
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
sem = sum(1 for v in proxy.data.vertices if not v.groups)
print("PROXY", len(proxy.data.polygons), "sem peso:", sem)
dt = corpo.modifiers.new("dt", "DATA_TRANSFER")
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
so([corpo], corpo)
bpy.ops.object.datalayout_transfer(modifier="dt")
bpy.ops.object.modifier_apply(modifier="dt")
bpy.data.objects.remove(proxy, do_unlink=True)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)

# 4) leve para o celular: até ALVO triângulos (os grupos de vértices acompanham)
tri = sum(len(p.vertices) - 2 for p in corpo.data.polygons)
if tri > ALVO:
    dec = corpo.modifiers.new("d", "DECIMATE")
    dec.ratio = ALVO / tri
    bpy.ops.object.modifier_apply(modifier="d")
tri = sum(len(p.vertices) - 2 for p in corpo.data.polygons)
so([corpo, arm], arm)
bpy.ops.object.parent_set(type="ARMATURE")  # com os grupos que já tem
arm.name = "Skeleton3D"  # o jogo procura as trilhas em "Skeleton3D:mixamorig_<osso>"

# 5) materiais foscos (pele morta não brilha: sem metálico/rugosidade/especular do original), cabelo recortado
# (alpha MASK: sem a casca preta do BLEND), resto opaco; cor em 1024, normal em 512 (memória do celular)
cor = set()
for m in corpo.data.materials:
    if not (m and m.use_nodes):
        continue
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    cabelo = "hair" in m.name.lower() or "cabelo" in m.name.lower()
    for n in list(nt.nodes):
        if n.type != "TEX_IMAGE" or not n.image:
            continue
        destinos = [l.to_socket.name for s in n.outputs for l in s.links]
        if "Base Color" in destinos:
            cor.add(n.image.name)
        elif not any(l.to_node.type == "NORMAL_MAP" for s in n.outputs for l in s.links):
            nt.nodes.remove(n)
    for nome, valor in (("Metallic", 0.0), ("Roughness", 0.9), ("Specular IOR Level", 0.25)):
        for l in list(bsdf.inputs[nome].links):
            nt.links.remove(l)
        bsdf.inputs[nome].default_value = valor
    if cabelo and bsdf.inputs["Alpha"].links:  # ROUND no alfa = o exportador grava alphaMode MASK (corte 0,5)
        de = bsdf.inputs["Alpha"].links[0].from_socket
        r = nt.nodes.new("ShaderNodeMath")
        r.operation = "ROUND"
        nt.links.new(de, r.inputs[0])
        nt.links.new(r.outputs[0], bsdf.inputs["Alpha"])
        m.surface_render_method = "DITHERED"
    else:
        for l in list(bsdf.inputs["Alpha"].links):
            nt.links.remove(l)
        bsdf.inputs["Alpha"].default_value = 1.0
        m.surface_render_method = "DITHERED"
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)
tmp = tempfile.mkdtemp()
for k, img in enumerate(bpy.data.images):
    if img.size[0] == 0:
        continue
    lado = 1024 if img.name in cor else 512
    if img.size[0] > lado:
        img.scale(lado, max(1, int(img.size[1] * lado / img.size[0])))
    img.filepath_raw = os.path.join(tmp, "t%d.png" % k)
    img.file_format = "PNG"
    img.save()
bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", export_animations=False, export_yup=True)
print("ZUMBI_OK tri=%d ossos=%d" % (tri, len(arm.data.bones)))
