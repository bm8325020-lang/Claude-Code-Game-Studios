# Map agent calibration: builds sample houses on a plane and saves screenshots.
extends SceneTree

const Kit = preload("res://world/kit.gd")
const Bld = preload("res://world/buildings.gd")

const OUT: String = "/tmp/claude-0/-home-user/09449103-5068-5eff-93a6-3d4914815589/scratchpad/v2shots/map/"

func _init() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	var kit: Kit = Kit.new()
	var bt: Kit.Batch = kit.batch()
	var bl: Bld = Bld.new(kit, bt, 3)
	bl.house(Transform3D(Basis(), Vector3(0, 0, 0)), {"w": 3, "d": 4, "floors": 2, "style": "brick", "balcony": true, "seed": 4})
	bl.house(Transform3D(Basis(), Vector3(12, 0, 0)), {"w": 2, "d": 3, "floors": 1, "style": "wood", "ridge": "x", "seed": 7})
	bt.commit(root, "test", true)
	var pl: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new(); pm.size = Vector2(80, 80); pl.mesh = pm
	root.add_child(pl)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0); sun.shadow_enabled = true
	root.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.6, 0.7, 0.85)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var cam: Camera3D = Camera3D.new(); root.add_child(cam)
	var views: Array = [[Vector3(10, 6, 16), Vector3(4, 3, 0)], [Vector3(-8, 7, -14), Vector3(4, 3, 0)]]
	for i in views.size():
		cam.look_at_from_position(views[i][0], views[i][1])
		for f in 6: await process_frame
		get_root().get_texture().get_image().save_png(OUT + "house_%d.png" % i)
	quit()
