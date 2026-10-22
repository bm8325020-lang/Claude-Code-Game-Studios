# PROTOTYPE - NOT FOR PRODUCTION
# HeroAnim: the hero's motion on top of AnimLib's clips. Builds an AnimationTree on a CharacterKit character:
#
#   loco (relaxed / weapon-ready blend spaces: idle, walk, jog, sprint, phase-matched, time-scaled to the real speed)
#     -> upper-body guard (Sword_Idle, or Idle_Shield in "block" mode)
#     -> mode (ground, swim, crouch, air, seated) -> action slots A/B (cross-faded) -> closed-fist grips.
# On top, a SkeletonModifier3D adds what clips cannot know: lean into turns and acceleration, the torso twist that
# keeps the chest on the target while the legs strafe, breathing, and a spring flinch on hits.
#
#   var ha := HeroAnim.new(character)          # character from CharacterKit.make
#   ha.update(dt, velocity, is_on_floor(), "free")   # every physics frame
#   var d: Dictionary = ha.act("light1")       # {length, hit: Array[float], cancel, invuln: Vector2, move: Vector3}
#   body.velocity += ha.root_motion / dt       # optional: travel the clip wants this frame (world space)
#
# Assumptions (for the combat agent):
# - HeroAnim turns the character node (yaw, world space) to face the movement direction in "free"/"swim"/"crouch"
#   and to face `look_dir` (set it to the lock-on target direction) in "lock"/"block". Set drive_yaw = false to
#   rotate the character yourself. `face(dir, instant)` snaps or eases the facing (e.g. to aim an attack).
# - act() returns seconds from now. `move` is the travel baked into the clip (model space, +Z forward); per-frame
#   travel is in `root_motion` (world space) after each update. Ignoring it only makes the feet slide a little.
# - "knockdown", "death" and "sit" hold their last pose until the next act() ("getup", "stand") or movement for sit.
# - In "swim" mode the model is lowered by SWIM_DEPTH so the water line sits on the chest when the character
#   origin is at the water surface.
# - "jump" plays the take-off; while not grounded the air loop plays; landing after a fall plays "land" by itself.
class_name HeroAnim
extends RefCounted

const ACTIONS: Array[String] = ["light1", "light2", "light3", "light4", "heavy", "sprint_attack", "dodge", "roll",
	"backstep", "block_hit", "parry", "hit_light", "hit_heavy", "knockdown", "getup", "death", "cast", "drink",
	"interact", "pickup", "open_chest", "talk", "cheer", "jump", "fall", "land", "climb", "sit"]
const COMBAT: Array[String] = ["light1", "light2", "light3", "light4", "heavy", "sprint_attack", "block_hit", "parry",
	"hit_light", "hit_heavy", "dodge", "roll", "backstep"]
