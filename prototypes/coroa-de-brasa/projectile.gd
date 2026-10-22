# PROTOTYPE - NOT FOR PRODUCTION
# Bolts, arrows, knives and orbs. A player's projectile hits enemies; an enemy's hits the hero. Optional homing,
# piercing, and an explosion radius when it lands.
extends Node3D

const Fx = preload("res://fx.gd")

var main: Node
var vel := Vector3.ZERO
var dmg := 10.0
var friendly := true  # true: fired by the hero
var radius := 0.5
var life := 2.0
var homing := 0.0  # turn rate toward the target (rad/s)
var pierce := 0
var blast := 0.0  # explosion radius on hit (0: none)
var col := Color(1, 0.6, 0.2)
var hit_list := []

func _physics_process(dt: float) -> void:
	life -= dt
	if homing > 0.0:
		var tgt: Vector3 = main.hero.global_position + Vector3(0, 1, 0) if not friendly else _nearest()
		if tgt != Vector3.INF:
			var want := (tgt - global_position).normalized() * vel.length()
			vel = vel.lerp(want, clampf(homing * dt, 0.0, 1.0))
	global_position += vel * dt
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP)
	if friendly:
		for e in main.enemies:
			if e.dead or e in hit_list:
				continue
			if e.global_position.distance_to(global_position - Vector3(0, 1, 0)) < radius + e.body_r:
				_land(e)
				if pierce <= 0:
					return
				pierce -= 1
	else:
		var h: Node3D = main.hero
		if h.global_position.distance_to(global_position - Vector3(0, 1, 0)) < radius + 0.4:
			main.hurt_hero(dmg, global_position)
			Fx.burst(main.world, global_position, col, 8, 3.0)
			queue_free()
			return
	if life <= 0.0 or _in_wall():
		if blast > 0.0:
			_explode()
		queue_free()

func _nearest() -> Vector3:
	var best := Vector3.INF
	var bd := 12.0
	for e in main.enemies:
		if not e.dead and e.global_position.distance_to(global_position) < bd:
			bd = e.global_position.distance_to(global_position)
			best = e.global_position + Vector3(0, 1, 0)
	return best

func _in_wall() -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = global_position
	q.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_point(q, 1).is_empty()

func _land(e) -> void:
	hit_list.append(e)
	if blast > 0.0:
		_explode()
		queue_free()
		return
	main.damage_enemy(e, dmg, global_position - vel.normalized())
	Fx.burst(main.world, global_position, col, 6, 3.0)
	if pierce <= 0:
		queue_free()

func _explode() -> void:
	Fx.wave(main.world, Vector3(global_position.x, main.floor_y(), global_position.z), blast, col)
	Fx.burst(main.world, global_position, col, 18, 6.0, 0.18)
	main.shake(0.25)
	for e in main.enemies.duplicate():
		if not e.dead and Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() < blast + e.body_r:
			main.damage_enemy(e, dmg, global_position)
