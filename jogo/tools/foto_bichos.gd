# Foto dos bichos da floresta (lobo, javali, raposa) perto do jogador, numa trilha (13/11).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_bichos.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("FotoBichos")
	for i in 60: await process_frame
	main.ciclo.tempo = 120.0
	main.controles.visible = false
	var l := Vector2(75, -95)  # meio da trilha do acampamento militar (fora dela só se vê tronco)
	var p: Vector3 = Bairro.ORIGEM + Vector3(l.x, main.bairro.altura(l) + 0.3, l.y)
	main.jogador.global_position = p + Vector3(0, 0, 30)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.global_position = p + Vector3(-0.63, 0, 0.77) * 5.5 + Vector3(0, 1.4, 0)
	cam.look_at(p + Vector3(0, 0.5, 0))
	for k in 3:
		var b := Bicho.new()
		b.tipo = ["lobo", "javali", "raposa"][k]
		main.add_child(b)
		b.global_position = p + Vector3(0.77, 0, 0.63) * ((k - 1) * 1.8) + Vector3(0, 0.1, 0)
		b.set_physics_process(false)
		b.modelo.rotation.y = 0.6
	for i in 40: await process_frame
	var im: Image = root.get_viewport().get_texture().get_image()
	im.resize(960, 540)
	im.save_png(OS.get_cmdline_user_args()[0])
	quit()
