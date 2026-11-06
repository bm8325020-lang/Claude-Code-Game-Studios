# Bomba e portão blindado (07/11, dono: "pra raidar esse lugar vai ter que explodir o portão com a bomba").
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_bomba.gd
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
	await frames(10)
	main.controles.jogador = null
	var b: Bairro = main.bairro
	var portoes: Array = b.find_children("Portao_*", "Porta", false, false)
	ok(portoes.size() == 4 and portoes.all(func(p: Porta) -> bool: return p.blindada), "quarentena tem 4 folhas de portão blindado")
	var corvos: Array = b.pontos_raid.filter(func(r: Dictionary) -> bool: return r.tipo == "corvo")
	ok(corvos.size() >= 13, "saqueadores dentro da quarentena e no mercado (%d)" % corvos.size())
	var j: Jogador = main.jogador
	j.vida = 100000
	var p: Porta = portoes[1]
	j.global_position = p.centro() + Vector3(0, 0.2, -1.5)
	await frames(5)
	p.alterna_por(j)
	p.leva_soco(500)
	ok(not p.aberta and not p.arrombada(), "USAR não abre e soco não quebra o portão blindado")
	j.mochila.adicionar("bomba", 1)
	j.planta_bomba()
	ok(not j.mochila.tem("bomba"), "a bomba sai da mochila ao armar")
	await frames(int(60 * (Jogador.BOMBA_T + 0.8)))
	ok(portoes.all(func(q: Porta) -> bool: return q.arrombada() and q.aberta), "a explosão arromba o portão inteiro")
	await frames(60 * 3)
	ok(portoes.all(func(q: Porta) -> bool: return q.aberta), "portão explodido não se conserta sozinho")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
