# PROTOTYPE - NOT FOR PRODUCTION
# The open world around the first valley, built from the KayKit Medieval Hexagon Pack (CC0) at giant scale: every hex
# is 32 m across and stands on a terrace of 3 m steps (climb a step, or walk up a ramp tile). 20 x 20 km of meadows,
# forests, autumn woods, snowy pine hills, deserts, lakes and mountains, with kingdoms of walled castle cities and
# villages (blue, red, yellow and green roofs) joined by road tiles. Everything comes from one seed and is streamed:
# detailed chunks of hexes around the player, a coarse horizon mesh out to ~4 km, a castle on the skyline for every
# town until you get close.
extends Node3D

const Level = preload("res://level.gd")
const HALF := 10000.0  # the world spans -10 km .. +10 km on x and z
const TOWN_CELL := 2000.0  # one town per 2 x 2 km cell
const CHUNK := 128.0
const LOAD_R := 2  # chunks kept around the player (5 x 5)
const TOWN_LOAD := 650.0
const TOWN_FREE := 850.0
const CENTER_R := 230.0  # inside: the hand-built valley (Level.ground_h); blended into the wild over BLEND
const BLEND := 140.0
const VALLEY_R := 360.0  # no hexes inside: the valley keeps its own smooth ground out to here
const FAR_N := 96  # horizon mesh: FAR_N x FAR_N quads of FAR_STEP metres around the player
const FAR_STEP := 80.0
# hex geometry: pointy-top kit hexes (flat sides on +-x), 1 unit inradius and 1 unit thick, scaled to S across, V tall
const S := 16.0  # inradius in metres: hexes are 32 m from side to side
const V := 6.0  # vertical scale: a kit slab is 6 m thick
const STEP := 3.0  # one terrace level (half a slab: what the kit's ramp tiles climb)
const ROW := 1.7320508 * S  # z distance between hex rows
# neighbour k sits across edge k; edge 0 faces +x and k turns 60 degrees each (+x toward -z, as Basis(UP, k * PI / 3))
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
# road and river tiles: which edges each one opens at rotation 0 (measured from the kit meshes)
const ROAD_TILES := {"A": [0, 3], "B": [1, 3], "C": [2, 3], "D": [1, 3, 5], "E": [0, 1, 3], "F": [0, 3, 5], "G": [2, 3, 4],
	"H": [0, 2, 3, 4], "I": [1, 2, 4, 5], "J": [0, 3, 4, 5], "K": [1, 2, 3, 4, 5], "L": [0, 1, 2, 3, 4, 5], "M": [3]}
const KINGDOMS := ["blue", "red", "yellow", "green"]
const CITY_NAMES := ["Valmorra", "Cidadela de Ferrugem", "Porto Cinzento", "Torreão de Ulm", "Bastião de Orth", "Velhoforte",
	"Castelo de Aldren", "Muralha de Kesh", "Fortaleza de Thal", "Trono Partido", "Cidadela Rubra", "Brumária", "Corvorrocha", "Arvendel"]
const VILLAGE_NAMES := ["Mirante Negro", "Carvalhal", "Vila dos Enforcados", "Pedra Rubra", "Ponte das Cinzas", "Sombravale",
	"Ermida Velha", "Vau dos Lobos", "Aldeia da Peste", "Vila Muda", "Brejo Fundo", "Cruz dos Corvos", "Moinho Queimado", "Poço Seco"]
const NAME_A := ["Alto", "Vale", "Monte", "Porto", "Campo", "Bosque", "Lago", "Pedra", "Rio", "Serra", "Ponte", "Torre", "Vila", "Castelo"]
const NAME_B := ["Dourado", "Verde", "das Flores", "do Sol", "Azul", "dos Ventos", "Claro", "da Aurora", "das Águas", "Real",
	"do Norte", "do Sul", "Brilhante", "Sereno", "das Rosas", "do Trigo", "Alegre", "da Lua"]

enum {MEADOW, FOREST, AUTUMN, SNOW, DESERT, BEACH}
const BIOME_NAMES := ["Campos Floridos", "Floresta Verde", "Bosque Outonal", "Pinheiral Nevado", "Deserto Dourado", "Margem do Lago"]
# the colour painted over the kit's lime grass per biome (alpha: how much), and over its leaves
const GRASS := {MEADOW: Color(0.45, 0.78, 0.25, 0.8), FOREST: Color(0.3, 0.62, 0.2, 0.9), AUTUMN: Color(0.95, 0.62, 0.2, 0.85),
	SNOW: Color(0.95, 0.97, 1.0, 1.0), DESERT: Color(0.98, 0.82, 0.5, 1.0), BEACH: Color(0.96, 0.88, 0.6, 1.0)}
