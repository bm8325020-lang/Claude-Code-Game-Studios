# Fotos da Estação Halverson (14/11, ESTACAO.md): de fora, corredor, laboratório com o Paciente Zero, UV na cara dele.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_estacao.gd -- saida.png
extends SceneTree


func _foto(imgs: Array[Image]) -> void:
	for i in 45: await process_frame
	var im: Image = root.get_viewport().get_texture().get_image()
	im.resize(640, 360)
	imgs.append(im)


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoEstacao")
	for i in 90: await process_frame
	main.ciclo.tempo = 150.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var j: Jogador = main.jogador
	j.vida = 1000000
	var e: Estacao = Estacao.atual
	print("FOTO estacao ", e != null)
	var pz: PacienteZero = main.spawner_zumbis.spawn({"pos": e.to_global(Vector3(5.0, 0.2, -8.0)), "pz": true})
	pz.set_physics_process(false)
	Config.v.terceira = false
	var imgs: Array[Image] = []
	var vistas: Array = [[Vector3(-8, 0.3, 26), 0.0, -0.1], [Vector3(-14, 0.3, 0), -PI * 0.5, 0.0], [Vector3(3, 0.3, -2.5), 0.0, -0.05], [Vector3(3, 0.3, -4.0), 0.25, 0.0]]
	for k in 4:
		var v: Array = vistas[k]
		j.global_position = e.to_global(v[0])
		j.camera.virar(e.rotation.y + float(v[1]), float(v[2]))
		if k == 3:
			j.mochila.adicionar("filtro_uv", 1)
			j.uv = true
			pz.modelo.rotation.y = PI
		await _foto(imgs)
	var out := Image.create(1280, 720, false, imgs[0].get_format())
	for k in 4:
		out.blit_rect(imgs[k], Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))
	print("FOTOESTACAO salva: ", out.save_png(args[0]))
	quit()
