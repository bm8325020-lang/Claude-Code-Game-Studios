# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is a dark 3D souls-like fight (stamina, roll, lock-on, Seed spell) fun on a phone?
# Date: 2026-10-21
# Builds dark-fantasy props procedurally and exports one GLB each.
# usage: blender -b --python make_props.py -- <out_dir>
import bpy, bmesh, math, random, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def mat(name, color, metal=0.0, rough=0.8, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 6.0
    return m

STONE = mat("stone", (0.32, 0.31, 0.3), rough=0.95)
WOOD = mat("wood", (0.18, 0.11, 0.06), rough=0.9)
IRON = mat("iron", (0.12, 0.12, 0.13), metal=0.9, rough=0.45)
STEEL = mat("steel", (0.55, 0.56, 0.6), metal=1.0, rough=0.25)
LEATHER = mat("leather", (0.2, 0.09, 0.05), rough=0.7)
EMBER = mat("ember", (1.0, 0.35, 0.05), emit=(1.0, 0.35, 0.05))
SEED = mat("seed_glow", (1.0, 0.45, 0.1), emit=(1.0, 0.5, 0.1))

def reset():
    # delete objects only: a factory reset would also delete the shared materials
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)

def add(obj, m):
    obj.data.materials.clear()
    obj.data.materials.append(m)
    return obj

def cube(size, loc=(0, 0, 0), rot=(0, 0, 0), m=STONE, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("b", "BEVEL"); mod.width = bevel; mod.segments = 2
    return add(o, m)

def cyl(r, h, loc=(0, 0, 0), rot=(0, 0, 0), m=STONE, verts=16, r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=h, location=loc, rotation=rot)
    return add(bpy.context.object, m)

def rough_up(o, amount=0.04, seed=1):
    """Cut the shape into a few more faces and jitter them so stone looks hand-cut, not CAD."""
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    rnd = random.Random(seed)
    for v in bm.verts:
        v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * amount
    bm.to_mesh(o.data); bm.free()
    return o

def finish(name):
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            bpy.context.view_layer.objects.active = o
            for mod in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            o.select_set(True)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
            bpy.ops.object.mode_set(mode="OBJECT")
            bpy.ops.object.shade_flat()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_apply=True)
    print("EXPORTED", name)

# ---- Bonfire: stone ring, charred logs, embers, a sword driven into the ash
reset()
for i in range(9):
    a = i / 9 * math.tau
    s = cube((0.32, 0.26, 0.2), loc=(math.cos(a) * 0.62, math.sin(a) * 0.62, 0.08), rot=(0, 0, a + random.uniform(-0.3, 0.3)), m=STONE)
    rough_up(s, 0.035, i)
cyl(0.5, 0.06, loc=(0, 0, 0.02), m=mat("ash", (0.06, 0.055, 0.05), rough=1.0), verts=12)
for i in range(5):
    a = i / 5 * math.tau
    cyl(0.06, 0.8, loc=(math.cos(a) * 0.18, math.sin(a) * 0.18, 0.2), rot=(math.radians(60), 0, a + math.pi / 2), m=WOOD, verts=7)
for i in range(6):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.04, 0.08), location=(random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), 0.08))
    add(bpy.context.object, EMBER)
cube((0.06, 0.012, 1.1), loc=(0, 0, 0.62), rot=(0.12, 0.05, 0.4), m=STEEL)      # blade
cube((0.32, 0.05, 0.05), loc=(0.05, 0.02, 1.18), rot=(0.12, 0.05, 0.4), m=IRON)  # crossguard
cyl(0.025, 0.24, loc=(0.07, 0.03, 1.33), rot=(0.12, 0.05, 0.4), m=LEATHER, verts=8)
finish("bonfire")

# ---- Broken column with a jagged top and fallen chunk
reset()
col = cyl(0.55, 3.4, loc=(0, 0, 1.7), m=STONE, verts=12)
bm = bmesh.new(); bm.from_mesh(col.data)
for v in bm.verts:
    if v.co.z > 1.6:
        v.co.z += random.uniform(-0.7, 0.1)
bm.to_mesh(col.data); bm.free()
rough_up(col, 0.03, 2)
cube((1.4, 1.4, 0.35), loc=(0, 0, 0.17), m=STONE, bevel=0.04)
rough_up(cube((0.9, 0.7, 0.5), loc=(1.2, 0.5, 0.25), rot=(0.3, 0.2, 0.7), m=STONE), 0.06, 5)
finish("column_broken")

# ---- Stone archway with an iron portcullis
reset()
for x in (-1.8, 1.8):
    rough_up(cube((0.8, 0.9, 4.0), loc=(x, 0, 2.0), m=STONE), 0.03, int(x * 10))
