# PROTOTYPE - NOT FOR PRODUCTION
# Modular dark-fantasy architecture for Cinzarra (level.gd): walls, parapets, church walls, timber houses,
# ruined towers, beams, stair steps, the belfry and rock cliffs. One GLB per piece, origin at the bottom centre.
# Material names (stone, plaster, wood, roof, dark, iron, rock) are swapped for the level's textured materials in Godot,
# so the colours here only matter for the preview sheet. Pieces are authored at a base size and stretched to fit.
# usage: blender -b --python make_architecture.py -- <out_dir>
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, noise

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

def mat(name, color, metal=0.0, rough=0.9):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m

STONE = mat("stone", (0.33, 0.32, 0.3))
PLASTER = mat("plaster", (0.55, 0.5, 0.42))
WOOD = mat("wood", (0.16, 0.1, 0.06))
ROOF = mat("roof", (0.2, 0.17, 0.17))
DARK = mat("dark", (0.02, 0.02, 0.025))
IRON = mat("iron", (0.1, 0.1, 0.11), metal=0.8, rough=0.5)
ROCK = mat("rock", (0.3, 0.28, 0.26))

parts = []

def reset():
    parts.clear()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)

def _keep(o, m, bevel):
    o.data.materials.clear()
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "NONE"
    parts.append(o)
    return o

