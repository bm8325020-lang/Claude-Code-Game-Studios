# PROTOTYPE - NOT FOR PRODUCTION
# Dead trees (twisted bare branches) and dark pines for the island, one single-material GLB each.
# usage: blender -b --python make_trees.py -- <out_dir>
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

def mat(name, color, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    return m

BARK = mat("bark", (0.11, 0.09, 0.08))
NEEDLES = mat("needles", (0.06, 0.1, 0.07))

def tube(bm, a, b, r0, r1, sides=4):
    """Tapered closed tube from a to b."""
    axis = (b - a).normalized()
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 0.01:
        side = axis.cross(Vector((1, 0, 0)))
    side.normalize()
    up = axis.cross(side)
    rings = []
    for p, r in ((a, r0), (b, r1)):
        rings.append([bm.verts.new(p + (side * math.cos(t) + up * math.sin(t)) * r)
                      for t in (i / sides * math.tau for i in range(sides))])
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[1])

def cone(bm, base, h, r, sides, rnd):
    ring = [bm.verts.new(base + Vector((math.cos(t) * r * rnd.uniform(0.8, 1.15), math.sin(t) * r * rnd.uniform(0.8, 1.15), rnd.uniform(-0.25, 0.05) * r)))
            for t in (i / sides * math.tau for i in range(sides))]
    tip = bm.verts.new(base + Vector((rnd.uniform(-0.1, 0.1) * r, rnd.uniform(-0.1, 0.1) * r, h)))
    for i in range(sides):
        bm.faces.new((ring[i], ring[(i + 1) % sides], tip))
    bm.faces.new(list(reversed(ring)))

def branch(bm, start, d, length, r, depth, rnd):
    # a slightly crooked limb in three segments
    p = start
    for s in range(3):
        d = (d + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(-0.1, 0.25)))).normalized()
        q = p + d * length / 3
        tube(bm, p, q, r * (1 - s / 3.5), r * (1 - (s + 1) / 3.5))
        if depth > 0 and s >= 1:
            for _ in range(2):
                nd = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.6)))).normalized()
                branch(bm, q, nd, length * rnd.uniform(0.45, 0.65), r * 0.45, depth - 1, rnd)
            break  # one fork per limb keeps the tree under ~300 triangles for phones
        p = q

def export(name, bm, m):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(m)
    for poly in me.polygons:
        poly.use_smooth = False
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB")
    print("EXPORTED", name)

for k in range(3):
    rnd = random.Random(20 + k)
    bm = bmesh.new()
    branch(bm, Vector((0, 0, 0)), Vector((0, 0, 1)), rnd.uniform(5.5, 7.5), 0.28, 2, rnd)
    for _ in range(4):  # root flare
        a = rnd.uniform(0, math.tau)
        tube(bm, Vector((0, 0, 0.5)), Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, -0.2)), 0.16, 0.04, 5)
    export("dead_tree_%d" % (k + 1), bm, BARK)

for k in range(2):
    rnd = random.Random(40 + k)
    bm = bmesh.new()
    h = rnd.uniform(9, 12)
    tube(bm, Vector((0, 0, -0.2)), Vector((0, 0, h * 0.4)), 0.25, 0.12, 6)
    tiers = 6
    for t in range(tiers):
        z = h * (0.18 + 0.13 * t)
        cone(bm, Vector((0, 0, z)), h * 0.28, (1 - t / tiers) * 2.4 + 0.4, 9, rnd)
    export("pine_%d" % (k + 1), bm, NEEDLES)
