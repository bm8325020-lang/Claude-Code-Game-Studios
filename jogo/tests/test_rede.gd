# Teste da mecânica 2 com dois processos: um cria a partida, o outro entra pelo IP local.
# Rodar (em paralelo):
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_rede.gd -- servidor
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_rede.gd -- cliente
# Cada um imprime "REDE <papel>: PASS/FAIL ..." — cada lado tem que ver o outro chegar e andar.
extends SceneTree

var falhas: Array[String] = []


func ok(c: bool, o_que: String) -> void:
	if not c:
		falhas.append(o_que)


func _init() -> void:
	var papel: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "servidor"
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5: await physics_frame
	if papel == "servidor":
		ok(main.criar_partida("Servidor") == OK, "cria a partida")
	else:
		main.rede.procurar()
		await espera_ms(2500)  # dá tempo do servidor abrir e anunciar
		ok(not main.rede.partidas.is_empty(), "acha a partida do servidor sozinho (broadcast no Wi-Fi)")
		ok(main.entrar_partida("127.0.0.1", "Cliente") == OK, "conecta")
	# espera os dois jogadores existirem neste aparelho
	var t0: int = Time.get_ticks_msec()
	while main.jogadores.get_child_count() < 2 and Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
		OS.delay_msec(16)  # a rede anda em tempo real; o teste roda mais rápido que isso
	ok(main.jogadores.get_child_count() == 2, "vê 2 jogadores (viu %d)" % main.jogadores.get_child_count())
	ok(main.jogador != null and main.jogador.local, "tem o próprio jogador")
	if falhas.is_empty():
		var outro: Jogador = null
		for n in main.jogadores.get_children():
			if n != main.jogador:
				outro = n
		var ini: Vector3 = outro.global_position
		main.controles.jogador = null
		main.jogador.entrada["move"] = Vector2(0, 1) if papel == "servidor" else Vector2(1, 0)
		var andou: float = 0.0
		for i in 240:
			await physics_frame
			OS.delay_msec(16)
			if is_instance_valid(outro):
				andou = maxf(andou, outro.global_position.distance_to(ini))
		main.jogador.entrada["move"] = Vector2.ZERO
		ok(andou > 3.0, "vê o outro andar (%.1f m)" % andou)
		ok(outro.clipe_rede != "" and outro.nick == ("Cliente" if papel == "servidor" else "Servidor"), "vê nome e animação do outro (nick=%s)" % outro.nick)
		ok(not outro.local and outro.camera == null, "o outro não tem câmera aqui")
		# zumbis: o servidor cria, o cliente recebe; um golpe do cliente vira dano no servidor
		ok(main.zumbis.get_child_count() == main.PONTOS_ZUMBI.size() + main.PONTOS_TOCAIA.size(), "vê os zumbis (%d)" % main.zumbis.get_child_count())
		var zl: Zumbi = null
		for n in main.zumbis.get_children():
			if (n as Zumbi).casa.distance_to(Vector3(24, 0, 0)) < 0.1:
				zl = n
		ok(zl != null, "zumbi do ponto (24, 0, 0) existe aqui")
		if zl and papel == "cliente":
			zl.levar_golpe(30, Vector3.FORWARD, main.jogador)
		await espera_ms(2000)
		if zl:
			ok(zl.vida == Zumbi.VIDA_MAX - 30, "golpe do cliente tira vida do zumbi nos dois (vida %d)" % zl.vida)
	await espera_ms(3000)  # deixa o outro lado terminar de medir
	print("REDE %s: %s %s" % [papel, "PASS" if falhas.is_empty() else "FAIL", ", ".join(falhas)])
	quit(0 if falhas.is_empty() else 1)


func espera_ms(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await physics_frame
		OS.delay_msec(16)
