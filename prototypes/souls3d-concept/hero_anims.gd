# PROTOTYPE - NOT FOR PRODUCTION
# Hand-made combat animations for the Mixamo hero. A key pose says where each hand goes (two-bone IK),
# where the blade points, and how hips, spine, head and legs turn (degrees, character axes:
# +X = hero's left, +Y = up, +Z = forward). The base stance is frame 0 of the "idle" clip.
# add_to() bakes every entry of MOVES into the AnimationLibrary next to the Mixamo clips.
extends RefCounted

const B := "mixamorig_"

# key fields: t (s), spin (whole-body yaw deg, hand targets turn with it), hips (offset m), hips_rot, spine (split over 3 bones), head, rleg/lleg, rknee/lknee (deg),
# rh/lh (hand target, model space m), relbow/lelbow (direction the elbow points), blade (sword direction)
const GUARD_L := Vector3(0.12, 1.12, 0.32)  # shield up in front of the chest
const GRIP_R := Vector3(-0.35, 1.0, 0.15)  # sword hand at rest, blade forward and up
const SHIELD := Vector3(1, -1, 0)  # shield elbow points out and down
const REST := {"rh": GRIP_R, "blade": Vector3(0, 0.5, 1), "lh": GUARD_L, "lelbow": SHIELD}
const STANCE := {"lleg": Vector3(-35, 0, 0), "lknee": Vector3(40, 0, 0), "rleg": Vector3(20, 0, 0)}

