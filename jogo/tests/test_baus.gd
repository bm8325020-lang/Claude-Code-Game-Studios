# Baús (prompt 2 do loop): sorteio da tabela, abrir parado (andar cancela), pegar um item, pegar tudo, encher de novo.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_baus.gd
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
	# sorteio: 5000 baús, conferir proporções
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cont: Dictionary = {}
	var cont_f: Dictionary = {}
	for k in 5000:
		for e: Dictionary in Loot.sorteia(rng):
			cont[e.tipo] = int(cont.get(e.tipo, 0)) + 1
		for e: Dictionary in Loot.sorteia(rng, true):
			cont_f[e.tipo] = int(cont_f.get(e.tipo, 0)) + 1
	var lan: float = float(cont.get("lanterna", 0)) / 5000.0
	ok(lan > 0.08 and lan < 0.2, "lanterna é rara: sai em %.0f%% dos baús" % (lan * 100.0))
	ok(float(cont.get("comida", 0)) > float(cont.get("lanterna", 0)) * 3.0, "comida é comum")
	ok(int(cont_f.get("comida", 0)) > int(cont.get("comida", 0)) * 1.06, "baú da cidade inicial tem comida mais vezes (%d x %d)" % [cont_f.get("comida", 0), cont.get("comida", 0)])
	for k in 200:
		var c: Array = Loot.sorteia(rng)
		if c.is_empty() or c.size() > Loot.ITENS_MAX:
			ok(false, "baú sempre tem de 1 a %d tipos" % Loot.ITENS_MAX)
			break
	# no jogo
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
	var b: Bau = main.get_node("Bau_1")
	ok(b != null and not b.conteudo.is_empty(), "baú na pista com coisa dentro")
	b.conteudo = [{"tipo": "comida", "qtd": 2}, {"tipo": "municao", "qtd": 12}]
	j.mochila.definir("comida", 0)
	j.global_position = b.global_position + Vector3(0, 0.1, 1.2)
	await frames(5)
	ok(j.bau_perto() == b, "perto do baú aparece ABRIR")
	var abriu: Array = [null]
	j.bau_aberto.connect(func(x: Bau) -> void: abriu[0] = x)
	j.entrada["pegar"] = true
	await frames(30)
	j.entrada["move"] = Vector2(0, 1)  # andou: cancela
	await frames(5)
	j.entrada["move"] = Vector2.ZERO
	await frames(int(Bau.ABRIR_T * 60))
	ok(abriu[0] == null and j.abrindo == null, "andar cancela a abertura")
	j.global_position = b.global_position + Vector3(0, 0.1, 1.2)
	await frames(5)
	j.entrada["pegar"] = true
	await frames(int(Bau.ABRIR_T * 60) + 5)
	ok(abriu[0] == b, "parado %.1f s abre o baú" % Bau.ABRIR_T)
	var r0: int = j.pistola.reserva
	j.pega_do_bau(b, 1)
	await frames(2)
	ok(j.pistola.reserva == r0 + 12 and b.conteudo.size() == 1 and b.conteudo[0].tipo == "comida", "pega a munição e ela sai do baú")
	j.pega_do_bau(b, -1)
	await frames(2)
	ok(j.comida == 2 and b.conteudo.is_empty(), "PEGAR TUDO esvazia o baú")
	j.global_position = Vector3(-20, 0.1, 30)
	await frames(3)
	b.conteudo = [{"tipo": "agua", "qtd": 1}]
	j.pega_do_bau(b, 0)
	await frames(2)
	ok(b.conteudo.size() == 1, "longe não pega nada")
	b.conteudo = []
	b._vazio_t = 0.2
	await frames(20)
	ok(not b.conteudo.is_empty(), "baú vazio se enche de novo depois de um tempo")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
