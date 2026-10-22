# PROTOTYPE - NOT FOR PRODUCTION
# Original enemies for Cinzarra, modelled on the KayKit skeleton rig so every existing clip still plays.
# Each body part is a low-poly shape bound rigidly to one bone (like KayKit's own models); the rig and its
# clips come from Skeleton_Warrior.glb, with the "_Rig" suffix Blender adds to action names stripped again.
# Weapons are separate GLBs in the KayKit hand-slot frame (blade along +Z, guard along X), attached in Godot.
# usage: blender -b --python make_foes.py -- <skeleton_glb> <out_dir>
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix, Euler

ARGS = sys.argv[sys.argv.index("--") + 1:]
RIG_GLB, OUT = ARGS[0], ARGS[1]
os.makedirs(OUT, exist_ok=True)

def mat(name, color, metal=0.0, rough=0.85, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 4.0
    return m

FLESH = mat("dead_flesh", (0.32, 0.27, 0.22))
RAG = mat("rag", (0.12, 0.1, 0.08))
RAG2 = mat("rag_red", (0.22, 0.06, 0.05))
IRON = mat("rust_iron", (0.2, 0.17, 0.15), metal=0.85, rough=0.6)
DARKIRON = mat("dark_iron", (0.08, 0.08, 0.09), metal=0.9, rough=0.45)
LEATHER = mat("old_leather", (0.16, 0.1, 0.06), rough=0.75)
BONE = mat("bone", (0.62, 0.57, 0.48), rough=0.8)
STONE = mat("statue_stone", (0.36, 0.35, 0.34), rough=0.95)
MOSS = mat("moss", (0.12, 0.16, 0.08))
VOID = mat("void", (0.0, 0.0, 0.0), rough=1.0)
EMBER = mat("ember_eyes", (1.0, 0.3, 0.05), emit=(1.0, 0.3, 0.05))
COLD = mat("cold_eyes", (0.3, 0.75, 1.0), emit=(0.3, 0.75, 1.0))
STEEL = mat("old_steel", (0.45, 0.45, 0.47), metal=1.0, rough=0.35)
WOOD = mat("wood", (0.18, 0.11, 0.06))

FOE = mat("foe", (1, 1, 1))

def bake_colors(me, mats):
    """One draw call per enemy on phones: every face's material colour goes into a vertex colour, one material left."""
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    me.color_attributes.active_color = col
    for p in me.polygons:
        b = mats[p.material_index].node_tree.nodes["Principled BSDF"]
        c = b.inputs["Emission Color"].default_value if b.inputs["Emission Strength"].default_value > 0 else b.inputs["Base Color"].default_value
        for li in p.loop_indices:
            col.data[li].color = c
        p.material_index = 0
    me.materials.clear()
    me.materials.append(FOE)

class Body:
    """Collects shapes into one bmesh; every vertex remembers the bone it is bound to."""
    def __init__(self):
        self.bm = bmesh.new()
        self.bone = self.bm.verts.layers.int.new("bone")
        self.mats, self.bones = [], []

    def _tag(self, verts, bone, m):
        if m not in self.mats:
            self.mats.append(m)
        if bone not in self.bones:
            self.bones.append(bone)
        bi, mi = self.bones.index(bone), self.mats.index(m)
        faces = set()
        for v in verts:
            v[self.bone] = bi
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = mi

    def box(self, bone, center, size, m, rot=(0, 0, 0), bevel=0.0, taper=1.0):
        """taper < 1 shrinks the top face, for wedge-like armour plates and limbs."""
        mx = Matrix.Translation(center) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mx)
        vs = r["verts"]
        if taper != 1.0:
            top = max(v.co.z for v in vs)
            for v in vs:
                if abs(v.co.z - top) < 1e-4:
                    v.co.x = center[0] + (v.co.x - center[0]) * taper
                    v.co.y = center[1] + (v.co.y - center[1]) * taper
        self._tag(vs, bone, m)
        if bevel:  # tag first: the chamfer's new vertices and faces copy the bone and material from the cube
            edges = list({e for v in vs for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)

    def tube(self, bone, a, b, r0, r1, m, sides=6):
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        side = axis.cross(Vector((0, 0, 1)))
        if side.length < 0.01:
            side = axis.cross(Vector((1, 0, 0)))
        side.normalize()
        up = axis.cross(side)
        rings = []
        for p, r in ((a, r0), (b, r1)):
            rings.append([self.bm.verts.new(p + (side * math.cos(t) + up * math.sin(t)) * r) for t in (i / sides * math.tau for i in range(sides))])
        for i in range(sides):
            j = (i + 1) % sides
            self.bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
        if r0 > 0.001:
            self.bm.faces.new(list(reversed(rings[0])))
        self.bm.faces.new(rings[1])
        self._tag(rings[0] + rings[1], bone, m)

    def ball(self, bone, center, radii, m, subdiv=1):
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=Matrix.Translation(center) @ Matrix.Diagonal((*radii, 1)))
        self._tag(r["verts"], bone, m)

    def cone(self, bone, base, tip, r, m, sides=6, squash=1.0):
        base, tip = Vector(base), Vector(tip)
        axis = (tip - base).normalized()
        side = axis.cross(Vector((0, 0, 1)))
        if side.length < 0.01:
            side = axis.cross(Vector((1, 0, 0)))
        side.normalize()
        up = axis.cross(side)
        ring = [self.bm.verts.new(base + (side * math.cos(t) + up * math.sin(t) * squash) * r) for t in (i / sides * math.tau for i in range(sides))]
        t = self.bm.verts.new(tip)
        for i in range(sides):
            self.bm.faces.new((ring[i], ring[(i + 1) % sides], t))
        self.bm.faces.new(list(reversed(ring)))
        self._tag(ring + [t], bone, m)

    def skirt(self, bone, z_top, z_bot, r_top, r_bot, m, strips=10, rnd=None, ragged=0.0, front_open=0.0, depth=0.8):
        """Hanging cloth: a ring of quads whose bottom edge is torn to different lengths."""
        top, bot = [], []
        for i in range(strips):
            a = i / strips * math.tau
            if front_open and abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < front_open:
                pass
            drop = (rnd.uniform(0, ragged) if rnd else 0.0)
            top.append(self.bm.verts.new((math.cos(a) * r_top, math.sin(a) * r_top * depth, z_top)))
            bot.append(self.bm.verts.new((math.cos(a) * r_bot, math.sin(a) * r_bot * depth, z_bot - drop)))
        for i in range(strips):
            j = (i + 1) % strips
            self.bm.faces.new((top[i], top[j], bot[j], bot[i]))
        self._tag(top + bot, bone, m)

