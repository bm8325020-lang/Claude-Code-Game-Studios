# PROTOTYPE - NOT FOR PRODUCTION
# Map preview (map agent): builds GameMap, saves screenshots from eye height at every place plus 3 overviews,
# and prints draw calls / primitives per view.
# Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/map_preview.gd
# Optional env: MAP_SHOTS=1,4,7 (only those views), MAP_OUT=dir
extends SceneTree

const MapT = preload("res://world/map.gd")

var OUT: String = "/home/user/Claude-Code-Game-Studios/prototypes/sementes-v2/tools/shots/"

# name, eye (x, z, height above ground or absolute if > 60), target (x, y_above_ground, z)
# Third-person player view: eye ~3.5 m (over the hero's shoulder), looking at the set piece.
var views: Array = [
	["map_01_square", Vector3(6, 3.6, -34), Vector3(-4, 2, -14)],
	["map_02_square_to_castle", Vector3(-6, 4.2, 4), Vector3(8, 42, -214)],
	["map_03_forge", Vector3(26, 3.4, -30), Vector3(14, 2, -34)],
	["map_04_north_street", Vector3(6, 3.8, -74), Vector3(-2, 3, -30)],
	["map_05_mill_bridge", Vector3(-34, 3.6, 92), Vector3(-56, 3, 58)],
	["map_06_forest_carvalha", Vector3(-168, 3.4, 36), Vector3(-185, 7, 24)],
	["map_07_bandit_camp", Vector3(-194, 3.8, 152), Vector3(-214, 3, 168)],
	["map_08_watchtower", Vector3(162, 4.0, -26), Vector3(186, 10, -50)],
	["map_09_mine", Vector3(176, 3.6, -158), Vector3(180, 4, -188)],
	["map_10_castle_road", Vector3(96, 4.2, -196), Vector3(10, 14, -214)],
	["map_11_lake_pier", Vector3(54, 3.6, 150), Vector3(46, 1, 184)],
	["map_12_farm", Vector3(72, 3.8, 48), Vector3(104, 3, 70)],
	["map_13_over_south", Vector3(20, 200, 330), Vector3(0, 0, -40)],
	["map_14_over_west", Vector3(-340, 175, -40), Vector3(0, 0, 10)],
	["map_15_over_northeast", Vector3(270, 170, -300), Vector3(-10, 0, 40)],
]


func _init() -> void:
	var env_out: String = OS.get_environment("MAP_OUT")
	if env_out != "":
		OUT = env_out
	DirAccess.make_dir_recursive_absolute(OUT)
	var map: MapT = MapT.new()
	get_root().add_child(map)
	map.build()
	print("MAP build stats: ", map.stats)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 62.0
	cam.far = 1200.0
	get_root().add_child(cam)
	cam.make_current()
	var only: String = OS.get_environment("MAP_SHOTS")
	for i in views.size():
		if only != "" and not (only.split(",") as PackedStringArray).has(str(i + 1)):
			continue
		var v: Array = views[i]
		var e: Vector3 = v[1]
		var t: Vector3 = v[2]
		var eye: Vector3 = Vector3(e.x, e.y, e.z)
		if e.y < 60.0:
			eye.y = map.ground_y(e.x, e.z) + e.y
		var tgt: Vector3 = Vector3(t.x, map.ground_y(t.x, t.z) + t.y, t.z)
		if t.y >= 30.0:
			tgt.y = t.y
		cam.look_at_from_position(eye, tgt)
		for f in 8:
			await process_frame
		var img: Image = get_root().get_texture().get_image()
		img.save_png(OUT + v[0] + ".png")
		print("VIEW %s draw_calls=%d primitives=%d objects=%d area='%s'" % [v[0],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			map.area_name(eye)])
	quit()
