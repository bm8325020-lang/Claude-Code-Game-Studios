# PROTOTYPE - NOT FOR PRODUCTION
# Map module: builds every hand-placed set piece of the Vale de Lume (houses, the mill, the toll bridge, the pier,
# the castle, the ruined watchtower, the mine gallery, the bandit quarry, the Carvalha-Mãe) and the little prop
# stories around them, and fills the contract lists of GameMap (spawns, npc_spots, interactables, camps).
# Static geometry is merged per region and per material (MapKit.Batch): one draw call per material per region.
# Procedural pieces the kits do not have (mill wheel, boat, tents, planks, rib arches, glow) are built here.
extends RefCounted

const Kit = preload("res://world/kit.gd")
const Bld = preload("res://world/buildings.gd")
const Terrain = preload("res://world/terrain.gd")

var m: Node3D          # the GameMap
var t: Terrain
var kit: Kit
var bld: Bld
var body: StaticBody3D
var holder: Node3D
var regions: Dictionary = {}   # name -> {big: Batch, small: Batch, wood: SurfaceTool, cloth: SurfaceTool, ...}
var cur: String = ""
var mats: Dictionary = {}
var tris_hint: int = 0


func _init(map: Node3D, terrain: Terrain, k: Kit, static_body: StaticBody3D) -> void:
	m = map
	t = terrain
	kit = k
	body = static_body
	bld = Bld.new(kit, kit.batch(), 7)
	holder = Node3D.new()
	holder.name = "Places"
	m.add_child(holder)
	_make_mats()


# ------------------------------------------------------------------ materials for procedural pieces
func _make_mats() -> void:
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/village/T_WoodTrim_BaseColor.png")
	wood.roughness = 0.9
	wood.vertex_color_use_as_albedo = true
	mats["wood"] = wood
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_texture = load("res://assets/village/T_Plaster_BaseColor.png")
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["cloth"] = cloth
	var rock: StandardMaterial3D = StandardMaterial3D.new()
	rock.albedo_texture = load("res://assets/ground/rock_face_03_diff_1k.jpg")
	rock.uv1_triplanar = true
	rock.uv1_scale = Vector3(0.35, 0.35, 0.35)
	rock.albedo_color = Color(0.86, 0.78, 0.68)
	rock.roughness = 0.95
	mats["rock"] = rock
	var ember: StandardMaterial3D = StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = Color(1.0, 0.55, 0.18)
	mats["ember"] = ember
	var flame: StandardMaterial3D = StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, 0.78, 0.35)
	mats["flame"] = flame
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.03, 0.025, 0.02)
	mats["dark"] = dark
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.13, 0.12, 0.13)
	glass.metallic = 0.6
	glass.roughness = 0.12
	glass.emission_enabled = true
	glass.emission = Color(0.55, 0.22, 0.08)
	glass.emission_energy_multiplier = 0.35
	mats["glass"] = glass


# ------------------------------------------------------------------ region batches
func region(name: String) -> void:
	cur = name
	if not regions.has(name):
		regions[name] = {"big": kit.batch(64.0), "small": kit.batch(9000.0), "procs": {}}


func _proc(mat: String) -> SurfaceTool:
	var procs: Dictionary = regions[cur].procs
	if not procs.has(mat):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		procs[mat] = st
	return procs[mat]


func commit_all() -> void:
	for name in regions.keys():
		var r: Dictionary = regions[name]
		var node: Node3D = Node3D.new()
		node.name = name
		holder.add_child(node)
		(r.big as Kit.Batch).commit(node, name, true)
		(r.small as Kit.Batch).commit(node, name + "_props", false, 90.0)
		var procs: Dictionary = r.procs
		for mk in procs.keys():
			var st: SurfaceTool = procs[mk]
			st.index()
			st.generate_normals()
			var am: ArrayMesh = st.commit()
			if am.get_surface_count() == 0:
				continue
			am.surface_set_material(0, mats[mk])
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "%s_%s" % [name, mk]
			mi.mesh = am
			if mk == "ember" or mk == "flame" or mk == "dark":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)


# ------------------------------------------------------------------ placement helpers
func gy(x: float, z: float) -> float:
	return t.sample(x, z)


static func rot(a: float) -> Basis:
	return Basis(Vector3.UP, a)


# Prop on the ground. big = merged into the shadow-casting batch (large things), else the props batch.
func P(name: String, x: float, z: float, yaw: float = 0.0, s: float = 1.0, dy: float = 0.0, big: bool = false) -> void:
	var xf: Transform3D = Transform3D(rot(yaw).scaled(Vector3.ONE * s), Vector3(x, gy(x, z) + dy, z))
	PX(name, xf, big)


func PX(name: String, xf: Transform3D, big: bool = false) -> void:
	var key: String = "big" if big else "small"
	(regions[cur][key] as Kit.Batch).add(name, xf)


# Prop in a local frame (root) at local position; y is local.
func PL(name: String, root: Transform3D, lp: Vector3, yaw: float = 0.0, s: float = 1.0, big: bool = false) -> void:
	PX(name, root * Transform3D(rot(yaw).scaled(Vector3.ONE * s), lp), big)


func col_box(c: Vector3, size: Vector3, yaw: float) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(rot(yaw), c)
	body.add_child(cs)


# A sloped walkable slab whose top surface runs from `a` to `b` (both on the walking surface).
func col_ramp(a: Vector3, b: Vector3, width: float) -> void:
	var f: Vector3 = (b - a).normalized()
	var r: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = r.cross(f).normalized()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(width, 0.4, a.distance_to(b) + 0.4)
	cs.shape = bs
	cs.transform = Transform3D(Basis(r, u, f), (a + b) * 0.5 - u * 0.2)
	body.add_child(cs)


func col_cyl(x: float, z: float, r: float, hgt: float) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = r
	sh.height = hgt
	cs.shape = sh
	cs.position = Vector3(x, gy(x, z) + hgt * 0.5 - 0.3, z)
	body.add_child(cs)


# Wood box (planks, posts, beams) in world space. Long axis gets the grain.
func wbox(xf: Transform3D, size: Vector3, tint: Color = Color(1, 1, 1)) -> void:
	_box(_proc("wood"), xf, size, tint, 0.36, 0.58)


func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, tint: Color, v0: float, v1: float) -> void:
	var h: Vector3 = size * 0.5
	var faces: Array = [
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var lu: float = absf(u.dot(size))
		var lv: float = absf(v.dot(size))
		# grain along the longer side of the face
		var swap: bool = lv > lu
		var c: Vector3 = n * absf(n.dot(h))
		var hu: Vector3 = u * absf(u.dot(h))
		var hv: Vector3 = v * absf(v.dot(h))
		var corners: Array = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
		var uvs: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var L: float = maxf(lu, lv) * 0.4
		for q in [0, 1, 2, 0, 2, 3]:
			var uv: Vector2 = uvs[q]
			var along: float = uv.y if swap else uv.x
			var across: float = uv.x if swap else uv.y
			st.set_color(tint)
			st.set_uv(Vector2(along * L, lerpf(v0, v1, across)))
			st.set_normal(xf.basis * n)
			st.add_vertex(xf * (corners[q] as Vector3))


func _mesh_into(mat: String, mesh: Mesh, xf: Transform3D, tint: Color = Color(1, 1, 1)) -> void:
	var st: SurfaceTool = _proc(mat)
	var arr: Array = mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in ix:
		st.set_color(tint)
		if uv.size() > i:
			st.set_uv(uv[i])
		st.set_normal((xf.basis * ns[i]).normalized())
		st.add_vertex(xf * vs[i])


# ------------------------------------------------------------------ contract helpers
func npc(id: String, role: String, p: Vector3, facing: float) -> void:
	(m.npc_spots as Array).append({"id": id, "pos": p, "facing": facing, "role": role})


func inter(id: String, kind: String, p: Vector3, extra: Dictionary = {}) -> void:
	var d: Dictionary = {"id": id, "pos": p, "kind": kind}
	d.merge(extra)
	(m.interactables as Array).append(d)


func camp(id: String, place: String, p: Vector3, kinds: Array, count: int, level: int) -> void:
	var ks: Array[String] = []
	ks.assign(kinds)
	(m.camps as Array).append({"id": id, "place": place, "pos": p, "kinds": ks, "count": count, "level": level})


func spawn(id: String, x: float, z: float) -> void:
	(m.spawns as Dictionary)[id] = Vector3(x, gy(x, z) + 0.1, z)


func at(x: float, z: float) -> Vector3:
	return Vector3(x, gy(x, z), z)


# A house from the map's house list. Returns its world root.
func house(hd: Dictionary) -> Transform3D:
	var spec: Dictionary = hd.spec
	var pad: Dictionary = hd.pad
	var p: Vector2 = hd.pos
	var yaw: float = hd.yaw
	var root: Transform3D = Transform3D(rot(yaw), Vector3(p.x, float(pad.y), p.y))
	bld.b = regions[cur].big
	var size: Vector3 = bld.house(root, spec)
	col_box(root * Vector3(0, size.y * 0.5 - 1.0, 0), Vector3(size.x, size.y, size.z), yaw)
	# stone footing strip so walls never float on the pad edge
	var W: float = size.x
	var D: float = size.z
	for sx in [-1.0, 1.0]:
		wbox(root * Transform3D(Basis(), Vector3(sx * W * 0.5, -0.25, 0)), Vector3(0.5, 0.6, D + 0.5), Color(0.55, 0.52, 0.5))
	for sz in [-1.0, 1.0]:
		wbox(root * Transform3D(Basis(), Vector3(0, -0.25, sz * D * 0.5)), Vector3(W + 0.5, 0.6, 0.5), Color(0.55, 0.52, 0.5))
	return root


# World point in front of a house door (dist metres out).
func door(hd: Dictionary, dist: float) -> Vector3:
	var spec: Dictionary = hd.spec
	var w: int = spec.get("w", 3)
	var d: int = spec.get("d", 4)
	var di: int = spec.get("door", w / 2)
	var off: float = (float(di) - float(w - 1) * 0.5) * 2.0
	var p: Vector2 = hd.pos
	var lp: Vector3 = rot(float(hd.yaw)) * Vector3(off, 0, d + dist)
	return at(p.x + lp.x, p.y + lp.z)


func hfind(id: String) -> Dictionary:
	for hd in m.houses:
		if hd.id == id:
			return hd
	return {}


# ------------------------------------------------------------------ small compositions
func woodpile(x: float, z: float, yaw: float, n: int) -> void:
	var b: Basis = rot(yaw)
	var y0: float = gy(x, z)
	var row: int = n
	var lvl: int = 0
	while row > 0:
		for i in row:
			var off: float = (float(i) - float(row - 1) * 0.5) * 0.3
			var p: Vector3 = Vector3(x, y0 + 0.14 + lvl * 0.26, z) + b * Vector3(off, 0, 0)
			var xf: Transform3D = Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, float(i) * 1.7), p)
			_mesh_into("wood", _log_mesh(), xf, Color(0.95, 0.85, 0.75))
		row -= 1
		lvl += 1