# KayKit rest pose, armature space (Z up, the model faces -Y)
SH = {"l": 1, "r": -1}
def limbs(b, arm_m, leg_m, hand_m, foot_m, arm_r=0.055, leg_r=0.07, hands="flesh"):
    for s, k in SH.items():
        b.tube("upperarm." + s, (k * 0.2, 0, 1.107), (k * 0.454, 0.01, 1.107), arm_r, arm_r * 0.85, arm_m)
        b.tube("lowerarm." + s, (k * 0.454, 0.01, 1.107), (k * 0.75, 0, 1.107), arm_r * 0.85, arm_r * 0.7, arm_m)
        b.box("hand." + s, (k * 0.84, 0, 1.1), (0.12, 0.07, 0.09), hand_m)
        b.tube("upperleg." + s, (k * 0.171, 0, 0.53), (k * 0.171, 0, 0.29), leg_r, leg_r * 0.85, leg_m)
        b.tube("lowerleg." + s, (k * 0.171, 0, 0.29), (k * 0.171, 0.0, 0.1), leg_r * 0.85, leg_r * 0.7, leg_m)
        b.box("foot." + s, (k * 0.171, -0.07, 0.05), (0.12, 0.26, 0.1), foot_m, taper=0.8)

def head_void(b, eye_m, y=-0.12, z=1.36, spread=0.045):
    for s in (-1, 1):
        b.ball("head", (s * spread, y, z), (0.022, 0.012, 0.016), eye_m, 0)

