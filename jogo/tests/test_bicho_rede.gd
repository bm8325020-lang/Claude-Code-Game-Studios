# Bichos pela rede (14/11, dono: "pra que um jogo que só eu vejo os animais?"): dois processos. O servidor solta um
# lobo perto dos dois; o cliente tem que ver o mesmo lobo andar e machucá-lo (o golpe vira dano no servidor).
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_bicho_rede.gd -- servidor   (em segundo plano)
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_bicho_rede.gd -- cliente
extends SceneTree

var falhas: Array[String] = []


func ok(c: bool, o_que: String) -> void:
	if not c:
		falhas.append(o_que)


func espera_ms(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await physics_frame
		OS.delay_msec(16)


func _init() -> void:
	var papel: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "servidor"
	(load("res://scripts/main.gd") as GDScript).set("nascer_no_bairro", false)
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5: await physics_frame
	if papel == "servidor":
		ok(main.criar_partida("Servidor") == OK, "cria a partida")
	else:
		await espera_ms(2500)
		ok(main.entrar_partida("127.0.0.1", "Cliente") == OK, "conecta")
	var t0: int = Time.get_ticks_msec()
	while main.jogadores.get_child_count() < 2 and Time.get_ticks_msec() - t0 < 60000:  # a floresta demora a carregar
		await physics_frame
		OS.delay_msec(16)
	ok(main.jogadores.get_child_count() == 2, "vê 2 jogadores")
	main.controles.jogador = null
	for j: Node in main.jogadores.get_children():
		(j as Jogador).vida = 100000
	if papel == "servidor":
		var p: Vector3 = main.jogador.global_position + Vector3(6, 0.5, 0)
		main.spawner_bichos.spawn({"tipo": "lobo", "pos": p})
		await espera_ms(6000)
		var lobo: Bicho = main.bichos_no.get_child(0) if main.bichos_no.get_child_count() > 0 else null
		ok(lobo != null and lobo.vida < 60, "o golpe do cliente machucou o lobo no servidor (vida %s)" % (str(lobo.vida) if lobo else "-"))
	else:
		t0 = Time.get_ticks_msec()
		while main.bichos_no.get_child_count() == 0 and Time.get_ticks_msec() - t0 < 5000:
			await physics_frame
			OS.delay_msec(16)
		var lobo: Bicho = main.bichos_no.get_child(0) if main.bichos_no.get_child_count() > 0 else null
		ok(lobo != null and lobo.tipo == "lobo", "o cliente vê o lobo que o servidor soltou")
		if lobo:
			var ini: Vector3 = lobo.global_position
			await espera_ms(1500)
			ok(lobo.global_position.distance_to(ini) > 0.5, "o lobo anda no cliente (%.1f m)" % lobo.global_position.distance_to(ini))
			lobo.levar_golpe(25, Vector3.RIGHT, main.jogador)
			await espera_ms(2500)
	print("BICHO_REDE %s: %s %s" % [papel, "PASS" if falhas.is_empty() else "FAIL", ", ".join(falhas)])
	quit(1 if not falhas.is_empty() else 0)
