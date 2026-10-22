# PROTOTYPE - NOT FOR PRODUCTION
# Map module: the authored heightfield of the Vale de Lume.
# Shapes are explicit (valley tilt, village rise, castle plateau with a south cliff, mine spur, watchtower hill,
# quarry hill, lake bowl, border mountains) and gentle noise only adds small undulation.
# Then the river spline is carved, roads are levelled into the slope, and building pads are flattened.
# Grid: 321 x 321 samples, 2 m apart, covering x,z in -320..320 (play area is about -300..300).
extends RefCounted

const N: int = 321
const STEP: float = 2.0
const HALF: float = 320.0
const LAKE_Y: float = 1.0
const LAKE_C: Vector2 = Vector2(30, 224)
const LAKE_R: Vector2 = Vector2(88, 54)

var h: PackedFloat32Array
var river_d: PackedFloat32Array      # distance (m) to the river centre line, per grid sample
var river_l: PackedFloat32Array      # river water level at the nearest river sample
var river_w: PackedFloat32Array      # half width there
var road_d: PackedFloat32Array       # distance to the nearest road (m)

var river_pts: PackedVector3Array    # resampled centre line, y = water level
var river_hw: PackedFloat32Array     # half width per sample
var roads: Array = []                # [{id, hw, pts: PackedVector3Array (y = road height), bridge: Array[bool]}]

var n_big: FastNoiseLite
var n_small: FastNoiseLite
var n_ridge: FastNoiseLite
var n_edge: FastNoiseLite


