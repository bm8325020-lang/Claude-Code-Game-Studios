# PROTOTYPE - NOT FOR PRODUCTION
# The open island around the walled ruins: heightmap terrain, sea, scattered pines and rocks.
# height() is the single source of ground height for the mesh, the collision and enemy feet.
extends Node3D

const SIZE := 440.0  # metres, square, centred on the ruins
const STEP := 2.0  # grid spacing
const SEA := -1.6
const RUINS := Rect2(-27, -49, 54, 86)  # walled area (x, z), kept flat
const PEAK := Vector2(0, -175)  # Pico do Dragao

var noise := FastNoiseLite.new()
var flats: Array = []

func _init() -> void:
	noise.seed = 11
	noise.frequency = 0.007
	noise.fractal_octaves = 4

func height(x: float, z: float) -> float:
	var d := Vector2(x, z + 10).length() / (SIZE * 0.47)
	var h := noise.get_noise_2d(x, z) * 13.0 + 3.0
	h += 48.0 * exp(-Vector2(x, z).distance_squared_to(PEAK) / (2.0 * 42.0 * 42.0))
	h = lerpf(h, SEA - 4.0, smoothstep(0.78, 1.0, d))  # island edge drops into the sea
	# flatten the ruins and the camps, blending over 14 m
	var gx := maxf(maxf(RUINS.position.x - x, x - RUINS.end.x), 0.0)
	var gz := maxf(maxf(RUINS.position.y - z, z - RUINS.end.y), 0.0)
	h = lerpf(-0.05, h, smoothstep(0.0, 14.0, Vector2(gx, gz).length()))
	for f in flats:
		h = lerpf(f[2], h, smoothstep(f[1], f[1] + 8.0, Vector2(x, z).distance_to(f[0])))
	return h

# flat round spot at the current ground height (call before build)
func flatten(c: Vector2, r: float) -> float:
	var y := height(c.x, c.y)
	flats.append([c, r, y])
	return y

func build(ground_mat: Material, sea_mat: Material) -> void:
	var n := int(SIZE / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := SIZE / 2.0
	for j in n:
		for i in n:
			heights[j * n + i] = height(-half + i * STEP, -half + j * STEP)
	for j in n:
		for i in n:
			st.add_vertex(Vector3(-half + i * STEP, heights[j * n + i], -half + j * STEP))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ground_mat
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(STEP, 1, STEP)
	body.add_child(cs)
	add_child(body)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE * 3, SIZE * 3)
	sea.mesh = pm
	sea.position.y = SEA
	sea.material_override = sea_mat
	add_child(sea)

# scatter one model many times as a MultiMesh; keep(p) says whether a spot is allowed
func scatter(mesh: Mesh, count: int, area: Rect2, scale_range: Vector2, keep: Callable, seed := 1) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xf := []
	var tries := 0
	while xf.size() < count and tries < count * 20:
		tries += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var y := height(p.x, p.y)
		if y < SEA + 0.6 or not keep.call(p, y):
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y - 0.1, p.y)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi
