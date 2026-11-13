# Mecânicas da floresta (13/11): colher frutinha/lenha/pedra, beber do rio, fogueira feita na mão (sem bancada) que
# assa a carne e cura, comida da mata mata a fome.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_mata.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0
var main: Node3D
var j: Jogador


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(30)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	j.vida = 100
	var b: Bairro = main.bairro
	# colher: vai até cada tipo de coisa da mata
	for tipo: String in ["fruta", "madeira", "pedra"]:
		var alvo: Array = []
		for k: Vector2i in b._coleta:
			for c: Array in b._coleta[k]:
				if c[1] == tipo:
					alvo = c
					break
			if not alvo.is_empty():
				break
		ok(not alvo.is_empty(), "a mata tem %s para colher" % tipo)
		if alvo.is_empty():
			continue
		j.global_position = (alvo[0] as Vector3) + Vector3(1.0, 0.3, 0)
		await frames(4)
		var c: Array = j.coleta_perto()  # a mais perta (a mata é densa: pode ser outra coisa ao lado)
		ok(not c.is_empty() and b.coleta_em(j.global_position, 2.3).any(func(x: Array) -> bool: return x[1] == tipo), "dá para colher %s aqui (%s)" % [tipo, str(c.slice(1, 2))])
		var antes: int = j.mochila.conta(String(c[1])) + j.mochila.conta("cogumelo")
		j._tenta_pegar()
		ok(j.mochila.conta(String(c[1])) + j.mochila.conta("cogumelo") > antes, "colheu (%s)" % c[1])
		ok(j.coleta_perto().is_empty() or j.coleta_perto()[2] != c[2], "o mesmo %s não dá de novo na hora" % tipo)
	# beber do rio
	var s: Array = b._rio[0]
	var meio: Vector2 = ((s[0] as Vector2) + (s[1] as Vector2)) * 0.5
	j.global_position = Bairro.ORIGEM + Vector3(meio.x, 0.5, meio.y)
	j.sede = 30.0
	await frames(4)
	var rio: Array = j.coleta_perto()
	ok(not rio.is_empty() and rio[1] == "rio", "na beira do rio dá para beber")
	j._tenta_pegar()
	ok(j.sede > 60.0, "bebeu do rio (sede %d)" % j.sede)
	# fogueira na mão, acender, assar
	j.global_position = Bairro.ORIGEM + Vector3(-300, 2.0, 300)
	await frames(20)
	j.mochila.adicionar("madeira", 5)
	j.mochila.adicionar("pedra", 5)
	ok(j.bancada_perto() == null and j.comeca_fabricar("fogueira", 1), "fogueira se faz sem bancada")
	await frames(int(Receitas.FABRICAR_T * 60) + 30)
	ok(j.mochila.conta("fogueira") == 1, "fez o kit de fogueira")
	var i: int = j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == "fogueira")
	j.usar_espaco(i)
	await frames(5)
	ok(get_nodes_in_group("fogueiras").size() == 1, "acendeu a fogueira")
	j.mochila.adicionar("carne_crua", 1)
	j.vida = 50
	j._assa_t = 0.0
	await frames(10)
	ok(j.mochila.conta("carne_assada") == 1 and j.vida > 50, "perto do fogo assou a carne e curou (vida %d)" % j.vida)
	j.fome = 20.0
	i = j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == "carne_assada")
	j.usar_espaco(i)
	ok(j.fome > 55.0, "carne assada mata a fome (%d)" % j.fome)
	print("%s: %d/%d" % ["PASS" if falhas == 0 else "FAIL", checks - falhas, checks])
	quit(1 if falhas else 0)
