# Fotos do refúgio cercado e da frente do hospital/delegacia/mercado (06/11). xvfb ... -s res://tools/foto_lugares.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoLugares")
	for i in 60: await process_frame
	main.controles.visible = false
	var b: Bairro = main.bairro
	var alvos: Array = []
	for n: Node in b.find_children("Refugio_*", "", true, false).slice(0, 2):
		alvos.append((n as Node3D).global_position)
	var dirs: Array = [Vector3(14, 9, 14), Vector3(14, 9, 14)]
	for nome: String in ["Hospital", "Delegacia", "Mercado"]:
		var no: Node3D = b.get_node_or_null(nome)
		if no and no.has_meta("frente"):
			var fr: Vector3 = no.get_meta("frente")
			var c: Vector2 = b._centro(no.get_meta("poly")) if no.has_meta("poly") else Vector2(fr.x, fr.z - 10)
			var fora := (Vector2(fr.x, fr.z) - (c + Vector2(Bairro.ORIGEM.x, Bairro.ORIGEM.z))).normalized()
			print(nome, " poly=", no.has_meta("poly"), " fora=", fora)
			alvos.append(fr)
			dirs.append(Vector3(fora.x * 20, 8, fora.y * 20))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var imgs: Array[Image] = []
	for ia in alvos.size():
		var a: Vector3 = alvos[ia]
		main.jogador.global_position = a + Vector3(0, 0.5, 0)
		cam.global_position = a + dirs[ia]
		cam.look_at(a + Vector3(0, 1, 0))
		for i in 30: await process_frame
		var im: Image = root.get_viewport().get_texture().get_image()
		im.resize(640, 360)
		imgs.append(im)
	print("fotos: ", imgs.size(), " alvos ", alvos)
	var out := Image.create(1280, 360 * ceili(imgs.size() / 2.0), false, imgs[0].get_format())
	for k in imgs.size():
		out.blit_rect(imgs[k], Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