const LEAVES := {MEADOW: Color(1, 1, 1, 0.0), FOREST: Color(0.22, 0.55, 0.16, 0.5), AUTUMN: Color(1.0, 0.5, 0.12, 0.9),
	SNOW: Color(0.3, 0.55, 0.35, 0.5), DESERT: Color(0.75, 0.8, 0.3, 0.4), BEACH: Color(1, 1, 1, 0.0)}
# ground colours (sRGB) for the horizon and the map, and the canopy colour of the trees that grow there
const GROUND := {MEADOW: Color(0.62, 0.78, 0.25), FOREST: Color(0.3, 0.6, 0.22), AUTUMN: Color(0.9, 0.6, 0.22),
	SNOW: Color(0.93, 0.96, 1.0), DESERT: Color(0.95, 0.8, 0.5), BEACH: Color(0.93, 0.86, 0.62)}
const CANOPY := {FOREST: Color(0.2, 0.48, 0.18), AUTUMN: Color(0.95, 0.48, 0.12), SNOW: Color(0.22, 0.45, 0.3)}
# per biome: [chance, decor] for a hex of the wild; solid decor blocks the way, trees do not
const DECOR := {
	MEADOW: [[0.06, ["tree_single_A", "tree_single_B"]], [0.05, ["hills_A", "hills_B", "hills_C", "hill_single_A", "hill_single_B"]],
		[0.03, ["rock_single_A", "rock_single_B", "rock_single_C"]], [0.02, ["trees_A_small", "trees_B_small"]]],
	FOREST: [[0.55, ["trees_A_large", "trees_A_medium", "trees_B_large", "trees_B_medium"]], [0.1, ["hills_A_trees", "hills_B_trees", "hills_C_trees"]]],
	AUTUMN: [[0.55, ["trees_A_large", "trees_A_medium", "trees_A_small"]], [0.08, ["hills_A_trees", "hills_C_trees"]]],
	SNOW: [[0.4, ["trees_B_large", "trees_B_medium", "trees_B_small"]], [0.12, ["mountain_A", "mountain_B", "mountain_C"]]],
	DESERT: [[0.1, ["rock_single_D", "rock_single_E", "rock_single_A"]], [0.1, ["hill_single_C", "hills_C", "hill_single_A"]], [0.06, ["mountain_A", "mountain_B"]], [0.04, ["tree_single_A"]]],
	BEACH: [[0.04, ["rock_single_B", "tree_single_A"]], [0.03, ["waterlily_A", "waterplant_A"]]],
}
const HIGH := ["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass_trees", "mountain_A_grass", "mountain_B_grass", "mountain_C_grass"]
const CITY_BUILDINGS := ["home_A", "home_B", "home_A", "home_B", "market", "tavern", "church", "blacksmith", "well", "barracks", "archeryrange", "tower_A", "windmill"]
const VILLAGE_BUILDINGS := ["home_A", "home_B", "home_A", "well", "windmill", "lumbermill", "tavern", "watermill", "mine"]

var main: Node
var noise := FastNoiseLite.new()
var mnoise := FastNoiseLite.new()
var tnoise := FastNoiseLite.new()  # temperature: snow to desert
var wnoise := FastNoiseLite.new()  # moisture: meadow to forest
var pnoise := FastNoiseLite.new()  # patches of autumn woods
var towns: Array = []  # {pos, hex, h, r, tr, name, city, kingdom, seed, node, enemies, gates, bonfire_hex, far}
var town_hex := {}  # Vector2i -> town, for every hex inside a town's ring
var roads: Array = []  # [a: Vector2, b: Vector2] town to town (the map draws them)
var road_hex := {}  # Vector2i -> edge bitmask of the road tiles
var chunks := {}  # Vector2i -> Node3D
var chests: Array = []  # [id, position, rotation] found while building the current chunk
var terrain_mat: ShaderMaterial
var far_mat: ShaderMaterial
var water_mat: StandardMaterial3D
var tile_mats := {}  # biome -> ShaderMaterial (ground) ; biome + 10 -> ShaderMaterial (decor)
var hex_meshes := {}  # kit piece name -> ArrayMesh (all its meshes merged, no material)
var far_mi: MeshInstance3D
var far_center := Vector2(INF, INF)
var far_task := -1
var far_data: Array = []
var found := {}  # town names the player has entered (the map shows them)
var map_tex: ImageTexture

