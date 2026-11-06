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
	ok(t._linha.text.contains("comida"), "começa pedindo comida (%s)" % t._linha.text)
	var xp0: int = j.prog.xp + j.prog.nivel * 1000
	t.evento("agua")
	ok(t._i == 1, "evento errado não conta (teste começa no cap. 1)")
	j.ganhar("comida", 1)
	await physics_frame
	ok(t._i == 2 and t._linha.text.contains("refúgio"), "pegou comida: história pede o refúgio (%s)" % t._linha.text)
	ok(j.prog.xp + j.prog.nivel * 1000 > xp0, "passo feito dá XP")
	ok(Minimapa.destino.is_finite(), "o refúgio fica marcado no mapa (07/11)")
	j.entrou_segura.emit(true)
	await physics_frame
	ok(t._i == 3 and t._linha.text.contains("DEFENDA") and t._onda_total > 0, "refúgio: luta obrigatória para defender (%s)" % t._linha.text)
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
	print("TAREFAS: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
