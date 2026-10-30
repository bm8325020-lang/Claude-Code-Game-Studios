# Fotos do relevo da cidade: ponte sobre o rio (de lado e de cima da margem) e o morro.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_relevo.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto")
	for i in 30: await process_frame
	main.ciclo.tempo = 100.0
	main.controles.visible = false
	var b: Bairro = main.bairro
	var c := Camera3D.new()
	main.add_child(c)
	c.current = true
	c.far = 600
	var ponte: Node3D = b.get_node("Ponte_1")
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Bairro.MAPA))
	var m: Array = dados.terreno.morros
	var topo: Vector3 = Bairro.ORIGEM + Vector3(m[0].p[0], m[0].alt, m[0].p[1]) if not m.is_empty() else Vector3.ZERO
	var lado: Vector3 = ponte.global_basis.x
	var vistas: Array = [[ponte.global_position + lado * 16.0 + Vector3(0, 4.0, 0), ponte.global_position + Vector3(0, -1.5, 0)],
		[ponte.global_position + ponte.global_basis.z * 14.0 + Vector3(0, 1.7, 0), ponte.global_position + Vector3(0, 1.0, 0)],
		[topo + Vector3(70, -7.0, 70), topo],
		[topo + Vector3(0, 1.7, 0), topo + Vector3(60, -4, 60)]]
	var o := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for k in vistas.size():
		c.global_position = vistas[k][0]
		c.look_at(vistas[k][1])
		for i in 6: await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * (k % 2), 360 * (k / 2)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()
