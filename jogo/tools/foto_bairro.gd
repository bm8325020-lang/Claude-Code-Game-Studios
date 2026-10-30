# Fotos da cidade (Senoia): de cima e na rua, perto de uma casa e de uma mansão.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_bairro.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	var t0: int = Time.get_ticks_msec()
	main.iniciar_solo("Foto")
	print("iniciar_solo: ", Time.get_ticks_msec() - t0, " ms")
	for i in 30: await process_frame
	main.ciclo.tempo = 100.0
	main.controles.visible = false
	var c := Camera3D.new()
	main.add_child(c)
	c.current = true
	c.far = 600
	var b: Bairro = main.bairro
	var casa: Node3D = b.get_node("Casa_4")
	var mansao: Node3D = b.get_node("Mansao_0")
	var vistas: Array = [[Bairro.ORIGEM + Vector3(-120, 90, 130), Bairro.ORIGEM],
		[(casa.get_meta("frente") as Vector3) + Vector3(6, 1.6, 6), casa.get_meta("frente") + Vector3(0, 1.5, 0) - (casa.get_meta("frente") - Bairro.ORIGEM).normalized() * 0.0],
		[(mansao.get_meta("frente") as Vector3) + Vector3(-7, 1.7, 7), mansao.get_meta("frente") + Vector3(0, 1.8, 0)],
		[main.jogador.global_position + Vector3(0, 1.62, 0), main.jogador.global_position + Vector3(10, 1.4, -10)]]
	var o := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for k in vistas.size():
		c.global_position = vistas[k][0]
		c.look_at(vistas[k][1])
		if k == 1:  # da rua para a casa
			c.look_at(Bairro.ORIGEM + Vector3(_cx(casa).x, 2.0, _cx(casa).y))
		if k == 2:
			c.look_at(Bairro.ORIGEM + Vector3(_cx(mansao).x, 2.5, _cx(mansao).y))
		for i in 6: await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * (k % 2), 360 * (k / 2)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()


func _cx(n: Node3D) -> Vector2:
	var p: PackedVector2Array = n.get_meta("poly")
	var c := Vector2.ZERO
	for q in p:
		c += q
	return c / p.size()
