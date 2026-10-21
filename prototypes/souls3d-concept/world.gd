# PROTOTYPE - NOT FOR PRODUCTION
# The open world around the first valley: 20 x 20 km of meadows, forests, autumn woods, snowy pine hills, deserts,
# lakes and mountains, with walled medieval cities (ramparts, towers, a castle keep, streets of houses) and villages
# joined by roads. Everything is generated from one seed and streamed: detailed terrain chunks with their trees and
# flowers around the player, a coarse horizon mesh out to ~4 km so far hills and forests stay in view, a castle
# silhouette for every town until it is built close up.
extends Node3D

const Level = preload("res://level.gd")
const HALF := 10000.0  # the world spans -10 km .. +10 km on x and z
const TOWN_CELL := 2000.0  # one town per 2 x 2 km cell
const CHUNK := 128.0
const RES := 33  # vertices per chunk side: 4 m spacing
const LOAD_R := 2  # chunks kept around the player (5 x 5)
const TOWN_LOAD := 650.0
const TOWN_FREE := 850.0
const CENTER_R := 230.0  # inside: the hand-built valley (Level.ground_h); blended into the wild over BLEND
const BLEND := 140.0
const BUCKET := 512.0  # roads and towns are looked up per bucket: sample() runs for every terrain vertex
const FAR_N := 96  # horizon mesh: FAR_N x FAR_N quads of FAR_STEP metres around the player
const FAR_STEP := 80.0
const CITY_NAMES := ["Valmorra", "Cidadela de Ferrugem", "Porto Cinzento", "Torreão de Ulm", "Bastião de Orth", "Velhoforte",
	"Castelo de Aldren", "Muralha de Kesh", "Fortaleza de Thal", "Trono Partido", "Cidadela Rubra", "Brumária", "Corvorrocha", "Arvendel"]
const VILLAGE_NAMES := ["Mirante Negro", "Carvalhal", "Vila dos Enforcados", "Pedra Rubra", "Ponte das Cinzas", "Sombravale",
	"Ermida Velha", "Vau dos Lobos", "Aldeia da Peste", "Vila Muda", "Brejo Fundo", "Cruz dos Corvos", "Moinho Queimado", "Poço Seco"]
const NAME_A := ["Alto", "Vale", "Monte", "Porto", "Campo", "Bosque", "Lago", "Pedra", "Rio", "Serra", "Ponte", "Torre", "Vila", "Castelo"]
const NAME_B := ["Dourado", "Verde", "das Flores", "do Sol", "Azul", "dos Ventos", "Claro", "da Aurora", "das Águas", "Real",
	"do Norte", "do Sul", "Brilhante", "Sereno", "das Rosas", "do Trigo", "Alegre", "da Lua"]

enum {MEADOW, FOREST, AUTUMN, SNOW, DESERT, BEACH}
const BIOME_NAMES := ["Campos Floridos", "Floresta Verde", "Bosque Outonal", "Pinheiral Nevado", "Deserto Dourado", "Margem do Lago"]
# ground colours (sRGB) and, for the horizon, the canopy colour of the trees that grow there
const GROUND := {MEADOW: Color(0.42, 0.68, 0.25), FOREST: Color(0.24, 0.5, 0.2), AUTUMN: Color(0.76, 0.52, 0.22),
	SNOW: Color(0.93, 0.96, 1.0), DESERT: Color(0.95, 0.8, 0.5), BEACH: Color(0.93, 0.86, 0.62)}