var _log: CylinderMesh


func _log_mesh() -> CylinderMesh:
	if _log == null:
		_log = CylinderMesh.new()
		_log.top_radius = 0.14
		_log.bottom_radius = 0.14
		_log.height = 1.3
		_log.radial_segments = 7
		_log.rings = 1
	return _log


func fence_line(a: Vector2, b: Vector2, kind: String = "Prop_WoodenFence_Single") -> void:
	var L: float = a.distance_to(b)
	var n: int = maxi(1, int(round(L / 2.0)))
	var dir: Vector2 = (b - a) / L
	var yaw: float = atan2(-dir.y, dir.x)
	for i in n:
		var p: Vector2 = a + dir * ((float(i) + 0.5) * L / n)
		var k: String = kind
		if kind == "Prop_WoodenFence_Single" and i % 3 == 1:
			k = "Prop_WoodenFence_Extension1"
		var y: float = gy(p.x, p.y)
		PX(k, Transform3D(rot(yaw) * Basis(Vector3(0, 0, 1), (gy(p.x + dir.x, p.y + dir.y) - gy(p.x - dir.x, p.y - dir.y)) * 0.25), Vector3(p.x, y, p.y)))


# Marco de Lume: a warm standing stone on a ring of flat stones, candles and an ember crack at its foot.
func marco(id: String, x: float, z: float, mossy: bool, candles: bool) -> void:
	var y: float = gy(x, z)
	var stone: String = "Rock_Medium_3#moss" if mossy else "Rock_Medium_3"
	PX(stone, Transform3D(rot(x * 0.7).scaled(Vector3(0.34, 0.78, 0.3)), Vector3(x, y - 0.15, z)), true)
	for i in 7:
		var a: float = TAU * i / 7.0 + 0.3
		P("RockPath_Square_Small_%d" % (i % 3 + 1), x + cos(a) * 1.9, z + sin(a) * 1.9, a, 1.0, 0.02)
	var glow: SphereMesh = SphereMesh.new()
	glow.radius = 0.5
	glow.height = 0.3
	glow.radial_segments = 10
	glow.rings = 3
	_mesh_into("ember", glow, Transform3D(Basis().scaled(Vector3(1.4, 0.35, 1.0)), Vector3(x + 0.3, y + 0.02, z + 0.45)))
	if candles:
		for i in 3:
			var a2: float = 0.9 + i * 0.55
			P("Candle_2", x + cos(a2) * 1.1, z + sin(a2) * 1.1, a2)
			_mesh_into("flame", _flame_mesh(0.05, 0.12), Transform3D(Basis(), at(x + cos(a2) * 1.1, z + sin(a2) * 1.1) + Vector3(0, 0.3, 0)))
	inter(id, "rest", at(x, z + 2.4), {"name": "Marco de Lume"})
	col_cyl(x, z, 0.6, 2.0)


