# PROTOTYPE - NOT FOR PRODUCTION
# The hero you play: moves with the joystick, attacks with a 3-hit combo aimed at the nearest enemy, dodges
# through attacks (invulnerable), drinks potions and uses the class's three skills (data.gd HEROES).
extends CharacterBody3D

const Data = preload("res://data.gd")
const Rig = preload("res://rig.gd")
const Fx = preload("res://fx.gd")
const Projectile = preload("res://projectile.gd")

var main: Node
var id := "knight"
var def: Dictionary
var model: Node3D
var ap: AnimationPlayer
var hp := 100.0
var max_hp := 100.0
var dead := false
var state := "free"  # free, attack, dodge, skill, hurt, dead
var t := 0.0
var combo := 0
var combo_t := 0.0
var queued := false
var hit_done := false
var move: Dictionary
var cds := [0.0, 0.0, 0.0]
var dodge_cd := 0.0
var invuln := 0.0
var hidden_t := 0.0  # rogue's shadow step: enemies lose you
var guard_t := 0.0  # knight's shield wall: half damage
var rage_t := 0.0  # barbarian's rage: faster
var whirl_t := 0.0
var aim := Vector3.FORWARD
var skill_fn := ""

func setup(m: Node, hero_id: String, tint: Color) -> void:
	main = m
	id = hero_id
	def = Data.HEROES[id]
	var r: Array = Rig.make("heroes", def.model, def.right, def.left, tint)
	model = r[0]
	ap = r[1]
	add_child(model)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	add_child(cs)
	collision_layer = 2
	collision_mask = 1 | 4
	ap.play("Idle_A")

func stat(k: String) -> float:
	return main.stat(k)

func _physics_process(dt: float) -> void:
	if main.paused_game:
		return
	t += dt
	combo_t -= dt
	invuln -= dt
	hidden_t -= dt
	guard_t -= dt
	rage_t -= dt
	dodge_cd -= dt
	for i in 3:
		cds[i] -= dt * (1.0 + stat("cdr"))
	if dead:
		_move(Vector3.ZERO, dt)
		main.ui.late_clear()
		return
	var input: Vector2 = main.ui.move_vec()
	var dir: Vector3 = main.cam_dir(input)
	var spd: float = def.speed * (1.0 + stat("speed")) * (1.25 if rage_t > 0.0 else 1.0)
	var v := Vector3.ZERO
	var aspd: float = 1.0 + stat("aspd") + (0.4 if rage_t > 0.0 else 0.0)
	if whirl_t > 0.0:
		whirl_t -= dt
		_whirl_tick(dt)
	match state:
		"free":
			v = dir * spd
			if dir.length() > 0.1:
				_face(dir)
				_anim("Running_A")
			else:
				_anim("Idle_A" if combo_t < -3.0 else "Melee_2H_Idle" if id == "barbarian" else "Idle_B" if id == "mage" else "Idle_A")
			if main.ui.pressed("attack"):
				_attack(aspd)
			elif main.ui.pressed("dodge") and dodge_cd <= 0.0:
				_dodge(dir)
			elif main.ui.pressed("potion"):
				main.drink()
			else:
				for i in 3:
					if main.ui.pressed("skill%d" % i) and cds[i] <= 0.0:
						_skill(i, dir)
						break
		"attack":
			var len_s: float = ap.current_animation_length / ap.speed_scale
			var hit_at: float = move.hit * len_s
			v = Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * move.get("lunge", 0.0) * (1.0 if t < hit_at else 0.0)
			if main.ui.pressed("attack"):
				queued = true
			if main.ui.pressed("dodge") and dodge_cd <= 0.0 and t > hit_at:
				_dodge(dir)
			elif not hit_done and t >= hit_at:
				hit_done = true
				_strike()
			elif queued and t > hit_at + 0.05:
				_attack(aspd)
			elif t >= len_s * 0.85:
				state = "free"
		"dodge":
			v = aim * 15.0 * (1.0 - clampf(t / 0.35, 0.0, 0.8))
			if t > 0.35:
				state = "free"
		"skill":
			v = Vector3.ZERO if whirl_t <= 0.0 else dir * spd * 0.7
			if whirl_t > 0.0 and dir.length() > 0.1:
				_face(dir)
			if t > ap.current_animation_length / ap.speed_scale * 0.9 and whirl_t <= 0.0:
				state = "free"
		"hurt":
			if t > 0.3:
				state = "free"
	_move(v, dt)
	main.ui.late_clear()  # every button press is read once, by this frame

