# Degrau (07/11 e 12/11): meio-fio/varanda de até 0,5 m sobe andando; beirada de 0,8 m não (precisa pular).
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_degrau.gd
extends SceneTree


func _caixa(main: Node3D, pos: Vector3, tam: Vector3) -> void:
	var c := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	cs.shape = b
	c.add_child(cs)
	main.add_child(c)
	c.global_position = pos + Vector3(0, tam.y * 0.5, 0)


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("TesteDegrau")
	for i in 10: await physics_frame
	var j: Jogador = main.jogador
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	var res: Array = []
	for alt: float in [0.4, 0.8]:
		var base := Vector3(60, 0, 60 + alt * 20)
		_caixa(main, base + Vector3(0, 0, -3), Vector3(4, alt, 3))
		j.global_position = base + Vector3(0, 0.1, 0)
		j.velocity = Vector3.ZERO
		for i in 20: await physics_frame
		var y0: float = j.global_position.y
		j.camera.virar(0.0, 0.0)  # olha para -Z
		j.entrada["move"] = Vector2(0, 1)
		var alto: float = 0.0
		for i in 90:
			await physics_frame
			alto = maxf(alto, j.global_position.y - y0)
		j.entrada["move"] = Vector2.ZERO
		res.append(alto)
	var ok: bool = res[0] > 0.3 and res[1] < 0.2
	print("DEGRAU: %s (0,4 m subiu %.2f; 0,8 m subiu %.2f)" % ["PASS" if ok else "FAIL", res[0], res[1]])
	quit(0 if ok else 1)
