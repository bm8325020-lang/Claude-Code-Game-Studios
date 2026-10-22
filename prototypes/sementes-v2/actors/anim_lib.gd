# PROTOTYPE - NOT FOR PRODUCTION
# Shared AnimationLibrary for every Quaternius character (Universal Base Characters rig, Unreal-mannequin bone
# names; also the Imp and Puglin monsters). Raw material: Universal Animation Library 1 and 2 (CC0 mocap). Each clip
# keeps its UAL name ("Walk", "Sword_Idle", ...), loops where it should, and only the root/pelvis keep translation
# (scaled to the model's hip height). Root motion is taken out of the pose and kept as data so the body
# (CharacterBody3D) moves instead.
# On top of the raw clips this file AUTHORS the actions of the HeroAnim.act contract (light1..light4, heavy, dodge,
# roll...): trimmed, re-timed and stitched segments, with hit frames measured from the weapon tip speed, plus short
# lower-case aliases for simple AI use: idle, walk, run, sprint, attack, attack2, attack3, hit, hit_heavy, death,
# knockdown, getup, dodge, block, taunt, cheer, talk (play them with Anim.play("walk")).
# One library per skeleton size (Male, Female, Imp, Puglin); its measurements live in the library metadata:
#   AnimLib.info(lib, "light1") -> {length, hit, cancel, invuln, move, in, out, hold}
#   AnimLib.speed(lib, "Loco_Walk") -> m/s,  AnimLib.motion_between(lib, "roll", t0, t1) -> Vector3 (model space)
class_name AnimLib
extends RefCounted

const SOURCES: Array[String] = ["res://assets/anims/UAL1_Standard.glb", "res://assets/anims/UAL2_Standard.glb"]
const LOOPS: Array[String] = ["Idle", "Sword_Idle", "Jog_Fwd", "Walk", "Walk_Formal", "Sprint", "Idle_Talking",
	"Idle_Shield", "Spell_Simple_Idle", "Zombie_Walk_Fwd", "Zombie_Idle", "Idle_FoldArms", "Idle_Lantern", "Idle_Torch",
	"Sitting_Idle", "Sitting_Talking", "Crouch_Idle", "Crouch_Fwd", "Swim_Fwd", "Swim_Idle", "Jump", "Dance",
	"Idle_Rail", "Idle_Rail_Call", "Idle_No", "Push", "Farm_Harvest", "Farm_Watering", "Fixing_Kneeling", "Walk_Carry",
	"TreeChopping", "Pistol_Idle", "Idle_TalkingPhone", "NinjaJump_Idle", "Slide", "Driving"]
const FPS: float = 30.0
const ALIASES: Dictionary = {"idle": "Idle", "walk": "Loco_Walk", "run": "Loco_Jog", "sprint": "Loco_Sprint",
	"attack": "light1", "attack2": "light2", "attack3": "heavy", "hit": "hit_light", "hit_heavy": "hit_heavy",
	"death": "death", "knockdown": "knockdown", "getup": "getup", "dodge": "dodge", "block": "Idle_Shield",
	"taunt": "Idle_No", "cheer": "cheer", "talk": "Idle_Talking", "combat_idle": "Sword_Idle"}

static var _libs: Dictionary = {}      # skeleton key -> AnimationLibrary
# Measurements of the first human (hero-sized) library, kept for code that reads them directly (enemy.gd):
static var ROOT_MOTION: Dictionary = {}
static var INFO: Dictionary = {}
static var SPEED: Dictionary = {}
static var CYCLE: Dictionary = {}
# Build scratch (filled while one library is built, then stored in its metadata):
static var _motion: Dictionary = {}    # clip -> PackedVector3Array (root offset per 1/FPS, model space, metres)
static var _info: Dictionary = {}      # authored action -> {length, hit, cancel, invuln, move, in, out, hold}
static var _speed: Dictionary = {}     # locomotion clip -> ground speed in m/s (measured from the planted foot)
static var _cycle_len: Dictionary = {} # locomotion clip -> natural cycle period in seconds
static var _raw: Dictionary = {}       # clip -> Animation with the root travel still in it (authoring input)


