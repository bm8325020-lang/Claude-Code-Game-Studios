# Foto do jogo de verdade (HUD na tela) em terceira e em primeira pessoa, no meio da mata (13/11).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_3p.gd -- saida.png [x,z]
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto3P")
	print("FOTO3P iniciou")
	for i in 90: await process_frame
	main.ciclo.tempo = 120.0
	var j: Jogador = main.jogador
	j.vida = 1000000
	j.fome = 15.0  # para ver o aviso piscando
	if args.size() > 1:
		var xz: PackedStringArray = args[1].split(",")
		var l := Vector2(float(xz[0]), float(xz[1]))
		j.global_position = Bairro.ORIGEM + Vector3(l.x, main.bairro.altura(l) + 0.5, l.y)
	var imgs: Array[Image] = []
	for terceira: bool in [true, false]:
		Config.v.terceira = terceira
		for i in 90: await process_frame
		var im: Image = root.get_viewport().get_texture().get_image()
		im.resize(640, 360)
		imgs.append(im)
	var out := Image.create(1280, 360, false, imgs[0].get_format())
	for k in 2:
		out.blit_rect(imgs[k], Rect2i(0, 0, 640, 360), Vector2i(k * 640, 0))
	print("FOTO3P salva: ", out.save_png(args[0]), " ", args[0])
	quit()
