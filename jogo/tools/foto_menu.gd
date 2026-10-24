# Foto do menu inicial: xvfb-run ... -s res://tools/foto_menu.gd -- saida.png
extends SceneTree
func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
