# Testes da mecânica 5 (zumbi simples): persegue, desvia de obstáculo, ataca, leva tiro, morre e levanta;
# o jogador cai com a vida zerada e volta no início.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_zumbi.gd
extends SceneTree

var main: Node3D
var j: Jogador
var z: Zumbi
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


func plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _init() -> void:
	Zumbi.chance_mordida = 0.0  # a mordida (test_mordida) para o zumbi; aqui mede o resto
	Zumbi.tipo_fixo = "zumbi_policial"  # este teste mede o zumbi médio (os tipos: test_tipos.gd)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0  # dia parado: a noite tem o teste dela
	main.ciclo.set_process(false)
	main.ciclo._process(0.0)
	ok(main.zumbis.get_child_count() == main.bairro.pontos_zumbi.size() * main.BANDO + main.PONTOS_ZUMBI.size() + main.PONTOS_TOCAIA.size() + main.PATRULHAS.size() + main.PONTOS_CHEFE.size(), "zumbis nascem (%d)" % main.zumbis.get_child_count())
	z = main.zumbis.get_child(0)
	z._sem_gritar = INF  # o grito tem o teste dele (no fim)
	for outro in main.zumbis.get_children():
		if outro != z:
			outro.free()
	await _persegue_e_ataca()
	await _desvia()
	await _tiro_e_morte()
	await _jogador_cai()
	await _ouve_tiro()
	await _chama_horda()
	await _cerca()
	await _noite()
	await _tocaia()
	await _patrulha()
	await _esperto()
	await _chefe()
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)


func _persegue_e_ataca() -> void:
	j.global_position = Vector3(30, 0.1, -20)
	z.global_position = Vector3(30, 0, -12)
	await frames(30)
	var d0: float = plano(z.global_position, j.global_position)
	await frames(90)
	ok(plano(z.global_position, j.global_position) < d0 - 2.0, "vê o jogador e vai até ele (%.1f -> %.1f m)" % [d0, plano(z.global_position, j.global_position)])
	ok(z.clipe_atual() in ["correr", "andar", "ataque"], "anima andando/correndo (%s)" % z.clipe_atual())
	for i in 300:
		await physics_frame
		if j.vida < Jogador.VIDA_MAX:
			break
	ok(j.vida == Jogador.VIDA_MAX - Zumbi.DANO, "o soco tira %d (vida %d)" % [Zumbi.DANO, j.vida])
	ok(plano(z.global_position, j.global_position) > 0.5, "não entra dentro do jogador")


func _desvia() -> void:
	# prédio de 8x8 entre os dois: o caminho reto está tapado
	j.vida = 100000
	j.global_position = Vector3(-12, 0.1, 4.5)
	j.velocity = Vector3.ZERO
	z.global_position = Vector3(-12, 0, 15.5)
	z.velocity = Vector3.ZERO
	z.alvo = j
	await frames(60 * 14)
	ok(plano(z.global_position, j.global_position) < 2.2, "contorna o prédio e chega (%.1f m)" % plano(z.global_position, j.global_position))


