# PROTOTYPE - NOT FOR PRODUCTION
# One room of the dungeon, built from the KayKit Dungeon and Forest packs on a grid of 4 m tiles. Tall walls on
# the far sides (north and west, away from the camera) with torches and banners; low fences on the near sides
# so the camera always sees the fight. The exit is a gate in the north wall that opens when the room is clear.
# Three looks: crypt (stone), forest (dirt, trees for walls), fort (wood floor, banners).
extends RefCounted

const Rig = preload("res://rig.gd")
const TILE := 4.0

# builds a room under parent; returns {node, bounds: Rect2 (x, z), exit: Vector3, entry: Vector3, spawns: [Vector3]}
static func build(parent: Node3D, biome: String, rng: RandomNumberGenerator, boss := false) -> Dictionary:
	var node := Node3D.new()
	parent.add_child(node)
	var w := rng.randi_range(6, 8) if not boss else 9
	var d := rng.randi_range(5, 7) if not boss else 8
	var x0 := -w * TILE / 2.0
	var z0 := -d * TILE / 2.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	node.add_child(body)
	var box := func(center: Vector3, size: Vector3) -> void:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = center
		body.add_child(cs)
	box.call(Vector3(0, -0.5, 0), Vector3(w * TILE, 1.0, d * TILE))
	var put := func(dir: String, name: String, pos: Vector3, rot := 0.0, sc := 1.0) -> Node3D:
		var p := Rig.prop(dir, name)
		p.position = pos
		p.rotation.y = rot
		p.scale = Vector3.ONE * sc
		node.add_child(p)
		return p
	# floor
	for i in w:
		for j in d:
			var c := Vector3(x0 + (i + 0.5) * TILE, 0, z0 + (j + 0.5) * TILE)
			var f := "floor_tile_large"
			match biome:
				"crypt":
					f = ["floor_tile_large", "floor_tile_large", "floor_tile_large", "floor_tile_large_rocks"][rng.randi() % 4]
				"forest":
					f = ["floor_dirt_large", "floor_dirt_large", "floor_dirt_large_rocky"][rng.randi() % 3]
				"fort":
					f = ["floor_wood_large", "floor_wood_large", "floor_wood_large_dark"][rng.randi() % 3]
			put.call("dungeon", f, c, rng.randi() % 4 * PI / 2.0)
	var exit_i := w / 2
	# far walls: north (z0) and west (x0); near sides: low fences (or nothing in the forest)
	for i in w:
		var c := Vector3(x0 + (i + 0.5) * TILE, 0, z0)
		if i == exit_i:
			continue
		_wall(put, biome, c, 0.0, rng)
	for j in d:
		_wall(put, biome, Vector3(x0, 0, z0 + (j + 0.5) * TILE), PI / 2.0, rng)
	if biome != "forest":
		put.call("dungeon", "wall_corner", Vector3(x0, 0, z0), 0.0)
	for i in w:
		if i == w / 2:
			continue  # the gap you came in by
		if biome != "forest":
			put.call("dungeon", "barrier", Vector3(x0 + (i + 0.5) * TILE, 0, z0 + d * TILE), 0.0)
		else:
			_bush(put, Vector3(x0 + (i + 0.5) * TILE, 0, z0 + d * TILE), rng)
	for j in d:
		if biome != "forest":
			put.call("dungeon", "barrier", Vector3(x0 + w * TILE, 0, z0 + (j + 0.5) * TILE), PI / 2.0)
		else:
			_bush(put, Vector3(x0 + w * TILE, 0, z0 + (j + 0.5) * TILE), rng)
	# invisible walls all round (3 m high: projectiles stop, the camera sees over the near ones)
	box.call(Vector3(0, 2, z0 - 0.4), Vector3(w * TILE + 2, 4, 1))
	box.call(Vector3(0, 2, z0 + d * TILE + 0.3), Vector3(w * TILE + 2, 4, 0.6))
	box.call(Vector3(x0 - 0.4, 2, 0), Vector3(1, 4, d * TILE + 2))
	box.call(Vector3(x0 + w * TILE + 0.3, 2, 0), Vector3(0.6, 4, d * TILE + 2))
	# the exit gate
	var exit := Vector3(x0 + (exit_i + 0.5) * TILE, 0, z0)
	var gate: Node3D = put.call("dungeon", "wall_gated" if biome != "forest" else "wall_doorway", exit, 0.0)
	# obstacles: cover to fight around, never on the path from the entry to the exit
	var obstacles: Array = {"crypt": [["dungeon", "pillar", 1.0], ["dungeon", "barrel_large", 1.0], ["dungeon", "crates_stacked", 1.0], ["dungeon", "column", 1.3], ["dungeon", "box_large", 1.0]],
		"forest": [["forest", "Rock_1_A_Color1", 2.6], ["forest", "Rock_3_B_Color1", 1.6], ["forest", "Tree_2_A_Color1", 1.4], ["forest", "Tree_Bare_1_A_Color1", 1.4], ["forest", "Rock_2_C_Color1", 1.8]],
		"fort": [["dungeon", "crates_stacked", 1.0], ["dungeon", "table_long", 1.0], ["dungeon", "barrel_large_decorated", 1.0], ["dungeon", "pillar", 1.0], ["dungeon", "box_stacked", 1.0]]}[biome]
	var n := rng.randi_range(3, 6) if not boss else 4
	var taken := []
	for k in n:
		for tries in 12:
			var gx := rng.randi_range(1, w - 2)
			var gz := rng.randi_range(1, d - 2)
			if gx == w / 2 or Vector2i(gx, gz) in taken:
				continue
			taken.append(Vector2i(gx, gz))
			var o: Array = obstacles[rng.randi() % obstacles.size()]
			var pos := Vector3(x0 + (gx + 0.5) * TILE + rng.randf_range(-0.8, 0.8), 0, z0 + (gz + 0.5) * TILE + rng.randf_range(-0.8, 0.8))
			put.call(o[0], o[1], pos, rng.randf() * TAU if o[0] == "forest" else rng.randi() % 4 * PI / 2.0, o[2])
			box.call(pos + Vector3(0, 1.5, 0), Vector3(1.6, 3.0, 1.6))
			break
	# floor dressing that you walk through
	for k in 10:
		var pos := Vector3(rng.randf_range(x0 + 1, x0 + w * TILE - 1), 0, rng.randf_range(z0 + 1, z0 + d * TILE - 1))
		match biome:
			"crypt":
				put.call("dungeon", ["candle_triple", "candle_melted", "bottle_A_brown", "coin_stack_small"][rng.randi() % 4], pos, rng.randf() * TAU)
			"forest":
				put.call("forest", ["Grass_1_A_Color1", "Grass_2_B_Color1", "Bush_1_A_Color1", "Grass_1_C_Color1"][rng.randi() % 4], pos, rng.randf() * TAU, 2.0)
			"fort":
				put.call("dungeon", ["box_small", "bottle_B_green", "coin_stack_medium", "candle_lit"][rng.randi() % 4], pos, rng.randf() * TAU)
	gate.set_meta("keep", true)  # the gate is swapped for an open doorway later: not merged
	Rig.merge_static(node)
	# light: two warm lamps over the room (the far wall's torches are only decor)
	for k in 2:
		var l := OmniLight3D.new()
		l.position = Vector3((k - 0.5) * w * TILE * 0.45, 6.0, 0)
		l.light_color = Color(1.0, 0.75, 0.5) if biome != "forest" else Color(0.75, 1.0, 0.7)
		l.light_energy = 1.1
		l.omni_range = w * TILE * 0.7
		l.omni_attenuation = 0.6
		node.add_child(l)
	var spawns := []
	for k in 12:
		spawns.append(Vector3(rng.randf_range(x0 + 3, x0 + w * TILE - 3), 0, rng.randf_range(z0 + 3, z0 + d * TILE * 0.6)))
	return {"node": node, "bounds": Rect2(x0 + 0.8, z0 + 0.8, w * TILE - 1.6, d * TILE - 1.6), "exit": exit + Vector3(0, 0, 1.2),
		"entry": Vector3(x0 + (w / 2 + 0.5) * TILE, 0, z0 + d * TILE - 2.5), "spawns": spawns, "gate": gate, "w": w, "d": d}

