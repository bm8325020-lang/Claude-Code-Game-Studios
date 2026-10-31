# Gavetas, cofres e sala segura (31/10, ideias do teste com novato): revistar abre a gaveta e dá algo ou "nada";
# a gaveta da chave dá a chave; o cofre só abre com chave (que some); o bilhete do cofre diz onde está a chave;
# no refúgio (sala segura) a vida volta e o zumbi desiste.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_gavetas.gd
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


func poe_na_frente(g: Gaveta) -> void:
	j.global_position = g.global_position + g.global_basis.z * 0.9 + Vector3(0, 0.05, 0)
	j.velocity = Vector3.ZERO
	await frames(3)


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
	var z: Zumbi = main.zumbis.get_child(0)
	for x in main.zumbis.get_children():
		if x != z:
			x.free()
	var gavetas: Array[Node] = get_nodes_in_group("gavetas")
	var cofres: Array = main.bairro.find_children("Cofre_*", "Bau", false, false)
	ok(gavetas.size() > 50, "a cidade tem gavetas nos móveis (%d)" % gavetas.size())
	ok(cofres.size() >= 5, "a cidade tem cofres trancados (%d)" % cofres.size())
	# gaveta comum: abre e dá algo ou "nada"
	var g: Gaveta = null
	for n in gavetas:
		if not (n as Gaveta).chave:
			g = n
			break
	var sinal: Array = []
	j.item_pego.connect(func(t: String, q: int) -> void: sinal.append(t))
	await poe_na_frente(g)
	ok(j.gaveta_perto() == g, "na frente do móvel aparece REVISTAR")
	j.entrada["pegar"] = true
	await frames(3)
	ok(g.aberta, "revistar abre a gaveta")
	ok(not sinal.is_empty(), "revistar dá um achado ou avisa que não tem nada (%s)" % str(sinal))
	ok(j.gaveta_perto() != g, "aberta não dá para revistar de novo")
	# cofre: trancado sem chave
	var cf: Bau = cofres[0]
	for it in get_nodes_in_group("itens"):  # item no chão tem prioridade no USAR: tira os de perto do cofre
		if (it as Node3D).global_position.distance_to(cf.global_position) < 4.0:
			it.free()
	j.global_position = cf.global_position + Vector3(0.9, 0.05, 0)
	await frames(3)
	ok(j.bau_perto() == cf and cf.trava, "o cofre está trancado")
	sinal.clear()
	j.entrada["pegar"] = true
	await frames(3)
	ok(j.abrindo == null and cf.trava and "trancado" in sinal, "sem chave não abre (abrindo %s trava %s sinal %s item %s)" % [j.abrindo, cf.trava, sinal, j.item_perto()])
	# a chave está na gaveta que o bilhete aponta
	var gc: Gaveta = cf.gaveta_chave
	ok(gc != null and gc.chave, "a chave do cofre está numa gaveta")
	for it in get_nodes_in_group("itens"):  # item no chão tem prioridade no USAR
		if (it as Node3D).global_position.distance_to(gc.ponto()) < 3.0:
			it.free()
	for n in gavetas:  # móveis colados: abre as vizinhas para o USAR achar a certa
		if n != gc and (n as Gaveta).ponto().distance_to(gc.ponto()) < 2.5:
			(n as Gaveta).aberta = true
	await poe_na_frente(gc)
	j.entrada["pegar"] = true
	await frames(3)
	ok(j.mochila.tem("chave"), "revistar a gaveta certa dá a chave (perto %s, certa %s %s, j %s)" % [j.gaveta_perto(), gc.name, gc.ponto(), j.global_position])
	var bilhete_ok: bool = false
	for b: Node3D in get_nodes_in_group("bilhetes"):
		if String(b.get_meta("texto")).contains("metros para o") and b.global_position.distance_to(cf.global_position) < 4.0:
			bilhete_ok = true
	ok(bilhete_ok, "perto do cofre tem o bilhete dizendo para que lado está a chave")
	j.global_position = cf.global_position + Vector3(0.9, 0.05, 0)
	await frames(3)
	j.entrada["pegar"] = true
	await frames(3)
	ok(not cf.trava and not j.mochila.tem("chave") and j.abrindo == cf, "com a chave destranca, a chave some e começa a abrir (trava %s chave %s abrindo %s perto %s)" % [cf.trava, j.mochila.tem("chave"), j.abrindo, j.bau_perto()])
	# sala segura
	var refugio: Node3D = null
	for c: Node3D in get_nodes_in_group("casas"):
		if c.has_meta("refugio"):
			refugio = c
			break
	j.global_position = main.bairro.dentro_da(String(refugio.name))
	j.vida = 40
	z.global_position = j.global_position + Vector3(3, 0, 0)
	z.alvo = j
	await frames(70)
	ok(j.segura, "dentro do refúgio é sala segura")
	ok(z.alvo == null, "o zumbi desiste de quem está na sala segura")
	await frames(60 * 5)
	ok(j.vida > 40, "na sala segura a vida volta (%d)" % j.vida)
	print("GAVETAS: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
