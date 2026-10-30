# Fotos dos modelos de assets/sketchfab/cidade (por fora e por dentro), em grade, e imprime o tamanho de cada um:
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_modelos.gd -- saida.png [filtro]
extends SceneTree

const PASTA := "res://assets/sketchfab/cidade/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var filtro: String = args[1] if args.size() > 1 else ""
	var mundo := Node3D.new()
	root.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	sol.shadow_enabled = true
	mundo.add_child(sol)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(0.6, 0.65, 0.7)
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	mundo.add_child(amb)
	var cam := Camera3D.new()
	cam.fov = 70
	mundo.add_child(cam)
	var fotos: Array[Image] = []
	for f in DirAccess.get_files_at(PASTA):
		if not f.ends_with(".glb") or (filtro != "" and not f.contains(filtro)):
			continue
		var m: Node3D = (load(PASTA + f) as PackedScene).instantiate()
		mundo.add_child(m)
		var cx := AABB()
		var primeiro := true
		var n_mesh := 0
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = mi.global_transform * mi.get_aabb()
			cx = a if primeiro else cx.merge(a)
			primeiro = false
			n_mesh += 1
		print("%s: tamanho %s, base %s, %d malhas" % [f, cx.size, cx.position, n_mesh])
		var c: Vector3 = cx.get_center()
		var r: float = cx.size.length()
		cam.position = c + Vector3(r * 0.4, r * 0.2, r * 0.4)
		cam.look_at(c)
		for i in 4: await process_frame
		fotos.append(root.get_texture().get_image())
		cam.position = Vector3(c.x, cx.position.y + minf(cx.size.y * 0.3, 4.3), c.z)
		cam.rotation = Vector3(0, 0.7, 0)
		for i in 4: await process_frame
		fotos.append(root.get_texture().get_image())
		m.free()
	var w := 320
	var h := 180
	var grade := Image.create(w * 4, h * ceili(fotos.size() / 4.0), false, Image.FORMAT_RGB8)
	for i in fotos.size():
		fotos[i].convert(Image.FORMAT_RGB8)
		fotos[i].resize(w, h)
		grade.blit_rect(fotos[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
	grade.save_png(args[0])
	quit()
