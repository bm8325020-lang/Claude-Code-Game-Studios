# População de zumbis (05/11, GTAZ orçamento + fila; Simple Zombies nunca nasce na tela): grupo nasce longe de todos,
# escondido atrás de prédio, marcado como do ambiente; teto ORCAMENTO; quem fica longe some; fora da cidade nada.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_populacao.gd
extends SceneTree

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
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(30)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	j.vida = 100000
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	ok(not Populacao.dentro(Vector3(-20, 0, 30)), "a pista de teste fica fora da cidade")
	j.global_position = main.ponto_nascer("", 1.0)
	j.velocity = Vector3.ZERO
	ok(Populacao.dentro(j.global_position), "o ponto de nascer é na cidade")
	var mapa: RID = main.get_world_3d().navigation_map
	for i in 300:  # a malha da cidade carrega numa thread (tempo de verdade, não quadros)
		var q: Vector3 = j.global_position + Vector3(40, 0, 0)
		if NavigationServer3D.map_get_closest_point(mapa, q).distance_to(q) < 8.0:
			break
		OS.delay_msec(50)
		await frames(5)
	var p := Populacao.new()
	var achou: bool = false
	for k in 10:
		achou = p.solta(main, j, 3)
		if achou:
			break
	ok(achou, "acha lugar escondido para o grupo")
	await frames(2)
	var amb: Array = main.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.horda == Zumbi.AMBIENTE)
	ok(amb.size() == 3, "3 do ambiente (%d)" % amb.size())
	var dmin: float = INF
	for z: Zumbi in amb:
		dmin = minf(dmin, z.global_position.distance_to(j.global_position))
	ok(dmin > Populacao.NASCE_MIN - 5.0, "nasce longe (%.0f m)" % dmin)
	# longe de todos e sem alvo: some
	var volta: Vector3 = j.global_position
	j.global_position = Vector3(-20, 0.1, 30)  # o jogador vai embora (pista de teste, a ~600 m)
	await frames(2)
	p._t = 0.0
	p.passa(main, 0.1)
	await frames(2)
	ok(main.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.horda == Zumbi.AMBIENTE).is_empty(), "longe de todos some")
	# teto: com o orçamento cheio não solta
	j.global_position = volta
	await frames(2)
	for k in Populacao.ORCAMENTO:
		main.spawner_zumbis.spawn({"pos": j.global_position + Vector3(300, 0, 300)})
	await frames(2)
	var n0: int = main.zumbis.get_child_count()
	p._t = 0.0
	p.passa(main, 0.1)
	await frames(2)
	ok(main.zumbis.get_child_count() == n0, "orçamento cheio: não nasce mais")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(1 if falhas else 0)