func _move(v: Vector3, dt: float) -> void:
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 25.0 * dt
	move_and_slide()

func _face(d: Vector3) -> void:
	if d.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(d.x, d.z), 0.35)
		aim = Vector3(d.x, 0, d.z).normalized()

func _snap_face(d: Vector3) -> void:
	d.y = 0
	if d.length() > 0.05:
		model.rotation.y = atan2(d.x, d.z)
		aim = d.normalized()

func _anim(n: String, blend := 0.15) -> void:
	if ap.current_animation != n:
		ap.speed_scale = 1.0
		ap.play(n, blend)

# the nearest living enemy within reach, or null
func target(reach: float) -> Node3D:
	var best: Node3D = null
	var bd := reach
	for e in main.enemies:
		if e.dead:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best

func _attack(aspd: float) -> void:
	if combo_t <= 0.0:
		combo = 0
	move = def.attack[combo % def.attack.size()]
	combo += 1
	combo_t = 0.9
	state = "attack"
	t = 0.0
	queued = false
	hit_done = false
	var tg := target(move.range + 3.0 if not move.has("shot") else move.range)
	if tg != null:
		_snap_face(tg.global_position - global_position)
	ap.play(move.anim, 0.08, move.speed * aspd)
	ap.speed_scale = move.speed * aspd
	ap.seek(0.0, true)

func _strike() -> void:
	var dmg: float = move.dmg * main.dmg_mult()
	if move.has("shot"):
		match move.shot:
			"bolt":
				shoot(aim, 22.0, dmg, Color(0.5, 0.7, 1), 0.25)
			"orb":
				var p := shoot(aim, 16.0, dmg, Color(0.8, 0.5, 1), 0.4)
				p.blast = 2.5
			"arrow":
				shoot(aim, 30.0, dmg, Color(1, 0.95, 0.7), 0.15, 1)
			"arrow3":
				for a in [-0.18, 0.0, 0.18]:
					shoot(aim.rotated(Vector3.UP, a), 30.0, dmg, Color(1, 0.95, 0.7), 0.15, 1)
		return
	main.sfx("swing")
	cone(move.range, move.arc, dmg)

# hit every enemy in front within range and angle
func cone(reach: float, arc: float, dmg: float) -> int:
	var n := 0
	for e in main.enemies.duplicate():
		if e.dead:
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() < reach + e.body_r and (d.length() < 0.8 or aim.angle_to(d.normalized()) < arc * 0.5):
			main.damage_enemy(e, dmg, global_position)
			n += 1
	return n

# hit every enemy around a point
func area(center: Vector3, radius: float, dmg: float) -> void:
	for e in main.enemies.duplicate():
		if not e.dead and Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length() < radius + e.body_r:
			main.damage_enemy(e, dmg, center)

func shoot(d: Vector3, spd: float, dmg: float, col: Color, size: float, pierce := 0) -> Node3D:
	var p := Projectile.new()
	p.main = main
	p.vel = d.normalized() * spd
	p.dmg = dmg
	p.radius = size + 0.35
	p.col = col
	p.pierce = pierce
	p.life = 1.2
	p.add_child(Fx.orb(size, col))
	main.world.add_child(p)
	p.global_position = global_position + Vector3(0, 1.1, 0) + d.normalized() * 0.6
	return p

func _dodge(dir: Vector3) -> void:
	if dir.length() > 0.1:
		_snap_face(dir)
	state = "dodge"
	t = 0.0
	invuln = 0.4
	dodge_cd = 0.6
	ap.play("Dodge_Forward", 0.05, 1.0)
	main.sfx("dodge")

