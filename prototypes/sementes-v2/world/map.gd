# PROTOTYPE - NOT FOR PRODUCTION
# Map module (owner: map agent). Contract: ARCHITECTURE.md "Map — world/map.gd".
# Builds the Vale de Lume, one hand-laid region of about 600 x 600 m (x east, z south, y up, metres), inside a
# 960 x 960 m world: beyond the eastern mountains, up the Passo da Escama gorge, lie the Pastos da Cauda.
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
# EAST OF THE BORDER (post-game, x 300..460): the east road forks at (150,-30), skirts the Atalaia hill and climbs the
# PASSO DA ESCAMA, a gorge through the mountains that pinches to ~10 m at (292,11). At its head (338,8) opens the
# PASTOS DA CAUDA, the summer pastures on the dragon's tail (plateau y~30): the Marco da Cauda by the pass, the
# shepherds' fold and hut (372..392, -14..10), and a track north-east to the PONTA DA CAUDA (396,-58), where the
# last Vigília guards dig the "scales" of the Lumeira.
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
const Places = preload("res://world/places.gd")

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
	Vector3(-125, 0, -105), Vector3(-100, 0, -42), Vector3(-80, 0, 8), Vector3(-62, 0, 43),
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
	# the old drove road up to the summer pastures: around the Atalaia hill, up the Passo da Escama to the fold
	{"id": "cauda", "hw": 2.0, "pts": [Vector2(150, -30), Vector2(166, -8), Vector2(194, 8), Vector2(222, 14),
		Vector2(244, 14), Vector2(268, 12), Vector2(292, 11), Vector2(316, 9), Vector2(338, 8), Vector2(356, 6),
		Vector2(372, 2), Vector2(386, 0)]},
	{"id": "cauda_ponta", "hw": 1.4, "pts": [Vector2(372, 2), Vector2(380, -18), Vector2(386, -34), Vector2(390, -46)]},
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
	terrain.trenches = [
		{"pts": [Vector2(176, -174), Vector2(176, -186), Vector2(178, -199), Vector2(183, -212), Vector2(186, -222)], "hw": 3.2, "y0": NAN, "rise": 2.5},
		{"pts": [Vector2(186, -222), Vector2(187, -226)], "hw": 7.5, "y0": NAN, "rise": 0.0},
	]
	terrain.generate(river_ctrl, road_defs, pads)
	for p in places:
		var pp: Vector3 = p.pos
		p.pos = Vector3(pp.x, terrain.sample(pp.x, pp.z), pp.z)
	stats["t_terrain_ms"] = Time.get_ticks_msec() - t0
	_static = StaticBody3D.new()
	_static.name = "Buildings"
	_static.collision_layer = 1
	add_child(_static)
	_sky()
	_ground()
	_water()
	stats["t_ground_ms"] = Time.get_ticks_msec() - t0
	var pl: Places = Places.new(self, terrain, kit, _static)
	pl.village()
	pl.farm()
	pl.river_place()
	pl.lake()
	pl.forest()
	pl.bandit_camp()
	pl.watchtower()
	pl.mine()
	pl.castle()
	pl.cauda()
	pl.commit_all()
	stats["t_places_ms"] = Time.get_ticks_msec() - t0
	veg = Veg.new(kit)
	_scatter()
	var vh: Node3D = Node3D.new()
	vh.name = "Vegetation"
	add_child(vh)
	veg.commit(vh)
	stats["veg_instances"] = veg.count
	for p in places:
		if not spawns.has(p.id):
			spawns[p.id] = (p.pos as Vector3) + Vector3(0, 0.1, 0)
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
		["passo_escama", "Passo da Escama", Vector2(292, 11), 26.0],
		["cauda", "Pastos da Cauda", Vector2(376, 12), 56.0],
		["cauda_ponta", "Ponta da Cauda", Vector2(396, -58), 26.0],
	]
	for d in defs:
		var v: Vector2 = d[2]
		places.append({"id": d[0], "name": d[1], "pos": Vector3(v.x, 0, v.y), "radius": d[3]})