func _flame_mesh(r: float, hgt: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = hgt
	c.radial_segments = 6
	c.rings = 1
	return c


func campfire(x: float, z: float) -> void:
	var y: float = gy(x, z)
	for i in 8:
		var a: float = TAU * i / 8.0
		P("Pebble_Round_%d" % (i % 5 + 1), x + cos(a) * 0.75, z + sin(a) * 0.75, a, 1.6)
	for i in 4:
		var a2: float = TAU * i / 4.0 + 0.4
		var xf: Transform3D = Transform3D(rot(a2) * Basis(Vector3.RIGHT, 1.2), Vector3(x, y + 0.25, z) + rot(a2) * Vector3(0, 0, 0.25))
		_mesh_into("wood", _log_mesh(), xf.scaled_local(Vector3(0.7, 0.7, 0.7)), Color(0.5, 0.42, 0.36))
	_mesh_into("flame", _flame_mesh(0.35, 1.0), Transform3D(Basis(), Vector3(x, y + 0.55, z)))
	_mesh_into("ember", _flame_mesh(0.22, 0.55), Transform3D(rot(0.5), Vector3(x + 0.1, y + 0.35, z - 0.05)))


# A ridge tent of canvas on a pole frame. Opening faces +Z of yaw.
func tent(x: float, z: float, yaw: float, w: float, d: float, hgt: float, tint: Color) -> void:
	var y: float = gy(x, z)
	var root: Transform3D = Transform3D(rot(yaw), Vector3(x, y, z))
	var st: SurfaceTool = _proc("cloth")
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	var A: Vector3 = Vector3(-hw, 0, -hd)
	var B: Vector3 = Vector3(hw, 0, -hd)
	var C: Vector3 = Vector3(hw, 0, hd)
	var D: Vector3 = Vector3(-hw, 0, hd)
	var R0: Vector3 = Vector3(0, hgt, -hd - 0.15)
	var R1: Vector3 = Vector3(0, hgt, hd + 0.25)
	var quads: Array = [[A, D, R1, R0], [C, B, R0, R1]]
	for q in quads:
		var uvq: Array = [Vector2(0, 0), Vector2(d * 0.3, 0), Vector2(d * 0.3, 0.6), Vector2(0, 0.6)]
		for k in [0, 1, 2, 0, 2, 3]:
			var lp: Vector3 = q[k]
			st.set_color(tint * (0.75 + 0.25 * lp.y / hgt))
			st.set_uv(uvq[k])
			st.add_vertex(root * lp)
	# back wall triangle
	for lp2 in [A, R0, B]:
		st.set_color(tint * 0.8)
		st.set_uv(Vector2((lp2 as Vector3).x * 0.3, (lp2 as Vector3).y * 0.3))
		st.add_vertex(root * (lp2 as Vector3))
	# poles
	wbox(root * Transform3D(Basis(), Vector3(0, hgt * 0.5, hd + 0.2)), Vector3(0.1, hgt + 0.1, 0.1))
	wbox(root * Transform3D(Basis(), Vector3(0, hgt + 0.02, 0.05)), Vector3(0.09, 0.09, d + 0.6))
	col_box(root * Vector3(0, hgt * 0.4, 0), Vector3(w, hgt * 0.8, d), yaw)


# ------------------------------------------------------------------ VILA DE BRASALUME
func village() -> void:
	region("Village")
	for hd in m.houses:
		if hd.spec.get("region", "Village") == "Village":
			house(hd)
	var S: Vector2 = Vector2(0, -20)
	var inn: Dictionary = hfind("inn")
	var forge: Dictionary = hfind("forge")
	var elder: Dictionary = hfind("elder")
	var chapel: Dictionary = hfind("chapel")
	var guard: Dictionary = hfind("guard")

	# -- the square: well, the Pedra do Primeiro Lume with its glassy pit roped off, the first Marco
	_well(5.5, -27.0)
	var py: float = gy(-4, -15)
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.9
	disc.bottom_radius = 1.6
	disc.height = 0.12
	disc.radial_segments = 18
	disc.rings = 1
	var glass_xf: Transform3D = Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.8)), Vector3(-4, py + 0.0, -15))
	var ast: SurfaceTool = _proc("glass")
	var arr: Array = disc.surface_get_arrays(0)
	for i in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
		ast.set_normal((arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)[i])
		ast.add_vertex(glass_xf * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)[i])
	PX("Rock_Medium_2", Transform3D(rot(0.4).scaled(Vector3(0.9, 0.35, 0.8)), Vector3(-6.6, py - 0.1, -13.2)), true)
	for i in 6:
		var a: float = TAU * i / 6.0
		var px: float = -4 + cos(a) * 3.0
		var pz: float = -15 + sin(a) * 2.6
		wbox(Transform3D(rot(a), at(px, pz) + Vector3(0, 0.45, 0)), Vector3(0.12, 1.0, 0.12), Color(0.8, 0.75, 0.7))
		var a2: float = TAU * (i + 1) / 6.0
		var q: Vector3 = at(-4 + cos(a2) * 3.0, -15 + sin(a2) * 2.6)
		var p: Vector3 = at(px, pz)
		var mid: Vector3 = (p + q) * 0.5 + Vector3(0, 0.62, 0)
		var dirv: Vector3 = q - p
		wbox(Transform3D(rot(atan2(dirv.x, dirv.z)), mid), Vector3(0.04, 0.04, dirv.length()), Color(0.95, 0.85, 0.6))
	inter("pedra_primeiro_lume", "landmark", at(-4, -11.5), {"name": "Pedra do Primeiro Lume"})
	marco("marco_vila", 9.5, -12.0, false, true)
	# benches under the square's shade tree; the merchant cart of Seu Bené with his goods
	P("Bench", -9.0, -27.5, 0.6, 1.0, 0.0, true)
	P("Stall_Cart_Empty", 8.0, -30.5, -0.35, 1.0, 0.0, true)
	P("FarmCrate_Apple", 6.6, -29.2, 0.2)
	P("FarmCrate_Carrot", 9.4, -29.0, -0.5)
	P("Barrel_Apples", 10.4, -31.0)
	P("Bag", 5.8, -31.6, 1.2)
	P("Crate_Wooden", 11.2, -32.2, 0.3)
	col_box(at(8, -30.5) + Vector3(0, 1, 0), Vector3(3.2, 2.0, 1.4), -0.35)
	npc("seu_bene", "merchant", at(7.4, -28.6), PI + 0.2)
	inter("carroca_bene", "shop", at(7.4, -28.0))

	# -- Estalagem da Panela Quente: tables outside, a barrel rack, the sign lantern
	var ir: Transform3D = Transform3D(rot(float(inn.yaw)), door(inn, 0.0))
	PL("Table_Large", ir, Vector3(3.6, 0, 3.0), 0.0, 0.8)
	PL("Bench", ir, Vector3(3.6, 0, 2.2), 0.0, 0.8)
	PL("Bench", ir, Vector3(3.6, 0, 3.8), PI, 0.8)
	PL("Mug", ir, Vector3(3.3, 0.66, 3.0), 0.0)
	PL("Mug", ir, Vector3(4.0, 0.66, 2.9), 1.0)
	PL("Barrel_Holder", ir, Vector3(-3.2, 0, 1.0), PI * 0.5)
	PL("Barrel", ir, Vector3(-3.4, 0, 2.3), 0.0)
	PL("Lantern_Wall", ir, Vector3(1.2, 2.2, -0.3), PI * 0.5)
	npc("rosa", "innkeeper", door(inn, 1.6), float(inn.yaw))
	(m.spawns as Dictionary)["player_start"] = door(inn, 1.0) + Vector3(0, 0.1, 0)
	inter("cartas_rosa", "pickup", door(inn, -2.0), {"item": "cartas_rosa"})

	# -- Forja de Joana: open shed with anvil, quench barrel, whetstone, wood and the old ploughshares
	var fr: Transform3D = Transform3D(rot(float(forge.yaw)), door(forge, 0.0))
	var shed: Transform3D = fr * Transform3D(Basis(), Vector3(-4.6, 0, 1.6))
	for sx in [-1.6, 1.6]:
		for sz in [-1.4, 1.4]:
			wbox(shed * Transform3D(Basis(), Vector3(sx, 1.25, sz)), Vector3(0.22, 2.5, 0.22))
	for i in 2:
		PL("Roof_Wooden_2x1", shed, Vector3(-1.0 + i * 2.0, 2.45, -0.8), 0.0, 1.0, true)
		PL("Roof_Wooden_2x1", shed, Vector3(-1.0 + i * 2.0, 2.45, 0.8), PI, 1.0, true)
	PL("Anvil_Log", shed, Vector3(0.3, 0, 0.2), 0.4, 1.0, true)
	PL("Whetstone", shed, Vector3(-1.2, 0, -0.7), 0.0)
	PL("Workbench", fr, Vector3(1.6, 0, 1.2), PI, 1.0, true)
	PL("Barrel", shed, Vector3(1.2, 0, 1.0), 0.0)
	PL("Bucket_Metal", shed, Vector3(1.0, 0, 1.6), 0.0)
	PL("WeaponStand", fr, Vector3(3.2, 0, 1.0), -0.3)
	PL("Pickaxe_Bronze", shed, Vector3(-1.5, 0.05, 0.9), 0.3)
	PL("Chain_Coil", fr, Vector3(2.4, 0, 2.3), 0.0)
	_mesh_into("ember", _flame_mesh(0.3, 0.3), shed * Transform3D(Basis(), Vector3(-1.0, 0.95, 0.9)))
	PL("Cauldron", shed, Vector3(-1.0, 0, 0.9), 0.0, 0.9, true)
	woodpile((fr * Vector3(-7.6, 0, -2.0)).x, (fr * Vector3(-7.6, 0, -2.0)).z, float(forge.yaw) + PI * 0.5, 5)
	col_box(shed * Vector3(0, 1.2, 0), Vector3(3.6, 2.4, 3.2), float(forge.yaw))
	npc("joana", "blacksmith", Vector3(shed * Vector3(0.4, 0, 1.4)), float(forge.yaw))
	inter("forja_joana", "forge", Vector3(shed * Vector3(0.3, 0, 1.2)), {"name": "Forja de Joana"})

	# -- Vó Cândida: bench by the door, spinning wheel stand-in (stool + basket), herb pots
	var er: Transform3D = Transform3D(rot(float(elder.yaw)), door(elder, 0.0))
	PL("Bench", er, Vector3(-2.0, 0, 0.9), 0.0, 0.7)
	PL("Stool", er, Vector3(1.3, 0, 0.9), 0.0)
	PL("Bag", er, Vector3(1.9, 0, 0.6), 0.5, 0.7)
	PL("Vase_2", er, Vector3(-3.4, 0, 0.4), 0.0, 0.8)
	PL("Bush_Common_Flowers", er, Vector3(2.8, 0, 0.2), 0.0, 0.8)
	npc("vo_candida", "elder", Vector3(er * Vector3(-1.8, 0, 1.2)), float(elder.yaw))

	# -- Capela do Repouso: bell tower, dovecote, candles of the forgotten
	var cr: Transform3D = Transform3D(rot(float(chapel.yaw)), Vector3(chapel.pos.x, float(chapel.pad.y), chapel.pos.y))
	bld.b = regions[cur].big
	var tw_root: Transform3D = cr * Transform3D(Basis(), Vector3(-4.6, 0, 3.0))
	var tsz: Vector3 = bld.tower(tw_root, 2, 4, false, false)
	col_box(tw_root * Vector3(0, tsz.y * 0.5, 0), tsz, float(chapel.yaw))
	var dove: Transform3D = cr * Transform3D(Basis(), Vector3(5.2, 0, -2.5))
	wbox(dove * Transform3D(Basis(), Vector3(0, 1.4, 0)), Vector3(0.25, 2.8, 0.25))
	wbox(dove * Transform3D(Basis(), Vector3(0, 3.0, 0)), Vector3(1.4, 0.9, 1.0), Color(0.95, 0.9, 0.85))
	PL("Roof_Wooden_2x1", dove, Vector3(0, 3.4, -0.5), 0.0, 0.8)
	PL("Roof_Wooden_2x1", dove, Vector3(0, 3.4, 0.5), PI, 0.8)
	inter("pombal", "dovecote", Vector3(dove * Vector3(0, 0, 1.2)), {"name": "Pombal"})
	PL("CandleStick_Stand", cr, Vector3(1.8, 0, 5.8), 0.0)
	PL("Banner_1", cr, Vector3(-1.8, 0, 5.6), 0.0)
	npc("frei_anselmo", "priest", door(chapel, 1.4), float(chapel.yaw))

	# -- Capitão Rui: guard house, training post, weapon rack, the dog's bowl
	var gr: Transform3D = Transform3D(rot(float(guard.yaw)), door(guard, 0.0))
	PL("Dummy", gr, Vector3(-2.6, 0, 4.4), 0.4, 1.0, true)
	PL("Dummy", gr, Vector3(1.8, 0, 5.2), -0.3, 1.0, true)
	PL("WeaponStand", gr, Vector3(3.6, 0, 1.0), -0.5)
	PL("Shield_Wooden", gr, Vector3(3.1, 0.0, 0.3), 0.2)
	PL("Barrel", gr, Vector3(-3.4, 0, 0.8))
	PL("Pot_1", gr, Vector3(-2.4, 0, 0.9), 0.0, 0.6)
	inter("poste_treino", "training", Vector3(gr * Vector3(-2.6, 0, 3.4)), {"name": "Poste de Treino"})
	npc("capitao_rui", "guard_captain", Vector3(gr * Vector3(-0.6, 0, 3.0)), float(guard.yaw) + 0.8)

	# -- everyday life around the other houses: woodpiles, carts, crates, gardens with fences
	var stories: Array = [
		["A", "woodpile"], ["B", "garden"], ["C", "cart"], ["D", "woodpile"], ["E", "garden"], ["F", "crates"],
		["G", "woodpile"], ["H", "garden"]]
	for s in stories:
		var hd: Dictionary = hfind(s[0])
		if hd.is_empty():
			continue
		var r: Transform3D = Transform3D(rot(float(hd.yaw)), Vector3(hd.pos.x, float(hd.pad.y), hd.pos.y))
		var W: float = float(hd.spec.w) * 2.0
		var D: float = float(hd.spec.d) * 2.0
		match s[1]:
			"woodpile":
				var wp: Vector3 = r * Vector3(W * 0.5 + 0.9, 0, -D * 0.2)
				woodpile(wp.x, wp.z, float(hd.yaw) + PI * 0.5, 5)
				PL("Axe_Bronze", r, Vector3(W * 0.5 + 0.9, 0.0, D * 0.25), 0.3)
			"garden":
				var g0: Vector3 = r * Vector3(-W * 0.5 - 0.6, 0, -D * 0.5)
				var g1: Vector3 = r * Vector3(-W * 0.5 - 5.0, 0, -D * 0.5)
				var g2: Vector3 = r * Vector3(-W * 0.5 - 5.0, 0, D * 0.3)
				fence_line(Vector2(g0.x, g0.z), Vector2(g1.x, g1.z))
				fence_line(Vector2(g1.x, g1.z), Vector2(g2.x, g2.z))
				for k in 6:
					var cp: Vector3 = r * Vector3(-W * 0.5 - 1.5 - (k % 3) * 1.2, 0, -D * 0.3 + (k / 3) * 1.4)
					P("Carrot", cp.x, cp.z, k * 1.3, 1.2)
				P("Bucket_Wooden_1", g0.x - 0.4, g0.z + 0.8)
			"cart":
				var cp2: Vector3 = r * Vector3(W * 0.5 + 2.2, 0, 1.0)
				P("Prop_Wagon", cp2.x, cp2.z, float(hd.yaw) + 0.2, 1.0, 0.0, true)
				col_box(cp2 + Vector3(0, 0.8, 0), Vector3(2.0, 1.6, 4.0), float(hd.yaw) + 0.2)
				P("Crate_Wooden", cp2.x + 1.5, cp2.z - 1.0, 0.4)
			"crates":
				var c0: Vector3 = r * Vector3(-W * 0.5 - 0.8, 0, D * 0.3)
				P("Crate_Wooden", c0.x, c0.z, 0.2)
				P("Crate_Wooden", c0.x + 0.2, c0.z - 1.0, 0.7)
				P("Barrel", c0.x - 0.5, c0.z + 0.9)
	# flower boxes and lanterns by the doors of houses that face the square
	for id in ["A", "F", "D"]:
		var hd2: Dictionary = hfind(id)
		var dr: Transform3D = Transform3D(rot(float(hd2.yaw)), door(hd2, 0.0))
		PL("Lantern_Wall", dr, Vector3(1.3, 2.2, -0.3), PI * 0.5)
		PL("Bush_Common_Flowers", dr, Vector3(-1.8, 0, 0.5), 0.0, 0.6)
	spawn("village_square", 1.0, -18.0)
	spawn("village", 1.0, -18.0)
	camp("village_strays", "village", at(-30, -50), ["wolf_imp"], 2, 1)


