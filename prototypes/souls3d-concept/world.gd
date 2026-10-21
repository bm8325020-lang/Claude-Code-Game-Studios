# PROTOTYPE - NOT FOR PRODUCTION
# The wide world around the first valley: 10 x 10 km of hills, forests and mountains, with walled medieval cities
# (ramparts, towers, a castle keep, streets of houses) and smaller villages, joined by roads. Everything is generated
# from one seed and streamed: only the terrain chunks around the player and the towns within TOWN_LOAD exist.
extends Node3D

const Level = preload("res://level.gd")
const HALF := 5000.0  # the world spans -5 km .. +5 km on x and z
const CHUNK := 128.0
const RES := 33  # vertices per chunk side: 4 m spacing
const LOAD_R := 2  # chunks kept around the player (5 x 5)
const TOWN_LOAD := 650.0
const TOWN_FREE := 850.0
const CENTER_R := 230.0  # inside: the hand-built valley (Level.ground_h); blended into the wild over BLEND
const BLEND := 140.0
const CITY_NAMES := ["Valmorra", "Cidadela de Ferrugem", "Porto Cinzento", "Torreão de Ulm", "Bastião de Orth", "Velhoforte",
	"Castelo de Aldren", "Muralha de Kesh", "Fortaleza de Thal", "Trono Partido", "Cidadela Rubra", "Brumária", "Corvorrocha", "Arvendel"]
const VILLAGE_NAMES := ["Mirante Negro", "Carvalhal", "Vila dos Enforcados", "Pedra Rubra", "Ponte das Cinzas", "Sombravale",
	"Ermida Velha", "Vau dos Lobos", "Aldeia da Peste", "Vila Muda", "Brejo Fundo", "Cruz dos Corvos", "Moinho Queimado", "Poço Seco"]

var main: Node
var noise := FastNoiseLite.new()
var mnoise := FastNoiseLite.new()
var towns: Array = []  # {pos: Vector2, h, r, name, city, seed, node, enemies, gates: [angles]}
var roads: Array = []  # [a: Vector2, b: Vector2, ha, hb]
var chunks := {}  # Vector2i -> Node3D
var terrain_mat: ShaderMaterial
var found := {}  # town names the player has entered (the map shows them)

func setup(m: Node) -> void:
	main = m
	noise.seed = 77
	noise.frequency = 0.0007
	noise.fractal_octaves = 5
	mnoise.seed = 91
	mnoise.frequency = 0.00035
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://terrain.gdshader")
	for k in [["mud", "brown_mud_leaves_01_diff"], ["mud_n", "brown_mud_leaves_01_nor_gl"], ["rock", "aerial_rocks_02_diff"],
			["rock_n", "aerial_rocks_02_nor_gl"], ["sand", "coast_sand_rocks_02_diff"], ["sand_n", "coast_sand_rocks_02_nor_gl"],
			["road", "cobblestone_floor_08_diff"], ["road_n", "cobblestone_floor_08_nor_gl"]]:
		terrain_mat.set_shader_parameter(k[0], load("res://assets/tex/%s_1k.jpg" % k[1]))
	terrain_mat.set_shader_parameter("sand_level", -100.0)
	_plan()

# ------------------------------------------------------------------ the plan: towns and roads, decided once from the seed
func _plan() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var city_names := CITY_NAMES.duplicate()
	var village_names := VILLAGE_NAMES.duplicate()
	var cell := 2000.0
	for gz in 5:
		for gx in 5:
			if gx == 2 and gz == 2:
				continue  # the first valley
			var p := Vector2(-HALF + cell * (gx + 0.5) + rng.randf_range(-550, 550), -HALF + cell * (gz + 0.5) + rng.randf_range(-550, 550))
			var city := rng.randf() < 0.45
			var t := {"pos": p, "r": 78.0 if city else 42.0, "city": city, "name": city_names.pop_front() if city else village_names.pop_front(), "seed": rng.randi(),
				"node": null, "enemies": [], "gates": []}
			t.h = clampf(wild_h(p.x, p.y), 4.0, 45.0)
			towns.append(t)
	# roads: every town to its two nearest neighbours, and the four nearest to the valley
	var links := {}
	for i in towns.size():
		var near := range(towns.size()).filter(func(j): return j != i)
		near.sort_custom(func(a, b): return towns[i].pos.distance_to(towns[a].pos) < towns[i].pos.distance_to(towns[b].pos))
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
	for t in towns:  # register the town bonfires now, so lit ones can be travelled to before they are built
		main.bonfires.append([_bonfire_pos(t), t.name])

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

