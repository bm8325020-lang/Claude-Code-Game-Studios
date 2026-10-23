# PROTOTYPE - NOT FOR PRODUCTION
# Enemy: one body for every camp kind of the combat contract (wolf_imp, bandit, bandit_archer, puglin, possessed,
# knight). Stats, looks and attacks are data in KINDS, scaled by the camp level. Behaviour: patrol around home,
# notice the hero (and wake the camp), telegraphed attacks (slow wind-up + a glint, then a fast strike), poise and
# stagger (parry and poise break open a riposte window), flee at low life (bandits), hit-and-run (puglins), keep
# distance and throw (archers), raise the shield (knights), at most MAX_ATTACKERS closing in at once while the rest
# hold a ring around the hero, and a leash back home.
#
#   var e := Enemy.spawn(parent, "bandit", camp_level, pos)      # or Enemy.new(); e.setup(kind, level); add_child
#
# Signals: died(enemy), noticed(enemy), damaged(enemy, amount).
# Public: kind, level, hp, max_hp, dead, radius, target_height, xp, display_name, home, state.
# take_hit(amount, source, kind) -> {result: "hit"|"blocked"|"dead"|"ignored", damage}; on_parried(by); is_open().
# Damage dealt goes through Fx.deal (main.damage when the scene has it). Groups: "enemies". Collision layer 3,
# mask 1 (world) + 2 (hero) + 3. The hero is the first node in group "hero".
# Every kind is a CharacterKit character (Imp and Puglin bodies included); attacks are AnimLib's authored actions
# with hit frames read from that character's library (AnimLib.info), raw UAL clips use the "hit" given here.
class_name Enemy
extends CharacterBody3D

signal died(enemy: Enemy)
signal noticed(enemy: Enemy)
signal damaged(enemy: Enemy, amount: float)

