# PvP em salas pela rede, dois processos: o servidor (com jogador "Ana") cria a sala; o cliente ("Bia") não vê a Ana
# enquanto está fora da sala, entra pelo código e passa a ver; a Ana começa, derruba a Bia, o placar conta nos
# dois e a Bia renasce com a vida cheia.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_pvp.gd -- servidor   (e em paralelo)
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_pvp.gd -- cliente
extends SceneTree

var falhas: Array[String] = []
var main: Node3D


func ok(c: bool, o_que: String) -> void:
	if not c:
		falhas.append(o_que)


## Espera `cond` virar verdade (até `ms`), com a rede andando em tempo real.
func espera(cond: Callable, ms: int = 15000) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < ms:
		await physics_frame
		OS.delay_msec(16)
	return cond.call()


func _init() -> void:
	var papel: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "servidor"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5: await physics_frame
	if papel == "servidor":
		ok(main.criar_partida("Ana") == OK, "cria a partida")
		await espera(func() -> bool: return main.jogador != null)
		main.pede_criar_sala.rpc_id(1, "Arena", false, 4, 5)
		ok(await espera(func() -> bool: return not main.minha_sala().is_empty()), "criou a sala")
		ok(await espera(func() -> bool: return main.minha_sala().get("jogadores", []).size() == 2, 30000), "a Bia entrou pelo código")
		main.pede_comecar_sala.rpc_id(1)
		ok(await espera(func() -> bool: return main.em_pvp()), "a partida começou")
		for z in main.zumbis.get_children():  # o centro da cidade tem zumbi: aqui só conta o tiro da Ana
			z.queue_free()
		await espera(func() -> bool: return false, 6000)  # a Bia chega no ponto dela e já vê a Ana (cidade grande: demora mais)
		var bia: Jogador = null
		for j: Jogador in main.jogadores.get_children():
			if j != main.jogador:
				bia = j
		ok(bia != null, "a Ana vê a Bia na sala")
		if bia:
			bia.levar_golpe(Jogador.VIDA_MAX + 50, Vector3.FORWARD, main.jogador)
		ok(await espera(func() -> bool: return main.placar_sala().size() == 2 and main.placar_sala()[0] == ["Ana", 1, 0]), "placar: Ana 1 abate")
		await espera(func() -> bool: return false, 20000)  # deixa o cliente conferir o renascer (cidade grande: o cliente anda mais devagar)
	else:
		ok(main.entrar_partida("127.0.0.1", "Bia") == OK, "conecta")
		ok(await espera(func() -> bool: return main.jogador != null and not main._salas_cli.salas.is_empty()), "vê que existe uma sala")
		await espera(func() -> bool: return false, 800)
		ok(main.jogadores.get_child_count() == 1, "fora da sala não vê a Ana (vê %d)" % main.jogadores.get_child_count())
		main.pede_lista_salas.rpc_id(1)
		await espera(func() -> bool: return false, 800)
		ok(main.lista_salas.is_empty(), "sala privada não aparece na lista")
		var cod: String = main._salas_cli.salas.keys()[0]
		main.pede_entrar_sala.rpc_id(1, cod)
		ok(await espera(func() -> bool: return main.jogadores.get_child_count() == 2), "na sala passa a ver a Ana")
		ok(await espera(func() -> bool: return main.jogador.vida <= 0, 20000), "a Bia caiu com o tiro da Ana")
		ok(main.jogador.mochila.tem("pistola"), "no PvP não larga nada")
		ok(await espera(func() -> bool: return main.jogador.vida == Jogador.VIDA_MAX, 10000), "renasce com a vida cheia")
		ok(main.placar_sala().size() == 2 and main.placar_sala()[1] == ["Bia", 0, 1], "placar chegou no cliente")
	print("PVP %s: %s" % [papel, "PASS" if falhas.is_empty() else "FAIL " + ", ".join(falhas)])
	quit(0 if falhas.is_empty() else 1)