# hit = the key where the blade crosses the target; main.gd MOVES uses the same times
static var MOVES := {
	# combo 1: forehand diagonal, right shoulder down to the left hip
	"x_slash1": {"length": 0.95, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.26, "hips": Vector3(0, -0.05, 0), "hips_rot": Vector3(0, -15, 0), "spine": Vector3(-5, -35, 0),
			"lleg": Vector3(-25, 0, 0), "lknee": Vector3(35, 0, 0), "rleg": Vector3(15, 0, 0),
			"rh": Vector3(-0.45, 1.7, -0.15), "relbow": Vector3(-1, 0.3, 0), "blade": Vector3(-0.3, 0.6, -1), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.4, "hips": Vector3(0, -0.1, 0.12), "hips_rot": Vector3(0, 20, 0), "spine": Vector3(10, 30, 0),
			"rh": Vector3(0.05, 1.15, 0.7), "relbow": Vector3(0, -1, -0.3), "blade": Vector3(0.7, -0.5, 0.5),
			"lh": GUARD_L + Vector3(0.1, -0.1, -0.1), "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.56, "hips": Vector3(0, -0.1, 0.15), "hips_rot": Vector3(0, 25, 0), "spine": Vector3(15, 45, 0),
			"rh": Vector3(0.35, 0.85, 0.35), "relbow": Vector3(-0.3, -1, 0), "blade": Vector3(0.6, -0.6, -0.3),
			"lh": GUARD_L + Vector3(0.15, -0.15, -0.15), "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.95}.merged(REST),
	]},
	# combo 2: backhand rising, left hip up to the right shoulder
	"x_slash2": {"length": 0.9, "keys": [
		{"t": 0.0, "hips_rot": Vector3(0, 25, 0), "spine": Vector3(15, 45, 0), "rh": Vector3(0.35, 0.85, 0.35),
			"relbow": Vector3(-0.3, -1, 0), "blade": Vector3(0.6, -0.6, -0.3), "lh": GUARD_L, "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.2, "hips_rot": Vector3(0, 28, 0), "spine": Vector3(8, 40, 0), "rh": Vector3(0.3, 0.9, 0.3),
			"relbow": Vector3(0, -1, 0), "blade": Vector3(0.7, -0.3, -0.5), "lh": GUARD_L, "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.36, "hips": Vector3(0, -0.06, 0.12), "hips_rot": Vector3(0, -15, 0), "spine": Vector3(0, -30, 0),
			"rh": Vector3(-0.25, 1.35, 0.65), "relbow": Vector3(-0.5, -1, 0), "blade": Vector3(-0.6, 0.5, 0.6),
			"lh": GUARD_L + Vector3(0.05, 0, -0.1), "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.5, "hips_rot": Vector3(0, -22, 0), "spine": Vector3(-5, -45, 0), "rh": Vector3(-0.55, 1.65, 0.1),
			"relbow": Vector3(-1, -0.2, 0), "blade": Vector3(-0.4, 0.8, -0.4), "lh": GUARD_L, "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.9}.merged(REST),
	]},
	# combo 3: overhead vertical chop
	"x_slash3": {"length": 1.05, "keys": [
		{"t": 0.0, "hips_rot": Vector3(0, -22, 0), "spine": Vector3(-5, -45, 0), "rh": Vector3(-0.55, 1.65, 0.1),
			"relbow": Vector3(-1, -0.2, 0), "blade": Vector3(-0.4, 0.8, -0.4), "lh": GUARD_L, "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.28, "spine": Vector3(-15, -10, 0), "rh": Vector3(-0.15, 1.9, -0.05), "relbow": Vector3(-1, 0.5, 0),
			"blade": Vector3(0, 0.3, -1), "lh": GUARD_L + Vector3(0, 0.1, 0), "lelbow": SHIELD},
		{"t": 0.42, "hips": Vector3(0, -0.15, 0.15), "spine": Vector3(25, 0, 0), "rh": Vector3(-0.05, 1.05, 0.72),
			"relbow": Vector3(-0.5, -1, 0), "blade": Vector3(0, -0.4, 1), "lh": GUARD_L + Vector3(0.1, -0.1, -0.1), "lelbow": SHIELD,
			"lleg": Vector3(-40, 0, 0), "lknee": Vector3(45, 0, 0), "rleg": Vector3(25, 0, 0)},
		{"t": 0.58, "hips": Vector3(0, -0.17, 0.15), "spine": Vector3(30, 0, 0), "rh": Vector3(-0.05, 0.78, 0.6),
			"relbow": Vector3(-0.5, -1, 0), "blade": Vector3(0, -0.9, 0.4), "lh": GUARD_L + Vector3(0.1, -0.1, -0.1), "lelbow": SHIELD,
			"lleg": Vector3(-40, 0, 0), "lknee": Vector3(45, 0, 0), "rleg": Vector3(25, 0, 0)},
		{"t": 1.05}.merged(REST),
	]},
	# combo 4: cocked thrust with a long lunge
	"x_thrust": {"length": 1.25, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.32, "hips_rot": Vector3(0, -20, 0), "spine": Vector3(-5, -30, 0), "rh": Vector3(-0.35, 1.25, -0.25),
			"relbow": Vector3(-1, -0.5, 0), "blade": Vector3(0, 0.05, 1), "lh": GUARD_L + Vector3(0, 0, 0.1), "lelbow": SHIELD},
		{"t": 0.48, "hips": Vector3(0, -0.12, 0.3), "hips_rot": Vector3(0, 15, 0), "spine": Vector3(15, 15, 0),
			"rh": Vector3(-0.05, 1.25, 0.9), "relbow": Vector3(-0.3, -1, -0.5), "blade": Vector3(0, 0, 1),
			"lh": GUARD_L + Vector3(0.1, -0.15, -0.2), "lelbow": SHIELD, "lleg": Vector3(-45, 0, 0), "lknee": Vector3(40, 0, 0), "rleg": Vector3(30, 0, 0)},
		{"t": 0.72, "hips": Vector3(0, -0.12, 0.3), "hips_rot": Vector3(0, 15, 0), "spine": Vector3(15, 15, 0),
			"rh": Vector3(-0.05, 1.2, 0.85), "relbow": Vector3(-0.3, -1, -0.5), "blade": Vector3(0, -0.05, 1),
			"lh": GUARD_L + Vector3(0.1, -0.15, -0.2), "lelbow": SHIELD, "lleg": Vector3(-45, 0, 0), "lknee": Vector3(40, 0, 0), "rleg": Vector3(30, 0, 0)},
		{"t": 1.25}.merged(REST),
	]},
	# combo 5: full spinning cut (spin = whole-body yaw, the hand targets turn with it)
	"x_spin": {"length": 1.25, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.18, "spin": 30, "hips": Vector3(0, -0.08, 0), "rh": Vector3(0.2, 1.1, 0.4), "relbow": Vector3(0, -1, 0),
			"blade": Vector3(0.8, 0, 0.3), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.32, "spin": -60, "hips": Vector3(0, -0.1, 0), "rh": Vector3(-0.72, 1.15, 0.25), "relbow": Vector3(0, -1, -0.5),
			"blade": Vector3(-1, 0, 0.2), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.46, "spin": -150, "hips": Vector3(0, -0.1, 0), "rh": Vector3(-0.72, 1.15, 0.25), "relbow": Vector3(0, -1, -0.5),
			"blade": Vector3(-1, 0, 0.2), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.6, "spin": -240, "hips": Vector3(0, -0.1, 0), "rh": Vector3(-0.72, 1.15, 0.25), "relbow": Vector3(0, -1, -0.5),
			"blade": Vector3(-1, 0, 0.2), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.76, "spin": -330, "hips": Vector3(0, -0.08, 0), "rh": Vector3(-0.6, 1.1, 0.3), "relbow": Vector3(0, -1, -0.5),
			"blade": Vector3(-0.8, -0.2, 0.5), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.92, "spin": -360}.merged(REST),
		{"t": 1.25, "spin": -360}.merged(REST),
	]},
	# hold ATTACK: crouch, rise and slam down with the whole body
	"x_heavy": {"length": 1.5, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.42, "hips": Vector3(0, -0.15, -0.05), "spine": Vector3(-20, -20, 0), "rh": Vector3(-0.2, 1.85, -0.25),
			"relbow": Vector3(-1, 0.3, 0), "blade": Vector3(0, 0.6, -1), "lh": Vector3(0.28, 1.0, 0.2), "lelbow": SHIELD,
			"lknee": Vector3(30, 0, 0), "rknee": Vector3(30, 0, 0), "lleg": Vector3(-20, 0, 0), "rleg": Vector3(-15, 0, 0)},
		{"t": 0.58, "hips": Vector3(0, 0.05, 0.2), "spine": Vector3(-5, 0, 0), "rh": Vector3(-0.1, 1.95, 0.3),
			"relbow": Vector3(-1, 0.3, 0), "blade": Vector3(0, 1, 0.3), "lh": Vector3(0.28, 1.1, 0.25), "lelbow": SHIELD},
		{"t": 0.7, "hips": Vector3(0, -0.22, 0.4), "spine": Vector3(35, 10, 0), "rh": Vector3(0, 0.68, 0.85),
			"relbow": Vector3(-0.5, -1, 0), "blade": Vector3(0, -0.8, 0.6), "lh": GUARD_L + Vector3(0.1, -0.2, 0), "lelbow": SHIELD,
			"lleg": Vector3(-50, 0, 0), "lknee": Vector3(60, 0, 0), "rleg": Vector3(35, 0, 0)},
		{"t": 0.98, "hips": Vector3(0, -0.22, 0.4), "spine": Vector3(32, 10, 0), "rh": Vector3(0, 0.65, 0.82),
			"relbow": Vector3(-0.5, -1, 0), "blade": Vector3(0, -0.85, 0.5), "lh": GUARD_L + Vector3(0.1, -0.2, 0), "lelbow": SHIELD,
			"lleg": Vector3(-50, 0, 0), "lknee": Vector3(60, 0, 0), "rleg": Vector3(35, 0, 0)},
		{"t": 1.5}.merged(REST),
	]},
	# sprint attack: leap and land in a low cut
	"x_run_atk": {"length": 1.35, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.24, "hips": Vector3(0, 0.25, 0.2), "spine": Vector3(-10, -25, 0), "rh": Vector3(-0.4, 1.9, -0.1),
			"relbow": Vector3(-1, 0.3, 0), "blade": Vector3(0, 0.5, -1), "lh": GUARD_L, "lelbow": SHIELD,
			"lleg": Vector3(-50, 0, 0), "lknee": Vector3(80, 0, 0), "rleg": Vector3(-10, 0, 0), "rknee": Vector3(70, 0, 0)},
		{"t": 0.44, "hips": Vector3(0, -0.2, 0.5), "spine": Vector3(30, 20, 0), "rh": Vector3(0.1, 0.8, 0.8),
			"relbow": Vector3(0, -1, -0.3), "blade": Vector3(0.4, -0.8, 0.5), "lh": GUARD_L + Vector3(0.1, -0.1, 0), "lelbow": SHIELD,
			"lleg": Vector3(-40, 0, 0), "lknee": Vector3(50, 0, 0), "rleg": Vector3(30, 0, 0)},
		{"t": 0.85, "hips": Vector3(0, -0.2, 0.5), "spine": Vector3(28, 20, 0), "rh": Vector3(0.12, 0.78, 0.75),
			"relbow": Vector3(0, -1, -0.3), "blade": Vector3(0.4, -0.85, 0.4), "lh": GUARD_L + Vector3(0.1, -0.1, 0), "lelbow": SHIELD,
			"lleg": Vector3(-40, 0, 0), "lknee": Vector3(50, 0, 0), "rleg": Vector3(30, 0, 0)},
		{"t": 1.35}.merged(REST),
	]},
	# out of a roll: rising cut from a crouch
	"x_roll_atk": {"length": 0.85, "keys": [
		{"t": 0.0, "hips": Vector3(0, -0.25, 0), "spine": Vector3(25, 0, 0), "rh": Vector3(-0.35, 0.55, 0.3),
			"relbow": Vector3(-1, -0.5, 0), "blade": Vector3(0, -0.7, 0.7), "lh": GUARD_L + Vector3(0, -0.2, 0), "lelbow": SHIELD,
			"lleg": Vector3(-40, 0, 0), "lknee": Vector3(70, 0, 0), "rleg": Vector3(-10, 0, 0), "rknee": Vector3(80, 0, 0)},
		{"t": 0.28, "hips": Vector3(0, -0.05, 0.2), "spine": Vector3(-10, -10, 0), "rh": Vector3(-0.15, 1.7, 0.5),
			"relbow": Vector3(-1, -0.3, 0), "blade": Vector3(0, 1, 0.2), "lh": GUARD_L, "lelbow": SHIELD}.merged(STANCE),
		{"t": 0.42, "spine": Vector3(-12, -12, 0), "rh": Vector3(-0.25, 1.9, 0.1), "relbow": Vector3(-1, 0, 0),
			"blade": Vector3(0, 0.6, -0.8), "lh": GUARD_L, "lelbow": SHIELD},
		{"t": 0.85}.merged(REST),
	]},
	# shield + ATTACK: shield bash that breaks guard
	"x_bash": {"length": 0.75, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.22, "spine": Vector3(0, 30, 0), "lh": Vector3(0.3, 1.15, 0.0), "lelbow": Vector3(1, -0.5, -0.5),
			"rh": Vector3(-0.4, 1.0, -0.1), "blade": Vector3(0, 0.3, -1)},
		{"t": 0.36, "hips": Vector3(0, -0.05, 0.25), "spine": Vector3(10, -30, 0), "lh": Vector3(0.05, 1.25, 0.75),
			"lelbow": Vector3(1, -1, 0), "rh": Vector3(-0.42, 1.0, -0.15), "blade": Vector3(0, 0.3, -1)}.merged(STANCE),
		{"t": 0.75}.merged(REST),
	]},
	# critical on a stunned enemy: both hands on the hilt, point down, plunge
	"x_riposte": {"length": 1.7, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.4, "spine": Vector3(-10, 0, 0), "rh": Vector3(-0.05, 1.75, 0.35), "relbow": Vector3(-1, 0, 0),
			"blade": Vector3(0, -1, 0.15), "lh": Vector3(0.05, 1.7, 0.35), "lelbow": Vector3(1, 0, 0)},
		{"t": 0.72, "hips": Vector3(0, -0.3, 0.15), "spine": Vector3(35, 0, 0), "rh": Vector3(0, 0.9, 0.62),
			"relbow": Vector3(-1, -0.3, 0), "blade": Vector3(0, -1, 0.2), "lh": Vector3(0.05, 0.95, 0.62), "lelbow": Vector3(1, -0.3, 0),
			"lleg": Vector3(-30, 0, 0), "lknee": Vector3(60, 0, 0), "rleg": Vector3(-10, 0, 0), "rknee": Vector3(60, 0, 0)},
		{"t": 1.2, "hips": Vector3(0, -0.3, 0.15), "spine": Vector3(33, 0, 0), "rh": Vector3(0, 0.88, 0.6),
			"relbow": Vector3(-1, -0.3, 0), "blade": Vector3(0, -1, 0.2), "lh": Vector3(0.05, 0.93, 0.6), "lelbow": Vector3(1, -0.3, 0),
			"lleg": Vector3(-30, 0, 0), "lknee": Vector3(60, 0, 0), "rleg": Vector3(-10, 0, 0), "rknee": Vector3(60, 0, 0)},
		{"t": 1.7}.merged(REST),
	]},
	# Fire Seed: gather at the chest, push the open hand forward
	"cast": {"length": 0.95, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.3, "spine": Vector3(0, 20, 0), "lh": Vector3(0.15, 1.3, 0.12), "lelbow": Vector3(1, -0.5, 0),
			"rh": Vector3(-0.4, 0.95, -0.05), "blade": Vector3(0, -0.3, -1)},
		{"t": 0.5, "hips": Vector3(0, -0.05, 0.1), "spine": Vector3(5, -20, 0), "lh": Vector3(0.05, 1.35, 0.78),
			"lelbow": Vector3(1, -0.3, 0), "rh": Vector3(-0.42, 0.95, -0.1), "blade": Vector3(0, -0.3, -1)}.merged(STANCE),
		{"t": 0.95}.merged(REST),
	]},
	# flask: sword down, flask to the helm, head back
	"drink": {"length": 1.4, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.4, "spine": Vector3(-5, 0, 0), "head": Vector3(-25, 0, 0), "lh": Vector3(0.0, 1.6, 0.25), "lelbow": Vector3(1, -0.5, 0),
			"rh": Vector3(-0.35, 0.95, 0.05), "blade": Vector3(0, -0.4, 1)},
		{"t": 1.0, "spine": Vector3(-8, 0, 0), "head": Vector3(-30, 0, 0), "lh": Vector3(0.0, 1.62, 0.22), "lelbow": Vector3(1, -0.5, 0),
			"rh": Vector3(-0.35, 0.95, 0.05), "blade": Vector3(0, -0.4, 1)},
		{"t": 1.4}.merged(REST),
	]},
	# parry: sharp outward flick of the shield
	"parry": {"length": 0.7, "keys": [
		{"t": 0.0}.merged(REST),
		{"t": 0.12, "spine": Vector3(0, -25, 0), "lh": Vector3(0.35, 1.3, 0.55), "lelbow": Vector3(1, -0.5, -0.5),
			"rh": Vector3(-0.4, 1.0, -0.05), "blade": Vector3(0, 0.3, -1)},
		{"t": 0.35, "spine": Vector3(0, -20, 0), "lh": Vector3(0.38, 1.28, 0.5), "lelbow": Vector3(1, -0.5, -0.5),
			"rh": Vector3(-0.4, 1.0, -0.05), "blade": Vector3(0, 0.3, -1)},
		{"t": 0.7}.merged(REST),
	]},
}

