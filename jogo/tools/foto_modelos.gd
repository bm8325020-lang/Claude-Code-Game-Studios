# Folha de fotos de modelos de assets/ruinas (pintados como no jogo), 2 por linha, vista de 3/4 pela frente.
#   xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tools/foto_modelos.gd -- saida.png sobrado_1 igreja ...
# Nome com ":dentro" fotografa de dentro (do meio para o fundo); ":cima" de cima; ":planta" de cima, sem telhado e
# sem forro, para conferir a mobília (frente da casa embaixo); ":ver=sofa_sala" olha para o móvel de frente (de dentro do cômodo).
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
	var tw: int = 1280 if n == 1 else 640  # um modelo só: foto grande
	var th: int = 800 if n == 1 else 400
	var o := Image.create(1280, th * linhas, false, Image.FORMAT_RGBA8)
	for k in n:
		var nome: String = args[k + 1].get_slice(":", 0)
		var modo: String = args[k + 1].get_slice(":", 1) if args[k + 1].contains(":") else ""
		var arq: String = ("res://assets/%s.glb" % nome) if nome.contains("/") else (Bairro.RUINAS % nome)  # "mundo/..." = asset pronto
		if nome.contains("/") and not ResourceLoader.exists(arq):  # normaliza.py: pasta/<nome>/<nome>.gltf
			arq = "res://assets/%s/%s.gltf" % [nome, nome.get_file()]
		var m: Node3D = (load(arq) as PackedScene).instantiate()
		cena.add_child(m)
		if not nome.contains("/"):  # asset pronto fica com as texturas dele
			b._pinta(m, Color(0.82, 0.8, 0.76))
		var forros: Array = []
		if modo == "planta":
			for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
				var nm: String = String(mi.name) + String(mi.get_parent().name)
				if nm.contains("telhado") or nm.contains("cobertura") or nm.contains("oitao") or nm.contains("testeira") or nm.contains("chamine"):
					mi.visible = false
				for i in mi.mesh.get_surface_count():
					var sm: Material = mi.mesh.surface_get_material(i)
					var so: Material = mi.get_surface_override_material(i)
					var nomes: String = (sm.resource_name if sm else "") + " " + (so.resource_name if so else "")
					if nomes.contains("forro") or nomes.contains("shingle") or nomes.contains("telh"):
						forros.append([mi, i])
		var some := StandardMaterial3D.new()
		some.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		some.albedo_color = Color(0, 0, 0, 0)
		for f: Array in forros:
			(f[0] as MeshInstance3D).set_surface_override_material(f[1], some)
		var a: AABB = Moveis._aabb(m)
		var t: float = maxf(maxf(a.size.x, a.size.z), a.size.y)
		var c: Vector3 = a.get_center()
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		if modo.begins_with("ver="):
			var alvo: Node3D = null
			var arg: String = modo.substr(4)
			var dist: float = float(arg.get_slice(",", 1)) if arg.contains(",") else 2.2  # negativo: por trás do móvel
			for no: Node in m.find_children(arg.get_slice(",", 0) + "*", "Node3D", true, false):
				alvo = no
				break
			if alvo:
				var fr: Vector3 = alvo.global_basis.z.normalized()  # frente do móvel (-Y do Blender)
				cam.fov = 80.0
				cam.global_position = alvo.global_position + fr * dist + alvo.global_basis.x.normalized() * 0.4 + Vector3(0, 1.7, 0)
				cam.look_at(alvo.global_position + fr * (2.0 if dist < 0 else 0.0) + Vector3(0, 0.5, 0))
		elif modo == "planta":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = maxf(a.size.x, a.size.z) * 1.05
			cam.global_position = c + Vector3(0, 40, 0)
			cam.look_at(c, Vector3(0, 0, -1))
		elif modo == "dentro":
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
		im.resize(tw, th)
		o.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i(tw * (k % 2), th * (k / 2)))
		m.free()
	o.save_png(args[0])
	b.free()
	quit()
