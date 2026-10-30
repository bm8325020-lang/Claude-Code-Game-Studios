# Sala de sobrevivência pelo carteiro, três processos: o carteiro (relay_main.gd), a Ana cria a sala (o mundo roda
# no aparelho dela) e fica na espera; COMEÇAR SOZINHO; a Bia acha a sala buscando pelo nome, entra no meio do jogo
# pelo código e as duas se veem.
#   godot --headless -s res://scripts/relay_main.gd -- porta=7899 &
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_sala_sobrev.gd -- host   (e em paralelo)
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_sala_sobrev.gd -- cliente
extends SceneTree

const URL := "ws://127.0.0.1:7899"
var falhas: Array[String] = []
var main: Node3D
var ultima: Dictionary = {}


func ok(c: bool, o_que: String) -> void:
	if not c:
		falhas.append(o_que)


func espera(cond: Callable, ms: int = 15000) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < ms:
		await physics_frame
		OS.delay_msec(16)
	return cond.call()


func _init() -> void:
	var papel: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "host"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5: await physics_frame
	main.abre_relay(URL)
	main.relay_msg.connect(func(m: Dictionary) -> void: ultima = m)
	if papel == "host":
		main.criar_sala_sobrev("Ana", "Zumbilandia", true, 3)
		ok(await espera(func() -> bool: return main.jogador != null and main.sala_sobrev.codigo != ""), "criou a sala e hospeda")
		ok(main.esperando and main.zumbis.process_mode == Node.PROCESS_MODE_DISABLED, "fica na espera com os zumbis parados")
		await espera(func() -> bool: return false, 500)
		main.comecar_sala_sobrev()
		ok(not main.esperando and main.zumbis.process_mode != Node.PROCESS_MODE_DISABLED, "COMEÇAR SOZINHO solta o jogo")
		ok(await espera(func() -> bool: return main.jogadores.get_child_count() == 2, 30000), "a Bia entrou no meio do jogo")
		await espera(func() -> bool: return false, 4000)
	else:
		await espera(func() -> bool: return false, 7000)  # a Ana cria a sala
		var achou: bool = false
		for i in 20:  # pergunta de novo até a Ana ter criado e começado
			main.relay.lista("landia")
			achou = await espera(func() -> bool: return ultima.get("op", "") == "lista" and ultima.salas.size() == 1 and ultima.salas[0].comecou, 1000)
			if achou:
				break
			ultima = {}
		ok(achou, "acha a sala buscando parte do nome")
		var sala: Dictionary = ultima.salas[0] if ultima.get("salas", []).size() > 0 else {}
		ok(sala.get("comecou", false), "a lista mostra que já começou")
		main.relay.lista("xyz")
		ok(await espera(func() -> bool: return ultima.get("op", "") == "lista" and ultima.salas.is_empty()), "busca sem resultado")
		main.entrar_sala_sobrev("Bia", String(sala.get("codigo", "????")).to_lower())
		ok(await espera(func() -> bool: return main.jogador != null and main.jogadores.get_child_count() == 2, 30000), "entrou pelo código e vê a Ana")
		ok(await espera(func() -> bool: return main.sala_sobrev.get("n", 0) == 2), "sabe quantos estão na sala")
		ok(not main.esperando, "entrou com o jogo já rolando: sem espera")
		var ana: Jogador = null
		for j: Jogador in main.jogadores.get_children():
			if j != main.jogador:
				ana = j
		ok(ana != null and await espera(func() -> bool: return ana.nick == "Ana"), "a Ana chega com o nome")
	print("SALA %s: %s" % [papel, "PASS" if falhas.is_empty() else "FAIL " + ", ".join(falhas)])
	quit(0 if falhas.is_empty() else 1)
