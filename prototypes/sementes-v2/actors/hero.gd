# PROTOTYPE - NOT FOR PRODUCTION
# Hero: the player body. Third-person camera (soft collision, touch drag look, lock-on), stamina, poise, light combo
# light1..light4, heavy, sprint attack, dodge/roll/backstep with i-frames, block with a parry window, potion (frasco),
# jump, interact. Timing comes from HeroAnim.act() (hit frames, cancel points, i-frames) so attacks land on the frame
# the fist or blade actually swings through; root motion moves the body.
#
#   var hero := Hero.new(); add_child(hero); hero.global_position = p
#   hero.equip({"body": "Male", "outfit": "Peasant", "weapon": "Sword_Bronze", "shield": "Shield_Wooden"})
#
# Signals: hp_changed(hp, max_hp), stamina_changed(st, max_st), potions_changed(n), died, revived,
#   hit_landed(target, amount, result), lock_changed(target or null), interact_requested, action_started(name),
#   hurt(amount, source, result).
# Public: hp, max_hp, stamina, max_stamina, power (outgoing damage multiplier), defense (incoming multiplier),
#   potions, max_potions, potion_heal, input_enabled (false during dialogs/menus), swimming (main sets it in water),
#   camera (Camera3D), lock_target, state ("free", "attack", "dodge", "block", "hit", "down", "drink", "action", "dead").
# Methods: equip(look), take_hit(amount, source, kind) -> {result, damage}, perform(action) -> seconds (main plays
#   "interact", "open_chest", "pickup", "talk", "cheer", "sit"...), revive(pos), heal(n), refill(), shake(amount),
#   look_input(drag_pixels), stick_for(world_dir) -> Vector2, set_bot(callable).
# Groups: "hero". Collision layer 2 (hero), mask 1 (world) + 3 (enemies). Enemies are found in group "enemies" and
#   should expose `dead: bool`, `radius: float`, `target_height: float`, optionally `is_open() -> bool`
#   (staggered: riposte) and `on_parried(by)`.
# Input: ui/touch.gd if present (autoload "Touch", a node in group "touch", or class_name Touch with static
#   functions) - move_vector() -> Vector2 (x right, y down like Input.get_vector), pressed(a) (this frame), held(a);
#   optional look_delta() -> Vector2 pixels. Without it, drags that reach _unhandled_input on the right 55% of the
#   screen turn the camera, so touch.gd should mark button touches as handled. Keyboard: project InputMap
#   (attack, roll=dodge, block, flask=potion, seed=skill, lock, jump, interact, menu, move_*), I = heavy,
#   Shift = sprint, right mouse drag = look.
# Damage always goes through Fx.deal (main.damage when the scene has it).
class_name Hero
extends CharacterBody3D