static func info(lib: AnimationLibrary, action: String) -> Dictionary:
	return (lib.get_meta("info") as Dictionary).get(action, {})


static func has_action(lib: AnimationLibrary, action: String) -> bool:
	return (lib.get_meta("info") as Dictionary).has(action)


static func speed(lib: AnimationLibrary, clip: String) -> float:
	return (lib.get_meta("speed") as Dictionary).get(clip, 1.0)


static func cycle(lib: AnimationLibrary, clip: String) -> float:
	return (lib.get_meta("cycle") as Dictionary).get(clip, 1.0)


# The library for this skeleton (cached per bone count and hip height).
static func library(sk: Skeleton3D) -> AnimationLibrary:
	var pelvis: int = sk.find_bone("pelvis")
	var hip: float = sk.get_bone_rest(pelvis).origin.length()
	var key: String = "%d|%.3f" % [sk.get_bone_count(), hip]
	if not _libs.has(key):
		_motion = {}
		_info = {}
		_speed = {}
		_cycle_len = {}
		var lib: AnimationLibrary = _build(sk, hip)
		lib.set_meta("motion", _motion)
		lib.set_meta("info", _info)
		lib.set_meta("speed", _speed)
		lib.set_meta("cycle", _cycle_len)
		_raw = {}
		_libs[key] = lib
		if INFO.is_empty() and sk.find_bone("pinky_01_r") >= 0:
			ROOT_MOTION = _motion
			INFO = _info
			SPEED = _speed
			CYCLE = _cycle_len
	return _libs[key]


static func _build(sk: Skeleton3D, model_hip: float) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for src_path in SOURCES:
		var src: Node = load(src_path).instantiate()
		var src_sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var ratio: float = model_hip / maxf(0.01, src_sk.get_bone_rest(src_sk.find_bone("pelvis")).origin.length())
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		for nm in ap.get_animation_list():
			var a: Animation = ap.get_animation(nm).duplicate(true)
			var short: String = String(nm).get_slice("|", String(nm).get_slice_count("|") - 1)
			for t in range(a.get_track_count() - 1, -1, -1):
				var bone: String = String(a.track_get_path(t)).get_slice(":", 1)
				if sk.find_bone(bone) < 0 or a.track_get_type(t) == Animation.TYPE_SCALE_3D:
					a.remove_track(t)  # bones this model lacks (imps have no pinkies); scale never changes
					continue
				a.track_set_path(t, NodePath("Skeleton3D:" + bone))
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					if bone != "pelvis" and bone != "root":
						a.remove_track(t)  # only the hips move; other bones keep this model's proportions
						continue
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * ratio)
			_raw[short] = a.duplicate(true)
			for t in a.get_track_count():
				if String(a.track_get_path(t)) == "Skeleton3D:root" and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					_strip_root(a, t, short)
			a.loop_mode = Animation.LOOP_LINEAR if short in LOOPS else Animation.LOOP_NONE
			lib.add_animation(short, a)
		src.free()
	_author(lib, sk)
	return lib


# Moves the root bone's travel into ROOT_MOTION (per frame, model space) and pins the root at its first key.
# Height travel (climbing) is moved out too; small bobbing stays in the pose.
static func _strip_root(a: Animation, t: int, clip: String) -> void:
	var n: int = a.track_get_key_count(t)
	if n < 2:
		return
	var first: Vector3 = a.track_get_key_value(t, 0)
	var last: Vector3 = a.track_get_key_value(t, n - 1)
	var lift: bool = absf(last.y - first.y) > 0.3
	if Vector3(last.x - first.x, 0, last.z - first.z).length() < 0.05 and not lift:
		return
	var path := PackedVector3Array()
	var frames: int = int(ceil(a.length * FPS))
	for f in frames + 1:
		var p: Vector3 = a.position_track_interpolate(t, minf(a.length, f / FPS))
		path.append(Vector3(p.x - first.x, p.y - first.y if lift else 0.0, p.z - first.z))
	_motion[clip] = path
	for k in n:
		var v: Vector3 = a.track_get_key_value(t, k)
		a.track_set_key_value(t, k, Vector3(first.x, first.y if lift else v.y, first.z))