# --- Esquecido (minion): a hollowed villager in a torn hood and rags ---------------------------------------------------
def hollow(b):
    rnd = random.Random(1)
    b.box("hips", (0, 0, 0.55), (0.3, 0.2, 0.22), RAG)
    b.box("spine", (0, 0.02, 0.8), (0.32, 0.2, 0.36), FLESH, taper=1.15)
    for z in (0.74, 0.82, 0.9):  # ribs showing through
        b.box("spine", (0, -0.1, z), (0.28, 0.03, 0.025), BONE)
    b.box("chest", (0, 0.03, 1.08), (0.38, 0.22, 0.26), RAG, taper=0.8)
    b.tube("chest", (0, 0, 1.18), (0, 0, 1.27), 0.05, 0.045, FLESH)
    b.ball("head", (0, -0.02, 1.36), (0.11, 0.12, 0.13), FLESH)
    b.cone("head", (0, 0.03, 1.27), (0, 0.12, 1.58), 0.17, RAG, 7)  # hood
    b.box("head", (0, -0.09, 1.36), (0.13, 0.04, 0.12), VOID)
    head_void(b, EMBER, y=-0.115)
    b.skirt("hips", 0.62, 0.3, 0.19, 0.24, RAG, 10, rnd, 0.1)
    b.skirt("chest", 1.18, 0.95, 0.21, 0.26, RAG, 8, rnd, 0.08)  # shoulder rag
    limbs(b, FLESH, RAG, FLESH, LEATHER, arm_r=0.045, leg_r=0.06)

# --- Cavaleiro Oco (warrior): rusted plate, great helm with a slit, red tabard ---------------------------------------
def knight(b, metal=IRON, cloth=RAG2, eyes=EMBER, bulk=1.0, crown=False, stone=False):
    rnd = random.Random(2)
    b.box("hips", (0, 0, 0.55), (0.34 * bulk, 0.24 * bulk, 0.22), metal, bevel=0.015)
    b.box("spine", (0, 0, 0.8), (0.36 * bulk, 0.26 * bulk, 0.34), metal, taper=1.2, bevel=0.015)
    b.box("chest", (0, -0.01, 1.08), (0.5 * bulk, 0.32 * bulk, 0.3), metal, taper=0.82, bevel=0.02)
    b.box("chest", (0, -0.17 * bulk, 1.03), (0.06, 0.04, 0.32), metal)  # breastplate ridge
    for s, k in SH.items():  # pauldrons, layered
        b.ball("upperarm." + s, (k * 0.25, 0, 1.15), (0.14 * bulk, 0.14 * bulk, 0.1), metal)
        b.box("upperarm." + s, (k * 0.3, 0, 1.08), (0.16 * bulk, 0.2 * bulk, 0.05), metal, rot=(0, k * 0.4, 0))
        b.box("lowerarm." + s, (k * 0.62, 0, 1.107), (0.2, 0.14 * bulk, 0.14 * bulk), metal, bevel=0.01)  # vambrace
        b.box("lowerleg." + s, (k * 0.171, -0.01, 0.2), (0.15 * bulk, 0.16 * bulk, 0.2), metal, bevel=0.01)  # greave
        b.ball("upperleg." + s, (k * 0.171, -0.05, 0.3), (0.07, 0.06, 0.06), metal)  # knee cop
    b.tube("chest", (0, 0, 1.18), (0, 0, 1.27), 0.07, 0.06, DARKIRON)
    # great helm: a tall box, a flared bottom rim, the eye slit and breaths
    b.box("head", (0, -0.01, 1.38), (0.24, 0.26, 0.28), metal, taper=0.85, bevel=0.015)
    b.box("head", (0, -0.14, 1.4), (0.2, 0.02, 0.025), VOID)
    head_void(b, eyes, y=-0.145, z=1.4, spread=0.04)
    b.box("head", (0, -0.15, 1.33), (0.025, 0.03, 0.12), metal)
    if crown:  # the Sentinels: a crest of stone horns
        for s in (-1, 1):
            b.cone("head", (s * 0.11, 0, 1.47), (s * 0.24, 0.04, 1.68), 0.05, metal, 5)
        b.cone("head", (0, 0.02, 1.52), (0, 0.06, 1.72), 0.05, metal, 5)
    else:
        b.cone("head", (0, 0.02, 1.52), (0, 0.1, 1.62), 0.03, cloth, 4)  # plume stub
    b.skirt("hips", 0.6, 0.18, 0.2 * bulk, 0.22 * bulk, cloth, 8, rnd, 0.06)  # tabard
    b.skirt("chest", 1.2, 0.5, 0.26 * bulk, 0.3 * bulk, cloth if not stone else MOSS, 9, rnd, 0.12)  # cape
    limbs(b, DARKIRON, DARKIRON, metal, metal, arm_r=0.06 * bulk, leg_r=0.075 * bulk)

