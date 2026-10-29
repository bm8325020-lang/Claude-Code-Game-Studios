# Morte com loot no chão (prompt 3 do loop): cair larga um saco com tudo (menos o facão), volta só com o facão,
# qualquer um revista e pega; sair do jogo caído/em luta larga o saco com a última cópia da mochila.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_morte.gd
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


func _sacos() -> Array:
	return main.soltos.get_children().filter(func(n: Node) -> bool: return n is Bau and (n as Bau).saco)


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
	await frames(5)
	j.mochila.adicionar("comida", 2)
	j.entrada["arma"] = "pistola"
	await frames(3)
	var balas: int = j.pistola.balas
	var reserva: int = j.pistola.reserva
	j.levar_dano(1000, Vector3.FORWARD)
	await frames(3)
	var sacos: Array = _sacos()
	ok(sacos.size() == 1, "caiu: aparece um saco no chão (%d)" % sacos.size())
	var saco: Bau = sacos[0] if sacos.size() > 0 else null
	var tem: Dictionary = {}
	if saco:
		for e: Dictionary in saco.conteudo:
			tem[e.tipo] = int(e.qtd)
	ok(tem.get("pistola", 0) == 1 and tem.get("comida", 0) == 2 and tem.get("lanterna", 0) == 1, "no saco: pistola, comida e lanterna (%s)" % str(tem))
	ok(tem.get("municao", 0) == reserva + balas, "a munição do pente vai junto (%d)" % tem.get("municao", 0))
	ok(not tem.has("facao") and j.mochila.conta("facao") == 1 and not j.mochila.tem("pistola"), "o facão fica com ele")
	ok(j.arma == "facao", "sem pistola volta para o facão")
	await frames(int(Jogador.RENASCE * 60) + 10)
	ok(j.vida == Jogador.VIDA_MAX and not j.mochila.tem("comida"), "volta sem nada (só o facão)")
	j.entrada["arma"] = "pistola"
	await frames(3)
	ok(j.arma == "facao", "não saca pistola que não tem")
	# revista o saco
	j.global_position = saco.global_position + Vector3(0, 0.1, 0.8)
	await frames(5)
	ok(j.bau_perto() == saco, "perto do saco aparece REVISTAR")
	j.pega_do_bau(saco, -1)
	await frames(5)
	ok(j.mochila.tem("pistola") and j.comida == 2 and _sacos().is_empty(), "pega tudo de volta e o saco some")
	# sair do jogo em luta / em paz
	j.copia_mochila = [{"tipo": "agua", "qtd": 1}]
	j.dano_srv_t = Time.get_ticks_msec() / 1000.0
	ok(main.saiu_morrendo(j) and _sacos().size() == 1, "saiu em luta: larga o saco")
	j.dano_srv_t = -99.0
	ok(not main.saiu_morrendo(j), "saiu em paz: leva tudo")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