# ---------- forward kinematics without a scene (used to measure clips) ----------

# Global (model space) transform of `bone` at time `time` of clip `a`, for skeleton `sk`'s rest pose.
static func bone_global(sk: Skeleton3D, a: Animation, bone: int, time: float) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var b: int = bone
	while b >= 0:
		xf = bone_local(sk, a, b, time) * xf
		b = sk.get_bone_parent(b)
	return xf


static func bone_local(sk: Skeleton3D, a: Animation, b: int, time: float) -> Transform3D:
	var rest: Transform3D = sk.get_bone_rest(b)
	var path := NodePath("Skeleton3D:" + sk.get_bone_name(b))
	var rt: int = a.find_track(path, Animation.TYPE_ROTATION_3D)
	var pt: int = a.find_track(path, Animation.TYPE_POSITION_3D)
	var q: Quaternion = rest.basis.get_rotation_quaternion()
	var o: Vector3 = rest.origin
	if rt >= 0 and a.track_get_key_count(rt) > 0:
		q = a.rotation_track_interpolate(rt, time)
	if pt >= 0 and a.track_get_key_count(pt) > 0:
		o = a.position_track_interpolate(pt, time)
	return Transform3D(Basis(q), o)




# ---------- authored hero motion ----------

# Each action: "seg" = [[clip, from, to, speed], ...] stitched with a short pose crossfade ("join" s);
# "hits": how many sword/fist impacts to measure (0 = none); "hand": "r"/"l"/"both" (which hand strikes);
# "cancel": seconds after the last hit (or absolute "cancel_at") when the next action may start;
# "invuln": Vector2 window; "center": keep the body over the capsule and turn its travel into root motion;
# "push": extra authored travel (metres, model space) spread over "push_t"; "in"/"out": blend times.
const ACTS: Dictionary = {
	# sword / axe
	"light1": {"seg": [["Sword_Regular_A", 0.0, 0.43, 1.0], ["Sword_Regular_A_Rec", 0.0, 0.97, 1.15]], "hits": 1, "cancel": 0.14, "in": 0.08, "out": 0.3},
	"light2": {"seg": [["Sword_Regular_B", 0.0, 0.53, 1.0], ["Sword_Regular_B_Rec", 0.0, 1.03, 1.2]], "hits": 1, "cancel": 0.14, "in": 0.1, "out": 0.3},
	"light3": {"seg": [["Sword_Regular_C", 0.0, 2.0, 1.15]], "hits": 1, "cancel": 0.16, "in": 0.1, "out": 0.3},
	"light4": {"seg": [["Sword_Regular_Combo", 1.0, 3.0, 1.1]], "hits": 1, "cancel": 0.25, "in": 0.12, "out": 0.35},
	"heavy": {"seg": [["Sword_Attack", 0.0, 1.57, 0.95]], "hits": 1, "cancel": 0.3, "in": 0.12, "out": 0.35},
	"sprint_attack": {"seg": [["Sword_Dash_RM", 0.0, 1.57, 1.1]], "hits": 1, "cancel": 0.3, "in": 0.06, "out": 0.3},
	"parry": {"seg": [["Shield_OneShot", 0.0, 0.83, 1.15]], "hits": 0, "cancel_at": 0.45, "in": 0.05, "out": 0.25},
	"block_hit_shield": {"seg": [["Idle_Shield_Break", 0.0, 1.07, 1.5]], "hits": 0, "cancel_at": 0.35, "in": 0.04, "out": 0.25, "push": Vector3(0, 0, -0.35), "push_t": 0.25},
	"block_hit": {"seg": [["Sword_Block", 0.0, 1.0, 1.4]], "hits": 0, "cancel_at": 0.35, "in": 0.04, "out": 0.25, "push": Vector3(0, 0, -0.35), "push_t": 0.25},
	# movement
	# Roll starts with a dive; the dodges start where the hands reach for the ground (no floaty leap)
	"dodge": {"seg": [["Roll", 0.38, 1.4, 1.45]], "hits": 0, "cancel_at": 0.5, "invuln": Vector2(0.0, 0.36), "in": 0.07, "out": 0.25, "push": Vector3(0, 0, 2.8), "push_t": 0.42},
	"roll": {"seg": [["Roll", 0.3, 1.5, 1.2]], "hits": 0, "cancel_at": 0.75, "invuln": Vector2(0.02, 0.5), "in": 0.08, "out": 0.3, "push": Vector3(0, 0, 3.8), "push_t": 0.62},
	"backstep": {"seg": [["Shield_Dash_RM", 0.0, 0.75, 1.3]], "hits": 0, "cancel_at": 0.4, "invuln": Vector2(0.03, 0.25), "in": 0.05, "out": 0.25, "push": Vector3(0, 0, -1.6), "push_t": 0.3, "mirror_travel": true},
	"jump": {"seg": [["Jump_Start", 0.15, 1.37, 1.3]], "hits": 0, "cancel_at": 0.3, "in": 0.06, "out": 0.25},
	"fall": {"seg": [["Jump", 0.0, 0.6, 1.0]], "hits": 0, "cancel_at": 0.0, "in": 0.25, "out": 0.25},
	"land": {"seg": [["Jump_Land", 0.0, 1.3, 1.25]], "hits": 0, "cancel_at": 0.35, "in": 0.05, "out": 0.3},
	"climb": {"seg": [["ClimbUp_1m_RM", 0.0, 0.67, 0.9]], "hits": 0, "cancel_at": 0.7, "in": 0.1, "out": 0.2, "center": false, "root_travel": true},
	# reactions
	"hit_light": {"seg": [["Hit_Chest", 0.0, 0.37, 0.9]], "hits": 0, "cancel_at": 0.3, "in": 0.03, "out": 0.2},
	"hit_heavy": {"seg": [["Idle_Shield_Break", 0.0, 1.07, 1.1]], "hits": 0, "cancel_at": 0.6, "in": 0.04, "out": 0.3},
	"knockdown": {"seg": [["Hit_Knockback", 0.0, 0.83, 0.9]], "hits": 0, "cancel_at": 9.0, "in": 0.04, "out": 0.3, "center": false, "hold": true},
	"getup": {"seg": [["LayToIdle", 0.0, 1.53, 1.1]], "hits": 0, "cancel_at": 1.1, "invuln": Vector2(0.0, 1.0), "in": 0.15, "out": 0.3, "center": false},
	"death": {"seg": [["Death01", 0.0, 2.43, 1.0]], "hits": 0, "cancel_at": 99.0, "in": 0.08, "out": 0.3, "center": false, "hold": true},
	# life
	"cast": {"seg": [["Spell_Simple_Enter", 0.0, 0.57, 1.1], ["Spell_Simple_Shoot", 0.0, 0.53, 1.0], ["Spell_Simple_Exit", 0.0, 0.47, 1.0]], "hits": 1, "hand": "both", "cancel": 0.3, "in": 0.12, "out": 0.3},
	"drink": {"seg": [["Consume", 0.0, 1.33, 1.0]], "hits": 0, "cancel_at": 1.1, "in": 0.15, "out": 0.3, "upper": true},
	"interact": {"seg": [["Interact", 0.0, 2.03, 1.25]], "hits": 0, "cancel_at": 1.2, "in": 0.15, "out": 0.35},
	"pickup": {"seg": [["PickUp_Table", 0.0, 0.87, 0.9]], "hits": 0, "cancel_at": 0.8, "in": 0.12, "out": 0.3},
	"open_chest": {"seg": [["Chest_Open", 0.0, 1.37, 1.0]], "hits": 0, "cancel_at": 1.2, "in": 0.15, "out": 0.35},
	"talk": {"seg": [["Idle_Talking", 0.0, 2.97, 1.0]], "hits": 0, "cancel_at": 0.5, "in": 0.25, "out": 0.4},
	"cheer": {"seg": [["Yes", 0.0, 2.5, 1.0]], "hits": 0, "cancel_at": 1.5, "in": 0.2, "out": 0.4},
	"sit": {"seg": [["Sitting_Enter", 0.0, 1.33, 1.0]], "hits": 0, "cancel_at": 9.0, "in": 0.2, "out": 0.3, "center": false, "hold": true},
	"stand": {"seg": [["Sitting_Exit", 0.0, 1.07, 1.0]], "hits": 0, "cancel_at": 0.9, "in": 0.1, "out": 0.3, "center": false},
	# bare hands (HeroAnim picks "<name>_fist" when no weapon is held)
	"light1_fist": {"seg": [["Punch_Jab", 0.0, 0.9, 1.15]], "hits": 1, "hand": "both", "cancel": 0.12, "in": 0.08, "out": 0.25},
	"light2_fist": {"seg": [["Punch_Cross", 0.0, 1.03, 1.15]], "hits": 1, "hand": "both", "cancel": 0.12, "in": 0.08, "out": 0.25},
	"light3_fist": {"seg": [["Punch_Jab", 0.0, 0.9, 1.3]], "hits": 1, "hand": "both", "cancel": 0.12, "in": 0.06, "out": 0.25},
	"light4_fist": {"seg": [["Melee_Hook", 0.0, 0.47, 0.95], ["Melee_Hook_Rec", 0.0, 0.6, 1.0]], "hits": 1, "hand": "both", "cancel": 0.2, "in": 0.08, "out": 0.3},
	"heavy_fist": {"seg": [["Melee_Hook", 0.0, 0.47, 0.8], ["Melee_Hook_Rec", 0.0, 0.6, 0.9]], "hits": 1, "hand": "both", "cancel": 0.25, "in": 0.1, "out": 0.3},
}
# Locomotion cycles re-cut to start on the left heel strike and normalised to 1 s, so they blend in phase.
const CYCLES: Dictionary = {"Loco_Walk": "Walk", "Loco_Jog": "Jog_Fwd", "Loco_Sprint": "Sprint", "Loco_Crouch": "Crouch_Fwd"}
const JOIN: float = 0.1


