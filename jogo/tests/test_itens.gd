# Testes da mecânica 11 (pegar item do chão): munição, lanterna, some ao pegar, volta depois.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_itens.gd
extends SceneTree

var main: Node3D
var j: Jogador
var checks: int = 0
var falhas: int = 0


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var caixa: Item = main.get_node("Item_0")
	# longe: nada para pegar
	j.global_position = caixa.global_position + Vector3(3, 0.1, 0)
	await frames(10)
	ok(j.item_perto() == null, "longe da caixa não aparece PEGAR")
	j.global_position = caixa.global_position + Vector3(0.8, 0.1, 0)
	await frames(10)
	ok(j.item_perto() == caixa, "perto da caixa aparece PEGAR")
	var antes: int = j.pistola.reserva
	j.entrada["pegar"] = true
	j.entrada["move"] = Vector2(0, 1)
	await frames(6)
	ok(j.clipe_atual() == "pegar" and Vector2(j.velocity.x, j.velocity.z).length() < 0.5, "abaixa para pegar e não anda (%s)" % j.clipe_atual())
	ok(j.pistola.reserva == antes + 24 and not caixa.ativo and not caixa.visible, "pega 24 balas e a caixa some (%d)" % j.pistola.reserva)
	j.entrada["move"] = Vector2.ZERO
	await frames(60)
	ok(j.item_perto() == null, "não pega de novo a caixa que sumiu")
	await frames(int(Item.VOLTA * 60) + 10)
	ok(caixa.ativo and caixa.visible, "a caixa volta depois de %d s" % int(Item.VOLTA))
	j.pistola.reserva = Pistola.RESERVA_MAX - 5
	j.entrada["pegar"] = true
	await frames(int(Jogador.PEGAR_DUR * 60) + 10)  # só pega outro depois de levantar
	ok(j.pistola.reserva == Pistola.RESERVA_MAX, "a reserva não passa de %d" % Pistola.RESERVA_MAX)
	# lanterna
	j.tem_lanterna = false
	var l := Item.new()
	l.tipo = "lanterna"
	l.position = j.global_position + Vector3(0.5, -0.1, 0.5)
	main.add_child(l)
	await frames(5)
	j.entrada["pegar"] = true
	await frames(60)
	ok(j.tem_lanterna and not l.ativo, "acha a lanterna e passa a ter lanterna")
	# fome e sede
	var f0: float = j.fome
	await frames(60 * 9)
	ok(j.fome < f0 and j.sede < 100.0, "fome e sede caem com o tempo (%.2f, %.2f)" % [j.fome, j.sede])
	var v0: int = j.vida
	j.fome = 0.0
	await frames(int(Jogador.INTERVALO_FOME * 60) + 5)
	ok(j.vida == v0 - Jogador.DANO_FOME, "fome zerada tira vida aos poucos (%d -> %d)" % [v0, j.vida])
	var lata: Item = main.get_node("Item_comida_0")
	j.global_position = lata.global_position + Vector3(-0.6, 0.1, 0)  # lado oposto da garrafa
	await frames(5)
	j.entrada["pegar"] = true
	await frames(60)
	ok(j.comida == 1 and not lata.ativo, "pega a lata de comida e guarda")
	j.entrada["comer"] = true
	await frames(3)
	ok(j.comida == 0 and absf(j.fome - Jogador.ENCHE) < 0.5, "come: gasta a lata e enche a fome (%.0f)" % j.fome)
	j.entrada["comer"] = true
	await frames(3)
	ok(absf(j.fome - Jogador.ENCHE) < 0.5, "sem lata não come")
	# mochila: largar a lanterna no chão, pegar de volta; facão não sai
	await frames(int(Jogador.PEGAR_DUR * 60) + 10)
	j.global_position = Vector3(-20, 0.1, 30)  # longe dos itens do mapa
	await frames(5)
	ok(j.mochila.espacos[0].tipo == "facao" and j.mochila.espacos[1].tipo == "pistola", "facão e pistola nos espaços 1 e 2 da barra")
	var n0: int = main.soltos.get_child_count()  # munição que não coube antes já está no chão
	j.largar(j.mochila.onde("facao"))
	ok(j.mochila.tem("facao") and main.soltos.get_child_count() == n0, "o facão não sai da mão")
	j.largar(j.mochila.onde("lanterna"))
	await frames(2)
	ok(not j.tem_lanterna and main.soltos.get_child_count() == n0 + 1, "larga a lanterna: sai da mochila e aparece no chão")
	var solta: Item = main.soltos.get_child(n0)
	ok(solta.tipo == "lanterna" and solta.solto and solta.global_position.distance_to(j.global_position) < 1.5, "no chão à frente")
	j.entrada["pegar"] = true
	await frames(int(Jogador.PEGAR_DUR * 60) + 10)
	ok(j.tem_lanterna and main.soltos.get_child_count() == n0, "pega de volta e o item largado some")
	j.usar_espaco(j.mochila.onde("pistola"))
	await frames(3)
	ok(j.arma == "pistola", "barra rápida: tocar na pistola põe na mão")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
