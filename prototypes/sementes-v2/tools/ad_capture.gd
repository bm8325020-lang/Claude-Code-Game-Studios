# PROTOTYPE - NOT FOR PRODUCTION
# Records real gameplay for the ad with Godot's Movie Maker (fixed frame rate, so it is smooth even on a slow box):
#   godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 res://tools/ad_capture.tscn
# A bot drives the hero: a walk through Vila de Brasalume, then a fight at a bandit camp.
extends Node

const WALK_END: float = 8.0
const END: float = 24.0

var game: Node3D
var hero: Hero
var t: float = 0.0
var _route: Array[Vector3] = []
var _atk_cd: float = 0.0
var _dodge_cd: float = 2.0
var _fight_started: bool = false


func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)
	hero = game.hero
	hero.equip({"body": "Male", "outfit": "Ranger", "weapon": "Sword_Bronze", "shield": "Shield_Wooden"})
	hero.max_hp = 900.0
	hero.hp = 900.0
	hero.power = 2.0
	game.touch.visible = false  # clean frame: the ad shows the world, not the thumb buttons
	var sp: Dictionary = game.map.spawns
	_route = [sp.get("village_square", hero.global_position), sp.get("bridge", hero.global_position)]
	hero.set_bot(_bot)


func _process(dt: float) -> void:
	t += dt
	_atk_cd -= dt
	_dodge_cd -= dt
	if t >= WALK_END and not _fight_started:
		_fight_started = true
		_go_to_camp()
	if t >= END:
		get_tree().quit()


func _go_to_camp() -> void:
	for c: Dictionary in game.map.camps:
		var ks: Array = c.get("kinds", [])
		if "bandit" in ks:
			var p: Vector3 = c.pos
			hero.global_position = p + Vector3(9.0, 0.0, 0.0)
			hero.global_position.y = game.map.ground_y(hero.global_position.x, hero.global_position.z) + 0.1
			hero.reset_physics_interpolation()
			hero.cam_yaw = atan2(-(-9.0), -0.0)  # look toward the camp
			return


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var bd: float = 1e9
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e.dead or not e.visible:
			continue
		var d: float = e.global_position.distance_to(hero.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _bot(h: Hero) -> Dictionary:
	var out: Dictionary = {"move": Vector2.ZERO, "pressed": [], "held": []}
	var pressed: Array = []
	if not _fight_started:
		if _route.is_empty():
			return out
		var to: Vector3 = _route[0] - h.global_position
		to.y = 0.0
		if to.length() < 3.0:
			_route.pop_front()
		else:
			out["move"] = h.stick_for(to.normalized()) * 0.75
		return out
	var e: Enemy = _nearest_enemy()
	if e == null:
		return out
	var to: Vector3 = e.global_position - h.global_position
	to.y = 0.0
	var d: float = to.length()
	if h.lock_target == null and d < 14.0:
		pressed.append("lock")
	if d > 2.2:
		out["move"] = h.stick_for(to.normalized())
	elif _dodge_cd <= 0.0 and e.state == "attack":
		_dodge_cd = 2.5
		out["move"] = h.stick_for(to.normalized().cross(Vector3.UP))
		pressed.append("dodge")
	elif _atk_cd <= 0.0:
		_atk_cd = 0.38
		pressed.append("heavy" if randf() < 0.2 else "attack")
	out["pressed"] = pressed
	return out


# combat routes damage through get_tree().current_scene.damage; this scene wraps main, so pass it on
func damage(target: Node, amount: float, source: Node, kind: String) -> Dictionary:
	return game.damage(target, amount, source, kind)
