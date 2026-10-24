# Foto do golpe de facão num boneco de treino: xvfb-run ... -s res://tools/foto_facao.gd -- saida.png
extends SceneTree
func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("Foto")
	for i in 5: await physics_frame
	main.controles.jogador = null
	var j: Jogador = main.jogador
	j.global_position = Vector3(-3, 0.1, 2.7)
	j.reset_physics_interpolation()
	j.camera.yaw = PI - 0.9
	j.camera.pitch = deg_to_rad(8)
	j.modelo.rotation.y = 0.0
	for i in 20: await process_frame
	j.entrada["atacar"] = true
	for i in 22: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