func _well(x: float, z: float) -> void:
	var y: float = gy(x, z)
	for ring in 2:
		for i in 10:
			var a: float = TAU * i / 10.0 + ring * 0.3
			PX("Pebble_Square_%d" % (i % 6 + 1), Transform3D(rot(a + PI * 0.5).scaled(Vector3(2.4, 2.8, 2.2)),
				Vector3(x + cos(a) * 0.95, y + ring * 0.33, z + sin(a) * 0.95)), true)
	var water: CylinderMesh = CylinderMesh.new()
	water.top_radius = 0.8
	water.bottom_radius = 0.8
	water.height = 0.05
	water.radial_segments = 12
	_mesh_into("dark", water, Transform3D(Basis(), Vector3(x, y + 0.45, z)))
	for sx in [-1.0, 1.0]:
		wbox(Transform3D(Basis(), Vector3(x + sx * 1.15, y + 1.1, z)), Vector3(0.16, 2.2, 0.16))
	wbox(Transform3D(Basis(), Vector3(x, y + 1.85, z)), Vector3(2.5, 0.12, 0.12))
	PX("Roof_Wooden_2x1", Transform3D(rot(0.0), Vector3(x, y + 2.15, z - 0.6)), true)
	PX("Roof_Wooden_2x1", Transform3D(rot(PI), Vector3(x, y + 2.15, z + 0.6)), true)
	P("Bucket_Wooden_1", x + 0.9, z + 1.0, 0.4)
	PX("Rope_1", Transform3D(Basis(), Vector3(x, y + 1.7, z)))
	col_cyl(x, z, 1.3, 2.4)
	inter("poco_vila", "well", at(x, z + 1.6))


# ------------------------------------------------------------------ QUINTA DO REGO
func farm() -> void:
	region("Farm")
	for hd in m.houses:
		if hd.spec.get("region", "") == "Farm":
			house(hd)
	var fh: Dictionary = hfind("farmhouse")
	var barn: Dictionary = hfind("barn")
	var coop: Dictionary = hfind("coop")
	# fences around the fields, with gaps where the paths come in
	for f in m.FIELDS:
		var c: Vector2 = f[0]
		var hs: Vector2 = (f[1] as Vector2) + Vector2(1.2, 1.2)
		var corners: Array = [c + Vector2(-hs.x, -hs.y), c + Vector2(hs.x, -hs.y), c + Vector2(hs.x, hs.y), c + Vector2(-hs.x, hs.y)]
		for k in 4:
			var a: Vector2 = corners[k]
			var b: Vector2 = corners[(k + 1) % 4]
			if k == 3:
				# gate gap on the west side
				var mid: Vector2 = (a + b) * 0.5
				fence_line(a, mid + (a - mid).normalized() * 1.6)
				fence_line(mid + (b - mid).normalized() * 1.6, b)
			else:
				fence_line(a, b)
	# yard life
	var fr: Transform3D = Transform3D(rot(float(fh.yaw)), door(fh, 0.0))
	PL("Bench", fr, Vector3(2.2, 0, 0.7), 0.0, 0.8)
	PL("Barrel_Apples", fr, Vector3(-2.4, 0, 0.6))
	PL("FarmCrate_Apple", fr, Vector3(-3.2, 0, 1.2), 0.3)
	var by: Transform3D = Transform3D(rot(float(barn.yaw)), door(barn, 0.0))
	P("Prop_Wagon", (by * Vector3(4.2, 0, 3.0)).x, (by * Vector3(4.2, 0, 3.0)).z, float(barn.yaw) + 0.5, 1.0, 0.0, true)
	col_box(by * Vector3(4.2, 0.8, 3.0), Vector3(2.0, 1.6, 4.0), float(barn.yaw) + 0.5)
	PL("FarmCrate_Carrot", by, Vector3(-2.2, 0, 1.2), 0.2)
	PL("FarmCrate_Empty", by, Vector3(-2.8, 0, 2.0), 1.0)
	PL("Bag", by, Vector3(-1.6, 0, 2.2), 0.4)
	PL("Pickaxe_Bronze", by, Vector3(2.0, 0.0, 0.6), 0.2)
	woodpile((by * Vector3(-5.5, 0, -2.0)).x, (by * Vector3(-5.5, 0, -2.0)).z, float(barn.yaw), 6)
	# hay bales stacked by the barn (wood-tinted cylinders read as straw)
	var hay: CylinderMesh = CylinderMesh.new()
	hay.top_radius = 0.6
	hay.bottom_radius = 0.6
	hay.height = 1.1
	hay.radial_segments = 12
	for i in 4:
		var hp: Vector3 = by * Vector3(-4.0 + (i % 3) * 1.2, 0.6 + (i / 3) * 1.1, 3.8 + (i / 3) * 0.0)
		_mesh_into("wood", hay, Transform3D(rot(float(barn.yaw)) * Basis(Vector3(0, 0, 1), PI * 0.5), hp), Color(1.9, 1.5, 0.75))
	# chicken coop run
	var cr: Transform3D = Transform3D(rot(float(coop.yaw)), door(coop, 0.0))
	var c0: Vector3 = cr * Vector3(-2.5, 0, 0.2)
	var c1: Vector3 = cr * Vector3(-2.5, 0, 4.0)
	var c2: Vector3 = cr * Vector3(2.5, 0, 4.0)
	var c3: Vector3 = cr * Vector3(2.5, 0, 0.2)
	fence_line(Vector2(c0.x, c0.z), Vector2(c1.x, c1.z))
	fence_line(Vector2(c1.x, c1.z), Vector2(c2.x, c2.z))
	fence_line(Vector2(c2.x, c2.z), Vector2(c3.x, c3.z))
	PL("Bucket_Wooden_1", cr, Vector3(1.0, 0, 2.0))
	PL("Pot_1", cr, Vector3(-1.0, 0, 2.6), 0.0, 0.6)
	# the dug seed in the grey field: a glassy pit, a hat-shaped stone, Matias's spade left in the dirt
	var pit: Vector2 = Vector2(132, 102)
	var pd: CylinderMesh = CylinderMesh.new()
	pd.top_radius = 1.4
	pd.bottom_radius = 1.2
	pd.height = 0.1
	pd.radial_segments = 16
	pd.rings = 1
	_mesh_into("glass", pd, Transform3D(Basis(), at(pit.x, pit.y) + Vector3(0, 0.0, 0)))
	P("Pickaxe_Bronze", pit.x + 1.8, pit.y + 0.5, 1.2)
	inter("cova_quinta", "landmark", at(pit.x, pit.y + 2.0), {"name": "Cova da Semente"})
	marco("marco_quinta", 118.0, 88.0, false, false)
	# a scarecrow in the wheat (Dummy) and the north-field fence where Matias leaves bread for his brother
	P("Dummy", 136, 44, 0.6, 1.1, 0.0, true)
	P("Bag", 128.5, 25.4, 0.0, 0.6)
	inter("cerca_norte", "landmark", at(128, 23.5), {"name": "Cerca do Campo Norte"})
	# turnips to pull in the grey/turnip field
	var nabos: Array = [Vector2(90, 100), Vector2(98, 104), Vector2(104, 112), Vector2(92, 114), Vector2(100, 96)]
	for i in nabos.size():
		var np: Vector2 = nabos[i]
		P("Carrot", np.x, np.y, i * 1.1, 1.3)
		inter("nabo_%d" % (i + 1), "pickup", at(np.x, np.y), {"item": "nabo"})
	inter("relha_velha", "pickup", Vector3(by * Vector3(0, 0, -2.0)), {"item": "relha_velha"})
	inter("sino_vaca_1", "pickup", at(150, 78), {"item": "sino_vaca"})
	npc("matias", "farmer", Vector3(fr * Vector3(1.0, 0, 3.0)), float(fh.yaw))
	camp("farm_coop", "farm", Vector3(cr * Vector3(0, 0, 6.0)), ["wolf_imp"], 3, 1)
	spawn("farm", 100, 66)


