# Foto do HUD jogando na cidade (minimapa, barras, mira), 1280x720:
#   xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tools/foto_hud.gd -- saida.png [x,z,giro] [arma[:mira]]
# arma: põe na mochila e saca (pistola, smg, espingarda, fuzil, sniper...); ":mira" = mirando.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Foto")
	for i in 40: await process_frame
	main.ciclo.tempo = 100.0
	if args.size() > 1:
		var v: PackedStringArray = args[1].split(",")
		var p := Vector2(float(v[0]), float(v[1]))
		main.jogador.global_position = Bairro.ORIGEM + Vector3(p.x, main.bairro.altura(p) + 0.2, p.y)
		main.jogador.rotation.y = deg_to_rad(float(v[2])) if v.size() > 2 else 0.0
		if main.jogador.camera:
			main.jogador.camera.virar(deg_to_rad(float(v[2])) if v.size() > 2 else 0.0, 0.0)
	if args.size() > 2:
		var arma: String = args[2].get_slice(":", 0)
		main.jogador.mochila.adicionar(arma, 1)
		main.jogador.entrada["arma"] = arma
		main.jogador.mira_travada = args[2].ends_with(":mira")
	for i in 60: await process_frame
	root.get_texture().get_image().save_png(args[0])
	quit()