# --- Clérigo da Cinza (caster): floor-length robe, deep cowl, bone mask with cold eyes ----------------------------------
def cultist(b):
    rnd = random.Random(3)
    b.box("hips", (0, 0, 0.55), (0.3, 0.22, 0.2), RAG)
    b.box("spine", (0, 0, 0.8), (0.3, 0.22, 0.34), RAG, taper=1.15)
    b.box("chest", (0, 0, 1.08), (0.4, 0.26, 0.28), RAG, taper=0.8)
    b.skirt("hips", 0.65, 0.02, 0.2, 0.32, RAG, 12, rnd, 0.04)  # robe to the floor
    b.skirt("spine", 0.95, 0.6, 0.19, 0.22, LEATHER, 8)  # belt sash
    for s, k in SH.items():  # wide sleeves
        b.tube("lowerarm." + s, (k * 0.46, 0.01, 1.107), (k * 0.72, 0, 1.08), 0.07, 0.12, RAG, 7)
    b.ball("head", (0, -0.02, 1.36), (0.11, 0.12, 0.13), FLESH)
    b.cone("head", (0, 0.04, 1.24), (0, 0.18, 1.7), 0.2, RAG, 8)  # deep cowl
    b.box("head", (0, -0.12, 1.36), (0.16, 0.04, 0.18), BONE, taper=0.7)  # bone mask
    b.box("head", (0, -0.145, 1.31), (0.06, 0.01, 0.03), VOID)
    head_void(b, COLD, y=-0.145, z=1.38, spread=0.04)
    for i in range(5):  # finger-bone necklace
        a = (i - 2) * 0.35
        b.box("chest", (math.sin(a) * 0.17, -math.cos(a) * 0.14, 1.1 - abs(i - 2) * 0.03), (0.02, 0.02, 0.06), BONE)
    limbs(b, RAG, RAG, BONE, LEATHER, arm_r=0.05, leg_r=0.065)

# --- Espreitador (rogue / crossbowman): leather, a hood and scarf, belts of knives -----------------------------------
def stalker(b):
    rnd = random.Random(4)
    b.box("hips", (0, 0, 0.55), (0.3, 0.2, 0.2), LEATHER)
    b.box("spine", (0, 0, 0.8), (0.3, 0.2, 0.32), LEATHER, taper=1.15, bevel=0.01)
    b.box("chest", (0, 0, 1.08), (0.42, 0.24, 0.26), LEATHER, taper=0.82, bevel=0.01)
    b.box("chest", (0, -0.0, 1.05), (0.44, 0.26, 0.04), DARKIRON, rot=(0, 0.6, 0))  # bandolier
    for x in (-0.08, 0.0, 0.08):
        b.box("chest", (x - 0.02, -0.13, 1.03 + x * 0.6), (0.03, 0.02, 0.09), STEEL)
    b.skirt("hips", 0.6, 0.32, 0.18, 0.21, RAG, 8, rnd, 0.06)
    b.skirt("chest", 1.2, 0.55, 0.22, 0.27, RAG, 9, rnd, 0.14)  # short cloak
    b.ball("head", (0, -0.02, 1.36), (0.11, 0.12, 0.13), FLESH)
    b.cone("head", (0, 0.03, 1.26), (0, 0.16, 1.6), 0.16, RAG, 7)  # hood
    b.box("head", (0, -0.1, 1.31), (0.2, 0.08, 0.08), RAG2)  # scarf over the mouth
    b.box("head", (0, -0.11, 1.39), (0.14, 0.03, 0.05), VOID)
    head_void(b, EMBER, y=-0.125, z=1.39, spread=0.035)
    limbs(b, LEATHER, LEATHER, LEATHER, LEATHER, arm_r=0.05, leg_r=0.065)