func _house(id: String, pos: Vector2, yaw: float, spec: Dictionary) -> void:
	var w: float = float(spec.get("w", 3)) * 2.0
	var d: float = float(spec.get("d", 3)) * 2.0
	var pad: Dictionary = {"c": pos, "size": Vector2(w + 2.5, d + 2.5), "yaw": yaw, "y": NAN, "fall": float(spec.get("fall", 4.5))}
	pads.append(pad)
	houses.append({"id": id, "pos": pos, "yaw": yaw, "spec": spec, "pad": pad})


func _pad(pos: Vector2, size: Vector2, yaw: float) -> Dictionary:
	var pad: Dictionary = {"c": pos, "size": size, "yaw": yaw, "y": NAN}
	pads.append(pad)
	return pad


var castle_pad: Dictionary
var path_discs: Array = []   # Vector3(x, radius, z): yards, camp floors


# Every building of the valley, placed by hand: position, yaw (front faces rot(yaw)*+Z) and what it is.
# Houses face their street or the square; the numbers come from the plan at the top of this file.
func _define_buildings() -> void:
	var V: String = "Village"
	# around the square (each faces the Pedra do Primeiro Lume)
	_house("inn", Vector2(-17, -38), 0.76, {"w": 4, "d": 5, "floors": 2, "style": "brick", "balcony": true, "door": 1, "seed": 11, "region": V})
	_house("forge", Vector2(19, -37), -0.84, {"w": 3, "d": 4, "floors": 1, "style": "brick", "door": 1, "seed": 12, "region": V})
	_house("elder", Vector2(-23, -3), 2.2, {"w": 2, "d": 3, "floors": 1, "style": "plaster", "door": 1, "seed": 13, "region": V})
	_house("chapel", Vector2(19, 7), -2.53, {"w": 3, "d": 5, "floors": 2, "style": "brick", "door": 1, "chimney": false, "seed": 14, "region": V})
	# north street, climbing toward the castle
	_house("guard", Vector2(-12, -57), PI * 0.5, {"w": 3, "d": 3, "floors": 1, "style": "brick", "seed": 15, "region": V})
	_house("A", Vector2(13, -50), -PI * 0.5, {"w": 3, "d": 3, "floors": 2, "style": "plaster", "balcony": true, "seed": 16, "region": V})
	_house("B", Vector2(17, -67), -1.4, {"w": 2, "d": 3, "floors": 2, "style": "wood", "door": 0, "seed": 17, "region": V})
	_house("C", Vector2(-8, -76), 1.75, {"w": 3, "d": 4, "floors": 1, "style": "plaster", "seed": 18, "region": V})
	# mill road (west) and lake road (south)
	_house("D", Vector2(-47, -6), 1.4, {"w": 3, "d": 3, "floors": 2, "style": "brick", "seed": 19, "region": V})
	_house("E", Vector2(-34, 22), -PI * 0.5, {"w": 2, "d": 3, "floors": 1, "style": "wood", "seed": 20, "region": V})
	_house("H", Vector2(-13, 20), PI * 0.5, {"w": 2, "d": 4, "floors": 2, "style": "plaster", "door": 1, "seed": 21, "region": V})
	# east road
	_house("F", Vector2(33, -35), 0.1, {"w": 3, "d": 4, "floors": 2, "style": "plaster", "seed": 22, "region": V})
	_house("G", Vector2(52, -11), PI, {"w": 3, "d": 3, "floors": 1, "style": "wood", "seed": 23, "region": V})
	# Quinta do Rego: farmhouse facing the yard, the barn, the coop
	_house("farmhouse", Vector2(98, 50), 0.0, {"w": 3, "d": 4, "floors": 2, "style": "plaster", "door": 1, "seed": 31, "region": "Farm"})
	_house("barn", Vector2(113, 74), -PI * 0.5, {"w": 4, "d": 5, "floors": 1, "style": "wood", "door": 2, "chimney": false, "seed": 32, "region": "Farm"})
	_house("coop", Vector2(87, 79), 2.43, {"w": 2, "d": 2, "floors": 1, "style": "wood", "door": 0, "chimney": false, "seed": 33, "region": "Farm"})
	# the mill on the east bank (small pad falloff so it does not fill the river), the toll hut at the bridge
	_house("mill", Vector2(-53, 40), PI * 0.5, {"w": 3, "d": 4, "floors": 2, "style": "brick", "door": 1, "seed": 41, "region": "River", "fall": 1.5})
	_house("toll", Vector2(-44, 70), -2.2, {"w": 2, "d": 2, "floors": 1, "style": "wood", "door": 0, "seed": 42, "region": "River"})
	# Dona Celeste's hut above the pier, Gaspar's cabin at the mine mouth
	_house("celeste", Vector2(62, 156), -PI * 0.5, {"w": 2, "d": 3, "floors": 1, "style": "wood", "door": 1, "seed": 51, "region": "Lake"})
	_house("gaspar", Vector2(197, -174), -PI * 0.5, {"w": 2, "d": 2, "floors": 1, "style": "wood", "door": 0, "seed": 61, "region": "Mine"})
	# the shepherds' summer hut on the Pastos da Cauda, facing the drove road
	_house("pastor", Vector2(372, -14), 0.0, {"w": 2, "d": 2, "floors": 1, "style": "wood", "door": 0, "seed": 71, "region": "Cauda"})
	castle_pad = _pad(Vector2(4, -216), Vector2(50, 42), 0.0)
	castle_pad["fall"] = 3.0
	# dirt yards (ground layer only): farmyard, castle court, quarry floor, tower top, mine apron, mill yard
	path_discs = [Vector3(100, 10, 64), Vector3(4, 20, -216), Vector3(-212, 13, 166), Vector3(186, 9, -48),
		Vector3(177, 6, -180), Vector3(-47, 5, 47), Vector3(-44, 4, 70), Vector3(62, 4, 156), Vector3(-185, 9, 25),
		Vector3(386, 8, 2), Vector3(392, 9, -50)]   # the Cauda fold yard, the Ponta dig


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
		# Pastos da Cauda: two wind-bent copses of pine where the herds sheltered
		Vector3(420, 40, 22), Vector3(344, -52, 18),
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
			if (absf(x) > 320.0 or absf(z) > 320.0) and not _in_world(x, z):
				continue  # bare mountain: no forest floor, mud, sand or field (the image starts at zero)
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
	var S: int = int(2.0 * Terrain.HALF)
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




