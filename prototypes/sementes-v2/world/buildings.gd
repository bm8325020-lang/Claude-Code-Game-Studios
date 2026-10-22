# PROTOTYPE - NOT FOR PRODUCTION
# Map module: composes buildings from the Medieval Village MegaKit modules (2 m grid, 3 m storeys).
# Local frame of every building: origin at the centre of the footprint on the ground, front (door side) is +Z.
# Wall modules span x -1..1 with their outside face toward +Z, so a wall at the front edge uses rotation 0.
class_name MapBuildings
extends RefCounted

const Kit = preload("res://world/kit.gd")

const H: float = 3.0   # storey height of the kit

var kit: Kit
var b: Kit.Batch          # static batch the modules go into
var rng: RandomNumberGenerator


func _init(k: Kit, batch: Kit.Batch, seed_value: int) -> void:
	kit = k
	b = batch
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value


static func rot_y(a: float) -> Basis:
	return Basis(Vector3.UP, a)


func put(name: String, root: Transform3D, local_pos: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	var t: Transform3D = Transform3D(rot_y(yaw).scaled(Vector3.ONE * scale), local_pos)
	b.add(name, root * t)


# One straight wall side made of `n` modules, centred on `center`, facing `yaw` (outward normal = rot_y(yaw) * +Z).
# kinds: array of module names (one per slot) or "" for the default.
func wall_side(root: Transform3D, center: Vector3, yaw: float, n: int, kinds: Array) -> void:
	var dir: Vector3 = rot_y(yaw) * Vector3.RIGHT
	for i in n:
		var off: float = (float(i) - float(n - 1) * 0.5) * 2.0
		var nm: String = kinds[i]
		put(nm, root, center + dir * off, yaw)


# Decorate a wall slot with a window or door insert matching the module that was placed there.
func _insert(root: Transform3D, pos: Vector3, yaw: float, wall: String, shutters: bool) -> void:
	if wall.contains("Window_Wide_Round"):
		put("Window_Wide_Round1", root, pos, yaw)
		if shutters:
			put("WindowShutters_Wide_Round_Open", root, pos, yaw)
	elif wall.contains("Window_Wide_Flat"):
		put("Window_Wide_Flat1", root, pos, yaw)
		if shutters:
			put("WindowShutters_Wide_Flat_Open", root, pos, yaw)
	elif wall.contains("Window_Thin_Round"):
		put("Window_Thin_Round1", root, pos, yaw)
		if shutters:
			put("WindowShutters_Thin_Round_Open", root, pos, yaw)
	elif wall.contains("Door_Round"):
		put("Door_2_Round", root, pos + rot_y(yaw) * Vector3(-0.53, 0, 0), yaw)
	elif wall.contains("Door_Flat"):
		put("Door_1_Flat", root, pos + rot_y(yaw) * Vector3(-0.53, 0, 0), yaw)


# A house. spec keys:
#  w, d: footprint in modules (2 m). floors: 1..3. style: "plaster" | "brick" | "wood" (ground floor material).
#  ridge: "z" (gable faces the street) or "x" (eaves face the street). door: slot index on the front wall.
#  chimney: bool. balcony: bool (on the upper floor front). seed: int.
# Returns the collision footprint size (Vector3).
func house(root: Transform3D, spec: Dictionary) -> Vector3:
	var w: int = spec.get("w", 3)
	var d: int = spec.get("d", 4)
	var floors: int = spec.get("floors", 1)
	var style: String = spec.get("style", "plaster")
	var ridge: String = spec.get("ridge", "z")
	var door: int = spec.get("door", w / 2)
	rng.seed = int(spec.get("seed", 1))
	var W: float = w * 2.0
	var D: float = d * 2.0
	for f in floors:
		var y: float = f * H
		var ground: bool = f == 0
		var st: String = style if ground else "plaster"
		# four sides: front(+z), back(-z), right(+x), left(-x)
		var sides: Array = [
			[Vector3(0, y, D * 0.5), 0.0, w, true],
			[Vector3(0, y, -D * 0.5), PI, w, false],
			[Vector3(W * 0.5, y, 0), PI * 0.5, d, false],
			[Vector3(-W * 0.5, y, 0), -PI * 0.5, d, false],
		]
		for s in sides:
			var n: int = s[2]
			var kinds: Array = []
			for i in n:
				kinds.append(_pick_wall(st, ground, bool(s[3]) and ground and i == door, i, n))
			wall_side(root, s[0], s[1], n, kinds)
			var dir: Vector3 = rot_y(s[1]) * Vector3.RIGHT
			for i in n:
				var off: float = (float(i) - float(n - 1) * 0.5) * 2.0
				_insert(root, (s[0] as Vector3) + dir * off, s[1], kinds[i], rng.randf() < 0.6)
		# corner posts
		var post: String = "Corner_Exterior_Brick" if st == "brick" else "Corner_Exterior_Wood"
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				put(post, root, Vector3(cx * W * 0.5, y, cz * D * 0.5), atan2(cx, cz))
		if f > 0:
			# floor trim between storeys
			for s in sides:
				var dir2: Vector3 = rot_y(s[1]) * Vector3.RIGHT
				for i in int(s[2]):
					var off2: float = (float(i) - float(int(s[2]) - 1) * 0.5) * 2.0
					put("Wall_BottomCover", root, (s[0] as Vector3) + dir2 * off2, s[1])
	var top: float = floors * H
	_roof(root, w, d, top, ridge)
	if spec.get("balcony", false) and floors >= 2:
		for i in w:
			var off3: float = (float(i) - float(w - 1) * 0.5) * 2.0
			put("Balcony_Simple_Straight", root, Vector3(off3, H, D * 0.5), 0.0)
			put("Floor_WoodDark", root, Vector3(off3, H + 0.02, D * 0.5 + 0.2), 0.0)
		for i in w + 1:
			var off4: float = (float(i) - float(w) * 0.5) * 2.0
			put("Prop_Support", root, Vector3(off4, 0.0, D * 0.5), 0.0)
	if spec.get("chimney", true):
		var cx2: float = (W * 0.5 - 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		put("Prop_Chimney", root, Vector3(cx2, top - 0.2, -D * 0.25), 0.0)
	# stone footing that hides the seam with the ground
	return Vector3(W, top + 2.0, D)


func _pick_wall(style: String, ground: bool, is_door: bool, i: int, n: int) -> String:
	if style == "brick":
		if is_door:
			return "Wall_UnevenBrick_Door_Round"
		var r: float = rng.randf()
		if r < 0.35:
			return "Wall_UnevenBrick_Window_Wide_Round"
		if r < 0.5:
			return "Wall_UnevenBrick_Window_Thin_Round"
		return "Wall_UnevenBrick_Straight"
	if is_door:
		return "Wall_Plaster_Door_Round" if rng.randf() < 0.5 else "Wall_Plaster_Door_Flat"
	var r2: float = rng.randf()
	if style == "wood" or (not ground and r2 < 0.25):
		if r2 < 0.45:
			return "Wall_Plaster_WoodGrid"
	if r2 < 0.35:
		return "Wall_Plaster_Window_Wide_Round"
	if r2 < 0.5:
		return "Wall_Plaster_Window_Thin_Round"
	if r2 < 0.6:
		return "Wall_Plaster_Window_Wide_Flat"
	if ground and r2 < 0.8:
		return "Wall_Plaster_Straight_Base"
	return "Wall_Plaster_Straight"


const ROOFS: Array[String] = ["4x4", "4x6", "4x8", "6x4", "6x6", "6x8", "6x10", "6x12", "6x14", "8x8", "8x10", "8x12", "8x14"]


func _roof(root: Transform3D, w: int, d: int, top: float, ridge: String) -> void:
	var W: int = w * 2
	var D: int = d * 2
	var yaw: float = 0.0
	var rw: int = W
	var rd: int = D
	if ridge == "x":
		yaw = PI * 0.5
		rw = D
		rd = W
	var key: String = "%dx%d" % [rw, rd]
	if not ROOFS.has(key):
		push_warning("MapBuildings: no roof " + key)
		return
	put("Roof_RoundTiles_" + key, root, Vector3(0, top, 0), yaw)
	var gable: String = "Roof_Front_Brick%d" % rw
	var half: float = rd * 0.5
	var dir: Vector3 = rot_y(yaw) * Vector3.BACK
	put(gable, root, Vector3(0, top, 0) + dir * half, yaw)
	put(gable, root, Vector3(0, top, 0) - dir * half, yaw + PI)


# A square tower of w x w modules, `floors` storeys of uneven brick. ruined: the top storey keeps only some walls
# and there is no roof. Otherwise a conical tile roof (scaled to the tower).
func tower(root: Transform3D, w: int, floors: int, ruined: bool, door: bool) -> Vector3:
	var W: float = w * 2.0
	for f in floors:
		var y: float = f * H
		var top_storey: bool = f == floors - 1
		var sides: Array = [
			[Vector3(0, y, W * 0.5), 0.0], [Vector3(0, y, -W * 0.5), PI],
			[Vector3(W * 0.5, y, 0), PI * 0.5], [Vector3(-W * 0.5, y, 0), -PI * 0.5]]
		for si in sides.size():
			var s: Array = sides[si]
			var kinds: Array = []
			for i in w:
				var nm: String = "Wall_UnevenBrick_Straight"
				if f == 0 and si == 0 and door and i == w / 2:
					nm = "Wall_UnevenBrick_Door_Round"
				elif f > 0 and (i + f + si) % 3 == 0:
					nm = "Wall_UnevenBrick_Window_Thin_Round"
				if ruined and top_storey and (si >= 2 or (si == 1 and i > 0)):
					nm = ""
				kinds.append(nm)
			var dir: Vector3 = rot_y(s[1]) * Vector3.RIGHT
			for i in w:
				if kinds[i] == "":
					continue
				var off: float = (float(i) - float(w - 1) * 0.5) * 2.0
				put(kinds[i], root, (s[0] as Vector3) + dir * off, s[1])
				if (kinds[i] as String).contains("Window"):
					put("Window_Thin_Round1", root, (s[0] as Vector3) + dir * off, s[1])
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				if ruined and top_storey and cx > 0.0:
					continue
				put("Corner_Exterior_Brick", root, Vector3(cx * W * 0.5, y, cz * W * 0.5), atan2(cx, cz))
		if f > 0:
			for s2 in sides:
				var dir2: Vector3 = rot_y(s2[1]) * Vector3.RIGHT
				for i in w:
					var off2: float = (float(i) - float(w - 1) * 0.5) * 2.0
					put("Wall_BottomCover", root, (s2[0] as Vector3) + dir2 * off2, s2[1])
	var top: float = floors * H
	if not ruined:
		put("Roof_Tower_RoundTiles", root, Vector3(0, top, 0), 0.0, W / 4.6)
	return Vector3(W, top, W)


# A straight curtain wall between two local points, `floors` high, outside facing `side` (+1 = left of a->b).
func wall_line(root: Transform3D, a: Vector3, bpt: Vector3, floors: int, side: float) -> void:
	var v: Vector3 = bpt - a
	var L: float = Vector2(v.x, v.z).length()
	var n: int = maxi(1, int(round(L / 2.0)))
	var dir: Vector3 = Vector3(v.x, 0, v.z).normalized()
	# yaw whose local +X maps to dir; outward normal then is rot_y(yaw)*+Z
	var yaw: float = atan2(-dir.z, dir.x)
	if side < 0.0:
		yaw += PI
	for f in floors:
		for i in n:
			var p: Vector3 = a + dir * ((float(i) + 0.5) * L / n)
			p.y = a.y + f * H
			var nm: String = "Wall_UnevenBrick_Straight"
			if f == floors - 1 and i % 4 == 2:
				nm = "Wall_UnevenBrick_Window_Thin_Round"
			put(nm, root, p, yaw)
			if f > 0:
				put("Wall_BottomCover", root, p, yaw)