static func _wall(put: Callable, biome: String, c: Vector3, rot: float, rng: RandomNumberGenerator) -> void:
	if biome == "forest":  # a line of trees and rocks
		put.call("forest", ["Tree_1_A_Color1", "Tree_2_B_Color1", "Tree_3_A_Color1", "Tree_4_A_Color1"][rng.randi() % 4], c, rng.randf() * TAU, rng.randf_range(1.5, 2.0))
		put.call("forest", ["Rock_1_B_Color1", "Rock_3_A_Color1"][rng.randi() % 2], c + Vector3(0, 0, 0).rotated(Vector3.UP, rot), rng.randf() * TAU, 3.0)
		return
	var piece: String = ["wall", "wall", "wall", "wall_cracked", "wall_window_closed", "wall_shelves" if biome == "fort" else "wall_arched"][rng.randi() % 6]
	put.call("dungeon", piece, c, rot)
	var inward := Vector3(0, 0, 0.55).rotated(Vector3.UP, rot) if rot == 0.0 else Vector3(0.55, 0, 0)
	if rng.randf() < 0.4:
		put.call("dungeon", "torch_mounted", c + inward + Vector3(0, 2.4, 0), rot)
	elif rng.randf() < 0.4:
		var col: String = "red" if biome == "fort" else ["blue", "green", "white"][rng.randi() % 3]
		put.call("dungeon", "banner_%s" % col if rng.randf() < 0.5 else "banner_patternA_%s" % col, c + inward * 0.3, rot)

static func _bush(put: Callable, c: Vector3, rng: RandomNumberGenerator) -> void:
	put.call("forest", ["Bush_1_A_Color1", "Bush_2_A_Color1", "Bush_4_B_Color1"][rng.randi() % 3], c, rng.randf() * TAU, 3.0)