# ------------------------------------------------------------------ MOINHO DAS TRÊS MÓS + PONTE DO DÍZIMO
func river_place() -> void:
	region("River")
	for hd in m.houses:
		if hd.spec.get("region", "") == "River":
			house(hd)
	var mill: Dictionary = hfind("mill")
	var mr: Transform3D = Transform3D(rot(float(mill.yaw)), Vector3(mill.pos.x, float(mill.pad.y), mill.pos.y))
	# the wheel sits in the stream on the west wall (local -Z of the mill, which faces east)
	var wl: Vector3 = mr * Vector3(0, 0, -5.3)
	var near: Array = t.river_nearest(wl.x, wl.z)
	var wy: float = (near[1] as Vector3).y
	var wc: Vector3 = Vector3(wl.x, wy + 1.9, wl.z)
	var wheel_axis: Basis = rot(float(mill.yaw))      # wheel plane = local XY of the mill (axle along local Z)
	var R: float = 3.0
	for i in 12:
		var a: float = TAU * i / 12.0
		var lp: Vector3 = Vector3(cos(a) * R, sin(a) * R, 0)
		var paddle: Transform3D = Transform3D(wheel_axis * Basis(Vector3(0, 0, 1), a), wc + wheel_axis * lp)
		wbox(paddle, Vector3(0.9, 0.1, 1.2), Color(0.8, 0.75, 0.7))
		for side in [-0.55, 0.55]:
			var a1: float = a + TAU / 24.0
			var rim: Transform3D = Transform3D(wheel_axis * Basis(Vector3(0, 0, 1), a1 + PI * 0.5), wc + wheel_axis * Vector3(cos(a1) * (R - 0.2), sin(a1) * (R - 0.2), side))
			wbox(rim, Vector3(1.65, 0.18, 0.12), Color(0.7, 0.62, 0.55))
	for i in 4:
		var a2: float = PI * i / 4.0
		for side2 in [-0.55, 0.55]:
			wbox(Transform3D(wheel_axis * Basis(Vector3(0, 0, 1), a2), wc + wheel_axis * Vector3(0, 0, side2)), Vector3(R * 2.0 - 0.4, 0.14, 0.12))
	wbox(Transform3D(wheel_axis, wc + wheel_axis * Vector3(0, 0, 1.2)), Vector3(0.35, 0.35, 3.2), Color(0.6, 0.55, 0.5))
	# the raft the hero came on: doors nailed together, broken and caught in the paddles
	for i in 3:
		var rp: Vector3 = wc + wheel_axis * Vector3(-1.6 + i * 0.9, -2.0 + i * 0.25, -1.3 - i * 0.3)
		wbox(Transform3D(wheel_axis * Basis(Vector3(1, 0, 0), 0.3 + i * 0.4) * Basis(Vector3.UP, i * 0.7), rp), Vector3(0.9, 0.08, 1.9), Color(0.75, 0.7, 0.62))
	inter("restos_jangada", "landmark", Vector3(mr * Vector3(-2.0, 0, -3.8)), {"name": "Restos da Jangada"})
	# sluice lever on the bank, flour sacks by the door, millstones leaning on the wall
	var lever: Vector3 = mr * Vector3(3.6, 0, -5.0)
	wbox(Transform3D(Basis(), Vector3(lever.x, gy(lever.x, lever.z) + 0.5, lever.z)), Vector3(0.5, 1.0, 0.5), Color(0.6, 0.6, 0.6))
	wbox(Transform3D(Basis(Vector3(1, 0, 0), 0.5), Vector3(lever.x, gy(lever.x, lever.z) + 1.3, lever.z)), Vector3(0.1, 1.4, 0.1))
	inter("moinho_comporta", "lever", Vector3(lever.x, gy(lever.x, lever.z), lever.z + 0.8), {"name": "Comporta do Moinho"})
	var dr: Transform3D = Transform3D(rot(float(mill.yaw)), door(mill, 0.0))
	for i in 3:
		PL("Bag", dr, Vector3(-2.2 + i * 0.5, 0, 0.9 + (i % 2) * 0.3), i * 0.9)
		inter("farinha_%d" % (i + 1), "pickup", Vector3(dr * Vector3(-2.2 + i * 0.5, 0, 1.0)), {"item": "farinha"})
	var stone: CylinderMesh = CylinderMesh.new()
	stone.top_radius = 0.75
	stone.bottom_radius = 0.75
	stone.height = 0.3
	stone.radial_segments = 14
	for i in 3:
		var sp: Vector3 = dr * Vector3(2.4 + i * 0.35, 0.72, -0.4 - i * 0.05)
		_mesh_into("rock", stone, Transform3D(rot(float(mill.yaw)) * Basis(Vector3(1, 0, 0), PI * 0.5 - 0.2), sp))
	PL("Prop_Wagon", dr, Vector3(4.5, 0, 4.5), 0.9, 1.0, true)
	camp("river_millers", "river", Vector3(dr * Vector3(0, 0, 6.0)), ["bandit"], 3, 2)

	# -- the toll bridge: planks over beams over posts, rails, a toll hut with the Vigília banner
	var road: Dictionary = {}
	for r in t.roads:
		if r.id == "mill":
			road = r
	var pts: PackedVector3Array = road.pts
	var br: Array = road.bridge
	var first: int = -1
	var last: int = -1
	for k in pts.size():
		if br[k]:
			if first < 0:
				first = k
			last = k
	first = maxi(0, first - 2)
	last = mini(pts.size() - 1, last + 2)
	var deck_y: float = pts[(first + last) / 2].y + 0.35
	var a0: Vector3 = pts[first]
	var a1: Vector3 = pts[last]
	var dir: Vector3 = Vector3(a1.x - a0.x, 0, a1.z - a0.z)
	var L: float = dir.length()
	dir /= L
	var yaw: float = atan2(dir.x, dir.z)
	var bb: Basis = rot(yaw)
	var n: int = int(L / 0.55)
	for i in n + 1:
		var p: Vector3 = Vector3(a0.x, deck_y, a0.z) + dir * (i * L / n)
		wbox(Transform3D(bb, p), Vector3(3.6, 0.12, 0.5), Color(0.85 + 0.15 * sin(i * 2.3), 0.8, 0.75))
	for side in [-1.0, 1.0]:
		wbox(Transform3D(bb, Vector3(a0.x, deck_y - 0.2, a0.z) + dir * (L * 0.5) + bb * Vector3(side * 1.5, 0, 0)), Vector3(0.3, 0.3, L + 0.6), Color(0.65, 0.6, 0.55))
		wbox(Transform3D(bb, Vector3(a0.x, deck_y + 1.0, a0.z) + dir * (L * 0.5) + bb * Vector3(side * 1.75, 0, 0)), Vector3(0.12, 0.12, L), Color(0.9, 0.85, 0.8))
		var np: int = int(L / 2.5) + 1
		for i in np:
			var pp: Vector3 = Vector3(a0.x, deck_y, a0.z) + dir * (i * L / (np - 1)) + bb * Vector3(side * 1.75, 0, 0)
			wbox(Transform3D(bb, pp + Vector3(0, 0.5, 0)), Vector3(0.16, 1.1, 0.16))
			var gyp: float = gy(pp.x, pp.z)
			var depth: float = deck_y - gyp
			if depth > 0.8:
				wbox(Transform3D(bb, Vector3(pp.x, (deck_y + gyp) * 0.5 - 0.3, pp.z)), Vector3(0.28, depth + 0.6, 0.28), Color(0.55, 0.5, 0.45))
	col_box(Vector3(a0.x, deck_y - 0.2, a0.z) + dir * (L * 0.5), Vector3(3.6, 0.4, L + 1.0), yaw)
	# ramps from the banks up to the deck: without them the road ran under a deck the hero could not climb onto
	for end in [[a0, -dir], [a1, dir]]:
		var e: Vector3 = end[0]
		var out: Vector3 = end[1]
		var top := Vector3(e.x, deck_y, e.z)
		var g := Vector3(e.x, 0.0, e.z) + out * 5.0
		g.y = gy(g.x, g.z) + 0.02
		if g.y >= deck_y - 0.1:
			continue
		col_ramp(top, g, 3.6)
	for side in [-1.0, 1.0]:
		col_box(Vector3(a0.x, deck_y + 0.6, a0.z) + dir * (L * 0.5) + bb * Vector3(side * 1.85, 0, 0), Vector3(0.2, 1.2, L), yaw)
	var mid: Vector3 = Vector3(a0.x, deck_y, a0.z) + dir * (L * 0.5)
	inter("ponte_rio", "bridge", mid + bb * Vector3(1.2, 0, 0), {"name": "Ponte do Dízimo"})
	var toll: Dictionary = hfind("toll")
	var tr: Transform3D = Transform3D(rot(float(toll.yaw)), door(toll, 0.0))
	PL("Banner_2", tr, Vector3(-2.0, 0, 0.5), 0.0)
	PL("Table_Large", tr, Vector3(1.6, 0, 1.3), PI * 0.5, 0.6)
	PL("Coin_Pile", tr, Vector3(1.6, 0.5, 1.2), 0.0)
	PL("Barrel", tr, Vector3(2.8, 0, 0.2))
	# barrier pole across the road at the east end of the bridge
	var bp: Vector3 = Vector3(a1.x, 0, a1.z) + dir * 2.5
	wbox(Transform3D(bb, Vector3(bp.x, gy(bp.x, bp.z) + 0.55, bp.z) + bb * Vector3(-2.4, 0, 0)), Vector3(0.3, 1.1, 0.3))
	wbox(Transform3D(bb * Basis(Vector3(0, 0, 1), 1.15), Vector3(bp.x, gy(bp.x, bp.z) + 1.9, bp.z) + bb * Vector3(-1.8, 0, 0)), Vector3(3.6, 0.12, 0.12), Color(1.1, 0.6, 0.5))
	camp("bridge_toll", "river", mid, ["bandit"], 3, 2)
	inter("sino_vaca_2", "pickup", Vector3(a1.x, gy(a1.x, a1.z), a1.z) + bb * Vector3(4.0, 0, 3.0), {"item": "sino_vaca"})
	spawn("river", (dr * Vector3(0, 0, 4)).x, (dr * Vector3(0, 0, 4)).z)
	spawn("bridge", bp.x, bp.z)


