# Foto do avião de carga passando (14/11, item 6).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_aviao.gd -- saida.png
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoAviao")
	for i in 90: await process_frame
	main.ciclo.tempo = 120.0
	var j: Jogador = main.jogador
	j.vida = 1000000
	Config.v.terceira = true
	var b: Bairro = main.bairro
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	var rumo := Vector3(1, 0, 0.3).normalized()
	main.aviao_passa(j.global_position + rumo * 40.0, rumo)
	j.camera.virar(atan2(-rumo.x, -rumo.z), -0.5)
	var a: Aviao = main.get_children().filter(func(n: Node) -> bool: return n is Aviao)[0]
	a.global_position = j.global_position + Vector3(0, Aviao.ALTURA, 0) + rumo * 45.0
	for i in 40: await process_frame
	a.global_position = j.global_position + Vector3(0, Aviao.ALTURA, 0) + rumo * 45.0  # a foto demora: põe de novo
	a.set_process(false)
	for i in 3: await process_frame
	var im: Image = root.get_viewport().get_texture().get_image()
	im.resize(960, 540)
	print("FOTOAVIAO salva: ", im.save_png(args[0]))
	quit()
