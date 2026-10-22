# PROTOTYPE - NOT FOR PRODUCTION
# The first souls loop of Cinzarra (design/levels/mapa-oficial.md):
# Santuário da Chama (y 0) -> great stair -> Burgo dos Esquecidos (y 15) -> Telhados Quebrados (parkour,
# y 15..30, with the Becos alley below at y 8) -> Igreja do Juramento (y 30) -> elevator shortcut back down.
extends RefCounted

const FALL_DEATH_Y := -40.0
const BURGO_Y := 15.0
const ALLEY_Y := 8.0
const CHURCH_Y := 30.0
const ELEVATOR := Vector3(-21.0, 0.0, 2.0)  # shaft column (x, z); the platform runs y 0 <-> 30
const GRAVE_Y := -3.0  # the cemetery floor, east of the shrine and below it

# --- terrain: a valley ringed by mountains; every area is a flattened shelf of it, joined by ramps and cliffs
const T_ORIGIN := Vector2(-170.0, -190.0)
const T_SIZE := 300.0
const T_STEP := 2.5
# [x0, z0, x1, z1, height, blend metres]
const FLATS := [
	[22.0, -28.0, 72.0, 28.0, GRAVE_Y - 0.4, 4.0],  # cemetery
	[-66.0, -49.0, -36.0, -3.0, ALLEY_Y - 0.6, 2.0],  # alley under the rooftops
	[-70.0, -100.0, 20.0, -48.0, BURGO_Y - 0.6, 3.0],  # Burgo
	[-26.0, -1.0, -14.0, 5.0, -0.8, 2.0],  # foot of the elevator shaft, beside the shrine
	[-62.0, -2.0, -26.0, 30.0, CHURCH_Y - 0.6, 2.0],  # church crag (the plaza overhangs its east edge, clear of the shaft)
]
# [from x, z, y, to x, z, y, half width]: the ground follows stairs and paths
const RAMPS := [
	[0.0, -12.0, -0.8, 0.0, -48.0, 14.2, 5.0],  # great stair
	[-67.5, -22.0, 7.2, -67.5, -54.0, 14.2, 3.0],  # alley stair
	[13.0, 0.0, -0.6, 24.0, 0.0, GRAVE_Y - 0.4, 3.5],  # path down to the cemetery
]

const BONFIRES := [
	[Vector3(0, 0, 0), "Santuário da Chama"],
	[Vector3(-24, BURGO_Y, -74), "Burgo dos Esquecidos"],
	[Vector3(-34, CHURCH_Y, 4), "Igreja do Juramento"],
]
# [position (y is the floor), kind]
const SPAWNS := [
	[Vector3(0, 6, -27), "minion"], [Vector3(1, 10, -36), "minion"],
	[Vector3(-20, BURGO_Y, -66), "warrior"], [Vector3(-30, BURGO_Y, -80), "minion"], [Vector3(5, BURGO_Y, -78), "rogue"],
	[Vector3(-30, 25, -58), "archer"], [Vector3(0, 24, -94), "archer"], [Vector3(-50, BURGO_Y, -72), "minion"],
	[Vector3(10, BURGO_Y, -62), "warrior"], [Vector3(-45, BURGO_Y, -85), "caster"],
	[Vector3(-55, ALLEY_Y, -30), "minion"], [Vector3(-48, ALLEY_Y, -15), "rogue"], [Vector3(-60, ALLEY_Y, -40), "warrior"],
	[Vector3(-56, 27, -10), "archer"],
	[Vector3(-36, CHURCH_Y, 10), "warrior"], [Vector3(-28, CHURCH_Y, 22), "caster"], [Vector3(-40, CHURCH_Y, 27), "rogue"],
	[Vector3(-53, CHURCH_Y, 11), "sentinel"], [Vector3(-53, CHURCH_Y, 19), "sentinel"],
	# Cemitério dos Juramentados (east, below the shrine): strong for this early, the souls-style warning
	[Vector3(34, GRAVE_Y, -8), "warrior"], [Vector3(42, GRAVE_Y, 8), "caster"], [Vector3(52, GRAVE_Y, -14), "warrior"],
	[Vector3(58, GRAVE_Y, 12), "minion"], [Vector3(48, GRAVE_Y, 20), "rogue"],
	# Jardim Morto (the forest in the valley): ash wolves
	[Vector3(8, -10, 42), "wolf"], [Vector3(16, -10, 48), "wolf"], [Vector3(-14, -10, 52), "wolf"], [Vector3(-40, -10, 60), "wolf"],
]
const BREAKABLES := [
	[Vector3(-14, BURGO_Y, -70), "Barrel", 1.1], [Vector3(-15, BURGO_Y, -71.4), "Vase_Large", 1.1], [Vector3(-36, BURGO_Y, -88), "Jar01_Art", 0.9],
	[Vector3(8, BURGO_Y, -84), "SmallBarrel_Art", 0.8], [Vector3(-52, BURGO_Y, -60), "Vase_Mid", 0.9], [Vector3(-64, ALLEY_Y, -12), "Barrel", 1.1],
	[Vector3(-63, ALLEY_Y, -10.6), "Jar02_Art", 1.0], [Vector3(-26, CHURCH_Y, 12), "Vase_Large", 1.1], [Vector3(-26, CHURCH_Y, 13.4), "Vase_Small", 0.7],
]
const SHARDS := [Vector3(-62, ALLEY_Y + 0.6, -6), Vector3(-40, 22.1, -26), Vector3(62, GRAVE_Y + 0.6, -20)]
# parkour: [centre x, top y, centre z, size x, size z, from-the-alley pillar?]
const ROOFTOPS := [
	[-60.0, 16.2, -44.0, 6.0, 5.0, true], [-60.0, 17.0, -38.5, 1.2, 4.0, false], [-58.0, 18.0, -32.0, 6.0, 6.0, true],
	[-52.0, 19.0, -28.0, 4.0, 4.0, true], [-46.0, 19.5, -28.0, 4.0, 1.0, false], [-40.0, 21.5, -26.0, 5.0, 6.0, true],
	[-40.0, 22.0, -19.5, 1.0, 5.0, false], [-44.0, 23.5, -13.0, 5.0, 5.0, true], [-50.0, 25.5, -12.0, 3.0, 3.0, true],
	[-56.0, 27.0, -10.0, 5.0, 5.0, true], [-56.0, 28.5, -3.0, 4.0, 4.0, true],
]
const HOUSES := [  # Burgo: [x, z, width, depth, height]
	[-60, -56, 10, 8, 9], [-45, -56, 8, 8, 7], [-30, -58, 9, 10, 10], [5, -56, 10, 8, 8], [14, -72, 8, 12, 9],
	[-60, -92, 10, 10, 8], [-40, -94, 12, 8, 11], [-18, -92, 8, 8, 7], [0, -94, 10, 10, 9], [14, -90, 8, 10, 8],
]

