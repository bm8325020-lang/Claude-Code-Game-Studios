# Dinheiro e lojista (prompt 8 do loop): matar zumbi dá dinheiro, comprar sem dinheiro ou longe falha,
# comprar gasta e põe na mochila, vender paga e tira da mochila; o facão não se vende.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_loja.gd
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
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	var z: Zumbi = null
	for c in main.zumbis.get_children():
		if z == null and not (c as Zumbi).chefe:
			z = c
		else:
			c.free()
	z._sem_gritar = INF
	j.global_position = Vector3(-20, 0.1, 30)
	await frames(2)
	z.levar_golpe(1000, Vector3.FORWARD, j)
	await frames(3)
	ok(j.dinheiro == Zumbi.DINHEIRO and j.abates == 1, "matar zumbi dá $%d e conta 1 abate (tem $%d, %d)" % [Zumbi.DINHEIRO, j.dinheiro, j.abates])
	ok(not j.comprar("comida"), "longe do lojista não compra")
	var l: Lojista = main.get_tree().get_first_node_in_group("lojista")
	j.global_position = l.global_position + Vector3(0, 0.1, 1.2)
	await frames(3)
	ok(j.lojista_perto() == l, "perto do lojista")
	j.dinheiro = 5
	var c0: int = j.mochila.conta("comida")
	ok(not j.comprar("comida") and j.dinheiro == 5 and j.mochila.conta("comida") == c0, "sem dinheiro não compra")
	j.dinheiro = 100
	ok(j.comprar("municao") and j.dinheiro == 100 - int(Lojista.VENDE.municao[1]), "compra munição e gasta")
	ok(not j.comprar("smg"), "não compra o que ele não vende")
	var i: int = j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == "municao")
	var m0: int = j.mochila.conta("municao")
	var d0: int = j.dinheiro
	ok(j.vender(i, 5) == 5 * int(Lojista.PAGA.municao) and j.mochila.conta("municao") == m0 - 5 and j.dinheiro == d0 + 5, "vende 5 balas")
	var f: int = j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == "facao")
	ok(f < 0 or j.vender(f) == 0, "o facão não se vende")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
