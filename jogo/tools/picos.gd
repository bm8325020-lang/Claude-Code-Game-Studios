# Caça pico de lag (12/11, dono: "do nada dá um pico de lag, uma queda de fps muito alta"): joga de verdade (anda pela
# cidade pelas rotas da malha, com a tela e o HUD ligados) e mede o tempo de relógio de cada quadro. No fim mostra a
# mediana e os piores quadros com o que mudou neles (zumbis que nasceram, nós e recursos criados).
#   DD_COM_TELA=1 DD_QUALIDADE=1 godot --headless --path . --fixed-fps 60 -s res://tools/picos.gd -- [segundos de jogo]
# (sem janela: mede CPU — scripts, física, animação; com xvfb o desenho por software esconde tudo)
extends SceneTree

var main: Node3D
var j: Jogador


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var dura: float = float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 120.0
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Picos")
	await frames(240)
	j = main.jogador
	j.vida = 1000000
	if "semz" in OS.get_cmdline_user_args():  # custo do mundo sem zumbi nenhum (para comparar)
		for z in main.zumbis.get_children():
			z.free()
	if "semmini" in OS.get_cmdline_user_args():
		main.controles._mini.visible = false
	if "tiramini" in OS.get_cmdline_user_args():
		main.controles._mini.get_parent().remove_child(main.controles._mini)
	if "tiratarefas" in OS.get_cmdline_user_args():
		main.controles._tarefas.get_parent().remove_child(main.controles._tarefas)
	if "semhud" in OS.get_cmdline_user_args():
		main.controles.visible = false
		main.controles.process_mode = Node.PROCESS_MODE_DISABLED
	var mapa: RID = root.get_world_3d().navigation_map
	var quadros: Array = []  # [ms, t de jogo, zumbis, nós, recursos, processo ms, física ms]
	var cam: PackedVector3Array = []
	var i_cam: int = 0
	var t_jogo: float = 0.0
	var antes: int = Time.get_ticks_usec()
	Input.action_press("frente")
	while t_jogo < dura:
		if i_cam >= cam.size():
			var ate: Vector3 = NavigationServer3D.map_get_closest_point(mapa, j.global_position + Vector3(randf_range(-90, 90), 0, randf_range(-90, 90)))
			cam = NavigationServer3D.map_get_path(mapa, j.global_position, ate, true)
			i_cam = 1
		if i_cam < cam.size():
			var d: Vector3 = cam[i_cam] - j.global_position
			d.y = 0.0
			if d.length() < 0.8:
				i_cam += 1
			elif j.camera:
				j.camera.virar(atan2(-d.x, -d.z), 0.0)
		j.vida = 1000000
		antes = Time.get_ticks_usec()  # o tempo do próprio robô (rota) não entra na conta
		await process_frame
		var agora: int = Time.get_ticks_usec()
		quadros.append([(agora - antes) / 1000.0, t_jogo, main.zumbis.get_child_count(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		t_jogo += 1.0 / 60.0
	Input.action_release("frente")
	var ms: Array = quadros.map(func(q: Array) -> float: return q[0])
	ms.sort()
	var med: float = ms[ms.size() / 2]
	var limite: float = med * 2.5
	var picos: Array = []
	for k in range(1, quadros.size()):
		if quadros[k][0] > limite:
			picos.append(k)
	print("PICOS: %d quadros; mediana %.1f ms; p95 %.1f; p99 %.1f; pior %.1f; acima de %.0f ms: %d (%.2f%%)" % [quadros.size(), med,
		ms[int(ms.size() * 0.95)], ms[int(ms.size() * 0.99)], ms[-1], limite, picos.size(), 100.0 * picos.size() / quadros.size()])
	picos.sort_custom(func(a: int, b: int) -> bool: return quadros[a][0] > quadros[b][0])
	for k: int in picos.slice(0, 30):
		var q: Array = quadros[k]
		var p: Array = quadros[k - 1]
		print("  %.0f ms em t=%.1f s | zumbis %+d (%d) | nós %+d | recursos %+d | processo %.1f | física %.1f" % [q[0], q[1], q[2] - p[2], q[2],
			q[3] - p[3], q[4] - p[4], q[5], q[6]])
	quit()