# [position, facing yaw]: lights the way and gives each area warm landmarks
const TORCHES := [
	[Vector3(-3.5, BURGO_Y + 2.2, -49.2), PI], [Vector3(3.5, BURGO_Y + 2.2, -49.2), PI], [Vector3(-25, BURGO_Y + 2.6, -99.8), 0.0],
	[Vector3(19.8, BURGO_Y + 2.6, -74), -PI / 2.0], [Vector3(-69.8, BURGO_Y + 2.6, -80), PI / 2.0], [Vector3(-36, BURGO_Y + 2.6, -59.5), PI],
	[Vector3(-65.2, ALLEY_Y + 2.4, -30), PI / 2.0], [Vector3(-36.8, ALLEY_Y + 2.4, -20), -PI / 2.0],
	[Vector3(-43.3, CHURCH_Y + 3.0, 11.5), -PI / 2.0], [Vector3(-43.3, CHURCH_Y + 3.0, 18.5), -PI / 2.0], [Vector3(-59.3, CHURCH_Y + 3.0, 15), PI / 2.0],
]

static var mats := {}
static var tnoise: FastNoiseLite
static var pieces := {}  # name -> ArrayMesh with the level's materials (assets/arch, tools/make_architecture.py)
static var batches := {}  # "piece|cell" -> [mesh, [Transform3D]]: every modelled piece is drawn through a few MultiMeshes
const MAT_OF := {"stone": "wall", "plaster": "plaster", "wood": "wood", "roof": "roof", "dark": "dark", "iron": "iron", "rock": "rock"}

# painted, untextured level material (paint.gdshader): a clean colour with soft patches; top = colour on up faces
static func _paint(c: Color, top := Color.WHITE, top_amount := 0.0, wobble := 0.12) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://paint.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("top_amount", top_amount)
	m.set_shader_parameter("wobble", wobble)
	return m

static func build(m: Node3D) -> void:
	mats = {
		"floor": _paint(Color(0.8, 0.66, 0.48), Color.WHITE, 0.0, 0.12),  # warm sandstone paving
		"wall": _paint(Color(0.93, 0.87, 0.74), Color(0.45, 0.7, 0.3), 0.5),  # cream stone with a little moss on top
		"rock": _paint(Color(0.62, 0.55, 0.47), Color(0.4, 0.72, 0.26), 1.0, 0.18),  # warm rock, grass on the ledges
		"roof": _paint(Color(0.78, 0.3, 0.2), Color.WHITE, 0.0, 0.1),  # terracotta
	}
	mats.wood = _paint(Color(0.55, 0.34, 0.18), Color.WHITE, 0.0, 0.15)
	mats.plaster = _paint(Color(0.98, 0.94, 0.85), Color.WHITE, 0.0, 0.06)
	mats.dark = _plain(Color(0.015, 0.012, 0.012), 1.0)
	mats.iron = _plain(Color(0.12, 0.12, 0.13), 0.5, 0.8)
	pieces = {}
	batches = {}
	tnoise = FastNoiseLite.new()  # the ground itself is streamed by world.gd, which reads ground_h here
	tnoise.seed = 5
	tnoise.frequency = 0.02
	tnoise.fractal_octaves = 3
	_sanctuary(m)
	_stair(m, Vector3(0, 0, -12), Vector3(0, BURGO_Y, -48), 6.0)
	_burgo(m)
	_rooftops(m)
	_church(m)
	_graveyard(m)
	_forest(m)
	for t in TORCHES:
		torch(m, t[0], t[1])
	for b in BONFIRES:
		m.bonfires.append([b[0], b[1]])
		m._prop("bonfire", b[0])
		var fire := OmniLight3D.new()
		fire.position = b[0] + Vector3(0, 0.9, 0)
		fire.light_color = Color(1, 0.5, 0.15)
		fire.light_energy = 3.0
		fire.omni_range = 10
		m.add_child(fire)
	m.bonfire_pos = BONFIRES[0][0]
	_flush(m)

static func _plain(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

# Kenney kit piece "kit/name" (assets/kenney): every mesh in the GLB merged into one ArrayMesh, one surface per
# source material, each drawn through kit_color.gdshader in its own bright colours
static var kit_mats := {}

static func _kit_mat(src: Material) -> ShaderMaterial:
	if not kit_mats.has(src):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://kit_color.gdshader")
		var std := src as StandardMaterial3D
		sm.set_shader_parameter("use_map", std != null and std.albedo_texture != null)
		if std != null:
			sm.set_shader_parameter("colormap", std.albedo_texture)
			sm.set_shader_parameter("base_color", std.albedo_color)
		kit_mats[src] = sm
	return kit_mats[src]

static func _kit_mesh(name: String) -> ArrayMesh:
	var mvk := name.begins_with("mvk/")  # Quaternius Medieval Village MegaKit: keep its own PBR materials
	var root: Node3D = load("res://assets/%s.gltf" % name).instantiate() if mvk else load("res://assets/kenney/%s.glb" % name).instantiate()
	var mis := root.find_children("*", "MeshInstance3D", true, false)
	if mvk and mis.size() == 1 and (mis[0] as MeshInstance3D).transform.is_equal_approx(Transform3D()) and mis[0].get_parent() == root:
		var lod := _coarse(mis[0].mesh)  # one mesh at the origin: keep it whole
		root.free()
		return lod
	var tools := {}  # source material -> SurfaceTool
	for mi in mis:
		var xf := Transform3D()
		var p: Node = mi
		while p != root:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var src_mesh: Mesh = mi.mesh
		for i in src_mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(i) if mi.get_surface_override_material(i) else src_mesh.surface_get_material(i)
			if not tools.has(src):
				tools[src] = SurfaceTool.new()
				tools[src].begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[src].append_from(src_mesh, i, xf)
	var mesh := ArrayMesh.new()
	# flat-coloured materials (the nature kit has many) become one vertex-coloured surface: one draw call per piece
	var vv := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	var ii := PackedInt32Array()
	for src in tools:
		var std := src as StandardMaterial3D
		if mvk or (std != null and std.albedo_texture != null):
			tools[src].commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, src if mvk else _kit_mat(src))
			continue
		var arr: Array = tools[src].commit_to_arrays()
		var base := vv.size()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		vv.append_array(verts)
		nn.append_array(arr[Mesh.ARRAY_NORMAL])
		var col: Color = std.albedo_color if std != null else Color.WHITE
		if name.begins_with("nature/") and col.s > 0.25 and col.h > 0.4 and col.h < 0.55:  # teal leaves: a fresh grass green
			col.h = 0.3
		for k in verts.size():
			cc.append(col)
		var idx = arr[Mesh.ARRAY_INDEX]
		for k in (range(verts.size()) if idx == null else Array(idx)):
			ii.append(base + k)
	if not vv.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vv
		arrays[Mesh.ARRAY_NORMAL] = nn
		arrays[Mesh.ARRAY_COLOR] = cc
		arrays[Mesh.ARRAY_INDEX] = ii
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _kit_vc_mat())
	root.free()
	return mesh

