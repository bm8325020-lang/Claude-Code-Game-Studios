# Mede o peso do mundo no processador (campanha anti-travamento): nós, corpos físicos, scripts com _process e tempo
# de process/física por quadro com o jogo rodando na cidade.
#   timeout 400 $G --headless --path . --fixed-fps 60 -s res://tools/peso_cpu.gd
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Peso")
	await process_frame
	main.jogador.vida = 1000000000  # morrer e renascer no meio da medição bagunça os números
	for i in int(OS.get_environment("ESPERA") if OS.get_environment("ESPERA") != "" else "900"): await process_frame  # carregamento assentar
	var por_script := {}
	var corpos := 0
	var total := 0
	for n in root.find_children("*", "", true, false):
		total += 1
		if n is CollisionObject3D:
			corpos += 1
		if n.get_script() and (n.is_processing() or n.is_physics_processing()):
			var k: String = (n.get_script() as Script).resource_path.get_file()
			por_script[k] = por_script.get(k, 0) + 1
	print("PESO nós=", total, " corpos=", corpos)
	var internos := {}
	for n in root.find_children("*", "", true, false):
		if n.is_processing_internal() or n.is_physics_processing_internal():
			internos[n.get_class()] = internos.get(n.get_class(), 0) + 1
	var ik := internos.keys(); ik.sort_custom(func(a, b): return internos[a] > internos[b])
	for k in ik.slice(0, 12): print("PESO interno: ", k, " ", internos[k])
	var ks := por_script.keys(); ks.sort_custom(func(a, b): return por_script[a] > por_script[b])
	for k in ks.slice(0, 15): print("PESO scripts com process: ", k, " ", por_script[k])
	# DESLIGA=a.gd,b.gd: desliga o process desses scripts para ver quanto cada um pesa
	for nome in OS.get_environment("DESLIGA").split(",", false):
		for n in root.find_children("*", "", true, false):
			if n.get_script() and (n.get_script() as Script).resource_path.get_file() == nome:
				n.set_process(false)
	var tudo: String = OS.get_environment("DESLIGA_TUDO")  # 1 = tudo, scripts = só scripts, interno = só o motor
	if tudo != "":
		for n in root.find_children("*", "", true, false):
			if tudo != "interno":
				n.set_process(false)
				n.set_physics_process(false)
			if tudo != "scripts":
				n.set_process_internal(false)
				n.set_physics_process_internal(false)
	print("PESO tweens=", get_processed_tweens().size())
	for cl in OS.get_environment("DESLIGA_CLASSE").split(",", false):
		for n in root.find_children("*", cl, true, false):
			n.set_process_internal(false)
			n.set_physics_process_internal(false)
	var p := 0.0
	var f := 0.0
	var pior := 0.0
	var parede := Time.get_ticks_usec()
	for i in 300:
		await process_frame
		pior = maxf(pior, Performance.get_monitor(Performance.TIME_PROCESS))
		p += Performance.get_monitor(Performance.TIME_PROCESS)
		f += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("PESO parede ms por quadro: %.2f" % ((Time.get_ticks_usec() - parede) / 300000.0))
	print("PESO ms por quadro: process=%.2f (pior %.1f) fisica=%.2f" % [p / 300.0 * 1000.0, pior * 1000.0, f / 300.0 * 1000.0])
	# CUSTO: chama _process/_physics_process de cada script à mão (com o motor parado neles) e cronometra
	var custo := {}
	var nos := root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and (n.is_processing() or n.is_physics_processing()))
	for n: Node in nos:
		n.set_process(false)
		n.set_physics_process(false)
	for r in 30:
		for n: Node in nos:
			if not is_instance_valid(n):
				continue
			var k: String = (n.get_script() as Script).resource_path.get_file()
			var t0 := Time.get_ticks_usec()
			if n.has_method("_process"):
				n._process(1.0 / 60.0)
			var t1 := Time.get_ticks_usec()
			if n.has_method("_physics_process"):
				n._physics_process(1.0 / 60.0)
			var t2 := Time.get_ticks_usec()
			var c: Vector2 = custo.get(k, Vector2.ZERO)
			custo[k] = c + Vector2(t1 - t0, t2 - t1)
		await process_frame
	var ck := custo.keys(); ck.sort_custom(func(a, b): return custo[a].x + custo[a].y > custo[b].x + custo[b].y)
	for k in ck.slice(0, 12):
		print("PESO custo %s: process=%.2f ms fisica=%.2f ms por quadro" % [k, custo[k].x / 30000.0, custo[k].y / 30000.0])
	var acord := 0
	for z: Zumbi in main.zumbis.get_children():
		acord += int(not z._dormindo)
	print("PESO zumbis acordados=", acord)
	print("PESO zumbis=", main.zumbis.get_child_count(), " objetos=", Performance.get_monitor(Performance.OBJECT_COUNT))
	quit()