# ------------------------------------------------------------------ LAGO MANSO
func lake() -> void:
	region("Lake")
	for hd in m.houses:
		if hd.spec.get("region", "") == "Lake":
			house(hd)
	var hut: Dictionary = hfind("celeste")
	var y: float = Terrain.LAKE_Y + 0.55
	var x0: float = 44.0
	var z0: float = 166.0
	var z1: float = 186.0
	var n: int = int((z1 - z0) / 0.5)
	for i in n:
		var z: float = z0 + i * 0.5
		wbox(Transform3D(rot(PI * 0.5), Vector3(x0 + sin(i * 1.7) * 0.03, y + gy(x0, z) * 0.0, z)), Vector3(0.45, 0.1, 2.6), Color(0.85 + 0.15 * sin(i * 3.1), 0.82, 0.76))
	for i in 6:
		var z2: float = z0 + 1.0 + i * 3.6
		for sx in [-1.25, 1.25]:
			var g: float = gy(x0 + sx, z2)
			wbox(Transform3D(Basis(), Vector3(x0 + sx, (y + g) * 0.5 - 0.2, z2)), Vector3(0.22, y - g + 0.9, 0.22), Color(0.55, 0.5, 0.45))
	# the end of the pier widens to a landing with a bollard, ropes, a bench
	for i in 4:
		wbox(Transform3D(Basis(), Vector3(x0 + 2.4, y, z1 - 3.5 + i * 0.9)), Vector3(2.2, 0.1, 0.8), Color(0.9, 0.85, 0.8))
	PX("Rope_2", Transform3D(Basis(), Vector3(x0 + 2.8, y + 0.06, z1 - 1.5)))
	PX("Bucket_Wooden_1", Transform3D(Basis(), Vector3(x0 - 0.6, y + 0.06, z1 - 4.0)))
	PX("FarmCrate_Empty", Transform3D(rot(0.3), Vector3(x0 + 0.4, y + 0.06, z0 + 3.0)))
	col_box(Vector3(x0, y - 0.25, (z0 + z1) * 0.5), Vector3(2.6, 0.4, z1 - z0), 0.0)
	col_box(Vector3(x0 + 2.4, y - 0.25, z1 - 2.2), Vector3(2.2, 0.4, 3.6), 0.0)
	# Celeste's boat moored at the landing
	var boat_xf: Transform3D = Transform3D(rot(0.15), Vector3(x0 + 4.6, Terrain.LAKE_Y + 0.05, z1 - 2.0))
	_boat(boat_xf)
	inter("barco_celeste", "boat", Vector3(x0 + 3.2, y, z1 - 2.0), {"name": "Barco de Celeste"})
	npc("dona_celeste", "fisher", Vector3(x0 + 0.3, y, z1 - 2.5), PI)
	camp("lake_insones", "lake", Vector3(x0, y, z0 - 2.0), ["possessed"], 3, 4)
	inter("insone_tome", "npc", Vector3(x0 + 2.8, y, z1 - 0.8), {"name": "Tomé"})
	inter("peixe_lua", "fishing", Vector3(x0 - 0.4, y, z1 - 0.5), {"item": "peixe_lua"})
	# hut life: drying rack with nets (rope coils), fish crates, overturned old boat
	var hr: Transform3D = Transform3D(rot(float(hut.yaw)), door(hut, 0.0))
	for sx in [-1.6, 1.6]:
		wbox(hr * Transform3D(Basis(), Vector3(sx + 3.6, 0.9, 1.5)), Vector3(0.12, 1.8, 0.12))
	wbox(hr * Transform3D(Basis(), Vector3(3.6, 1.75, 1.5)), Vector3(3.6, 0.08, 0.08))
	PL("Rope_3", hr, Vector3(3.6, 1.35, 1.5), 0.0)
	PL("Rope_1", hr, Vector3(2.8, 0, 2.4), 0.0)
	PL("FarmCrate_Empty", hr, Vector3(-2.0, 0, 1.0), 0.4)
	PL("Barrel", hr, Vector3(-2.6, 0, 0.2))
	_boat(hr * Transform3D(Basis(Vector3(0, 0, 1), PI) * rot(1.4), Vector3(-1.0, 0.75, 5.5)))
	spawn("lake", 44, 160)
	spawn("pier", x0, z1 - 2.0)


func _boat(xf: Transform3D) -> void:
	# lofted hull: stations along z, each a U of 5 points
	var st: SurfaceTool = _proc("wood")
	var L: float = 4.2
	var stations: int = 9
	var rings: Array = []
	for s in stations:
		var u: float = float(s) / (stations - 1)
		var z: float = (u - 0.5) * L
		var w: float = 0.85 * sqrt(maxf(0.0, 1.0 - pow(abs(u - 0.5) * 2.0, 2.2)))
		var dep: float = 0.45 * (0.6 + 0.4 * w / 0.85)
		var top: float = 0.35 + 0.18 * pow(abs(u - 0.5) * 2.0, 2.0)
		var ring: Array = [Vector3(-w, top, z), Vector3(-w * 0.9, -dep * 0.4, z), Vector3(0, -dep, z), Vector3(w * 0.9, -dep * 0.4, z), Vector3(w, top, z)]
		rings.append(ring)
	for s in stations - 1:
		for k in 4:
			var q: Array = [rings[s][k], rings[s + 1][k], rings[s + 1][k + 1], rings[s][k + 1]]
			var uvq: Array = [Vector2(s * 0.5, 0.38 + k * 0.05), Vector2((s + 1) * 0.5, 0.38 + k * 0.05), Vector2((s + 1) * 0.5, 0.43 + k * 0.05), Vector2(s * 0.5, 0.43 + k * 0.05)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(0.9, 0.82, 0.72))
				st.set_uv(uvq[i])
				st.add_vertex(xf * (q[i] as Vector3))
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_color(Color(0.6, 0.52, 0.45))
				st.set_uv(uvq[i])
				st.add_vertex(xf * (q[i] as Vector3))
	for i in 2:
		wbox(xf * Transform3D(Basis(), Vector3(0, 0.15, -0.6 + i * 1.3)), Vector3(1.4, 0.06, 0.3))


# ------------------------------------------------------------------ BOSQUE DOS SUSSURROS
func forest() -> void:
	region("Forest")
	var c: Vector2 = Vector2(-185, 25)
	var y: float = gy(c.x, c.y)
	# the Carvalha-Mãe: the oldest tree of the valley, roots holding the seed, moss and mushrooms all around
	PX("TwistedTree_3#moss", Transform3D(rot(0.8).scaled(Vector3.ONE * 1.55), Vector3(c.x, y - 0.4, c.y)), true)
	col_cyl(c.x, c.y, 2.2, 8.0)
	for i in 9:
		var a: float = TAU * i / 9.0 + 0.2
		var r: float = 3.2 + (i % 3) * 0.9
		P("Mushroom_Laetiporus" if i % 3 == 0 else "Mushroom_Common", c.x + cos(a) * r, c.y + sin(a) * r, a, 1.0 + (i % 2) * 0.5)
	for i in 5:
		var a2: float = TAU * i / 5.0 + 1.0
		PX("Rock_Medium_%d#moss" % (i % 3 + 1), Transform3D(rot(a2).scaled(Vector3(0.6, 0.45, 0.6)), at(c.x + cos(a2) * 6.5, c.y + sin(a2) * 6.5) - Vector3(0, 0.3, 0)), true)
	inter("carvalha_mae", "tree", at(c.x + 3.4, c.y + 2.0), {"name": "Carvalha-Mãe"})
	marco("marco_bosque", c.x + 11.0, c.y - 7.0, true, false)
	# a cow bell hanging in the imps' nest north of the glade, and an old hunter's camp on the track
	var nest: Vector2 = Vector2(-205, -40)
	for i in 6:
		var a3: float = TAU * i / 6.0
		P("DeadTree_%d" % (i % 5 + 1), nest.x + cos(a3) * 3.5, nest.y + sin(a3) * 3.5, a3, 0.25)
	inter("sino_vaca_3", "pickup", at(nest.x, nest.y), {"item": "sino_vaca"})
	camp("forest_nest", "forest", at(nest.x, nest.y), ["wolf_imp"], 3, 2)
	camp("forest_glade", "forest", at(c.x + 14, c.y + 10), ["wolf_imp"], 5, 2)
	camp("forest_road", "forest", at(-118, 64), ["wolf_imp"], 4, 2)
	var hc: Vector2 = Vector2(-150, 34)
	campfire(hc.x, hc.y)
	P("Bench", hc.x - 1.8, hc.y + 1.2, 0.4, 0.7)
	tent(hc.x + 2.5, hc.y - 2.8, 0.6, 2.2, 2.6, 1.7, Color(0.62, 0.58, 0.45))
	spawn("forest", c.x + 16, c.y + 4)


