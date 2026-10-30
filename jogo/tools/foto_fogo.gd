# Fotos do fogo: barril de perto (dia e noite) e casa queimada com coluna de fumaça (de perto e de longe).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_fogo.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto")
	for i in 30: await process_frame
	main.controles.visible = false
	var fogos: Array = main.bairro.find_children("*", "Fogo", false, false)
	var barril: Node3D = fogos.filter(func(f: Fogo) -> bool: return not f.coluna)[0]
	var casa: Node3D = fogos.filter(func(f: Fogo) -> bool: return f.coluna)[0]
	var c := Camera3D.new()
	main.add_child(c)
	c.current = true
	c.far = 600
	var vistas: Array = [[100.0, barril, Vector3(3, 1.6, 3)], [Ciclo.DIA + 60.0, barril, Vector3(3, 1.6, 3)],
		[Ciclo.DIA + 60.0, casa, Vector3(10, 3, 10)], [100.0, casa, Vector3(80, 20, 80)]]
	var o := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for k in vistas.size():
		main.ciclo.tempo = vistas[k][0]
		c.global_position = (vistas[k][1] as Node3D).global_position + vistas[k][2]
		c.look_at((vistas[k][1] as Node3D).global_position + Vector3(0, 1.0 if k < 3 else 8.0, 0))
		for i in 40: await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * (k % 2), 360 * (k / 2)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()