func setup(m: Node) -> void:
	main = m
	noise.seed = 77
	noise.frequency = 0.0007
	noise.fractal_octaves = 5
	mnoise.seed = 91
	mnoise.frequency = 0.00035
	tnoise.seed = 13
	tnoise.frequency = 0.00011
	tnoise.fractal_octaves = 3
	wnoise.seed = 29
	wnoise.frequency = 0.00016
	wnoise.fractal_octaves = 3
	pnoise.seed = 41
	pnoise.frequency = 0.0005
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://terrain.gdshader")
	far_mat = terrain_mat.duplicate()
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.55, 0.85, 0.72)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.06
	water_mat.metallic = 0.2
	var atlas: Texture2D = load("res://assets/hex/hexagons_medieval.png")
	for b in GRASS:
		for k in 2:
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hex.gdshader")
			sm.set_shader_parameter("atlas", atlas)
			sm.set_shader_parameter("recolor", GRASS[b] if k == 0 else LEAVES[b])
			sm.set_shader_parameter("leaves", k == 1)
			tile_mats[b + 10 * k] = sm
	_plan()
	far_mi = MeshInstance3D.new()
	far_mi.material_override = far_mat
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_mi.extra_cull_margin = 400.0
	main.add_child(far_mi)
	_far_apply(_far_build(Vector2.ZERO))  # the first horizon is built at once; later ones on a worker thread
	far_center = Vector2.ZERO

# ------------------------------------------------------------------ hex grid
func hex_center(h: Vector2i) -> Vector2:
	return Vector2(S * (2.0 * h.x + h.y), ROW * h.y)

func hex_at(x: float, z: float) -> Vector2i:
	var r := z / ROW
	var q := x / (2.0 * S) - r / 2.0
	# cube rounding
	var cx := q
	var cz := r
	var cy := -cx - cz
	var rx := roundf(cx)
	var ry := roundf(cy)
	var rz := roundf(cz)
	var dx := absf(rx - cx)
	var dy := absf(ry - cy)
	var dz := absf(rz - cz)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy <= dz:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

