# História (07/11; era Tarefas 31/10): começa em "pegue comida", anda com os eventos certos, marca o destino no mapa.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_tarefas.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("TesteTarefas")
	for i in 5: await physics_frame
	var j: Jogador = main.jogador
	var t: Tarefas = main.controles._tarefas
	ok(t._linha.text.contains("FACÃO"), "começa só no soco: pegar o facão (%s)" % t._linha.text)
	j.mochila.tirar("facao", 1)  # teste nasce com facão/pistola; a história começa sem
	j.mochila.tirar("pistola", 1)
	var xp0: int = j.prog.xp + j.prog.nivel * 1000
	t.evento("agua")
	ok(t._i == 1, "evento errado não conta (teste começa no cap. 1)")
	ok(Minimapa.destino.is_finite(), "o facão fica marcado no mapa")
	ok(t._fila_radio.size() > 0 or t._legenda_t > 0.0, "o objetivo chega pelo rádio")
	j.ganhar("facao", 1)
	await physics_frame
	ok(t._i == 2 and t._linha.text.contains("DELEGACIA"), "facão: raid na delegacia (%s)" % t._linha.text)
	j.ganhar("pistola", 1)
	await physics_frame
	ok(t._i == 3 and t._linha.text.contains("refúgio"), "pistola: história pede o refúgio (%s)" % t._linha.text)
	j.entrou_segura.emit(true)
	await physics_frame
	ok(t._i == 4 and t._linha.text.contains("DEFENDA") and t._onda_total > 0, "refúgio: luta obrigatória para defender (%s)" % t._linha.text)
	# 06/11 (dono travou em 9/15): no refúgio (sala segura) os zumbis da luta não desistem; perdido longe volta perto
	j.segura = true
	for i in 60 * 4: await physics_frame
	ok(t._onda_nos.size() > 0, "onda nasceu (%d)" % t._onda_nos.size())
	var todos_caçam: bool = t._onda_nos.all(func(z: Zumbi) -> bool: return z.luta and z.alvo == j)
	ok(todos_caçam, "zumbis da luta caçam quem está no refúgio")
	if t._onda_nos.size() > 0:
		var z0: Zumbi = t._onda_nos[0]
		z0.global_position = j.global_position + Vector3(250, 0, 0)
		for i in 90: await physics_frame
		ok(z0.global_position.distance_to(j.global_position) < 30.0, "zumbi da luta perdido longe volta perto (%.0f m)" % z0.global_position.distance_to(j.global_position))
	# 06/11: soco "roubado" e começo sem nada (só na história de verdade; testes seguem com o facão)
	ok(Armas.BRANCAS.punhos.alcance > Armas.BRANCAS.facao.alcance and int(Armas.BRANCAS.punhos.dano[0]) >= 30, "soco forte e longo")
	ok(Voz.tem(String(Tarefas.ROTEIRO[1][7].radio)), "objetivo do rádio tem voz")
	print("TAREFAS: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
