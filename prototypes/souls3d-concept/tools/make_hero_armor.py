# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is a dark 3D souls-like fight (stamina, roll, lock-on, Seed spell) fun on a phone?
# Date: 2026-10-21
# Builds the hero's plate armour as one GLB. Each object is named "<bone>__<piece>" and is
# modelled in that Mixamo bone's local space (Godot axes, metres), so the game parents it to a
# BoneAttachment3D with an identity transform. Sizes come from the X Bot's per-bone extents.
# usage: blender -b --python make_hero_armor.py -- <out_dir>
import bpy, bmesh, math, random, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

def mat(name, color, metal=0.0, rough=0.8, emit=None, two_sided=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not two_sided
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 2.5
    return m

PLATE = mat("plate", (0.2, 0.2, 0.21), metal=0.75, rough=0.58)
DARK = mat("plate_dark", (0.09, 0.09, 0.1), metal=0.7, rough=0.65)
TRIM = mat("trim", (0.3, 0.2, 0.09), metal=0.8, rough=0.55)
CLOTH = mat("cloth", (0.16, 0.035, 0.03), rough=0.95, two_sided=True)
LEATHER = mat("leather", (0.14, 0.08, 0.05), rough=0.75)
EMBER = mat("ember", (0.6, 0.15, 0.02), emit=(1.0, 0.3, 0.04))

def obj_from_bm(bm, name, m, thick=0.0):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(m)
    if thick:
        s = o.modifiers.new("solid", "SOLIDIFY")
        s.thickness = thick
        s.offset = 1.0
        s.use_even_offset = True
    return o

def lathe(rings, name, m, arc=(0.0, math.tau), seg=24, thick=0.006, cap_top=False, cap_bot=False, cx=0.0, cz=0.0):
    """Shell around the bone's Y axis. rings: (y, rx, rz_front, rz_back). a=0 points to +Z (front)."""
    bm = bmesh.new()
    full = abs(arc[1] - arc[0] - math.tau) < 1e-6
    n = seg if full else seg + 1
    rows = []
    for y, rx, rzf, rzb in rings:
        row = []
        for i in range(n):
            a = arc[0] + (arc[1] - arc[0]) * i / seg
            c = math.cos(a)
            row.append(bm.verts.new((cx + math.sin(a) * rx, y, cz + c * (rzf if c > 0 else rzb))))
        rows.append(row)
    for r in range(len(rows) - 1):
        for i in range(n if full else n - 1):
            j = (i + 1) % n
            bm.faces.new((rows[r][i], rows[r][j], rows[r + 1][j], rows[r + 1][i]))
    if cap_top:
        bm.faces.new(list(reversed(rows[-1])))
    if cap_bot:
        bm.faces.new(rows[0])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return obj_from_bm(bm, name, m, thick)

def box(name, m, center, size, bevel=0.004):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] + center[0], v.co.y * size[1] + center[1], v.co.z * size[2] + center[2]))
    o = obj_from_bm(bm, name, m)
    if bevel:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 2
    return o

def gem(name, center, r):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x + center[0], v.co.y * 1.3 + center[1], v.co.z * 0.6 + center[2]))
    return obj_from_bm(bm, name, EMBER)

