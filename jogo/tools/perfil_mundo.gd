# Quanto custa por quadro cada sistema do jogo (12/11): chama o _process/_physics_process de cada nó com script e soma
# por arquivo. Mostra os mais caros.   DD_COM_TELA=1 DD_QUALIDADE=1 godot --headless --path . -s res://tools/perfil_mundo.gd
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("PerfM")
	for i in 240: await process_frame
	var soma: Dictionary = {}  # "arquivo:metodo" -> [us por quadro, nós]
	for n: Node in [main] + main.find_children("*", "", true, false):
		if n.get_script() == null or n is Zumbi:
			continue
		var arq: String = (n.get_script() as Script).resource_path.get_file()
		for par: Array in [["_process", n.is_processing()], ["_physics_process", n.is_physics_processing()]]:
			if not par[1] or not n.has_method(par[0]):
				continue
			var t0: int = Time.get_ticks_usec()
			for k in 30:
				n.call(par[0], 1.0 / 60.0)
			var us: float = (Time.get_ticks_usec() - t0) / 30.0
			var ch: String = arq + ":" + String(par[0])
			if not soma.has(ch):
				soma[ch] = [0.0, 0]
			soma[ch][0] += us
			soma[ch][1] += 1
	var chaves: Array = soma.keys()
	chaves.sort_custom(func(a: String, b: String) -> bool: return soma[a][0] > soma[b][0])
	var total: float = 0.0
	for ch: String in chaves:
		total += soma[ch][0]
	print("PERFM total dos scripts (sem zumbi): %.0f us por quadro" % total)
	for ch: String in chaves.slice(0, 14):
		print("PERFM %7.0f us  %s (%d nós)" % [soma[ch][0], ch, soma[ch][1]])
	quit()
