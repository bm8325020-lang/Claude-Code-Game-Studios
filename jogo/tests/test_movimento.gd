# Testes da mecânica 1 (andar + câmera), sem tela: um "bot" preenche a entrada do jogador e mede o resultado.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_movimento.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0
var main: Node3D
var j: Jogador


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null  # o teclado não mexe: o teste dirige a entrada
	await _velocidades()
	await _pulo()
	await _agachar_tunel()
	await _rampas()
	await _camera_parede()
	await _animacoes()
	await _controle_no_ar()
	await _mira_travada()
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func poe(p: Vector3, yaw: float = 0.0) -> void:
	j.global_position = p
	j.velocity = Vector3.ZERO
	j.camera.yaw = yaw
	j.entrada = {"move": Vector2.ZERO, "olhar": Vector2.ZERO, "pular": false, "correr": false, "agachar": false, "andar": false, "mirar": false}
	j.mira_travada = false
	if j.agachado:
		j._alterna_agachar()
	j.reset_physics_interpolation()
	await frames(10)


func vel_plano() -> float:
	return Vector2(j.velocity.x, j.velocity.z).length()


func _velocidades() -> void:
	# área livre ao sul (x 30, z 40)
	await poe(Vector3(30, 0.1, 40), 0.0)
	j.entrada["move"] = Vector2(0, 1)
	await frames(15)  # 0,25 s
	ok(vel_plano() > Jogador.TROTE * 0.9, "chega ao trote em 0,25 s (%.2f)" % vel_plano())
	ok(j.global_position.z < 40.0, "frente da câmera (yaw 0) é -Z")
	j.entrada["correr"] = true
	await frames(30)
	ok(absf(vel_plano() - Jogador.CORRER) < 0.3, "correr chega a %.1f m/s (%.2f)" % [Jogador.CORRER, vel_plano()])
	j.entrada["correr"] = false
	j.entrada["move"] = Vector2.ZERO
	await frames(20)
	ok(vel_plano() < 0.05, "para em 1/3 s sem escorregar (%.2f)" % vel_plano())
	j.entrada["move"] = Vector2(0, 0.4)
	await frames(30)
	ok(absf(vel_plano() - Jogador.ANDAR * 0.4 / 0.55) < 0.25, "analógico pela metade = andar devagar (%.2f)" % vel_plano())
	j.entrada["move"] = Vector2(1, 0)
	j.camera.yaw = PI * 0.5
	await frames(30)
	ok(j.velocity.z < -3.0, "direção segue o giro da câmera (%.2f)" % j.velocity.z)


func _pulo() -> void:
	await poe(Vector3(30, 0.1, 30))
	var y0: float = j.global_position.y
	var topo: float = y0
	j.entrada["pular"] = true
	for i in 70:
		await physics_frame
		topo = maxf(topo, j.global_position.y)
	ok(topo - y0 > 1.15 and topo - y0 < 1.45, "pulo sobe ~1,3 m (%.2f)" % (topo - y0))
	ok(j.is_on_floor(), "volta ao chão")
	# buffer: apertar pular um pouco antes de pousar ainda pula
	j.entrada["pular"] = true
	for i in 40:
		await physics_frame
	j.global_position = Vector3(30, 0.6, 30)
	j.velocity = Vector3(0, -3, 0)
	await frames(2)
	j.entrada["pular"] = true
	var pulou: bool = false
	for i in 20:
		await physics_frame
		if j.velocity.y > 3.0:
			pulou = true
	ok(pulou, "aperto pouco antes de pousar vale (buffer)")
	# caixa de 1,0 m: alcança pulando correndo
	await poe(Vector3(-6, 0.1, -3.5), 0.0)
	j.entrada["move"] = Vector2(0, 1)
	await frames(20)
	j.entrada["pular"] = true
	var em_cima: bool = false
	for i in 60:
		await physics_frame
		em_cima = em_cima or (j.is_on_floor() and j.global_position.y > 0.9)
	ok(em_cima, "sobe na caixa de 1 m pulando")


func _agachar_tunel() -> void:
	await poe(Vector3(0, 0.1, 7.5), PI)  # yaw PI: frente é +Z, para dentro do túnel
	j.entrada["move"] = Vector2(0, 1)
	await frames(60)
	ok(j.global_position.z < 9.2, "em pé não entra no túnel de 1,4 m (z=%.2f)" % j.global_position.z)
	j.entrada["agachar"] = true
	await frames(90)
	ok(j.agachado and j.global_position.z > 10.0, "agachado entra (z=%.2f)" % j.global_position.z)
	ok(vel_plano() < Jogador.AGACHADO + 0.1, "agachado é lento (%.2f)" % vel_plano())
	j.entrada["move"] = Vector2.ZERO
	await frames(10)
	j.entrada["agachar"] = true
	await frames(5)
	ok(j.agachado, "não levanta debaixo do teto")
	j.entrada["pular"] = true
	await frames(5)
	ok(j.velocity.y < 1.0, "não pula debaixo do teto")


