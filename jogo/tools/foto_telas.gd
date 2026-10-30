# Folha com as telas da interface (menu, criar sala, entrar, configurações, espera, HUD no PC e no celular, pausa, queda):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_telas.gd -- saida.png
extends SceneTree

var fotos: Array[Image] = []


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	await _foto()
	main.menu._mostra("criar")
	await _foto()
	main.menu._mostra("entrar")
	main.menu._relay_msg({"op": "lista", "salas": [{"codigo": "AB12", "nome": "Zumbilândia", "n": 2, "max": 4, "comecou": true}, {"codigo": "CD34", "nome": "Só os brabo", "n": 1, "max": 8, "comecou": false}]})
	await _foto()
	main.menu._mostra("config")
	await _foto()
	main.iniciar_solo("Foto")
	for i in 20: await process_frame
	main.esperando = true
	main.sala_sobrev = {"codigo": "AB12", "nome": "Zumbilândia", "max": 4, "n": 2}
	await _foto()
	main.esperando = false
	main.ciclo.tempo = 0.0
	main.controles.aviso("Lanterna pega")
	await _foto()
	main.jogador.mochila.adicionar("comida", 3)
	main.jogador.mochila.adicionar("agua", 2)
	main.controles.abre_mochila(true)
	main.controles._mochila._toque(2)
	for i in 10: await process_frame
	await _foto()
	main.controles.abre_mochila(false)
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
	var o := Image.create(800 * 3, 360 * 4, false, fotos[0].get_format())
	for k in fotos.size():
		o.blit_rect(fotos[k], Rect2i(0, 0, 800, 360), Vector2i(800 * (k % 3), 360 * (k / 3)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()


func _foto() -> void:
	for i in 4: await process_frame
	var im := root.get_viewport().get_texture().get_image()
	im.resize(800, 360)
	fotos.append(im)
