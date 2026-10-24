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
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	ok(main.zumbis.get_child_count() == main.PONTOS_ZUMBI.size(), "zumbis nascem (%d)" % main.zumbis.get_child_count())
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
	j.entrada["atacar"] = true
	await frames(3)
	ok(z.vida == Zumbi.VIDA_MAX - Pistola.DANO, "tiro no peito do zumbi tira %d (vida %d)" % [Pistola.DANO, z.vida])
	ok(z.clipe_atual() == "dano", "cambaleia com o tiro (%s)" % z.clipe_atual())
	z.set_physics_process(true)
	z.levar_golpe(100, Vector3.FORWARD, j)
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
	await frames(int(Jogador.RENASCE * 60) + 10)
	ok(j.vida == Jogador.VIDA_MAX and plano(j.global_position, j.inicio) < 0.5, "volta no início com a vida cheia")


func _ouve_tiro() -> void:
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
	amigo.global_position = Vector3(48, 0, -4)  # 20 m do que grita, 25 m do jogador: não vê nem ouve sozinho
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
	await frames(60 * 9)
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
