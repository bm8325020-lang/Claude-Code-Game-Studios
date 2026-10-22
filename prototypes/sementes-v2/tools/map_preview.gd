# PROTOTYPE - NOT FOR PRODUCTION
# Map preview (map agent): builds GameMap, saves screenshots from eye height at every place plus 3 overviews,
# and prints draw calls / primitives per view.
# Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/map_preview.gd
# Optional env: MAP_SHOTS=1,4,7 (only those views), MAP_OUT=dir
extends SceneTree

const MapT = preload("res://world/map.gd")

var OUT: String = "/tmp/claude-0/-home-user/09449103-5068-5eff-93a6-3d4914815589/scratchpad/v2shots/map/"

# name, eye (x, z, height above ground or absolute if > 60), target (x, y_above_ground, z)
var views: Array = [
	["01_square_to_castle", Vector3(-3, 1.7, 2), Vector3(8, 40, -214)],
	["02_north_street", Vector3(4, 1.7, -78), Vector3(0, 2, -20)],
	["03_mill_bridge", Vector3(-30, 1.7, 92), Vector3(-62, 2, 60)],
	["04_forest_carvalha", Vector3(-160, 1.7, 36), Vector3(-185, 6, 25)],
	["05_bandit_camp", Vector3(-180, 1.7, 156), Vector3(-214, 3, 166)],
	["06_watchtower", Vector3(160, 1.7, -24), Vector3(186, 6, -46)],
	["07_mine", Vector3(170, 1.7, -150), Vector3(178, 4, -192)],
	["08_castle_road", Vector3(110, 1.7, -196), Vector3(8, 8, -214)],
	["09_lake_pier", Vector3(54, 1.7, 146), Vector3(30, 0, 220)],
	["10_farm", Vector3(66, 1.7, 46), Vector3(112, 2, 74)],
	["11_over_south", Vector3(20, 200, 330), Vector3(0, 0, -40)],
	["12_over_west", Vector3(-340, 170, -60), Vector3(0, 0, 10)],
	["13_over_northeast", Vector3(260, 160, -300), Vector3(-20, 0, 60)],
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
