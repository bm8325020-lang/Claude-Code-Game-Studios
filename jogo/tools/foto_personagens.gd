# Foto dos personagens (jogador, os 3 zumbis e o chefe) lado a lado, andando, vistos de frente.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/foto_personagens.gd -- saida.png
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.ciclo.tempo = 100.0
	main.menu.visible = false
	var nomes: Array = [Anims.JOGADOR] + Array(Anims.ZUMBIS) + [Anims.CHEFE]
	for k in nomes.size():
		var b: Node3D = Anims.boneco(nomes[k])
		if nomes[k] == Anims.CHEFE:
			b.scale = Vector3.ONE * Zumbi.ESCALA_CHEFE
		main.add_child(b)
		b.global_position = Vector3(60 + (k - 2) * 1.6, 0, 60)
		var ap := AnimationPlayer.new()
		b.add_child(ap)
		ap.add_animation_library("", Anims.adaptada(Anims.biblioteca() if k == 0 else Anims.biblioteca_zumbi(), nomes[k]))
		ap.play("andar")
		ap.seek(0.4, true)
	var c := Camera3D.new()
	main.add_child(c)
	c.global_position = Vector3(60, 1.4, 65.5)
	c.look_at(Vector3(60, 1.0, 60))
	c.current = true
	for i in 20: await process_frame
	var im := root.get_viewport().get_texture().get_image()
	im.resize(960, 540)
	im.save_png(OS.get_cmdline_user_args()[0])
	quit()
