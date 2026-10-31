# Folha de fotos de modelos de assets/ruinas (pintados como no jogo), 2 por linha, vista de 3/4 pela frente.
#   xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tools/foto_modelos.gd -- saida.png sobrado_1 igreja ...
# Nome com ":dentro" fotografa de dentro (do meio para o fundo); ":cima" de cima.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cena := Node3D.new()
	root.add_child(cena)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	cena.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.shadow_enabled = true
	cena.add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	chao.mesh = pm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.35, 0.36, 0.32)
	chao.material_override = mc
	cena.add_child(chao)
	var cam := Camera3D.new()
	cam.far = 500
	cena.add_child(cam)
	cam.current = true
	await process_frame
	var b := Bairro.new()
	var n: int = args.size() - 1
	var linhas: int = (n + 1) / 2
	var o := Image.create(1280, 400 * linhas, false, Image.FORMAT_RGBA8)
	for k in n:
		var nome: String = args[k + 1].get_slice(":", 0)
		var modo: String = args[k + 1].get_slice(":", 1) if args[k + 1].contains(":") else ""
		var m: Node3D = (load(Bairro.RUINAS % nome) as PackedScene).instantiate()
		cena.add_child(m)
		b._pinta(m, Color(0.82, 0.8, 0.76))
		var a: AABB = Moveis._aabb(m)
		var t: float = maxf(maxf(a.size.x, a.size.z), a.size.y)
		var c: Vector3 = a.get_center()
		if modo == "dentro":
			cam.global_position = Vector3(c.x - a.size.x * 0.3, 1.6, a.end.z - 1.0)
			cam.look_at(Vector3(c.x + a.size.x * 0.2, 1.3, a.position.z + 1.0))
		elif modo == "cima":
			cam.global_position = c + Vector3(t * 0.4, t * 1.3, t * 0.9)
			cam.look_at(c)
		else:
			cam.global_position = c + Vector3(-t * 0.75, t * 0.35 + 1.0, t * 1.05)
			cam.look_at(c + Vector3(0, -a.size.y * 0.1, 0))
		for i in 6:
			await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 400)
		o.blit_rect(im, Rect2i(0, 0, 640, 400), Vector2i(640 * (k % 2), 400 * (k / 2)))
		m.free()
	o.save_png(args[0])
	b.free()
	quit()