static func add_to(lib: AnimationLibrary, skel: Skeleton3D) -> void:
	var ctx := _context(skel, lib.get_animation("idle"))
	for name in MOVES:
		if lib.has_animation(name):
			lib.remove_animation(name)  # a hand-made clip replaces the Mixamo one of the same name
		lib.add_animation(name, _bake(ctx, MOVES[name]))

static func _context(skel: Skeleton3D, base: Animation) -> Dictionary:
	var n := skel.get_bone_count()
	var local := []
	var rest_g := []
	for i in n:
		local.append(skel.get_bone_rest(i).basis.get_rotation_quaternion())
		var p := skel.get_bone_parent(i)
		var g: Transform3D = skel.get_bone_rest(i) if p < 0 else rest_g[p] * skel.get_bone_rest(i)
		rest_g.append(g)
	var hips := skel.get_bone_rest(skel.find_bone(B + "Hips")).origin
	for t in base.get_track_count():
		var bone := skel.find_bone(str(base.track_get_path(t)).get_slice(":", 1))
		if bone < 0:
			continue
		if base.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			local[bone] = base.rotation_track_interpolate(t, 0.0)
		elif base.track_get_type(t) == Animation.TYPE_POSITION_3D:
			hips = base.position_track_interpolate(t, 0.0)
	var ctx := {"skel": skel, "local": local, "rest_g": rest_g, "hips": hips}
	ctx.base_g = _fk(ctx, local, hips)
	return ctx

