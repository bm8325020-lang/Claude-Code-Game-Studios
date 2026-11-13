# Árvores e arbusto estilizados pintados à mão (13/11, dono: "pegue modelos prontos de verdade"): Sketchfab CC BY
# (parelaxel "Stylised Redwood Trees Pack", div.andromeda "Stylized Pine", parelaxel "Small Stylised Bush"; créditos em
# assets/mundo/LICENCAS.md). Cada árvore do pacote vira um modelo: malhas juntas, base no chão, altura em metros.
#   blender -b -P tools/assets/natureza2.py
import bpy, os
from mathutils import Vector

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "mundo")
BR = os.path.join(R, "brutos", "vegetation", "trees")
SAIDA = os.path.join(R, "vegetation", "natureza")
# nome: (arquivo, prefixo do nó no pacote ("" = tudo), altura em metros)
MODELOS = {
    "sequoia_g1": ("stylised_redwood_trees_pack_with_lod_groups.glb", "TreeBig001", 26.0),
    "sequoia_g2": ("stylised_redwood_trees_pack_with_lod_groups.glb", "TreeBig002", 28.0),
    "sequoia_g3": ("stylised_redwood_trees_pack_with_lod_groups.glb", "TreeBig003", 24.0),
    "sequoia_m1": ("stylised_redwood_trees_pack_with_lod_groups.glb", "TreeMedium001", 18.0),
    "sequoia_m2": ("stylised_redwood_trees_pack_with_lod_groups.glb", "TreeMedium002", 17.0),
    "sequoia_m3": ("stylised_redwood_trees_pack_with_lod_groups.glb", "TreeMedium003", 19.0),
    "pinho_e": ("stylized_pine.glb", "", 13.0),
    "moita_e": ("small_stylised_bush.glb", "", 1.3),
}


def converte(nome, arq, pref, alt):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(BR, arq))
    ms = [o for o in bpy.data.objects if o.type == "MESH" and (pref == "" or pref in o.name) and "Icosphere" not in o.name]
    for o in list(bpy.data.objects):
        if o not in ms:
            bpy.data.objects.remove(o, do_unlink=True) if o.type == "MESH" else None
    for o in ms:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vs = [v.co for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    esc = alt / max(mx.z - mn.z, 1e-4)
    for v in o.data.vertices:
        v.co = Vector(((v.co.x - (mn.x + mx.x) / 2) * esc, (v.co.y - (mn.y + mx.y) / 2) * esc, (v.co.z - mn.z) * esc))
    for img in bpy.data.images:  # celular: texturas até 512
        if img.size[0] > 512:
            img.scale(512, 512)
    o.name = nome
    d = os.path.join(SAIDA, nome)
    os.makedirs(d, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, nome + ".gltf"), export_format="GLTF_SEPARATE", export_apply=True,
                              export_yup=True, export_image_format="WEBP")
    print("NATUREZA2_OK", nome, len(o.data.polygons), "faces")


for nome, (arq, pref, alt) in MODELOS.items():
    converte(nome, arq, pref, alt)