def tattered(name, m, top_y, bot_y, top_w, bot_w, top_z, bot_z, wrap, cols=10, rows=8, seed=3):
    """Hanging cloth panel facing -Z with a ragged, notched hem."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    grid = []
    for r in range(rows + 1):
        t = r / rows
        y = top_y + (bot_y - top_y) * t
        w = top_w + (bot_w - top_w) * t
        z0 = top_z + (bot_z - top_z) * t
        row = []
        for c in range(cols + 1):
            u = c / cols * 2 - 1
            hem = rnd.uniform(0, 0.07) if r == rows else 0.0
            row.append(bm.verts.new((u * w, y + hem, z0 + wrap * (u * u) + rnd.uniform(-0.006, 0.006) * t)))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            if r == rows - 1 and rnd.random() < 0.3:
                continue  # torn notches along the hem
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return obj_from_bm(bm, name, m, 0.004)

def slit(target, center, size):
    cut = box("cut", PLATE, center, size, bevel=0)
    mod = target.modifiers.new("slit", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cut
    mod.solver = "EXACT"
    return cut

cutters = []

# ---- Head: great helm with an eye slit, breaths, a ridge and an ember glow behind the slit
HEAD = "mixamorig_Head"
helm_rings = [(-0.095, 0.118, 0.155, 0.135), (-0.03, 0.113, 0.145, 0.128), (0.05, 0.12, 0.152, 0.132),
              (0.13, 0.122, 0.148, 0.132), (0.19, 0.112, 0.133, 0.122), (0.24, 0.082, 0.097, 0.092),
              (0.27, 0.042, 0.05, 0.046), (0.282, 0.0, 0.0, 0.0)]
helm_rings = [(y, rx * 0.95, f * 0.95, b * 0.95) for y, rx, f, b in helm_rings]
helm = lathe(helm_rings, HEAD + "__helm", PLATE, seg=28, thick=0.007, cz=0.024)
cutters.append(slit(helm, (0, 0.075, 0.17), (0.17, 0.018, 0.09)))
lathe([(y, rx + 0.009, f + 0.009, b + 0.009) for y, rx, f, b in helm_rings[:-1]], HEAD + "__ridge", TRIM,
      arc=(-0.07, 0.07), seg=2, thick=0.006, cz=0.024)
lathe([(-0.1, 0.116, 0.152, 0.133), (-0.075, 0.116, 0.152, 0.133)], HEAD + "__rim", TRIM, seg=28, thick=0.006, cz=0.024)
box(HEAD + "__glow", EMBER, (0, 0.075, 0.148), (0.15, 0.01, 0.004), bevel=0)

# ---- Chest: breastplate + backplate, front ridge, the Seed gem, gorget, cape
CHEST = "mixamorig_Spine2"
cuirass = [(-0.07, 0.158, 0.15, 0.138), (-0.01, 0.163, 0.165, 0.145), (0.07, 0.165, 0.172, 0.15),
           (0.14, 0.158, 0.16, 0.145), (0.19, 0.13, 0.13, 0.128), (0.215, 0.09, 0.09, 0.09)]
lathe(cuirass, CHEST + "__cuirass", PLATE, seg=28, thick=0.008, cz=-0.002)
lathe([(y, rx + 0.01, f + 0.01, b + 0.01) for y, rx, f, b in cuirass[:-1]], CHEST + "__ridge", TRIM,
      arc=(-0.05, 0.05), seg=2, thick=0.006, cz=-0.002)
gem(CHEST + "__seed", (0, 0.07, 0.185), 0.026)
lathe([(0.06, 0.04, 0.04, 0.04), (0.06, 0.05, 0.05, 0.05)], CHEST + "__seed_ring", TRIM, seg=20, thick=0.008, cz=0.176)
lathe([(0.17, 0.1, 0.1, 0.1), (0.22, 0.092, 0.095, 0.092), (0.27, 0.082, 0.088, 0.082)], CHEST + "__gorget", DARK,
      seg=24, thick=0.007, cz=0.0)
tattered(CHEST + "__cape", CLOTH, top_y=0.2, bot_y=-0.56, top_w=0.17, bot_w=0.25, top_z=-0.15, bot_z=-0.27, wrap=0.06)

# ---- Waist: two faulds lames, belt with buckle, side tassets
lathe([(-0.04, 0.152, 0.148, 0.13), (0.05, 0.158, 0.155, 0.135)], "mixamorig_Spine1__lame", DARK, seg=28, thick=0.007, cz=0.015)
lathe([(0.0, 0.148, 0.142, 0.125), (0.09, 0.152, 0.148, 0.13)], "mixamorig_Spine__lame", PLATE, seg=28, thick=0.007, cz=0.01)
HIPS = "mixamorig_Hips"
lathe([(0.0, 0.18, 0.15, 0.17), (0.05, 0.178, 0.148, 0.168)], HIPS + "__belt", LEATHER, seg=28, thick=0.008, cz=-0.026)
box(HIPS + "__buckle", TRIM, (0, 0.025, 0.128), (0.06, 0.045, 0.012))
for side in (-1, 1):
    lathe([(0.0, 0.19, 0.17, 0.17), (-0.2, 0.22, 0.2, 0.2)], HIPS + "__tasset_%s" % ("l" if side > 0 else "r"), PLATE,
          arc=(side * math.pi / 2 - 0.55, side * math.pi / 2 + 0.55), seg=6, thick=0.007, cz=-0.026)

# ---- Arms (same piece on both sides; pieces are symmetric across the bone's X axis)
for side in ("Left", "Right"):
    arm, fore, hand = "mixamorig_%sArm" % side, "mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side
    # pauldron: layered dome over the top of the shoulder (-Z is up on the arm bones)
    lathe([(-0.05, 0.07, 0.07, 0.07), (-0.02, 0.105, 0.105, 0.105), (0.03, 0.128, 0.128, 0.128),
           (0.09, 0.128, 0.128, 0.128), (0.14, 0.112, 0.112, 0.112)], arm + "__pauldron", PLATE,
          arc=(math.pi - 1.9, math.pi + 1.9), seg=16, thick=0.008)
    lathe([(0.12, 0.112, 0.112, 0.112), (0.2, 0.098, 0.098, 0.098)], arm + "__pauldron_lame", DARK,
          arc=(math.pi - 1.6, math.pi + 1.6), seg=14, thick=0.007, cz=0.008)
    lathe([(0.03, 0.135, 0.135, 0.135), (0.045, 0.137, 0.137, 0.137)], arm + "__pauldron_trim", TRIM,
          arc=(math.pi - 1.9, math.pi + 1.9), seg=16, thick=0.006)
    lathe([(0.15, 0.064, 0.064, 0.064), (0.27, 0.06, 0.06, 0.06)], arm + "__rerebrace", PLATE, seg=20, thick=0.006, cz=0.006)
    lathe([(-0.035, 0.064, 0.064, 0.064), (0.0, 0.076, 0.076, 0.076), (0.04, 0.066, 0.066, 0.066)], fore + "__couter", DARK,
          seg=20, thick=0.007)
    lathe([(0.05, 0.063, 0.063, 0.063), (0.2, 0.058, 0.058, 0.058), (0.24, 0.06, 0.06, 0.06), (0.285, 0.074, 0.074, 0.074)],
          fore + "__vambrace", PLATE, seg=20, thick=0.006)
    lathe([(-0.005, 0.062, 0.05, 0.05), (0.05, 0.062, 0.05, 0.05), (0.095, 0.055, 0.042, 0.042)], hand + "__gauntlet", DARK,
          arc=(math.pi - 1.7, math.pi + 1.7), seg=12, thick=0.006)

# ---- Legs (Y runs down the leg, +Z is the front of the knee, same orientation on both legs)
for side in ("Left", "Right"):
    up, leg, foot, toe = ("mixamorig_%s%s" % (side, b) for b in ("UpLeg", "Leg", "Foot", "ToeBase"))
    lathe([(-0.06, 0.125, 0.13, 0.13), (0.08, 0.118, 0.125, 0.125)], up + "__fauld", DARK,
          arc=(-1.35, 1.35), seg=12, thick=0.007, cz=0.0)
    lathe([(0.06, 0.112, 0.118, 0.11), (0.2, 0.104, 0.115, 0.1), (0.36, 0.085, 0.1, 0.085)], up + "__cuisse", PLATE,
          arc=(-1.4, 1.4), seg=14, thick=0.007, cz=0.005)
    lathe([(-0.075, 0.06, 0.07, 0.07), (-0.02, 0.078, 0.095, 0.095), (0.03, 0.08, 0.098, 0.098), (0.085, 0.066, 0.08, 0.08)],
          leg + "__poleyn", DARK, arc=(-1.5, 1.5), seg=12, thick=0.007, cz=-0.005)
    lathe([(0.07, 0.068, 0.082, 0.078), (0.2, 0.07, 0.083, 0.088), (0.33, 0.062, 0.072, 0.07), (0.43, 0.056, 0.066, 0.062)],
          leg + "__greave", PLATE, seg=20, thick=0.006, cz=-0.005)
    lathe([(-0.045, 0.066, 0.085, 0.085), (0.06, 0.068, 0.085, 0.085), (0.15, 0.062, 0.075, 0.072)], foot + "__sabaton", DARK,
          seg=18, thick=0.006, cz=-0.019, cx=0.007)
    lathe([(-0.005, 0.058, 0.07, 0.04), (0.06, 0.052, 0.06, 0.035), (0.1, 0.03, 0.035, 0.02), (0.112, 0.0, 0.0, 0.0)],
          toe + "__toe", PLATE, seg=16, thick=0.006, cz=0.03)

for c in cutters:
    c.hide_set(True)
    c.hide_render = True

# modelled in Godot axes: rotate +90 deg on X so the glTF Y-up conversion gives them back unchanged
for o in list(bpy.context.scene.objects):
    if o in cutters:
        continue
    o.rotation_euler = (math.pi / 2, 0, 0)
for o in cutters:
    o.rotation_euler = (math.pi / 2, 0, 0)
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:
    o.hide_set(False)
    o.select_set(True)
bpy.context.view_layer.objects.active = bpy.context.scene.objects[0]
bpy.ops.object.transform_apply(rotation=True)
for o in bpy.context.scene.objects:
    if o.type == "MESH" and o not in cutters:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        o.data.shade_smooth() if hasattr(o.data, "shade_smooth") else None
for c in cutters:
    bpy.data.objects.remove(c, do_unlink=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "hero_armor.glb"), export_format="GLB", export_apply=True)
print("EXPORTED hero_armor", len(bpy.context.scene.objects))