func hex_dist(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2

# terrace level of a hex (0 = lake), -1 inside the valley (no hex there)
func level(h: Vector2i) -> int:
	var c := hex_center(h)
	if c.length() < VALLEY_R:
		return -1
	if town_hex.has(h):
		return town_hex[h].lv
	var y := wild_h(c.x, c.y)
	if road_hex.has(h):
		return maxi(1, roundi(y / STEP))  # roads never sink into lakes: they cross them on causeways
	return 0 if y < 0.0 else maxi(1, roundi(y / STEP))

# ------------------------------------------------------------------ the plan: towns and roads, decided once from the seed
func _plan() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var city_names := CITY_NAMES.duplicate()
	var village_names := VILLAGE_NAMES.duplicate()
	var extra := []
	for a in NAME_A:
		for b in NAME_B:
			extra.append("%s %s" % [a, b])
	var nrng := RandomNumberGenerator.new()
	nrng.seed = 99
	for i in range(extra.size() - 1, 0, -1):  # a seeded shuffle: the same names every run (saves keep found towns)
		var j := nrng.randi_range(0, i)
		var tmp = extra[i]
		extra[i] = extra[j]
		extra[j] = tmp
	var n := int(HALF * 2.0 / TOWN_CELL)
	for gz in n:
		for gx in n:
			var cc := Vector2(-HALF + TOWN_CELL * (gx + 0.5), -HALF + TOWN_CELL * (gz + 0.5))
			var p := cc + Vector2(rng.randf_range(-550, 550), rng.randf_range(-550, 550))
			var city := rng.randf() < 0.45
			if cc.length() < 1500.0:
				continue  # the four cells around the first valley stay wild
			var names: Array = city_names if city else village_names
			var name: String = names.pop_front() if not names.is_empty() else extra.pop_front()
			var hx := hex_at(p.x, p.y)
			var lv := maxi(1, roundi(clampf(wild_h(p.x, p.y), 4.0, 60.0) / STEP))
			var tr := 4 if city else 2  # the ring of walls (or fences), in hexes from the centre
			var t := {"pos": hex_center(hx), "hex": hx, "lv": lv, "h": lv * STEP, "tr": tr, "r": (tr + 0.5) * 2.0 * S, "city": city,
				"name": name, "kingdom": KINGDOMS[rng.randi() % 4], "seed": rng.randi(), "node": null, "enemies": [], "gates": []}
			towns.append(t)
	for t in towns:
		for dq in range(-t.tr, t.tr + 1):
			for dr in range(-t.tr, t.tr + 1):
				var h: Vector2i = t.hex + Vector2i(dq, dr)
				if hex_dist(h, t.hex) <= t.tr:
					town_hex[h] = t
	# roads: every town to its two nearest neighbours, and the four nearest to the valley
	var links := {}
	for i in towns.size():
		var near := range(towns.size()).filter(func(j): return j != i)
		near.sort_custom(func(a, b): return towns[i].pos.distance_squared_to(towns[a].pos) < towns[i].pos.distance_squared_to(towns[b].pos))
		for j in near.slice(0, 2):
			links[Vector2i(mini(i, j), maxi(i, j))] = true
	for k in links:
		_road(towns[k.x].pos, towns[k.y].pos)
	var by_center := range(towns.size())
	by_center.sort_custom(func(a, b): return towns[a].pos.length() < towns[b].pos.length())
	for i in by_center.slice(0, 4):
		var t: Dictionary = towns[i]
		_road(t.pos.normalized() * (VALLEY_R + 2.0 * S), t.pos)
	for t in towns:  # register the town bonfires now, so lit ones can be travelled to before they are built
		var a: float = t.gates[0] if not t.gates.is_empty() else 0.0
		t.bonfire_hex = hex_at(t.pos.x + cos(a) * (t.tr - 1) * 2.0 * S, t.pos.y + sin(a) * (t.tr - 1) * 2.0 * S)
		main.bonfires.append([_bonfire_pos(t), t.name])
		t.far = _far_town(t)

# a road of hex tiles from a to b: each step opens the edge toward the next hex in both tiles
func _road(a: Vector2, b: Vector2) -> void:
	roads.append([a, b])
	var ha := hex_at(a.x, a.y)
	var hb := hex_at(b.x, b.y)
	var n := hex_dist(ha, hb)
	var prev := ha
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		var h := hex_at(p.x, p.y)
		if h == prev:
			continue
		var k := DIRS.find(h - prev)
		if k < 0:  # rounding skipped a hex: step through a shared neighbour
			for kk in 6:
				if hex_dist(prev + DIRS[kk], h) == 1:
					_road_edge(prev, kk)
					prev = prev + DIRS[kk]
					break
			k = DIRS.find(h - prev)
		if k >= 0:
			_road_edge(prev, k)
		prev = h
	for t in towns:  # a gate where the road meets each town it starts or ends in
		for p in [a, b]:
			if t.pos.distance_to(p) < 1.0:
				var other: Vector2 = b if p == a else a
				t.gates.append((other - t.pos).angle())

func _road_edge(h: Vector2i, k: int) -> void:
	if hex_center(h).length() < VALLEY_R or hex_center(h + DIRS[k]).length() < VALLEY_R:
		return
	road_hex[h] = road_hex.get(h, 0) | (1 << k)
	road_hex[h + DIRS[k]] = road_hex.get(h + DIRS[k], 0) | (1 << ((k + 3) % 6))

func _bonfire_pos(t: Dictionary) -> Vector3:
	var c := hex_center(t.bonfire_hex)
	return Vector3(c.x, t.h, c.y)

# ------------------------------------------------------------------ height and biomes
func wild_h(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var mount := smoothstep(0.15, 0.55, mnoise.get_noise_2d(x, z)) * (1.0 - absf(noise.get_noise_2d(z * 1.7, x * 1.7))) * 160.0
	var edge := smoothstep(HALF - 400.0, HALF, maxf(absf(x), absf(z))) * 260.0  # the world's rim is impassable mountains
	var bumps := noise.get_noise_2d(x * 7.0, z * 7.0) * 6.0  # local hills and hollows
	var h := 10.0 + n * 42.0 + bumps + mount + edge
	if h < 0.0:
		h = -1.6 * (1.0 - exp(h / 5.0))
	return h

# temperature (x: cold < 0 < hot) and moisture (y: dry < 0 < wet); the first valley is mild and green
func climate(x: float, z: float) -> Vector2:
	var calm := smoothstep(400.0, 1500.0, Vector2(x, z).length())
	return Vector2(tnoise.get_noise_2d(x, z) * 1.6 * calm, wnoise.get_noise_2d(x, z) * 1.6)

func biome(x: float, z: float, h: float, c: Vector2) -> int:
	if h < 1.2 and Vector2(x, z).length() > CENTER_R + BLEND:  # the valley floor is low but no lake shore
		return BEACH
	if c.x < -0.35 or h > 105.0:
		return SNOW
	if c.x > 0.38:
		return DESERT
	if c.y > 0.12:
		return AUTUMN if pnoise.get_noise_2d(x, z) > 0.25 else FOREST
	return MEADOW

# the ground colour, blended across biome borders (horizon mesh, map and the valley's own ground)
func ground_color(x: float, z: float, h: float, c: Vector2) -> Color:
	var col: Color = GROUND[MEADOW]
	var wet := smoothstep(0.02, 0.2, c.y)
	col = col.lerp(GROUND[FOREST], wet)
	col = col.lerp(GROUND[AUTUMN], wet * smoothstep(0.15, 0.35, pnoise.get_noise_2d(x, z)))
	col = col.lerp(GROUND[DESERT], smoothstep(0.3, 0.45, c.x))
	col = col.lerp(GROUND[SNOW], maxf(1.0 - smoothstep(-0.42, -0.28, c.x), smoothstep(95.0, 115.0, h)))
	if Vector2(x, z).length() < CENTER_R + BLEND:
		return col
	return col.lerp(GROUND[BEACH], 1.0 - smoothstep(0.3, 1.6, h))

func biome_name(p: Vector3) -> String:
	return BIOME_NAMES[biome(p.x, p.z, p.y, climate(p.x, p.z))]

# ground height of the valley's smooth terrain (only meaningful inside VALLEY_R)
func sample(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	return lerpf(Level.ground_h(x, z), wild_h(x, z), smoothstep(CENTER_R, CENTER_R + BLEND, r))

# ------------------------------------------------------------------ streaming
func update(p: Vector3) -> void:
	var c := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if not chunks.has(c):
		_build_chunk(c)  # the ground under the player always exists, even right after fast travel
	var built := 0
	for r in LOAD_R + 1:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var k := c + Vector2i(dx, dz)
				if built < 1 and not chunks.has(k) and maxi(absi(dx), absi(dz)) == r:
					_build_chunk(k)
					built += 1
	for k in chunks.keys():
		if maxi(absi(k.x - c.x), absi(k.y - c.y)) > LOAD_R + 1:
			chunks[k].queue_free()
			chunks.erase(k)
	# the horizon mesh skips the square the detailed chunks cover (only once they are all there)
	var lo := Vector2(c.x - LOAD_R, c.y - LOAD_R) * CHUNK
	var hi := Vector2(c.x + LOAD_R + 1, c.y + LOAD_R + 1) * CHUNK
	var m := 12.0 if built == 0 else CHUNK + 12.0  # overlap the chunks a little: no gap where the two meshes meet
	far_mat.set_shader_parameter("hole", Vector4(lo.x + m, lo.y + m, hi.x - m, hi.y - m))
	_far_update(Vector2(p.x, p.z))
	var flat := Vector2(p.x, p.z)
	for t in towns:
		var d: float = flat.distance_to(t.pos)
		if t.node == null and d < TOWN_LOAD and built == 0:
			_build_town(t)
			built += 1
		elif t.node != null and d > TOWN_FREE:
			_free_town(t)
		if d < t.r and not found.has(t.name):
			found[t.name] = true

# one kit piece as a single ArrayMesh (its meshes merged in the piece's own space), cached
func _hex_mesh(name: String) -> ArrayMesh:
	if not hex_meshes.has(name):
		var root: Node3D = load("res://assets/hex/%s.gltf" % name).instantiate()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D()
			var p: Node = mi
			while p != root:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
			for i in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, i, xf)
		hex_meshes[name] = st.commit()
		root.free()
	return hex_meshes[name]

func _build_chunk(c: Vector2i) -> void:
	var node := Node3D.new()
	node.position = Vector3(c.x * CHUNK, 0, c.y * CHUNK)
	var origin := Vector3(c.x * CHUNK, 0, c.y * CHUNK)
	var groups := {}  # [material key, solid?] -> SurfaceTool
	var add := func(piece: String, key: int, solid: bool, xf: Transform3D) -> void:
		var g := Vector2i(key, 1 if solid else 0)
		if not groups.has(g):
			groups[g] = SurfaceTool.new()
			groups[g].begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[g].append_from(_hex_mesh(piece), 0, Transform3D(xf.basis, xf.origin - origin))
	chests = []
	var floors := []  # lake hexes: an invisible floor 1.4 m under the water, so you wade
	# every hex whose centre falls in this chunk
	var h0 := hex_at(c.x * CHUNK, c.y * CHUNK)
	for dr in range(-1, int(CHUNK / ROW) + 3):
		for dq in range(-int(CHUNK / S) - 2, int(CHUNK / S) + 3):
			var h := h0 + Vector2i(dq, dr)
			var p := hex_center(h)
			if p.x < c.x * CHUNK or p.x >= (c.x + 1) * CHUNK or p.y < c.y * CHUNK or p.y >= (c.y + 1) * CHUNK:
				continue
			var lv := level(h)
			if lv < 0:
				continue
			_hex_tile(h, p, lv, add, floors)
	if Vector2(c.x * CHUNK + CHUNK / 2.0, c.y * CHUNK + CHUNK / 2.0).length() < VALLEY_R + CHUNK:
		_valley_ground(node, c)
	if not groups.is_empty():
		var mesh := ArrayMesh.new()
		var col := ArrayMesh.new()  # what you collide with: the ground tiles and the solid decor
		for g in groups:
			groups[g].commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, tile_mats[g.x])
			if g.y == 1:
				groups[g].commit(col)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # phones: the sun's shadows stay on the characters
		node.add_child(mi)
		var body := StaticBody3D.new()
		body.collision_layer = 1 | 2
		var faces := PackedVector3Array()
		for i in col.get_surface_count():
			faces.append_array(col.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] if col.surface_get_arrays(i)[Mesh.ARRAY_INDEX] == null else _faces(col, i))
		for f in floors:
			faces.append_array(f)
		if not faces.is_empty():
			var cs := CollisionShape3D.new()
			var sh := ConcavePolygonShape3D.new()
			sh.set_faces(faces)
			cs.shape = sh
			body.add_child(cs)
			node.add_child(body)
	main.add_child(node)
	for ch in chests:
		main.add_chest(ch[0], ch[1], ch[2], node)
	chunks[c] = node