# --- the walled cities ------------------------------------------------------------------------------------------------
GAMBESON = mat("gambeson", (0.3, 0.26, 0.2))
TABARD = mat("city_tabard", (0.28, 0.2, 0.06))  # faded city yellow
BLACK = mat("black_plate", (0.04, 0.04, 0.05), metal=0.9, rough=0.35)
GOLD = mat("old_gold", (0.45, 0.33, 0.1), metal=1.0, rough=0.4)
PURPLE = mat("witch_cloth", (0.16, 0.06, 0.18))
SKIN = mat("pale_skin", (0.5, 0.4, 0.34))
BEAK = mat("plague_leather", (0.1, 0.08, 0.05), rough=0.6)
GLASS = mat("plague_lens", (0.6, 0.55, 0.2), emit=(0.6, 0.5, 0.1))

# Guarda da Muralha: kettle helm over a mail coif, padded gambeson, city tabard
def guard(b):
    rnd = random.Random(5)
    b.box("hips", (0, 0, 0.55), (0.34, 0.24, 0.22), GAMBESON)
    b.box("spine", (0, 0, 0.8), (0.36, 0.26, 0.34), GAMBESON, taper=1.15)
    for z in (0.7, 0.8, 0.9):  # quilting
        b.box("spine", (0, -0.135, z), (0.34, 0.01, 0.015), LEATHER)
    b.box("chest", (0, -0.01, 1.08), (0.46, 0.3, 0.3), GAMBESON, taper=0.85)
    b.box("chest", (0, -0.16, 0.95), (0.3, 0.02, 0.5), TABARD)  # tabard front
    b.skirt("hips", 0.62, 0.25, 0.2, 0.23, TABARD, 8, rnd, 0.03)
    b.tube("chest", (0, 0, 1.18), (0, 0, 1.27), 0.07, 0.07, IRON)
    b.ball("head", (0, -0.01, 1.36), (0.12, 0.13, 0.13), IRON)  # mail coif
    b.box("head", (0, -0.1, 1.34), (0.13, 0.04, 0.12), SKIN)  # face
    head_void(b, EMBER, y=-0.125, z=1.37, spread=0.035)
    b.cone("head", (0, 0, 1.43), (0, 0, 1.55), 0.13, IRON, 8)  # kettle helm crown
    b.tube("head", (0, 0, 1.42), (0, 0, 1.44), 0.24, 0.24, IRON, 10)  # its wide brim
    for s_, k in SH.items():
        b.ball("upperarm." + s_, (k * 0.25, 0, 1.13), (0.11, 0.12, 0.09), IRON)
    limbs(b, GAMBESON, GAMBESON, LEATHER, LEATHER, arm_r=0.06, leg_r=0.075)

