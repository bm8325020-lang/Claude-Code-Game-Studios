# Foto do boneco de lado e de costas com a mochila (06/11). xvfb-run ... -s res://tools/foto_mochila.gd -- saida.png
extends SceneTree


func _init() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 30, 0)
	raiz.add_child(luz)
	var m: Node3D = Anims.boneco(Anims.JOGADOR)
	raiz.add_child(m)
	Anims.poe_mochila(m)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	var fotos: Array[Image] = []
	for ang: float in [PI * 0.5, PI]:  # de lado, de costas
		cam.position = Vector3(sin(ang) * 2.6, 1.2, cos(ang) * 2.6)
		cam.look_at(Vector3(0, 1.1, 0))
		for i in 6: await process_frame
		fotos.append(root.get_viewport().get_texture().get_image())
	var w: int = fotos[0].get_width()
	var out := Image.create(w * 2, fotos[0].get_height(), false, fotos[0].get_format())
	for k in 2:
		out.blit_rect(fotos[k], Rect2i(0, 0, w, fotos[k].get_height()), Vector2i(w * k, 0))
	out.resize(1200, 340)
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