func _faces(m: ArrayMesh, i: int) -> PackedVector3Array:
	var a := m.surface_get_arrays(i)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var out := PackedVector3Array()
	out.resize(idx.size())
	for k in idx.size():
		out[k] = v[idx[k]]
	return out

# one hex: its ground tile (grass, ramp, road, water), filler under it down to its lowest neighbour, and what stands on it
func _hex_tile(h: Vector2i, p: Vector2, lv: int, add: Callable, floors: Array) -> void:
	var y := lv * STEP
	var cl := climate(p.x, p.y)
	var b := biome(p.x, p.y, wild_h(p.x, p.y), cl)
	if lv == 0:
		b = BEACH
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(h)
	var nl := []
	var low := lv
	for k in 6:
		var l := level(h + DIRS[k])
		nl.append(lv if l < 0 else l)
		low = mini(low, nl[k])
	var tile := Transform3D(Basis.from_scale(Vector3(S, V, S)), Vector3(p.x, y, p.y))
	var t: Dictionary = town_hex.get(h, {})
	if lv == 0:
		add.call("hex_water", b, false, tile)
		var f := PackedVector3Array()
		for k in 6:  # a flat hexagon 1.4 m below the surface (it sits at -1.2): one triangle per edge
			var a0 := PI / 6.0 + k * PI / 3.0
			var a1 := a0 + PI / 3.0
			var r := S * 1.1547
			f.append_array([Vector3(p.x, -2.6, p.y), Vector3(p.x + cos(a1) * r, -2.6, p.y - sin(a1) * r), Vector3(p.x + cos(a0) * r, -2.6, p.y - sin(a0) * r)])
		floors.append(f)
		return
	if road_hex.has(h):
		var mask: int = road_hex[h]
		var up := -1  # a straight road climbing one step: the ramp road tile
		for k in 3:
			if mask == (1 << k) | (1 << (k + 3)):
				if nl[k] == lv + 1 and nl[k + 3] <= lv:
					up = k
				elif nl[k + 3] == lv + 1 and nl[k] <= lv:
					up = k + 3
		if up >= 0:
			add.call("hex_road_A_sloped_low", b, true, Transform3D(Basis(Vector3.UP, up * PI / 3.0) * Basis.from_scale(Vector3(S, V, S)), tile.origin))
		else:
			var fit := _road_fit(mask)
			add.call("hex_road_" + fit[0], b, true, Transform3D(Basis(Vector3.UP, fit[1] * PI / 3.0) * Basis.from_scale(Vector3(S, V, S)), tile.origin))
	else:
		var ramp := -1  # walkable terrain: most hexes below a one-step neighbour become a ramp up to it
		if t.is_empty() and rng.randf() < 0.6:
			for k in 6:
				if nl[k] == lv + 1 and nl[(k + 3) % 6] <= lv:
					ramp = k
					break
		if ramp >= 0:
			add.call("hex_grass_sloped_low", b, true, Transform3D(Basis(Vector3.UP, ramp * PI / 3.0) * Basis.from_scale(Vector3(S, V, S)), tile.origin))
		else:
			add.call("hex_grass", b, true, tile)
	if (lv - low) * STEP > V:  # fill the cliff below the slab down to the lowest neighbour
		add.call("hex_grass_bottom", b, true, Transform3D(Basis.from_scale(Vector3(S, (lv - low) * STEP - V, S)), Vector3(p.x, y - V, p.y)))
	var on := Vector3(p.x, y, p.y)
	if not t.is_empty():
		_town_piece(h, t, on, add, rng)
		return
	if road_hex.has(h):
		return
	if rng.randf() < 0.012:  # a chest in the wild
		chests.append(["c%d_%d" % [h.x, h.y], on, rng.randf() * TAU])
		return
	var spin := Basis(Vector3.UP, rng.randi() % 6 * PI / 3.0).scaled(Vector3.ONE * S)
	if lv * STEP > 70.0 and rng.randf() < 0.45:
		add.call(HIGH[rng.randi() % HIGH.size()], 10 + b, true, Transform3D(spin, on))
		return
	var roll := rng.randf()
	for d in DECOR[b]:
		if roll < d[0]:
			var piece: String = d[1][rng.randi() % d[1].size()]
			add.call(piece, 10 + b, not piece.begins_with("tree") and not piece.begins_with("water"), Transform3D(spin, on))
			return
		roll -= d[0]