const GRAVITY: float = 22.0
const MAX_ATTACKERS: int = 2
# hit: clip seconds of the strike for raw clips (authored clips read AnimLib.INFO); slow: wind-up playback speed.
const KINDS: Dictionary = {
	"wolf_imp": {"name": "Diabrete de Brasa", "look": {"body": "Imp", "tint": Color(1.0, 0.78, 0.62)}, "scale": 0.72,
		"hp": 34.0, "dmg": 7.0, "speed": 4.6, "poise": 12.0, "radius": 0.45, "height": 1.05, "reach": 1.2, "notice": 14.0,
		"xp": 10, "pack": true, "idle": "Idle", "walk": "Loco_Walk", "run": "Loco_Jog", "hurt": "hit_light", "stagger": "hit_heavy", "die": "death",
		"attacks": [{"anim": "light1", "slow": 0.45, "lunge": 4.0, "mult": 1.0},
			{"anim": "heavy", "slow": 0.5, "lunge": 3.0, "mult": 1.4, "kind": "heavy"}]},
	"bandit": {"name": "Sem-Terra", "scale": 1.0,
		"look": {"body": "Male", "outfit": "Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.78, 0.64, 0.5), "weapon": "Axe_Bronze"},
		"hp": 60.0, "dmg": 11.0, "speed": 3.6, "poise": 25.0, "radius": 0.4, "height": 1.75, "reach": 1.8, "notice": 13.0,
		"xp": 18, "flee_at": 0.5, "flee_chance": 0.5, "idle": "Idle", "combat_idle": "Sword_Idle", "walk": "Loco_Walk", "run": "Loco_Jog",
		"hurt": "hit_light", "stagger": "hit_heavy", "die": "death",
		"attacks": [{"anim": "light1", "slow": 0.5, "lunge": 2.5, "mult": 1.0}, {"anim": "heavy", "slow": 0.45, "lunge": 2.0, "mult": 1.6, "kind": "heavy"}]},
	"bandit_archer": {"name": "Atirador Sem-Terra", "scale": 1.0,
		"look": {"body": "Female", "outfit": "Ranger", "hood": true, "tint": Color(0.7, 0.66, 0.52), "weapon": ""},
		"hp": 42.0, "dmg": 9.0, "speed": 3.4, "poise": 15.0, "radius": 0.4, "height": 1.7, "reach": 1.3, "notice": 18.0,
		"xp": 16, "ranged": true, "keep": Vector2(6.0, 12.0), "flee_at": 0.3, "flee_chance": 0.4,
		"idle": "Idle", "walk": "Loco_Walk", "run": "Loco_Jog", "hurt": "hit_light", "stagger": "hit_heavy", "die": "death",
		"attacks": [{"anim": "OverhandThrow", "hit": 0.62, "slow": 0.55, "lunge": 0.0, "mult": 1.0, "kind": "projectile", "ranged": true},
			{"anim": "light1", "slow": 0.6, "lunge": 1.5, "mult": 0.8, "melee_only": true}]},
	"puglin": {"name": "Pugo", "look": {"body": "Puglin"}, "scale": 1.0,
		"hp": 30.0, "dmg": 6.0, "speed": 4.2, "poise": 10.0, "radius": 0.4, "height": 0.9, "reach": 1.0, "notice": 12.0,
		"xp": 9, "pack": true, "hit_run": true, "idle": "Idle", "walk": "Loco_Walk", "run": "Loco_Jog", "hurt": "hit_light", "stagger": "hit_heavy", "die": "death",
		"attacks": [{"anim": "light2", "slow": 0.4, "lunge": 4.0, "mult": 1.0}, {"anim": "light4", "slow": 0.45, "lunge": 3.5, "mult": 1.3}]},
	"possessed": {"name": "Insone", "scale": 1.0,
		"look": {"body": "Male", "outfit": "Peasant", "hair": "Hair_Long", "hair_color": Color(0.45, 0.43, 0.42), "tint": Color(0.58, 0.6, 0.68)},
		"hp": 85.0, "dmg": 13.0, "speed": 1.7, "poise": 45.0, "radius": 0.4, "height": 1.75, "reach": 1.5, "notice": 20.0,
		"xp": 22, "armor": true, "idle": "Zombie_Idle", "walk": "Zombie_Walk_Fwd", "run": "Zombie_Walk_Fwd", "walk_speed": 1.1,
		"hurt": "hit_light", "stagger": "hit_heavy", "die": "death",
		"attacks": [{"anim": "Zombie_Scratch", "hit": 0.7, "slow": 0.5, "lunge": 1.5, "mult": 1.0}]},
	"knight": {"name": "Guarda da Vigília", "scale": 1.04,
		"look": {"body": "Male", "outfit": "Ranger", "pauldrons": true, "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.5, 0.47, 0.52), "weapon": "Sword_Bronze", "shield": "Shield_Wooden"},
		"hp": 140.0, "dmg": 14.0, "speed": 3.2, "poise": 55.0, "radius": 0.42, "height": 1.8, "reach": 2.0, "notice": 15.0,
		"xp": 45, "armor": true, "guard": 0.25, "idle": "Idle", "combat_idle": "Sword_Idle", "walk": "Loco_Walk", "run": "Loco_Jog",
		"hurt": "hit_light", "stagger": "hit_heavy", "die": "death", "block": "block_hit", "guard_idle": "Idle_Shield",
		"attacks": [{"anim": "light1", "slow": 0.55, "lunge": 2.5, "mult": 1.0, "next": 1}, {"anim": "light2", "slow": 0.9, "lunge": 2.0, "mult": 1.0, "chain_only": true},
			# heavy swings wind up longer than other enemies' (slow 0.45 -> 0.33): the watchtower knights were a third of all deaths
			{"anim": "heavy", "slow": 0.33, "lunge": 2.5, "mult": 1.7, "kind": "heavy"}, {"anim": "sprint_attack", "slow": 0.45, "lunge": 1.0, "mult": 1.4, "kind": "heavy", "far": true}]},
}

var kind: String = "bandit"
var level: int = 1
var display_name: String = ""
var hp: float = 60.0
var max_hp: float = 60.0
var dmg: float = 10.0
var speed: float = 3.5
var poise: float = 20.0
var max_poise: float = 20.0
var radius: float = 0.4
var target_height: float = 1.7
var reach: float = 1.5
var xp: int = 10
var dead: bool = false
var home: Vector3 = Vector3.ZERO
var state: String = "idle"
var engaging: bool = false
var heals_home: bool = true
var data: Dictionary = {}
var model: Node3D
var ap: AnimationPlayer
var _lib: AnimationLibrary

var t: float = 0.0
var _yaw: float = 0.0
var _hero: Node3D = null
var _cooldown: float = 1.0
var _atk: Dictionary = {}
var _atk_hit: float = 0.0
var _atk_end: float = 0.0
var _atk_done: bool = false
var _glinted: bool = false
var _state_len: float = 0.0
var _wander: Vector3 = Vector3.ZERO
var _wander_t: float = 0.0
var _slot: float = 0.0
var _slot_t: float = 0.0
var _flinches: float = 0.0
var _flee_rolled: bool = false
var _loco_clip: String = ""
var _open: bool = false
var _sink_t: float = -1.0


static func spawn(parent: Node, k: String, lvl: int, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.setup(k, lvl)
	parent.add_child(e)
	e.global_position = pos
	e.home = pos
	return e


func setup(k: String, lvl: int) -> void:
	kind = k
	level = maxi(1, lvl)
	data = KINDS.get(k, KINDS["bandit"])
	_apply_stats()


func _apply_stats() -> void:
	var lv: float = float(level - 1)
	display_name = data["name"]
	max_hp = float(data["hp"]) * (1.0 + 0.18 * lv)  # 0.3 made late enemies damage sponges (bot: ~20 hits per knight)
	hp = max_hp
	dmg = float(data["dmg"]) * (1.0 + 0.15 * minf(lv, 9.0) + 0.10 * maxf(lv - 9.0, 0.0))  # gentler past level 10
	max_poise = float(data["poise"]) * (1.0 + 0.1 * lv)
	poise = max_poise
	speed = float(data["speed"])
	radius = float(data["radius"])
	target_height = float(data["height"])
	reach = float(data["reach"])
	xp = int(round(float(data["xp"]) * (1.0 + 0.25 * lv)))


func _ready() -> void:
	if data.is_empty():
		setup(kind, level)
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(target_height, radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	_build_model()
	if home == Vector3.ZERO:
		home = global_position
	_yaw = randf() * TAU
	_slot = randf() * TAU
	_cooldown = randf_range(0.6, 1.4)
	_play(data["idle"], 0.0)


func _build_model() -> void:
	var lk: Dictionary = (data["look"] as Dictionary).duplicate()
	if kind == "possessed" or kind == "bandit":
		lk["body"] = "Female" if randf() < 0.35 else "Male"
		if lk["body"] == "Female":
			lk["beard"] = false
			lk["hair"] = "Hair_Buns" if kind == "bandit" else "Hair_Long"
	model = CharacterKit.make(lk)
	ap = model.get_meta("anim")
	_lib = ap.get_animation_library("")
	model.scale = Vector3.ONE * float(data["scale"])
	add_child(model)


func _play(clip: String, blend: float = -1.0, spd: float = 1.0) -> void:
	if ap == null or not ap.has_animation(clip):
		return
	ap.speed_scale = 1.0
	ap.play(clip, blend, spd)
	_loco_clip = ""


func hero() -> Node3D:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("hero") as Node3D
	return _hero


func _hero_alive() -> bool:
	var h: Node3D = hero()
	return h != null and String(h.get("state")) != "dead"


# ---------------------------------------------------------------- loop

func _physics_process(dt: float) -> void:
	if dt <= 0.0:
		return
	if dead:
		_dead_update(dt)
		return
	t += dt
	_cooldown -= dt
	_flinches = maxf(0.0, _flinches - dt * 0.8)
	poise = minf(max_poise, poise + max_poise * 0.12 * dt) if state != "stagger" else poise
	var want := Vector3.ZERO
	var face_hero: bool = false
	var h: Node3D = hero()
	var to := Vector3.ZERO
	var dist: float = 999.0
	if h != null:
		to = h.global_position - global_position
		to.y = 0
		dist = to.length()
	engaging = false
	match state:
		"idle":
			want = _patrol(dt)
			if _hero_alive() and _sees(to, dist):
				notice()
		"alert":
			face_hero = true
			if t > 0.55:
				_set_state("combat")
		"combat":
			var r: Array = _combat(dt, to, dist)
			want = r[0]
			face_hero = r[1]
		"attack":
			engaging = true
			want = _attack_update(dt, to, dist)
		"hurt":
			if t > _state_len:
				_set_state("combat")
		"stagger":
			if t > _state_len:
				_open = false
				poise = max_poise
				_set_state("combat")
		"guard":
			face_hero = true
			if t > _state_len or dist > 6.0:
				_set_state("combat")
			elif dist < reach + radius + 0.2 and _cooldown <= 0.0:
				_start_attack(_choose_attack(dist))
		"retreat":
			want = -to.normalized() * speed * 0.8
			face_hero = true
			if t > _state_len:
				_set_state("combat")
		"flee":
			want = -to.normalized() * speed * 1.1
			if dist > 18.0:
				_set_state("cower")
		"cower":
			face_hero = true
			if dist < 5.0:
				_set_state("combat")
		"return":
			var th: Vector3 = home - global_position
			th.y = 0
			want = th.normalized() * speed * 0.8
			if heals_home and dist > 15.0:  # no healing in the player's face while they chase it
				hp = minf(max_hp, hp + max_hp * 0.2 * dt)
			if th.length() < 1.0:
				_set_state("idle")
		_:
			var r2: Array = _custom_state(dt, to, dist)
			want = r2[0]
			face_hero = r2[1]
	if state in ["combat", "idle", "retreat", "flee", "return"]:
		want += _separation() * 2.0
	# facing
	var face_dir := Vector3.ZERO
	if face_hero and dist < 999.0:
		face_dir = to
	elif state != "attack" and Vector2(want.x, want.z).length() > 0.3:
		face_dir = want
	if face_dir.length() > 0.01:
		var rate: float = 6.0 if state != "attack" else 10.0
		_yaw = lerp_angle(_yaw, atan2(face_dir.x, face_dir.z), 1.0 - exp(-dt * rate))
	model.rotation.y = _yaw
	# body
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3(want.x, 0, want.z), 18.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	_loco_anim(hv)


func _set_state(s: String, secs: float = 0.0) -> void:
	state = s
	t = 0.0
	_state_len = secs
	if s in ["combat", "idle", "flee", "return", "retreat", "cower"]:
		_loco_clip = ""  # resume locomotion clips


func _sees(to: Vector3, dist: float) -> bool:
	var range_: float = float(data["notice"])
	if dist > range_:
		return false
	if dist < range_ * 0.45 or kind == "possessed":
		return true
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	return fwd.angle_to(to.normalized()) < deg_to_rad(65.0)


# Becomes aware of the hero and wakes the rest of the camp nearby.
func notice(spread: bool = true) -> void:
	if dead or state not in ["idle", "return", "cower"]:
		return
	_set_state("alert")
	Fx.text(self, global_position + Vector3(0, target_height + 0.5, 0), "!", Color(1.0, 0.8, 0.3), 96, 0.4, 0.6)
	noticed.emit(self)
	if spread:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e is Enemy and (e as Enemy).global_position.distance_to(global_position) < 14.0:
				(e as Enemy).notice(false)


func _patrol(dt: float) -> Vector3:
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = randf_range(3.0, 6.0)
		var a: float = randf() * TAU
		_wander = home + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 4.0)
	var d: Vector3 = _wander - global_position
	d.y = 0
	if d.length() < 0.5 or _wander_t > 4.5:
		return Vector3.ZERO  # stand a moment, then walk
	return d.normalized() * 1.1


func _engaged_count() -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and bool(e.get("engaging")):
			n += 1
	return n


func _combat(dt: float, to: Vector3, dist: float) -> Array:
	if not _hero_alive() or (global_position.distance_to(home) > 45.0 and dist > 8.0):
		_set_state("return")
		return [Vector3.ZERO, false]
	var dirv: Vector3 = to.normalized() if dist > 0.01 else Vector3.FORWARD
	var touch: float = reach + radius + 0.35
	if data.get("ranged", false):
		var keep: Vector2 = data["keep"]
		engaging = false
		if dist < 2.6 and _cooldown <= 0.0:
			_start_attack(_pick(func(a: Dictionary) -> bool: return a.get("melee_only", false)))
			return [Vector3.ZERO, true]
		if dist < keep.x and global_position.distance_to(home) < 8.0:  # backs off a little, then stands its ground
			return [-dirv * speed * 0.45, true]
		if dist < keep.x:
			if _cooldown <= 0.0 and dist < 3.2:
				_start_attack(_pick(func(a: Dictionary) -> bool: return a.get("melee_only", false)))
			return [dirv * 0.0, true]
		if dist > keep.y:
			return [dirv * speed, false]
		if _cooldown <= 0.0:
			_start_attack(_pick(func(a: Dictionary) -> bool: return a.get("ranged", false)))
		return [Vector3.ZERO, true]
	# knights raise the shield when the hero is close and swinging
	if data.has("guard") and dist < 4.0 and _cooldown > 0.0 and String(hero().get("state")) == "attack" and randf() < float(data["guard"]) * dt * 6.0:
		_set_state("guard", randf_range(1.0, 1.8))
		_loco_clip = ""
		_play(data["guard_idle"], 0.1)
		return [Vector3.ZERO, true]
	var wants_in: bool = _cooldown <= 0.0 and (_engaged_count() < MAX_ATTACKERS or self is Boss)
	if wants_in:
		engaging = true
		if dist <= touch:
			_start_attack(_choose_attack(dist))
			return [Vector3.ZERO, true]
		for a in data["attacks"]:
			if (a as Dictionary).get("far", false) and dist > 4.0 and dist < 7.5 and randf() < 0.02:
				_start_attack(a)
				return [Vector3.ZERO, true]
		return [dirv * speed, dist < 3.0]
	# wait on a ring around the hero, shuffling between slots
	_slot_t -= dt
	if _slot_t <= 0.0:
		_slot_t = randf_range(1.5, 3.0)
		_slot += randf_range(-0.9, 0.9)
	var ring: float = 3.4 + radius
	var spot: Vector3 = hero().global_position + Vector3(sin(_slot), 0, cos(_slot)) * ring
	var d: Vector3 = spot - global_position
	d.y = 0
	if dist < ring - 0.8:
		return [-dirv * speed * 0.5, true]
	if d.length() < 0.6:
		return [Vector3.ZERO, true]
	return [d.normalized() * minf(speed, 1.2 + d.length()), dist < 6.0]


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var d: Vector3 = global_position - (e as Node3D).global_position
		d.y = 0
		var l: float = d.length()
		var min_d: float = radius + float(e.get("radius")) + 0.6
		if l < min_d and l > 0.001:
			push += d / l * (min_d - l)
	return push


func _pick(filter: Callable) -> Dictionary:
	var opts: Array = (data["attacks"] as Array).filter(filter)
	return opts.pick_random() if not opts.is_empty() else data["attacks"][0]


# Which attack to throw now (Boss overrides).
func _choose_attack(_dist: float) -> Dictionary:
	return _pick(func(a: Dictionary) -> bool: return not a.get("ranged", false) and not a.get("chain_only", false) and not a.get("far", false))


# Animation speed multiplier for attacks (Boss overrides per phase).
func _attack_speed() -> float:
	return 1.0


func _start_attack(a: Dictionary) -> void:
	_atk = a
	var clip: String = a["anim"]
	var info: Dictionary = AnimLib.info(_lib, clip)
	if not info.is_empty():
		var hits: Array = info["hit"]
		_atk_hit = float(hits[0]) if not hits.is_empty() else float(info["length"]) * 0.4
		_atk_end = float(info["length"])
	else:
		_atk_hit = float(a.get("hit", 0.4))
		_atk_end = ap.get_animation(clip).length if ap.has_animation(clip) else 1.0
	_atk_done = false
	_glinted = false
	_set_state("attack")
	_play(clip, 0.12)
	ap.speed_scale = float(a.get("slow", 0.6)) * _attack_speed()


func _attack_update(_dt: float, to: Vector3, dist: float) -> Vector3:
	var pos: float = ap.current_animation_position if ap.is_playing() else _atk_end
	var a: Dictionary = _atk
	var dirv: Vector3 = to.normalized() if dist > 0.01 else Vector3(sin(_yaw), 0, cos(_yaw))
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var want := Vector3.ZERO
	if not _atk_done:
		# track the hero through the wind-up, commit just before the strike (so a late roll sideways works)
		if pos < _atk_hit - 0.2:
			_yaw = lerp_angle(_yaw, atan2(dirv.x, dirv.z), 0.12)
		if not _glinted and pos >= _atk_hit - 0.42:
			_glinted = true
			_telegraph()
		if pos >= _atk_hit - 0.16:
			ap.speed_scale = 1.15 * _attack_speed()
			var gap: float = dist - radius - reach * 0.6
			if gap > 0.0 and float(a.get("lunge", 0.0)) > 0.0:
				want = fwd * minf(float(a["lunge"]), gap * 6.0)
		if pos >= _atk_hit:
			_atk_done = true
			_strike(a, to, dist)
	if pos >= _atk_end - 0.05 or not ap.is_playing():
		_cooldown = randf_range(1.2, 2.4) / maxf(0.5, _attack_speed())
		if a.has("next") and dist < reach + radius + 1.2 and _hero_alive():
			_start_attack(data["attacks"][int(a["next"])])
		elif data.get("hit_run", false):
			_set_state("retreat", randf_range(0.9, 1.5))
		else:
			_set_state("combat")
	return want


func _telegraph() -> void:
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var at: Vector3 = global_position + Vector3(0, target_height * 0.85, 0) + fwd * 0.35
	var heavy: bool = String(_atk.get("kind", "light")) == "heavy"
	Fx.glint(self, at, Color(1.0, 0.45, 0.2) if heavy else Color(1.0, 0.9, 0.6), 1.2 if heavy else 0.8)


func _strike(a: Dictionary, to: Vector3, dist: float) -> void:
	var h: Node3D = hero()
	if h == null:
		return
	var k: String = String(a.get("kind", "light"))
	var amount: float = dmg * float(a.get("mult", 1.0))
	if a.get("ranged", false):
		_throw(h, amount)
		return
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var aim_off: float = rad_to_deg(fwd.angle_to(to.normalized())) if dist > 0.01 else 0.0
	Fx.sfx(self, ["knifeSlice", "knifeSlice2"], global_position + Vector3(0, 1, 0), -6.0)
	if dist - 0.35 <= reach + radius and aim_off < 70.0 and absf(h.global_position.y - global_position.y) < 2.0:
		Fx.deal(self, h, amount, k)
	_after_strike(a)


# Hook for subclasses (the Boss leaves embers).
func _after_strike(_a: Dictionary) -> void:
	pass


func _throw(h: Node3D, amount: float) -> void:
	var start: Vector3 = global_position + Vector3(0, target_height * 0.9, 0) + Vector3(sin(_yaw), 0, cos(_yaw)) * 0.4
	var target: Vector3 = h.global_position + Vector3(0, 1.1, 0)
	var hv: Variant = h.get("velocity")
	var tt: float = start.distance_to(target) / 15.0
	if hv is Vector3:
		target += Vector3((hv as Vector3).x, 0, (hv as Vector3).z) * tt * 0.5
	var v: Vector3 = (target - start) / tt + Vector3(0, 0.5 * Stone.G * tt, 0)
	var s := Stone.new()
	s.owner_enemy = self
	s.amount = amount
	s.vel = v
	get_parent().add_child(s)
	s.global_position = start
	Fx.sfx(self, "cloth3", start, -4.0)


# ---------------------------------------------------------------- receiving damage

func take_hit(amount: float, source: Node, k: String = "light") -> Dictionary:
	if dead:
		return {"result": "ignored", "damage": 0.0}
	if state in ["idle", "return", "cower"]:
		notice()
	var front: bool = true
	if source is Node3D:
		var to: Vector3 = (source as Node3D).global_position - global_position
		to.y = 0
		front = to.length() < 0.05 or Vector3(sin(_yaw), 0, cos(_yaw)).dot(to.normalized()) > 0.3
	if state == "guard" and front and k != "riposte":
		poise -= amount * (2.2 if k == "heavy" else 1.2)  # light hits also wear the guard down (casual players rarely use heavy)
		if poise > 0.0:
			_play(data.get("block", "block_hit"), 0.05)
			_set_state("guard", maxf(0.6, _state_len - t))
			return {"result": "blocked", "damage": 0.0}
		Fx.text(self, global_position + Vector3(0, target_height + 0.6, 0), "GUARDA QUEBRADA", Color(1.0, 0.8, 0.3), 64)
		Fx.sfx(self, "impactPlate_heavy_001", global_position + Vector3(0, 1.2, 0), 2.0)  # the guard break should feel good
		_stagger(1.4)
		return {"result": "hit", "damage": 0.0}
	hp -= amount
	damaged.emit(self, amount)
	if hp <= 0.0:
		_die()
		return {"result": "dead", "damage": amount}
	_on_damaged()
	if dead or state in ["sleep", "phase"]:
		return {"result": "hit", "damage": amount}
	poise -= amount * (2.0 if k in ["heavy", "riposte"] else 1.0)
	if poise <= 0.0 and state != "stagger":
		Fx.text(self, global_position + Vector3(0, target_height + 0.6, 0), "ATORDOADO", Color(1.0, 0.85, 0.3), 60)
		_stagger(1.2)
	elif state == "attack" and (data.get("armor", false) or _flinches >= 2.5):
		pass  # armoured swing: takes the hit, keeps swinging
	elif state not in ["stagger", "flee"]:
		_flinches += 1.0
		_play(data["hurt"], 0.05, 1.2)
		_set_state("hurt", 0.38)
	if not _flee_rolled and hp < max_hp * float(data.get("flee_at", 0.0)):
		_flee_rolled = true
		if randf() < float(data.get("flee_chance", 0.0)):
			_set_state("flee")
			Fx.text(self, global_position + Vector3(0, target_height + 0.6, 0), "foge!", Color(0.9, 0.9, 0.7), 56)
	return {"result": "hit", "damage": amount}


# Hook for subclasses: states Enemy does not know (Boss salute, phase change, sleep). Returns [velocity, face_hero].
func _custom_state(_dt: float, _to: Vector3, _dist: float) -> Array:
	return [Vector3.ZERO, true]


# Hook for subclasses (Boss phases).
func _on_damaged() -> void:
	pass


func _stagger(secs: float) -> void:
	_open = true
	_play(data.get("stagger", data["hurt"]), 0.05, 0.8)
	_set_state("stagger", secs)
	engaging = false


# The hero parried this enemy's swing: long stagger, riposte window.
func on_parried(_by: Node) -> void:
	if dead:
		return
	poise = 0.0
	Fx.text(self, global_position + Vector3(0, target_height + 0.6, 0), "ABERTO!", Color(1.0, 0.85, 0.3), 64)
	_stagger(1.7)


func is_open() -> bool:
	return _open and state == "stagger"


func _die() -> void:
	hp = 0.0
	dead = true
	engaging = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	_set_state("dead")
	var chest: Vector3 = global_position + Vector3(0, target_height * 0.6, 0)
	if kind == "wolf_imp":
		# bursts into sparks that smell of bread
		Fx.embers(self, chest, 40)
		Fx.sfx(self, "fireball", chest, -4.0)
		model.visible = false
		_sink_t = 1.0
	else:
		_play(data["die"], 0.1)
		Fx.dust(self, global_position, 10, 0.6)
		_sink_t = 10.0
		if kind == "possessed":
			Fx.text(self, chest + Vector3(0, 0.6, 0), "Zzz", Color(0.75, 0.85, 1.0), 70, 1.2, 2.5)
	died.emit(self)


func _dead_update(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	if _sink_t > 0.0:
		_sink_t -= dt
		if _sink_t < 1.5:
			model.position.y -= dt * 0.6
		if _sink_t <= 0.0:
			queue_free()


# ---------------------------------------------------------------- locomotion clips

func _loco_anim(hv: Vector3) -> void:
	if state not in ["idle", "alert", "combat", "retreat", "flee", "cower", "return"]:
		return
	var v: float = hv.length()
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var back: bool = v > 0.2 and fwd.dot(hv / v) < -0.3
	var clip: String
	var rate: float = 1.0
	if v < 0.25:
		clip = data.get("combat_idle", data["idle"]) if state in ["combat", "alert", "retreat"] else data["idle"]
	elif v < 2.6 or String(data["run"]) == String(data["walk"]):
		clip = data["walk"]
		rate = v / float(data["walk_speed"]) if data.has("walk_speed") else _loco_rate(clip, v)
	else:
		clip = data["run"]
		rate = _loco_rate(clip, v)
	rate = clampf(rate, 0.5, 1.9) * (-1.0 if back else 1.0)
	if clip != _loco_clip:
		_loco_clip = clip
		if ap.has_animation(clip):
			ap.play(clip, 0.2)
	ap.speed_scale = rate if v >= 0.25 else 1.0


# Loco_* clips are one cycle per second: playback rate that makes the feet match ground speed v.
func _loco_rate(clip: String, v: float) -> float:
	var sc: float = float(data["scale"])
	return v / maxf(0.1, AnimLib.speed(_lib, clip) * sc * AnimLib.cycle(_lib, clip))


# A thrown stone (archers): ballistic, hurts the hero on contact, puffs dust on the ground.
class Stone extends Node3D:
	const G: float = 9.0
	var vel: Vector3 = Vector3.ZERO
	var amount: float = 8.0
	var owner_enemy: Node = null
	var life: float = 4.0

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.16
		sm.radial_segments = 8
		sm.rings = 4
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.42, 0.38)
		m.roughness = 0.9
		sm.material = m
		mi.mesh = sm
		add_child(mi)

	func _physics_process(dt: float) -> void:
		life -= dt
		var from: Vector3 = global_position
		vel.y -= G * dt
		var to: Vector3 = from + vel * dt
		var h: Node3D = get_tree().get_first_node_in_group("hero") as Node3D
		if h != null:
			var chest: Vector3 = h.global_position + Vector3(0, 1.0, 0)
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(chest, from, to)
			if closest.distance_to(chest) < 0.6 and String(h.get("state")) != "dead":
				if owner_enemy != null and is_instance_valid(owner_enemy):
					Fx.deal(owner_enemy, h, amount, "projectile")
				Fx.sparks(self, closest, Color(0.9, 0.8, 0.6), 6)
				queue_free()
				return
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() or life <= 0.0:
			Fx.dust(self, hit.get("position", to), 4, 0.3)
			Fx.sfx(self, "impactWood_medium_001", to, -10.0)
			queue_free()
			return
		global_position = to
