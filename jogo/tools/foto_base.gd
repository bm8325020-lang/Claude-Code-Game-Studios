# Fotos do pacote de 14/11: o acampamento destruído onde se acorda (item 5) e uma base montada (item 2), de dia e de noite.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_base.gd -- saida.png
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
	main.iniciar_solo("FotoBase")
	for i in 90: await process_frame
	main.ciclo.tempo = 120.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var j: Jogador = main.jogador
	j.vida = 1000000
	var b: Bairro = main.bairro
	Config.v.terceira = true
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	j.camera.virar(atan2(-b.inicio_dir.x, -b.inicio_dir.z), -0.25)
	var imgs: Array[Image] = []
	await _foto(imgs)
	# base 25 m trilha abaixo: barraca, cabana, torre, horta, baú e cerca em volta
	var fr := Vector3(-b.inicio_dir.z, 0, b.inicio_dir.x)
	var c: Vector3 = b.inicio_pos + fr * 25.0
	var lado: Vector3 = b.inicio_dir
	var ang: float = atan2(lado.x, lado.z)
	main._poe_peca("barraca", c + lado * 4.0, ang, "FotoBase")
	main._poe_peca("cabana", c - lado * 5.0 + fr * 2.0, ang, "FotoBase")
	main._poe_peca("torre", c + fr * 7.0 + lado * 4.0, ang, "FotoBase")
	main._poe_peca("horta", c + lado * 2.0 - fr * 4.0, ang, "FotoBase")
	main._poe_peca("bau_base", c + lado * 4.0 + fr * 2.0, ang, "FotoBase")
	for k in 4:
		main._poe_peca("estacas", c + lado * 9.0 + fr * (-5.0 + k * 3.4), ang, "FotoBase")
	var fogo := Fogo.new()
	fogo.tamanho = 0.45
	fogo.lenha = true
	main.add_child(fogo)
	fogo.global_position = c + Vector3(0, b.altura(Vector2(c.x - Bairro.ORIGEM.x, c.z - Bairro.ORIGEM.z)) - c.y + Bairro.ORIGEM.y + 0.05, 0)
	j.global_position = c - lado * 12.0 + fr * 6.0 + Vector3(0, 0.5, 0)
	j.camera.virar(atan2(-(c - j.global_position).x, -(c - j.global_position).z), -0.2)
	await _foto(imgs)
	main.ciclo.tempo = Ciclo.DIA + Ciclo.NOITE * 0.4  # meio da noite
	main.ciclo.set_process(true)
	await process_frame
	main.ciclo.set_process(false)
	await _foto(imgs)
	j.global_position = c - fr * 2.0 + Vector3(0, 0.5, 0)  # do lado da fogueira (não em cima)
	await _foto(imgs)
	var out := Image.create(1280, 720, false, imgs[0].get_format())
	for k in 4:
		out.blit_rect(imgs[k], Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))
	print("FOTOBASE salva: ", out.save_png(args[0]), " ", args[0])
	quit()