signal hp_changed(hp: float, max_hp: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal potions_changed(n: int)
signal died
signal revived
signal hit_landed(target: Node3D, amount: float, result: String)
signal lock_changed(target: Node3D)
signal interact_requested
signal action_started(action: String)
signal hurt(amount: float, source: Node, result: String)

const ACTIONS: Array[String] = ["attack", "heavy", "dodge", "block", "skill", "potion", "interact", "lock", "jump", "menu"]
const KEYMAP: Dictionary = {"attack": "attack", "heavy": "heavy", "dodge": "roll", "block": "block", "skill": "seed",
	"potion": "flask", "interact": "interact", "lock": "lock", "jump": "jump", "menu": "menu"}
const RUN: float = 5.0
const LOCK_RUN: float = 3.6
const SPRINT: float = 7.6
const BLOCK_WALK: float = 1.6
const SWIM: float = 2.2
const GRAVITY: float = 22.0
const JUMP_V: float = 7.0
const LOCK_RANGE: float = 18.0
const PARRY_WINDOW: float = 0.22
# Per weapon prop: damage, reach (m past the target's radius), arc (degrees each side), sounds.
const WEAPONS: Dictionary = {
	"": {"dmg": 8.0, "reach": 1.25, "arc": 60.0, "swing": ["cloth1", "cloth3"], "impact": ["impactPunch_heavy_000", "impactPunch_heavy_001"], "stam": 0.8},
	"Sword_Bronze": {"dmg": 16.0, "reach": 2.0, "arc": 75.0, "swing": ["knifeSlice", "knifeSlice2"], "impact": ["impactWood_heavy_000", "impactPlate_heavy_000"], "stam": 1.0},
	"Axe_Bronze": {"dmg": 19.0, "reach": 2.0, "arc": 65.0, "swing": ["knifeSlice2"], "impact": ["impactWood_heavy_000"], "stam": 1.2},
	"Pickaxe_Bronze": {"dmg": 15.0, "reach": 1.9, "arc": 55.0, "swing": ["knifeSlice2"], "impact": ["impactWood_medium_001"], "stam": 1.15},
	"Torch_Metal": {"dmg": 10.0, "reach": 1.7, "arc": 60.0, "swing": ["cloth1"], "impact": ["impactWood_medium_002"], "stam": 0.9},
}
# Per move: damage multiplier, stamina cost, reach multiplier, damage kind (poise), hit-stop seconds.
const MOVES: Dictionary = {
	"light1": {"mult": 1.0, "stam": 12.0, "reach": 1.0, "kind": "light", "stop": 0.045},
	"light2": {"mult": 1.05, "stam": 12.0, "reach": 1.0, "kind": "light", "stop": 0.045},
	"light3": {"mult": 1.15, "stam": 14.0, "reach": 1.05, "kind": "light", "stop": 0.05},
	"light4": {"mult": 1.6, "stam": 18.0, "reach": 1.1, "kind": "heavy", "stop": 0.08},
	"heavy": {"mult": 2.2, "stam": 28.0, "reach": 1.15, "kind": "heavy", "stop": 0.1},
	"sprint_attack": {"mult": 1.7, "stam": 20.0, "reach": 1.2, "kind": "heavy", "stop": 0.08},
}
const DODGE_COST: Dictionary = {"backstep": 10.0, "dodge": 15.0, "roll": 20.0}
const STEPS: Array[String] = ["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002",
	"footstep_concrete_003", "footstep_concrete_004"]

var max_hp: float = 100.0
var hp: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var max_poise: float = 25.0
var poise: float = 25.0
var power: float = 1.0
var defense: float = 1.0
var potions: int = 3
var max_potions: int = 3
var potion_heal: float = 45.0
var input_enabled: bool = true
var stick_len: float = 0.0  # how hard the player pushes the stick this frame (main's "stuck" rescue reads it)
var swimming: bool = false
var look: Dictionary = {}

var character: Node3D
var anim: HeroAnim
var camera: Camera3D
var cam_root: Node3D
var spring: SpringArm3D
var cam_yaw: float = PI
var cam_pitch: float = -0.32
var lock_target: Node3D = null
var state: String = "free"
var state_t: float = 0.0

var _act: Dictionary = {}
var _act_name: String = ""
var _act_t: float = 0.0
var _hit_i: int = 0
var _combo: int = 0
var _queued: String = ""
var _queue_t: float = 0.0
var _aim: Node3D = null
var _stam_delay: float = 0.0
var _poise_delay: float = 0.0
var _sprint_t: float = 0.0
var _sprinting: bool = false
var _step_t: float = 0.0
var _trauma: float = 0.0
var _look_idle: float = 9.0
var _getup_at: float = 0.0
var _healed: bool = false
var _hit_any: bool = false
var _key_heavy_prev: bool = false
var _touch: Object = null
var _touch_retry: float = 0.0
var _look_touch: int = -1
var _bot: Callable = Callable()
var _trail: Fx.Trail
var _tip_len: float = -1.0
var _marker: Sprite3D


func _ready() -> void:
	add_to_group("hero")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	cam_root = Node3D.new()
	cam_root.name = "CamRoot"
	cam_root.top_level = true
	add_child(cam_root)
	spring = SpringArm3D.new()
	spring.spring_length = 4.4
	spring.collision_mask = 1
	spring.margin = 0.2
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	spring.add_excluded_object(get_rid())
	cam_root.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 600.0
	spring.add_child(camera)
	camera.current = true
	cam_root.global_position = global_position + Vector3(0, 1.55, 0)
	_trail = Fx.Trail.new()
	add_child(_trail)
	_marker = Sprite3D.new()
	_marker.texture = Fx.glow_texture()
	_marker.modulate = Color(1.0, 0.75, 0.35)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.shaded = false
	_marker.pixel_size = 0.012
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)
	if character == null:
		equip(look if not look.is_empty() else {"body": "Male", "outfit": "Peasant", "weapon": ""})


# Rebuilds the character for a new look (outfit, weapon, shield). Keeps facing; cancels any action.
func equip(new_look: Dictionary) -> void:
	look = new_look.duplicate()
	var dir := Vector3(0, 0, 1)
	if character != null:
		dir = character.global_basis.z
		remove_child(character)
		character.queue_free()
	character = CharacterKit.make(look)
	add_child(character)
	anim = HeroAnim.new(character)
	anim.face(dir, true)
	_tip_len = -1.0
	if state != "dead":
		_set_state("free")


