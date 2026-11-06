# Peso da horda (anti-travamento 08/11, dono: "quando vem horda, ou até 4 zumbis, trava muito"): N zumbis perseguindo o
# jogador num ponto aberto da cidade. Mede o relógio de parede por quadro (process + física; o TIME_PROCESS mente no
# headless) e, com tela, as chamadas de desenho e triângulos com os zumbis na frente da câmera (qualidade Média).
#   CPU:   timeout 600 $G --headless --path . --fixed-fps 60 -s res://tools/peso_horda.gd -- [N=40]
#   Tela:  timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 --fixed-fps 60 \
#            -s res://tools/peso_horda.gd -- [N] [qualidade=1]
extends SceneTree

const PONTO: Vector3 = Vector3(-12, 0.3, 300)  # rua aberta (relativo ao Bairro.ORIGEM)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 40
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	Config.v.qualidade = int(args[1]) if args.size() > 1 else 1
	main.iniciar_solo("Peso")
	for i in 30: await process_frame
	Config.aplica(self)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	j.vida = 1000000000
	j._jogo_t = Jogador.NOVATO_T
	main.ciclo.set_process(false)
	main.ciclo.tempo = 100.0  # dia
	main.ciclo._process(0.0)
	main.populacao._t = INF  # só os zumbis desta medida
	main.horda._t = INF
	for z in main.zumbis.get_children():
		z.free()
	var q := Vector2(PONTO.x, PONTO.z)
	j.global_position = Bairro.ORIGEM + Vector3(q.x, main.bairro.altura(q) + PONTO.y, q.y)
	j.velocity = Vector3.ZERO
	var mapa: RID = main.get_world_3d().navigation_map
	for i in 400:  # a malha da cidade carrega numa thread (tempo de verdade)
		var t: Vector3 = j.global_position + Vector3(30, 0, 0)
		if NavigationServer3D.map_get_closest_point(mapa, t).distance_to(t) < 8.0:
			break
		OS.delay_msec(50)
		await process_frame
	if OS.get_environment("CAMINHO") != "":  # CAMINHO=1: custo de um pedido de caminho e do ponto mais perto na malha
		for dist in [5.0, 30.0]:
			var tq := Time.get_ticks_usec()
			var alvo_c: Vector3 = NavigationServer3D.map_get_closest_point(mapa, j.global_position + Vector3(dist, 0, dist * 0.3))
			print("HORDA ponto mais perto: %.2f ms" % ((Time.get_ticks_usec() - tq) / 1000.0))
			tq = Time.get_ticks_usec()
			var cam := NavigationServer3D.map_get_path(mapa, j.global_position, alvo_c, true)
			print("HORDA caminho %.0f m: %.2f ms, %d pontos" % [dist, (Time.get_ticks_usec() - tq) / 1000.0, cam.size()])
	# os zumbis numa meia-volta na frente da câmera (a tela conta os que se vê), já atrás do jogador
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var frente: Vector3 = -j.global_basis.z
	var pos: Array[Vector3] = []
	for k in n:
		var a: float = atan2(frente.x, frente.z) + rng.randf_range(-1.2, 1.2)
		var p: Vector3 = j.global_position + Vector3(sin(a), 0, cos(a)) * rng.randf_range(15.0, 40.0)
		pos.append(NavigationServer3D.map_get_closest_point(mapa, p) + Vector3(0, 0.1, 0))
	var ts := Time.get_ticks_usec()
	for p in pos:
		main.spawner_zumbis.spawn({"pos": p})
	print("HORDA criar %d zumbis: %.1f ms (%.2f ms cada)" % [n, (Time.get_ticks_usec() - ts) / 1000.0, (Time.get_ticks_usec() - ts) / 1000.0 / maxf(n, 1)])
	await process_frame
	for z: Zumbi in main.zumbis.get_children():
		z.alvo = j
		z._sem_gritar = 99.0
	for i in 30: await process_frame
	var chamadas := Vector3.ZERO
	var amostras: int = 0
	var tempos: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var quadros: int = 600 if DisplayServer.get_name() == "headless" else 120  # 10 s de jogo (com tela, o xvfb é lento)
	for i in quadros:
		var a := Time.get_ticks_usec()
		await process_frame
		tempos.append((Time.get_ticks_usec() - a) / 1000.0)
		if i % 20 == 10:
			chamadas += Vector3(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			amostras += 1
	tempos.sort()
	var perto: int = 0
	var vivos: int = 0
	for z: Zumbi in main.zumbis.get_children():
		vivos += int(z.vida > 0)
		perto += int(z.global_position.distance_to(j.global_position) < 6.0)
	var perf = (Zumbi as Script).get("PERF")  # medidas por parte, se o zumbi.gd estiver instrumentado
	if perf is Dictionary:
		for k in perf: print("HORDA perf %s %.2f ms/quadro" % [k, perf[k] / 1000.0 / (quadros + 30)])
	print("HORDA n=%d vivos=%d colados=%d" % [n, vivos, perto])
	print("HORDA parede ms por quadro: %.2f (mediana %.2f, pior 5%% %.2f)" % [(Time.get_ticks_usec() - t0) / 1000.0 / quadros,
		tempos[quadros / 2], tempos[quadros * 95 / 100]])
	chamadas /= maxf(amostras, 1)
	print("HORDA desenho: %d chamadas, %d objetos, %d triângulos" % [chamadas.x, chamadas.y, chamadas.z])
	quit()