const SWIM_DEPTH: float = 1.25
const UPPER: Array[String] = ["spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l",
	"hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]

var ch: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var tree: AnimationTree
var proc: ProcPose
var look_dir: Vector3 = Vector3(0, 0, 1)
var drive_yaw: bool = true
var root_motion: Vector3 = Vector3.ZERO
var current: String = ""        # action playing ("" = locomotion)

var _yaw: float = 0.0
var _yaw_rate: float = 0.0
var _speed: float = 0.0
var _prev_speed: float = 0.0
var _ready: float = 0.0
var _ready_timer: float = 0.0
var _slot: int = 0
var _t: float = 0.0
var _info: Dictionary = {}
var _air: float = 0.0
var _seated: bool = false
var _mode_idx: int = 0
var _hips: float = 0.0
var _back: float = 0.0
var _turning: bool = false
var _sw: Vector3 = Vector3.ZERO     # walk/jog/sprint speeds
var _cyc: Vector3 = Vector3.ONE     # walk/jog/sprint natural periods
var _light_flip: bool = false


func _init(character: Node3D) -> void:
	ch = character
	sk = ch.get_meta("skeleton")
	ap = ch.get_meta("anim")
	_yaw = ch.global_rotation.y if ch.is_inside_tree() else ch.rotation.y
	_sw = Vector3(AnimLib.SPEED["Loco_Walk"], AnimLib.SPEED["Loco_Jog"], AnimLib.SPEED["Loco_Sprint"])
	_cyc = Vector3(AnimLib.CYCLE["Loco_Walk"], AnimLib.CYCLE["Loco_Jog"], AnimLib.CYCLE["Loco_Sprint"])
	_build_tree()
	proc = ProcPose.new()
	proc.name = "ProcPose"
	sk.add_child(proc)
	ch.set_meta("tree", tree)
	ch.set_meta("hero_anim", self)


func set_active(on: bool) -> void:
	tree.active = on
	proc.active = on


func _anim(nm: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = nm
	return n


func _loco_space(idle: String) -> AnimationNodeBlendSpace1D:
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 12.0
	bs.sync = true
	bs.add_blend_point(_anim(idle), 0.0, -1, "idle")
	bs.add_blend_point(_anim("Loco_Walk"), _sw.x, -1, "Loco_Walk")
	bs.add_blend_point(_anim("Loco_Jog"), _sw.y, -1, "Loco_Jog")
	bs.add_blend_point(_anim("Loco_Sprint"), _sw.z, -1, "Loco_Sprint")
	return bs


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("relaxed", _loco_space("Idle"))
	bt.add_node("ready", _loco_space("Sword_Idle"))
	bt.add_node("stance", AnimationNodeBlend2.new())
	bt.connect_node("stance", 0, "relaxed")
	bt.connect_node("stance", 1, "ready")
	bt.add_node("loco_ts", AnimationNodeTimeScale.new())
	bt.connect_node("loco_ts", 0, "stance")
	var guard := AnimationNodeBlend2.new()
	guard.filter_enabled = true
	for b in UPPER:
		guard.set_filter_path(NodePath("Skeleton3D:" + b), true)
	bt.add_node("guard", guard)
	bt.add_node("guard_pose", _anim("Sword_Idle"))
	bt.connect_node("guard", 0, "loco_ts")
	bt.connect_node("guard", 1, "guard_pose")
	# other modes
	var swim := AnimationNodeBlendSpace1D.new()
	swim.add_blend_point(_anim("Swim_Idle"), 0.0, -1, "Swim_Idle")
	swim.add_blend_point(_anim("Swim_Fwd"), 1.0, -1, "Swim_Fwd")
	bt.add_node("swim", swim)
	var crouch := AnimationNodeBlendSpace1D.new()
	crouch.sync = true
	crouch.add_blend_point(_anim("Crouch_Idle"), 0.0, -1, "Crouch_Idle")
	crouch.add_blend_point(_anim("Loco_Crouch"), 1.0, -1, "Loco_Crouch")
	bt.add_node("crouch", crouch)
	bt.add_node("crouch_ts", AnimationNodeTimeScale.new())
	bt.connect_node("crouch_ts", 0, "crouch")
	bt.add_node("air", _anim("Jump"))
	bt.add_node("seated", _anim("Sitting_Idle"))
	var mode := AnimationNodeTransition.new()
	for i in 5:
		mode.add_input(["ground", "swim", "crouch", "air", "seated"][i])
	mode.xfade_time = 0.25
	bt.add_node("mode", mode)
	bt.connect_node("mode", 0, "guard")
	bt.connect_node("mode", 1, "swim")
	bt.connect_node("mode", 2, "crouch_ts")
	bt.connect_node("mode", 3, "air")
	bt.connect_node("mode", 4, "seated")
	# actions: two slots so a new action cross-fades over the one still playing
	var act := AnimationNodeTransition.new()
	act.add_input("loco")
	act.add_input("a")
	act.add_input("b")
	act.xfade_time = 0.1
	act.set_input_reset(1, true)
	act.set_input_reset(2, true)
	act.allow_transition_to_self = true
	bt.add_node("act", act)
	var sa := _anim("Idle")
	sa.play_mode = AnimationNodeAnimation.PLAY_MODE_FORWARD
	bt.add_node("slot_a", sa)
	bt.add_node("slot_b", _anim("Idle"))
	bt.connect_node("act", 0, "mode")
	bt.connect_node("act", 1, "slot_a")
	bt.connect_node("act", 2, "slot_b")
	# closed fists around the props
	for side in ["r", "l"]:
		var g := AnimationNodeBlend2.new()
		g.filter_enabled = true
		for b in sk.get_bone_count():
			var bn: String = sk.get_bone_name(b)
			if bn.ends_with("_" + side) and ["index", "middle", "ring", "pinky", "thumb"].any(func(x: String) -> bool: return bn.begins_with(x)):
				g.set_filter_path(NodePath("Skeleton3D:" + bn), true)
		bt.add_node("grip_" + side, g)
		bt.add_node("grip_pose_" + side, _anim("Grip"))
		bt.connect_node("grip_" + side, 1, "grip_pose_" + side)
	bt.connect_node("grip_r", 0, "act")
	bt.connect_node("grip_l", 0, "grip_r")
	bt.connect_node("output", 0, "grip_l")
	tree = AnimationTree.new()
	tree.name = "Tree"
	ch.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = ap.root_node
	tree.tree_root = bt
	tree.active = true
	_p("loco_ts/scale", 1.0)
	_p("crouch_ts/scale", 1.0)
	_p("mode/transition_request", "ground")
	_p("act/transition_request", "loco")


func _p(param: String, v: Variant) -> void:
	tree.set("parameters/" + param, v)


func _holds(slot: String) -> bool:
	var look: Dictionary = ch.get_meta("look", {})
	return String(look.get(slot, "")) != ""


# Turns the character toward a world direction (instant snaps, else it eases in over a few frames).
func face(dir: Vector3, instant: bool = false) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	look_dir = Vector3(dir.x, 0, dir.z).normalized()
	if instant:
		_yaw = atan2(look_dir.x, look_dir.z)
		_apply_yaw()


func _apply_yaw() -> void:
	if drive_yaw and ch.is_inside_tree():
		ch.global_rotation = Vector3(0, _yaw, 0)


static func _wrap(a: float) -> float:
	return wrapf(a, -PI, PI)


func update(dt: float, velocity: Vector3, grounded: bool, mode: String) -> void:
	if dt <= 0.0:
		return
	var flat := Vector3(velocity.x, 0, velocity.z)
	var spd: float = flat.length()
	_prev_speed = _speed
	_speed = lerpf(_speed, spd, 1.0 - exp(-dt * 12.0))
	var accel: float = (_speed - _prev_speed) / dt
	# ---- action clock, blend-out and root motion
	root_motion = Vector3.ZERO
	if current != "":
		var t0: float = _t
		_t += dt
		root_motion = Basis(Vector3.UP, _yaw) * AnimLib.motion_between(_info_name(), t0, _t)
		var hold: bool = _info.get("hold", false)
		if not hold and _t >= float(_info.length) - float(_info.out) and _t - dt < float(_info.length) - float(_info.out):
			_back_to_loco(float(_info.out))
		if not hold and _t >= float(_info.length):
			current = ""
		if current == "sit" and _t >= float(_info.length):
			_seated = true
			current = ""
			_back_to_loco(0.2)
	if _seated and spd > 0.3 and current == "":
		_seated = false
		_play("stand")
	# ---- readiness (weapon up) and timers
	_ready_timer = maxf(0.0, _ready_timer - dt)
	var want_ready: float = 1.0 if _holds("weapon") and (mode in ["lock", "block"] or _ready_timer > 0.0) else 0.0
	_ready = move_toward(_ready, want_ready, dt * 3.0)
	# ---- facing
	var move_yaw: float = atan2(flat.x, flat.z) if spd > 0.15 else _yaw
	var target: float = _yaw
	var hips_target: float = 0.0
	var backward: bool = false
	var locked: bool = mode in ["lock", "block"]
	if locked:
		var face_yaw: float = atan2(look_dir.x, look_dir.z)
		var rel: float = _wrap(move_yaw - face_yaw) if spd > 0.15 else 0.0
		if absf(rel) > deg_to_rad(110.0):
			backward = true
			rel = _wrap(rel - PI)
		hips_target = clampf(rel * 0.7, -1.2, 1.2)
		target = face_yaw
	elif spd > 0.15 and current == "":
		target = move_yaw
	_hips = lerp_angle(_hips, hips_target, 1.0 - exp(-dt * 10.0))
	_back = move_toward(_back, 1.0 if backward else 0.0, dt * 5.0)
	var prev_yaw: float = _yaw
	var err: float = _wrap(target - _yaw)
	var acting: bool = current != "" and _t > 0.12  # attacks may still aim during the first frames
	if not acting and not _seated:
		var rate: float = 7.0 if spd > 0.5 else 4.0
		_yaw = _wrap(_yaw + clampf(err, -rate * dt, rate * dt) * (1.0 if locked else minf(1.0, 0.35 + spd * 0.2)))
	_yaw_rate = lerpf(_yaw_rate, _wrap(_yaw - prev_yaw) / dt, 1.0 - exp(-dt * 8.0))
	_turning = spd < 0.3 and absf(err) > 0.3 and current == "" and not _seated
	var model_yaw: float = _yaw + _hips
	if drive_yaw and ch.is_inside_tree():
		ch.global_rotation = Vector3(0, model_yaw, 0)
	# ---- mode
	if grounded:
		if _air > 0.45 and current == "":
			_play("land")
		_air = 0.0
	else:
		_air += dt
	var mi: int = 0
	if mode == "swim":
		mi = 1
	elif mode == "crouch":
		mi = 2
	elif _air > 0.15 and mode != "swim":
		mi = 3
	elif _seated:
		mi = 4
	if mi != _mode_idx:
		_mode_idx = mi
		_p("mode/transition_request", ["ground", "swim", "crouch", "air", "seated"][mi])
	var model: Node3D = sk.get_parent().get_parent()
	model.position.y = lerpf(model.position.y, -SWIM_DEPTH if mi == 1 else 0.0, 1.0 - exp(-dt * 6.0))
	# ---- locomotion parameters
	var blend: float = _speed
	if _turning:
		blend = maxf(blend, _sw.x * 0.55)  # step around while turning on the spot
	_p("relaxed/blend_position", blend)
	_p("ready/blend_position", blend)
	_p("stance/blend_amount", _ready)
	var freq: float = 1.0
	if blend < _sw.x:
		freq = lerpf(1.0, 1.0 / _cyc.x, blend / _sw.x)
	elif blend < _sw.y:
		freq = lerpf(1.0 / _cyc.x, 1.0 / _cyc.y, (blend - _sw.x) / (_sw.y - _sw.x))
	elif blend < _sw.z:
		freq = lerpf(1.0 / _cyc.y, 1.0 / _cyc.z, (blend - _sw.y) / (_sw.z - _sw.y))
	else:
		freq = (1.0 / _cyc.z) * blend / _sw.z
	_p("loco_ts/scale", freq * (1.0 - 2.0 * _back))
	var block: bool = mode == "block"
	(tree.tree_root as AnimationNodeBlendTree).get_node("guard_pose").set("animation", "Idle_Shield" if block and _holds("shield") else "Sword_Idle")
	var guard: float = 1.0 if block else _ready * clampf(1.0 - (_speed - _sw.x) / maxf(0.1, _sw.y - _sw.x), 0.0, 1.0) * 0.85
	_p("guard/blend_amount", guard)
	_p("swim/blend_position", clampf(_speed / 1.6, 0.0, 1.0))
	_p("crouch/blend_position", clampf(_speed / maxf(0.1, AnimLib.SPEED["Loco_Crouch"]), 0.0, 1.0))
	_p("crouch_ts/scale", maxf(1.0, _speed / maxf(0.1, AnimLib.SPEED["Loco_Crouch"])) / AnimLib.CYCLE["Loco_Crouch"] if _speed > 0.1 else 1.0)
	_p("grip_r/blend_amount", 1.0 if _holds("weapon") else 0.0)
	_p("grip_l/blend_amount", 1.0 if _holds("shield") else 0.0)
	# ---- procedural layer
	proc.lean_roll = lerpf(proc.lean_roll, clampf(-_yaw_rate * _speed * 0.035, -0.28, 0.28), 1.0 - exp(-dt * 6.0))
	var pitch_t: float = clampf(accel * 0.025, -0.12, 0.16) if mi == 0 and current == "" else 0.0
	proc.lean_pitch = lerpf(proc.lean_pitch, pitch_t, 1.0 - exp(-dt * 5.0))
	proc.twist = -_hips
	proc.exertion = clampf(proc.exertion + dt * (0.25 if _speed > _sw.y else -0.08), 0.0, 1.0)
	proc.calm = 1.0 - clampf(_speed / _sw.x, 0.0, 1.0) if current == "" else 0.3
	proc.step(dt)


func _back_to_loco(xfade: float) -> void:
	(tree.tree_root as AnimationNodeBlendTree).get_node("act").set("xfade_time", xfade)
	_p("act/transition_request", "loco")


func _info_name() -> String:
	return String(_info.get("name", current))


# Plays an action; returns {length, hit: Array[float], cancel, invuln: Vector2, move: Vector3} in seconds.
func act(nm: String) -> Dictionary:
	return _play(nm)


func _play(nm: String) -> Dictionary:
	var clip: String = nm
	if not _holds("weapon") and AnimLib.ACTS.has(nm + "_fist"):
		clip = nm + "_fist"
	if nm == "fall":
		_air = 1.0
	if nm == "hit_light":
		_light_flip = not _light_flip
		proc.flinch(0.35 if _light_flip else -0.35)
	elif nm == "hit_heavy" or nm == "block_hit":
		proc.flinch(0.6)
	if not AnimLib.INFO.has(clip):
		push_warning("HeroAnim: no action " + nm)
		return {"length": 0.0, "hit": [] as Array[float], "cancel": 0.0, "invuln": Vector2.ZERO, "move": Vector3.ZERO}
	if nm in COMBAT:
		_ready_timer = 6.0
	if nm == "getup" or nm == "stand" or nm == "death":
		_seated = false
	var info: Dictionary = (AnimLib.INFO[clip] as Dictionary).duplicate()
	info["name"] = clip
	_info = info
	_slot = 2 if _slot == 1 else 1
	var bt: AnimationNodeBlendTree = tree.tree_root
	bt.get_node("slot_a" if _slot == 1 else "slot_b").set("animation", clip)
	bt.get_node("act").set("xfade_time", float(info["in"]))
	_p("act/transition_request", "a" if _slot == 1 else "b")
	current = nm
	_t = 0.0
	var hit: Array[float] = info.hit
	return {"length": info.length, "hit": hit.duplicate(), "cancel": info.cancel, "invuln": info.invuln, "move": info.move}


# Procedural pose layer: runs after the AnimationTree has posed the skeleton.
class ProcPose extends SkeletonModifier3D:
	var lean_roll: float = 0.0
	var lean_pitch: float = 0.0
	var twist: float = 0.0
	var exertion: float = 0.0
	var calm: float = 1.0
	var _clock: float = 0.0
	var _flinch: float = 0.0
	var _flinch_v: float = 0.0
	var _flinch_side: float = 0.0

	func flinch(strength: float) -> void:
		_flinch_v += absf(strength) * 9.0
		_flinch_side = signf(strength) * 0.5

	func step(dt: float) -> void:
		_clock += dt * lerpf(1.0, 2.2, exertion)
		# damped spring back to 0
		_flinch_v += (-_flinch * 120.0 - _flinch_v * 14.0) * dt
		_flinch += _flinch_v * dt

	func _rot_model(s: Skeleton3D, b: int, axis: Vector3, ang: float) -> void:
		if b < 0 or absf(ang) < 0.0001:
			return
		var parent: int = s.get_bone_parent(b)
		var pb: Basis = s.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var ax: Vector3 = (pb.inverse() * axis).normalized()
		s.set_bone_pose_rotation(b, Quaternion(ax, ang) * s.get_bone_pose_rotation(b))

	func _process_modification() -> void:
		var s: Skeleton3D = get_skeleton()
		if s == null:
			return
		var fwd := Vector3(0, 0, 1)
		var right := Vector3(-1, 0, 0)
		# whole-body lean pivots on the feet (root bone sits on the ground)
		_rot_model(s, s.find_bone("root"), fwd, lean_roll)
		_rot_model(s, s.find_bone("root"), right, -lean_pitch * 0.5)
		_rot_model(s, s.find_bone("spine_01"), right, -lean_pitch * 0.5)
		# chest stays on the target while the legs strafe
		for bn in ["spine_01", "spine_02", "spine_03"]:
			_rot_model(s, s.find_bone(bn), Vector3.UP, twist / 3.0)
		# breathing: chest rise and shoulders, bigger after sprinting
		var br: float = sin(_clock * TAU / 3.4)
		var amp: float = lerpf(0.012, 0.03, exertion) * lerpf(0.6, 1.0, calm)
		_rot_model(s, s.find_bone("spine_03"), right, -br * amp)
		_rot_model(s, s.find_bone("clavicle_l"), fwd, -br * amp * 0.8)
		_rot_model(s, s.find_bone("clavicle_r"), fwd, br * amp * 0.8)
		_rot_model(s, s.find_bone("neck_01"), right, br * amp * 0.7)
		# hit flinch: chest snaps back and twists, head follows late
		if absf(_flinch) > 0.0005:
			_rot_model(s, s.find_bone("spine_02"), right, _flinch * 0.35)
			_rot_model(s, s.find_bone("spine_03"), Vector3.UP, _flinch * _flinch_side * 0.5)
			_rot_model(s, s.find_bone("Head"), right, _flinch * 0.25)