func _tiro_e_morte() -> void:
	j.vida = Jogador.VIDA_MAX
	j.global_position = Vector3(30, 0.1, -20)
	z.global_position = Vector3(30, 0, -14)
	z.alvo = null
	await frames(5)
	z.set_physics_process(false)  # parado para mirar
	z.vida = Zumbi.VIDA_MAX
	j.entrada["arma"] = "pistola"
	j.entrada["mira_segurando"] = true
	for k in 3:
		var d: Vector3 = (z.global_position + Vector3(0, 1.0, 0) - j.camera.cam.global_position).normalized()
		j.camera.virar(atan2(-d.x, -d.z), -asin(d.y))
		await frames(20)
	var marcas: Array[bool] = []
	j.acertou_alvo.connect(func(forte: bool) -> void: marcas.append(forte))
	j.entrada["atacar"] = true
	await frames(3)
	ok(z.vida == Zumbi.VIDA_MAX - Pistola.DANO, "tiro no peito do zumbi tira %d (vida %d)" % [Pistola.DANO, z.vida])
	ok(marcas == [false], "marca branca na mira no tiro no corpo (%s)" % str(marcas))
	var sangue: bool = false
	for n in root.get_children():
		if n is CPUParticles3D:
			sangue = true
	ok(sangue, "espirra sangue no lugar do tiro")
	ok(z.clipe_atual() == "dano", "cambaleia com o tiro (%s)" % z.clipe_atual())
	z.set_physics_process(true)
	z.levar_golpe(Zumbi.VIDA_MAX, Vector3.FORWARD, j)
	await frames(5)
	ok(z.vida == 0 and z.clipe_atual() == "morte", "morre com a vida zerada (%s)" % z.clipe_atual())
	ok(z.collision_layer == 0 and not z.is_in_group("golpeavel"), "morto não bloqueia nem leva golpe")
	await frames(int(Zumbi.MORTO_POR * 60) + 20)
	ok(z.vida == Zumbi.VIDA_MAX and z.is_in_group("golpeavel"), "levanta depois de %d s" % int(Zumbi.MORTO_POR))
	j.entrada["mira_segurando"] = null


func _jogador_cai() -> void:
	j.vida = 10
	j.global_position = Vector3(30, 0.1, -20)
	z.global_position = Vector3(30, 0, -18.8)
	z.alvo = j
	for i in 240:
		await physics_frame
		if j.vida <= 0:
			break
	ok(j.vida == 0 and j.clipe_atual() == "morte", "jogador cai com a vida zerada (%s)" % j.clipe_atual())
	ok(j.mochila.tem("facao") and not j.mochila.tem("pistola"), "caído: só o facão fica (o resto vai no saco)")
	await frames(int(Jogador.RENASCE * 60) + 10)
	ok(j.vida == Jogador.VIDA_MAX and plano(j.global_position, j.inicio) < 0.5, "volta no início com a vida cheia")


func _ouve_tiro() -> void:
	# o jogador caiu no teste anterior e largou o saco: devolve pistola, balas e lanterna para os próximos
	j.mochila.adicionar("pistola", 1)
	j.mochila.adicionar("lanterna", 1)
	j.pistola.reserva = Pistola.RESERVA_INICIAL
	j.pistola.balas = Pistola.PENTE
	# jogador atrás do prédio (o zumbi não vê); o tiro chama o zumbi até o lugar do barulho
	j.vida = 100000
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(-12, 0.1, 4.5)
	z.alvo = null
	z.global_position = Vector3(-12, 0, 30)
	z.casa = Vector3(-12, 0, 30)
	await frames(30)
	ok(z.alvo == null and z.velocity.length() < 0.1, "sem ver nem ouvir, fica parado")
	main.zumbis.add_child(Zumbi.new())  # um segundo zumbi longe demais para ouvir
	var longe: Zumbi = main.zumbis.get_child(main.zumbis.get_child_count() - 1)
	longe.global_position = Vector3(30, 0, 60)
	await frames(5)
	j.entrada["arma"] = "pistola"
	await frames(3)
	j.entrada["atacar"] = true
	await frames(60 * 4)
	ok(plano(z.global_position, z.casa) > 5.0, "ouve o tiro e sai de casa (%.1f m)" % plano(z.global_position, z.casa))
	ok(plano(longe.global_position, Vector3(30, 0, 60)) < 0.5, "zumbi a mais de %d m não ouve" % int(Pistola.BARULHO))
	# tira o jogador de perto: o zumbi chega no lugar do tiro, procura e volta para casa
	j.global_position = Vector3(40, 0.1, -25)
	var chegou: bool = false
	for i in 60 * 25:
		await physics_frame
		if z._olhando_t > 0.0:
			chegou = true
			break
	ok(chegou and plano(z.global_position, Vector3(-12, 0, 4.5)) < 2.5, "chega onde foi o tiro (%.1f m)" % plano(z.global_position, Vector3(-12, 0, 4.5)))
	for i in 60 * 45:  # procura 4 s e volta devagar, contornando o prédio
		await physics_frame
		if not z._voltando and z._olhando_t <= 0.0:
			break
	ok(z.alvo == null and plano(z.global_position, z.casa) < 1.0, "não acha ninguém e volta para casa (%.1f m)" % plano(z.global_position, z.casa))


