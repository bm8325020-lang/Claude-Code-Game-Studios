# Pacote de jogabilidade (14/11, dono: itens 1 a 5): base que cresce, noite de defesa, loot com raridade e acessórios,
# tiro com impacto (perna derruba, cabeça estoura) e esquiva com fôlego, começo no acampamento destruído.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_base.gd
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


func _usa(tipo: String) -> void:
	j.mochila.adicionar(tipo, 1)
	j.usar_espaco(j.mochila.onde(tipo))
	await frames(3)


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(30)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	j.vida = 100
	var b: Bairro = main.bairro

	# 5) começo: o acampamento destruído existe, com o bilhete
	ok(b.inicio_pos.is_finite(), "mapa tem o acampamento do começo")
	ok(b.get_node_or_null("Inicio/Bilhete") is Item, "bilhete no acampamento")
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	await frames(20)
	ok(j.is_on_floor(), "o acampamento é chão firme (não nasce dentro de árvore/buraco)")

	# 3) raridade e acessórios
	var rng := RandomNumberGenerator.new()
	var achou: bool = false
	for k in 40:
		for e: Dictionary in Loot.sorteia(rng, false, true):
			if Loot.e_arma(String(e.tipo)):
				achou = achou or e.has("rar")
	ok(achou, "arma de baú de raid vem com raridade")
	j.ganhar("faca", 1, 3)
	ok(j.raridade_de("faca") == 3, "pegou faca lendária")
	j.ganhar("faca", 1, 1)
	ok(j.raridade_de("faca") == 3, "faca pior não troca a lendária")
	var p: Pistola = j.pistola
	var comum: int = p.dano_em(5.0, 1.2, false)
	j.raridades["pistola"] = 2
	ok(p.dano_em(5.0, 1.2, false) > comum, "pistola rara dá mais dano")
	var esp: float = p.dispersao(false)
	j.mochila.adicionar("mira", 1)
	ok(p.dispersao(false) < esp, "mira na mochila espalha menos")
	j.mochila.adicionar("pente_ext", 1)
	await frames(2)
	ok(p.pente == Pistola.PENTE + Pistola.PENTE / 2, "pente estendido: %d balas" % p.pente)
	ok(Pistola.dano_maximo("sniper") >= roundi(110 * 2 * Loot.RAR_DANO[3]), "teto do servidor cabe a arma lendária")

	# 2) base: barraca, cabana só depois da barraca, cerca, torre, baú, horta
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	await frames(10)
	await _usa("cabana")
	ok(get_nodes_in_group("base_cabana").is_empty(), "cabana pede barraca antes")
	for t: String in ["barraca", "estacas", "torre", "bau_base", "horta"]:
		j.camera.virar(randf() * TAU, 0.0)
		await _usa(t)
		ok(get_nodes_in_group("base_" + t).size() == 1, "montou %s" % t)
	await _usa("cabana")
	ok(get_nodes_in_group("base_cabana").size() == 1, "montou a cabana depois da barraca")
	ok(main.ponto_nascer("Teste").distance_to((get_nodes_in_group("base_cabana")[0] as Node3D).global_position) < 3.0, "renasce na cabana")
	var barraca: Peca = get_nodes_in_group("base_barraca")[0]
	j.global_position = barraca.global_position + Vector3(0, 0.3, 0)
	await frames(5)
	ok(j.cama_perto() != Vector3.INF and j.cama_perto() != Vector3.ZERO, "dá para dormir na barraca")
	var horta: Peca = get_nodes_in_group("base_horta")[0]
	horta.colhida_t = -999.0
	j.global_position = horta.global_position + Vector3(1.0, 0.3, 0)
	await frames(5)
	var fr: int = j.mochila.conta("fruta")
	var c: Array = j.coleta_perto()
	ok(not c.is_empty() and c[1] == "horta", "horta pronta para colher")
	if not c.is_empty() and c[1] == "horta":
		j._colhe(c)
	ok(j.mochila.conta("fruta") > fr, "colheu da horta")
	var bp: Peca = get_nodes_in_group("base_bau_base")[0]
	ok(bp.bau != null and bp.bau.pode(j), "baú da base abre para qualquer um")
	var cerca: Peca = get_nodes_in_group("base_estacas")[0]
	main.spawner_zumbis.spawn({"pos": cerca.global_position + cerca.global_basis.z * 0.6 + Vector3(0, 0.1, 0)})
	await frames(150)
	ok(not is_instance_valid(cerca) or cerca.vida < Peca.VIDA_ESTACAS, "zumbi colado quebra a cerca")
	for z in main.zumbis.get_children():
		z.free()

	# 1) noite de defesa: onda contra a base e caixa ao amanhecer
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	var antes: int = main._fila_zumbis.size() + main.zumbis.get_child_count()
	ok(main.defesa.cai_noite(main), "a noite cai e a onda vem")
	ok(main._fila_zumbis.size() + main.zumbis.get_child_count() >= antes + Defesa.ONDA_BASE, "onda com %d zumbis" % Defesa.ONDA_BASE)
	var caixas: int = main.soltos.get_children().filter(func(n: Node) -> bool: return n is Bau).size()
	ok(main.defesa.amanhece(main), "sobreviveu à noite")
	await frames(3)
	ok(main.defesa.noites == 1, "conta a noite segurada")
	ok(main.soltos.get_children().filter(func(n: Node) -> bool: return n is Bau).size() > caixas, "caixa de suprimento caiu do lado da base")
	main._fila_zumbis.clear()
	for z in main.zumbis.get_children():
		z.free()

	# 4) tiro: perna derruba, cabeça estoura; esquiva
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	await frames(10)
	var zz: Zumbi = main.spawner_zumbis.spawn({"pos": j.global_position + Vector3(6, 0, 0)})
	await frames(10)
	for k in 12:
		zz.tiro_na_perna()
		if zz._deitado:
			break
	ok(zz._deitado, "tiro na perna derruba")
	zz.estoura_cabeca()
	ok(zz._sem_cabeca, "tiro na cabeça estoura")
	zz.free()
	await frames(30)
	j.folego = 100.0
	var de: Vector3 = j.global_position
	j.entrada["esquiva"] = true
	await frames(2)
	ok(j._esquiva_t > 0.0, "esquiva começou")
	var v: int = j.vida
	j._recebe_dano(20, Vector3.ZERO)
	ok(j.vida == v, "no meio da esquiva não leva dano")
	await frames(20)
	ok(Vector2(j.global_position.x - de.x, j.global_position.z - de.z).length() > 1.2, "esquiva tira do lugar (%.1f m)" % Vector2(j.global_position.x - de.x, j.global_position.z - de.z).length())
	ok(j.folego <= 100.0 - Jogador.ESQUIVA_FOLEGO + 5.0, "esquiva gasta fôlego")

	# 6) eventos: avião com a caixa e saqueadores correndo; lua cheia; fogo novo
	j.global_position = b.inicio_pos + Vector3(0, 0.3, 0)
	await frames(5)
	var fila: int = main._fila_zumbis.size() + main.zumbis.get_child_count()
	var largou: bool = false
	for k in 5:
		largou = largou or main.suprimento.solta(main)
	ok(largou, "suprimento cai na mata")
	await frames(2)
	ok(main.get_children().any(func(n: Node) -> bool: return n is Aviao), "avião passa por cima")
	ok(main._fila_zumbis.size() + main.zumbis.get_child_count() >= fila + Suprimento.SAQUEADORES, "saqueadores correm para a caixa")
	ok(Clima.TIPOS.has("lua_cheia"), "lua cheia existe")
	var fg := Fogo.new()
	fg.lenha = true
	main.add_child(fg)
	await frames(2)
	ok(fg.find_children("*", "CPUParticles3D", false, false).size() >= 3, "fogo com chamas, fumaça e faíscas")
	ok(fg.find_children("*", "MeshInstance3D", false, false).size() >= 5, "fogueira com lenha e brasa")

	print("test_base: %d checks, %d falhas" % [checks, falhas])
	quit(1 if falhas > 0 else 0)
