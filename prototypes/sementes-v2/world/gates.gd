# PROTOTYPE - NOT FOR PRODUCTION
# Story gates: the valley opens in stages with the main quests, so each new area is earned. Each gate stands on a
# chokepoint (the toll bridge over the river, the mine mouth, the castle gatehouse, the Passo da Escama), blocks with a
# collider (plus invisible walls where the slope beside it could be climbed), tells the player who or what opens it
# when they bump into it, and opens (collider off, prop tweened away) when its quest reaches its step.
# main.gd builds it after the map, calls sync() on every quest change and on load, and asks hint_near()/blocks().
extends Node3D

# id, area (pt-BR, for "Caminho aberto: <área>"), pos (x, z), facing (yaw: rot(facing) * +Z = the way in),
# width (m), look, quest + step that opens it (step -1: when the quest is done), hint (who/what opens it),
# guards: place ids / quest targets behind it (tests check no quest step needs them while it is closed),
# walls: extra invisible walls [[a, b], ...] (x, z) where the ground beside the gate is climbable.
const DATA: Array = [
	{"id": "ponte_dizimo", "area": "Bosque dos Sussurros", "pos": Vector2(-73.7, 82.2), "facing": -0.865, "width": 12.0,
		"look": "toll", "quest": "m05", "step": 1,
		"hint": "A cancela da ponte está baixada. Quando a Vó Cândida te mandar ao moinho, ela sobe.",
		"guards": ["forest", "bandit_camp"],
		# the river can be swum anywhere and its banks climbed: a wall along the west bank (river_ctrl in map.gd
		# shifted 9 m west) from the northern rim, past the bridge, to the lake, and through the lake to the south rim
		"walls": [[Vector2(-261, -476), Vector2(-261, -318)], [Vector2(-261, -318), Vector2(-235, -262)],
			[Vector2(-235, -262), Vector2(-205, -214)], [Vector2(-205, -214), Vector2(-169, -170)],
			[Vector2(-169, -170), Vector2(-134, -105)], [Vector2(-134, -105), Vector2(-109, -42)],
			[Vector2(-109, -42), Vector2(-89, 8)], [Vector2(-89, 8), Vector2(-71, 43)], [Vector2(-71, 43), Vector2(-77.6, 77.6)],
			[Vector2(-69.8, 86.8), Vector2(-47, 122)], [Vector2(-47, 122), Vector2(-21, 160)], [Vector2(-21, 160), Vector2(3, 190)],
			[Vector2(3, 190), Vector2(17, 214)], [Vector2(17, 214), Vector2(17, 476)]]},
	{"id": "mina_portao", "area": "Mina do Fôlego", "pos": Vector2(176.23, -187.48), "facing": 2.989, "width": 6.4,
		"look": "grate", "quest": "m11", "step": 2,
		"hint": "O portão da mina está trancado. O Gaspar tem a chave.",
		"guards": ["mina_fundo"], "walls": []},
	{"id": "castelo_grade", "area": "Castelo de Vigília", "pos": Vector2(26.3, -216.0), "facing": -PI * 0.5, "width": 7.0,
		"look": "portcullis", "quest": "m14", "step": 0,
		"hint": "A grade do castelo está baixada. Só a senha da Vó Cândida a levanta.",
		"guards": ["castle"], "walls": []},
	{"id": "passo_escama", "area": "Pastos da Cauda", "pos": Vector2(292.0, 11.0), "facing": PI * 0.5, "width": 14.0,
		"look": "rockfall", "quest": "m14", "step": -1,
		"hint": "Pedras fecham o Passo da Escama. Os pastores só limpam o caminho depois que o Conde cair.",
		"guards": ["cauda", "cauda_ponta"],
		# the gorge sides and the mountains round the Cauda are climbable: a wall across the whole east, gate excepted
		"walls": [[Vector2(292, -476), Vector2(292, 3.5)], [Vector2(292, 18.5), Vector2(292, 476)]]},
]

const HINT_RANGE: float = 3.0

var _gates: Dictionary = {}  # id -> {d, root (moving prop node), to (its open transform), cols: Array[CollisionShape3D], open}


static func earned(d: Dictionary, q: Quests) -> bool:
	var id: String = str(d.quest)
	if q.is_done(id):
		return true
	return int(d.step) >= 0 and q.status(id) == "active" and int(q.step_i.get(id, 0)) >= int(d.step)


