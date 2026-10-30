# Capa (fundo do menu e da tela de carregamento): a cidade vista do alto do morro no fim da tarde, com fumaça.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_capa.gd -- assets/ui/capa.jpg
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Capa")
	for i in 5: await process_frame
	main.controles.visible = false
	main.ciclo.tempo = Ciclo.DIA - 25.0  # anoitecendo
	var c := Camera3D.new()
	main.add_child(c)
	c.current = true
	c.far = 700
	c.fov = 60
	var centro := Bairro.ORIGEM + Vector3(0, 0, 20)
	c.global_position = Bairro.ORIGEM + Vector3(-150, 28, -150)
	c.look_at(centro + Vector3(0, 2, 0))
	for i in 25: await process_frame  # renderização de software (xvfb) é lenta: poucos quadros bastam
	var im := root.get_viewport().get_texture().get_image()
	im.save_jpg(OS.get_cmdline_user_args()[0], 0.85)
	quit()