# ------------------------------------------------------------------ ACAMPAMENTO DOS SEM-TERRA (quarry)
func bandit_camp() -> void:
	region("Camp")
	var c: Vector2 = Vector2(-212, 166)
	campfire(c.x, c.y)
	var tents: Array = [
		[Vector2(-220, 158), 0.7, 3.2, 3.6, 2.4, Color(0.72, 0.62, 0.45)],     # Tobias's tent, biggest
		[Vector2(-204, 156), -0.5, 2.4, 3.0, 1.9, Color(0.62, 0.6, 0.5)],
		[Vector2(-222, 174), 2.2, 2.4, 2.8, 1.8, Color(0.55, 0.47, 0.38)],
		[Vector2(-206, 177), -2.4, 2.2, 2.8, 1.8, Color(0.7, 0.55, 0.42)],
	]
	for tdef in tents:
		var tp: Vector2 = tdef[0]
		tent(tp.x, tp.y, tdef[1], tdef[2], tdef[3], tdef[4], tdef[5])
	var tob: Vector2 = tents[0][0]
	var ty: float = tents[0][1]
	var tr: Transform3D = Transform3D(rot(ty), at(tob.x, tob.y))
	PL("Banner_1", tr, Vector3(2.4, 0, 2.2), 0.0)
	PL("Chest_Wood", tr, Vector3(-1.9, 0, 2.4), 0.3)
	PL("Table_Large", tr, Vector3(0.6, 0, 3.6), 0.2, 0.6)
	PL("Scroll_1", tr, Vector3(0.6, 0.5, 3.6), 0.4)
	inter("tenda_tobias", "tent", Vector3(tr * Vector3(0, 0, 2.6)), {"name": "Tenda de Tobias"})
	npc("tobias", "bandit_leader", Vector3(tr * Vector3(0.4, 0, 2.4)), ty)
	# the stolen Vigília cart with flour sacks, crates and barrels
	P("Prop_Wagon", -198, 166, 1.9, 1.0, 0.0, true)
	col_box(at(-198, 166) + Vector3(0, 0.8, 0), Vector3(2.0, 1.6, 4.0), 1.9)
	for i in 4:
		P("Bag", -199.5 + (i % 2) * 0.6, 163.2 + i * 0.5, i)
	P("Crate_Wooden", -196.0, 169.5, 0.3)
	P("Crate_Wooden", -195.6, 170.6, 0.9, 0.9, 0.9)
	P("Barrel", -201.0, 170.0)
	P("Chest_Wood", -214.5, 171.0, 2.6)
	inter("bau_farinha", "chest", at(-214.5, 170.0), {"item": "farinha"})
	P("Bench", -209.5, 163.6, 1.2, 0.7)
	P("Bench", -214.5, 163.4, -1.0, 0.7)
	P("Pot_1_Lid", -211.2, 166.8)
	P("WeaponStand", -207.0, 160.0, -0.8)
	woodpile(-217.0, 165.0, 1.4, 5)
	# archer perches on the quarry rim: plank platforms with crates
	var perches: Array = [Vector2(-232, 152), Vector2(-236, 172), Vector2(-218, 190)]
	for pp in perches:
		var v: Vector2 = pp
		var py: float = gy(v.x, v.y)
		wbox(Transform3D(rot(v.x), Vector3(v.x, py + 0.2, v.y)), Vector3(3.0, 0.12, 2.4))
		P("Crate_Wooden", v.x + 0.8, v.y + 0.5, 0.3)
		P("Banner_2_Cloth", v.x - 1.0, v.y - 0.8, 0.0)
	camp("camp_bandits", "bandit_camp", at(c.x, c.y), ["bandit"], 3, 3)
	camp("camp_archers", "bandit_camp", at(-234, 166), ["bandit_archer"], 3, 3)
	inter("semente_sem_terra", "pickup", Vector3(tr * Vector3(-1.9, 0, 1.6)), {"item": "semente_sem_terra"})
	spawn("bandit_camp", -190, 162)


# ------------------------------------------------------------------ A ATALAIA
func watchtower() -> void:
	region("Watchtower")
	var c: Vector2 = Vector2(186, -52)
	var y: float = gy(c.x, c.y)
	var root: Transform3D = Transform3D(Basis(), Vector3(c.x, y, c.y))
	bld.b = regions[cur].big
	var sz: Vector3 = bld.tower(root, 3, 4, true, true)
	col_box(root * Vector3(0, sz.y * 0.5, 0), sz, 0.0)
	# floor of the ruined top and the dead beacon brazier
	for i in 3:
		for j in 3:
			PL("Floor_UnevenBrick", root, Vector3(-2 + i * 2, 9.02, -2 + j * 2), 0.0, 1.0, true)
	PL("Cauldron", root, Vector3(-0.8, 9.05, -0.6), 0.0, 1.6, true)
	_mesh_into("dark", _flame_mesh(0.6, 0.12), root * Transform3D(Basis(), Vector3(-0.8, 10.3, -0.6)))
	# rubble around the foot
	for i in 8:
		var a: float = TAU * i / 8.0 + 0.4
		PX("Pebble_Square_%d" % (i % 6 + 1), Transform3D(rot(a).scaled(Vector3.ONE * (2.0 + (i % 3))), at(c.x + 4.5 + cos(a) * (1.0 + i * 0.2), c.y + sin(a) * 2.0)), false)
	PX("Rock_Medium_2", Transform3D(rot(1.1).scaled(Vector3(0.5, 0.4, 0.5)), at(c.x + 5.5, c.y - 1.0)), true)
	# the Guarda da Vigília post: a tent, banners, the Livro do Desenterro on a lectern
	tent(c.x - 8.0, c.y + 6.0, 1.2, 2.6, 3.0, 2.0, Color(0.42, 0.38, 0.4))
	P("Banner_1", c.x - 3.6, c.y + 4.2, 0.0)
	P("Banner_1", c.x + 3.6, c.y + 4.2, 0.0)
	P("BookStand", c.x - 5.0, c.y + 9.0, PI * 0.8)
	P("WeaponStand", c.x + 6.0, c.y + 6.5, -0.4)
	P("Crate_Wooden", c.x + 7.2, c.y + 4.4, 0.2)
	P("Barrel", c.x + 7.8, c.y + 5.6)
	campfire(c.x - 2.0, c.y + 9.5)
	inter("livro_desenterro", "pickup", at(c.x - 5.0, c.y + 10.0), {"item": "livro_desenterro"})
	inter("farol_atalaia", "beacon", at(c.x, c.y + 4.4), {"name": "Farol da Atalaia"})
	marco("marco_atalaia", c.x + 12.0, c.y + 10.0, false, false)
	camp("tower_guards", "watchtower", at(c.x, c.y + 8), ["knight"], 2, 4)
	camp("tower_road_guards", "watchtower", at(150, -30), ["knight"], 3, 4)
	spawn("watchtower", c.x, c.y + 14)


# ------------------------------------------------------------------ MINA DO FÔLEGO
func mine() -> void:
	region("Mine")
	for hd in m.houses:
		if hd.spec.get("region", "") == "Mine":
			house(hd)
	var tr: Dictionary = t.trenches[0]
	var pts: Array = tr.pts
	var mouth: Vector2 = pts[1]
	var hw: float = tr.hw
	var dirv: Vector2 = ((pts[2] as Vector2) - mouth).normalized()
	var yaw: float = atan2(dirv.x, dirv.y)
	var bb: Basis = rot(yaw)
	# timber portal at the mouth with a roof of planks: the gallery reads as a tunnel going in
	for k in 4:
		var d: float = k * 3.0
		var p: Vector2 = mouth + dirv * d
		var py: float = gy(p.x, p.y)
		for side in [-1.0, 1.0]:
			wbox(Transform3D(bb, Vector3(p.x, py + 1.6, p.y) + bb * Vector3(side * (hw - 0.4), 0, 0)), Vector3(0.4, 3.2, 0.4), Color(0.75, 0.68, 0.6))
		wbox(Transform3D(bb, Vector3(p.x, py + 3.35, p.y)), Vector3(hw * 2.0 + 0.4, 0.45, 0.45), Color(0.75, 0.68, 0.6))
		if k < 3:
			for i in 6:
				wbox(Transform3D(bb, Vector3(p.x, py + 3.62, p.y) + bb * Vector3(0, 0, 0.25 + i * 0.5)), Vector3(hw * 2.0 + 0.6, 0.1, 0.48), Color(0.6, 0.55, 0.5))
	# the gate (Gaspar's key) just inside the mouth
	var gp: Vector2 = mouth + dirv * 1.5
	var gpy: float = gy(gp.x, gp.y)
	for i in 3:
		PX("Prop_MetalFence_Simple", Transform3D(bb, Vector3(gp.x, gpy, gp.y) + bb * Vector3(-2.0 + i * 2.0, 0, 0)), true)
	col_box(Vector3(gp.x, gpy + 1.5, gp.y), Vector3(hw * 2.0, 3.0, 0.4), yaw)
	inter("mina_portao", "gate", Vector3(gp.x, gpy, gp.y) - Vector3(dirv.x, 0, dirv.y) * 1.6, {"name": "Portão da Mina", "key": "chave_gaspar", "collision_size": Vector3(hw * 2.0, 3.0, 0.4)})
	# rib arches in the gallery: the mountain is the Lumeira, the miners dug between her ribs
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = hw - 0.5
	torus.outer_radius = hw + 0.3
	torus.rings = 20
	torus.ring_segments = 8
	var total: float = 0.0
	for k in range(1, pts.size() - 1):
		total += (pts[k] as Vector2).distance_to(pts[k + 1])
	var dd: float = 13.0
	while dd < total - 8.0:
		var q: Vector2 = _along(pts, 1, dd)
		var qn: Vector2 = _along(pts, 1, dd + 1.0) - q
		var qy: float = gy(q.x, q.y)
		_mesh_into("rock", torus, Transform3D(rot(atan2(qn.x, qn.y)) * Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(q.x, qy - 0.2, q.y)), Color(1.0, 0.92, 0.82))
		dd += 5.0
	# the deep chamber: Marco do Fundo, warm stones, the old tunnel up to the castle crypt
	var ch: Vector2 = pts[pts.size() - 1]
	var chy: float = gy(ch.x, ch.y)
	marco("marco_fundo", ch.x - 2.5, ch.y + 1.5, true, true)
	for i in 7:
		var a: float = TAU * i / 7.0
		_mesh_into("rock", torus, Transform3D(rot(a) * Basis(Vector3(1, 0, 0), PI * 0.5).scaled(Vector3(1.3, 1.3, 1.3)), Vector3(ch.x + cos(a) * 6.5, chy - 0.6, ch.y + sin(a) * 6.5)), Color(1.0, 0.9, 0.8))
	var tun: Vector2 = ch + Vector2(-1.0, -1.0).normalized() * 8.5
	var hole: QuadMesh = QuadMesh.new()
	hole.size = Vector2(2.6, 3.0)
	_mesh_into("dark", hole, Transform3D(rot(PI * 0.25 + PI), Vector3(tun.x, gy(tun.x, tun.y) + 1.4, tun.y)))
	for side in [-1.0, 1.0]:
		wbox(Transform3D(rot(PI * 0.25), Vector3(tun.x, gy(tun.x, tun.y) + 1.5, tun.y) + rot(PI * 0.25) * Vector3(side * 1.45, 0, 0.1)), Vector3(0.35, 3.0, 0.35))
	wbox(Transform3D(rot(PI * 0.25), Vector3(tun.x, gy(tun.x, tun.y) + 3.1, tun.y)), Vector3(3.4, 0.4, 0.4))
	inter("tunel_castelo", "door", at(tun.x, tun.y) + Vector3(1.0, 0, 1.0), {"name": "Túnel Velho", "leads_to": "castle_crypt"})
	inter("semente_funda", "pickup", at(ch.x + 1.5, ch.y - 1.0), {"item": "semente_funda"})
	(m.spawns as Dictionary)["mina_fundo"] = at(ch.x + 2.0, ch.y + 3.0) + Vector3(0, 0.1, 0)
	(m.places as Array).append({"id": "mina_fundo", "name": "Fundo da Mina", "pos": at(ch.x, ch.y), "radius": 12.0})
	camp("mine_pugos", "mine", at(_along(pts, 1, 18.0).x, _along(pts, 1, 18.0).y), ["puglin"], 6, 5)
	# outside: Gaspar's cabin, rails of crates, lanterns, pickaxes, a cart of ore
	var cab: Dictionary = hfind("gaspar")
	var cr: Transform3D = Transform3D(rot(float(cab.yaw)), door(cab, 0.0))
	PL("Bench", cr, Vector3(1.8, 0, 0.8), 0.0, 0.7)
	PL("Lantern_Wall", cr, Vector3(-1.2, 2.2, -0.3), PI * 0.5)
	woodpile((cr * Vector3(-3.0, 0, 0.6)).x, (cr * Vector3(-3.0, 0, 0.6)).z, float(cab.yaw), 4)
	var out: Vector2 = mouth - dirv * 4.0
	P("Prop_Wagon", out.x + 3.5, out.y - 1.0, yaw + 0.3, 1.0, 0.0, true)
	col_box(at(out.x + 3.5, out.y - 1.0) + Vector3(0, 0.8, 0), Vector3(2.0, 1.6, 4.0), yaw + 0.3)
	P("Pickaxe_Bronze", out.x - 2.8, out.y + 0.5, 0.4)
	P("Crate_Metal", out.x - 3.4, out.y - 0.8, 0.2)
	P("Crate_Wooden", out.x - 3.0, out.y - 2.0, 0.9)
	P("Torch_Metal", out.x - 2.2, out.y + 2.2, yaw)
	P("Torch_Metal", out.x + 2.2, out.y + 2.2, yaw)
	npc("gaspar", "miner", Vector3(cr * Vector3(0.8, 0, 1.6)), float(cab.yaw))
	spawn("mine", out.x, out.y - 3.0)