func build(map: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "GateColliders"
	body.collision_layer = 1
	add_child(body)
	for d: Dictionary in DATA:
		var p: Vector2 = d.pos
		var w: float = d.width
		var base := Transform3D(Basis(Vector3.UP, float(d.facing)), Vector3(p.x, map.ground_y(p.x, p.y), p.y))
		# tall: the slopes beside a gate rise fast, and a hero climbing them must not step over its top
		var cols: Array[CollisionShape3D] = [_box(body, base * Vector3(0, 12.0, 0), Vector3(w, 28.0, 1.2), float(d.facing))]
		for wl: Array in d.walls:
			cols.append(_wall(body, map, wl[0], wl[1]))
		var root := Node3D.new()
		root.name = str(d.id)
		add_child(root)
		root.transform = base
		var moving: Node3D = _look(map.kit, root, str(d.look), w)
		var to: Transform3D = moving.transform
		match str(d.look):
			"toll":
				to = to.rotated_local(Vector3(0, 0, 1), 1.35)  # the pole swings up around its hinge post
			"grate", "portcullis":
				to = to.translated(Vector3(0, 3.6, 0))  # rises into the arch
			"rockfall":
				to = to.translated(Vector3(0, -6.0, 0))  # cleared away: the rocks sink out of sight
		_gates[str(d.id)] = {"d": d, "root": root, "moving": moving, "to": to, "cols": cols, "open": false}


func is_open(id: String) -> bool:
	return bool((_gates.get(id, {"open": true}) as Dictionary).open)


# Opens every gate the quests have earned. Returns the ones opened by this call (for the toast).
func sync(q: Quests, animate: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in _gates:
		var g: Dictionary = _gates[id]
		if g.open or not earned(g.d, q):
			continue
		g.open = true
		for cs: CollisionShape3D in g.cols:
			cs.disabled = true
		var mv: Node3D = g.moving
		if animate:
			var tw := create_tween()
			tw.tween_property(mv, "transform", g.to, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(mv.hide)
		else:
			mv.hide()
		out.append(g.d)
	return out


# The hint of a closed gate the hero is standing against, or "".
func hint_near(pos: Vector3) -> String:
	for id: String in _gates:
		var g: Dictionary = _gates[id]
		if not g.open and _dist(g.d, Vector2(pos.x, pos.z)) < HINT_RANGE:
			return str(g.d.hint)
	return ""


# Is this road point at a closed gate? (the HUD arrow must not route through it)
func blocks(p: Vector2) -> bool:
	for id: String in _gates:
		var g: Dictionary = _gates[id]
		if not g.open and _dist(g.d, p) < 4.0:
			return true
	return false


# distance from p to the gate's line (its width across the way in)
static func _dist(d: Dictionary, p: Vector2) -> float:
	var c: Vector2 = d.pos
	var across := Vector2(cos(float(d.facing)), -sin(float(d.facing)))  # rot(facing) * +X, on the x/z plane
	var hw: float = float(d.width) * 0.5
	var t: float = clampf((p - c).dot(across), -hw, hw)
	return p.distance_to(c + across * t)


func _box(body: StaticBody3D, c: Vector3, size: Vector3, yaw: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), c)
	body.add_child(cs)
	return cs


# an invisible wall from a to b, tall enough to cover the slope it runs along
func _wall(body: StaticBody3D, map: Node3D, a: Vector2, b: Vector2) -> CollisionShape3D:
	var lo: float = INF
	var hi: float = -INF
	var n: int = maxi(10, int(a.distance_to(b) / 3.0))
	for i in n + 1:
		var p: Vector2 = a.lerp(b, float(i) / n)
		var y: float = map.ground_y(p.x, p.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	var m: Vector2 = (a + b) * 0.5
	var dir: Vector2 = b - a
	return _box(body, Vector3(m.x, (lo + hi) * 0.5 + 3.0, m.y), Vector3(dir.length() + 1.0, hi - lo + 12.0, 1.2), atan2(-dir.y, dir.x))


func _mesh(kit: RefCounted, parent: Node3D, name: String, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.call("mesh", name)
	mi.transform = xf
	parent.add_child(mi)


# Builds the look under root (local x across the way, +z the way in) and returns the node that moves when it opens.
func _look(kit: RefCounted, root: Node3D, look: String, w: float) -> Node3D:
	var mv := Node3D.new()
	root.add_child(mv)
	var n: int = maxi(1, int(ceil(w / 2.0)))
	match look:
		"toll":
			# hinge post at one end, a log pole across the road with a row of hanging planks under it
			_mesh(kit, root, "Anvil_Log", Transform3D(Basis().scaled(Vector3(0.8, 1.3, 0.8)), Vector3(-w * 0.5 - 0.4, 0, 0)))
			_mesh(kit, root, "Anvil_Log", Transform3D(Basis().scaled(Vector3(0.6, 1.0, 0.6)), Vector3(w * 0.5 + 0.4, 0, 0)))
			mv.position = Vector3(-w * 0.5, 1.25, 0)
			var lb := Basis(Vector3.UP, PI * 0.5).scaled(Vector3(0.3, 0.3, w / 10.7))  # Roof_Log lies along z, 10.7 m
			_mesh(kit, mv, "Roof_Log", Transform3D(lb, Vector3(w * 0.5, -4.54 * 0.3, 0)))
			for i in n:
				_mesh(kit, mv, "Prop_WoodenFence_Single", Transform3D(Basis(), Vector3(1.0 + i * 2.0, -1.2, 0)))
			_mesh(kit, mv, "Banner_1", Transform3D(Basis().scaled(Vector3.ONE * 0.6), Vector3(w * 0.5, 0.2, 0.1)))
		"grate", "portcullis":
			var piece: String = "Prop_MetalFence_Simple" if look == "grate" else "Prop_MetalFence_Ornament"
			var sy: float = 1.15 if look == "grate" else 1.7
			for i in n:
				_mesh(kit, mv, piece, Transform3D(Basis().scaled(Vector3(w / (n * 1.95), sy, 1.0)), Vector3(-w * 0.5 + (i + 0.5) * w / n, 0, 0)))
		"rockfall":
			for i in n + 1:
				var x: float = -w * 0.5 + i * w / n
				var s: float = 1.6 + 0.5 * ((i * 7) % 3)
				_mesh(kit, mv, "Rock_Medium_%d" % (i % 3 + 1), Transform3D(Basis(Vector3.UP, i * 1.7).scaled(Vector3.ONE * s), Vector3(x, -0.4, (i % 2) * 1.2)))
				if i % 2 == 0:
					_mesh(kit, mv, "Rock_Medium_%d" % ((i + 1) % 3 + 1), Transform3D(Basis(Vector3.UP, i).scaled(Vector3.ONE * 1.3), Vector3(x + 1.0, 2.6, 0.6)))
			_mesh(kit, mv, "DeadTree_3", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5).scaled(Vector3.ONE * 0.7), Vector3(-w * 0.3, 2.2, -1.4)))
	return mv
