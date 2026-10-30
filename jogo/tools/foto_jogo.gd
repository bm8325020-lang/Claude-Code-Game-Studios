extends SceneTree
func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto")
	for i in 20: await process_frame
	main.ciclo.tempo = float(OS.get_cmdline_user_args()[1])
	for i in 30: await process_frame
	var im := root.get_viewport().get_texture().get_image()
	im.resize(640, 360)
	im.save_png(OS.get_cmdline_user_args()[0])
	quit()
