# Testes da horda andarilha (05/11, mods de zumbi do GTA V): nasce longe do jogador com um líder maior, marcha para
# cima dele, o líder não toma dano enquanto houver outro vivo, e corpo de horda some (não levanta). Quem morre
# levanta zumbi deitado do lado do saco.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_horda.gd
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
	Zumbi.ronda_ligada = false  # 07/11: zumbi rondando muda as posições que este teste mede
	await frames(30)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	j.vida = 100000
	main.ciclo.set_process(false)
	main.ciclo.tempo = 60.0  # dia
	main.ciclo._process(0.0)
	for z in main.zumbis.get_children():
		z.free()
	j.global_position = main.ponto_nascer("", 1.0)
	j.velocity = Vector3.ZERO
	var mapa: RID = main.get_world_3d().navigation_map
	for i in 300:  # a malha da cidade carrega numa thread (tempo de verdade, não quadros)
		var q: Vector3 = j.global_position + Vector3(40, 0, 0)
		if NavigationServer3D.map_get_closest_point(mapa, q).distance_to(q) < 8.0:
			break
		OS.delay_msec(50)
		await frames(5)
	ok(main.horda.solta(main, 4), "acha lugar para a horda")
	await frames(2)
	var membros: Array = main.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.horda > 0)  # a horda tem id > 0
	ok(membros.size() == 5, "4 + o líder (%d)" % membros.size())
	var lideres: Array = membros.filter(func(z: Zumbi) -> bool: return z.lider)
	ok(lideres.size() == 1, "um líder")
	var lider: Zumbi = lideres[0] if lideres.size() > 0 else null
	ok(lider != null and lider.vida == Zumbi.VIDA_LIDER, "líder com mais vida")
	var d0: float = INF
	for z: Zumbi in membros:
		d0 = minf(d0, z.global_position.distance_to(j.global_position))
	ok(d0 > Horda.LONGE_DE_TODOS - 6.0, "nasce longe do jogador (%.0f m)" % d0)
	await frames(60 * 12)
	var d1: float = INF
	var marchando: int = 0
	for z: Zumbi in membros:
		if is_instance_valid(z):
			d1 = minf(d1, z.global_position.distance_to(j.global_position))
			if z.marcha.is_finite() or z.alvo != null:
				marchando += 1
	ok(marchando >= 4, "marcham (%d)" % marchando)
	ok(d1 < d0 - 5.0, "vêm na direção do jogador (%.0f -> %.0f m)" % [d0, d1])
	ok(lider.imune, "líder imune com os outros vivos")
	var antes: int = lider.vida
	lider._aplica(50, Vector3.FORWARD)
	ok(lider.vida == antes, "líder não toma dano")
	var outro: Zumbi = null
	for z: Zumbi in membros:
		if z != lider:
			z._aplica(100000, Vector3.FORWARD)
			outro = z
	await frames(60 * 5)
	ok(not lider.imune, "sozinho, o líder perde a imunidade")
	lider._aplica(50, Vector3.FORWARD)
	ok(lider.vida < antes, "e toma dano")
	await frames(int(60 * (Zumbi.CORPO_HORDA + 2.0)))
	ok(not is_instance_valid(outro), "corpo de horda some (não levanta)")
	main.solta_saco([{"tipo": "comida", "qtd": 1}], j.global_position)
	await frames(2)
	var do_morto: Array = main.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.horda == Zumbi.DO_MORTO)
	ok(do_morto.size() == 1 and (do_morto[0] as Zumbi).tocaia, "quem morre levanta zumbi deitado do lado do saco")
	ok(Horda.lado(Vector3(0, 0, -1)) == "NORTE" and Horda.lado(Vector3(1, 0, 0)) == "LESTE", "nome do lado")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