const CANOPY := {FOREST: Color(0.16, 0.42, 0.14), AUTUMN: Color(0.88, 0.42, 0.1), SNOW: Color(0.2, 0.4, 0.26)}
# per biome: [tree chance, trees, ground-plant chance, plants] for each scatter point (Kenney Nature Kit, CC0)
const FLORA := {
	MEADOW: [0.05, ["tree_default", "tree_oak", "tree_fat", "tree_plateau"], 0.4,
		["flower_redA", "flower_redB", "flower_yellowA", "flower_yellowB", "flower_purpleA", "flower_purpleB", "plant_bush", "plant_bushSmall"]],
	FOREST: [0.3, ["tree_default", "tree_oak", "tree_tall", "tree_fat", "tree_cone", "tree_simple"], 0.25,
		["mushroom_redGroup", "plant_bushLarge", "plant_bushDetailed", "stump_round", "log", "flower_purpleA", "flower_redC"]],
	AUTUMN: [0.3, ["tree_oak_fall", "tree_fat_fall", "tree_tall_fall", "tree_cone_fall", "tree_simple_fall", "tree_small_fall"], 0.25,
		["mushroom_tanGroup", "flower_yellowA", "flower_yellowC", "plant_bush", "log_large", "mushroom_redGroup"]],
	SNOW: [0.22, ["tree_pineTallA", "tree_pineTallB", "tree_pineRoundA", "tree_pineRoundC", "tree_pineDefaultA", "tree_pineDefaultB"], 0.05,
		["stone_tallA", "rock_largeA", "stump_old"]],
	DESERT: [0.03, ["cactus_tall", "cactus_short", "rock_tallA", "stone_tallB", "tree_palmTall"], 0.05, ["rock_smallA", "cactus_short", "plant_flatShort"]],
	BEACH: [0.05, ["tree_palmTall", "tree_palmShort", "tree_palmBend"], 0.08, ["rock_smallA", "plant_bushSmall", "flower_yellowB"]],
}

var main: Node
var noise := FastNoiseLite.new()
var mnoise := FastNoiseLite.new()
var tnoise := FastNoiseLite.new()  # temperature: snow to desert
var wnoise := FastNoiseLite.new()  # moisture: meadow to forest
var pnoise := FastNoiseLite.new()  # patches of autumn woods
var towns: Array = []  # {pos: Vector2, h, r, name, city, seed, node, enemies, gates: [angles], far: MeshInstance3D}
var roads: Array = []  # [a: Vector2, b: Vector2, ha, hb]
var road_buckets := {}  # Vector2i -> [road]
var town_buckets := {}  # Vector2i -> [town]
var chunks := {}  # Vector2i -> Node3D
var terrain_mat: ShaderMaterial
var far_mat: ShaderMaterial
var water_mat: StandardMaterial3D
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
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plan()
	far_mi = MeshInstance3D.new()
	far_mi.material_override = far_mat
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_mi.extra_cull_margin = 400.0
	main.add_child(far_mi)
	_far_apply(_far_build(Vector2.ZERO))  # the first horizon is built at once; later ones on a worker thread
	far_center = Vector2.ZERO

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
			var t := {"pos": p, "r": 78.0 if city else 42.0, "city": city, "name": name, "seed": rng.randi(),
				"node": null, "enemies": [], "gates": []}
			t.h = clampf(wild_h(p.x, p.y), 4.0, 60.0)
			towns.append(t)
	# roads: every town to its two nearest neighbours, and the four nearest to the valley
	var links := {}
	for i in towns.size():
		var near := range(towns.size()).filter(func(j): return j != i)
		near.sort_custom(func(a, b): return towns[i].pos.distance_squared_to(towns[a].pos) < towns[i].pos.distance_squared_to(towns[b].pos))
		for j in near.slice(0, 2):
			links[Vector2i(mini(i, j), maxi(i, j))] = true
	for k in links:
		_road(towns[k.x].pos, towns[k.x].h, towns[k.y].pos, towns[k.y].h)
	var by_center := range(towns.size())
	by_center.sort_custom(func(a, b): return towns[a].pos.length() < towns[b].pos.length())
	for i in by_center.slice(0, 4):
		var t: Dictionary = towns[i]
		var edge: Vector2 = t.pos.normalized() * (CENTER_R + BLEND)
		_road(edge, wild_h(edge.x, edge.y), t.pos, t.h)
	for rd in roads:
		var lo: Vector2 = Vector2(minf(rd[0].x, rd[1].x), minf(rd[0].y, rd[1].y)) - Vector2(20, 20)
		var hi: Vector2 = Vector2(maxf(rd[0].x, rd[1].x), maxf(rd[0].y, rd[1].y)) + Vector2(20, 20)
		_bucket(road_buckets, rd, lo, hi)
	for t in towns:  # register the town bonfires now, so lit ones can be travelled to before they are built
		_bucket(town_buckets, t, t.pos - Vector2.ONE * (t.r + 40.0), t.pos + Vector2.ONE * (t.r + 40.0))
		main.bonfires.append([_bonfire_pos(t), t.name])
		t.far = _far_town(t)