# the road tile and rotation (in 60-degree steps) whose open edges match mask
func _road_fit(mask: int) -> Array:
	for name in ROAD_TILES:
		for rot in 6:
			var m := 0
			for e in ROAD_TILES[name]:
				m |= 1 << ((e + rot) % 6)
			if m == mask:
				return [name, rot]
	return ["L", 0]  # no exact fit (should not happen): the crossroads

# a town hex: castle or main building in the middle, houses inside, a ring of walls (fences for villages) with gates
func _town_piece(h: Vector2i, t: Dictionary, on: Vector3, add: Callable, rng: RandomNumberGenerator) -> void:
	var d := hex_dist(h, t.hex)
	var to_centre: Vector2 = t.pos - Vector2(on.x, on.z)
	var face := atan2(to_centre.x, to_centre.y)  # +z (the door) toward the centre
	var sc := Basis.from_scale(Vector3.ONE * S)
	if d == t.tr:
		var tangent := Vector2(-to_centre.y, to_centre.x)
		var along := atan2(-tangent.y, tangent.x)
		var gate := road_hex.has(h)
		var piece := ("wall_straight_gate" if gate else "wall_straight") if t.city else ("fence_wood_straight_gate" if gate else "fence_wood_straight")
		add.call(piece, 10 + MEADOW, true, Transform3D(Basis(Vector3.UP, along) * sc, on))
		return
	if h == t.bonfire_hex or road_hex.has(h):
		return
	if d == 0:
		add.call("building_castle_" + t.kingdom if t.city else "building_tavern_" + t.kingdom, 10 + MEADOW, true, Transform3D(Basis(Vector3.UP, face) * sc, on))
		chests.append(["t%d_%d" % [h.x, h.y], on + Vector3(S * 0.8, 0, S * 0.8), face])  # the town's treasure, by the keep
		return
	if rng.randf() < 0.18:
		return  # a small square: room to fight
	var list: Array = CITY_BUILDINGS if t.city else VILLAGE_BUILDINGS
	var piece: String = list[rng.randi() % list.size()]
	add.call("building_%s_%s" % [piece, t.kingdom], 10 + MEADOW, true, Transform3D(Basis(Vector3.UP, face) * sc, on))

