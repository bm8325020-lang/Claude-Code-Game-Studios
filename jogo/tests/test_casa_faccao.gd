# Casa da facção (prompt 13): manutenção (prazo, aviso, paga do fundo, perde sem fundo), liberação quando nenhum
# membro está no servidor (o baú vai com a facção e volta ao dominar outra casa); no jogo: baú da facção só abre para
# membros, guardar, renascer na frente da casa, cama cura.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_casa_faccao.gd
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
	var f := Faccoes.new()
	f.comecar("Casa_1", "ana", ["ana"])
	var nome: String = f.passa(Faccoes.DOMINAR_T + 1, {"Casa_1": ["ana"]})[0][2]
	var d: Dictionary = f.faccoes[nome]
	ok(is_equal_approx(d.prazo, Faccoes.MANUT_DIAS * Faccoes.DIA), "prazo de %d dias do jogo" % Faccoes.MANUT_DIAS)
	var avisos: Array = []
	for k in Faccoes.MANUT_DIAS - 1:
		avisos.append_array(f.passa_manutencao(Faccoes.DIA).filter(func(e: Array) -> bool: return e[0] == "aviso"))
	ok(avisos.size() == Faccoes.AVISO_DIAS, "avisa uma vez por dia nos últimos %d dias (%s)" % [Faccoes.AVISO_DIAS, str(avisos)])
	f.depositar("ana", Faccoes.MANUT_CUSTO + 5)
	var ev: Array = f.passa_manutencao(Faccoes.DIA + 1.0)
	ok(ev.any(func(e: Array) -> bool: return e[0] == "pagou") and d.fundo == 5 and d.casa == "Casa_1", "no prazo com fundo: paga e continua com a casa")
	ev = f.passa_manutencao(Faccoes.MANUT_DIAS * Faccoes.DIA + 1.0)
	ok(ev.any(func(e: Array) -> bool: return e[0] == "perdeu") and d.casa == "", "no prazo sem fundo: perde a casa")
	f.comecar("Casa_2", "ana", ["ana"])
	f.passa(Faccoes.REDOMINAR_T + 1, {"Casa_2": ["ana"]})
	ok(f.liberar(nome, [{"tipo": "mola", "qtd": 3}]) == "Casa_2" and d.casa == "" and d.guardado.size() == 1, "todos saíram: casa liberada e o baú vai com a facção")
	# no jogo
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Dono")
	await frames(10)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	var casa: Node3D = main.bairro.get_node("Mansao_1")
	var bf: Bau = main.bairro.bau_da("Mansao_1")
	j.global_position = bf.global_position + casa.global_basis.x * -0.2 + casa.global_basis.z * 0.9 + Vector3(0, 0.1, 0)
	await frames(5)
	ok(bf.conteudo.is_empty() and j.bau_perto() != bf, "sem facção: o baú da facção não abre")
	main.faccoes.faccoes["Velha"] = {"membros": ["Dono"], "casa": "", "fundo": 0, "prazo": 0.0, "guardado": [{"tipo": "cano", "qtd": 2}]}
	main.faccoes.tentativas["Mansao_1"] = {"faccao": "Velha", "t": 0.2, "total": 180.0, "quem": "Dono"}
	await frames(60)
	ok(bf.faccao == "Velha" and bf.conteudo.size() == 1 and j.bau_perto() == bf, "dominou: o baú é da facção, abre e o guardado voltou")
	j.mochila.adicionar("mola", 4)
	j.guarda_no_bau(bf, j.mochila.espacos.find_custom(func(e: Variant) -> bool: return e != null and e.tipo == "mola"))
	await frames(3)
	ok(bf.conteudo.size() == 2 and j.mochila.conta("mola") == 0, "guarda da mochila no baú da facção")
	ok(main.pode_usar(casa.get_node("BancadaFac"), "Dono") and not main.pode_usar(casa.get_node("LojaFac"), "Outro") and main.pode_usar(main.get_node("Lojista"), "Outro"), "bancada e loja da mansão: só a facção dona usa")
	j.vida = 50
	j.velocity = Vector3.ZERO
	j.global_position = casa.get_node("Cama").global_position + casa.global_basis.x * 1.3 + Vector3(0, 0.1, 0)
	await frames(5)
	ok(j.cama_perto() != Vector3.INF, "perto da cama aparece DEITAR")
	j.deitar()
	await frames(120)
	ok(j.deitado and j.vida > 55, "deitado na cama cura (vida %d)" % j.vida)
	j.entrada["move"] = Vector2(0, 1)
	await frames(3)
	j.entrada["move"] = Vector2.ZERO
	ok(not j.deitado, "mexeu: levanta")
	j.levar_dano(1000, Vector3.FORWARD)
	j._morto_t = 0.02
	await frames(10)
	ok(j.vida > 0 and j.global_position.distance_to(main.bairro.frente_da("Mansao_1")) < 1.5, "renasce na frente da casa da facção")
	main.faccoes.faccoes.Velha.membros = ["Fulano"]  # nenhum membro no servidor
	main._libera_casas()
	await frames(3)
	ok(bf.faccao == "" and bf.conteudo.is_empty() and main.faccoes.faccoes.Velha.guardado.size() == 2, "nenhum membro no servidor: casa liberada, itens guardados na facção")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