func _bucket(buckets: Dictionary, item, lo: Vector2, hi: Vector2) -> void:
	for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
		for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
			var k := Vector2i(bx, bz)
			if not buckets.has(k):
				buckets[k] = []
			buckets[k].append(item)

func _road(a: Vector2, ha: float, b: Vector2, hb: float) -> void:
	roads.append([a, b, ha, hb])
	for t in towns:  # a gate where the road meets each town it starts or ends in
		for p in [a, b]:
			if t.pos.distance_to(p) < 1.0:
				var other: Vector2 = b if p == a else a
				t.gates.append((other - t.pos).angle())

func _bonfire_pos(t: Dictionary) -> Vector3:
	var a: float = t.gates[0] if not t.gates.is_empty() else 0.0
	var p: Vector2 = t.pos + Vector2(cos(a), sin(a)) * (t.r - 16.0)
	return Vector3(p.x, t.h, p.y)

# ------------------------------------------------------------------ height and biomes
func wild_h(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var mount := smoothstep(0.15, 0.55, mnoise.get_noise_2d(x, z)) * (1.0 - absf(noise.get_noise_2d(z * 1.7, x * 1.7))) * 160.0
	var edge := smoothstep(HALF - 400.0, HALF, maxf(absf(x), absf(z))) * 260.0  # the world's rim is impassable mountains
	var bumps := noise.get_noise_2d(x * 7.0, z * 7.0) * 6.0  # local hills and hollows
	var h := 10.0 + n * 42.0 + bumps + mount + edge
	if h < 0.0:
		h = -1.6 * (1.0 - exp(h / 5.0))  # lakes stay shallow: you wade, you never drown
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

# the ground colour, blended across biome borders
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

# ground height and road mask (0..1) at a point
func sample(x: float, z: float) -> Vector2:
	var r := Vector2(x, z).length()
	var h := wild_h(x, z)
	if r < CENTER_R + BLEND:
		h = lerpf(Level.ground_h(x, z), h, smoothstep(CENTER_R, CENTER_R + BLEND, r))
	var road := 0.0
	var p := Vector2(x, z)
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	for rd in road_buckets.get(key, []):
		var a: Vector2 = rd[0]
		var b: Vector2 = rd[1]
		if p.x < minf(a.x, b.x) - 20.0 or p.x > maxf(a.x, b.x) + 20.0 or p.y < minf(a.y, b.y) - 20.0 or p.y > maxf(a.y, b.y) + 20.0:
			continue
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := (p - (a + ab * t)).length()
		if d < 16.0:
			var target := maxf(lerpf(rd[2], rd[3], smoothstep(0.0, 1.0, t)), 0.4)  # roads cross lakes on a causeway
			h = lerpf(target, h, smoothstep(3.5, 16.0, d))
			road = maxf(road, 1.0 - smoothstep(2.5, 4.0, d))
	for tw in town_buckets.get(key, []):
		var d: float = p.distance_to(tw.pos)
		if d < tw.r + 40.0:
			h = lerpf(tw.h, h, smoothstep(tw.r, tw.r + 40.0, d))
			if d < tw.r:
				road = maxf(road, 0.35)
	return Vector2(h, road)

func height(x: float, z: float) -> float:
	return sample(x, z).x

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

func _build_chunk(c: Vector2i) -> void:
	var step := CHUNK / (RES - 1)
	var ox := c.x * CHUNK
	var oz := c.y * CHUNK
	var heights := PackedFloat32Array()
	heights.resize(RES * RES)
	var road := PackedFloat32Array()
	road.resize(RES * RES)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet := false
	for j in RES:
		for i in RES:
			var x := ox + i * step
			var z := oz + j * step
			var s := sample(x, z)
			heights[j * RES + i] = s.x
			road[j * RES + i] = s.y
			wet = wet or (s.x < -0.05 and Vector2(x, z).length() > CENTER_R + BLEND)  # the valley floor sits below 0 but is dry
			var col := ground_color(x, z, s.x, climate(x, z))
			col.a = s.y
			st.set_color(col)
			st.add_vertex(Vector3(i * step, s.x, j * step))
	for j in RES - 1:
		for i in RES - 1:
			var a := j * RES + i
			for k in [a, a + 1, a + RES, a + 1, a + RES + 1, a + RES]:
				st.add_index(k)
	st.generate_normals()
	var node := Node3D.new()
	node.position = Vector3(ox, 0, oz)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	if wet:  # a lake: one water plane at y 0 over the chunk
		var w := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(CHUNK, CHUNK)
		w.mesh = pm
		w.material_override = water_mat
		w.position = Vector3(CHUNK / 2.0, 0.0, CHUNK / 2.0)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(w)
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
	_scatter(node, c, heights, road, step)
	main.add_child(node)
	chunks[c] = node

# trees, rocks, flowers and bushes of the wild by biome (the valley has its own), merged per chunk into one mesh for
# the big things and one for the small ones: two draw calls per chunk however dense the forest. No tree shadows:
# on a phone the shadow pass would draw every forest chunk near the player twice
func _scatter(node: Node3D, c: Vector2i, heights: PackedFloat32Array, road: PackedFloat32Array, step: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var big := []
	var small := []
	const N := 20  # scatter points per side: one every 6.4 m
	for j in N:
		for i in N:
			var lx := (i + rng.randf()) * CHUNK / N
			var lz := (j + rng.randf()) * CHUNK / N
			var gi := clampi(int(lx / step), 0, RES - 2)
			var gj := clampi(int(lz / step), 0, RES - 2)
			var a := gj * RES + gi
			var wx := c.x * CHUNK + lx
			var wz := c.y * CHUNK + lz
			if Vector2(wx, wz).length() < CENTER_R + 40.0 or road[a] > 0.02 or road[a + 1] > 0.02 or road[a + RES] > 0.02:
				continue
			var fx := lx / step - gi
			var fz := lz / step - gj
			var h := lerpf(lerpf(heights[a], heights[a + 1], fx), lerpf(heights[a + RES], heights[a + RES + 1], fx), fz)
			if h < 0.15 or absf(heights[a + 1] - heights[a]) + absf(heights[a + RES] - heights[a]) > 3.0:
				continue
			var b := biome(wx, wz, h, climate(wx, wz))
			var f: Array = FLORA[b]
			var roll := rng.randf()
			var piece := ""
			var sc := 1.0
			if roll < f[0]:
				piece = f[1][rng.randi() % f[1].size()]
				sc = rng.randf_range(4.0, 7.0) if piece.begins_with("cactus") else rng.randf_range(5.0, 9.0)
				if piece.begins_with("rock") or piece.begins_with("stone"):
					sc = rng.randf_range(3.0, 6.0)
			elif roll < f[0] + f[2]:
				piece = f[3][rng.randi() % f[3].size()]
				sc = rng.randf_range(3.5, 5.5)
			if piece == "" or _near_town(Vector2(wx, wz), 20.0):
				continue
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(lx, h - 0.25, lz))
			(big if roll < f[0] else small).append(["nature/" + piece, xf])
	_merge(node, big, 330.0, false)  # beyond that the horizon mesh shows forests by their canopy colour
	_merge(node, small, 80.0, false)

func _merge(node: Node3D, items: Array, vis_end: float, shadow: bool) -> void:
	if items.is_empty():
		return
	var tools := {}  # material -> SurfaceTool
	for it in items:
		var mesh: ArrayMesh = Level._piece(it[0])
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if not tools.has(mat):
				tools[mat] = SurfaceTool.new()
				tools[mat].begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat].append_from(mesh, i, it[1])
	var out := ArrayMesh.new()
	for mat in tools:
		tools[mat].commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = out
	mi.visibility_range_end = vis_end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)

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
			if r < CENTER_R + BLEND:
				h = lerpf(Level.ground_h(x, z), h, smoothstep(CENTER_R, CENTER_R + BLEND, r))
			var cl := climate(x, z)
			var col := ground_color(x, z, h, cl)
			var b := biome(x, z, h, cl)
			if CANOPY.has(b):  # seen from afar a forest is its treetops
				col = col.lerp(CANOPY[b], 0.75)
			if h < 0.0 and r > CENTER_R + BLEND:  # far lakes: a flat blue surface
				col = Color(0.3, 0.68, 0.9)
				h = 0.0
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

