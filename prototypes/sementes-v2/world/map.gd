# PROTOTYPE - NOT FOR PRODUCTION
# Map module (owner: map agent). Contract: ARCHITECTURE.md "Map — world/map.gd".
# Builds the Vale de Lume, one hand-laid region of about 600 x 600 m (x east, z south, y up, metres).
#
# THE PLAN (drawn on paper first; every number below is used in the code):
#
#        z=-300  ~~~~~~~~ northern mountains: the stone body of the Lumeira (world border, tallest) ~~~~~~~~
#                  river springs here         CASTELO DE VIGÍLIA                MINA DO FÔLEGO
#        z=-250   (-250,-310)                  rock table, top y=42           spur ridge, sheer south face
#                     \                        centre (8,-214), sheer         mine mouth (176,-190)
#        z=-200        \  pines                cliff south+west, long  <--road climbs the east spur
#                       \                      east slope for the road        Gaspar's cabin (196,-178)
#        z=-150  pines   \ (-160,-170)                        \                  |
#                         \                                    \ knoll (95,-112) | mine road
#        z=-100  BOSQUE    (-125,-105)    knoll (-40,-125)      \               |
#                DOS        \                                    \              |      ATALAIA
#        z=-50   SUSSURROS   (-98,-40)        [north street]      \          (125,-42)---hill top (186,-46)
#                (west of     \          inn  | forge  east road --------------/      ruined tower, beacon
#        z=0     the river)    (-80,10)   SQUARE (0,-20): well, Pedra do Primeiro Lume, Marco de Lume
#                 Carvalha-Mãe  \  mill road /     chapel + dovecote (18,14)
#                 clearing       MILL (-57,45)    lake road
#        z=50     (-185,25)       BRIDGE (-62,74)   \  farm lane ---> QUINTA DO REGO (100,62)
#                 trail SW         \                 \                farmhouse, barn, coop, fields
#        z=100     \                (-38,122)          \               wheat (gold) / grey field (dug seed)
#                   \                 \                 \
#        z=150   QUARRY pit            (-12,160)       pier (44,166)   knoll (160,150)
#                SEM-TERRA camp         \  LAGO MANSO centre (30,224), water y=1.0, sandy north shore
#        z=200   (-214,166)              '---> river mouth                Celeste's hut (64,156)
#        z=300  ~~~~~~~~ southern hills (lower border) ~~~~~~~~
#            x=-300                         x=0                                         x=300
#
# Why the roads go where they go: everything starts at the village square. North street climbs to the castle
# along the east spur (the only side without a cliff). The mill road goes west to the mill and the toll bridge,
# then becomes the forest track to the Carvalha-Mãe; a narrow trail leaves it for the hidden quarry. The east road
# serves the forge and goes to the watchtower hill, with a fork north to the mine. The lake road goes south past the
# farm lane to Celeste's pier.
#
# Assumptions about other modules: none at build time. Characters walk on collision layer 1 (terrain + buildings).
# main.gd calls build() once; this node adds its own WorldEnvironment and DirectionalLight3D (remove them if the
# lead wants a global sky). `stats` holds build counts for the preview tool.
class_name GameMap
extends Node3D

const Kit = preload("res://world/kit.gd")
const Terrain = preload("res://world/terrain.gd")
const Bld = preload("res://world/buildings.gd")
const Veg = preload("res://world/vegetation.gd")

const SQUARE: Vector2 = Vector2(0, -20)

var spawns: Dictionary = {}
var places: Array = []
var camps: Array = []
var npc_spots: Array = []
var interactables: Array = []
var stats: Dictionary = {}

var terrain: Terrain
var kit: Kit
var veg: Veg
var sun: DirectionalLight3D
var env: Environment

var river_ctrl: Array = [
	Vector3(-252, 0, -318), Vector3(-226, 0, -262), Vector3(-196, 0, -214), Vector3(-160, 0, -170),
	Vector3(-125, 0, -105), Vector3(-100, 0, -42), Vector3(-82, 0, 8), Vector3(-68, 0, 45),
	Vector3(-58, 0, 78), Vector3(-38, 0, 122), Vector3(-12, 0, 160), Vector3(12, 0, 190), Vector3(26, 0, 214)]