# global transforms (model space) for local rotations + hips position
static func _fk(ctx: Dictionary, local: Array, hips: Vector3) -> Array:
	var skel: Skeleton3D = ctx.skel
	var g := []
	for i in skel.get_bone_count():
		var o := hips if skel.get_bone_parent(i) < 0 else skel.get_bone_rest(i).origin
		var t := Transform3D(Basis(local[i]), o)
		var p := skel.get_bone_parent(i)
		g.append(t if p < 0 else g[p] * t)
	return g

static func _q(deg: Vector3) -> Quaternion:
	# x first, then y, then z, all about fixed character axes
	return Quaternion(Vector3.BACK, deg_to_rad(deg.z)) * Quaternion(Vector3.UP, deg_to_rad(deg.y)) * Quaternion(Vector3.RIGHT, deg_to_rad(deg.x))

static func _turn(ctx: Dictionary, local: Array, bone: String, deg: Vector3) -> void:
	var i: int = ctx.skel.find_bone(B + bone)
	var gb: Quaternion = ctx.base_g[i].basis.get_rotation_quaternion()
	local[i] = local[i] * (gb.inverse() * _q(deg) * gb)

static func _pose(ctx: Dictionary, k: Dictionary) -> Array:
	var skel: Skeleton3D = ctx.skel
	var local: Array = ctx.local.duplicate()
	var spin: float = deg_to_rad(k.get("spin", 0.0))
	if spin != 0.0:
		k = k.duplicate()
		k.hips_rot = k.get("hips_rot", Vector3.ZERO) + Vector3(0, rad_to_deg(spin), 0)
		for f in ["rh", "lh", "blade", "relbow", "lelbow"]:
			if k.has(f):
				k[f] = (k[f] as Vector3).rotated(Vector3.UP, spin)
	var hips: Vector3 = ctx.hips + k.get("hips", Vector3.ZERO)
	_turn(ctx, local, "Hips", k.get("hips_rot", Vector3.ZERO))
	for s in ["Spine", "Spine1", "Spine2"]:
		_turn(ctx, local, s, k.get("spine", Vector3.ZERO) / 3.0)
	_turn(ctx, local, "Head", k.get("head", Vector3.ZERO))
	for side in [["Right", "r"], ["Left", "l"]]:
		_turn(ctx, local, side[0] + "UpLeg", k.get(side[1] + "leg", Vector3.ZERO))
		_turn(ctx, local, side[0] + "Leg", k.get(side[1] + "knee", Vector3.ZERO))
	for side in [["Right", "r"], ["Left", "l"]]:
		if k.has(side[1] + "h"):
			_arm(ctx, local, hips, side[0], k[side[1] + "h"], k.get(side[1] + "elbow", Vector3(0, -1, -1)), k.get("blade") if side[1] == "r" else null)
	return [local, hips]