func _along(pts: Array, from: int, dist: float) -> Vector2:
	var left: float = dist
	for k in range(from, pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var L: float = a.distance_to(b)
		if left <= L:
			return a.lerp(b, left / L)
		left -= L
	return pts[pts.size() - 1]


# ------------------------------------------------------------------ CASTELO DE VIGÍLIA
func castle() -> void:
	region("Castle")
	var pad: Dictionary = m.castle_pad
	var c: Vector2 = pad.c
	var y: float = pad.y
	var root: Transform3D = Transform3D(Basis(), Vector3(c.x, y, c.y))
	bld.b = regions[cur].big
	var hx: float = 22.0
	var hz: float = 18.0
	var corners: Array = [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	# curtain walls (east wall has the gate gap in the middle)
	bld.wall_line(root, Vector3(-hx + 3, 0, -hz), Vector3(hx - 3, 0, -hz), 3, -1.0)
	bld.wall_line(root, Vector3(-hx + 3, 0, hz), Vector3(hx - 3, 0, hz), 3, 1.0)
	bld.wall_line(root, Vector3(-hx, 0, -hz + 3), Vector3(-hx, 0, hz - 3), 3, 1.0)
	bld.wall_line(root, Vector3(hx, 0, -hz + 3), Vector3(hx, 0, -3.5), 3, -1.0)
	bld.wall_line(root, Vector3(hx, 0, 3.5), Vector3(hx, 0, hz - 3), 3, -1.0)
	col_box(root * Vector3(0, 4.5, -hz), Vector3(hx * 2, 9, 1.0), 0.0)
	col_box(root * Vector3(0, 4.5, hz), Vector3(hx * 2, 9, 1.0), 0.0)
	col_box(root * Vector3(-hx, 4.5, 0), Vector3(1.0, 9, hz * 2), 0.0)
	col_box(root * Vector3(hx, 4.5, -hz * 0.5 - 1.75), Vector3(1.0, 9, hz - 3.5), 0.0)
	col_box(root * Vector3(hx, 4.5, hz * 0.5 + 1.75), Vector3(1.0, 9, hz - 3.5), 0.0)
	for cc in corners:
		var tr: Transform3D = root * Transform3D(Basis(), cc)
		var s: Vector3 = bld.tower(tr, 3, 5, false, false)
		col_box(tr * Vector3(0, s.y * 0.5, 0), s, 0.0)
	# gatehouse: two towers and an arch over the road
	for sz in [-1.0, 1.0]:
		var gt: Transform3D = root * Transform3D(Basis(), Vector3(hx, 0, sz * 4.5))
		var s2: Vector3 = bld.tower(gt, 2, 4, false, false)
		col_box(gt * Vector3(0, s2.y * 0.5, 0), s2, 0.0)
	for f in 2:
		PL("Wall_Arch" if f == 0 else "Wall_UnevenBrick_Straight", root, Vector3(hx + 0.3, f * 3.0, 1.0), PI * 0.5, 1.0, true)
		PL("Wall_Arch" if f == 0 else "Wall_UnevenBrick_Straight", root, Vector3(hx + 0.3, f * 3.0, -1.0), PI * 0.5, 1.0, true)
	PL("Banner_1", root, Vector3(hx + 1.6, 0, 3.0), PI * 0.5, 1.4)
	PL("Banner_1", root, Vector3(hx + 1.6, 0, -3.0), PI * 0.5, 1.4)
	inter("castelo_portao", "gate", root * Vector3(hx + 3.0, 0, 0), {"name": "Portão do Castelo"})
	# the keep: three storeys of stone, a tall tower with every window lit (the Count never sleeps)
	var keep: Transform3D = root * Transform3D(rot(PI * 0.5), Vector3(-9, 0, 0))
	var ks: Vector3 = bld.house(keep, {"w": 4, "d": 5, "floors": 3, "style": "brick", "ridge": "z", "seed": 41, "chimney": true})
	col_box(keep * Vector3(0, ks.y * 0.5, 0), ks, PI * 0.5)
	var kt: Transform3D = root * Transform3D(Basis(), Vector3(-15, 0, -9))
	var kts: Vector3 = bld.tower(kt, 3, 7, false, false)
	col_box(kt * Vector3(0, kts.y * 0.5, 0), kts, 0.0)
	# courtyard: banners, braziers, weapon racks, crates, a well of black water
	for i in 4:
		var bp: Vector3 = Vector3(4.0 + i * 3.5, 0, -10.0)
		PL("Torch_Metal", root, bp, 0.0, 1.3)
	PL("WeaponStand", root, Vector3(8, 0, 12), PI)
	PL("WeaponStand", root, Vector3(12, 0, 12), PI)
	PL("Crate_Wooden", root, Vector3(16, 0, -14), 0.3)
	PL("Crate_Wooden", root, Vector3(17, 0, -13), 0.9)
	PL("Barrel", root, Vector3(15.5, 0, -12.5))
	PL("Prop_Wagon", root, Vector3(10, 0, -13), 1.4, 1.0, true)
	PL("Banner_2", root, Vector3(-3.2, 0, 4.6), PI * 0.5)
	PL("Banner_2", root, Vector3(-3.2, 0, -4.6), PI * 0.5)
	var kdoor: Vector3 = keep * Vector3(0, 0, 6.5)
	inter("relicario", "relic", kdoor + Vector3(-2.0, 0, 0), {"name": "Câmara do Coração"})
	inter("castelo_alavanca", "lever", root * Vector3(14, 0, 14), {"name": "Alavanca do Portão Interno"})
	camp("castle_gate", "castle", root * Vector3(hx + 8, 0, 0), ["knight"], 2, 6)
	camp("castle_yard", "castle", root * Vector3(6, 0, 0), ["knight"], 4, 6)
	camp("castle_lord", "castle", kdoor + Vector3(3.0, 0, 0), ["boss"], 1, 8)
	(m.spawns as Dictionary)["castle"] = root * Vector3(hx + 10.0, 0.1, 0)
	(m.spawns as Dictionary)["castle_crypt"] = kdoor + Vector3(2.0, 0.1, 0)
	(m.spawns as Dictionary)["castle_tunnel_exit"] = root * Vector3(-17.0, 0.1, 10.0)
	PL("Chest_Wood", root, Vector3(-18, 0, 14), 0.4)
	inter("bau_castelo", "chest", root * Vector3(-18, 0, 12.8), {"item": "ouro"})