# Carrasco: huge, bare-chested, a black hood with eye holes, leather apron and a great axe
def executioner(b):
    rnd = random.Random(6)
    b.box("hips", (0, 0, 0.55), (0.42, 0.3, 0.24), LEATHER)
    b.box("spine", (0, 0.02, 0.8), (0.46, 0.34, 0.36), SKIN, taper=1.2)
    b.box("chest", (0, 0.01, 1.08), (0.6, 0.38, 0.3), SKIN, taper=0.85)
    b.ball("spine", (0, -0.12, 0.72), (0.24, 0.12, 0.16), SKIN)  # gut
    b.box("chest", (0, -0.2, 0.9), (0.36, 0.03, 0.6), LEATHER)  # apron
    b.skirt("hips", 0.62, 0.22, 0.24, 0.27, LEATHER, 8, rnd, 0.05)
    b.box("chest", (0.12, -0.12, 1.12), (0.05, 0.3, 0.5), LEATHER, rot=(0, 0.5, 0))  # strap
    b.tube("chest", (0, 0, 1.18), (0, 0, 1.27), 0.09, 0.08, SKIN)
    b.cone("head", (0, 0, 1.22), (0, 0.02, 1.66), 0.17, BLACK, 8)  # hood
    b.ball("head", (0, -0.03, 1.36), (0.14, 0.14, 0.15), BLACK)
    b.box("head", (0, -0.15, 1.4), (0.16, 0.02, 0.04), VOID)
    head_void(b, EMBER, y=-0.16, z=1.4, spread=0.045)
    limbs(b, SKIN, LEATHER, SKIN, LEATHER, arm_r=0.085, leg_r=0.09)

# Cavaleiro Negro: blackened plate edged in gold, horned great helm, long torn cape
def blackknight(b):
    knight(b, metal=BLACK, cloth=RAG, eyes=EMBER, bulk=1.15, crown=True)
    for z in (1.2, 0.62):  # gold trim
        b.box("chest" if z > 1 else "hips", (0, 0, z), (0.52 if z > 1 else 0.38, 0.34 if z > 1 else 0.27, 0.03), GOLD)
    for s_, k in SH.items():
        b.cone("upperarm." + s_, (k * 0.28, 0, 1.22), (k * 0.36, 0, 1.4), 0.04, GOLD, 4)  # pauldron spikes

# Feiticeira da Torre: veiled, long violet robe, a circlet and cold eyes; bony hands
def sorceress(b):
    rnd = random.Random(7)
    b.box("hips", (0, 0, 0.55), (0.28, 0.2, 0.2), PURPLE)
    b.box("spine", (0, 0, 0.8), (0.26, 0.2, 0.34), PURPLE, taper=1.1)
    b.box("chest", (0, 0, 1.08), (0.36, 0.24, 0.28), PURPLE, taper=0.8)
    b.skirt("hips", 0.66, 0.02, 0.19, 0.34, PURPLE, 14, rnd, 0.03)
    b.skirt("chest", 1.22, 0.4, 0.2, 0.3, RAG, 10, rnd, 0.1)  # shawl
    for s_, k in SH.items():
        b.tube("lowerarm." + s_, (k * 0.46, 0.01, 1.107), (k * 0.72, 0, 1.08), 0.06, 0.13, PURPLE, 7)
    b.ball("head", (0, -0.02, 1.36), (0.1, 0.11, 0.12), SKIN)
    b.skirt("head", 1.5, 1.2, 0.12, 0.16, RAG, 10, rnd, 0.06)  # veil
    b.tube("head", (0, 0, 1.44), (0, 0, 1.46), 0.12, 0.12, GOLD, 10)  # circlet
    b.cone("head", (0, -0.1, 1.46), (0, -0.12, 1.56), 0.025, GOLD, 4)
    head_void(b, COLD, y=-0.115, z=1.38, spread=0.035)
    limbs(b, PURPLE, PURPLE, BONE, LEATHER, arm_r=0.045, leg_r=0.06)

