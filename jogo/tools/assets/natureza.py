# Natureza da floresta (13/11, dono: "agora os modelos prontos... mecânicas focadas no ambiente florestal"): modelos
# low poly da Quaternius (CC0: Ultimate Nature Pack, Ultimate Food Pack; OpenGameArt) convertidos para o jogo:
# tudo junto numa malha, base no chão, centro em x/z, altura em metros. Saída: assets/mundo/vegetation/natureza/<nome>/<nome>.gltf
#   blender -b -P tools/assets/natureza.py -- <pasta FBX da natureza> <pasta FBX da comida>
import bpy, os, sys
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
NAT, COMIDA = a[0], a[1]
SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "mundo", "vegetation", "natureza")
# nome no jogo: (pasta, arquivo, altura em metros)
MODELOS = {
    "pinheiro_q1": (NAT, "PineTree_1", 19.0), "pinheiro_q2": (NAT, "PineTree_2", 21.0), "pinheiro_q3": (NAT, "PineTree_3", 17.0),
    "comum_q1": (NAT, "CommonTree_1", 15.0), "comum_q2": (NAT, "CommonTree_2", 14.0), "comum_q3": (NAT, "CommonTree_3", 16.0),
    "betula_q1": (NAT, "BirchTree_1", 16.0), "betula_q2": (NAT, "BirchTree_2", 15.0),
    "outono_q1": (NAT, "CommonTree_Autumn_1", 15.0), "outono_q2": (NAT, "BirchTree_Autumn_1", 15.0),
    "salgueiro_q1": (NAT, "Willow_1", 12.0),
    "arbusto_q1": (NAT, "Bush_1", 1.3), "arbusto_q2": (NAT, "Bush_2", 1.1), "frutinha_q": (NAT, "BushBerries_1", 1.2),
    "planta_q1": (NAT, "Plant_1", 0.7), "planta_q2": (NAT, "Plant_3", 0.9), "flores_q": (NAT, "Flowers", 0.35),
    "pedra_q1": (NAT, "Rock_Moss_1", 1.0), "pedra_q2": (NAT, "Rock_Moss_2", 1.6), "pedra_q3": (NAT, "Rock_Moss_4", 0.7),
    "toco_q": (NAT, "TreeStump_Moss", 0.8), "tronco_q": (NAT, "WoodLog_Moss", 0.7), "lirio_q": (NAT, "Lilypad", 0.05),
    # itens (mochila, chão, ícone)
    "item_madeira": (NAT, "WoodLog", 0.22), "item_pedra": (NAT, "Rock_1", 0.16), "item_fruta": (COMIDA, "Apple", 0.1),
    "item_carne_crua": (COMIDA, "Steak", 0.05), "item_carne_assada": (COMIDA, "ChickenLeg", 0.08),
    "item_cogumelo": (COMIDA, "Mushroom", 0.1), "item_panela": (COMIDA, "CookingPot", 0.25),
}


def converte(nome, pasta, arq, alt):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(pasta, arq + ".fbx"))
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    ms = [o for o in bpy.data.objects if o.type == "MESH"]
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
    o.name = nome
    d = os.path.join(SAIDA, nome)
    os.makedirs(d, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, nome + ".gltf"), export_format="GLTF_SEPARATE", export_apply=True, export_yup=True)
    print("NATUREZA_OK", nome, len(o.data.polygons), "faces")


for nome, (pasta, arq, alt) in MODELOS.items():
    converte(nome, pasta, arq, alt)
