# Fotos de cima dos lugares novos da E6 (12/11): pátio de contêineres, acampamento caído, garagem de ônibus, posto dos Corvos.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_e6.gd -- saida.png x,z x,z ...
# (x,z = coordenadas da planta, as que tools/mapa/senoia.py imprime)
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoE6")
	for i in 60: await process_frame
	main.controles.visible = false
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	main.jogador.vida = 1000000
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var imgs: Array[Image] = []
	for k in range(1, args.size()):
		var xz: PackedStringArray = args[k].split(",")
		var p2 := Vector2(float(xz[0]), float(xz[1]))
		var a: Vector3 = Bairro.ORIGEM + Vector3(p2.x, main.bairro.altura(p2), p2.y)
		main.jogador.global_position = a + Vector3(0, 0.5, 0)
		cam.global_position = a + Vector3(0, 30, 34)
		cam.look_at(a)
		for i in 40: await process_frame
		var im: Image = root.get_viewport().get_texture().get_image()
		im.resize(640, 360)
		imgs.append(im)
	var out := Image.create(1280, 360 * ceili(imgs.size() / 2.0), false, imgs[0].get_format())
	for k in imgs.size():
		out.blit_rect(imgs[k], Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))
	out.save_png(args[0])
	quit()