# ------------------------------------------------------------------ skills
func _skill(i: int, dir: Vector3) -> void:
	var s: Array = def.skills[i]
	cds[i] = s[2]
	state = "skill"
	t = 0.0
	var dmg: float = main.dmg_mult()
	var tg := target(12.0)
	if tg != null and s[0] not in ["blink", "shadow", "roll_shot"]:
		_snap_face(tg.global_position - global_position)
	elif dir.length() > 0.1:
		_snap_face(dir)
	match s[0]:
		"charge":  # dash forward hitting everything on the way
			ap.play("Melee_1H_Attack_Stab", 0.05, 2.0)
			invuln = 0.4
			var to: Vector3 = main.clamp_to_room(global_position + aim * 8.0)
			var tw := create_tween()
			tw.tween_property(self, "global_position", Vector3(to.x, global_position.y, to.z), 0.3)
			tw.tween_callback(func(): area(global_position, 2.6, 45.0 * dmg))
			main.sfx("swing")
		"bash":  # a shove all around, then half damage for 3 s
			ap.play("Melee_Block_Attack", 0.05, 1.3)
			Fx.wave(main.world, global_position, 4.0, Color(0.6, 0.8, 1))
			for e in main.enemies:
				if not e.dead and e.global_position.distance_to(global_position) < 4.0:
					main.damage_enemy(e, 20.0 * dmg, global_position)
					e.stun_t = 1.5
			guard_t = 3.0
			main.shake(0.3)
		"spin":
			ap.play("Melee_2H_Attack_Spin", 0.05, 1.4)
			for k in 3:
				get_tree().create_timer(0.25 + k * 0.4).timeout.connect(func():
					Fx.wave(main.world, global_position, 4.0, Color(1, 0.8, 0.4))
					area(global_position, 4.0, 40.0 * dmg))
		"leap":  # jump onto the target and smash
			ap.play("Melee_1H_Attack_Jump_Chop", 0.05, 1.3)
			var to := (tg.global_position if tg != null else global_position + aim * 6.0) - aim * 1.2
			invuln = 0.8
			var tw := create_tween()
			tw.tween_property(self, "global_position", Vector3(to.x, global_position.y, to.z), 0.45)
			tw.tween_callback(func():
				Fx.wave(main.world, global_position, 4.0, Color(1, 0.6, 0.3))
				Fx.burst(main.world, global_position, Color(0.8, 0.7, 0.5), 20, 6.0)
				main.shake(0.5)
				area(global_position, 4.0, 70.0 * dmg))
		"rage":
			ap.play("Cheering", 0.05, 2.0)
			rage_t = 7.0
			Fx.burst(main.world, global_position + Vector3(0, 1, 0), Color(1, 0.2, 0.1), 30, 5.0)
			main.number(global_position + Vector3(0, 2.5, 0), "FÚRIA!", Color(1, 0.3, 0.2))
		"whirl":
			ap.play("Melee_2H_Attack_Spinning", 0.05, 1.3)
			whirl_t = 2.6
		"fireball":
			ap.play("Ranged_Magic_Shoot", 0.05, 1.5)
			var p := shoot(aim, 18.0, 70.0 * dmg, Color(1, 0.5, 0.15), 0.5)
			p.blast = 3.5
		"blink":
			ap.play("Ranged_Magic_Raise", 0.05, 3.0)
			Fx.burst(main.world, global_position + Vector3(0, 1, 0), Color(0.6, 0.6, 1), 20, 4.0)
			var to := global_position + (dir if dir.length() > 0.1 else -aim) * 8.0
			global_position = main.clamp_to_room(to)
			invuln = 0.5
			Fx.burst(main.world, global_position + Vector3(0, 1, 0), Color(0.6, 0.6, 1), 20, 4.0)
		"meteors":
			ap.play("Ranged_Magic_Summon", 0.05, 2.0)
			for k in 9:
				get_tree().create_timer(0.4 + k * 0.22).timeout.connect(func(): _meteor(70.0 * dmg))
		"knives":
			ap.play("Throw", 0.05, 2.0)
			for a in [-0.4, -0.2, 0.0, 0.2, 0.4]:
				shoot(aim.rotated(Vector3.UP, a), 24.0, 26.0 * dmg, Color(0.9, 0.9, 1), 0.15, 1)
		"shadow":
			ap.play("Dodge_Forward", 0.05, 1.2)
			state = "dodge"
			invuln = 0.6
			hidden_t = 2.5
			main.crit_next = true
			Fx.burst(main.world, global_position + Vector3(0, 1, 0), Color(0.3, 0.2, 0.5), 20, 3.0)
		"blades":
			ap.play("Melee_2H_Attack_Spinning", 0.05, 1.6)
			whirl_t = 2.2
		"volley":
			ap.play("Ranged_Bow_Release", 0.05, 2.0)
			for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				shoot(aim.rotated(Vector3.UP, a), 30.0, 28.0 * dmg, Color(1, 0.95, 0.7), 0.15, 2)
		"roll_shot":
			ap.play("Dodge_Backward", 0.05, 1.0)
			state = "dodge"
			invuln = 0.45
			state = "skill"
			var to: Vector3 = main.clamp_to_room(global_position - aim * 5.0)
			var tw := create_tween()
			tw.tween_property(self, "global_position", Vector3(to.x, global_position.y, to.z), 0.3)
			tw.tween_callback(func(): shoot(aim, 34.0, 60.0 * dmg, Color(1, 0.8, 0.4), 0.25, 4))
		"rain":
			ap.play("Ranged_Bow_Release_Up", 0.05, 1.4)
			var c := tg.global_position if tg != null else global_position + aim * 7.0
			Fx.ring(main.world, c, 4.0, 2.4, Color(1, 0.9, 0.5, 0.45))
			for k in 8:
				get_tree().create_timer(0.3 + k * 0.28).timeout.connect(func():
					Fx.burst(main.world, c + Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3)), Color(1, 0.95, 0.7), 8, 4.0)
					area(c, 4.0, 18.0 * dmg))
	main.sfx("skill")

