# Arma automática com seletor (prompt 7 do loop): só saca se tiver; semi = 1 tiro segurando; automático = rajada
# na cadência; a dispersão cresce na rajada; seletor só nela; mesma munição da pistola; receita mediana.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_auto.gd
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
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	j.global_position = Vector3(-20, 0.1, 30)
	j.camera.virar(0.0, -0.1)
	j.entrada["arma"] = "smg"
	await frames(3)
	ok(j.arma == "facao", "sem a submetralhadora na mochila não saca")
	j.mochila.adicionar("smg", 1)
	j.entrada["arma"] = "smg"
	await frames(3)
	ok(j.arma == "smg" and j.smg.visible and not j.pistola.visible, "saca a submetralhadora")
	ok(j.smg.automatica and j.smg.modo_auto and not j.pistola.automatica, "começa no automático; a pistola não tem seletor")
	# semi: segurando o gatilho sai 1 tiro só
	j.entrada["modo"] = true
	await frames(2)
	ok(not j.smg.modo_auto, "botão MODO: tiro a tiro")
	var b0: int = j.smg.balas
	j.entrada["atacar"] = true
	j.entrada["atirando"] = true
	await frames(60)
	j.entrada["atirando"] = false
	ok(b0 - j.smg.balas == 1, "no tiro a tiro, segurar dá 1 tiro (%d)" % (b0 - j.smg.balas))
	# automático: 1 s segurando = rajada na cadência
	j.entrada["modo"] = true
	await frames(2)
	ok(j.smg.modo_auto, "botão MODO de novo: automático")
	j.smg.balas = j.smg.pente
	b0 = j.smg.balas
	j.entrada["atacar"] = true
	j.entrada["atirando"] = true
	var abertura_max: float = 0.0
	for i in 60:
		await physics_frame
		abertura_max = maxf(abertura_max, j.smg._abertura)
	j.entrada["atirando"] = false
	var esperado: int = int(1.0 / j.smg.cadencia)
	var tiros: int = b0 - j.smg.balas
	ok(absi(tiros - esperado) <= 2, "rajada de 1 s: %d tiros (cadência dá %d)" % [tiros, esperado])
	ok(abertura_max > j.smg.disp_tiro * 4.0, "a mira abre durante a rajada (%.1f graus)" % abertura_max)
	# munição compartilhada
	var r0: int = j.smg.reserva
	j.entrada["recarregar"] = true
	await frames(int(j.smg.recarga * 60) + 10)
	ok(j.smg.balas == j.smg.pente and j.pistola.reserva == r0 - tiros, "recarrega da mesma reserva da pistola (%d)" % j.pistola.reserva)
	# seletor só na submetralhadora
	j.entrada["arma"] = "pistola"
	await frames(3)
	j.entrada["modo"] = true
	await frames(2)
	ok(not j.pistola.modo_auto, "a pistola não muda para automático")
	# receita mediana
	ok(Receitas.LISTA.smg.raridade == Receitas.MEDIANA, "a receita da submetralhadora é mediana")
	j.mochila.tirar("smg", 1)
	j.receitas.append("smg")
	for p: String in Receitas.LISTA.smg.pecas:
		j.mochila.adicionar(p, int(Receitas.LISTA.smg.pecas[p]))
	j.global_position = main.bancada.global_position + Vector3(0, 0.1, 1.3)
	await frames(5)
	ok(j.comeca_fabricar("smg", 1), "fabrica na bancada")
	await frames(int(Receitas.FABRICAR_T * 60) + 10)
	ok(j.mochila.tem("smg"), "submetralhadora pronta")
	ok(Pistola._marcas.size() > 0, "tiro deixa marca (furo ou sangue) no cenário (%d)" % Pistola._marcas.size())
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