var road_defs: Array = [
	{"id": "castle", "hw": 2.2, "pts": [Vector2(0, -20), Vector2(0, -34), Vector2(3, -60), Vector2(14, -92),
		Vector2(42, -122), Vector2(82, -146), Vector2(114, -168), Vector2(122, -192), Vector2(98, -206),
		Vector2(66, -213), Vector2(34, -215)]},
	{"id": "mill", "hw": 2.0, "pts": [Vector2(0, -20), Vector2(-14, -20), Vector2(-32, -8), Vector2(-43, 16),
		Vector2(-45, 44), Vector2(-50, 62), Vector2(-62, 74), Vector2(-80, 82), Vector2(-104, 74),
		Vector2(-132, 56), Vector2(-158, 40), Vector2(-178, 30)]},
	{"id": "quarry_trail", "hw": 1.3, "pts": [Vector2(-132, 56), Vector2(-150, 90), Vector2(-166, 122),
		Vector2(-180, 148), Vector2(-194, 164)]},
	{"id": "east", "hw": 2.0, "pts": [Vector2(0, -20), Vector2(14, -20), Vector2(45, -24), Vector2(85, -33),
		Vector2(125, -42), Vector2(150, -30), Vector2(170, -24), Vector2(190, -32), Vector2(188, -42)]},
	{"id": "mine", "hw": 1.8, "pts": [Vector2(125, -42), Vector2(134, -80), Vector2(148, -122),
		Vector2(164, -158), Vector2(176, -178)]},
	{"id": "lake", "hw": 2.0, "pts": [Vector2(0, -20), Vector2(0, -6), Vector2(4, 24), Vector2(26, 56),
		Vector2(44, 92), Vector2(48, 128), Vector2(45, 154), Vector2(44, 166)]},
	{"id": "farm", "hw": 1.6, "pts": [Vector2(26, 56), Vector2(56, 62), Vector2(86, 62)]},
]

# Buildings: id, pos, yaw (front faces rot(yaw)*+Z: 0 south, PI north, PI/2 east, -PI/2 west), spec for MapBuildings.
var houses: Array = []
var pads: Array = []
var _static: StaticBody3D


func _ready() -> void:
	pass


func build() -> void:
	var t0: int = Time.get_ticks_msec()
	kit = Kit.new()
	terrain = Terrain.new()
	_define_places()
	_define_buildings()
	terrain.generate(river_ctrl, road_defs, pads)
	stats["t_terrain_ms"] = Time.get_ticks_msec() - t0
	_static = StaticBody3D.new()
	_static.name = "Buildings"
	_static.collision_layer = 1
	add_child(_static)
	_sky()
	_ground()
	_water()
	stats["t_ground_ms"] = Time.get_ticks_msec() - t0
	if has_method("_build_world"):
		call("_build_world")
	stats["t_total_ms"] = Time.get_ticks_msec() - t0


# ------------------------------------------------------------------ contract queries
func ground_y(x: float, z: float) -> float:
	return terrain.sample(x, z)


func area_name(pos: Vector3) -> String:
	var best: String = ""
	var best_k: float = 1.0
	for p in places:
		var c: Vector3 = p.pos
		var k: float = Vector2(pos.x - c.x, pos.z - c.z).length() / float(p.radius)
		if k < best_k:
			best_k = k
			best = p.name
	return best


# ------------------------------------------------------------------ layout
func _define_places() -> void:
	var defs: Array = [
		["village", "Vila de Brasalume", Vector2(0, -32), 72.0],
		["farm", "Quinta do Rego", Vector2(112, 78), 62.0],
		["river", "Moinho das Três Mós", Vector2(-60, 60), 40.0],
		["forest", "Bosque dos Sussurros", Vector2(-198, 10), 100.0],
		["bandit_camp", "Acampamento dos Sem-Terra", Vector2(-210, 166), 38.0],
		["watchtower", "A Atalaia", Vector2(186, -46), 42.0],
		["mine", "Mina do Fôlego", Vector2(182, -184), 32.0],
		["castle", "Castelo de Vigília", Vector2(8, -214), 56.0],
		["lake", "Lago Manso", Vector2(30, 216), 86.0],
	]
	for d in defs:
		var v: Vector2 = d[2]
		places.append({"id": d[0], "name": d[1], "pos": Vector3(v.x, 0, v.y), "radius": d[3]})


func _house(id: String, pos: Vector2, yaw: float, spec: Dictionary) -> void:
	var w: float = float(spec.get("w", 3)) * 2.0
	var d: float = float(spec.get("d", 3)) * 2.0
	var pad: Dictionary = {"c": pos, "size": Vector2(w + 2.5, d + 2.5), "yaw": yaw, "y": NAN}
	pads.append(pad)
	houses.append({"id": id, "pos": pos, "yaw": yaw, "spec": spec, "pad": pad})


