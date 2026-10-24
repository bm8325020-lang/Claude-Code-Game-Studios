# PROTOTYPE - NOT FOR PRODUCTION
# Tries to get past every closed story gate (world/gates.gd) with real physics: straight at it, around it over the
# slopes, through the river and the lake, jumping all the way. Prints which attempts got through.
#   godot --headless --path . --fixed-fps 30 -s tools/gate_probe.gd
extends SceneTree

# [gate, start (x, z), waypoints..., goal]: the goal is past the gate; reaching it within 8 m means a leak
const TRIES: Array = [
	["passo_escama", Vector2(268, 12), Vector2(330, 8)],
	["passo_escama", Vector2(268, 12), Vector2(285, -12), Vector2(310, -12), Vector2(330, 8)],
	["passo_escama", Vector2(268, 12), Vector2(285, 34), Vector2(310, 34), Vector2(330, 8)],
	["passo_escama", Vector2(250, 0), Vector2(255, -45), Vector2(310, -60), Vector2(345, -30)],
	["passo_escama", Vector2(250, 20), Vector2(255, 65), Vector2(310, 70), Vector2(345, 40)],
	["castelo_grade", Vector2(45, -216), Vector2(10, -216)],
	["castelo_grade", Vector2(45, -216), Vector2(32, -246), Vector2(5, -248), Vector2(10, -216)],
	["castelo_grade", Vector2(45, -216), Vector2(32, -190), Vector2(5, -188), Vector2(10, -216)],
	["mina_portao", Vector2(176, -178), Vector2(181, -206)],
	["ponte_dizimo", Vector2(-44, 58), Vector2(-60, 70), Vector2(-90, 84)],
	["ponte_dizimo", Vector2(-44, 58), Vector2(-60, 70), Vector2(-66, 66), Vector2(-90, 70)],
	["ponte_dizimo", Vector2(-40, 30), Vector2(-90, 30)],
	["ponte_dizimo", Vector2(-25, 115), Vector2(-70, 125)],
	["ponte_dizimo", Vector2(-60, -60), Vector2(-130, -60)],
	["ponte_dizimo", Vector2(40, 190), Vector2(0, 240), Vector2(-60, 220), Vector2(-90, 180)],
	["ponte_dizimo", Vector2(40, 190), Vector2(60, 262), Vector2(-40, 262), Vector2(-90, 200)],
	["ponte_dizimo", Vector2(-190, -230), Vector2(-260, -250), Vector2(-280, -200)],
]

var g: Node3D
var _aim: Vector3 = Vector3.ZERO
var _tick: int = 0


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sementes2_save.json"))
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 5:
		await process_frame
	var hero: Hero = g.hero
	hero.set_bot(func(h: Hero) -> Dictionary:
		_tick += 1
		var d: Vector3 = _aim - h.global_position
		d.y = 0.0
		return {"move": h.stick_for(d.normalized()) if d.length() > 1.0 else Vector2.ZERO,
			"pressed": ["jump"] if _tick % 20 == 0 else [], "held": ["sprint"]})
	var leaks: int = 0
	for tr: Array in TRIES:
		var s: Vector2 = tr[1]
		hero.global_position = Vector3(s.x, g.map.ground_y(s.x, s.y) + 0.5, s.y)
		hero.velocity = Vector3.ZERO
		hero.reset_physics_interpolation()
		var goal: Vector2 = tr[tr.size() - 1]
		var best: float = INF
		for k in range(2, tr.size()):
			var w: Vector2 = tr[k]
			_aim = Vector3(w.x, 0, w.y)
			for f in 30 * 25:
				await physics_frame
				var p := Vector2(hero.global_position.x, hero.global_position.z)
				best = minf(best, p.distance_to(goal))
				if p.distance_to(w) < 3.0:
					break
		var leak: bool = best < 8.0
		leaks += int(leak)
		print("%s %s from %s: closest %.1f m to %s, ended %s%s" % ["LEAK" if leak else "held", tr[0], s, best, goal,
			Vector2(hero.global_position.x, hero.global_position.z).round(), "" if g.gates.is_open(str(tr[0])) else ""])
	print("gate probe: %d leaks in %d tries" % [leaks, TRIES.size()])
	quit()