# a town seen from afar: its ring of walls, a few roofs and the keep's tower, until it is built close up
func _far_town(t: Dictionary) -> MeshInstance3D:
	var st_wall := SurfaceTool.new()
	var st_roof := SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := CylinderMesh.new()
	ring.top_radius = t.r - 6.0
	ring.bottom_radius = t.r - 6.0
	ring.height = 10.0 if t.city else 4.0
	ring.radial_segments = 24
	ring.rings = 1
	st_wall.append_from(ring, 0, Transform3D(Basis(), Vector3(0, ring.height / 2.0, 0)))
	var roofs := CylinderMesh.new()  # the mass of red roofs inside the walls
	roofs.top_radius = t.r * 0.45
	roofs.bottom_radius = t.r - 8.0
	roofs.height = 9.0
	roofs.radial_segments = 16
	st_roof.append_from(roofs, 0, Transform3D(Basis(), Vector3(0, ring.height / 2.0 + 4.5, 0)))
	var towers := [Vector3(0, 0, -5)] if not t.city else [Vector3(0, 0, -5), Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 12), Vector3(-12, 0, 12)]
	for i in towers.size():
		var hgt := (34.0 if t.city else 16.0) if i == 0 else 20.0
		var tw := CylinderMesh.new()
		tw.top_radius = 3.5
		tw.bottom_radius = 3.5
		tw.height = hgt
		tw.radial_segments = 8
		st_wall.append_from(tw, 0, Transform3D(Basis(), towers[i] + Vector3(0, hgt / 2.0, 0)))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 4.5
		cone.height = 7.0
		cone.radial_segments = 8
		st_roof.append_from(cone, 0, Transform3D(Basis(), towers[i] + Vector3(0, hgt + 3.5, 0)))
	var mesh := ArrayMesh.new()
	st_wall.commit(mesh)
	mesh.surface_set_material(0, Level.mats.wall)
	st_roof.commit(mesh)
	mesh.surface_set_material(1, Level.mats.roof)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(t.pos.x, t.h, t.pos.y)
	mi.visibility_range_end = 4000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	return mi

