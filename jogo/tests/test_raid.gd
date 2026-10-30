# Raid da delegacia (plano do dono, 30/10): a delegacia está no centro, cheia de zumbis policiais (alguns armados) e
# com baús de loot raro; o zumbi armado atira de longe; o da raid morto fica morto.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_raid.gd
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
	var b: Bairro = main.bairro
	ok(b.has_node("Delegacia") and b.raids.size() == 1, "tem delegacia na cidade")
	var armados: int = b.pontos_raid.filter(func(r: Dictionary) -> bool: return r.armado).size()
	ok(b.pontos_raid.size() >= 10 and armados >= 3, "delegacia com %d zumbis (%d armados)" % [b.pontos_raid.size(), armados])
	var baus: Array = b.get_node("Delegacia").find_children("Bau_raid_*", "Bau", true, false)
	ok(baus.size() == 3 and baus.all(func(x: Bau) -> bool: return x.raid), "3 baús de raid")
	# loot de raid: bem mais raras que o baú comum
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var raras_raid: int = 0
	var raras: int = 0
	for i in 400:
		for it: Dictionary in Loot.sorteia(rng, false, true):
			raras_raid += int(Loot.raridade(it.tipo) == Loot.RARO)
		for it: Dictionary in Loot.sorteia(rng):
			raras += int(Loot.raridade(it.tipo) == Loot.RARO)
	ok(raras_raid > raras * 3, "baú de raid tem muito mais coisa rara (%d contra %d)" % [raras_raid, raras])
	var raid_z: Array = main.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.de_raid)
	ok(raid_z.size() == b.pontos_raid.size() and raid_z.all(func(z: Zumbi) -> bool: return z.tipo == "zumbi_policial"), "zumbis da raid nascem (policiais)")
	# zumbi armado atira de longe, num lugar aberto da pista
	for z in main.zumbis.get_children():
		z.free()
	Zumbi.chance_mordida = 0.0
	var z := Zumbi.new()
	z.armado = true
	z.de_raid = true
	z.tipo_pedido = "zumbi_policial"
	z.position = Vector3(30, 0, -12)
	z.casa = z.position
	main.zumbis.add_child(z)
	await frames(2)
	j.global_position = Vector3(30, 0.1, -22)  # 10 m
	j.vida = 100000
	z._sem_gritar = INF
	z.alvo = j
	var antes: int = j.vida
	var tiros: int = 0
	for i in 60 * 15:  # uns 6 tiros: a chance de errar todos é desprezível
		await physics_frame
		if z._mirando >= 0.0:
			tiros += 1
		if j.vida < antes:
			break
	ok(antes - j.vida > 0, "zumbi armado acerta tiro de 10 m (tirou %d)" % (antes - j.vida))
	ok(z.global_position.distance_to(j.global_position) > Zumbi.TIRO_DE, "e atira em vez de só correr até você")
	# morto fica morto
	z.levar_golpe(100000, Vector3.FORWARD, j)
	await frames(60 * int(Zumbi.MORTO_POR + 2))
	ok(z.vida <= 0, "zumbi da raid morto não levanta em %d s" % int(Zumbi.MORTO_POR))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
