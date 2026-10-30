# Converte um zumbi do Sketchfab (glb com esqueleto do Mixamo/Fuse) para o formato dos personagens do jogo:
# ossos "mixamorig:Osso" (sem o sufixo _NN do Sketchfab), sem o osso _rootJoint, sem animações, texturas até 1024 px,
# GLB com as texturas dentro. Rodar:
#   blender -b -P tools/blender/zumbi_sketchfab.py -- entrada.glb saida.glb
import bpy, re, sys
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data_clear()
# assa as transformações dos pais (o Sketchfab põe giros e escalas em nós vazios em cima do esqueleto)
for o in bpy.data.objects:
    o.select_set(o.type in ("ARMATURE", "MESH"))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in bpy.data.objects:
    if o.type == "MESH":
        o.select_set(True)
        md = [m for m in o.modifiers if m.type == "ARMATURE"]
        if md:
            md[0].object = arm
        o.parent = arm
        o.matrix_parent_inverse = arm.matrix_world.inverted()
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
for o in bpy.data.objects:
    if o.type == "MESH":
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in [o for o in bpy.data.objects if o.type not in ("ARMATURE", "MESH")]:
    bpy.data.objects.remove(o, do_unlink=True)
# ossos: "mixamorig:Hips_01" -> "mixamorig:Hips"; tira o _rootJoint
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
for b in list(eb):
    if b.name.startswith("_rootJoint") or b.name.lower().startswith("root"):
        for f in b.children:
            f.parent = None
        eb.remove(b)
bpy.ops.object.mode_set(mode="OBJECT")
for b in arm.data.bones:
    novo = "mixamorig:" + re.sub(r"_\d+$", "", b.name).split(":")[-1]  # "Zombie:Hips_01", "Hips_02" -> "mixamorig:Hips"
    for o in bpy.data.objects:  # os grupos de vértices acompanham o nome do osso
        if o.type == "MESH" and b.name in o.vertex_groups:
            o.vertex_groups[b.name].name = novo
    b.name = novo
arm.name = "Skeleton3D"  # o jogo procura as trilhas em "Skeleton3D:mixamorig_<osso>"
import os, tempfile
tmp = tempfile.mkdtemp()
for k, img in enumerate(bpy.data.images):
    if img.size[0] == 0:
        continue
    if img.size[0] > 1024:
        img.scale(1024, max(1, int(img.size[1] * 1024 / img.size[0])))
    img.filepath_raw = os.path.join(tmp, "t%d.png" % k)  # o exportador precisa da imagem num arquivo
    img.file_format = "PNG"
    img.save()
bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", export_animations=False, export_yup=True)
print("ZUMBI_OK", len(arm.data.bones))