static func _author(lib: AnimationLibrary, sk: Skeleton3D) -> void:
	for nm in CYCLES:
		lib.add_animation(nm, _cycle(sk, _raw[CYCLES[nm]], nm))
	var idle_pelvis: Vector3 = bone_global(sk, _raw["Idle"], sk.find_bone("pelvis"), 0.0).origin
	for nm in ACTS:
		lib.add_animation(nm, _compose(sk, nm, ACTS[nm], idle_pelvis))
	lib.add_animation("Grip", _grip(sk))
	for al in ALIASES:
		if lib.has_animation(ALIASES[al]):
			lib.add_animation(al, lib.get_animation(ALIASES[al]))


# Finds the left heel strike (left foot furthest forward), measures ground speed from the planted foot,
# and resamples one cycle to 1 s starting there.
static func _cycle(sk: Skeleton3D, a: Animation, nm: String) -> Animation:
	var fl: int = sk.find_bone("foot_l")
	var fr: int = sk.find_bone("foot_r")
	var bl: int = sk.find_bone("ball_l")
	var br: int = sk.find_bone("ball_r")
	var frames: int = int(round(a.length * FPS))
	var best_z: float = -99.0
	var phase: float = 0.0
	var vels: Array[float] = []
	var lowest: float = 99.0
	var pts: Array[Vector3] = []   # contact point of the lower foot (x unused -> 0 = left, 1 = right)
	for f in frames + 1:
		var t: float = f / FPS
		var l: Vector3 = bone_global(sk, a, fl, t).origin
		var lb: Vector3 = bone_global(sk, a, bl, t).origin
		var r: Vector3 = bone_global(sk, a, fr, t).origin
		var rb: Vector3 = bone_global(sk, a, br, t).origin
		if f < frames and l.z > best_z:
			best_z = l.z
			phase = t
		var lc: Vector3 = l if l.y < lb.y else lb
		var rc: Vector3 = r if r.y < rb.y else rb
		pts.append(Vector3(0.0 if lc.y < rc.y else 1.0, minf(lc.y, rc.y), lc.z if lc.y < rc.y else rc.z))
		lowest = minf(lowest, minf(lc.y, rc.y))
	for f in range(1, pts.size()):
		if pts[f].y < lowest + 0.05 and pts[f].x == pts[f - 1].x:
			vels.append(absf(pts[f].z - pts[f - 1].z) * FPS)
	vels.sort()
	_speed[nm] = vels[vels.size() / 2] if not vels.is_empty() else 1.0
	_cycle_len[nm] = a.length
	var out := Animation.new()
	out.length = 1.0
	out.loop_mode = Animation.LOOP_LINEAR
	for t in a.get_track_count():
		var nt: int = out.add_track(a.track_get_type(t))
		out.track_set_path(nt, a.track_get_path(t))
		for f in int(FPS) + 1:
			var u: float = f / FPS
			var st: float = fmod(phase + u * a.length, a.length)
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(nt, u, a.rotation_track_interpolate(t, st))
			else:
				var p: Vector3 = a.position_track_interpolate(t, st)
				if String(a.track_get_path(t)) == "Skeleton3D:root":
					p = Vector3(0, p.y, 0)
				out.position_track_insert_key(nt, u, p)
	return out