func _stamp_disc(data: PackedByteArray, S: int, c: Vector2, R: float) -> void:
	var cx: float = c.x + Terrain.HALF
	var cz: float = c.y + Terrain.HALF
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


# ------------------------------------------------------------------ vegetation rules
# Nothing grows by noise alone. Every set has a reason:
#  trees      - inside the authored forest blobs (forest_density), species by place (pines up north and on high
#               ground, oaks and twisted trees in the Bosque, birch-like common trees in valley copses); a few
#               hand-placed shade trees in the village and the farm.
#  understory - ferns, bushes and mushrooms only under trees; bushes along forest edges.
#  grass      - tufts on road shoulders, around building footings and fences, in meadow patches.
#  reeds      - tall wispy grass on the river banks and the reedy (south/east) lake shore.
#  flowers    - in a few named meadows (square gardens, lake shore, the Carvalha glade, the watchtower hill).
#  boulders   - at the foot of steep slopes and along the river; pebbles on road edges.
#  crops      - rows in the farm fields (wheat gold, grey field dead tufts).
var _blocked: PackedByteArray
var _rng: RandomNumberGenerator


func _block_mask() -> void:
	var N: int = Terrain.N
	_blocked = PackedByteArray()
	_blocked.resize(N * N)
	var items: Array = []
	for pad in pads:
		items.append([pad.c, (pad.size as Vector2) * 0.5 + Vector2(1.5, 1.5), float(pad.yaw)])
	for d in path_discs:
		var e: Vector3 = d
		items.append([Vector2(e.x, e.z), Vector2(e.y, e.y) * 0.75, 0.0])
	items.append([SQUARE, Vector2(15, 15), 0.0])
	for it in items:
		var c: Vector2 = it[0]
		var hs: Vector2 = it[1]
		var yaw: float = it[2]
		var R: float = hs.length()
		for j in range(maxi(0, int((c.y - R + Terrain.HALF) / Terrain.STEP)), mini(N - 1, int((c.y + R + Terrain.HALF) / Terrain.STEP) + 1) + 1):
			for i in range(maxi(0, int((c.x - R + Terrain.HALF) / Terrain.STEP)), mini(N - 1, int((c.x + R + Terrain.HALF) / Terrain.STEP) + 1) + 1):
				var x: float = -Terrain.HALF + i * Terrain.STEP - c.x
				var z: float = -Terrain.HALF + j * Terrain.STEP - c.y
				var lx: float = x * cos(yaw) - z * sin(yaw)
				var lz: float = x * sin(yaw) + z * cos(yaw)
				if absf(lx) <= hs.x and absf(lz) <= hs.y:
					_blocked[j * N + i] = 1


