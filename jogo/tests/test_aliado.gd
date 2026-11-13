# Corvo aliado (12/11, dono: "um jeito de conseguir aliados, no máximo 3, inteligentes, só uma ajuda"): só contrata com
# trégua e dinheiro; segue o dono; atira em zumbi sem levar surra; não caça jogador; PARADO fica; dispensar some.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_aliado.gd
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


func chao(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(root.get_world_3d().navigation_map, p) + Vector3(0, 0.2, 0)


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(90)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	Zumbi.ronda_ligada = false
	for z in main.zumbis.get_children():
		z.free()
	j.vida = 1000000
	j.global_position = chao(Bairro.ORIGEM + Vector3(-60, 0, 170))  # na trilha da mata (fora dela as árvores tapam o tiro)
	await frames(5)
	var c: Zumbi = main.spawner_zumbis.spawn({"pos": chao(j.global_position + Vector3(2.5, 0, 0)), "armado": true, "tipo": "corvo"})
	await frames(5)
	ok(c.humano(), "nasceu um Corvo")
	ok(j.corvo_perto() == null, "sem trégua não dá para contratar")
	j.tregua_dia = main.ciclo.dia
	c.global_position = chao(j.global_position + Vector3(2.5, 0, 0))
	ok(j.corvo_perto() == c, "com trégua, o Corvo perto pode ser contratado")
	j.dinheiro = 50
	j.contrata()
	ok(c.dono == null and j.dinheiro == 50, "sem dinheiro não contrata")
	j.dinheiro = 1000
	j.contrata()
	ok(c.dono == j and j.dinheiro == 1000 - Jogador.ALIADO_PRECO[0], "contratou e pagou (%d)" % j.dinheiro)
	ok(j.meus_aliados().size() == 1 and c.vida == Zumbi.ALIADO_VIDA, "está na lista de aliados, com a vida de aliado")
	j.tregua_dia = -1  # a trégua acaba; o contrato não
	var v0: int = c.vida
	c.levar_golpe(50, Vector3.FORWARD, j)
	ok(c.vida == v0, "golpe do dono não fere o aliado")
	# segue
	j.global_position = chao(j.global_position + Vector3(-5, 0, 13))  # segue a trilha
	await frames(300)
	ok(c.global_position.distance_to(j.global_position) < 6.5 and c.alvo == null, "seguiu o dono (%.1f m) e não o caça" % c.global_position.distance_to(j.global_position))
	# zumbi à vista: atira, não troca soco
	var z: Zumbi = main.spawner_zumbis.spawn({"pos": chao(c.global_position + (c.global_position - j.global_position).normalized() * 9.0)})
	var zv: int = z.vida
	var perto_min: float = INF
	for i in 900:
		await physics_frame
		if z.vida <= 0:
			break
		perto_min = minf(perto_min, z.global_position.distance_to(c.global_position))
	ok(z.vida < zv, "atirou no zumbi (vida %d -> %d)" % [zv, z.vida])
	ok(c.vida > Zumbi.ALIADO_VIDA * 0.7, "não apanhou à toa (vida %d, zumbi chegou a %.1f m)" % [c.vida, perto_min])
	for q in main.zumbis.get_children():
		if q != c:
			q.free()
	await frames(30)
	# parado
	j.ordena(Zumbi.Ordem.PARADO)
	var posto: Vector3 = c.global_position
	j.global_position = chao(j.global_position + Vector3(5, 0, -13))
	await frames(240)
	ok(c.global_position.distance_to(posto) < 1.5, "PARADO: ficou no lugar (andou %.1f m)" % c.global_position.distance_to(posto))
	j.ordena(Zumbi.Ordem.SEGUIR)
	await frames(360)
	ok(c.global_position.distance_to(j.global_position) < 6.5, "SEGUIR: voltou para o dono (%.1f m)" % c.global_position.distance_to(j.global_position))
	j.ordena(-1)
	await frames(5)
	ok(j.meus_aliados().is_empty(), "dispensado: foi embora")
	print("%s: %d/%d" % ["PASS" if falhas == 0 else "FAIL", checks - falhas, checks])
	quit(1 if falhas else 0)
