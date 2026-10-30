# Foto do tiro em primeira pessoa (rastro saindo do cano da arma da tela): pistola e smg lado a lado.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_tiro.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto")
	for i in 20: await process_frame
	main.ciclo.tempo = 0.0
	var j: Jogador = main.jogador
	j.mochila.adicionar("smg", 1)
	var o := Image.create(1280, 360, false, Image.FORMAT_RGBA8)
	var k: int = 0
	for arma: String in ["pistola", "smg"]:
		j.usar_espaco(j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == arma))
		for i in 60: await process_frame
		j.entrada["atacar"] = true
		j.entrada["atirando"] = true
		for i in 2: await process_frame
		print(arma, " boca na tela: ", j.camera.cam.unproject_position(j.camera.maos.boca(arma)))
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * k, 0))
		j.entrada["atirando"] = false
		k += 1
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()