# where things grow: the old valley and, east of it, the pass and the Pastos da Cauda (the rest is bare mountain)
func _in_world(x: float, z: float) -> bool:
	return (absf(x) <= 312.0 and absf(z) <= 312.0) or (x > 236.0 and x < 462.0 and absf(z) < 140.0)


func _free(x: float, z: float, road_margin: float) -> bool:
	if not _in_world(x, z):
		return false
	var N: int = Terrain.N
	var i: int = clampi(int(round((x + Terrain.HALF) / Terrain.STEP)), 0, N - 1)
	var j: int = clampi(int(round((z + Terrain.HALF) / Terrain.STEP)), 0, N - 1)
	var k: int = j * N + i
	if _blocked[k] != 0:
		return false
	if terrain.road_d[k] < road_margin:
		return false
	if terrain.river_d[k] < terrain.river_w[k] + 1.0:
		return false
	if terrain.lake_norm(x, z) < 1.04:
		return false
	if is_field(x, z) > 0.05:
		return false
	return true


func _slope(x: float, z: float) -> float:
	return 1.0 - terrain.normal_at(x, z).y


func _put(name: String, x: float, z: float, s: float, tint: Color = Color(1, 1, 1), sink: float = 0.0) -> void:
	var y: float = terrain.sample(x, z) - sink
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y, z))
	veg.add(name, xf, tint)