# Stitches the segments of one action into a single clip (see ACTS) and measures it into INFO and ROOT_MOTION.
static func _compose(sk: Skeleton3D, nm: String, cfg: Dictionary, idle_pelvis: Vector3) -> Animation:
	var bones: int = sk.get_bone_count()
	var root: int = sk.find_bone("root")
	var pelvis: int = sk.find_bone("pelvis")
	var center: bool = cfg.get("center", true)
	var rots: Array = []     # per frame: Array[Quaternion] per bone
	var root_pos: Array[Vector3] = []
	var pelvis_pos: Array[Vector3] = []
	var motion: Array[Vector3] = []
	var travel := Vector3.ZERO
	for si in (cfg.seg as Array).size():
		var seg: Array = cfg.seg[si]
		var a: Animation = _raw[seg[0]]
		var t0: float = seg[1]
		var t1: float = minf(seg[2], a.length)
		var spd: float = seg[3]
		var n: int = maxi(1, int(round((t1 - t0) / spd * FPS)))
		var rt: Array[int] = []
		for b in bones:
			rt.append(a.find_track(NodePath("Skeleton3D:" + sk.get_bone_name(b)), Animation.TYPE_ROTATION_3D))
		var rp: int = a.find_track(NodePath("Skeleton3D:root"), Animation.TYPE_POSITION_3D)
		var pp: int = a.find_track(NodePath("Skeleton3D:pelvis"), Animation.TYPE_POSITION_3D)
		var seg_rots: Array = []
		var seg_root: Array[Vector3] = []
		var seg_pel: Array[Vector3] = []
		var world: Array[Vector3] = []
		var first: int = 1 if si > 0 else 0
		for f in range(first, n + 1):
			var st: float = minf(t1, t0 + f / FPS * spd)
			var q: Array[Quaternion] = []
			for b in bones:
				q.append(a.rotation_track_interpolate(rt[b], st) if rt[b] >= 0 else sk.get_bone_rest(b).basis.get_rotation_quaternion())
			var r: Vector3 = a.position_track_interpolate(rp, st) if rp >= 0 else sk.get_bone_rest(root).origin
			var p: Vector3 = a.position_track_interpolate(pp, st) if pp >= 0 else sk.get_bone_rest(pelvis).origin
			seg_rots.append(q)
			seg_root.append(r)
			seg_pel.append(p)
			world.append(r + Basis(q[root]) * p)
		# smoothed pelvis track over the ground = the travel the capsule should do
		var smooth: Array[Vector3] = []
		for i in world.size():
			var acc := Vector3.ZERO
			var cnt: int = 0
			for j in range(maxi(0, i - 6), mini(world.size(), i + 7)):
				acc += world[j]
				cnt += 1
			smooth.append(acc / cnt)
		var base: Vector3 = smooth[0]
		for i in world.size():
			var off := Vector3.ZERO
			if center:
				off = Vector3(smooth[i].x - idle_pelvis.x, 0, smooth[i].z - idle_pelvis.z)
			seg_root[i] -= off
			var mv := Vector3(smooth[i].x - base.x, 0, smooth[i].z - base.z) if center else Vector3.ZERO
			motion.append(travel + mv)
		if center:
			travel += Vector3(smooth[smooth.size() - 1].x - base.x, 0, smooth[smooth.size() - 1].z - base.z)
		# pose crossfade from the previous segment's last frame
		if si > 0:
			var prev_q: Array[Quaternion] = rots[rots.size() - 1]
			var prev_r: Vector3 = root_pos[root_pos.size() - 1]
			var prev_p: Vector3 = pelvis_pos[pelvis_pos.size() - 1]
			var nb: int = mini(seg_rots.size(), int(JOIN * FPS))
			for i in nb:
				var w: float = smoothstep(0.0, 1.0, float(i + 1) / float(nb + 1))
				var qs: Array[Quaternion] = seg_rots[i]
				for b in bones:
					qs[b] = prev_q[b].slerp(qs[b], w)
				seg_root[i] = prev_r.lerp(seg_root[i], w)
				seg_pel[i] = prev_p.lerp(seg_pel[i], w)
		rots.append_array(seg_rots)
		root_pos.append_array(seg_root)
		pelvis_pos.append_array(seg_pel)
	# clips whose travel is on the root bone (climb): the body moves by root motion, the pose stays on the capsule
	if cfg.get("root_travel", false):
		var base_r: Vector3 = root_pos[0]
		for i in root_pos.size():
			motion[i] = root_pos[i] - base_r
			root_pos[i] = base_r
	# authored extra travel (dodges): ease-out over push_t
	var push: Vector3 = cfg.get("push", Vector3.ZERO)
	var push_t: float = cfg.get("push_t", 0.3)
	if cfg.get("mirror_travel", false):
		for i in motion.size():
			motion[i] = Vector3.ZERO
	for i in motion.size():
		var k: float = clampf((i / FPS) / push_t, 0.0, 1.0)
		motion[i] += push * (1.0 - pow(1.0 - k, 2.5))
	var out := Animation.new()
	var frames: int = rots.size()
	out.length = (frames - 1) / FPS
	out.loop_mode = Animation.LOOP_NONE
	for b in bones:
		var tr: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("Skeleton3D:" + sk.get_bone_name(b)))
		for f in frames:
			out.rotation_track_insert_key(tr, f / FPS, (rots[f] as Array[Quaternion])[b])
	for pair in [[root, root_pos], [pelvis, pelvis_pos]]:
		var tr: int = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(tr, NodePath("Skeleton3D:" + sk.get_bone_name(pair[0])))
		var arr: Array[Vector3] = pair[1]
		for f in frames:
			out.position_track_insert_key(tr, f / FPS, arr[f])
	_motion[nm] = PackedVector3Array(motion)
	_info[nm] = _measure(sk, out, cfg, motion)
	return out