# the hand-built valley keeps a smooth ground; outside VALLEY_R it drops far below the hexes
func _valley_ground(node: Node3D, c: Vector2i) -> void:
	const RES := 33
	var step := CHUNK / (RES - 1)
	var ox := c.x * CHUNK
	var oz := c.y * CHUNK
	var heights := PackedFloat32Array()
	heights.resize(RES * RES)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in RES:
		for i in RES:
			var x := ox + i * step
			var z := oz + j * step
			var y := sample(x, z) if Vector2(x, z).length() < VALLEY_R + S else -60.0
			heights[j * RES + i] = y
			var col := ground_color(x, z, y, climate(x, z))
			col.a = 0.0
			st.set_color(col)
			st.add_vertex(Vector3(i * step, y, j * step))
	for j in RES - 1:
		for i in RES - 1:
			var a := j * RES + i
			for k in [a, a + 1, a + RES, a + 1, a + RES + 1, a + RES]:
				st.add_index(k)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 2
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = RES
	hs.map_depth = RES
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(step, 1, step)
	cs.position = Vector3(CHUNK / 2.0, 0, CHUNK / 2.0)
	body.add_child(cs)
	node.add_child(body)

# ------------------------------------------------------------------ the horizon: hills, forests and lakes out to ~4 km
func _far_update(p: Vector2) -> void:
	if far_task >= 0:
		if WorkerThreadPool.is_task_completed(far_task):
			WorkerThreadPool.wait_for_task_completion(far_task)
			far_task = -1
			_far_apply(far_data)
		return
	var c := (p / 1000.0).round() * 1000.0
	if c != far_center:
		far_center = c
		far_task = WorkerThreadPool.add_task(func(): far_data = _far_build(c))

# arrays for the coarse horizon mesh around c (runs on a worker thread: noise only, no scene access)
func _far_build(c: Vector2) -> Array:
	var n := FAR_N + 1
	var o := c - Vector2.ONE * FAR_N * FAR_STEP / 2.0
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	cols.resize(n * n)
	for j in n:
		for i in n:
			var x := o.x + i * FAR_STEP
			var z := o.y + j * FAR_STEP
			var h := wild_h(x, z)
			var r := Vector2(x, z).length()
			if r < VALLEY_R:
				h = sample(x, z)
			var cl := climate(x, z)
			var col := ground_color(x, z, h, cl)
			var b := biome(x, z, h, cl)
			if CANOPY.has(b):  # seen from afar a forest is its treetops
				col = col.lerp(CANOPY[b], 0.75)
			if h < 0.0 and r > VALLEY_R:  # far lakes: a flat blue surface
				col = Color(0.3, 0.68, 0.9)
				h = 0.0
			elif r > VALLEY_R:
				h = maxf(STEP, roundf(h / STEP) * STEP)  # the same terraces as the hexes
			verts[j * n + i] = Vector3(x, h - 0.6, z)
			cols[j * n + i] = Color(col.r, col.g, col.b, 0.0)
	var idx := PackedInt32Array()
	for j in FAR_N:
		for i in FAR_N:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	return [verts, cols, idx]

func _far_apply(d: Array) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = d[0]
	arrays[Mesh.ARRAY_COLOR] = d[1]
	arrays[Mesh.ARRAY_INDEX] = d[2]
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	far_mi.mesh = st.commit()

