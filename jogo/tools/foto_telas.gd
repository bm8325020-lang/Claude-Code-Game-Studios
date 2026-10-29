# Folha com as telas da interface (menu, online, Wi-Fi, configurações, HUD no PC e no celular, pausa, queda):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_telas.gd -- saida.png
extends SceneTree

var fotos: Array[Image] = []


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	await _foto()
	main.menu._mostra("online")
	main.menu._busca_servidores()
	for i in 90: await process_frame
	await _foto()
	main.menu._mostra("wifi")
	await _foto()
	main.menu._mostra("config")
	await _foto()
	main.iniciar_solo("Foto")
	for i in 20: await process_frame
	main.ciclo.tempo = 0.0
	main.controles.aviso("Lanterna pega")
	await _foto()
	var c: Controles = main.controles
	c.toque = true
	c._monta_toque()
	await _foto()
	c.pausa(true)
	await _foto()
	c.pausa(false)
	main.jogador.levar_dano(1000, Vector3.FORWARD)
	for i in 30: await process_frame
	await _foto()
	var o := Image.create(640 * 4, 360 * 2, false, fotos[0].get_format())
	for k in fotos.size():
		o.blit_rect(fotos[k], Rect2i(0, 0, 640, 360), Vector2i(640 * (k % 4), 360 * (k / 4)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()


func _foto() -> void:
	for i in 4: await process_frame
	var im := root.get_viewport().get_texture().get_image()
	im.resize(640, 360)
	fotos.append(im)
