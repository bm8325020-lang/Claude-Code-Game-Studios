# PROTOTYPE - NOT FOR PRODUCTION
# The first souls loop of Cinzarra (design/levels/mapa-oficial.md):
# Santuário da Chama (y 0) -> great stair -> Burgo dos Esquecidos (y 15) -> Telhados Quebrados (parkour,
# y 15..30, with the Becos alley below at y 8) -> Igreja do Juramento (y 30) -> elevator shortcut back down.
extends RefCounted

const FALL_DEATH_Y := -25.0
const BURGO_Y := 15.0
const ALLEY_Y := 8.0
const CHURCH_Y := 30.0
const ELEVATOR := Vector3(-21.0, 0.0, 2.0)  # shaft column (x, z); the platform runs y 0 <-> 30

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
]
const BREAKABLES := [
	[Vector3(-14, BURGO_Y, -70), "Barrel", 1.1], [Vector3(-15, BURGO_Y, -71.4), "Vase_Large", 1.1], [Vector3(-36, BURGO_Y, -88), "Jar01_Art", 0.9],
	[Vector3(8, BURGO_Y, -84), "SmallBarrel_Art", 0.8], [Vector3(-52, BURGO_Y, -60), "Vase_Mid", 0.9], [Vector3(-64, ALLEY_Y, -12), "Barrel", 1.1],
	[Vector3(-63, ALLEY_Y, -10.6), "Jar02_Art", 1.0], [Vector3(-26, CHURCH_Y, 12), "Vase_Large", 1.1], [Vector3(-26, CHURCH_Y, 13.4), "Vase_Small", 0.7],
]
const SHARDS := [Vector3(-62, ALLEY_Y + 0.6, -6), Vector3(-40, 22.1, -26)]
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

static var mats := {}
static var pieces := {}  # name -> ArrayMesh with the level's materials (assets/arch, tools/make_architecture.py)
static var batches := {}  # "piece|cell" -> [mesh, [Transform3D]]: every modelled piece is drawn through a few MultiMeshes
const MAT_OF := {"stone": "wall", "plaster": "plaster", "wood": "wood", "roof": "roof", "dark": "dark", "iron": "iron", "rock": "rock"}

static func _mat(tex: String, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_diff_1k.jpg" % tex)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/%s_nor_gl_1k.jpg" % tex)
	if ResourceLoader.exists("res://assets/tex/%s_rough_1k.jpg" % tex):
		m.roughness_texture = load("res://assets/tex/%s_rough_1k.jpg" % tex)
	m.albedo_color = tint
	m.uv1_triplanar = true  # level blocks are plain boxes: world-space tiling keeps texel size even
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m

static func build(m: Node3D) -> void:
	mats = {
		"floor": _mat("cobblestone_floor_08", 0.3), "wall": _mat("castle_wall_slates", 0.25),
		"rock": _mat("aerial_rocks_02", 0.06, Color(0.55, 0.52, 0.5)), "roof": _mat("castle_wall_slates", 0.4, Color(0.35, 0.3, 0.3)),
	}
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.13, 0.08)
	wood.roughness = 0.9
	mats.wood = wood
	mats.plaster = _mat("coast_sand_rocks_02", 0.5, Color(0.8, 0.72, 0.6))  # rough daub between the timbers
	mats.dark = _plain(Color(0.015, 0.012, 0.012), 1.0)
	mats.iron = _plain(Color(0.12, 0.12, 0.13), 0.5, 0.8)
	pieces = {}
	batches = {}
	_sanctuary(m)
	_stair(m, Vector3(0, 0, -12), Vector3(0, BURGO_Y, -48), 6.0)
	_burgo(m)
	_rooftops(m)
	_church(m)
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

static func _piece(name: String) -> ArrayMesh:
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
	var key := "%s|%d|%d" % [name, floori(bottom.x / 48.0), floori(bottom.z / 48.0)]
	if not batches.has(key):
		batches[key] = [_piece(name), []]
	batches[key][1].append(Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(scale), bottom))

