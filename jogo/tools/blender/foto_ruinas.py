# Folha de fotos das ruínas (conferir antes de pôr no jogo):
#   blender -b -P tools/blender/foto_ruinas.py -- assets/ruinas saida_dir
import bpy, sys, os, math
a = sys.argv[sys.argv.index("--") + 1:]
pasta, saida = a[0], a[1]
for f in sorted(os.listdir(pasta)):
    if not f.endswith(".glb"):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(pasta, f))
    for o in bpy.data.objects:
        if "colonly" in o.name:
            o.hide_render = True
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    bpy.context.collection.objects.link(cam)
    cam.location = (14, -20, 13)
    cam.rotation_euler = (math.radians(60), 0, math.radians(35))
    bpy.context.scene.camera = cam
    sol = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN"))
    bpy.context.collection.objects.link(sol)
    sol.rotation_euler = (0.8, 0.2, 0.6)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 420
    sc.render.filepath = os.path.join(saida, f[:-4] + ".png")
    bpy.ops.render.render(write_still=True)
