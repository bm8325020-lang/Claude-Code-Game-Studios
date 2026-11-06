# Foto do rádio do canto falando (06/11). Rodar com tela: xvfb-run ... -s res://tools/foto_radio.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoRadio")
	for i in 90: await process_frame
	var t: Tarefas = main.controles._tarefas
	t._fila_radio.clear()
	t._legenda_t = 0.0
	t.legenda("RÁDIO · DANA", String(Tarefas.ROTEIRO[2][7].radio), 8.0)
	for i in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