func _chama_horda() -> void:
	for outro in main.zumbis.get_children():
		if outro != z:
			outro.free()
	var amigo := Zumbi.new()
	main.zumbis.add_child(amigo)
	var longe := Zumbi.new()
	main.zumbis.add_child(longe)
	j.vida = 100000
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(30, 0.1, -25)
	z.alvo = null
	z._indo_ouvir = false
	z._voltando = false
	z._olhando_t = 0.0
	z._sem_gritar = 0.0
	z.global_position = Vector3(30, 0, -12)  # vê o jogador (13 m)
	amigo.global_position = Vector3(30, 0, 6)  # 18 m do que grita, 31 m do jogador: não vê nem ouve sozinho
	longe.global_position = Vector3(60, 0, 20)  # longe demais do grito
	await frames(25)
	ok(z.alvo == j and z.clipe_atual() == "grito", "vê o jogador e grita (%s)" % z.clipe_atual())
	ok(amigo.alvo == j, "o grito chama o zumbi a 20 m para o mesmo alvo")
	ok(longe.alvo == null, "zumbi a mais de %d m não ouve o grito" % int(Zumbi.GRITO_RAIO))
	ok(z.velocity.length() < 0.3, "gritando fica parado")
	await frames(int(Zumbi.GRITO_PAUSA * 0.5 * 60))
	ok(z.clipe_atual() != "grito", "o grito acaba (%s)" % z.clipe_atual())
	z.alvo = null
	await frames(20)
	ok(z.alvo == j and z.clipe_atual() != "grito", "não grita de novo antes de %d s" % int(Zumbi.GRITO_PAUSA))


func _cerca() -> void:
	# três zumbis chegando pelo mesmo lado: em vez de fila, se espalham em volta do jogador
	for outro in main.zumbis.get_children():
		if outro != z:
			outro.free()
	var grupo: Array[Zumbi] = [z]
	for k in 2:
		var n := Zumbi.new()
		main.zumbis.add_child(n)
		grupo.append(n)
	j.vida = 100000
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(30, 0.1, -25)
	for k in 3:
		var zz: Zumbi = grupo[k]
		zz.global_position = Vector3(29.0 + k, 0, -10.0 - k * 1.5)
		zz.velocity = Vector3.ZERO
		zz._sem_gritar = INF
		zz.alvo = j
	await frames(60 * 5)  # correm mais desde 30/10: chegam e cercam em ~5 s
	var angs: Array[float] = []
	for zz in grupo:
		var d: Vector3 = zz.global_position - j.global_position
		angs.append(atan2(d.x, d.z))
	angs.sort()
	var maior_vao: float = TAU - (angs[2] - angs[0])
	for k in 2:
		maior_vao = maxf(maior_vao, angs[k + 1] - angs[k])
	ok(maior_vao < deg_to_rad(200.0), "se espalham em volta (maior vão %d°)" % int(rad_to_deg(maior_vao)))
	var perto: int = 0
	for zz in grupo:
		if plano(zz.global_position, j.global_position) < 2.5:
			perto += 1
	ok(perto >= 2, "fecham o cerco e chegam perto (%d de 3)" % perto)


