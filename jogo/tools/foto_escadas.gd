# Foto das escadas dos fundos e do telhado dos sobrados (05/11): -- saida.png
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
	var o := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	var escadas: Array = main.bairro.find_children("EscadaFundos", "StaticBody3D", true, false)
	for k in 4:
		var m: Node3D = escadas[k * 3 % escadas.size()].get_parent()
		var no: Node3D = m.get_parent()
		var tam: Vector2 = main.bairro._tam_ruina(String(no.get_meta("modelo")))
		var alvo: Vector3 = m.to_global(Vector3(-tam.x * 0.5 + 2.9, 3.0, -tam.y * 0.5 - 1.3))
		if k < 3:
			c.global_position = m.to_global(Vector3(-tam.x * 0.5 - 6.0, 2.5, -tam.y * 0.5 - 9.0))
		else:  # de cima do telhado
			c.global_position = m.to_global(Vector3(0, float(no.get_meta("teto")) + 1.2, 0))
			alvo = m.to_global(Vector3(tam.x * 2.0, float(no.get_meta("teto")), 0))
		c.look_at(alvo)
		for i in 8: await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * (k % 2), 360 * (k / 2)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()
