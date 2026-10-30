# Fotos do bairro: de cima (como a referência do dono) e na altura do jogador.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_bairro.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto")
	for i in 30: await process_frame
	main.ciclo.tempo = 100.0
	main.controles.visible = false
	var c := Camera3D.new()
	main.add_child(c)
	c.current = true
	var o := Image.create(1280, 360, false, Image.FORMAT_RGBA8)
	var vistas: Array = [[Bairro.ORIGEM + Vector3(-45, 40, 45), Bairro.ORIGEM], [main.jogador.global_position + Vector3(0, 1.6, 0), main.jogador.global_position + Vector3(0, 1.4, 0) + main.jogador.global_basis.z * -1.0 + Vector3(0, 0, 0)]]
	for k in 2:
		c.global_position = vistas[k][0]
		c.look_at(vistas[k][1] if k == 0 else Bairro.ORIGEM + Vector3(0, 1.5, 0))
		for i in 6: await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * k, 0))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()