func _scatter() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 2024
	_block_mask()
	var common: Array[String] = ["CommonTree_1", "CommonTree_2", "CommonTree_4"]
	var pines: Array[String] = ["Pine_1", "Pine_2", "Pine_4"]
	var twisted: Array[String] = ["TwistedTree_1", "TwistedTree_5"]
	for n in common + pines + twisted:
		veg.define(n, 200.0, true, 30.0)
	for n in ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Plant_1_Big"]:
		veg.define(n, 46.0, false)
	veg.define("Mushroom_Common", 35.0, false)
	for n in ["Grass_Common_Short", "Grass_Wispy_Short", "Grass_Wispy_Tall", "Grass_Common_Short#wheat", "Grass_Wispy_Short#grey"]:
		veg.define(n, 28.0, false)
	for n in ["Flower_3_Group", "Flower_4_Group", "Clover_1"]:
		veg.define(n, 30.0, false)
	for n in ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]:
		veg.define(n, 170.0, true, 34.0)
	veg.define("Pebble_Round_2", 30.0, false)
	veg.define("Pebble_Square_3", 30.0, false)
	veg.define("DeadTree_2", 180.0, true, 34.0)
	veg.define("DeadTree_4", 180.0, true, 34.0)

	# --- forest trees on a jittered 7 m grid
	var trees: Array = []
	var gs: float = 8.5
	var z: float = -310.0
	while z < 310.0:
		var x: float = -310.0
		while x < 462.0:
			var px: float = x + _rng.randf_range(-2.8, 2.8)
			var pz: float = z + _rng.randf_range(-2.8, 2.8)
			x += gs
			var f: float = forest_density(px, pz)
			var hy: float = terrain.sample(px, pz)
			# the mountain flanks get thin pine woods up to the tree line
			var mt: float = 0.0
			if hy > 22.0 and hy < 58.0 and _slope(px, pz) < 0.45:
				mt = 0.55 * (1.0 - Terrain.sstep(46.0, 58.0, hy)) * (1.0 - terrain.cauda_mask(px, pz))  # pasture stays open
			f = maxf(f, mt)
			if f < 0.25 or _rng.randf() > f * 0.72:
				continue
			if not _free(px, pz, 6.0):
				continue
			if _slope(px, pz) > 0.5:
				continue
			# keep the castle plateau and the quarry pit bare
			if Vector2(px - 8, pz + 214).length() < 40.0:
				continue
			var nm: String
			var s: float = _rng.randf_range(0.85, 1.3)
			var bosque: bool = px < -95.0 and pz > -120.0
			if pz < -150.0 or hy > 24.0:
				nm = pines[_rng.randi() % 3]
			elif bosque:
				var r: float = _rng.randf()
				if r < 0.12:
					nm = twisted[_rng.randi() % 2]
					s = _rng.randf_range(0.7, 0.95)
				elif r < 0.35:
					nm = pines[_rng.randi() % 3]
				else:
					nm = common[_rng.randi() % 3]
			else:
				nm = common[_rng.randi() % 3] if _rng.randf() < 0.75 else pines[_rng.randi() % 3]
			var tint: Color = Color(1, 1, 1).lerp(Color(1.12, 1.0, 0.75), _rng.randf() * 0.6)
			if bosque:
				tint = tint * Color(0.9, 0.98, 0.88)
			_put(nm, px, pz, s, tint, 0.2)
			trees.append(Vector3(px, s, pz))
		z += gs
	stats["trees"] = trees.size()
	# hand-placed shade trees: the square, the inn yard, the farm lane, the pier path, the chapel
	var shade: Array = [Vector2(-10, -30), Vector2(13, 2), Vector2(-28, -46), Vector2(30, -8), Vector2(-24, 10),
		Vector2(78, 54), Vector2(88, 40), Vector2(122, 92), Vector2(54, 144), Vector2(70, 170), Vector2(36, 20),
		Vector2(-36, 52), Vector2(-60, 92), Vector2(160, -38), Vector2(-4, -92), Vector2(44, -48)]
	for sp in shade:
		var v: Vector2 = sp
		_put(common[_rng.randi() % 3], v.x, v.y, _rng.randf_range(1.05, 1.3), Color(1.05, 1.0, 0.85), 0.2)
		trees.append(Vector3(v.x, 1.1, v.y))
	# dead trees where the seeds were dug out (grey field) and on the watchtower road
	for dp in [Vector2(150, 118), Vector2(124, 120), Vector2(172, -20), Vector2(205, -60)]:
		var dv: Vector2 = dp
		_put("DeadTree_2" if dv.x < 160 else "DeadTree_4", dv.x, dv.y, 0.6, Color(1, 1, 1), 0.2)
	# trunk collision (one cylinder each, cheap)
	for tr in trees:
		var tv: Vector3 = tr
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: CylinderShape3D = CylinderShape3D.new()
		sh.radius = 0.35 * tv.y
		sh.height = 4.0
		cs.shape = sh
		cs.position = Vector3(tv.x, terrain.sample(tv.x, tv.z) + 1.8, tv.z)
		_static.add_child(cs)

	# --- understory: under and around trees
	for tr in trees:
		var tv2: Vector3 = tr
		var nn: int = _rng.randi_range(0, 3)
		for k in nn:
			var a: float = _rng.randf() * TAU
			var r2: float = _rng.randf_range(1.5, 4.5)
			var ux: float = tv2.x + cos(a) * r2
			var uz: float = tv2.z + sin(a) * r2
			if not _free(ux, uz, 3.0):
				continue
			var pick: float = _rng.randf()
			var dens: float = forest_density(ux, uz)
			if pick < 0.35:
				_put("Fern_1", ux, uz, _rng.randf_range(0.8, 1.3))
			elif pick < 0.55:
				_put("Bush_Common", ux, uz, _rng.randf_range(0.7, 1.2), Color(1, 1, 1).lerp(Color(1.1, 1.05, 0.7), _rng.randf()))
			elif pick < 0.65 and dens < 0.6:
				_put("Bush_Common_Flowers", ux, uz, _rng.randf_range(0.7, 1.0))
			elif pick < 0.75 and dens > 0.5:
				_put("Mushroom_Common", ux, uz, _rng.randf_range(0.8, 1.4))
			elif pick < 0.85:
				_put("Plant_1_Big", ux, uz, _rng.randf_range(0.6, 0.9))
			else:
				_put("Grass_Wispy_Short", ux, uz, _rng.randf_range(0.8, 1.2))

	# --- road shoulders: grass tufts, a pebble now and then, flowers near the village
	for r in terrain.roads:
		var pts: PackedVector3Array = r.pts
		var hw: float = r.hw
		for k in range(0, pts.size() - 1):
			var p: Vector3 = pts[k]
			var q: Vector3 = pts[k + 1]
			var dir: Vector3 = (q - p)
			dir.y = 0.0
			if dir.length() < 0.01:
				continue
			dir = dir.normalized()
			var side: Vector3 = Vector3(-dir.z, 0, dir.x)
			for sgn in [-1.0, 1.0]:
				if _rng.randf() > 0.7:
					continue
				var off: float = hw + _rng.randf_range(0.6, 2.2)
				var g: Vector3 = p + side * (sgn * off) + dir * _rng.randf_range(0.0, 2.0)
				if not _free(g.x, g.z, hw + 0.4):
					continue
				var rr: float = _rng.randf()
				if rr < 0.6:
					_put("Grass_Common_Short", g.x, g.z, _rng.randf_range(0.8, 1.3))
				elif rr < 0.8:
					_put("Grass_Wispy_Short", g.x, g.z, _rng.randf_range(0.8, 1.2))
				elif rr < 0.9:
					_put("Pebble_Round_2" if _rng.randf() < 0.5 else "Pebble_Square_3", g.x, g.z, _rng.randf_range(1.0, 2.2))
				elif Vector2(g.x, g.z).distance_to(SQUARE) < 140.0:
					_put("Flower_3_Group" if _rng.randf() < 0.5 else "Flower_4_Group", g.x, g.z, _rng.randf_range(0.6, 0.9))

	# --- meadow patches of grass and clover (clumped, never a uniform carpet)
	var mn: FastNoiseLite = FastNoiseLite.new()
	mn.seed = 77
	mn.frequency = 0.045
	var gz: float = -300.0
	while gz < 300.0:
		var gx: float = -300.0
		while gx < 462.0:
			var px2: float = gx + _rng.randf_range(-1.6, 1.6)
			var pz2: float = gz + _rng.randf_range(-1.6, 1.6)
			gx += 3.2
			var clump: float = mn.get_noise_2d(px2, pz2)
			if clump < 0.18:
				continue
			if _rng.randf() > (clump - 0.18) * 2.2:
				continue
			if (terrain.sample(px2, pz2) > 30.0 and terrain.cauda_mask(px2, pz2) < 0.5) or _slope(px2, pz2) > 0.3:
				continue
			if not _free(px2, pz2, 3.5):
				continue
			var rr2: float = _rng.randf()
			if rr2 < 0.55:
				_put("Grass_Common_Short", px2, pz2, _rng.randf_range(0.8, 1.4), Color(1, 1, 1).lerp(Color(1.15, 1.05, 0.7), _rng.randf()))
			elif rr2 < 0.8:
				_put("Grass_Wispy_Short", px2, pz2, _rng.randf_range(0.9, 1.4))
			elif rr2 < 0.92:
				_put("Clover_1", px2, pz2, _rng.randf_range(0.7, 1.0))
			else:
				_put("Flower_3_Group" if _rng.randf() < 0.5 else "Flower_4_Group", px2, pz2, _rng.randf_range(0.6, 0.9))
		gz += 3.2

	# --- named flower meadows
	var meadows: Array = [Vector3(-30, 12, -60), Vector3(70, 14, 180), Vector3(-185, 12, 25), Vector3(170, 16, -60),
		Vector3(-14, 8, 4), Vector3(26, 8, -12), Vector3(356, 18, 40), Vector3(352, 8, 20)]
	for md in meadows:
		var mv: Vector3 = md
		for k in int(mv.y * 3.0):
			var a2: float = _rng.randf() * TAU
			var r3: float = sqrt(_rng.randf()) * mv.y
			var fx: float = mv.x + cos(a2) * r3
			var fz: float = mv.z + sin(a2) * r3
			if not _free(fx, fz, 2.5):
				continue
			_put(["Flower_3_Group", "Flower_4_Group", "Clover_1", "Flower_3_Group"][_rng.randi() % 4], fx, fz, _rng.randf_range(0.55, 0.9))

	# --- river banks: reeds and stones; lake: reeds on the south/east shore, stones on the beach
	var rp: PackedVector3Array = terrain.river_pts
	for k in range(0, rp.size() - 1):
		var p2: Vector3 = rp[k]
		var d2: Vector3 = rp[k + 1] - p2
		d2.y = 0.0
		var side2: Vector3 = Vector3(-d2.z, 0, d2.x).normalized()
		var w: float = terrain.river_hw[k]
		for sgn2 in [-1.0, 1.0]:
			var rr3: float = _rng.randf()
			var b: Vector3 = p2 + side2 * (sgn2 * (w + _rng.randf_range(0.2, 2.5)))
			if _blocked[clampi(int(round((b.z + Terrain.HALF) / Terrain.STEP)), 0, Terrain.N - 1) * Terrain.N + clampi(int(round((b.x + Terrain.HALF) / Terrain.STEP)), 0, Terrain.N - 1)] != 0:
				continue
			if terrain.cell(b.x, b.z, terrain.road_d) < 4.0:
				continue
			if rr3 < 0.45:
				_put("Grass_Wispy_Tall", b.x, b.z, _rng.randf_range(0.9, 1.4), Color(1.05, 1.0, 0.8))
			elif rr3 < 0.53:
				_put("Rock_Medium_%d" % (_rng.randi() % 3 + 1), b.x, b.z, _rng.randf_range(0.3, 0.7), Color(1, 1, 1), 0.3)
	for k in 900:
		var a3: float = _rng.randf() * TAU
		var lr: float = _rng.randf_range(1.0, 1.12)
		var lx: float = Terrain.LAKE_C.x + cos(a3) * Terrain.LAKE_R.x * lr
		var lz: float = Terrain.LAKE_C.y + sin(a3) * Terrain.LAKE_R.y * lr
		var ln: float = terrain.lake_norm(lx, lz)
		if ln < 0.98 or ln > 1.14:
			continue
		if terrain.cell(lx, lz, terrain.road_d) < 4.0 or absf(lx - 44.0) < 4.0 and lz < 190.0:
			continue
		var beach: bool = lz < Terrain.LAKE_C.y - 10.0
		if beach:
			if _rng.randf() < 0.08:
				_put("Rock_Medium_%d" % (_rng.randi() % 3 + 1), lx, lz, _rng.randf_range(0.25, 0.6), Color(1, 1, 1), 0.25)
		elif _rng.randf() < 0.55:
			_put("Grass_Wispy_Tall", lx, lz, _rng.randf_range(1.0, 1.5), Color(1.05, 1.0, 0.8))

	# --- boulders at the foot of steep ground (cliffs, quarry walls, the mine spur), never on roads
	var bz: float = -300.0
	while bz < 300.0:
		var bx: float = -300.0
		while bx < 462.0:
			var qx: float = bx + _rng.randf_range(-3.0, 3.0)
			var qz: float = bz + _rng.randf_range(-3.0, 3.0)
			bx += 6.0
			var sl: float = _slope(qx, qz)
			if sl < 0.12 or sl > 0.4:
				continue
			# foot of a cliff: steep ground just uphill
			var n: Vector3 = terrain.normal_at(qx, qz)
			var up: Vector2 = Vector2(-n.x, -n.z).normalized()
			if _slope(qx + up.x * 4.0, qz + up.y * 4.0) < 0.5:
				continue
			if not _free(qx, qz, 4.0) or _rng.randf() > 0.6:
				continue
			_put("Rock_Medium_%d" % (_rng.randi() % 3 + 1), qx, qz, _rng.randf_range(0.6, 1.6), Color(1, 1, 1).lerp(Color(0.85, 0.82, 0.78), _rng.randf()), 0.4)
		bz += 6.0

	# --- crops: wheat rows (gold), the grey field (dead tufts), turnip rows
	for fdef in FIELDS:
		var c: Vector2 = fdef[0]
		var hs: Vector2 = fdef[1]
		var crop: String = fdef[2]
		var row: float = -hs.y + 1.0
		while row < hs.y - 0.5:
			var cx: float = -hs.x + 1.0
			while cx < hs.x - 0.5:
				var wx: float = c.x + cx + _rng.randf_range(-0.3, 0.3)
				var wz: float = c.y + row
				if crop == "wheat" and _rng.randf() < 0.85:
					_put("Grass_Common_Short#wheat", wx, wz, _rng.randf_range(0.9, 1.25))
				elif crop == "grey" and _rng.randf() < 0.18:
					_put("Grass_Wispy_Short#grey", wx, wz, _rng.randf_range(0.6, 1.0))
				elif crop == "turnip" and _rng.randf() < 0.4:
					_put("Plant_1_Big", wx, wz, _rng.randf_range(0.35, 0.5), Color(0.9, 1.05, 0.75))
				cx += 1.6 if crop == "wheat" else 2.2
			row += 1.4
