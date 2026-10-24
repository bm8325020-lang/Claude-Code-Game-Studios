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
	for outro in main.zumbis.get_children():
		if outro != z:
			outro.free()
	await _persegue_e_ataca()
	await _desvia()
	await _tiro_e_morte()
	await _jogador_cai()
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
