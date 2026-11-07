# Molotov (07/11): o fogo queima o zumbi perto e não o longe.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_molotov.gd
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("TesteMolotov")
	for i in 10: await physics_frame
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var perto := Zumbi.new()
	var longe := Zumbi.new()
	main.zumbis.add_child(perto)
	main.zumbis.add_child(longe)
	for i in 3: await physics_frame
	perto.global_position = Vector3(30, 0, -18)
	longe.global_position = Vector3(40, 0, -18)
	perto.set_physics_process(false)
	longe.set_physics_process(false)
	var v0: int = perto.vida
	var mo := Molotov.new()
	main.add_child(mo)
	mo.global_position = Vector3(30.5, 0, -18)
	for i in 90: await process_frame
	var ok1: bool = perto.vida < v0
	var ok2: bool = longe.vida == longe._vida_max
	print("MOLOTOV: %s (perto %d -> %d, longe %d)" % ["PASS" if ok1 and ok2 else "FAIL", v0, perto.vida, longe.vida])
	quit(0 if ok1 and ok2 else 1)