func weapon_name() -> String:
	return String(look.get("weapon", ""))


func _weapon() -> Dictionary:
	return WEAPONS.get(weapon_name(), WEAPONS["Sword_Bronze"] if weapon_name() != "" else WEAPONS[""])


func has_shield() -> bool:
	return String(look.get("shield", "")) != ""


# Autopilot for tests: callable(hero) -> {move: Vector2, pressed: Array, held: Array}.
func set_bot(c: Callable) -> void:
	_bot = c


# ---------------------------------------------------------------- input

var _touch_methods: Dictionary = {}


func _find_touch() -> void:
	var n: Node = get_tree().root.get_node_or_null("Touch")
	if n == null:
		n = get_tree().get_first_node_in_group("touch")
	if n != null:
		_touch = n
		return
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) == "Touch":
			_touch = load(String(c["path"]))
			return


func _tcall(method: String, arg: Variant = null) -> Variant:
	if _touch == null:
		return null
	if _touch is Node:
		if not (_touch as Node).has_method(method):
			return null
	elif _touch is Script:
		if _touch_methods.is_empty():  # build once: rebuilding the method list per input query cost ~10 ms/frame
			for m in (_touch as Script).get_script_method_list():
				_touch_methods[String(m["name"])] = true
		if not _touch_methods.has(method):
			return null
	return _touch.call(method) if arg == null else _touch.call(method, arg)


func _read_input(dt: float) -> Dictionary:
	if _bot.is_valid():
		return _bot.call(self)
	var out: Dictionary = {"move": Vector2.ZERO, "pressed": [], "held": []}
	if not input_enabled:
		return out
	if _touch == null:
		_touch_retry -= dt
		if _touch_retry <= 0.0:
			_touch_retry = 1.0
			_find_touch()
	var mv := Vector2.ZERO
	if InputMap.has_action("move_left"):
		mv = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var tv: Variant = _tcall("move_vector")
	if tv is Vector2 and (tv as Vector2).length() > mv.length():
		mv = tv
	out["move"] = mv
	var pressed: Array = []
	var held: Array = []
	for a in ACTIONS:
		var key: String = KEYMAP[a]
		var p: bool = InputMap.has_action(key) and Input.is_action_just_pressed(key)
		var h: bool = InputMap.has_action(key) and Input.is_action_pressed(key)
		if _tcall("pressed", a) == true:
			p = true
		if _tcall("held", a) == true:
			h = true
		if p:
			pressed.append(a)
		if h:
			held.append(a)
	var kh: bool = Input.is_physical_key_pressed(KEY_I)
	if kh and not _key_heavy_prev:
		pressed.append("heavy")
	_key_heavy_prev = kh
	if Input.is_physical_key_pressed(KEY_SHIFT):
		held.append("sprint")
	var ld: Variant = _tcall("look_delta")
	if ld is Vector2:
		look_input(ld)
	out["pressed"] = pressed
	out["held"] = held
	return out