func _init() -> void:
	n_big = _noise(11, 0.007, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	n_small = _noise(12, 0.045, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	n_ridge = _noise(13, 0.012, FastNoiseLite.TYPE_SIMPLEX, 4)
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_edge = _noise(14, 0.03, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)


func _noise(s: int, f: float, t: int, oct: int) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = s
	n.frequency = f
	n.noise_type = t
	n.fractal_octaves = oct
	return n


static func sstep(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func gauss(x: float, z: float, cx: float, cz: float, s: float) -> float:
	var dx: float = x - cx
	var dz: float = z - cz
	return exp(-(dx * dx + dz * dz) / (2.0 * s * s))


# ------------------------------------------------------------------ authored shapes
func base(x: float, z: float) -> float:
	# valley floor: tilts down to the lake in the south, rises gently to the east and west flanks
	var v: float = 6.0 - 0.022 * z + 0.00005 * x * x
	v += n_big.get_noise_2d(x, z) * 2.2 + n_small.get_noise_2d(x, z) * 0.3
	# Brasalume sits on a low rise above the river
	v += 3.0 * gauss(x, z, 0, -20, 70)
	# authored hills: watchtower hill (east), two grazing knolls, quarry hill (south-west)
	v += 22.0 * gauss(x, z, 186, -46, 36)
	v += 7.0 * gauss(x, z, 95, -112, 30)
	v += 5.0 * gauss(x, z, -40, -125, 32)
	v += 6.0 * gauss(x, z, 160, 150, 38)
	v += 4.0 * gauss(x, z, -150, -20, 30)
	v += 24.0 * gauss(x, z, -228, 172, 34)
	# watchtower hilltop is levelled where the old tower stands
	var tw: float = 1.0 - sstep(8.0, 16.0, Vector2(x - 186, z + 46).length())
	if tw > 0.0:
		v = lerpf(v, 6.0 - 0.022 * -46.0 + 0.00005 * 186.0 * 186.0 + 21.0, tw)
	# quarry: a pit cut into the quarry hill, open to the east (where the trail comes in)
	var q: Vector2 = Vector2((x + 214.0) / 26.0, (z - 166.0) / 20.0)
	if q.x > 0.0:
		q.x *= 0.45
	var qm: float = 1.0 - sstep(0.85, 1.05, q.length() + n_edge.get_noise_2d(x, z) * 0.06)
	if qm > 0.0:
		v = lerpf(v, 4.2 + 0.4 * n_small.get_noise_2d(x * 3.0, z * 3.0), qm)
	v = _plateau_castle(x, z, v)
	v = _spur_mine(x, z, v)
	v = _mountains(x, z, v)
	return v


# Castle of Vigília: a rock table 40 m above the valley. Sheer cliff to the south and west (the village sees it),
# a long sloping spur to the east that carries the road.
func _plateau_castle(x: float, z: float, v: float) -> float:
	var dx: float = x - 8.0
	var dz: float = z + 214.0
	if dz < 0.0:
		dz *= 0.25          # merges into the northern mountains
	var r: float = Vector2(dx, dz / 0.82).length()
	var R: float = 44.0 + n_edge.get_noise_2d(x, z) * 5.0
	var dir: Vector2 = Vector2(dx, dz).normalized()
	var w: float = 7.0 + 95.0 * sstep(0.25, 0.95, dir.x)
	var m: float = 1.0 - sstep(0.0, w, r - R)
	var top: float = 42.0 + n_small.get_noise_2d(x, z) * 0.4
	if m <= 0.0:
		return v
	return maxf(v, lerpf(v, top, pow(m, 0.8)))


# The mine spur: a ridge running north-east, its south face a rock wall where the mine mouth opens.
func _spur_mine(x: float, z: float, v: float) -> float:
	var a: Vector2 = Vector2(176, -214)
	var bb: Vector2 = Vector2(290, -262)
	var p: Vector2 = Vector2(x, z)
	var ab: Vector2 = bb - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var d: float = p.distance_to(a + ab * t)
	var R: float = 22.0 + n_edge.get_noise_2d(x, z) * 4.0
	var w: float = 9.0
	if x < a.x:
		w = 30.0
	var m: float = 1.0 - sstep(0.0, w, d - R)
	if m <= 0.0:
		return v
	return maxf(v, lerpf(v, 40.0 + t * 25.0 + n_ridge.get_noise_2d(x, z) * 5.0, m))


# The border: the body of the Lumeira turned to stone, highest in the north.
func _mountains(x: float, z: float, v: float) -> float:
	var ex: float = absf(x) / 300.0
	var ez: float = absf(z) / 300.0
	var e: float = pow(pow(ex, 5.0) + pow(ez, 5.0), 0.2)
	e += n_edge.get_noise_2d(x * 0.5, z * 0.5) * 0.05
	var foot: float = sstep(0.68, 0.9, e) * 7.0
	var m: float = sstep(0.83, 1.0, e)
	if m <= 0.0:
		return v + foot
	var north: float = 1.0 + 0.45 * sstep(50.0, -150.0, z)
	var broad: float = n_big.get_noise_2d(x * 1.7 + 400.0, z * 1.7) * 0.5 + 0.5
	var crag: float = n_ridge.get_noise_2d(x, z) * 0.5 + 0.5
	var peak: float = (26.0 + 34.0 * broad + 9.0 * crag) * north
	return v + foot + pow(m, 1.35) * peak


# ------------------------------------------------------------------ build
# river_ctrl: control points (x, _, z) from source to lake; road_defs: [{id, hw, pts: Array[Vector2]}]
# pads: [{c: Vector2, size: Vector2, yaw: float, y: float (NAN = auto)}]
func generate(river_ctrl: Array, road_defs: Array, pads: Array) -> void:
	h = PackedFloat32Array()
	h.resize(N * N)
	for j in N:
		var z: float = -HALF + j * STEP
		for i in N:
			h[j * N + i] = base(-HALF + i * STEP, z)
	_carve_lake()
	_river(river_ctrl)
	_roads(road_defs)
	_pads(pads)
	_smooth_cells(1)
	for tr in trenches:
		_trench(tr)


# Trenches cut into the rock after everything else (the mine gallery): {pts: Array[Vector2], hw: float, y0: float, y1: float}
var trenches: Array = []


func _trench(tr: Dictionary) -> void:
	var pts: Array = tr.pts
	var hw: float = tr.hw
	var y0: float = tr.y0
	if is_nan(y0):
		y0 = sample((pts[0] as Vector2).x, (pts[0] as Vector2).y)
		tr.y0 = y0
	var y1: float = y0 + float(tr.rise)
	var total: float = 0.0
	for k in pts.size() - 1:
		total += (pts[k] as Vector2).distance_to(pts[k + 1])
	var acc: float = 0.0
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var L: float = a.distance_to(b)
		var steps: int = int(ceil(L / 1.0))
		for s in steps + 1:
			var p: Vector2 = a.lerp(b, float(s) / steps)
			var fl: float = lerpf(y0, y1, (acc + L * float(s) / steps) / total)
			var R: float = hw + 4.0
			for j in range(maxi(0, int((p.y - R + HALF) / STEP)), mini(N - 1, int((p.y + R + HALF) / STEP) + 1) + 1):
				for i in range(maxi(0, int((p.x - R + HALF) / STEP)), mini(N - 1, int((p.x + R + HALF) / STEP) + 1) + 1):
					var d: float = Vector2(-HALF + i * STEP - p.x, -HALF + j * STEP - p.y).length()
					var idx: int = j * N + i
					var target: float = fl + maxf(0.0, d - hw) * 4.0
					if target < h[idx]:
						h[idx] = target
		acc += L


static func catmull(pts: Array, step: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for k in pts.size() - 1:
		var p0: Vector3 = pts[maxi(k - 1, 0)]
		var p1: Vector3 = pts[k]
		var p2: Vector3 = pts[k + 1]
		var p3: Vector3 = pts[mini(k + 2, pts.size() - 1)]
		var seg: int = maxi(2, int(ceil(p1.distance_to(p2) / step)))
		for s in seg:
			var t: float = float(s) / seg
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _carve_lake() -> void:
	for j in N:
		var z: float = -HALF + j * STEP
		for i in N:
			var x: float = -HALF + i * STEP
			var d: float = lake_norm(x, z)
			if d > 1.5:
				continue
			var k: int = j * N + i
			var floor_y: float = LAKE_Y - 0.4 - 4.2 * sstep(0.98, 0.45, d)
			var shore: float = maxf(h[k], LAKE_Y + 0.45 + (d - 1.0) * 6.0)
			var target: float = floor_y if d < 1.0 else shore
			h[k] = lerpf(target, h[k], sstep(1.1, 1.5, d))


func lake_norm(x: float, z: float) -> float:
	var q: Vector2 = Vector2((x - LAKE_C.x) / LAKE_R.x, (z - LAKE_C.y) / LAKE_R.y)
	return q.length() + n_edge.get_noise_2d(x * 1.5, z * 1.5) * 0.06


func _river(ctrl: Array) -> void:
	river_pts = catmull(ctrl, 2.0)
	var n: int = river_pts.size()
	river_hw = PackedFloat32Array()
	river_hw.resize(n)
	var prev: float = 1e9
	for k in n:
		var p: Vector3 = river_pts[k]
		var lv: float = minf(minf(sample(p.x, p.z) - 1.3, prev - 0.01), 24.0)
		prev = lv
		river_pts[k] = Vector3(p.x, maxf(lv, LAKE_Y), p.z)
		river_hw[k] = lerpf(3.6, 6.5, float(k) / n)
	# smooth levels (keeps it monotone: average of monotone sequence stays monotone)
	for pass_i in 4:
		var c: PackedVector3Array = river_pts.duplicate()
		for k in range(2, n - 2):
			var y: float = (c[k - 2].y + c[k - 1].y + c[k].y + c[k + 1].y + c[k + 2].y) / 5.0
			river_pts[k] = Vector3(c[k].x, y, c[k].z)
	river_d = _filled(1e9)
	river_l = _filled(0.0)
	river_w = _filled(1.0)
	for k in n:
		var p: Vector3 = river_pts[k]
		var R: float = river_hw[k] + 16.0
		_stamp_dist(p, R, k, river_d, true)
	for idx in N * N:
		var d: float = river_d[idx]
		if d > 1e8:
			continue
		var L: float = river_l[idx]
		var W: float = river_w[idx]
		var target: float
		if d < W:
			var u: float = d / W
			target = L - 0.25 - 1.7 * (1.0 - u * u)
		else:
			target = L + 0.35 + (d - W) * 0.22
		h[idx] = lerpf(target, h[idx], sstep(W + 3.0, W + 16.0, d))


func _filled(v: float) -> PackedFloat32Array:
	var a: PackedFloat32Array = PackedFloat32Array()
	a.resize(N * N)
	a.fill(v)
	return a


# Writes min distance from p into dist (grid), and when it wins, the river level / half width of sample k.
func _stamp_dist(p: Vector3, R: float, k: int, dist: PackedFloat32Array, is_river: bool) -> void:
	var i0: int = maxi(0, int((p.x - R + HALF) / STEP))
	var i1: int = mini(N - 1, int((p.x + R + HALF) / STEP) + 1)
	var j0: int = maxi(0, int((p.z - R + HALF) / STEP))
	var j1: int = mini(N - 1, int((p.z + R + HALF) / STEP) + 1)
	for j in range(j0, j1 + 1):
		var z: float = -HALF + j * STEP
		for i in range(i0, i1 + 1):
			var x: float = -HALF + i * STEP
			var d: float = Vector2(x - p.x, z - p.z).length()
			var idx: int = j * N + i
			if d < dist[idx]:
				dist[idx] = d
				if is_river:
					river_l[idx] = p.y
					river_w[idx] = river_hw[k]
				else:
					river_l[idx] = river_l[idx]


func _roads(defs: Array) -> void:
	road_d = _filled(1e9)
	var road_y: PackedFloat32Array = _filled(0.0)
	var road_w: PackedFloat32Array = _filled(1.0)
	roads.clear()
	for def in defs:
		var ctrl: Array = []
		for p2 in def.pts:
			var v2: Vector2 = p2
			ctrl.append(Vector3(v2.x, 0, v2.y))
		var pts: PackedVector3Array = catmull(ctrl, 2.0)
		var n: int = pts.size()
		var bridge: Array = []
		for k in n:
			var p: Vector3 = pts[k]
			var rd: float = river_dist(p.x, p.z)
			bridge.append(rd < 9.5)
			pts[k] = Vector3(p.x, sample(p.x, p.z), p.z)
		# smooth the road profile so it reads as a laid road, not the raw ground
		for pass_i in 4:
			var c: PackedVector3Array = pts.duplicate()
			for k in range(1, n - 1):
				var a: int = maxi(0, k - 4)
				var b2: int = mini(n - 1, k + 4)
				var s: float = 0.0
				for m in range(a, b2 + 1):
					s += c[m].y
				pts[k] = Vector3(c[k].x, s / (b2 - a + 1), c[k].z)
		# bridge deck: flat at the height of the higher bank
		var deck: float = -1e9
		for k in n:
			if bridge[k]:
				for m in [k - 6, k + 6]:
					if m >= 0 and m < n and not bridge[m]:
						deck = maxf(deck, pts[m].y)
		for k in n:
			if bridge[k] and deck > -1e8:
				pts[k] = Vector3(pts[k].x, deck, pts[k].z)
		var hw: float = def.hw
		roads.append({"id": def.id, "hw": hw, "pts": pts, "bridge": bridge})
		for k in n:
			if bridge[k]:
				continue
			var p: Vector3 = pts[k]
			var R: float = hw + 7.0
			var i0: int = maxi(0, int((p.x - R + HALF) / STEP))
			var i1: int = mini(N - 1, int((p.x + R + HALF) / STEP) + 1)
			var j0: int = maxi(0, int((p.z - R + HALF) / STEP))
			var j1: int = mini(N - 1, int((p.z + R + HALF) / STEP) + 1)
			for j in range(j0, j1 + 1):
				var z: float = -HALF + j * STEP
				for i in range(i0, i1 + 1):
					var x: float = -HALF + i * STEP
					var d: float = Vector2(x - p.x, z - p.z).length()
					var idx: int = j * N + i
					if d < road_d[idx]:
						road_d[idx] = d
						road_y[idx] = p.y
						road_w[idx] = hw
	for idx in N * N:
		var d: float = road_d[idx]
		if d > 1e8:
			continue
		if river_d[idx] < river_w[idx] + 2.0:
			continue
		var t: float = sstep(road_w[idx] + 0.5, road_w[idx] + 7.0, d)
		h[idx] = lerpf(road_y[idx] - 0.06, h[idx], t)


func _pads(pads: Array) -> void:
	for pad in pads:
		var c: Vector2 = pad.c
		var size: Vector2 = pad.size
		var yaw: float = pad.yaw
		var y: float = pad.y
		if is_nan(y):
			y = sample(c.x, c.y)
			pad.y = y
		var fall: float = float(pad.get("fall", 4.5))
		var R: float = size.length() * 0.5 + fall + 0.5
		var ca: float = cos(yaw)
		var sa: float = sin(yaw)
		var i0: int = maxi(0, int((c.x - R + HALF) / STEP))
		var i1: int = mini(N - 1, int((c.x + R + HALF) / STEP) + 1)
		var j0: int = maxi(0, int((c.y - R + HALF) / STEP))
		var j1: int = mini(N - 1, int((c.y + R + HALF) / STEP) + 1)
		for j in range(j0, j1 + 1):
			var z: float = -HALF + j * STEP - c.y
			for i in range(i0, i1 + 1):
				var x: float = -HALF + i * STEP - c.x
				# into pad space (yaw rotates +z toward +x)
				var lx: float = x * ca - z * sa
				var lz: float = x * sa + z * ca
				var ex: float = maxf(absf(lx) - size.x * 0.5, 0.0)
				var ez: float = maxf(absf(lz) - size.y * 0.5, 0.0)
				var d: float = Vector2(ex, ez).length()
				var t: float = sstep(0.6, fall, d)
				var idx: int = j * N + i
				h[idx] = lerpf(y - 0.05, h[idx], t)


func _smooth_cells(passes: int) -> void:
	# light blur only where the ground was not shaped by cliffs (keeps cliffs sharp)
	for p in passes:
		var c: PackedFloat32Array = h.duplicate()
		for j in range(1, N - 1):
			for i in range(1, N - 1):
				var k: int = j * N + i
				var avg: float = (c[k - 1] + c[k + 1] + c[k - N] + c[k + N]) * 0.25
				if absf(avg - c[k]) < 0.6:
					h[k] = lerpf(c[k], avg, 0.5)


# ------------------------------------------------------------------ queries
func sample(x: float, z: float) -> float:
	var fx: float = clampf((x + HALF) / STEP, 0.0, N - 1.001)
	var fz: float = clampf((z + HALF) / STEP, 0.0, N - 1.001)
	var i: int = int(fx)
	var j: int = int(fz)
	var tx: float = fx - i
	var tz: float = fz - j
	var k: int = j * N + i
	var h00: float = h[k]
	var h10: float = h[k + 1]
	var h01: float = h[k + N]
	var h11: float = h[k + N + 1]
	# same diagonal as the render mesh (00 -> 11)
	if tx > tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func river_dist(x: float, z: float) -> float:
	var fx: int = clampi(int(round((x + HALF) / STEP)), 0, N - 1)
	var fz: int = clampi(int(round((z + HALF) / STEP)), 0, N - 1)
	if river_d.is_empty():
		return 1e9
	return river_d[fz * N + fx]


func cell(x: float, z: float, arr: PackedFloat32Array) -> float:
	var fx: int = clampi(int(round((x + HALF) / STEP)), 0, N - 1)
	var fz: int = clampi(int(round((z + HALF) / STEP)), 0, N - 1)
	return arr[fz * N + fx]


func normal_at(x: float, z: float) -> Vector3:
	var e: float = STEP
	return Vector3(sample(x - e, z) - sample(x + e, z), 2.0 * e, sample(x, z - e) - sample(x, z + e)).normalized()


# Nearest point on the river centre line: [index, Vector3 point]
func river_nearest(x: float, z: float) -> Array:
	var best: float = 1e9
	var bi: int = 0
	for k in river_pts.size():
		var p: Vector3 = river_pts[k]
		var d: float = (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
		if d < best:
			best = d
			bi = k
	return [bi, river_pts[bi]]


# ------------------------------------------------------------------ mesh + collision
func build_nodes(parent: Node3D, mat: Material) -> void:
	var CH: int = 64                    # quads per chunk side
	var chunks: int = (N - 1) / CH
	for cj in chunks:
		for ci in chunks:
			parent.add_child(_chunk(ci * CH, cj * CH, CH, mat))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	var data: PackedFloat32Array = h.duplicate()
	for k in data.size():
		data[k] = data[k] / STEP
	shape.map_data = data
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * STEP
	body.add_child(cs)
	parent.add_child(body)


func _chunk(i0: int, j0: int, CH: int, mat: Material) -> MeshInstance3D:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var V: int = CH + 1
	for j in V:
		for i in V:
			var gi: int = i0 + i
			var gj: int = j0 + j
			var x: float = -HALF + gi * STEP
			var z: float = -HALF + gj * STEP
			verts.append(Vector3(x, h[gj * N + gi], z))
			var hl: float = h[gj * N + maxi(gi - 1, 0)]
			var hr: float = h[gj * N + mini(gi + 1, N - 1)]
			var hd: float = h[maxi(gj - 1, 0) * N + gi]
			var hu: float = h[mini(gj + 1, N - 1) * N + gi]
			var nrm: Vector3 = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
			norms.append(nrm)
			var t: Vector3 = Vector3(1, 0, 0) - nrm * nrm.x
			t = t.normalized()
			tangents.append_array([t.x, t.y, t.z, 1.0])
			uvs.append(Vector2((x + HALF) / (2.0 * HALF), (z + HALF) / (2.0 * HALF)))
	for j in CH:
		for i in CH:
			var a: int = j * V + i
			var b2: int = a + 1
			var c: int = a + V
			var d: int = c + 1
			# diagonal a-d, matches sample()
			idx.append_array([a, b2, d, a, d, c])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tangents
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Ground_%d_%d" % [i0, j0]
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
