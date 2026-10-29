# Peças de arma e drop de zumbi (prompt 5 do loop): chances do drop, chefe larga mais e mais raro, o drop
# aparece no chão em volta do corpo, pega e empilha na mochila, e some depois de um tempo.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_pecas.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var com_drop: int = 0
	var raras: int = 0
	for k in 6000:
		var d: Array = Loot.drop(rng)
		if not d.is_empty():
			com_drop += 1
		for e: Dictionary in d:
			if Loot.raridade(e.tipo) == Loot.RARO:
				raras += 1
	var p: float = com_drop / 6000.0
	ok(absf(p - Loot.CHANCE_ZUMBI) < 0.03, "zumbi comum larga algo em %.0f%% das vezes (alvo %.0f%%)" % [p * 100.0, Loot.CHANCE_ZUMBI * 100.0])
	var raras_chefe: int = 0
	var sempre: bool = true
	for k in 2000:
		var d: Array = Loot.drop(rng, true)
		var n: int = 0
		for e: Dictionary in d:
			n += 1
			if Loot.raridade(e.tipo) == Loot.RARO:
				raras_chefe += 1
		if d.is_empty():
			sempre = false
	ok(sempre, "o chefe sempre larga alguma coisa")
	ok(raras_chefe / 2000.0 > raras / float(com_drop) * 2.0, "o chefe larga peça rara bem mais vezes (%d em 2000 x %d em %d)" % [raras_chefe, raras, com_drop])
	# no jogo: mata o chefe e o drop aparece no chão
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	var chefe: Zumbi = null
	for z in main.zumbis.get_children():
		if (z as Zumbi).chefe:
			chefe = z
		else:
			z.free()
	ok(chefe != null, "o chefe está na pista")
	chefe._sem_gritar = INF
	j.global_position = Vector3(-20, 0.1, 30)
	var n0: int = main.soltos.get_child_count()
	chefe.levar_golpe(1000, Vector3.FORWARD, j)
	await frames(3)
	var largados: Array = main.soltos.get_children().slice(n0)
	ok(largados.size() >= Loot.CHEFE_ROLAGENS.x - 1 and largados.size() <= Loot.CHEFE_ROLAGENS.y, "o chefe larga %d coisas no chão" % largados.size())
	ok(largados.all(func(it: Node) -> bool: return it is Item and (it as Item).global_position.distance_to(chefe.global_position) < 1.0), "em volta do corpo")
	# pega uma peça e empilha
	var mola := Item.new()
	mola.tipo = "mola"
	mola.quantidade = 3
	main.add_child(mola)
	mola.global_position = j.global_position + Vector3(0.5, -0.1, 0)
	j.mochila.adicionar("mola", 4)
	await frames(3)
	j.entrada["pegar"] = true
	await frames(int(Jogador.PEGAR_DUR * 60) + 10)
	ok(j.mochila.conta("mola") == 7 and j.mochila.espacos.filter(func(e: Variant) -> bool: return e != null and e.tipo == "mola").size() == 1,
		"pega a peça e empilha com as outras (%d)" % j.mochila.conta("mola"))
	# o drop some depois de um tempo
	if not largados.is_empty():
		(largados[0] as Item)._some_t = 0.1
		await frames(15)
		ok(not is_instance_valid(largados[0]), "o que o zumbi largou some depois de %d s" % int(Zumbi.DROP_SOME))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