func _near_town(p: Vector2, margin: float) -> bool:
	for t in towns:
		if p.distance_to(t.pos) < t.r + margin:
			return true
	return false

# ------------------------------------------------------------------ towns
func _y(p: Vector2) -> float:
	return height(p.x, p.y)

func _gate_near(t: Dictionary, a: float, width: float) -> bool:
	for g in t.gates:
		if absf(angle_difference(a, g)) < width:
			return true
	return false

func _build_town(t: Dictionary) -> void:
	var node := Node3D.new()
	main.add_child(node)
	t.node = node
	t.far.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed
	Level.batches = {}
	var c: Vector2 = t.pos
	var y: float = t.h
	var R: float = t.r
	var spawns := []
	if t.city:
		# ramparts: Kenney castle wall blocks around the town, towers every eight, openings where roads arrive
		var rw := R - 6.0
		var n := int(TAU * rw / 4.0)
		var wh: float = Level._top("castle/wall") * 4.0
		for i in n:
			var a := i * TAU / n
			var gap := _gate_near(t, a, 6.0 / rw)
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * rw
			if gap:
				continue
			if i % 8 == 0 or _gate_near(t, a, 10.0 / rw):
				var top := _tower(node, Vector3(p.x, y, p.y), 2, -a)
				if i % 16 == 0:
					spawns.append([Vector3(p.x, top, p.y), "wallbow"])
			else:
				Level.place("castle/wall", Vector3(p.x, y, p.y), Vector3.ONE * 4.0, -a + PI / 2.0)
				Level.collider_rot(node, Vector3(p.x, y + wh / 2.0, p.y), Vector3(4.2, wh, 4.0), -a + PI / 2.0)
		# the keep: a walled square courtyard with corner towers and a great tower, the Black Knight inside
		var k := 12.0
		for side in 4:
			for s in 6:
				var along := -k + 2.0 + s * 4.0
				var local: Vector2 = [Vector2(along, -k), Vector2(k, along), Vector2(-along, k), Vector2(-k, -along)][side]
				if side == 2 and (s == 2 or s == 3):
					continue  # the keep's gate
				var p: Vector2 = c + local
				var rot := 0.0 if side % 2 == 0 else PI / 2.0
				Level.place("castle/wall", Vector3(p.x, y, p.y), Vector3.ONE * 4.0, rot)
				Level.collider_rot(node, Vector3(p.x, y + wh / 2.0, p.y), Vector3(4.0, wh, 4.0), rot)
		for corner in [Vector2(-k, -k), Vector2(k, -k), Vector2(k, k), Vector2(-k, k)]:
			_tower(node, Vector3(c.x + corner.x, y, c.y + corner.y), 3, 0.0)
		var great := _tower(node, Vector3(c.x, y, c.y - 5.0), 5, 0.0)
		Level.place("castle/flag-banner-long", Vector3(c.x, great, c.y - 3.0), Vector3.ONE * 4.0)
		spawns.append([Vector3(c.x, y, c.y + 4.0), "blackknight"])
		spawns.append([Vector3(c.x + 3.0, y, c.y + k + 4.0), "executioner"])
	else:
		var top := _tower(node, Vector3(c.x, y, c.y), 2, 0.0)  # the village watchtower
		spawns.append([Vector3(c.x, top, c.y), "wallbow"])
	# houses on rings around the centre, doors toward it, leaving streets toward the gates
	var rings := [30.0, 46.0, 60.0] if t.city else [16.0, 28.0]
	for rr in rings:
		var a0 := rng.randf() * TAU
		var a := a0
		while a < a0 + TAU - 0.3:
			var w := rng.randi_range(2, 4)
			var span: float = (w * 2.0 + 3.0) / rr
			if not _gate_near(t, a, 0.16):
				var p: Vector2 = c + Vector2(cos(a), sin(a)) * rr
				var rot := -a - PI / 2.0  # local +z (the door) faces the centre
				var floors := 3 if rng.randf() < 0.25 else 2
				var fp: Vector3 = Level.mvk_house(node, Vector3(p.x, y, p.y), w, rng.randi_range(3, 4), floors, rot, rng.randi())
				Level.collider_rot(node, Vector3(p.x, y + fp.y / 2.0, p.y), fp, rot)
				if rng.randf() < 0.45:
					var sp: Vector2 = c + Vector2(cos(a + span * 0.5), sin(a + span * 0.5)) * (rr - 6.0)
					spawns.append([Vector3(sp.x, y, sp.y), (["guard", "guard", "plague", "sorceress", "bandit", "knifethrower"] if t.city else ["possessed", "possessed_f", "bandit", "imp", "puglin", "possessed"]).pick_random()])
			a += span
	# market, lamps and the town bonfire by the main gate
	Level.place("fantasy-town/fountain-round", Vector3(c.x + (20.0 if t.city else 0.0), y, c.y + (0.0 if t.city else 8.0)), Vector3.ONE * 4.0)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * (22.0 if t.city else 11.0)
		Level.place("graveyard/lightpost-single", Vector3(p.x, y, p.y), Vector3.ONE * 3.0)
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.position = Vector3(p.x, y + 3.6, p.y)
			l.light_color = Color(1.0, 0.6, 0.3)
			l.light_energy = 1.4
			l.omni_range = 10.0
			l.distance_fade_enabled = true
			l.distance_fade_begin = 35.0
			l.distance_fade_length = 10.0
			node.add_child(l)
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
	Level._flush(node)
	t.spawns = spawns
	_spawn_town(t)
	var inward: Vector3 = Vector3(c.x, y, c.y) - bf
	main.npcs.populate_town(t, rng, [bf + inward.normalized() * 6.0 + Vector3(2.5, 0, 0), bf + inward.normalized() * 9.0 - Vector3(2.5, 0, 0)])

func _tower(node: Node3D, bottom: Vector3, n: int, rot: float) -> float:
	var y := bottom.y
	for i in n:
		var part := "castle/tower-square-base" if i == 0 else "castle/tower-square-mid-windows"
		Level.place(part, Vector3(bottom.x, y, bottom.z), Vector3.ONE * 4.0, rot)
		y += Level._top(part) * 4.0
	Level.place("castle/tower-square-top", Vector3(bottom.x, y, bottom.z), Vector3.ONE * 4.0, rot)
	Level.collider_rot(node, Vector3(bottom.x, (bottom.y + y) / 2.0, bottom.z), Vector3(4.0, y - bottom.y, 4.0), rot)
	return y

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
	if Vector2(p.x, p.z).length() > CENTER_R + BLEND:
		return [biome_name(p).to_upper(), "Terras selvagens"]
	return []
