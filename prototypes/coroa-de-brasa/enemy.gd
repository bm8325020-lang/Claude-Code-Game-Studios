# PROTOTYPE - NOT FOR PRODUCTION
# A skeleton of the dungeon. It rises from the floor, then: melee ones walk up, show a red ring and strike;
# ranged ones keep their distance and shoot bolts; casters throw slow homing orbs and call minions. A bigger
# "elite" has more life and a glow. Bosses use the same body with extra moves (boss.gd).
extends CharacterBody3D

const Data = preload("res://data.gd")
const Rig = preload("res://rig.gd")
const Fx = preload("res://fx.gd")
const Projectile = preload("res://projectile.gd")

var main: Node
var kind := "minion"
var def: Dictionary
var model: Node3D
var ap: AnimationPlayer
var hp := 40.0
var max_hp := 40.0
var dmg := 10.0
var speed := 4.0
var scale_k := 1.0
var body_r := 0.5
var elite := false
var dead := false
var state := "spawn"
var t := 0.0
var cd := 1.8  # time until the next attack may start
var warn: Node3D
var burn_t := 0.0
var stun_t := 0.0
var flash_t := 0.0
var strafe := 1.0
var gold := 3
var xp := 4

func setup(m: Node, k: String, level: int, is_elite := false) -> void:
	main = m
	kind = k
	def = Data.ENEMIES[k]
	elite = is_elite
	var mult := 1.0 + 0.18 * level  # deeper rooms: tougher bones
	max_hp = def.hp * mult * (2.6 if elite else 1.0)
	hp = max_hp
	dmg = def.dmg * (1.0 + 0.12 * level) * (1.4 if elite else 1.0)
	speed = def.speed * randf_range(0.9, 1.1)
	scale_k = 1.35 if elite else 1.0
	gold = def.gold * (4 if elite else 1)
	xp = def.xp * (3 if elite else 1)
	_body()

func _body() -> void:
	var r: Array = Rig.make("skeletons", def.model, def.get("right", ""), def.get("left", ""))
	model = r[0]
	ap = r[1]
	model.scale = Vector3.ONE * scale_k
	add_child(model)
	body_r = 0.45 * scale_k
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_r
	cap.height = 1.7 * scale_k
	cs.shape = cap
	cs.position.y = 0.85 * scale_k
	add_child(cs)
	collision_layer = 4
	collision_mask = 1
	if elite:
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.3, 0.9)
		l.light_energy = 2.0
		l.omni_range = 3.0
		l.position.y = 1.5
		add_child(l)
	ap.play("Skeletons_Awaken_Floor", 0.0, 1.4)
	t = 0.0

func _physics_process(dt: float) -> void:
	if dead or main.paused_game:
		return
	t += dt
	cd -= dt
	flash_t -= dt
	if burn_t > 0.0:
		burn_t -= dt
		hp -= 4.0 * dt
		if hp <= 0.0:
			main.kill_enemy(self)
			return
	var hero: Node3D = main.hero
	var to := hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var v := Vector3.ZERO
	if stun_t > 0.0:
		stun_t -= dt
		_move(Vector3.ZERO, dt)
		return
	match state:
		"spawn":
			if t > 1.6:
				state = "chase"
		"chase":
			if main.hero.hidden_t > 0.0 or main.hero.dead:
				_anim("Skeletons_Idle")
			else:
				_face(to)
				var want: float = def.range * (0.85 if def.kind == "melee" else 0.8)
				if def.kind == "melee":
					if dist > want:
						v = to.normalized() * speed
						_anim("Running_A" if speed > 4.0 else "Skeletons_Walking")
					else:
						_anim("Skeletons_Idle")
						if cd <= 0.0:
							_windup()
				else:  # keep away, sidestep, shoot
					if dist < want * 0.55:
						v = -to.normalized() * speed * 0.8
					elif dist > want:
						v = to.normalized() * speed
					else:
						v = to.normalized().cross(Vector3.UP) * strafe * speed * 0.5
						if randf() < 0.01:
							strafe = -strafe
					_anim("Running_A" if v.length() > 0.5 else "Skeletons_Idle")
					if cd <= 0.0 and dist < def.range * 1.15:
						_windup()
		"windup":
			_face(to)
			var wind := 0.6 if def.kind == "melee" else 0.7
			if t > wind:
				state = "strike"
				t = 0.0
				ap.speed_scale = 1.0
				_strike(to, dist)
		"strike":
			if t > 0.55:
				state = "chase"
				cd = randf_range(1.2, 2.2) / (1.3 if elite else 1.0)
	v += _separation() * 2.0
	_move(v, dt)