static func _flush(m: Node3D) -> void:
	for k in batches:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = batches[k][0]
		mm.instance_count = batches[k][1].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, batches[k][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		m.add_child(mmi)
	batches = {}

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

# rock mass under a platform (centre and size like block)
static func cliff(center: Vector3, size: Vector3) -> void:
	place("cliff", center - Vector3(0, size.y / 2.0, 0), size)

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
	var under := Vector3(width + 1.2, 18, run.length())
	place("cliff", (a + b) / 2.0 + Vector3(0, -19, 0), under if absf(dir.z) > absf(dir.x) else Vector3(under.z, under.y, under.x))

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
	var base := MeshInstance3D.new()  # the cliff the shrine stands on
	var bm := CylinderMesh.new()
	bm.top_radius = 14.6
	bm.bottom_radius = 7.0
	bm.height = 34.0
	base.mesh = bm
	base.material_override = mats.rock
	base.position.y = -18.0
	m.add_child(base)
	for i in 7:  # broken colonnade on the rim, gaps toward the stair, the cemetery gate and the elevator
		var a := i * TAU / 7.0 + 0.45
		m._place("pm/Column_SmallBroken_01" if i % 2 else "pm/Column_Regular", Vector3(sin(a) * 12.0, 0, cos(a) * 12.0), 2.6 if i % 2 else 5.0, Color.WHITE, mats.wall)
	m._place("pm/Arc", Vector3(0, 0, 9), 5.0, Color.WHITE, mats.wall, 0.0)
	# east: the way down to the cemetery is barred for now
	m._prop("archway_gate", Vector3(13.5, 0, 0), PI / 2)
	wall(m, Vector3(13.5, 2, 0), Vector3(0.6, 4, 3.2))
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
	cliff(Vector3(-25, BURGO_Y - 16, -74), Vector3(90, 30, 52))
	wall(m, Vector3(-25, BURGO_Y + 1, -100.5), Vector3(90, 2, 1))  # north parapet
	wall(m, Vector3(20.5, BURGO_Y + 1, -74), Vector3(1, 2, 52))  # east parapet
	wall(m, Vector3(-70.5, BURGO_Y + 1, -82), Vector3(1, 2, 36))  # west parapet, open where the ramp comes up
	for side in [-1, 1]:  # south parapet either side of the stair head
		wall(m, Vector3(-22.5 if side < 0 else 11.5, BURGO_Y + 1, -47.5), Vector3(41 if side < 0 else 17, 2, 1))
	for i in HOUSES.size():
		var h: Array = HOUSES[i]
		collider(m, Vector3(h[0], BURGO_Y + h[4] / 2.0, h[1]), Vector3(h[2], h[4], h[3]))
		# timber houses face the square; the two archer perches (spawns at y 24/25) are flat-roofed watch houses
		var watch: bool = i == 2 or i == 8
		var rot := PI if h[1] > -74 else 0.0
		var sc := Vector3(h[2] / 10.0, h[4] / (8.4 if watch else 8.0), h[3] / 8.0)
		if h[0] > 12:
			rot = -PI / 2.0
			sc = Vector3(h[3] / 10.0, sc.y, h[2] / 8.0)
		place("house_watch" if watch else "house", Vector3(h[0], BURGO_Y, h[1]), sc, rot)
	m._prop("wall_ruin", Vector3(-8, BURGO_Y, -60), 0.3)
	m._prop("graves", Vector3(-42, BURGO_Y, -66), 1.2)
	m._place("pm/Cart", Vector3(-10, BURGO_Y, -82), 1.8, Color(0.45, 0.4, 0.38), null, 0.6)
	# the alley under the rooftops, with a ramp back up into the Burgo's west side
	block(m, Vector3(-51, ALLEY_Y - 0.5, -26), Vector3(30, 1, 46), mats.floor)
	cliff(Vector3(-51, ALLEY_Y - 17, -26), Vector3(30, 32, 46))
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
	cliff(Vector3(-42, y - 20, 14), Vector3(40, 38, 32))
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
	for a in AREAS:
		if a[2] == t:
			return a
	return []