def box(size, loc, m=STONE, bevel=0.04, rot=(0, 0, 0)):
    """Box by size (x, y, z) with its centre at loc; a small chamfer catches the light like cut stone."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _keep(o, m, bevel)

def prism(outline, depth, y, m=STONE, bevel=0.0):
    """Extrude a convex outline [(x, z)...] drawn on the wall face, depth along y, centred on y."""
    me = bpy.data.meshes.new("p")
    bm = bmesh.new()
    front = [bm.verts.new((x, y - depth / 2, z)) for x, z in outline]
    back = [bm.verts.new((x, y + depth / 2, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("p", me)
    bpy.context.collection.objects.link(o)
    return _keep(o, m, bevel)

def lancet(w, h, spring, steps=4):
    """Pointed (gothic) arch outline, base at z=0, width w, total height h, the arc starting at z=spring."""
    pts = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, spring)]
    for i in range(1, steps):
        t = i / steps
        pts.append((w / 2 * math.cos(t * math.pi / 2) ** 0.8, spring + (h - spring) * math.sin(t * math.pi / 2)))
    pts.append((0.0, h))
    for x, z in reversed(pts[3:-1]):
        pts.append((-x, z))
    pts.append((-w / 2, spring))
    return pts

def gable(w, d, h, z0, m=ROOF, over=0.5, courses=4):
    """Steep gabled roof as overlapping tile courses (each a tilted slab), ridge along x."""
    half = d / 2 + over
    slope = math.atan2(h, half)
    run = math.hypot(half, h)
    for side in (-1, 1):
        for c in range(courses):
            t0 = c / courses
            seg = run / courses + 0.18
            mid = (t0 + 0.5 / courses) * run
            cy = side * (half - math.cos(slope) * mid)
            cz = z0 + math.sin(slope) * mid + 0.06 * (courses - c)
            box((w + over * 2, seg, 0.16), (0, cy, cz), m, 0.0, (-side * slope, 0, 0))
    box((w + over * 2 + 0.1, 0.35, 0.3), (0, 0, z0 + h + 0.12), WOOD, 0.03)  # ridge beam

def export(name):
    for o in parts:
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    for poly in o.data.polygons:
        poly.use_smooth = False
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("EXPORTED", name, tris, "tris")
    reset()

# --- wall_4: 4 m run of castle wall, 4 m tall, 1 m thick, with a buttress at one end -----------------------------
def wall():
    box((4.0, 1.1, 0.5), (0, 0, 0.25))  # plinth
    for i, (z0, z1, d) in enumerate(((0.5, 1.6, 0.92), (1.6, 2.7, 0.86), (2.7, 3.7, 0.92))):  # stone courses
        box((4.0, d, z1 - z0), (0, 0, (z0 + z1) / 2), STONE, 0.05)
    box((4.1, 1.08, 0.3), (0, 0, 3.85), STONE, 0.05)  # coping
    box((0.7, 1.5, 2.2), (-1.65, 0, 1.1), STONE, 0.06)  # buttress, stepped
    box((0.6, 1.25, 1.6), (-1.65, 0, 2.9), STONE, 0.06)
    for x in (-0.4, 1.1):
        box((0.22, 0.95, 0.5), (x, 0, 2.05), DARK, 0.0)  # arrow slits
    export("wall_4")

# --- parapet_4: 4 m run, 2 m tall, crenellated -------------------------------------------------------------------
def parapet():
    box((4.0, 1.15, 0.35), (0, 0, 0.175))
    box((4.0, 0.9, 1.05), (0, 0, 0.875), STONE, 0.05)
    box((4.1, 1.05, 0.2), (0, 0, 1.45), STONE, 0.04)
    for x in (-1.25, 0.75):
        box((1.1, 0.9, 0.5), (x, 0, 1.8), STONE, 0.05)
    box((0.5, 1.3, 1.55), (1.75, 0, 0.775), STONE, 0.05)  # little pier every 4 m
    export("parapet_4")

# --- church_wall_4: 4 m run, 12 m tall, a lancet window and a two-stage buttress ---------------------------------
def church_wall():
    box((4.0, 1.2, 0.8), (0, 0, 0.4))
    box((4.0, 0.9, 10.6), (0, 0, 6.1), STONE, 0.05)
    box((4.15, 1.15, 0.6), (0, 0, 11.7), STONE, 0.05)  # cornice
    box((4.05, 1.0, 0.25), (0, 0, 3.0), STONE, 0.04)  # string course
    win = lancet(1.3, 5.2, 3.6)
    prism([(x, z + 4.2) for x, z in lancet(1.8, 6.0, 4.0)], 1.0, 0.0, STONE, 0.03)  # window frame
    prism([(x, z + 4.6) for x, z in win], 1.06, 0.0, DARK)
    box((0.08, 1.08, 5.0), (0, 0, 7.1), IRON, 0.0)  # mullion
    box((1.0, 1.9, 4.5), (-1.55, 0, 2.25), STONE, 0.06)  # buttress
    box((0.8, 1.6, 4.0), (-1.55, 0, 6.5), STONE, 0.06)
    box((0.6, 1.3, 2.6), (-1.55, 0, 9.8), STONE, 0.06)
    prism([(-1.85, 11.1), (-1.25, 11.1), (-1.55, 12.6)], 1.3, 0.0, STONE)  # pinnacle
    export("church_wall_4")

# --- house: 10 x 8 m, 8 m to the eaves; stone ground floor, jettied timber-framed upper floor, tiled gable ---------
def house(flat=False):
    w, d, h1, h = 10.0, 8.0, 3.4, 8.0
    box((w, d, h1), (0, 0, h1 / 2), STONE, 0.06)
    box((w + 0.5, d + 0.5, h - h1), (0, 0, (h1 + h) / 2), PLASTER, 0.0)  # jetty: upper floor overhangs
    box((w + 0.7, d + 0.7, 0.3), (0, 0, h1 + 0.1), WOOD, 0.03)  # floor beam
    box((w + 0.7, d + 0.7, 0.3), (0, 0, h - 0.1), WOOD, 0.03)  # wall plate
    fy, sx = d / 2 + 0.3, w / 2 + 0.3
    for x in (-5.0, -2.5, 0.0, 2.5, 5.0):  # posts on the long faces
        for s in (-1, 1):
            box((0.28, 0.12, h - h1), (min(max(x, -sx + 0.1), sx - 0.1), s * fy, (h1 + h) / 2), WOOD, 0.0)
    for y in (-4.0, -1.3, 1.3, 4.0):  # posts on the gable ends
        for s in (-1, 1):
            box((0.12, 0.28, h - h1), (s * sx, min(max(y, -fy + 0.1), fy - 0.1), (h1 + h) / 2), WOOD, 0.0)
    for x0, s in ((-3.75, 1), (3.75, -1)):  # braces
        for side in (-1, 1):
            box((0.22, 0.12, 3.4), (x0, side * fy, (h1 + h) / 2), WOOD, 0.0, (0, s * 0.62, 0))
    for x in (-1.25, 1.25):  # upper windows with shutters
        for side in (-1, 1):
            box((1.0, 0.16, 1.3), (x, side * (fy + 0.02), h1 + 2.4), DARK, 0.0)
            box((0.5, 0.1, 1.4), (x - 0.78, side * (fy + 0.06), h1 + 2.4), WOOD, 0.02, (0, 0, side * 0.35))
    door = lancet(1.6, 2.7, 1.9)
    prism(door, 0.3, -d / 2 - 0.05, WOOD)  # front door (-y becomes +z in Godot)
    prism([(x * 1.25, z - 0.05) for x, z in door], 0.2, -d / 2 + 0.02, STONE, 0.02)
    box((1.0, 0.2, 1.0), (3.2, -d / 2 - 0.02, 1.7), DARK, 0.0)
    box((1.2, 0.3, 0.15), (3.2, -d / 2 - 0.05, 1.15), STONE, 0.02)
    if flat:  # watch house: crenellated flat roof for the crossbowmen
        box((w + 0.6, d + 0.6, 0.4), (0, 0, h + 0.2), STONE, 0.04)
        for s in (-1, 1):
            box((w + 0.6, 0.5, 0.7), (0, s * (d / 2 + 0.05), h + 0.75), STONE, 0.04)
            box((0.5, d + 0.6, 0.7), (s * (w / 2 + 0.05), 0, h + 0.75), STONE, 0.04)
        for x in (-4.0, -1.3, 1.3, 4.0):
            for s in (-1, 1):
                box((0.9, 0.5, 0.5), (x, s * (d / 2 + 0.05), h + 1.35), STONE, 0.04)
        export("house_watch")
    else:
        gable(w, d, 4.2, h)
        tri =[(-d / 2 - 0.25, h), (d / 2 + 0.25, h), (0, h + 4.0)]
        for s in (-1, 1):
            me = prism([(y, z) for y, z in tri], 0.25, 0, PLASTER)
            me.rotation_euler = (0, 0, math.pi / 2)
            me.location = (s * (w / 2 + 0.12), 0, 0)
            bpy.context.view_layer.objects.active = me
            me.select_set(True)
            bpy.ops.object.transform_apply(location=True, rotation=True)
            me.select_set(False)
        box((0.9, 0.9, 2.6), (2.8, 1.4, h + 3.3), STONE, 0.05)  # chimney
        box((1.1, 1.1, 0.2), (2.8, 1.4, h + 4.6), STONE, 0.03)
        export("house")

# --- ruin_tower: 4 x 4 m, 10 m; quoined corners, slits, a broken cornice. Its top is flat for parkour ---------------
def ruin_tower():
    rnd = random.Random(3)
    box((4.0, 4.0, 10.0), (0, 0, 5.0), STONE, 0.05)
    for cx in (-1, 1):
        for cy in (-1, 1):
            for k in range(6):  # alternating long and short corner stones
                lx, ly = (0.9, 0.5) if k % 2 else (0.5, 0.9)
                box((lx, ly, 1.2), (cx * (2.0 - lx / 2 + 0.08), cy * (2.0 - ly / 2 + 0.08), 0.8 + k * 1.6), STONE, 0.05)
    for z in (3.5, 7.0):
        for s in (-1, 1):
            box((0.3, 4.06, 1.1), (s * 0.6, 0, z), DARK, 0.0)
    box((4.35, 4.35, 0.35), (0, 0, 9.83), STONE, 0.04)
    for i in range(5):  # rubble on the cornice edges
        a = rnd.uniform(0, math.tau)
        box((rnd.uniform(0.3, 0.6),) * 3, (math.cos(a) * 1.9, math.sin(a) * 1.9, 10.1), STONE, 0.06, (rnd.random(), rnd.random(), rnd.random()))
    export("ruin_tower")

# --- beam: 1 x 1 x 1 timber with iron straps (stretched to fit) --------------------------------------------------
def beam():
    box((1.0, 1.0, 1.0), (0, 0, 0.5), WOOD, 0.08)
    for y in (-0.38, 0.38):
        box((1.06, 0.08, 1.06), (0, y, 0.5), IRON, 0.0)
    export("beam")

# --- step: 1 x 1 x 1 stair step with a rounded nose ---------------------------------------------------------------
def step():
    box((1.0, 1.0, 0.85), (0, 0.04, 0.425), STONE, 0.05)
    box((1.0, 0.25, 0.25), (0, -0.4, 0.86), STONE, 0.08)
    for x in (-0.5, 0.5):
        box((0.14, 1.05, 1.02), (x, 0.02, 0.5), STONE, 0.04)  # cheek stones
    export("step")

# --- belfry: 7 x 7 m open bell chamber with pointed arches and a slate spire --------------------------------------
def belfry():
    box((7.0, 7.0, 0.5), (0, 0, 0.25), STONE, 0.05)
    for cx in (-1, 1):
        for cy in (-1, 1):
            box((1.0, 1.0, 5.0), (cx * 3.0, cy * 3.0, 3.0), STONE, 0.05)
    for s in (-1, 1):
        arch = [(x, z + 0.5) for x, z in lancet(5.0, 4.7, 3.0)]
        frame = [(-3.5, 0.5), (3.5, 0.5), (3.5, 5.5), (-3.5, 5.5)]
        prism(frame, 0.4, s * 3.3, STONE, 0.0)
        prism(arch, 0.44, s * 3.3, DARK, 0.0)
        for o in (prism(frame, 0.4, 0, STONE), prism(arch, 0.44, 0, DARK)):
            o.rotation_euler = (0, 0, math.pi / 2)
            o.location = (s * 3.3, 0, 0)
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            bpy.ops.object.transform_apply(location=True, rotation=True)
            o.select_set(False)
    box((7.6, 7.6, 0.5), (0, 0, 5.75), STONE, 0.05)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=5.2, radius2=0.0, depth=6.5, location=(0, 0, 9.25), rotation=(0, 0, math.pi / 4))
    _keep(bpy.context.object, ROOF, 0.0)
    for cx in (-1, 1):
        for cy in (-1, 1):
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.6, radius2=0.0, depth=1.8, location=(cx * 3.4, cy * 3.4, 6.9), rotation=(0, 0, math.pi / 4))
            _keep(bpy.context.object, ROOF, 0.0)
    box((0.1, 0.1, 1.4), (0, 0, 13.1), IRON, 0.0)
    box((0.7, 0.1, 0.1), (0, 0, 13.4), IRON, 0.0)
    export("belfry")

# --- cliff: rough rock mass, 1 x 1 x 1 with a flat top, tapering a little toward the bottom ------------------------
def cliff(seed):
    me = bpy.data.meshes.new("c")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    off = Vector((seed * 7.1, seed * 3.3, seed * 1.7))
    for v in bm.verts:
        p = v.co.copy()
        z = p.z + 0.5  # 0 bottom .. 1 top
        if z > 0.99:  # keep the top flat and inside the floor slab it sits under
            v.co.x *= 0.97
            v.co.y *= 0.97
            continue
        n = noise.noise(p * 3.0 + off)
        taper = 0.8 + 0.2 * z
        v.co.x = p.x * taper * (1.0 + 0.12 * n)
        v.co.y = p.y * taper * (1.0 + 0.12 * noise.noise(p * 3.0 + off + Vector((5, 5, 5))))
        v.co.z = p.z + 0.04 * n
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("c", me)
    bpy.context.collection.objects.link(o)
    o.location.z = 0.5
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True)
    o.select_set(False)
    _keep(o, ROCK, 0.0)
    export("cliff")

reset()
wall()
parapet()
church_wall()
house()
house(flat=True)
ruin_tower()
beam()
step()
belfry()
cliff(1)