# the MegaKit models every roof tile and brick (a corner is 3100 triangles). From the importer's LODs take two: the
# finest whose edges stay under 30 cm for near houses, the coarsest for far ones (stored in far_pieces)
static var far_pieces := {}  # near ArrayMesh -> far ArrayMesh
static var mvk_mats := {}  # every glTF file has its own copy of the kit's few materials: share one per name

static func _coarse(src: Mesh) -> ArrayMesh:
	var near := ArrayMesh.new()
	var far := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var far_arrays := arrays.duplicate()
		var s: Dictionary = RenderingServer.mesh_get_surface(src.get_rid(), i)
		for l in s.get("lods", []):
			var data: PackedByteArray = l.index_data
			var idx := PackedInt32Array()
			if s.index_data.size() >= s.index_count * 4:  # 32-bit indices
				idx = data.to_int32_array()
			else:
				idx.resize(data.size() / 2)
				for k in idx.size():
					idx[k] = data.decode_u16(k * 2)
			if l.edge_length <= 0.3:
				arrays[Mesh.ARRAY_INDEX] = idx
			far_arrays[Mesh.ARRAY_INDEX] = idx
		var mat: Material = src.surface_get_material(i)
		if not mvk_mats.has(mat.resource_name):
			mvk_mats[mat.resource_name] = mat
		near.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		near.surface_set_material(i, mvk_mats[mat.resource_name])
		far.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, far_arrays)
		far.surface_set_material(i, mvk_mats[mat.resource_name])
	far_pieces[near] = far
	return near

static func _kit_vc_mat() -> ShaderMaterial:
	if not kit_mats.has("vc"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://kit_color.gdshader")
		sm.set_shader_parameter("use_map", false)
		sm.set_shader_parameter("use_vcolor", true)
		sm.set_shader_parameter("saturation", 1.15)  # foliage, flowers and rocks: bright and lively
		kit_mats["vc"] = sm
	return kit_mats["vc"]

# MegaKit plaster colours (multiplied over the kit's beige plaster): "mvk/Wall_...#k" is that wall painted PLASTER[k]
const PLASTER := [Color(1.4, 1.45, 1.55), Color(1.45, 1.4, 0.9), Color(1.45, 1.05, 1.1), Color(1.0, 1.25, 1.75),
	Color(1.05, 1.45, 1.25), Color(1.25, 1.1, 1.65)]

static func _painted(base: ArrayMesh, k: int) -> ArrayMesh:
	var mesh: ArrayMesh = base.duplicate()
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if mat.resource_name == "MI_Plaster":
			if not mvk_mats.has("MI_Plaster#%d" % k):
				var m: StandardMaterial3D = mat.duplicate()
				m.albedo_color = PLASTER[k]
				mvk_mats["MI_Plaster#%d" % k] = m
			mesh.surface_set_material(i, mvk_mats["MI_Plaster#%d" % k])
	return mesh

static func _piece(name: String) -> ArrayMesh:
	if not pieces.has(name) and name.contains("#"):
		var base := _piece(name.get_slice("#", 0))
		var k := int(name.get_slice("#", 1))
		pieces[name] = _painted(base, k)
		far_pieces[pieces[name]] = _painted(far_pieces.get(base, base), k)
	if not pieces.has(name) and name.contains("/"):
		pieces[name] = _kit_mesh(name)
		for plain in ["mvk/Wall_Plaster_Straight"]:  # far away a wall with windows is a plain wall
			if name != plain and name.begins_with(plain.trim_suffix("Straight")):
				far_pieces[pieces[name]] = far_pieces[_piece(plain)]
	if not pieces.has(name):
		var s: Node3D = load("res://assets/arch/%s.glb" % name).instantiate()
		var mesh: ArrayMesh = (s.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, mats[MAT_OF[mesh.surface_get_material(i).resource_name]])
		pieces[name] = mesh
		s.free()
	return pieces[name]

# a modelled piece standing on `bottom`, stretched by `scale` (pieces are authored at a nominal size), turned by rot_y
static func place(name: String, bottom: Vector3, scale: Vector3, rot_y := 0.0) -> void:
	var cell := 48.0 if name.begins_with("mvk/") else 96.0  # houses: small blocks, so far ones can switch to the coarse mesh
	var key := "%s|%d|%d" % [name, floori(bottom.x / cell), floori(bottom.z / cell)]
	if not batches.has(key):
		batches[key] = [_piece(name), []]
	batches[key][1].append(Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(scale), bottom))