# Hit frames = peaks of the weapon tip speed (or fist speed); cancel and invulnerability from the table.
static func _measure(sk: Skeleton3D, a: Animation, cfg: Dictionary, motion: Array[Vector3]) -> Dictionary:
	var hits: Array[float] = []
	var want: int = cfg.get("hits", 0)
	if want > 0:
		var hand: String = cfg.get("hand", "r")
		var sides: Array[String] = ["_" + hand]
		if hand == "both":
			sides = ["_r", "_l"]
		var speeds: Array[float] = []
		var prev: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		var frames: int = int(round(a.length * FPS))
		for f in frames + 1:
			var best: float = 0.0
			for si in sides.size():
				var hb: int = sk.find_bone("hand" + sides[si])
				var tip_local := Vector3.ZERO
				if hand == "r" and not cfg.has("hand"):
					tip_local = CharacterKit.grip_transform(sk, "Sword_Bronze", "hand_r") * Vector3(0, 0.75, 0)
				var tip: Vector3 = bone_global(sk, a, hb, f / FPS) * tip_local
				if f > 0:
					best = maxf(best, (tip - prev[si]).length() * FPS)
				prev[si] = tip
			speeds.append(best)
		var top: float = 0.0
		for v in speeds:
			top = maxf(top, v)
		var peaks: Array[Vector2] = []
		for f in range(1, speeds.size() - 1):
			if speeds[f] >= speeds[f - 1] and speeds[f] > speeds[f + 1] and speeds[f] > top * 0.55:
				peaks.append(Vector2(speeds[f], f / FPS))
		peaks.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x > y.x)
		for p in peaks:
			if hits.size() >= want:
				break
			var close: bool = false
			for h in hits:
				close = close or absf(h - p.y) < 0.2
			if not close:
				hits.append(snappedf(p.y, 0.001))
		hits.sort()
	var cancel: float = cfg.get("cancel_at", 0.0)
	if not hits.is_empty():
		cancel = hits[hits.size() - 1] + float(cfg.get("cancel", 0.15))
	return {"length": a.length, "hit": hits, "cancel": minf(cancel, a.length), "invuln": cfg.get("invuln", Vector2.ZERO),
		"move": motion[motion.size() - 1] if not motion.is_empty() else Vector3.ZERO,
		"in": cfg.get("in", 0.15), "out": cfg.get("out", 0.3), "hold": cfg.get("hold", false), "upper": cfg.get("upper", false)}


