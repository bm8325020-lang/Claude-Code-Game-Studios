# Cliente contra o servidor dedicado (o mesmo que roda na nuvem), na mesma máquina:
#   godot --headless --main-pack servidor.pck -- dedicado   (em outro terminal)
#   godot --headless --path . -s res://tests/test_dedicado.gd
extends SceneTree

var main: Node3D
var falhas: Array[String] = []


func ok(c: bool, o_que: String) -> void:
	if not c:
		falhas.append(o_que)
		print("FALHA: ", o_que)


func espera_ms(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await physics_frame
		OS.delay_msec(16)  # a rede anda em tempo real


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await espera_ms(300)
	ok(main.entrar_partida("127.0.0.1", "Cliente") == OK, "conecta")
	var t0: int = Time.get_ticks_msec()
	while main.jogador == null and Time.get_ticks_msec() - t0 < 15000:
		await espera_ms(100)
	ok(main.jogador != null, "o servidor cria o meu jogador")
	if main.jogador:
		main.controles.jogador = null
		ok(main.jogadores.get_child_count() == 1, "só eu de jogador (o servidor não tem boneco): %d" % main.jogadores.get_child_count())
		await espera_ms(1500)
		ok(main.zumbis.get_child_count() == main.PONTOS_ZUMBI.size() + main.PONTOS_TOCAIA.size() + main.PATRULHAS.size(), "recebe os zumbis do servidor (%d)" % main.zumbis.get_child_count())
		ok(main.ciclo.tempo > Ciclo.INICIO, "recebe o horário do servidor (%.0f s)" % main.ciclo.tempo)
		var z: Zumbi = null
		for n in main.zumbis.get_children():
			if (n as Zumbi).casa.distance_to(Vector3(24, 0, 0)) < 0.1:
				z = n
		main.jogador.global_position = Vector3(24, 0.1, -9)
		await espera_ms(4000)
		ok(z != null and z.global_position.distance_to(z.casa) > 1.5, "o zumbi do servidor vem atrás de mim (andou %.1f m)" % (z.global_position.distance_to(z.casa) if z else -1.0))
	print("DEDICADO: %s %s" % ["PASS" if falhas.is_empty() else "FAIL", ", ".join(falhas)])
	quit(0 if falhas.is_empty() else 1)
