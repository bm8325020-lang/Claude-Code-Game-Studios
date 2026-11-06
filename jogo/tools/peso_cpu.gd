# Mede o peso do mundo no processador (campanha anti-travamento): nós, corpos físicos, scripts com _process e tempo
# de process/física por quadro com o jogo rodando na cidade.
#   timeout 400 $G --headless --path . --fixed-fps 60 -s res://tools/peso_cpu.gd
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Peso")
	for i in 120: await process_frame
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
	var ks := por_script.keys(); ks.sort_custom(func(a, b): return por_script[a] > por_script[b])
	for k in ks.slice(0, 15): print("PESO scripts com process: ", k, " ", por_script[k])
	var p := 0.0
	var f := 0.0
	for i in 120:
		await process_frame
		p += Performance.get_monitor(Performance.TIME_PROCESS)
		f += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("PESO ms por quadro: process=%.2f fisica=%.2f" % [p / 120.0 * 1000.0, f / 120.0 * 1000.0])
	print("PESO zumbis=", main.zumbis.get_child_count(), " objetos=", Performance.get_monitor(Performance.OBJECT_COUNT))
	quit()