func _unhandled_input(event: InputEvent) -> void:
	if _bot.is_valid() or not input_enabled:
		return
	var w: float = get_viewport().get_visible_rect().size.x
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and st.position.x > w * 0.45 and _look_touch < 0:
			_look_touch = st.index
		elif not st.pressed and st.index == _look_touch:
			_look_touch = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _look_touch:
			look_input(sd.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look_input((event as InputEventMouseMotion).relative)


# Turns the camera by a drag in pixels (UI can call this too).
func look_input(rel: Vector2) -> void:
	if rel == Vector2.ZERO:
		return
	cam_yaw -= rel.x * 0.006
	cam_pitch = clampf(cam_pitch - rel.y * 0.004, -1.05, 0.35)
	_look_idle = 0.0


func _cam_dirs() -> Array[Vector3]:
	var f := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var r := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	return [f, r]


# The stick vector that would move the hero along world direction `dir` (used by bots and cutscenes).
func stick_for(dir: Vector3) -> Vector2:
	var d: Array[Vector3] = _cam_dirs()
	var n := Vector3(dir.x, 0, dir.z).normalized()
	return Vector2(n.dot(d[1]), -n.dot(d[0]))


func _world_dir(mv: Vector2) -> Vector3:
	var d: Array[Vector3] = _cam_dirs()
	var v: Vector3 = d[1] * mv.x - d[0] * mv.y
	return v.limit_length(1.0)


# ---------------------------------------------------------------- main loop

func _physics_process(dt: float) -> void:
	if anim == null or dt <= 0.0:
		return
	var inp: Dictionary = _read_input(dt)
	var pressed: Array = inp["pressed"]
	var held: Array = inp["held"]
	var mv: Vector2 = inp["move"]
	stick_len = mv.length()
	var dir: Vector3 = _world_dir(mv)
	state_t += dt
	_act_t += dt
	_queue_t -= dt
	if _queue_t <= 0.0:
		_queued = ""
	_regen(dt)
	if "lock" in pressed and state != "dead":
		_toggle_lock()
	_check_lock()
	var extra := Vector3.ZERO   # added to root motion during actions
	var want := Vector3.ZERO    # locomotion target velocity
	var loco: bool = false
	match state:
		"free":
			loco = true
			_sprint_t = _sprint_t + dt if mv.length() > 0.9 and lock_target == null else 0.0
			_sprinting = (_sprint_t > 0.5 or "sprint" in held) and dir.length() > 0.3 and stamina > 1.0 and not swimming
			var spd: float = RUN
			if swimming:
				spd = SWIM
			elif _sprinting:
				spd = SPRINT
				stamina -= 13.0 * dt
				_stam_delay = 0.5
			elif lock_target != null:
				spd = LOCK_RUN
			want = dir * spd
			_free_actions(pressed, held, dir)
		"block":
			loco = true
			want = dir * BLOCK_WALK
			if not "block" in held or swimming:
				_set_state("free")
			elif "attack" in pressed and stamina > 1.0:
				_start_attack("light1", dir)
			elif "dodge" in pressed and stamina > 1.0:
				_start_dodge(dir)
		"attack":
			for a in ["attack", "heavy", "dodge"]:
				if a in pressed:
					_queued = a
					_queue_t = 0.45
			extra = _lunge(dt)
			_attack_hits()
			if _act_t >= float(_act["cancel"]) and _queued != "" and stamina > 1.0:
				var q: String = _queued
				_queued = ""
				if q == "dodge":
					_start_dodge(dir)
				elif q == "heavy":
					_start_attack("heavy", dir)
				else:
					_start_attack("light%d" % (_combo % 4 + 1), dir)
			elif _act_t >= float(_act["cancel"]) + 0.12 and dir.length() > 0.5:
				_set_state("free")  # walk out of the recovery
			elif _act_t >= float(_act["length"]):
				_set_state("free")
		"dodge":
			if "attack" in pressed or "dodge" in pressed:
				_queued = "attack" if "attack" in pressed else "dodge"
				_queue_t = 0.35
			if _act_t >= float(_act["cancel"]):
				if _queued == "attack" and stamina > 1.0:
					_queued = ""
					_combo = 0
					_start_attack("light1", dir)
				elif _queued == "dodge" and stamina > 1.0:
					_queued = ""
					_start_dodge(dir)
				elif dir.length() > 0.3 or _act_t >= float(_act["length"]):
					_set_state("free")
		"hit":
			if _act_t >= float(_act["cancel"]):
				_set_state("free")
		"down":
			if _act_t >= _getup_at and _act_name == "knockdown":
				_play("getup")
			elif _act_name == "getup" and _act_t >= float(_act["cancel"]):
				_set_state("free")
		"drink":
			want = dir * 1.0
			loco = true
			if not _healed and _act_t >= float(_act["length"]) * 0.6:
				_healed = true
				heal(potion_heal)
				Fx.burst(self, global_position + Vector3(0, 1.2, 0), Color(0.6, 1.0, 0.55), 12, 1.5, 0.8, 0.12, -1.0, true)
			if _act_t >= float(_act["cancel"]):
				_set_state("free")
		"action":
			if _act_t >= float(_act["cancel"]):
				_set_state("free")
		"dead":
			pass
	# trail on the swinging hand or blade
	if state == "attack":
		for h in (_act["hit"] as Array):
			if _act_t > float(h) - 0.16 and _act_t < float(h) + 0.06:
				_sample_trail()
				break
	# ---- body
	var mode: String = "free"
	if swimming:
		mode = "swim"
	elif state == "block":
		mode = "block"
	elif lock_target != null and state != "dead":
		mode = "lock"
	if lock_target != null and state in ["free", "block", "drink"]:
		anim.face(lock_target.global_position - global_position)
	anim.update(dt, velocity, is_on_floor(), mode)
	var hv := Vector3(velocity.x, 0, velocity.z)
	if loco:
		var accel: float = 30.0 if want.length() > hv.length() else 40.0
		if not is_on_floor():
			accel = 6.0
		hv = hv.move_toward(want, accel * dt)
	else:
		hv = anim.root_motion / dt + extra
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * dt
	if swimming:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()
	_footsteps(dt, hv.length())
	_update_camera(dt, dir)


func _free_actions(pressed: Array, held: Array, dir: Vector3) -> void:
	if swimming:
		return
	if "attack" in pressed and stamina > 1.0:
		_combo = 0
		_start_attack("sprint_attack" if _sprinting else "light1", dir)
	elif "heavy" in pressed and stamina > 1.0:
		_start_attack("heavy", dir)
	elif "dodge" in pressed and stamina > 1.0 and is_on_floor():
		_start_dodge(dir)
	elif "jump" in pressed and is_on_floor() and stamina > 1.0:
		velocity.y = JUMP_V
		_spend(8.0)
		anim.act("jump")
		Fx.sfx(self, ["cloth1", "cloth3"], global_position, -6.0)
	elif "potion" in pressed and potions > 0:
		potions -= 1
		potions_changed.emit(potions)
		_healed = false
		_play("drink")
		_set_state("drink", false)
		Fx.sfx(self, "metalPot1", global_position, -6.0)
	elif "interact" in pressed:
		interact_requested.emit()
	elif "block" in held and stamina > 1.0:
		_set_state("block")


func _regen(dt: float) -> void:
	_stam_delay -= dt
	_poise_delay -= dt
	if _stam_delay <= 0.0 and state in ["free", "block", "drink", "action"] and not _sprinting:
		stamina = minf(max_stamina, stamina + (16.0 if state == "block" else 38.0) * dt)
	if _poise_delay <= 0.0:
		poise = minf(max_poise, poise + 12.0 * dt)
	stamina_changed.emit(stamina, max_stamina)
	_trauma = maxf(0.0, _trauma - dt * 2.2)


func _spend(n: float) -> void:
	stamina -= n
	_stam_delay = 0.6
	stamina_changed.emit(stamina, max_stamina)


func _set_state(s: String, reset_act: bool = true) -> void:
	state = s
	state_t = 0.0
	if s == "free":
		_combo = 0
	if reset_act and s in ["free", "block"]:
		_act_name = ""


func _play(nm: String) -> Dictionary:
	_act = anim.act(nm)
	_act_name = nm
	_act_t = 0.0
	_hit_i = 0
	action_started.emit(nm)
	return _act


# ---------------------------------------------------------------- attacks

func _start_attack(nm: String, dir: Vector3) -> void:
	var mv: Dictionary = MOVES[nm]
	_spend(float(mv["stam"]) * float(_weapon()["stam"]))
	_aim = lock_target if lock_target != null else _soft_target(dir)
	if _aim != null:
		anim.face(_aim.global_position - global_position, true)
	elif dir.length() > 0.2:
		anim.face(dir, true)
	_play(nm)
	_set_state("attack", false)
	_hit_any = false
	if nm.begins_with("light"):
		_combo = int(nm.right(1))


# Nearest enemy in front (or in the stick direction) within a few metres: light auto-aim for touch players.
func _soft_target(dir: Vector3) -> Node3D:
	var fwd: Vector3 = dir if dir.length() > 0.2 else _facing()
	var best: Node3D = null
	var best_s: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _alive(e):
			continue
		var to: Vector3 = (e as Node3D).global_position - global_position
		to.y = 0
		var d: float = to.length()
		if d > 4.5:
			continue
		var ang: float = fwd.angle_to(to.normalized()) if d > 0.01 else 0.0
		if ang > deg_to_rad(80.0):
			continue
		var s: float = d + ang * 2.5
		if s < best_s:
			best_s = s
			best = e
	return best


# Extra travel before the first hit so swings close small gaps to the target.
func _lunge(_dt: float) -> Vector3:
	if _aim == null or not _alive(_aim) or _hit_i > 0:
		return Vector3.ZERO
	var hits: Array = _act["hit"]
	if hits.is_empty() or _act_t > float(hits[0]):
		return Vector3.ZERO
	var to: Vector3 = _aim.global_position - global_position
	to.y = 0
	var gap: float = to.length() - _radius_of(_aim) - float(_weapon()["reach"]) * 0.7
	if gap <= 0.0:
		return Vector3.ZERO
	var left: float = maxf(0.08, float(hits[0]) - _act_t)
	return to.normalized() * minf(4.5, gap / left)


func _attack_hits() -> void:
	var hits: Array = _act["hit"]
	while _hit_i < hits.size() and _act_t >= float(hits[_hit_i]):
		_hit_i += 1
		_melee_hit()


func _melee_hit() -> void:
	var w: Dictionary = _weapon()
	var mv: Dictionary = MOVES.get(_act_name, MOVES["light1"])
	var fwd: Vector3 = _facing()
	var reach: float = float(w["reach"]) * float(mv["reach"])
	Fx.sfx(self, w["swing"], global_position + Vector3(0, 1.2, 0), -4.0, 0.15)
	var landed: bool = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _alive(e):
			continue
		var en: Node3D = e
		var to: Vector3 = en.global_position - global_position
		var dy: float = to.y
		to.y = 0
		var d: float = to.length() - _radius_of(en)
		if d > reach or absf(dy) > 2.4:
			continue
		if d > 0.4 and rad_to_deg(fwd.angle_to(to.normalized())) > float(w["arc"]):
			continue
		var dmg: float = float(w["dmg"]) * float(mv["mult"]) * power * randf_range(0.92, 1.08)
		var kind: String = mv["kind"]
		if en.has_method("is_open") and en.call("is_open"):
			dmg *= 1.8
			kind = "riposte"
		var r: Dictionary = Fx.deal(self, en, dmg, kind)
		var res: String = String(r.get("result", "hit"))
		if res == "ignored" or res == "":
			continue
		landed = true
		var th: float = float(en.get("target_height")) if en.get("target_height") != null else 1.2
		var at: Vector3 = en.global_position + Vector3(0, th * 0.75, 0) - to.normalized() * _radius_of(en) * 0.8
		var amount: float = float(r.get("damage", dmg))
		hit_landed.emit(en, amount, res)
		if res == "blocked":
			Fx.sparks(self, at, Color(0.85, 0.85, 1.0), 10)
			Fx.sfx(self, "impactPlate_heavy_002", at, 0.0)
			Fx.number(self, at + Vector3(0, 0.5, 0), "bloqueou", Color(0.75, 0.75, 0.8))
			shake(0.25)
			Fx.hit_stop(self, 0.05)
		else:
			var big: bool = kind != "light"
			Fx.sparks(self, at, Color(1.0, 0.65, 0.3) if big else Color(1.0, 0.85, 0.55), 18 if big else 12)
			Fx.sfx(self, w["impact"], at, 0.0)
			Fx.number(self, at + Vector3(0, 0.5, 0), str(int(round(amount))), Color(1.0, 0.6, 0.2) if kind == "riposte" else (Color(1, 0.88, 0.6) if big else Color.WHITE), big)
			if kind == "riposte":
				Fx.number(self, at + Vector3(0, 0.9, 0), "CRÍTICO!", Color(1.0, 0.35, 0.2), true)
			shake(0.35 if big else 0.18)
			Fx.hit_stop(self, float(mv["stop"]) * (1.8 if kind == "riposte" else 1.0))
	_hit_any = _hit_any or landed


func _sample_trail() -> void:
	var sk: Skeleton3D = character.get_meta("skeleton")
	var prop: Node3D = sk.get_node_or_null("WeaponR/Prop")
	if prop != null:
		if _tip_len < 0.0:
			_tip_len = 0.6
			for mi in prop.find_children("*", "MeshInstance3D", true, false):
				var ab: AABB = (mi as MeshInstance3D).get_aabb()
				_tip_len = maxf(_tip_len, (ab.position.y + ab.size.y) * (mi as MeshInstance3D).transform.basis.get_scale().y)
		var xf: Transform3D = prop.global_transform
		_trail.color = Color(1.0, 0.92, 0.75, 0.75)
		_trail.sample(xf * Vector3(0, _tip_len * 0.3, 0), xf * Vector3(0, _tip_len, 0))
	else:
		var hand: Transform3D = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_r"))
		var hand_l: Transform3D = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_l"))
		var h: Transform3D = hand if _act_name in ["light2", "light4", "heavy"] else hand_l
		_trail.color = Color(1.0, 0.85, 0.6, 0.45)
		_trail.sample(h.origin, h.origin + (h.origin - global_position - Vector3(0, 1.2, 0)).normalized() * 0.18)


func _start_dodge(dir: Vector3) -> void:
	var nm: String = "roll"
	if dir.length() < 0.2:
		nm = "backstep"
		if lock_target != null:
			anim.face(lock_target.global_position - global_position, true)
	else:
		nm = "dodge" if lock_target != null else "roll"
		anim.face(dir, true)
	_spend(DODGE_COST[nm])
	_play(nm)
	_set_state("dodge", false)
	Fx.sfx(self, ["cloth1", "cloth3"], global_position, -3.0)
	Fx.dust(self, global_position, 6, 0.4)


func _invulnerable() -> bool:
	if state == "dodge" or (state == "down" and _act_name == "getup"):
		var iv: Vector2 = _act.get("invuln", Vector2.ZERO)
		return _act_t >= iv.x and _act_t <= iv.y
	return false


# Plays a non-combat action for main (interact, open_chest, pickup, talk, cheer, sit, cast...). Returns its length.
func perform(action: String) -> float:
	if state == "dead":
		return 0.0
	var a: Dictionary = _play(action)
	_set_state("action", false)
	return float(a.get("length", 0.0))


# ---------------------------------------------------------------- receiving damage

func take_hit(amount: float, source: Node, kind: String = "light") -> Dictionary:
	if state == "dead":
		return {"result": "ignored", "damage": 0.0}
	if _invulnerable():
		Fx.text(self, global_position + Vector3(0, 2.1, 0), "esquiva", Color(0.7, 0.9, 1.0), 48)
		return {"result": "dodged", "damage": 0.0}
	var from_front: bool = true
	if source is Node3D and is_instance_valid(source):
		var to: Vector3 = (source as Node3D).global_position - global_position
		to.y = 0
		from_front = to.length() < 0.05 or _facing().dot(to.normalized()) > 0.2
	var chest: Vector3 = global_position + Vector3(0, 1.3, 0)
	if state == "block" and from_front and kind != "fire":
		if state_t < PARRY_WINDOW:
			_play("parry")
			_set_state("hit", false)
			Fx.sparks(self, chest + _facing() * 0.5, Color(0.8, 0.9, 1.0), 22)
			Fx.sfx(self, "impactPlate_heavy_002", chest, 3.0)
			Fx.number(self, chest + Vector3(0, 0.8, 0), "APARADO!", Color(0.6, 0.9, 1.0), true)
			Fx.hit_stop(self, 0.12)
			shake(0.3)
			if kind != "projectile" and source != null and source.has_method("on_parried"):
				source.call("on_parried", self)
			hurt.emit(0.0, source, "parried")
			return {"result": "parried", "damage": 0.0}
		var cost: float = amount * (0.7 if has_shield() else 1.3)
		_spend(cost)
		if stamina > 0.0:
			var chip: float = amount * (0.0 if has_shield() else 0.15) * defense
			hp -= chip
			hp_changed.emit(hp, max_hp)
			_play("block_hit")
			_set_state("block", false)
			state_t = PARRY_WINDOW  # no parry from a held block that just took a hit
			Fx.sparks(self, chest + _facing() * 0.45, Color(0.9, 0.9, 1.0), 10)
			Fx.sfx(self, "impactPlate_heavy_000", chest, 0.0)
			shake(0.2)
			hurt.emit(chip, source, "blocked")
			if hp <= 0.0:
				_die()
			return {"result": "blocked", "damage": chip}
		Fx.number(self, chest + Vector3(0, 0.8, 0), "GUARDA QUEBRADA", Color(1.0, 0.5, 0.3), true)
		amount *= 0.6
		kind = "heavy"
	var dmg: float = amount * defense
	hp -= dmg
	hp_changed.emit(hp, max_hp)
	Fx.number(self, chest + Vector3(0, 0.6, 0), "-%d" % int(round(dmg)), Color(1.0, 0.3, 0.25))
	Fx.sfx(self, ["impactPunch_heavy_000", "impactPunch_heavy_001"], chest, 0.0)
	Fx.sparks(self, chest, Color(1.0, 0.4, 0.3), 8)
	shake(0.5 if kind == "heavy" else 0.32)
	hurt.emit(dmg, source, "hit")
	if hp <= 0.0:
		_die()
		return {"result": "dead", "damage": dmg}
	if kind == "fire":
		return {"result": "hit", "damage": dmg}  # burns: no stagger
	poise -= dmg * (1.6 if kind == "heavy" else 1.0)
	_poise_delay = 1.2
	if dmg >= max_hp * 0.22 and kind == "heavy":
		_knockdown(source)
	elif poise <= 0.0 or kind == "heavy":
		poise = max_poise
		_play("hit_heavy")
		_set_state("hit", false)
	elif state == "attack" and _act_name in ["heavy", "light4", "sprint_attack"]:
		anim.proc.flinch(0.3)  # hyper armour on big swings: flinch, keep swinging
	elif state in ["free", "attack", "block", "drink", "action", "hit"]:
		_play("hit_light")
		_set_state("hit", false)
	return {"result": "hit", "damage": dmg}


func _knockdown(source: Node) -> void:
	if source is Node3D:
		anim.face((source as Node3D).global_position - global_position, true)
	_play("knockdown")
	_set_state("down", false)
	_getup_at = 1.1
	Fx.dust(self, global_position, 10, 0.6)


func _die() -> void:
	hp = 0.0
	hp_changed.emit(hp, max_hp)
	_play("death")
	_set_state("dead", false)
	_set_lock(null)
	Fx.sfx(self, "jingle_death", global_position, -2.0)
	died.emit()


func revive(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	refill()
	_play("getup")
	_set_state("down", false)
	_getup_at = 0.0
	revived.emit()


func heal(n: float) -> void:
	hp = minf(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)
	Fx.number(self, global_position + Vector3(0, 2.0, 0), "+%d" % int(n), Color(0.55, 1.0, 0.5))


func refill() -> void:
	hp = max_hp
	stamina = max_stamina
	potions = max_potions
	hp_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	potions_changed.emit(potions)


# ---------------------------------------------------------------- lock-on and camera

func _alive(e: Variant) -> bool:
	return e != null and is_instance_valid(e) and e is Node3D and not bool((e as Node).get("dead"))


func _radius_of(e: Node3D) -> float:
	var r: Variant = e.get("radius")
	return float(r) if r != null else 0.45


func _facing() -> Vector3:
	var z: Vector3 = character.global_basis.z
	return Vector3(z.x, 0, z.z).normalized()


func _toggle_lock() -> void:
	if lock_target != null:
		_set_lock(null)
		return
	var best: Node3D = null
	var best_s: float = INF
	var fwd: Vector3 = _cam_dirs()[0]
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _alive(e):
			continue
		var to: Vector3 = (e as Node3D).global_position - global_position
		var d: float = to.length()
		if d > LOCK_RANGE:
			continue
		var s: float = d + fwd.angle_to(Vector3(to.x, 0, to.z).normalized()) * 8.0
		if s < best_s:
			best_s = s
			best = e
	_set_lock(best)


func _set_lock(t: Node3D) -> void:
	if t == lock_target:
		return
	lock_target = t
	lock_changed.emit(t)


func _check_lock() -> void:
	if lock_target != null and (not _alive(lock_target) or lock_target.global_position.distance_to(global_position) > LOCK_RANGE + 4.0):
		_set_lock(null)


func shake(amount: float) -> void:
	_trauma = minf(1.0, maxf(_trauma, amount))


func _update_camera(dt: float, move_dir: Vector3) -> void:
	_look_idle += dt
	var head: Vector3 = global_position + Vector3(0, 1.55, 0)
	var cp: Vector3 = cam_root.global_position
	cp.x = head.x
	cp.z = head.z
	cp.y = lerpf(cp.y, head.y, 1.0 - exp(-dt * 10.0))
	cam_root.global_position = cp
	if lock_target != null:
		var to: Vector3 = lock_target.global_position - global_position
		cam_yaw = lerp_angle(cam_yaw, atan2(-to.x, -to.z), 1.0 - exp(-dt * 6.0))
		var flat: float = Vector2(to.x, to.z).length()
		var want_pitch: float = clampf(-0.28 - atan2(maxf(0.0, -to.y), flat), -0.8, -0.1)
		cam_pitch = lerpf(cam_pitch, want_pitch, 1.0 - exp(-dt * 3.0))
		spring.spring_length = lerpf(spring.spring_length, 4.9, 1.0 - exp(-dt * 3.0))
		_marker.visible = true
		var th: Variant = lock_target.get("target_height")
		_marker.global_position = lock_target.global_position + Vector3(0, (float(th) if th != null else 1.3) + 0.45, 0)
	else:
		_marker.visible = false
		spring.spring_length = lerpf(spring.spring_length, 4.4, 1.0 - exp(-dt * 3.0))
		# drift behind the hero while running and not steering the camera by hand
		if _look_idle > 1.5 and move_dir.length() > 0.5 and state == "free":
			var behind: float = atan2(-move_dir.x, -move_dir.z)
			var side: float = absf(sin(angle_difference(cam_yaw, behind)))
			cam_yaw = lerp_angle(cam_yaw, behind, (1.0 - exp(-dt * 0.9)) * side)
	cam_root.rotation = Vector3(cam_pitch, cam_yaw, 0)
	var s: float = _trauma * _trauma
	camera.h_offset = randf_range(-1.0, 1.0) * s * 0.3
	camera.v_offset = randf_range(-1.0, 1.0) * s * 0.3


func _footsteps(dt: float, spd: float) -> void:
	if not is_on_floor() or spd < 0.8 or state != "free" or swimming:
		return
	_step_t -= dt * spd / 3.0
	if _step_t <= 0.0:
		_step_t = 0.55
		Fx.sfx(self, STEPS, global_position, -14.0 if spd < 6.0 else -10.0)
		if _sprinting:
			Fx.dust(self, global_position, 3, 0.3)
