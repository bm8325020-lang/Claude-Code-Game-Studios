extends SceneTree
func _init() -> void:
	var tira: String = OS.get_environment("TIRA")
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.iniciar_solo("Peso")
	for i in 400: await process_frame
	match tira:
		"gavetas":
			for n in root.find_children("*", "", true, false):
				if n is Gaveta: n.queue_free()
		"zumbis":
			for z in main.zumbis.get_children(): z.queue_free()
		"sinc":
			for n in root.find_children("*", "MultiplayerSynchronizer", true, false): n.queue_free()
		"bairro":
			main.bairro.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 60: await process_frame
	var p := 0.0
	var f := 0.0
	for i in 600:
		await process_frame
		p += Performance.get_monitor(Performance.TIME_PROCESS)
		f += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("PESO tira=%s process=%.2f ms fisica=%.2f ms" % [tira, p / 600 * 1000.0, f / 600 * 1000.0])
	quit()