func _noite() -> void:
	main.ciclo.tempo = Ciclo.DIA + 60.0
	main.ciclo._process(0.0)
	ok(main.ciclo.e_noite() and is_equal_approx(main.ciclo.noite(), 1.0), "relógio na noite fechada")
	ok(main.ciclo.sol.light_energy < 0.4 and main.ciclo.ambiente.background_color.v < 0.2, "escurece o sol e o céu")
	await process_frame
	await process_frame
	ok(j._lanterna.visible and j._lanterna.light_energy > 1.0 and j._lanterna_mao.visible, "lanterna na mão liga sozinha no escuro")
	for outro in main.zumbis.get_children():
		if outro != z:
			outro.free()
	j.vida = 100
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(30, 0.1, -25)
	z.global_position = Vector3(30, 0, -18)
	z.velocity = Vector3.ZERO
	z.alvo = j
	await frames(55)  # termina o ataque anterior e acelera
	ok(Vector2(z.velocity.x, z.velocity.z).length() > Zumbi.CORRER * z._vel * 1.15, "à noite corre mais (%.1f m/s, %s)" % [Vector2(z.velocity.x, z.velocity.z).length(), z.tipo])
	for i in 400:
		await physics_frame
		if j.vida < 100:
			break
	ok(j.vida == 100 - roundi(Zumbi.DANO * Zumbi.NOITE_DANO), "à noite o soco tira mais (vida %d)" % j.vida)
	main.ciclo.tempo = 0.0
	main.ciclo._process(0.0)
	await process_frame
	await process_frame
	ok(not j._lanterna.visible, "de dia a lanterna apaga")


func _tocaia() -> void:
	for outro in main.zumbis.get_children():
		outro.free()
	var t := Zumbi.new()
	t.tocaia = true
	t.position = Vector3(30, 0, -17)
	t.casa = t.position
	main.zumbis.add_child(t)
	j.vida = 100
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(30, 0.1, -25)  # 8 m, à vista
	await frames(40)
	ok(t.clipe_atual() == "deitado" and t.alvo == null, "de tocaia fica deitado mesmo vendo alguém (%s)" % t.clipe_atual())
	j.global_position = Vector3(30, 0.1, -20)  # passa a 3 m
	await frames(20)
	ok(t.alvo == j and t.clipe_atual() == "levantar", "levanta quando alguém passa perto (%s)" % t.clipe_atual())
	for i in 300:
		await physics_frame
		if j.vida < 100:
			break
	ok(j.vida < 100, "levanta e ataca (vida %d)" % j.vida)
	# tiro no corpo deitado: acerta (colisor deitado) e acorda
	t.free()
	var t2 := Zumbi.new()
	t2.tocaia = true
	t2.position = Vector3(30, 0, -18)
	t2.casa = t2.position
	main.zumbis.add_child(t2)
	j.vida = 100
	j.global_position = Vector3(30, 0.1, -25)
	await frames(10)
	t2.set_physics_process(false)
	j.entrada["arma"] = "pistola"
	j.entrada["mira_segurando"] = true
	for k in 3:
		var d: Vector3 = (t2.global_position + Vector3(0, 0.3, 0) - j.camera.cam.global_position).normalized()
		j.camera.virar(atan2(-d.x, -d.z), -asin(d.y))
		await frames(20)
	j.entrada["atacar"] = true
	await frames(3)
	ok(t2.vida == Zumbi.VIDA_MAX - Pistola.DANO, "tiro acerta o corpo deitado (vida %d)" % t2.vida)
	ok(not t2._deitado, "o tiro acorda o zumbi")
	j.entrada["mira_segurando"] = null


# maior velocidade de lado (perpendicular à linha até o jogador) do zumbi em `n` quadros
func _lado_max(zz: Zumbi, n: int) -> float:
	var m: float = 0.0
	for i in n:
		await physics_frame
		var linha: Vector3 = j.global_position - zz.global_position
		linha.y = 0.0
		var lado := Vector3(linha.z, 0, -linha.x).normalized()
		m = maxf(m, absf(zz.velocity.dot(lado)))
	return m