# Andarilho da Peste: plague-doctor beak mask with glowing lenses, wide hat, oilskin coat
def plague(b):
    rnd = random.Random(8)
    b.box("hips", (0, 0, 0.55), (0.3, 0.22, 0.2), BEAK)
    b.box("spine", (0, 0, 0.8), (0.32, 0.22, 0.34), BEAK, taper=1.15)
    b.box("chest", (0, 0, 1.08), (0.42, 0.26, 0.28), BEAK, taper=0.82)
    b.skirt("hips", 0.64, 0.08, 0.2, 0.3, BEAK, 12, rnd, 0.05)  # long coat
    b.skirt("chest", 1.22, 0.85, 0.24, 0.3, RAG, 10, rnd, 0.08)  # cape
    b.ball("head", (0, -0.01, 1.36), (0.12, 0.12, 0.13), BEAK)
    b.cone("head", (0, -0.1, 1.34), (0, -0.38, 1.27), 0.07, BONE, 6)  # the beak
    for sx in (-1, 1):
        b.ball("head", (sx * 0.05, -0.115, 1.4), (0.03, 0.015, 0.03), GLASS, 0)
    b.tube("head", (0, 0, 1.46), (0, 0, 1.48), 0.26, 0.26, BEAK, 10)  # hat brim
    b.tube("head", (0, 0, 1.48), (0, 0, 1.62), 0.12, 0.1, BEAK, 8)  # crown
    for i in range(3):  # vials on the belt
        b.box("hips", (-0.12 + i * 0.12, -0.13, 0.6), (0.04, 0.04, 0.09), GLASS)
    limbs(b, BEAK, BEAK, LEATHER, LEATHER, arm_r=0.05, leg_r=0.065)

def clear():
    # not a factory reset: that would also delete the shared materials
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.images):
        for d in list(coll):
            coll.remove(d)

def build(name, fn, **kw):
    clear()
    bpy.ops.import_scene.gltf(filepath=RIG_GLB)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    b = Body()
    fn(b, **kw)
    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    groups = [ob.vertex_groups.new(name=bn) for bn in b.bones]
    b.bm.to_mesh(me)
    layer = b.bm.verts.layers.int["bone"]
    for v in b.bm.verts:
        groups[v[layer]].add([v.index], 1.0, "REPLACE")
    tris = sum(len(f.verts) - 2 for f in b.bm.faces)
    b.bm.free()
    bake_colors(me, b.mats)
    for p in me.polygons:
        p.use_smooth = False
    ob.parent = rig
    ob.modifiers.new("rig", "ARMATURE").object = rig
    for a in bpy.data.actions:
        if a.name.endswith("_Rig"):
            a.name = a.name[:-4]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_animation_mode="ACTIONS", export_vertex_color="ACTIVE")
    print("EXPORTED", name, tris, "tris")

# --- weapons, in the hand-slot frame -----------------------------------------------------------------------------------
def weapon(name, fn, turn=0.0):
    clear()
    b = Body()
    fn(b)
    if turn:
        bmesh.ops.rotate(b.bm, verts=b.bm.verts[:], matrix=Matrix.Rotation(turn, 3, "X"))
    me = bpy.data.meshes.new(name)
    b.bm.to_mesh(me)
    tris = sum(len(f.verts) - 2 for f in b.bm.faces)
    b.bm.free()
    bake_colors(me, b.mats)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_vertex_color="ACTIVE")
    print("EXPORTED", name, tris, "tris")

def broadsword(b, length=0.95, width=0.09, m=IRON):
    b.tube("x", (0, 0, -0.12), (0, 0, 0.12), 0.025, 0.025, LEATHER, 5)
    b.ball("x", (0, 0, -0.14), (0.04, 0.04, 0.04), m, 0)
    b.box("x", (0, 0, 0.14), (0.28, 0.05, 0.04), m)
    b.box("x", (0, 0, 0.16 + length / 2), (width, 0.02, length), m, taper=0.55)
    b.cone("x", (0, 0, 0.16 + length), (0, 0, 0.26 + length), width * 0.38, m, 4, squash=0.25)

