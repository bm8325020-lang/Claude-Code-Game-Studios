# PROTOTYPE - NOT FOR PRODUCTION
# Render cost probe: loads main.tscn, puts the hero (and its real third-person camera) at seven spots and prints
# draw calls / primitives / objects per spot once the frame settles. Needs a renderer (not --headless):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tools/perf_probe.gd [-- shots_prefix]
# With a shots prefix it also saves <prefix><spot>.png per spot. PERF_BREAKDOWN=1 also prints what each map part
# costs (draws/prims it removes when hidden, and the sun's shadow pass).
extends SceneTree

# spawn id, camera yaw (0 looks toward -z)
const SPOTS: Array = [
	["village_square", 0.0], ["farm", 0.8], ["forest", 2.2], ["lake", PI], ["castle", 0.0], ["mine", PI], ["cauda", 0.6],
]
const SETTLE: int = 15   # frames after a teleport before reading
const SAMPLE: int = 6    # frames averaged per spot

var game: Node
var _i: int = -1
var _f: int = 0
var _acc: Array = [0, 0, 0, 0.0]   # draw calls, primitives, objects, frame ms
var _shots: String = ""
var _rows: Array = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_shots = args[0]
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)


func _process(dt: float) -> bool:
	if _i < 0:
		_next()
		return false
	_f += 1
	var hero: Node3D = game.get("hero")
	hero.set("hp", 99999.0)
	if _f > SETTLE:
		_acc[0] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_acc[1] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_acc[2] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		_acc[3] += dt * 1000.0
	if _f == SETTLE + SAMPLE:
		var n: float = float(SAMPLE)
		var row: String = "%-15s draws=%5d  prims=%8d  objects=%5d  frame_ms=%.1f" % [
			SPOTS[_i][0], roundi(_acc[0] / n), roundi(_acc[1] / n), roundi(_acc[2] / n), _acc[3] / n]
		_rows.append(row)
		print("PERF ", row)
		if _shots != "":
			root.get_texture().get_image().save_png("%s%s.png" % [_shots, SPOTS[_i][0]])
		if OS.get_environment("PERF_BREAKDOWN") == "1":
			_bd = _parts()
			_bd_i = 0
			_bd_base = [_acc[0] / n, _acc[1] / n]
		else:
			_next()
	elif _f > SETTLE + SAMPLE:
		_breakdown()
	return false


var _bd: Array = []
var _bd_i: int = 0
var _bd_base: Array = []


# Hidden-part probes, 3 frames each: toggle, wait, read, restore.
func _parts() -> Array:
	var out: Array = []
	var map: Node = game.get("map")
	for c in map.get_children():
		if c is Node3D and not (c is Light3D):
			out.append(c)
	for c in map.get_node("Places").get_children():
		out.append(c)
	out.append(map.get("sun"))
	return out


func _toggle(n: Node, on: bool) -> void:
	if n is DirectionalLight3D:
		(n as DirectionalLight3D).shadow_enabled = on
	else:
		(n as Node3D).visible = on


func _breakdown() -> void:
	var k: int = (_f - SETTLE - SAMPLE - 1) % 3
	if _bd_i >= _bd.size():
		_next()
		return
	var n: Node = _bd[_bd_i]
	if k == 0:
		_toggle(n, false)
	elif k == 2:
		var d: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var pr: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("PERF   part %-22s draws -%4d  prims -%7d" % [n.name, roundi(_bd_base[0]) - d, roundi(_bd_base[1]) - pr])
		_toggle(n, true)
		_bd_i += 1


func _next() -> void:
	_i += 1
	_f = 0
	_acc = [0, 0, 0, 0.0]
	if _i >= SPOTS.size():
		print("PERF summary (avg of %d frames after %d settle frames)" % [SAMPLE, SETTLE])
		for r in _rows:
			print("PERF ", r)
		quit()
		return
	var map: Node = game.get("map")
	var hero: Node3D = game.get("hero")
	var p: Vector3 = (map.get("spawns") as Dictionary).get(SPOTS[_i][0], Vector3.ZERO)
	p.y = float(map.call("ground_y", p.x, p.z)) + 0.1
	hero.global_position = p
	hero.set("cam_yaw", float(SPOTS[_i][1]))
	hero.reset_physics_interpolation()