for i in range(11):
    a = math.pi * i / 10
    rough_up(cube((0.75, 0.9, 0.55), loc=(math.cos(a) * 2.0, 0, 4.0 + math.sin(a) * 1.4), rot=(0, -a + math.pi / 2, 0), m=STONE), 0.02, 30 + i)
for x in [-1.2 + i * 0.3 for i in range(9)]:
    cyl(0.04, 3.6, loc=(x, 0, 1.9), m=IRON, verts=6)
for z in (0.6, 1.8, 3.0):
    cube((2.6, 0.08, 0.08), loc=(0, 0, z), m=IRON)
finish("archway_gate")

# ---- Tombstones and a leaning cross
reset()
for i, (x, rot) in enumerate([(-1.2, 0.08), (0, -0.15), (1.2, 0.2)]):
    t = cube((0.6, 0.18, 0.9), loc=(x, 0, 0.42), rot=(rot, 0, random.uniform(-0.2, 0.2)), m=STONE, bevel=0.05)
    rough_up(t, 0.02, 40 + i)
    cube((0.8, 0.5, 0.08), loc=(x, 0.3, 0.02), m=mat("dirt", (0.09, 0.07, 0.05), rough=1.0))
cube((0.12, 0.12, 1.3), loc=(2.4, 0, 0.6), rot=(0.25, 0, 0), m=STONE)
cube((0.6, 0.12, 0.12), loc=(2.4, -0.08, 0.95), rot=(0.25, 0, 0), m=STONE)
finish("graves")

# ---- Wall torch sconce
reset()
cube((0.25, 0.08, 0.35), loc=(0, 0, 0), m=IRON, bevel=0.01)
cube((0.05, 0.35, 0.05), loc=(0, 0.17, 0.05), m=IRON)
cyl(0.09, 0.12, loc=(0, 0.35, 0.12), m=IRON, verts=8, r2=0.13)
cyl(0.035, 0.55, loc=(0, 0.35, 0.3), m=WOOD, verts=7)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.09, location=(0, 0.35, 0.6)); add(bpy.context.object, EMBER)
finish("torch_sconce")

# ---- Ruined wall segment
reset()
for row in range(6):
    for c in range(7):
        if row > 2 and c > 5 - row // 1.5:
            continue
        off = 0.3 if row % 2 else 0.0
        b = cube((0.58, 0.5, 0.36), loc=(-1.8 + c * 0.6 + off, 0, 0.19 + row * 0.37), m=STONE, bevel=0.03)
        rough_up(b, 0.02, row * 10 + c)
finish("wall_ruin")

# ---- Seed shrine: stepped pedestal with a glowing Seed
reset()
for i, s in enumerate((1.6, 1.2, 0.8)):
    rough_up(cube((s, s, 0.3), loc=(0, 0, 0.15 + i * 0.3), m=STONE, bevel=0.03), 0.015, 70 + i)
cyl(0.18, 0.9, loc=(0, 0, 1.35), m=STONE, verts=8, r2=0.3)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.14, location=(0, 0, 1.95)); s = bpy.context.object; s.scale = (1, 1, 1.35); add(s, SEED)
cyl(0.015, 0.2, loc=(0.04, 0, 2.18), rot=(0, 0.5, 0), m=mat("leaf", (0.1, 0.35, 0.08), rough=0.7), verts=5)
finish("seed_shrine")

# ---- Longsword (origin at the grip, blade along +Y)
reset()
blade = cube((0.06, 1.0, 0.012), loc=(0, 0.62, 0), m=STEEL)
bm = bmesh.new(); bm.from_mesh(blade.data)
for v in bm.verts:
    if v.co.y > 0.45:
        v.co.x *= 0.15
bm.to_mesh(blade.data); bm.free()
cube((0.28, 0.04, 0.04), loc=(0, 0.1, 0), m=IRON, bevel=0.008)
cyl(0.022, 0.22, loc=(0, -0.02, 0), rot=(math.pi / 2, 0, 0), m=LEATHER, verts=8)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.035, location=(0, -0.14, 0)); add(bpy.context.object, IRON)
finish("longsword")

# ---- Heater shield
reset()
bm = bmesh.new()
pts = [(-0.3, 0.35), (0.3, 0.35), (0.3, 0.0), (0.18, -0.28), (0, -0.42), (-0.18, -0.28), (-0.3, 0.0)]
f = bm.faces.new([bm.verts.new((x, 0, z)) for x, z in pts])
bmesh.ops.extrude_face_region(bm, geom=[f])
for v in bm.verts[len(pts):]:
    v.co.y -= 0.04
me = bpy.data.meshes.new("shield"); bm.to_mesh(me); bm.free()
o = bpy.data.objects.new("shield", me); bpy.context.collection.objects.link(o); add(o, IRON)
cube((0.06, 0.02, 0.62), loc=(0, 0.012, -0.02), m=STEEL)
cube((0.5, 0.02, 0.06), loc=(0, 0.012, 0.12), m=STEEL)
finish("shield")