static func _arm(ctx: Dictionary, local: Array, hips: Vector3, side: String, target: Vector3, pole: Vector3, blade) -> void:
	var skel: Skeleton3D = ctx.skel
	var ia := skel.find_bone(B + side + "Arm")
	var ifo := skel.find_bone(B + side + "ForeArm")
	var ih := skel.find_bone(B + side + "Hand")
	var g := _fk(ctx, local, hips)
	var s: Vector3 = g[ia].origin
	var l1: float = skel.get_bone_rest(ifo).origin.length()
	var l2: float = skel.get_bone_rest(ih).origin.length()
	var d := target - s
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := d.normalized()
	var pp := (pole - dir * pole.dot(dir)).normalized()
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var elbow := s + dir * along + pp * sqrt(maxf(l1 * l1 - along * along, 0.0))
	var u := (elbow - s).normalized()
	var f := (s + dir * dist - elbow).normalized()
	var n := u.cross(f)
	if n.length() < 0.01:
		n = u.cross(-pp)
	n = (n - u * n.dot(u)).normalized()
	var rest_g: Array = ctx.rest_g
	var a0: Vector3 = (rest_g[ifo].origin - rest_g[ia].origin).normalized()
	var n0 := a0.cross(Vector3.BACK)  # rest T-pose: the elbow flexes toward the front (+Z)
	var rest_frame := _frame(a0, n0)
	var gu: Basis = _frame(u, n) * rest_frame.inverse() * rest_g[ia].basis.orthonormalized()
	var nf := (n - f * n.dot(f)).normalized()
	var gf: Basis = _frame(f, nf) * rest_frame.inverse() * rest_g[ifo].basis.orthonormalized()
	var gh: Basis = _frame(f, nf) * rest_frame.inverse() * rest_g[ih].basis.orthonormalized()
	if blade != null:
		var cur: Vector3 = gh * Vector3.FORWARD  # the sword prop points down the hand's -Z
		gh = Basis(Quaternion(cur.normalized(), (blade as Vector3).normalized())) * gh
	var gp: Basis = g[skel.get_bone_parent(ia)].basis
	local[ia] = (gp.inverse() * gu).get_rotation_quaternion()
	local[ifo] = (gu.inverse() * gf).get_rotation_quaternion()
	local[ih] = (gf.inverse() * gh).get_rotation_quaternion()

static func _frame(x: Vector3, y: Vector3) -> Basis:
	return Basis(x, y, x.cross(y))

static func _bake(ctx: Dictionary, def: Dictionary) -> Animation:
	var skel: Skeleton3D = ctx.skel
	var a := Animation.new()
	a.length = def.length
	a.loop_mode = Animation.LOOP_LINEAR if def.get("loop", false) else Animation.LOOP_NONE
	var tracks := {}
	var hips_track := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(hips_track, "Skeleton3D:" + B + "Hips")
	for i in skel.get_bone_count():
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, "Skeleton3D:" + skel.get_bone_name(i))
		a.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
		tracks[i] = tr
	for k in def.keys:
		var pose := _pose(ctx, k)
		a.position_track_insert_key(hips_track, k.t, pose[1])
		for i in tracks:
			a.rotation_track_insert_key(tracks[i], k.t, pose[0][i])
	a.track_set_interpolation_type(hips_track, Animation.INTERPOLATION_CUBIC)
	return a