func _esperto() -> void:
	for outro in main.zumbis.get_children():
		outro.free()
	var zz := Zumbi.new()
	main.zumbis.add_child(zz)
	await frames(2)
	zz._sem_gritar = INF
	j.vida = 100000
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(30, 0.1, -30)
	j.entrada["arma"] = "pistola"
	j.entrada["mira_segurando"] = false
	zz.global_position = Vector3(30, 0, -16)
	zz.alvo = j
	j.camera.virar(PI)  # olhando para +Z, na direção do zumbi
	var sem_mira: float = await _lado_max(zz, 90)
	zz.global_position = Vector3(30, 0, -16)
	j.entrada["mira_segurando"] = true
	var com_mira: float = await _lado_max(zz, 90)
	ok(sem_mira < 0.8 and com_mira < 0.8, "mirando nele vem reto, sem ziguezague (de lado: %.1f sem mira, %.1f com mira)" % [sem_mira, com_mira])
	j.entrada["mira_segurando"] = null
	await frames(5)
	# pouca vida: não foge, continua vindo (dono 30/10: fugir era "criança")
	zz.global_position = Vector3(30, 0, -27.5)
	zz.vida = 40
	await frames(10)
	zz.levar_golpe(20, Vector3.FORWARD, j)
	var d0: float = plano(zz.global_position, j.global_position)
	await frames(60 * 2)
	ok(zz._foge_t <= 0.0 and plano(zz.global_position, j.global_position) <= d0 + 0.5, "com pouca vida não foge (%.1f -> %.1f m)" % [d0, plano(zz.global_position, j.global_position)])


func _patrulha() -> void:
	for outro in main.zumbis.get_children():
		outro.free()
	var rota: Array = [Vector3(30, 0, -10), Vector3(30, 0, 2), Vector3(40, 0, 2)]
	var p := Zumbi.new()
	p.position = rota[0]
	p.casa = rota[0]
	p.rota = rota
	main.zumbis.add_child(p)
	j.global_position = Vector3(-30, 0.1, 30)  # longe: ninguém vê
	await frames(2)
	p._sem_gritar = INF
	var passou: Array[int] = []
	for i in 60 * 80:  # volta inteira ~38 m a 0,8 m/s, mais as paradas
		await physics_frame
		for k in rota.size():
			if plano(p.global_position, rota[k]) < 1.0 and not passou.has(k):
				passou.append(k)
		if passou.size() == rota.size() and plano(p.global_position, rota[0]) < 1.0:
			break
	ok(passou.size() == rota.size(), "patrulha passa por todos os pontos (%s)" % str(passou))
	ok(plano(p.global_position, rota[0]) < 1.5, "e volta ao começo da rota")
	# vê alguém: sai da rota e persegue
	j.global_position = p.global_position + Vector3(0, 0.1, 8)
	j.vida = 100000
	await frames(40)
	ok(p.alvo == j, "sai da patrulha quando vê alguém")


func _chefe() -> void:
	for outro in main.zumbis.get_children():
		outro.free()
	var c := Zumbi.new()
	c.chefe = true
	c.position = Vector3(30, 0, -14)
	c.casa = c.position
	main.zumbis.add_child(c)
	j.global_position = Vector3(-30, 0.1, 30)
	await frames(2)
	c._sem_gritar = INF
	ok(c.vida == Zumbi.VIDA_CHEFE and c.modelo.scale.x > 1.2, "chefe nasce grande e com %d de vida" % c.vida)
	c.levar_golpe(Pistola.DANO, Vector3.FORWARD, j)
	await frames(2)
	ok(c._cambaleio <= 0.0, "tiro de pistola não faz o chefe cambalear")
	c.vida = 30
	c.levar_golpe(10, Vector3.FORWARD, j)
	await frames(2)
	ok(not c._fugiu, "chefe não foge com pouca vida")
	c.vida = Zumbi.VIDA_CHEFE
	j.vida = Jogador.VIDA_MAX
	j.global_position = c.global_position + Vector3(0, 0.1, 1.2)
	var antes: int = j.vida
	for i in 60 * 6:
		await physics_frame
		if j.vida < antes:
			break
	ok(antes - j.vida == Zumbi.DANO_CHEFE, "soco do chefe tira %d (tirou %d)" % [Zumbi.DANO_CHEFE, antes - j.vida])
