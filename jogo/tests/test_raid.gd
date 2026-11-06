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
	var nomes: Array = b.raids.map(func(r: Dictionary) -> String: return r.nome)
	ok(b.has_node("Delegacia") and "DELEGACIA" in nomes, "tem delegacia na cidade (raids: %s)" % str(nomes))
	ok(b.has_node("Hospital") and b.has_node("Mercado") and b.has_node("Igreja") and nomes.size() == 4, "hospital, supermercado e igreja também são raid")
	var da_delegacia: Array = b.pontos_raid.filter(func(r: Dictionary) -> bool: return r.tipo == "zumbi_policial")
	var armados: int = da_delegacia.filter(func(r: Dictionary) -> bool: return r.armado).size()
	ok(da_delegacia.size() >= 10 and armados >= 3, "delegacia com %d zumbis (%d armados)" % [da_delegacia.size(), armados])
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
	var policiais: Array = raid_z.filter(func(z: Zumbi) -> bool: return z.tipo == "zumbi_policial")
	ok(raid_z.size() == b.pontos_raid.size() and policiais.size() >= da_delegacia.size(), "zumbis da raid nascem (os da delegacia, policiais)")
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
	# Os Corvos (06/11): saqueadores vivos no mercado; avisam antes do primeiro tiro e não mordem nem gemem
	var c := Zumbi.new()
	c.de_raid = true
	c.tipo_pedido = "corvo"
	c.position = Vector3(36, 0, -12)
	c.casa = c.position
	main.zumbis.add_child(c)
	await frames(2)
	ok(c.humano() and c.armado and not c.come and c.chance_grito == 0.0, "corvo é gente armada que não grita nem come")
	ok(c.anim.has_animation(c._real("andar")) and c._real("andar") == "andar_p", "corvo anda como gente (%s)" % c._real("andar"))
	c.alvo = j
	await frames(3)
	ok(c._avisou and c._tiro_cd < 1.0, "corvo não avisa: atira logo que vê (07/11)")
	# rouba o saco de quem morreu e devolve quando morre
	c.alvo = null
	c._caca_t = 0.0
	var saco := Bau.new()
	saco.saco = true
	main.add_child(saco)
	saco.global_position = c.global_position + Vector3(1.0, 0, 0)
	saco.conteudo = [{"tipo": "municao", "qtd": 20}]
	c._caca()
	c._caca()
	ok(saco.conteudo.is_empty() and c._roubado.size() == 1, "corvo rouba o saco de quem morreu")
	saco.free()
	var corvos: Array = b.pontos_raid.filter(func(r: Dictionary) -> bool: return r.tipo == "corvo")
	ok(corvos.size() >= 3 and corvos.all(func(r: Dictionary) -> bool: return r.armado), "mercado tem %d corvos armados" % corvos.size())
	c.free()
	# morto fica morto
	z.levar_golpe(100000, Vector3.FORWARD, j)
	await frames(60 * 12)
	ok(z.vida <= 0 and z._morto_t > Zumbi.MORTO_POR, "zumbi da raid morto fica morto (15 min)")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
