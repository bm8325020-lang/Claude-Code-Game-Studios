# Resgate com raid (prompt 10): regra do grupo perto (2+ vivos a até 75 m), tamanho da raid, e no jogo: caído no
# grupo espera sem largar nada, a raid nasce em volta, matar todos levanta com 30 de vida e paga; se o servidor
# negar ou o tempo acabar, morte normal com saco.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_resgate.gd
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


func sacos(main: Node) -> int:
	return main.soltos.get_children().filter(func(n: Node) -> bool: return n is Bau).size()


func _init() -> void:
	var g := Grupos.new()
	g.de = {1: 1, 2: 1, 3: 1, 4: 9}
	var p := Vector3.ZERO
	ok(g.pode_resgate(1, p, {2: Vector3(10, 0, 0), 3: Vector3(0, 0, 70)}), "2 do grupo perto: tem resgate")
	ok(not g.pode_resgate(1, p, {2: Vector3(10, 0, 0), 3: Vector3(0, 0, 80)}), "um longe demais: não tem")
	ok(not g.pode_resgate(1, p, {2: Vector3(10, 0, 0), 4: Vector3(1, 0, 0)}), "quem é de outro grupo não conta")
	ok(Grupos.zumbis_raid(0, 0) == 4 and Grupos.zumbis_raid(2000, 150) > Grupos.zumbis_raid(0, 0) and Grupos.zumbis_raid(99999, 9999) == 12, "raid cresce com a mochila e os abates (4 a 12)")
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	j.global_position = Vector3(40, 0.1, 40)
	j.mochila.adicionar("municao", 30)
	# no grupo (de mentira: o servidor não acha os amigos perto) -> espera, depois o servidor nega -> morte normal
	main._grupos_cli = {1: 1, 2: 1}
	main.grupos.de = {1: 1, 2: 1}
	var sacos0: int = sacos(main)
	j.levar_dano(1000, Vector3.FORWARD)
	await frames(5)
	ok(not j.resgate and j._morto_t <= Jogador.RENASCE and sacos(main) > sacos0, "servidor nega (amigos longe): morte normal com saco")
	j._morto_t = 0.01
	await frames(5)
	# agora a raid de verdade: o servidor solta, o grupo mata todos e ele levanta
	j.mochila.adicionar("municao", 30)
	j.resgate = true
	j.vida = 0
	j._morto_t = Jogador.RESGATE_T
	var nsacos: int = sacos(main)
	main.inicia_raid(1, j.global_position, 0, 0)
	await frames(5)
	var raid: Array = main.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.raid == 1)
	ok(raid.size() == 4 and raid.all(func(z: Zumbi) -> bool: return z.global_position.distance_to(j.global_position) < 13.0), "a raid nasce em volta do caído (%d zumbis)" % raid.size())
	var d0: int = j.dinheiro
	for z: Zumbi in raid:
		z.levar_golpe(1000, Vector3.FORWARD, null)
	await frames(5)
	ok(j.vida == Jogador.RESGATE_VIDA and not j.resgate and sacos(main) == nsacos and j.mochila.conta("municao") >= 30, "matou todos: levanta com %d de vida sem largar nada" % Jogador.RESGATE_VIDA)
	ok(j.dinheiro >= d0 + main.RESGATE_DINHEIRO, "e ganha a recompensa ($%d)" % (j.dinheiro - d0))
	# o tempo acaba: morte normal
	j.vida = 0
	j.resgate = true
	j._morto_t = 0.05
	main.inicia_raid(1, j.global_position, 0, 0)
	await frames(10)
	ok(not j.resgate and sacos(main) > nsacos, "o tempo acabou: larga o saco e volta no início")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
