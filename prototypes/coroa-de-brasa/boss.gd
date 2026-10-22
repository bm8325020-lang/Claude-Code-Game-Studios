# PROTOTYPE - NOT FOR PRODUCTION
# A floor's boss: a giant skeleton with a move set (data.gd BOSSES). Every move is telegraphed on the floor:
# slam (a big ring), spin (spins toward you), nova (a ring of orbs), orbs (homing), summon (calls minions).
# Under half HP it roars into phase 2: faster, and every move comes twice as often.
extends "res://enemy.gd"

var bdef: Dictionary
var phase := 1
var move := ""
var tick := 0.0

func setup_boss(m: Node, b: Dictionary, level: int) -> void:
	main = m
	bdef = b
	kind = b.base
	def = Data.ENEMIES[kind]
	max_hp = b.hp * (1.0 + 0.1 * level)
	hp = max_hp
	dmg = b.dmg
	speed = def.speed * 0.8
	scale_k = b.scale
	gold = 120
	xp = 80
	elite = true
	_body()

func _physics_process(dt: float) -> void:
	if dead or main.paused_game:
		return
	t += dt
	cd -= dt
	if burn_t > 0.0:
		burn_t -= dt
		hp -= 4.0 * dt
	var to: Vector3 = main.hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var v := Vector3.ZERO
	var fury := 1.0 if phase == 1 else 1.35
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		state = "roar"
		t = 0.0
		ap.play("Skeletons_Taunt_Longer", 0.1)
		main.banner(bdef.name.to_upper(), "se enfurece!", Color(1, 0.3, 0.2))
		main.shake(0.8)
	match state:
		"spawn":
			if t > 1.6:
				state = "chase"
		"roar":
			if t > 2.0:
				state = "chase"
				_summon(3)
		"chase":
			_face(to)
			if dist > 3.0 * scale_k * 0.6:
				v = to.normalized() * speed * fury
				_anim("Skeletons_Walking" if fury < 1.2 else "Running_A")
			else:
				_anim("Skeletons_Idle")
			if cd <= 0.0:
				move = bdef.moves.pick_random()
				state = move
				t = 0.0
				tick = 0.0
				_begin(move)
		"slam":
			_face(to)
			if t > 1.0 / fury and tick == 0.0:
				tick = 1.0
				Fx.wave(main.world, global_position, 5.0, Color(1, 0.5, 0.2))
				main.shake(0.6)
				if dist < 5.0:
					main.hurt_hero(dmg * 1.3, global_position)
			if t > 1.6 / fury:
				_end()
		"spin":
			v = to.normalized() * speed * 0.9 * fury
			tick -= dt
			if tick <= 0.0:
				tick = 0.35
				if dist < 3.2:
					main.hurt_hero(dmg * 0.5, global_position)
			if t > 2.6:
				_end()
		"nova":
			if t > 0.9 and tick == 0.0:
				tick = 1.0
				_ring_of_orbs(14, 0.0)
				if phase == 2:
					get_tree().create_timer(0.45).timeout.connect(func(): if not dead: _ring_of_orbs(14, PI / 14.0))
			if t > 1.5:
				_end()
		"orbs":
			if t > 0.7 and tick == 0.0:
				tick = 1.0
				for i in 3 + phase:
					_shoot(Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y + PI + (i - 1.5) * 0.5), 5.0, 1.6, Color(0.6, 0.3, 1))
			if t > 1.3:
				_end()
		"summon":
			if t > 1.2 and tick == 0.0:
				tick = 1.0
				_summon(2 + phase)
			if t > 1.8:
				_end()
	v += _separation()
	_move(v, dt)

func _begin(m: String) -> void:
	match m:
		"slam":
			ap.play("Melee_2H_Attack_Chop", 0.1, 0.7)
			warn = Fx.ring(main.world, global_position, 5.0, 1.0)
		"spin":
			ap.play("Melee_2H_Attack_Spinning", 0.1)
			warn = Fx.ring(main.world, global_position, 3.2, 0.5, Color(1, 0.5, 0.1, 0.5))
		"nova", "orbs":
			ap.play("Ranged_Magic_Raise", 0.1, 1.3)
		"summon":
			ap.play("Ranged_Magic_Summon", 0.1, 2.2)

func _end() -> void:
	state = "chase"
	cd = randf_range(1.0, 2.0) / (1.0 if phase == 1 else 1.6)

func _ring_of_orbs(n: int, off: float) -> void:
	for i in n:
		_shoot(Vector3.FORWARD.rotated(Vector3.UP, off + i * TAU / n), 7.0, 0.0, Color(1, 0.4, 0.2))

func _summon(n: int) -> void:
	for i in n:
		var a := i * TAU / n
		main.spawn_enemy("minion" if i % 3 else "warrior", global_position + Vector3(cos(a), 0, sin(a)) * 4.0)
	Fx.burst(main.world, global_position + Vector3(0, 2, 0), Color(0.6, 0.3, 1), 24, 6.0)

func hurt(amount: float, _from: Vector3) -> void:
	hp -= amount  # bosses are never staggered