func _move(v: Vector3, dt: float) -> void:
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * dt
	move_and_slide()

func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o in main.enemies:
		if o == self or o.dead:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0
		var min_d: float = body_r + o.body_r + 0.2
		if d.length() < min_d and d.length() > 0.01:
			push += d.normalized() * (min_d - d.length())
	return push

func _face(dir: Vector3) -> void:
	if dir.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.2)

func _anim(n: String, blend := 0.2) -> void:
	if ap.current_animation != n:
		ap.play(n, blend)

# only two enemies wind up or strike at a time; the others wait their turn (keeps crowds fair on a phone)
func _turn_free() -> bool:
	var n := 0
	for o in main.enemies:
		if o != self and not o.dead and o.state in ["windup", "strike"]:
			n += 1
	return n < 2

func _windup() -> void:
	if not _turn_free():
		cd = randf_range(0.3, 0.8)
		return
	state = "windup"
	t = 0.0
	ap.play(def.attack, 0.1)
	ap.speed_scale = 0.45  # a slow, readable start
	if def.kind == "melee":
		var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
		warn = Fx.ring(main.world, global_position + fwd * def.range * 0.6, def.range * 0.75 * scale_k, 0.6)
	else:
		warn = Fx.ring(main.world, global_position, 0.9 * scale_k, 0.7, Color(1, 0.6, 0.1, 0.5))

func _strike(to: Vector3, dist: float) -> void:
	var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	match def.kind:
		"melee":
			if dist < def.range * 1.15 * scale_k and fwd.angle_to(to.normalized()) < 1.1:
				main.hurt_hero(dmg, global_position)
				main.thorns(self)
		"ranged":
			_shoot(fwd, 16.0, 0.0, Color(1, 0.75, 0.3))
			if elite:
				_shoot(fwd.rotated(Vector3.UP, 0.25), 16.0, 0.0, Color(1, 0.75, 0.3))
				_shoot(fwd.rotated(Vector3.UP, -0.25), 16.0, 0.0, Color(1, 0.75, 0.3))
		"caster":
			if randf() < 0.25 and main.enemies.size() < 10:
				for i in 2:
					main.spawn_enemy("minion", global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
				Fx.burst(main.world, global_position + Vector3(0, 1, 0), Color(0.6, 0.3, 1), 16, 4.0)
			else:
				_shoot(fwd, 6.0, 2.0, Color(0.6, 0.3, 1))

func _shoot(dir: Vector3, spd: float, homing: float, col: Color) -> void:
	var p := Projectile.new()
	p.main = main
	p.friendly = false
	p.dmg = dmg
	p.vel = dir * spd
	p.homing = homing
	p.life = 3.0
	p.radius = 0.35
	p.col = col
	p.add_child(Fx.orb(0.22, col))
	main.world.add_child(p)
	p.global_position = global_position + Vector3(0, 1.2 * scale_k, 0) + dir * 0.8

func hurt(amount: float, from: Vector3) -> void:
	hp -= amount
	var tw := create_tween()  # a squash on every hit: you feel each blow land
	tw.tween_property(model, "scale", Vector3(1.15, 0.85, 1.15) * scale_k, 0.05)
	tw.tween_property(model, "scale", Vector3.ONE * scale_k, 0.1)
	if state == "spawn":
		return
	var away := global_position - from
	away.y = 0
	if not elite and state != "strike":  # a hit interrupts a common skeleton's swing
		if is_instance_valid(warn):
			warn.queue_free()
		state = "chase"
		cd = maxf(cd, 0.5)
		ap.speed_scale = 1.0
		ap.play("Hit_A", 0.05)
		global_position += away.normalized() * 0.35

func die() -> void:
	dead = true
	if is_instance_valid(warn):
		warn.queue_free()
	ap.speed_scale = 1.0
	ap.play("Skeletons_Death", 0.05)
	collision_layer = 0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.4)
	tw.tween_callback(queue_free)
