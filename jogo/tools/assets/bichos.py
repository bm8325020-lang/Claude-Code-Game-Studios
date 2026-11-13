# Bichos da floresta (13/11): Quaternius CC0 animados (Animal Pack Vol.2: lobo; Animals Pack: raposa; Farm Animals: porco
# que vira javali no jogo) convertidos de FBX para GLB com as animações. Imprime os nomes das animações.
#   blender -b -P tools/assets/bichos.py -- <lobo.fbx> <raposa.fbx> <porco.fbx>
import bpy, os, sys
a = sys.argv[sys.argv.index("--") + 1:]
SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "bichos")
for nome, arq in zip(["lobo", "raposa", "javali"], a):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=arq)
    print("BICHO", nome, [act.name for act in bpy.data.actions])
    bpy.ops.export_scene.gltf(filepath=os.path.join(SAIDA, nome + ".glb"), export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_yup=True)