# One-frame clip with closed fists: right fingers from Sword_Idle, left from Idle_Shield.
static func _grip(sk: Skeleton3D) -> Animation:
	var out := Animation.new()
	out.length = 0.5
	out.loop_mode = Animation.LOOP_LINEAR
	for b in sk.get_bone_count():
		var bn: String = sk.get_bone_name(b)
		var fingers: bool = ["index", "middle", "ring", "pinky", "thumb"].any(func(x: String) -> bool: return bn.begins_with(x))
		if not fingers:
			continue
		var src: Animation = _raw["Sword_Idle"] if bn.ends_with("_r") else _raw["Idle_Shield"]
		var t: int = src.find_track(NodePath("Skeleton3D:" + bn), Animation.TYPE_ROTATION_3D)
		if t < 0:
			continue
		var tr: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("Skeleton3D:" + bn))
		out.rotation_track_insert_key(tr, 0.0, src.rotation_track_interpolate(t, 0.0))
	return out


# Root motion of action `nm` between two moments (model space, metres).
static func motion_between(lib: AnimationLibrary, nm: String, t0: float, t1: float) -> Vector3:
	var all: Dictionary = lib.get_meta("motion")
	if not all.has(nm):
		return Vector3.ZERO
	var m: PackedVector3Array = all[nm]
	return _motion_at(m, t1) - _motion_at(m, t0)


static func _motion_at(m: PackedVector3Array, t: float) -> Vector3:
	var x: float = clampf(t * FPS, 0.0, m.size() - 1.0)
	var i: int = int(x)
	return m[i].lerp(m[mini(i + 1, m.size() - 1)], x - i)
