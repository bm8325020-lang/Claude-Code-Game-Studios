# Uma foto da pista com o jogador correndo (para conferir animação e câmera): xvfb-run ... -s res://tools/foto.gd -- saida.png
extends SceneTree
func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.controles.jogador = null
	var j: Jogador = main.jogador
	j.camera.yaw = 0.6
	j.entrada["move"] = Vector2(0.3, 1)
	for i in 50: await process_frame
	var saida: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/foto.png"
	root.get_viewport().get_texture().get_image().save_png(saida)
	quit()
