# Foto do fogo (14/11): fogueira de acampamento e fogo grande (casa queimada), de dia e de noite, de perto.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_fogo.gd -- saida.png
extends SceneTree


func _foto(imgs: Array[Image]) -> void:
	for i in 60: await process_frame
	var im: Image = root.get_viewport().get_texture().get_image()
	im.resize(640, 360)
	imgs.append(im)


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoFogo")
	for i in 90: await process_frame
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var j: Jogador = main.jogador
	j.vida = 1000000
	var b: Bairro = main.bairro
	Config.v.terceira = true
	var fr := Vector3(-b.inicio_dir.z, 0, b.inicio_dir.x)
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	var c: Vector3 = b.inicio_pos + fr * 3.5 - Vector3(0, 0.1, 0)
	var f := Fogo.new()
	f.tamanho = 0.45
	f.lenha = true
	main.add_child(f)
	f.global_position = c
	var g := Fogo.new()
	g.tamanho = 1.5
	g.coluna = true
	main.add_child(g)
	g.global_position = c + fr * 9.0 + b.inicio_dir * 4.0
	j.camera.virar(atan2(-fr.x, -fr.z), -0.15)
	var imgs: Array[Image] = []
	for tempo: float in [120.0, Ciclo.DIA + Ciclo.NOITE * 0.4]:
		main.ciclo.tempo = tempo
		main.ciclo.set_process(true)
		await process_frame
		main.ciclo.set_process(false)
		Config.v.terceira = true
		await _foto(imgs)
		Config.v.terceira = false
		await _foto(imgs)
	var out := Image.create(1280, 720, false, imgs[0].get_format())
	for k in 4:
		out.blit_rect(imgs[k], Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))
	print("FOTOFOGO salva: ", out.save_png(args[0]))
	quit()