func _whirl_tick(dt: float) -> void:
	if fmod(whirl_t, 0.25) < dt:
		area(global_position, 3.4, (12.0 if id == "barbarian" else 10.0) * main.dmg_mult())
		Fx.wave(main.world, global_position, 3.4, Color(1, 0.85, 0.5) if id == "barbarian" else Color(0.8, 0.8, 1))
	if whirl_t <= 0.0:
		state = "free"

func _meteor(dmg: float) -> void:
	var tg := target(14.0)
	var c := (tg.global_position if tg != null else global_position + aim * 6.0) + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	var o := Fx.orb(0.5, Color(1, 0.45, 0.1))
	main.world.add_child(o)
	o.global_position = c + Vector3(3, 12, 3)
	Fx.ring(main.world, c, 2.5, 0.45, Color(1, 0.5, 0.1, 0.5))
	var tw := o.create_tween()
	tw.tween_property(o, "global_position", c, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Fx.wave(main.world, c, 2.6, Color(1, 0.5, 0.15))
		Fx.burst(main.world, c + Vector3(0, 0.4, 0), Color(1, 0.5, 0.1), 14, 6.0)
		main.shake(0.2)
		area(c, 2.6, dmg)
		o.queue_free())

func hurt(amount: float, from: Vector3) -> void:
	if dead or invuln > 0.0:
		return
	if guard_t > 0.0:
		amount *= 0.5
	hp -= amount
	invuln = 0.5
	if hp <= 0.0:
		hp = 0.0
		dead = true
		state = "dead"
		ap.play("Death_A", 0.05)
		return
	if state == "free" or state == "hurt":
		state = "hurt"
		t = 0.0
		ap.play("Hit_A", 0.05, 1.4)
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		global_position += away.normalized() * 0.4