def greatsword(b):
    b.tube("x", (0, 0, -0.3), (0, 0, 0.14), 0.035, 0.035, LEATHER, 5)
    b.box("x", (0, 0, 0.16), (0.5, 0.08, 0.07), STONE)
    b.box("x", (0, 0, 0.2 + 0.75), (0.2, 0.05, 1.5), STONE, taper=0.7)
    b.cone("x", (0, 0, 1.7), (0, 0, 1.92), 0.08, STONE, 4, squash=0.3)

def staff(b):
    b.tube("x", (0, 0, -0.8), (0, 0, 1.0), 0.025, 0.02, WOOD, 5)
    for i in range(4):  # a cage of bone prongs holding a cold flame
        a = i * math.pi / 2
        b.tube("x", (0, 0, 0.98), (math.cos(a) * 0.1, math.sin(a) * 0.1, 1.2), 0.015, 0.008, BONE, 4)
    b.ball("x", (0, 0, 1.12), (0.05, 0.05, 0.07), COLD, 1)

def dagger(b):
    broadsword(b, 0.42, 0.06, STEEL)

def crossbow(b):
    b.box("x", (0, -0.4, 0.05), (0.08, 0.95, 0.07), WOOD)  # stock along -Y like KayKit's
    b.box("x", (0, 0.05, -0.05), (0.06, 0.2, 0.18), WOOD, rot=(0.4, 0, 0))
    for s in (-1, 1):
        b.box("x", (s * 0.27, -0.82, 0.07), (0.5, 0.05, 0.05), DARKIRON, rot=(0, 0, s * -0.35))
    b.box("x", (0, -0.7, 0.08), (0.95, 0.008, 0.008), BONE)  # string
    b.box("x", (0, -0.55, 0.11), (0.02, 0.5, 0.02), STEEL)  # bolt

def halberd(b):
    b.tube("x", (0, 0, -0.9), (0, 0, 1.4), 0.025, 0.022, WOOD, 5)
    b.box("x", (0.1, 0, 1.3), (0.22, 0.02, 0.28), IRON, taper=0.6)  # axe blade
    b.box("x", (-0.07, 0, 1.32), (0.12, 0.02, 0.05), IRON)  # back hook
    b.cone("x", (0, 0, 1.4), (0, 0, 1.68), 0.04, IRON, 4, squash=0.4)  # spike

def greataxe(b):
    b.tube("x", (0, 0, -0.5), (0, 0, 1.1), 0.035, 0.03, WOOD, 5)
    b.box("x", (0.2, 0, 0.95), (0.38, 0.03, 0.5), DARKIRON, taper=1.6)  # the wide head
    b.box("x", (-0.08, 0, 0.95), (0.1, 0.04, 0.12), DARKIRON)

def shield(b):
    b.box("x", (0, -0.06, 0.2), (0.5, 0.05, 0.62), BLACK, bevel=0.01, taper=0.75)  # kite shield in the hand slot frame
    b.box("x", (0, -0.09, 0.22), (0.08, 0.01, 0.5), GOLD)
    b.box("x", (0, -0.09, 0.3), (0.36, 0.01, 0.06), GOLD)

def cleaver(b):
    b.tube("x", (0, 0, -0.12), (0, 0, 0.12), 0.022, 0.022, WOOD, 5)
    b.box("x", (0.05, 0, 0.36), (0.16, 0.015, 0.46), IRON)

build("Hollow", hollow)
build("Knight", knight)
build("Sentinel", knight, metal=STONE, cloth=MOSS, eyes=EMBER, bulk=1.25, crown=True, stone=True)
build("Cultist", cultist)
build("Stalker", stalker)
weapon("w_sword", broadsword)
weapon("w_greatsword", greatsword)
weapon("w_staff", staff)
weapon("w_dagger", dagger)
weapon("w_crossbow", crossbow, -math.pi / 2)  # stock forward along the hand slot, like the blades
build("Guard", guard)
build("Executioner", executioner)
build("BlackKnight", blackknight)
build("Sorceress", sorceress)
build("Plague", plague)
weapon("w_halberd", halberd)
weapon("w_greataxe", greataxe)
weapon("w_shield", shield)
weapon("w_cleaver", cleaver)