# ------------------------------------------------------------------ height
func wild_h(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var mount := smoothstep(0.15, 0.55, mnoise.get_noise_2d(x, z)) * (1.0 - absf(noise.get_noise_2d(z * 1.7, x * 1.7))) * 140.0
	var edge := smoothstep(HALF - 300.0, HALF, maxf(absf(x), absf(z))) * 220.0  # the world's rim is impassable mountains
	var bumps := noise.get_noise_2d(x * 7.0, z * 7.0) * 7.0  # local hills and hollows
	return 10.0 + n * 40.0 + bumps + mount + edge

# ground height and road mask (0..1) at a point
func sample(x: float, z: float) -> Vector2:
	var r := Vector2(x, z).length()
	var h := wild_h(x, z)
	if r < CENTER_R + BLEND:
		h = lerpf(Level.ground_h(x, z), h, smoothstep(CENTER_R, CENTER_R + BLEND, r))
	var road := 0.0
	var p := Vector2(x, z)
	for rd in roads:
		var a: Vector2 = rd[0]
		var b: Vector2 = rd[1]
		if p.x < minf(a.x, b.x) - 20.0 or p.x > maxf(a.x, b.x) + 20.0 or p.y < minf(a.y, b.y) - 20.0 or p.y > maxf(a.y, b.y) + 20.0:
			continue
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := (p - (a + ab * t)).length()
		if d < 16.0:
			var target := lerpf(rd[2], rd[3], smoothstep(0.0, 1.0, t))
			h = lerpf(target, h, smoothstep(3.5, 16.0, d))
			road = maxf(road, 1.0 - smoothstep(2.5, 4.0, d))
	for tw in towns:
		var d: float = p.distance_to(tw.pos)
		if d < tw.r + 40.0:
			h = lerpf(tw.h, h, smoothstep(tw.r, tw.r + 40.0, d))
			if d < tw.r:
				road = maxf(road, 0.35)
	return Vector2(maxf(h, -14.0), road)

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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in RES:
		for i in RES:
			var s := sample(ox + i * step, oz + j * step)
			heights[j * RES + i] = s.x
			st.set_color(Color(s.y, 0, 0))
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
	_scatter(node, c, heights, step)
	main.add_child(node)
	chunks[c] = node

# trees and rocks of the wild (the valley has its own); two kinds per chunk keep the draw calls down
func _scatter(node: Node3D, c: Vector2i, heights: PackedFloat32Array, step: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var kinds := [["nature/tree_pineTallA_detailed", "nature/tree_thin_dark", "graveyard/pine-crooked", "nature/tree_pineRoundC", "nature/tree_default_dark"].pick_random(),
		["nature/rock_tallA", "nature/rock_largeB", "nature/stump_old", "nature/tree_pineTallB_detailed"].pick_random()]
	var xfs := [[], []]
	for n in 44:
		var i := rng.randi_range(1, RES - 2)
		var j := rng.randi_range(1, RES - 2)
		var wx := c.x * CHUNK + i * step
		var wz := c.y * CHUNK + j * step
		if Vector2(wx, wz).length() < CENTER_R + 40.0:
			continue
		var h := heights[j * RES + i]
		if absf(heights[j * RES + i + 1] - h) + absf(heights[(j + 1) * RES + i] - h) > 3.5 or sample(wx, wz).y > 0.05 or _near_town(Vector2(wx, wz), 25.0):
			continue
		var k := 0 if rng.randf() < 0.7 else 1
		xfs[k].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(5.0, 9.0)), Vector3(i * step, h - 0.3, j * step)))
	for k in 2:
		if xfs[k].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Level._piece(kinds[k])
		mm.instance_count = xfs[k].size()
		for i in xfs[k].size():
			mm.set_instance_transform(i, xfs[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 230.0
		node.add_child(mmi)

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
			var w := rng.randi_range(2, 3)
			var span: float = (w * Level.KS + 3.0) / rr
			if not _gate_near(t, a, 0.16):
				var p: Vector2 = c + Vector2(cos(a), sin(a)) * rr
				var rot := -a - PI / 2.0  # local +z (the door) faces the centre
				var floors := 3 if rng.randf() < 0.25 else 2
				Level.kit_house(node, Vector3(p.x, y, p.y), w, 2, floors, rot, rng.randi())
				Level.collider_rot(node, Vector3(p.x, y + floors * Level.KS / 2.0, p.y), Vector3(w * Level.KS, floors * Level.KS, 2 * Level.KS), rot)
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
	return []