# the menu map's picture: biome colours, forests, lakes and snow of the whole world (made once, 160 x 160)
func map_texture() -> ImageTexture:
	if map_tex == null:
		const N := 160
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for j in N:
			for i in N:
				var x := -HALF + (i + 0.5) * HALF * 2.0 / N
				var z := -HALF + (j + 0.5) * HALF * 2.0 / N
				var h := wild_h(x, z)
				var cl := climate(x, z)
				var b := biome(x, z, h, cl)
				var col := ground_color(x, z, h, cl)
				if CANOPY.has(b):
					col = col.lerp(CANOPY[b], 0.6)
				if h < 0.0:
					col = Color(0.3, 0.68, 0.9)
				img.set_pixel(i, j, col.darkened(clampf((h - 40.0) / 400.0, 0.0, 0.12)))
		map_tex = ImageTexture.create_from_image(img)
	return map_tex

# a town on the skyline: its castle (or tavern) until the town is built close up
func _far_town(t: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _hex_mesh("building_castle_" + t.kingdom if t.city else "building_windmill_" + t.kingdom)
	mi.material_override = tile_mats[10 + MEADOW]
	mi.scale = Vector3.ONE * S
	mi.position = Vector3(t.pos.x, t.h, t.pos.y)
	mi.visibility_range_end = 4000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

# ------------------------------------------------------------------ towns: their people and their bonfire (the buildings
# are part of the hex chunks)
func _build_town(t: Dictionary) -> void:
	var node := Node3D.new()
	main.add_child(node)
	t.node = node
	t.far.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed
	var spawns := []
	for dq in range(-t.tr, t.tr + 1):
		for dr in range(-t.tr, t.tr + 1):
			var h: Vector2i = t.hex + Vector2i(dq, dr)
			var d := hex_dist(h, t.hex)
			if d > t.tr - 1 or d == 0 or h == t.bonfire_hex or rng.randf() > 0.4:
				continue
			# between the buildings: toward a corner of the hex
			var a := rng.randi() % 6 * PI / 3.0 + PI / 6.0
			var c := hex_center(h) + Vector2(cos(a), -sin(a)) * S * 0.85
			spawns.append([Vector3(c.x, t.h, c.y), (["guard", "guard", "plague", "sorceress", "bandit", "knifethrower"] if t.city else ["possessed", "possessed_f", "bandit", "imp", "puglin", "possessed"]).pick_random()])
	if t.city:
		var c := hex_center(t.hex) + Vector2(0, S * 1.3)
		spawns.append([Vector3(c.x, t.h, c.y), "blackknight"])
		spawns.append([Vector3(c.x + 4.0, t.h, c.y + 3.0), "executioner"])
	var bf := _bonfire_pos(t)
	var prop: Node3D = main._prop("bonfire", bf)
	prop.reparent(node)
	var fire := OmniLight3D.new()
	fire.position = bf + Vector3(0, 0.9, 0)
	fire.light_color = Color(1, 0.5, 0.15)
	fire.light_energy = 3.0
	fire.omni_range = 10
	fire.distance_fade_enabled = true
	fire.distance_fade_begin = 35.0
	fire.distance_fade_length = 10.0
	node.add_child(fire)
	t.spawns = spawns
	_spawn_town(t)
	var inward: Vector3 = Vector3(t.pos.x, t.h, t.pos.y) - bf
	main.npcs.populate_town(t, rng, [bf + inward.normalized() * 6.0 + Vector3(2.5, 0, 0), bf + inward.normalized() * 9.0 - Vector3(2.5, 0, 0)])

func _spawn_town(t: Dictionary) -> void:
	for sp in t.get("spawns", []):
		main._spawn_enemy(sp[0], sp[1])
		t.enemies.append(main.enemies[-1])

func _despawn_town(t: Dictionary) -> void:
	for e in t.enemies:
		if main.lock_target == e:
			main.lock_target = null
		main.enemies.erase(e)
		if is_instance_valid(e.root):
			e.root.queue_free()
	t.enemies = []

func _free_town(t: Dictionary) -> void:
	_despawn_town(t)
	main.npcs.remove_town(t)
	t.node.queue_free()
	t.node = null
	t.far.visible = true

# resting at a bonfire brings every loaded town back to life, like the valley
func respawn() -> void:
	for t in towns:
		if t.node != null:
			t.enemies = t.enemies.filter(func(e): return main.enemies.has(e))
			_despawn_town(t)
			_spawn_town(t)

func area_of(p: Vector3) -> Array:
	for t in towns:
		if Vector2(p.x, p.z).distance_to(t.pos) < t.r:
			return [t.name.to_upper(), "Cidade murada" if t.city else "Vilarejo"]
	if Vector2(p.x, p.z).length() > VALLEY_R:
		return [biome_name(p).to_upper(), "Terras selvagens"]
	return []