func _rampas() -> void:
	# rampa de 30° em x = 11 começa em z = -14 e sobe para -Z? não: sobe para +Z a partir de z = -14
	await poe(Vector3(11, 0.1, -16), PI)
	j.entrada["move"] = Vector2(0, 1)
	await frames(150)
	ok(j.global_position.y > 2.5, "sobe a rampa de 30° (y=%.2f)" % j.global_position.y)
	await poe(Vector3(16, 0.1, -16), PI)
	j.entrada["move"] = Vector2(0, 1)
	await frames(150)
	ok(j.global_position.y < 1.5, "não sobe a rampa de 50° andando (y=%.2f)" % j.global_position.y)
	# escada: de z -9 indo para -Z
	await poe(Vector3(-14, 0.1, -8.8), 0.0)
	j.entrada["move"] = Vector2(0, 1)
	var topo: float = 0.0
	var sempre_no_chao: bool = true
	for i in 60:
		await physics_frame
		topo = maxf(topo, j.global_position.y)
		sempre_no_chao = sempre_no_chao and j.is_on_floor()
	ok(topo > 1.4 and sempre_no_chao, "sobe a escada andando, sem pular (topo=%.2f)" % topo)


func _camera_parede() -> void:
	# de costas para o muro: a câmera tem que encurtar e não passar para o outro lado
	await poe(Vector3(13.5, 0.1, 8), PI * 0.5)  # entre os muros x=12 e x=15, olhando para -X
	await process_frame
	await frames(5)
	var cam_x: float = j.camera.cam.global_position.x
	ok(cam_x < 14.75 and cam_x > 12.25, "câmera fica entre os muros (x=%.2f)" % cam_x)
	j.entrada["olhar"] = Vector2(0, 400)
	await frames(5)
	ok(rad_to_deg(j.camera.pitch) <= CameraTerceira.PITCH_MAX + 0.01, "giro vertical tem limite (%.1f°)" % rad_to_deg(j.camera.pitch))


func _animacoes() -> void:
	await poe(Vector3(30, 0.1, 20))
	ok(j.clipe_atual() == "parado", "parado = parado (%s)" % j.clipe_atual())
	j.entrada["move"] = Vector2(0, 1)
	await frames(30)
	ok(j.clipe_atual() == "trote", "andando = trote (%s)" % j.clipe_atual())
	j.entrada["correr"] = true
	await frames(30)
	ok(j.clipe_atual() == "correr", "correndo = correr (%s)" % j.clipe_atual())
	j.entrada["correr"] = false
	j.entrada["pular"] = true
	await frames(4)
	ok(j.clipe_atual() in ["pulo_inicio", "no_ar"], "pulando = no ar (%s)" % j.clipe_atual())
	await frames(60)
	j.entrada["move"] = Vector2.ZERO
	j.entrada["agachar"] = true
	await frames(30)
	ok(j.clipe_atual() == "agachado", "agachado parado = agachado (%s)" % j.clipe_atual())
	var esq: Skeleton3D = j.modelo.find_children("*", "Skeleton3D", true, false)[0]
	var antes: Quaternion = esq.get_bone_pose_rotation(esq.find_bone("upperleg.l"))
	await frames(10)
	j.entrada["agachar"] = true
	j.entrada["move"] = Vector2(0, 1)
	await frames(20)
	ok(esq.get_bone_pose_rotation(esq.find_bone("upperleg.l")) != antes, "a animação mexe os ossos do modelo")


func _controle_no_ar() -> void:
	# pulando para a frente, empurra para o lado no meio do pulo: a direção muda antes de pousar
	await poe(Vector3(40, 0.1, 40), 0.0)
	j.entrada["move"] = Vector2(0, 1)
	await frames(20)
	j.entrada["pular"] = true
	await frames(8)
	ok(not j.is_on_floor(), "está no ar")
	j.entrada["move"] = Vector2(1, 0)
	await frames(15)
	ok(not j.is_on_floor() and j.velocity.x > 2.5, "muda de direção no meio do pulo (vx=%.2f)" % j.velocity.x)
	ok(absf(j.velocity.z) < 2.0, "a velocidade para a frente cai no ar (vz=%.2f)" % j.velocity.z)


func _mira_travada() -> void:
	await poe(Vector3(40, 0.1, 30), 0.0)
	j.entrada["mirar"] = true
	await frames(5)
	ok(j.mira_travada, "botão de mira liga a mira travada")
	j.entrada["move"] = Vector2(1, 0)  # anda para a direita
	await frames(40)
	ok(absf(wrapf(j.modelo.rotation.y - (j.camera.yaw + PI), -PI, PI)) < 0.15, "com a mira travada o corpo olha para a frente da câmera")
	ok(j.clipe_atual() in ["lado_esq", "lado_dir"], "andando de lado = animação de lado (%s)" % j.clipe_atual())
	j.entrada["move"] = Vector2(0, -1)
	await frames(30)
	ok(j.clipe_atual() == "tras", "andando de costas = animação de costas (%s)" % j.clipe_atual())
	j.entrada["correr"] = true
	await frames(10)
	ok(not j.correndo, "não corre com a mira travada")
	j.entrada["mirar"] = true
	await frames(5)
	ok(not j.mira_travada, "aperta de novo e destrava")
