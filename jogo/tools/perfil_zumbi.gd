# Quanto custa um zumbi acordado (12/11): 20 perseguindo o jogador na cidade; média do quadro e de cada pedaço da IA.
#   DD_COM_TELA=1 DD_QUALIDADE=1 godot --headless --path . --fixed-fps 60 -s res://tools/perfil_zumbi.gd
extends SceneTree


func _mede(nome: String, f: Callable, n: int = 300) -> void:
	var t0: int = Time.get_ticks_usec()
	for k in n:
		f.call()
	print("PERFZ %7.1f us  %s" % [(Time.get_ticks_usec() - t0) / float(n), nome])


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("PerfZ")
	for i in 200: await process_frame
	var j: Jogador = main.jogador
	j.vida = 100000000
	main.controles.jogador = null
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var mapa: RID = root.get_world_3d().navigation_map
	var zs: Array = []
	for k in 20:
		var a: float = TAU * k / 20.0
		var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, j.global_position + Vector3(cos(a), 0, sin(a)) * 45.0)
		var z: Zumbi = main.spawner_zumbis.spawn({"pos": p + Vector3(0, 0.1, 0), "horda": Zumbi.DO_MORTO})
		z.alvo = j
		z.luta = true
		zs.append(z)
	for i in 30: await physics_frame
	var fis: Array = []
	var pro: Array = []
	var rel: Array = []
	var antes: int = Time.get_ticks_usec()
	for i in 240:
		await process_frame
		j.vida = 100000000
		fis.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		pro.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		rel.append((Time.get_ticks_usec() - antes) / 1000.0)
		antes = Time.get_ticks_usec()
	var d0: float = (zs[0] as Zumbi).global_position.distance_to(j.global_position)
	for par: Array in [["física", fis], ["processo", pro], ["relógio", rel]]:
		var v: Array = (par[1] as Array).duplicate()
		v.sort()
		print("PERFZ 20 zumbis perseguindo, %s: mediana %.2f ms, p95 %.2f, pior %.2f" % [par[0], v[120], v[228], v[239]])
	print("PERFZ zumbi 0 a %.0f m do jogador" % d0)
	var z0: Zumbi = zs[0]
	var alvo_p: Vector3 = j.global_position
	_mede("_physics_process inteiro", func() -> void: z0._physics_process(1.0 / 60.0))
	_mede("_process (animação)", func() -> void: z0._process(1.0 / 60.0))
	_mede("move_and_slide", func() -> void: z0.move_and_slide())
	_mede("_caminho", func() -> void: z0._caminho(alvo_p, 2.0, 1.0 / 60.0))
	_mede("_escolhe_alvo", func() -> void: z0._escolhe_alvo())
	_mede("_calcula_cerco", func() -> void: z0._calcula_cerco())
	_mede("_porta_na_frente", func() -> void: z0._porta_na_frente(Vector3.FORWARD))
	_mede("_publica", func() -> void: z0._publica())
	_mede("_toca", func() -> void: z0._toca("andar", 0.25))
	_mede("_ve (raio)", func() -> void:
		z0._ve_quadro = -100
		z0._ve(j))
	_mede("anim.advance", func() -> void: z0.anim.advance(1.0 / 60.0))
	_mede("espreitando", func() -> void: j.espreitando())
	quit()
