# Grupos (prompt 9): convidar, aceitar/recusar, limite de 4, sair (quem fica sozinho sai), convite vence, sem fogo
# amigo (`mesmo`); e no jogo: o servidor monta o grupo e o jogador sabe quem é do grupo dele.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_grupos.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var g := Grupos.new()
	ok(g.convidar(1, 1) != "", "não convida a si mesmo")
	ok(g.convidar(1, 2) == "" and g.responder(2, false) == 0 and not g.de.has(1), "recusar não cria grupo")
	g.convidar(1, 2)
	ok(g.responder(2, true) == 1 and g.mesmo(1, 2), "aceitar cria o grupo de quem convidou")
	ok(not g.mesmo(1, 3) and not g.mesmo(1, 1), "fora do grupo (e você mesmo) não é amigo")
	g.convidar(2, 3)
	g.convidar(1, 4)
	ok(g.responder(3, true) == 1 and g.responder(4, true) == 1 and g.membros(1).size() == 4, "membro também convida; 4 no grupo")
	ok(g.convidar(1, 5) != "", "grupo cheio não convida mais")
	ok(g.convidar(5, 2) != "", "quem já está num grupo não recebe convite")
	g.sair(1)
	ok(g.membros(1).size() == 3 and not g.de.has(1), "quem cria pode sair e o grupo continua")
	g.sair(3)
	g.sair(4)
	ok(g.de.is_empty(), "quem fica sozinho sai também")
	g.convidar(6, 7)
	g.passa(Grupos.CONVITE_T + 1.0)
	ok(g.responder(7, true) == 0, "convite vence em %d s" % int(Grupos.CONVITE_T))
	# no jogo (sozinho = servidor): convida o próprio nick falha com aviso; grupo do servidor chega no jogador
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("Teste")
	for i in 5: await physics_frame
	ok(main.grupos is Grupos and main.convidar_nick("ninguem") != "", "convidar nick que não está jogando falha")
	main.grupos.de = {1: 1, 99: 1}
	main._manda_grupos()
	for i in 3: await physics_frame
	ok(main.grupo_de(1) == 1 and main.grupo_de(99) == 1 and main.amigos().is_empty(), "o jogador recebe o grupo do servidor (amigo 99 fora da partida não aparece)")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
