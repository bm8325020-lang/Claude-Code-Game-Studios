# O jogador visto de fora (como o amigo vê): facão parado/andando/golpe, pistola parado/andando, correndo.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/foto_terceira.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	(load("res://scripts/main.gd") as GDScript).set("nascer_no_bairro", false)
	main.iniciar_solo("Foto")
	for i in 20: await process_frame
	main.ciclo.tempo = 100.0
	main.controles.visible = false
	for z in main.zumbis.get_children():
		z.free()
	var j: Jogador = main.jogador
	j.global_position = Vector3(30, 0.05, 30)
	for g: GeometryInstance3D in j.modelo.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON  # o próprio corpo aparece (o amigo vê)
	var c := Camera3D.new()
	c.fov = 30.0
	main.add_child(c)
	c.current = true
	var o := Image.create(1200, 450, false, Image.FORMAT_RGBA8)
	var poses: Array = [["facao", Vector2.ZERO, false], ["facao", Vector2(0, 1), false], ["facao", Vector2.ZERO, true],
		["pistola", Vector2.ZERO, false], ["pistola", Vector2(0, 1), false], ["pistola", Vector2(0.0, 1), false]]
	for k in poses.size():
		var p: Array = poses[k]
		j.usar_espaco(j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == p[0]))
		j.global_position = Vector3(30, 0.05, 30)
		j.camera.yaw = PI
		j.entrada["move"] = p[1]
		j.entrada["correr"] = k == 5
		for i in 40: await physics_frame
		j.camera.maos.alvo = null  # a arma da tela (primeira pessoa) não aparece para os outros
		j.camera.maos.visible = false
		for g: GeometryInstance3D in j.modelo.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if p[2]:
			j.entrada["atacar"] = true
			for i in 14: await physics_frame
		if OS.get_environment("DBG") != "":
			for g: GeometryInstance3D in (j.pistola if p[0] == "pistola" else j._facao).find_children("*", "GeometryInstance3D", true, false):
				print(k, " ", g.name, " vis=", g.is_visible_in_tree(), " sombra=", g.cast_shadow, " pos=", g.global_position, " mao=", j._esq.global_transform * j._esq.get_bone_global_pose(j._esq.find_bone(j.MAO)).origin, " layers=", g.layers)
		var frente: Vector3 = j.modelo.global_basis.z
		c.global_position = j.global_position + frente * 4.0 + Vector3(0, 1.3, 0) + j.modelo.global_basis.x * 1.5
		c.look_at(j.global_position + Vector3(0, 1.0, 0))
		await process_frame
		await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(400, 225)
		o.blit_rect(im, Rect2i(0, 0, 400, 225), Vector2i(400 * (k % 3), 225 * (k / 3)))
	o.save_png(OS.get_cmdline_user_args()[0])
	quit()