func _pad(pos: Vector2, size: Vector2, yaw: float) -> Dictionary:
	var pad: Dictionary = {"c": pos, "size": size, "yaw": yaw, "y": NAN}
	pads.append(pad)
	return pad


func _define_buildings() -> void:
	pass


# ------------------------------------------------------------------ ground
func _noise_image(size: int, seeds: Array, freq: float) -> ImageTexture:
	var img: Image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	var ns: Array = []
	for s in seeds:
		var n: FastNoiseLite = FastNoiseLite.new()
		n.seed = s
		n.frequency = freq
		n.fractal_octaves = 4
		ns.append(n)
	for y in size:
		for x in size:
			# tileable: sample a torus in 4D is not available, so blend 4 shifted samples
			var fx: float = float(x) / size
			var fy: float = float(y) / size
			var c: Array = []
			for n in ns:
				var nn: FastNoiseLite = n
				var a: float = nn.get_noise_2d(x, y) * (1.0 - fx) * (1.0 - fy)
				a += nn.get_noise_2d(x - size, y) * fx * (1.0 - fy)
				a += nn.get_noise_2d(x, y - size) * (1.0 - fx) * fy
				a += nn.get_noise_2d(x - size, y - size) * fx * fy
				c.append(clampf(a * 1.2 + 0.5, 0.0, 1.0))
			img.set_pixel(x, y, Color(c[0], c[1], c[2], 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


var macro_tex: ImageTexture


func _ground() -> void:
	macro_tex = _noise_image(256, [21, 22, 23], 0.02)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://world/terrain.gdshader")
	mat.set_shader_parameter("macro", macro_tex)
	mat.set_shader_parameter("ctrl", _ctrl_texture())
	mat.set_shader_parameter("paths", _path_texture())
	var g: String = "res://assets/ground/"
	mat.set_shader_parameter("t_grass", load(g + "grass_ground_diff_1k.jpg"))
	mat.set_shader_parameter("t_forest", load(g + "forest_leaves_02_diff_1k.jpg"))
	mat.set_shader_parameter("t_dirt", load(g + "dirt_floor_diff_1k.jpg"))
	mat.set_shader_parameter("t_rock", load(g + "rock_face_03_diff_1k.jpg"))
	mat.set_shader_parameter("t_mud", load(g + "brown_mud_leaves_01_diff_1k.jpg"))
	mat.set_shader_parameter("t_sand", load(g + "coast_sand_01_diff_1k.jpg"))
	mat.set_shader_parameter("n_grass", load(g + "grass_ground_nor_gl_1k.jpg"))
	mat.set_shader_parameter("n_dirt", load(g + "dirt_floor_nor_gl_1k.jpg"))
	mat.set_shader_parameter("n_rock", load(g + "rock_face_03_nor_gl_1k.jpg"))
	var holder: Node3D = Node3D.new()
	holder.name = "Terrain"
	add_child(holder)
	terrain.build_nodes(holder, mat)


# Forest density in 0..1 (authored blobs, broken by noise). Used for the ground layer and the tree rules.
var _fn: FastNoiseLite


func forest_density(x: float, z: float) -> float:
	if _fn == null:
		_fn = FastNoiseLite.new()
		_fn.seed = 31
		_fn.frequency = 0.02
	var blobs: Array = [
		# Bosque dos Sussurros, west of the river
		Vector3(-205, -60, 95), Vector3(-215, 55, 85), Vector3(-160, 0, 45), Vector3(-175, 130, 55),
		Vector3(-150, -150, 60), Vector3(-238, -190, 60), Vector3(-120, 170, 40),
		# east flank and southern rim
		Vector3(258, 40, 60), Vector3(250, 150, 70), Vector3(236, -120, 45), Vector3(-90, 262, 55),
		Vector3(150, 262, 60), Vector3(250, 255, 60),
		# northern foothills
		Vector3(-80, -205, 45), Vector3(110, -238, 40), Vector3(-30, -270, 40),
		# copses in the valley (wind breaks and pasture shade)
		Vector3(62, -78, 16), Vector3(-42, -104, 18), Vector3(150, 12, 18), Vector3(-10, 98, 14), Vector3(170, 96, 16),
		Vector3(96, 150, 16), Vector3(-110, 120, 22),
	]
	var v: float = 0.0
	for b in blobs:
		var bb: Vector3 = b
		var d: float = Vector2(x - bb.x, z - bb.y).length() / bb.z
		v = maxf(v, 1.0 - Terrain.sstep(0.55, 1.0, d))
	v = clampf(v + _fn.get_noise_2d(x, z) * 0.35, 0.0, 1.0)
	# clearings: the Carvalha-Mãe glade, the quarry pit
	v *= Terrain.sstep(18.0, 30.0, Vector2(x + 185, z - 25).length())
	v *= Terrain.sstep(26.0, 40.0, Vector2(x + 214, z - 166).length())
	return v


func is_field(x: float, z: float) -> float:
	# fields of the Quinta do Rego: [centre, half size]
	var f: float = 0.0
	for r in FIELDS:
		var c: Vector2 = r[0]
		var hs: Vector2 = r[1]
		var ex: float = absf(x - c.x) - hs.x
		var ez: float = absf(z - c.y) - hs.y
		f = maxf(f, 1.0 - Terrain.sstep(-1.5, 1.0, maxf(ex, ez)))
	return f


# [centre, half size, crop]
const FIELDS: Array = [
	[Vector2(136, 50), Vector2(18, 24), "wheat"],
	[Vector2(136, 104), Vector2(18, 20), "grey"],
	[Vector2(96, 106), Vector2(16, 16), "turnip"],
	[Vector2(64, 104), Vector2(10, 18), "wheat"],
]


func _ctrl_texture() -> ImageTexture:
	var N: int = Terrain.N
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	for j in N:
		var z: float = -Terrain.HALF + j * Terrain.STEP
		for i in N:
			var x: float = -Terrain.HALF + i * Terrain.STEP
			var k: int = j * N + i
			var forest: float = forest_density(x, z)
			var rd: float = terrain.river_d[k]
			var wet: float = 0.0
			if rd < 1e8:
				wet = 1.0 - Terrain.sstep(terrain.river_w[k] + 1.0, terrain.river_w[k] + 6.0, rd)
			var ln: float = terrain.lake_norm(x, z)
			var hy: float = terrain.h[k]
			var sand: float = (1.0 - Terrain.sstep(1.05, 1.22, ln)) * (1.0 - Terrain.sstep(2.6, 3.4, hy))
			# north shore is a beach, the rest is reedy mud
			if z > Terrain.LAKE_C.y - 10.0:
				wet = maxf(wet, sand)
				sand *= 0.2
			img.set_pixel(i, j, Color(forest, wet, sand, is_field(x, z)))
	return ImageTexture.create_from_image(img)


func _path_texture() -> ImageTexture:
	var S: int = 640
	var data: PackedByteArray = PackedByteArray()
	data.resize(S * S)
	for r in terrain.roads:
		var hw: float = r.hw
		var pts: PackedVector3Array = r.pts
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]
			var b: Vector3 = pts[k + 1]
			var steps: int = int(ceil(a.distance_to(b)))
			for s in steps:
				var p: Vector3 = a.lerp(b, float(s) / steps)
				_stamp_disc(data, S, Vector2(p.x, p.z), hw)
	_stamp_disc(data, S, SQUARE, 14.0)
	for extra in path_discs:
		var e: Vector3 = extra
		_stamp_disc(data, S, Vector2(e.x, e.z), e.y)
	var img: Image = Image.create_from_data(S, S, false, Image.FORMAT_L8, data)
	return ImageTexture.create_from_image(img)


var path_discs: Array = []   # Vector3(x, radius, z): yards, camp floors


func _stamp_disc(data: PackedByteArray, S: int, c: Vector2, R: float) -> void:
	var cx: float = c.x + 320.0
	var cz: float = c.y + 320.0
	var e: float = R + 1.5
	for j in range(maxi(0, int(cz - e)), mini(S - 1, int(cz + e) + 1)):
		for i in range(maxi(0, int(cx - e)), mini(S - 1, int(cx + e) + 1)):
			var d: float = Vector2(i + 0.5 - cx, j + 0.5 - cz).length()
			var v: int = int(255.0 * (1.0 - Terrain.sstep(R - 0.8, R + 1.2, d)))
			var idx: int = j * S + i
			if v > data[idx]:
				data[idx] = v


# ------------------------------------------------------------------ water
var water_noise: NoiseTexture2D


func _water_mat(flow: float) -> ShaderMaterial:
	if water_noise == null:
		water_noise = NoiseTexture2D.new()
		water_noise.seamless = true
		water_noise.width = 256
		water_noise.height = 256
		water_noise.generate_mipmaps = true
		var n: FastNoiseLite = FastNoiseLite.new()
		n.frequency = 0.03
		n.fractal_octaves = 3
		water_noise.noise = n
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://world/water.gdshader")
	m.set_shader_parameter("wave_noise", water_noise)
	m.set_shader_parameter("flow_speed", flow)
	if flow <= 0.0:
		m.set_shader_parameter("wave_height", 0.06)
	return m


func _water() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Water"
	add_child(holder)
	# river ribbon
	var pts: PackedVector3Array = terrain.river_pts
	var cols: int = 9
	var verts: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var along: float = 0.0
	var rows: int = 0
	for k in pts.size():
		var p: Vector3 = pts[k]
		if terrain.lake_norm(p.x, p.z) < 0.9:
			break
		var tng: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)])
		tng.y = 0.0
		tng = tng.normalized()
		var across: Vector3 = Vector3(-tng.z, 0, tng.x)
		var hw: float = terrain.river_hw[k] + 4.0
		if k > 0:
			along += Vector2(p.x - pts[k - 1].x, p.z - pts[k - 1].z).length()
		for c in cols:
			var u: float = lerpf(-1.0, 1.0, float(c) / (cols - 1))
			var q: Vector3 = p + across * (u * hw)
			q.y = p.y
			var depth: float = p.y - terrain.sample(q.x, q.z)
			verts.append(q)
			norms.append(Vector3.UP)
			colors.append(Color(clampf(depth / 4.0, 0.0, 1.0), 0, 0, 1))
			uvs.append(Vector2(along, u * hw))
		if rows > 0:
			var base_i: int = (rows - 1) * cols
			for c in cols - 1:
				var a: int = base_i + c
				idx.append_array([a, a + cols, a + 1, a + 1, a + cols, a + cols + 1])
		rows += 1
	holder.add_child(_mesh_node("River", verts, norms, uvs, colors, idx, _water_mat(0.9)))
	# lake grid
	verts = PackedVector3Array()
	colors = PackedColorArray()
	uvs = PackedVector2Array()
	norms = PackedVector3Array()
	idx = PackedInt32Array()
	var st: float = 2.0
	var x0: float = Terrain.LAKE_C.x - Terrain.LAKE_R.x * 1.3
	var z0: float = Terrain.LAKE_C.y - Terrain.LAKE_R.y * 1.3
	var nx: int = int(Terrain.LAKE_R.x * 2.6 / st) + 1
	var nz: int = int(Terrain.LAKE_R.y * 2.6 / st) + 1
	var vid: Dictionary = {}
	for j in nz:
		for i in nx:
			var x: float = x0 + i * st
			var z: float = z0 + j * st
			var depth: float = Terrain.LAKE_Y - terrain.sample(x, z)
			vid[Vector2i(i, j)] = verts.size()
			verts.append(Vector3(x, Terrain.LAKE_Y, z))
			norms.append(Vector3.UP)
			colors.append(Color(clampf(depth / 4.0, 0.0, 1.0), 0, 0, 1))
			uvs.append(Vector2(x, z))
	for j in nz - 1:
		for i in nx - 1:
			var a: int = vid[Vector2i(i, j)]
			var b: int = vid[Vector2i(i + 1, j)]
			var c: int = vid[Vector2i(i, j + 1)]
			var d: int = vid[Vector2i(i + 1, j + 1)]
			var any_wet: bool = false
			for q in [a, b, c, d]:
				if colors[q].r > 0.0 or Terrain.LAKE_Y - terrain.sample(verts[q].x, verts[q].z) > -0.4:
					any_wet = true
			if any_wet:
				idx.append_array([a, b, d, a, d, c])
	holder.add_child(_mesh_node("Lake", verts, norms, uvs, colors, idx, _water_mat(0.0)))


func _mesh_node(nm: String, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, idx: PackedInt32Array, mat: Material) -> MeshInstance3D:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = idx
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ light and sky
func _sky() -> void:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.33, 0.52, 0.80)
	sky_mat.sky_horizon_color = Color(0.93, 0.76, 0.56)
	sky_mat.sky_curve = 0.3
	sky_mat.ground_bottom_color = Color(0.62, 0.56, 0.46)
	sky_mat.ground_horizon_color = Color(0.80, 0.68, 0.52)
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.ambient_light_sky_contribution = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.76, 0.62)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0019
	env.fog_sky_affect = 0.25
	env.fog_sun_scatter = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	# low golden-hour sun from the south-west: lights the castle cliff face as seen from the square
	var dir: Vector3 = Vector3(0.55, -0.36, -0.75).normalized()
	sun.basis = Basis.looking_at(dir, Vector3.UP)
	sun.light_color = Color(1.0, 0.84, 0.64)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	add_child(sun)
