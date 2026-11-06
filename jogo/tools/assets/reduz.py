# Campanha anti-lag (06/11): diminui os triângulos de modelos prontos pesados (móveis do Poly Haven são de cinema:
# cama com 50 mil) sem mudar o resto. Decimate (colapso) em cada malha, proporcional, até o máximo pedido; malha com
# esqueleto (zumbi) continua com os pesos. Grava no mesmo arquivo (os originais ficam no histórico do git).
#   ~/.local/blender/blender -b --factory-startup --python-exit-code 1 -P tools/assets/reduz.py -- <máx> arq.gltf|arq.glb ...
import bpy, os, sys

a = sys.argv[sys.argv.index("--") + 1:]
MAXIMO = int(a[0])


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


for arq in a[1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=arq)
    malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    total = sum(tris(o) for o in malhas)
    if total <= MAXIMO:
        print("REDUZ_PULA", os.path.basename(arq), total)
        continue
    ratio = MAXIMO / total
    for o in malhas:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        d = o.modifiers.new("reduz", "DECIMATE")
        d.ratio = ratio
        d.use_collapse_triangulate = True
        bpy.ops.object.modifier_move_to_index(modifier=d.name, index=0)  # antes do esqueleto
        bpy.ops.object.modifier_apply(modifier=d.name)
    depois = sum(tris(o) for o in malhas)
    glb = arq.endswith(".glb")
    # export_keep_originals: o .gltf continua apontando para as texturas que já estão lá (sem cópia nova)
    bpy.ops.export_scene.gltf(filepath=arq, export_format="GLB" if glb else "GLTF_SEPARATE", export_animations=False,
                              export_yup=True, export_keep_originals=not glb)
    print("REDUZ_OK", os.path.basename(arq), total, "->", depois)