static func _flush(m: Node3D) -> void:
	var blocks := {}  # "cell" -> {material: [near SurfaceTool, far SurfaceTool]}
	for k in batches:
		if str(k).begins_with("mvk/"):  # MegaKit houses: merged per block and material, a few draw calls per block
			var cell := str(k).substr(str(k).find("|"))
			if not blocks.has(cell):
				blocks[cell] = {}
			var near: ArrayMesh = batches[k][0]
			var far: ArrayMesh = far_pieces.get(near, near)
			for i in near.get_surface_count():
				var mat := near.surface_get_material(i)
				if not blocks[cell].has(mat):
					blocks[cell][mat] = [SurfaceTool.new(), SurfaceTool.new()]
					blocks[cell][mat][0].begin(Mesh.PRIMITIVE_TRIANGLES)
					blocks[cell][mat][1].begin(Mesh.PRIMITIVE_TRIANGLES)
				for xf in batches[k][1]:
					blocks[cell][mat][0].append_from(near, i, xf)
					blocks[cell][mat][1].append_from(far, i, xf)
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = batches[k][0]
		mm.instance_count = batches[k][1].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, batches[k][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if str(k).begins_with("fantasy-town/"):  # town houses: the ramparts and towers hide them from afar anyway
			mmi.visibility_range_end = 170.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a whole town in the shadow pass doubled its cost
		elif str(k).begins_with("nature/") or str(k).begins_with("graveyard/"):  # trees, rocks and grave clutter fade out early
			mmi.visibility_range_end = 95.0
			mmi.visibility_range_end_margin = 10.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		m.add_child(mmi)
	for cell in blocks:
		for v in 2:
			var mesh := ArrayMesh.new()
			for mat in blocks[cell]:
				blocks[cell][mat][v].commit(mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a whole town in the shadow pass doubled its cost
			mi.visibility_range_begin = 0.0 if v == 0 else 60.0
			mi.visibility_range_end = 60.0 if v == 0 else 170.0
			m.add_child(mi)
	batches = {}

static func collider_rot(m: Node3D, center: Vector3, size: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	m.add_child(body)

static func collider(m: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	m.add_child(body)

# a wall run as modelled 4 m segments along its long side: low ones get the crenellated parapet
static func wall(m: Node3D, center: Vector3, size: Vector3, piece := "", collide := true) -> void:
	if collide:
		collider(m, center, size)
	if piece == "":
		piece = "parapet_4" if size.y <= 2.5 else "wall_4"
	var nominal_h: float = {"parapet_4": 2.0, "wall_4": 4.0, "church_wall_4": 12.0}[piece]
	var along_x := size.x >= size.z
	var length: float = size.x if along_x else size.z
	var n := maxi(1, roundi(length / 4.0))
	var seg := length / n
	for i in n:
		var off := -length / 2.0 + seg * (i + 0.5)
		var c := center + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
		place(piece, c - Vector3(0, size.y / 2.0, 0), Vector3(seg / 4.0, size.y / nominal_h, size.z if along_x else size.x), 0.0 if along_x else PI / 2.0)

# height of a kit piece in its own units (its AABB top)
static func _top(name: String) -> float:
	return _piece(name).get_aabb().end.y

# a solid kit block (castle wall tile, crypt...) of footprint s x s metres standing on bottom
static func _kit_block(m: Node3D, name: String, bottom: Vector3, s: float, h: float, rot := 0.0) -> void:
	place(name, bottom, Vector3.ONE * s, rot)
	collider(m, bottom + Vector3(0, h / 2.0, 0), Vector3(s, h, s))

# castle watch tower: n stacked square sections with a battlement top; walkable on top (archers stand there)
static func _tower(m: Node3D, bottom: Vector3, n: int) -> float:
	var s := 4.0
	var y := bottom.y
	for i in n:
		var part := "castle/tower-square-base" if i == 0 else "castle/tower-square-mid-windows"
		place(part, Vector3(bottom.x, y, bottom.z), Vector3.ONE * s)
		y += _top(part) * s
	place("castle/tower-square-top", Vector3(bottom.x, y, bottom.z), Vector3.ONE * s)
	collider(m, Vector3(bottom.x, (bottom.y + y) / 2.0, bottom.z), Vector3(s, y - bottom.y, s))
	return y

static func ground_h(x: float, z: float) -> float:
	var n := tnoise.get_noise_2d(x, z)
	var h := -10.0 + n * 3.0
	h += smoothstep(105.0, 150.0, Vector2(x + 20.0, z + 30.0).length()) * (18.0 + n * 8.0)  # the valley's rim of hills
	h = lerpf(-0.8, h, smoothstep(13.0, 24.0, Vector2(x, z).length()))  # the shrine's hill
	for f in FLATS:
		var gx := maxf(maxf(f[0] - x, x - f[2]), 0.0)
		var gz := maxf(maxf(f[1] - z, z - f[3]), 0.0)
		h = lerpf(f[4], h, smoothstep(0.0, f[5], Vector2(gx, gz).length()))
	for r in RAMPS:
		var a := Vector2(r[0], r[1])
		var b := Vector2(r[3], r[4])
		var ab := b - a
		var t := clampf((Vector2(x, z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var side := (Vector2(x, z) - (a + ab * t)).length()
		h = lerpf(lerpf(r[2], r[5], t), h, smoothstep(r[6], r[6] + 3.0, side))
	return h

# Cemitério dos Juramentados: crypts, rows of graves, iron fence, dead pines and two lamps
static func _graveyard(m: Node3D) -> void:
	var y := GRAVE_Y
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 15:  # iron fence along the far edges
		place("graveyard/iron-fence", Vector3(26.0 + i * 3.0, y, -26.0), Vector3.ONE * 3.0)
		place("graveyard/iron-fence", Vector3(26.0 + i * 3.0, y, 26.0), Vector3.ONE * 3.0, PI)
	for i in 17:
		place("graveyard/iron-fence", Vector3(70.0, y, -24.0 + i * 3.0), Vector3.ONE * 3.0, PI / 2.0)
	collider(m, Vector3(47, y + 1.2, -26.6), Vector3(46, 2.4, 0.6))
	collider(m, Vector3(47, y + 1.2, 26.6), Vector3(46, 2.4, 0.6))
	collider(m, Vector3(70.6, y + 1.2, 0), Vector3(0.6, 2.4, 52))
	for c in [[Vector3(60, y, -20), "crypt-large", 3.5, 0.0], [Vector3(60, y, 18), "crypt-large", 3.5, PI], [Vector3(44, y, -18), "crypt-small", 3.0, 0.0],
			[Vector3(36, y, 18), "crypt-small", 3.0, PI]]:
		var name: String = c[1]
		place("graveyard/" + name, c[0], Vector3.ONE * c[2], c[3])
		place("graveyard/" + name + "-roof", c[0], Vector3.ONE * c[2], c[3])
		var aabb := _piece("graveyard/" + name).get_aabb()
		var sz: Vector3 = aabb.size * c[2]
		collider(m, c[0] + Vector3(0, sz.y / 2.0, 0), Vector3(sz.x, sz.y, sz.z) if c[3] == 0.0 or c[3] == PI else Vector3(sz.z, sz.y, sz.x))
	var stones := ["gravestone-cross-large", "gravestone-round", "gravestone-wide", "gravestone-broken", "gravestone-decorative", "gravestone-roof", "gravestone-bevel"]
	for row in 6:
		for k in 8:
			if rng.randf() < 0.25:
				continue
			var p := Vector3(30.0 + k * 4.5 + rng.randf_range(-0.6, 0.6), y, -10.0 + row * 4.0 + rng.randf_range(-0.4, 0.4))
			place("graveyard/" + stones[rng.randi() % stones.size()], p, Vector3.ONE * 2.6, rng.randf_range(-0.25, 0.25))
			if rng.randf() < 0.5:
				place("graveyard/grave-border", p + Vector3(0, 0, 1.3), Vector3.ONE * 2.6)
	for i in 10:
		var p := Vector3(rng.randf_range(26, 68), y, rng.randf_range(-24, 24))
		place("graveyard/" + ["pine-crooked", "pine-fall-crooked", "pine-crooked"][i % 3], p, Vector3.ONE * rng.randf_range(4.0, 6.0), rng.randf() * TAU)
	for c in [Vector3(28, y, -5), Vector3(28, y, 5), Vector3(52, y, 0)]:
		place("graveyard/lightpost-single", c, Vector3.ONE * 3.0, PI / 2.0)
		var l := OmniLight3D.new()
		l.position = c + Vector3(0, 3.6, 0)
		l.light_color = Color(0.55, 0.8, 0.6)  # cold grave-light
		l.light_energy = 1.4
		l.omni_range = 9.0
		m.add_child(l)
	place("graveyard/altar-stone", Vector3(66, y, 0), Vector3.ONE * 3.0, -PI / 2.0)
	place("graveyard/candle-multiple", Vector3(66, y + 1.2, 0), Vector3.ONE * 3.0)

# Jardim Morto: green and autumn trees, flowers and bushes in the valley; nothing inside the built areas or on the paths
static func _forest(m: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var trees := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat", "nature/tree_detailed", "nature/tree_default_fall",
		"nature/tree_pineRoundC", "nature/tree_oak_fall", "nature/tree_tall"]
	var props := ["nature/flower_redA", "nature/flower_yellowB", "nature/flower_purpleA", "nature/plant_bushLarge", "nature/mushroom_redGroup", "nature/rock_largeB"]
	var placed := 0
	var tries := 0
	while placed < 200 and tries < 4000:
		tries += 1
		var x := rng.randf_range(T_ORIGIN.x + 10.0, T_ORIGIN.x + T_SIZE - 10.0)
		var z := rng.randf_range(T_ORIGIN.y + 10.0, T_ORIGIN.y + T_SIZE - 10.0)
		var h := ground_h(x, z)
		if h > 5.0 or Vector2(x, z).length() < 28.0 or Vector2(x, z).length() > 215.0 or _in_built(x, z):
			continue
		var slope := absf(ground_h(x + 2.0, z) - h) + absf(ground_h(x, z + 2.0) - h)
		if slope > 3.0:
			continue
		placed += 1
		if rng.randf() < 0.75:
			place(trees[rng.randi() % trees.size()], Vector3(x, h - 0.3, z), Vector3.ONE * rng.randf_range(5.0, 9.0), rng.randf() * TAU)
		else:
			place(props[rng.randi() % props.size()], Vector3(x, h - 0.4, z), Vector3.ONE * rng.randf_range(2.5, 6.0), rng.randf() * TAU)

static func _in_built(x: float, z: float) -> bool:
	for f in FLATS:
		if x > f[0] - 6.0 and x < f[2] + 6.0 and z > f[1] - 6.0 and z < f[3] + 6.0:
			return true
	for r in RAMPS:
		var a := Vector2(r[0], r[1])
		var b := Vector2(r[3], r[4])
		var t := clampf((Vector2(x, z) - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if (Vector2(x, z) - a.lerp(b, t)).length() < r[6] + 4.0:
			return true
	return false

# a Medieval Village MegaKit house (2 m wall modules, 3 m storeys): painted plaster walls with the door on local +z,
# windows and timber framing, a round-tile roof whose ridge runs along local z, brick gable fronts, a chimney
const ROOFS := {4: [4, 6, 8], 6: [4, 6, 8, 10, 12, 14], 8: [8, 10, 12, 14]}

static func mvk_house(m: Node3D, origin: Vector3, w: int, d: int, floors: int, rot: float, seed := 0) -> Vector3:
	var W := w * 2
	var depths: Array = ROOFS[clampi(W, 4, 8)]
	var D: int = depths[0]
	for dd in depths:
		if absi(dd - d * 2) < absi(D - d * 2):
			D = dd
	d = D / 2
	w = clampi(W, 4, 8) / 2
	W = w * 2
	var b := Basis(Vector3.UP, rot)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var paint := "#%d" % (rng.randi() % PLASTER.size())  # each house its own colour
	var low := ["mvk/Wall_Plaster_Straight", "mvk/Wall_Plaster_Window_Thin_Round", "mvk/Wall_Plaster_Straight", "mvk/Wall_Plaster_Window_Wide_Flat"]
	var high := ["mvk/Wall_Plaster_Window_Wide_Round", "mvk/Wall_Plaster_WoodGrid", "mvk/Wall_Plaster_Window_Thin_Round", "mvk/Wall_Plaster_Straight", "mvk/Wall_Plaster_Window_Wide_Flat"]
	for f in floors:
		var y := f * 3.0
		for i in w:  # front (+z) and back
			var x := (i - (w - 1) / 2.0) * 2.0
			var front: String = "mvk/Wall_Plaster_Door_Round" if f == 0 and i == w / 2 else (low if f == 0 else high)[rng.randi() % (low if f == 0 else high).size()]
			place(front + paint, origin + b * Vector3(x, y, d), Vector3.ONE, rot)
			place((low if f == 0 else high)[rng.randi() % 4] + paint, origin + b * Vector3(-x, y, -d), Vector3.ONE, rot + PI)
		for i in d:  # sides
			var z := (i - (d - 1) / 2.0) * 2.0
			place((low if f == 0 else high)[rng.randi() % 4] + paint, origin + b * Vector3(w, y, z), Vector3.ONE, rot + PI / 2.0)
			place((low if f == 0 else high)[rng.randi() % 4] + paint, origin + b * Vector3(-w, y, -z), Vector3.ONE, rot - PI / 2.0)
		for c in [Vector3(w, y, d), Vector3(-w, y, d), Vector3(w, y, -d), Vector3(-w, y, -d)]:
			place("mvk/Corner_Exterior_Wood", origin + b * c, Vector3.ONE, rot + atan2(c.x, c.z) - PI / 4.0)
	var top := floors * 3.0
	place("mvk/Roof_RoundTiles_%dx%d" % [W, D], origin + b * Vector3(0, top, 0), Vector3.ONE, rot)
	place("mvk/Roof_Front_Brick%d" % W, origin + b * Vector3(0, top, d), Vector3.ONE, rot)
	place("mvk/Roof_Front_Brick%d" % W, origin + b * Vector3(0, top, -d), Vector3.ONE, rot + PI)
	if rng.randf() < 0.6:
		place("mvk/Prop_Chimney", origin + b * Vector3(w * 0.5, top + 1.0, -d * 0.4), Vector3.ONE, rot)
	return Vector3(W, top, D)  # footprint for the collider

# a Kenney fantasy-town house: w x d cells of KS metres, stone ground floor and timber upper floors, a door on
# its local +z side and a gabled roof whose ridge runs along local x; rot turns the whole house
const KS := 3.0
const ROOF_TURN := PI / 2.0  # turned so each cell shows its gable to the street: a row of pointed fronts, like old towns

static func kit_house(m: Node3D, origin: Vector3, w: int, d: int, floors: int, rot: float, seed := 0) -> void:
	var b := Basis(Vector3.UP, rot)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sides := [[Vector2i(1, 0), 0.0], [Vector2i(-1, 0), PI], [Vector2i(0, 1), -PI / 2.0], [Vector2i(0, -1), PI / 2.0]]
	for f in floors:
		for cx in w:
			for cz in d:
				var cell := Vector3((cx - (w - 1) / 2.0) * KS, f * KS, (cz - (d - 1) / 2.0) * KS)
				for sd in sides:
					var nx: int = cx + sd[0].x
					var nz: int = cz + sd[0].y
					if nx >= 0 and nx < w and nz >= 0 and nz < d:
						continue  # inner side
					var piece := "fantasy-town/wall"
					if f == 0 and sd[0] == Vector2i(0, 1) and cx == w / 2:
						piece = "fantasy-town/wall-doorway-round"
					elif f == 0:
						piece = ["fantasy-town/wall", "fantasy-town/wall-window-stone", "fantasy-town/wall"][rng.randi() % 3]
					else:
						piece = ["fantasy-town/wall-wood-window-shutters", "fantasy-town/wall-wood-detail-cross", "fantasy-town/wall-wood-window-small", "fantasy-town/wall-wood"][rng.randi() % 4]
					place(piece, origin + b * cell, Vector3.ONE * KS, rot + sd[1])
	var top := floors * KS
	for cx in w:  # one steep gable per cell along the front, running back over the whole depth
		var cell := Vector3((cx - (w - 1) / 2.0) * KS, top, 0.0)
		place("fantasy-town/roof-high-gable", origin + b * cell, Vector3(KS * d, KS * 0.7 * d, KS), rot + ROOF_TURN)
	if seed % 2 == 0:
		place("fantasy-town/chimney", origin + b * Vector3((w - 1) / 2.0 * KS, top, 0), Vector3.ONE * KS, rot)

# rock mass under a platform (centre and size like block); its collider only stops the camera (layer 2)
static func cliff(m: Node3D, center: Vector3, size: Vector3) -> void:
	place("cliff", center - Vector3(0, size.y / 2.0, 0), size)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * Vector3(0.85, 1.0, 0.85)  # the rock tapers toward the bottom
	cs.shape = sh
	body.add_child(cs)
	m.add_child(body)

# wall torch: an iron bracket, a flame that glows and a short warm light
static func torch(m: Node3D, pos: Vector3, facing: float) -> void:
	var out := Vector3(sin(facing), 0, cos(facing))
	place("beam", pos - Vector3(0, 0.3, 0) + out * 0.25, Vector3(0.12, 0.6, 0.12))
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.42
	sm.radial_segments = 6
	sm.rings = 3
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.6, 0.2)
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = pos + out * 0.25 + Vector3(0, 0.45, 0)
	m.add_child(flame)
	var l := OmniLight3D.new()
	l.position = flame.position + out * 0.4
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.6
	l.omni_range = 8.0
	m.add_child(l)

# a solid block; collide=false for decoration
static func block(m: Node3D, center: Vector3, size: Vector3, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		body.add_child(mi)
		m.add_child(body)
	else:
		mi.position = center
		m.add_child(mi)

# straight stair: a smooth ramp to walk on, visual steps on top, low side walls
static func _stair(m: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var run := Vector2(b.x - a.x, b.z - a.z)
	var length := Vector3(b - a).length()
	var body := StaticBody3D.new()
	body.position = (a + b) / 2.0 - Vector3(0, 0.25, 0)
	body.look_at_from_position(body.position, body.position + (b - a), Vector3.UP)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, 0.5, length)
	cs.shape = sh
	body.add_child(cs)
	m.add_child(body)
	var steps := int(run.length() / 1.4)
	var dir := Vector3(run.x, 0, run.y).normalized()
	for i in steps:
		var t := (i + 0.5) / steps
		var p := a.lerp(b, t)
		var rise := (b.y - a.y) / steps + 0.2
		place("step", p - Vector3(0, 0.15 + rise / 2.0, 0), Vector3(width, rise, run.length() / steps), atan2(dir.x, dir.z) + PI)
	var side := dir.cross(Vector3.UP)
	for s in [-1, 1]:
		var w := StaticBody3D.new()
		w.position = (a + b) / 2.0 + side * s * (width / 2.0 + 0.3) + Vector3(0, 0.6, 0)
		w.look_at_from_position(w.position, w.position + (b - a), Vector3.UP)
		var wcs := CollisionShape3D.new()
		var wsh := BoxShape3D.new()
		wsh.size = Vector3(0.6, 1.2, length)
		wcs.shape = wsh
		w.add_child(wcs)
		var wmi := MeshInstance3D.new()
		var wbm := BoxMesh.new()
		wbm.size = wsh.size
		wmi.mesh = wbm
		wmi.material_override = mats.wall
		w.add_child(wmi)
		m.add_child(w)
	pass  # the terrain follows the stair (RAMPS), no rock mass needed under it

static func _sanctuary(m: Node3D) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, -0.5, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 14.0
	cyl.height = 1.0
	cs.shape = cyl
	body.add_child(cs)
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 14.0
	cm.bottom_radius = 14.0
	cm.height = 1.0
	top.mesh = cm
	top.material_override = mats.floor
	body.add_child(top)
	m.add_child(body)
	for i in 7:  # broken colonnade on the rim, gaps toward the stair, the cemetery gate and the elevator
		var a := i * TAU / 7.0 + 0.45
		m._place("pm/Column_SmallBroken_01" if i % 2 else "pm/Column_Regular", Vector3(sin(a) * 12.0, 0, cos(a) * 12.0), 2.6 if i % 2 else 5.0, Color.WHITE, mats.wall)
	m._place("pm/Arc", Vector3(0, 0, 9), 5.0, Color.WHITE, mats.wall, 0.0)
	# east: the path down to the cemetery
	place("graveyard/border-pillar", Vector3(13.6, -0.3, -2.4), Vector3.ONE * 3.0)
	place("graveyard/border-pillar", Vector3(13.6, -0.3, 2.4), Vector3.ONE * 3.0)
	# crenellated rim so a long combo cannot carry you off the cliff; open to the stair (north), gate (east), elevator (west)
	for i in 21:
		var ang := i * TAU / 21.0
		if absf(angle_difference(ang, PI)) < 0.35 or absf(angle_difference(ang, PI / 2.0)) < 0.35 or absf(angle_difference(ang, -PI / 2.0)) < 0.35:
			continue
		var c := Vector3(sin(ang), 0, cos(ang)) * 13.6
		var rim := StaticBody3D.new()
		rim.position = c + Vector3(0, 1, 0)
		rim.rotation.y = ang + PI / 2.0
		var rcs := CollisionShape3D.new()
		var rsh := BoxShape3D.new()
		rsh.size = Vector3(4.2, 2, 0.8)
		rcs.shape = rsh
		rim.add_child(rcs)
		m.add_child(rim)
		place("parapet_4", c, Vector3(4.2 / 4.0, 1.0, 0.8), ang + PI / 2.0)
	# west: landing to the elevator shaft
	block(m, Vector3(-16.5, -0.5, ELEVATOR.z), Vector3(5.0, 1.0, 3.0), mats.floor)

static func _burgo(m: Node3D) -> void:
	block(m, Vector3(-25, BURGO_Y - 0.5, -74), Vector3(90, 1, 52), mats.floor)
	# outer ramparts (north and east): Kenney castle wall blocks, 4 m a tile, towers on the corners
	var kw := 4.0
	var wh := _top("castle/wall") * kw
	for i in 23:
		_kit_block(m, "castle/wall", Vector3(-68.0 + i * kw, BURGO_Y, -102.0), kw, wh)
	for i in 13:
		_kit_block(m, "castle/wall", Vector3(22.0, BURGO_Y, -98.0 + i * kw), kw, wh, PI / 2.0)
	for c in [Vector3(-72.0, BURGO_Y, -102.0), Vector3(22.0, BURGO_Y, -102.0), Vector3(22.0, BURGO_Y, -46.0)]:
		_tower(m, c, 3)
	place("castle/flag-banner-long", Vector3(-26.0, BURGO_Y + wh, -100.5), Vector3.ONE * kw)
	place("castle/flag-banner-long", Vector3(2.0, BURGO_Y + wh, -100.5), Vector3.ONE * kw)
	wall(m, Vector3(-70.5, BURGO_Y + 1, -82), Vector3(1, 2, 36))  # west parapet, open where the ramp comes up
	for side in [-1, 1]:  # south parapet either side of the stair head
		wall(m, Vector3(-22.5 if side < 0 else 11.5, BURGO_Y + 1, -47.5), Vector3(41 if side < 0 else 17, 2, 1))
	for i in HOUSES.size():
		var h: Array = HOUSES[i]
		if i == 2 or i == 8:  # the two archer perches are castle watch towers
			_tower(m, Vector3(h[0], BURGO_Y, h[1]), 2)
			continue
		# MegaKit houses facing the square: stone ground floor, plastered upper floors, round-tile roof
		var floors := 2 if h[4] < 10 else 3
		var rot := PI if h[1] > -74 else 0.0
		if h[0] > 12:
			rot = -PI / 2.0
		var fp := mvk_house(m, Vector3(h[0], BURGO_Y, h[1]), clampi(roundi(h[2] / 2.0), 2, 4), clampi(roundi(h[3] / 2.0), 2, 5), floors, rot, i)
		collider_rot(m, Vector3(h[0], BURGO_Y + fp.y / 2.0, h[1]), fp, rot)
	for c in [Vector3(-12, BURGO_Y, -66), Vector3(-36, BURGO_Y, -75), Vector3(-2, BURGO_Y, -84)]:  # street lamps
		place("graveyard/lightpost-single", c, Vector3.ONE * 3.0)
	place("fantasy-town/fountain-round", Vector3(-12, BURGO_Y, -76), Vector3.ONE * 4.0)
	collider(m, Vector3(-12, BURGO_Y + 0.6, -76), Vector3(4.4, 1.2, 4.4))
	place("fantasy-town/stall-red", Vector3(4, BURGO_Y, -70), Vector3.ONE * 3.0, PI)
	place("fantasy-town/cart-high", Vector3(-48, BURGO_Y, -66), Vector3.ONE * 3.0, 0.4)
	m._prop("wall_ruin", Vector3(-8, BURGO_Y, -60), 0.3)
	m._prop("graves", Vector3(-42, BURGO_Y, -66), 1.2)
	m._place("pm/Cart", Vector3(-10, BURGO_Y, -82), 1.8, Color(0.45, 0.4, 0.38), null, 0.6)
	# the alley under the rooftops, with a ramp back up into the Burgo's west side
	block(m, Vector3(-51, ALLEY_Y - 0.5, -26), Vector3(30, 1, 46), mats.floor)
	_stair(m, Vector3(-67.5, ALLEY_Y, -22), Vector3(-67.5, BURGO_Y, -54), 4.0)
	for z in [-46.0, -6.0]:
		wall(m, Vector3(-51, ALLEY_Y + 1, z - 3.0 * sign(z + 26)), Vector3(30, 2, 1))

static func _rooftops(m: Node3D) -> void:
	for r in ROOFTOPS:
		if r[5]:  # a ruined house rising from the alley
			var hgt: float = r[1] - ALLEY_Y
			collider(m, Vector3(r[0], ALLEY_Y + hgt / 2.0, r[2]), Vector3(r[3], hgt, r[4]))
			place("ruin_tower", Vector3(r[0], ALLEY_Y, r[2]), Vector3(r[3] / 4.0, hgt / 10.0, r[4] / 4.0))
		else:  # a bare wooden beam
			collider(m, Vector3(r[0], r[1] - 0.15, r[2]), Vector3(r[3], 0.3, r[4]))
			place("beam", Vector3(r[0], r[1] - 0.3, r[2]), Vector3(r[3], 0.3, r[4]))

static func _church(m: Node3D) -> void:
	var y := CHURCH_Y
	block(m, Vector3(-42, y - 0.5, 14), Vector3(40, 1, 32), mats.floor)
	for c in [Vector3(-64.0, y, -4.0), Vector3(-64.0, y, 32.0)]:  # corner towers on the crag
		_tower(m, c, 2)
	# nave: lancet-windowed walls with a door on the east side, open roof beams
	wall(m, Vector3(-52, y + 6, 4), Vector3(16, 12, 1), "church_wall_4")
	wall(m, Vector3(-52, y + 6, 26), Vector3(16, 12, 1), "church_wall_4")
	wall(m, Vector3(-60, y + 6, 15), Vector3(1, 12, 22), "church_wall_4")
	wall(m, Vector3(-44, y + 6, 8), Vector3(1, 12, 8), "church_wall_4")
	wall(m, Vector3(-44, y + 6, 22.5), Vector3(1, 12, 7), "church_wall_4")
	wall(m, Vector3(-44, y + 10, 15), Vector3(1, 4, 6), "wall_4")
	for z in [8.0, 13.0, 18.0, 23.0]:
		place("beam", Vector3(-52, y + 11.7, z), Vector3(16, 0.6, 0.6))
	m._prop("seed_shrine", Vector3(-58, y, 15), PI / 2)
	# bell tower: the ladder takes you up (interact), the bell is on top
	collider(m, Vector3(-30, y + 6, 26), Vector3(6, 12, 6))
	place("ruin_tower", Vector3(-30, y, 26), Vector3(1.5, 1.2, 1.5))
	collider(m, Vector3(-30, y + 12.25, 26), Vector3(7, 0.5, 7))
	place("belfry", Vector3(-30, y + 12.0, 26), Vector3.ONE)  # open bell chamber and slate spire
	for c in [Vector2(-33, 23), Vector2(-27, 23), Vector2(-33, 29), Vector2(-27, 29)]:
		collider(m, Vector3(c.x, y + 15, c.y), Vector3(1.0, 5, 1.0))
	var bell := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 1.1
	bm.height = 1.6
	bell.mesh = bm
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.45, 0.32, 0.15)
	bronze.metallic = 0.9
	bronze.roughness = 0.4
	bell.material_override = bronze
	bell.position = Vector3(-30, y + 16.2, 26)
	m.add_child(bell)
	var rail := Vector3(-30, y, 22.6)  # ladder on the tower's north face
	block(m, rail + Vector3(0, 6, 0), Vector3(1.2, 12, 0.2), mats.wood, false)
	m.interacts.append({"pos": rail, "r": 1.6, "label": "SUBIR", "do": func(): m._climb(rail + Vector3(0, 12.5, 2.4))})
	m.interacts.append({"pos": rail + Vector3(0, 12.5, 2.4), "r": 1.6, "label": "DESCER", "do": func(): m._climb(rail + Vector3(0, 0, -1.2))})
	m.interacts.append({"pos": Vector3(-30, y + 12.5, 26), "r": 2.2, "label": "SINO", "do": func(): m._ring_bell(1)})
	# plaza parapets (open to the rooftops on the north-west and to the elevator bridge on the east)
	wall(m, Vector3(-42, y + 1, 30.5), Vector3(40, 2, 1))
	wall(m, Vector3(-62.5, y + 1, 18), Vector3(1, 2, 24))
	wall(m, Vector3(-21.5, y + 1, 18), Vector3(1, 2, 24))
	wall(m, Vector3(-36, y + 1, -2.5), Vector3(28, 2, 1))
	# elevator bridge, shaft frame and the moving platform
	for c in [Vector2(-1.8, -1.8), Vector2(1.8, -1.8), Vector2(-1.8, 1.8), Vector2(1.8, 1.8)]:
		place("beam", Vector3(ELEVATOR.x + c.x * 1.05, -1.0, ELEVATOR.z + c.y * 1.05), Vector3(0.4, y + 6.0, 0.4))

const AREAS := [  # [name, subtitle, test]
	["SANTUÁRIO DA CHAMA", "Tudo volta para cá", "sanctuary"],
	["BURGO DOS ESQUECIDOS", "Os que ficaram esqueceram o próprio nome", "burgo"],
	["TELHADOS QUEBRADOS", "Pule, ou volte pelos becos", "roofs"],
	["BECOS DO BURGO", "Aqui embaixo ninguém ouve você cair", "alley"],
	["IGREJA DO JURAMENTO", "Toque o sino. Desperte o que dorme", "church"],
	["CEMITÉRIO DOS JURAMENTADOS", "Volte quando for mais forte", "graveyard"],
	["JARDIM MORTO", "Os lobos sentem o cheiro da Chama", "forest"],
]

static func area_of(p: Vector3) -> Array:
	var t := ""
	if Vector2(p.x, p.z).length() < 16.0 and p.y < 5.0:
		t = "sanctuary"
	elif p.y > CHURCH_Y - 1.0 and p.z > -3.0 and p.x < -20.0:
		t = "church"
	elif p.y < BURGO_Y - 2.0 and p.y > ALLEY_Y - 2.0 and p.x < -35.0 and p.z > -49.0:
		t = "alley"
	elif p.x < -36.0 and p.z > -47.0 and p.y > BURGO_Y:
		t = "roofs"
	elif p.y > BURGO_Y - 1.0 and p.z < -47.0:
		t = "burgo"
	elif p.x > 20.0 and p.y < 2.0 and absf(p.z) < 30.0:
		t = "graveyard"
	elif p.y < -4.0:
		t = "forest"
	for a in AREAS:
		if a[2] == t:
			return a
	return []
