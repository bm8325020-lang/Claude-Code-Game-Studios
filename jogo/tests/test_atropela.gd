# Carro (dono 07/11): atropela zumbi na frente acima de Carro.ATROPELA_VEL; dentro do carro o zumbi não machuca.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_atropela.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(10)
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	var c: Carro = main.bairro.get_node("CarroEntrada")
	var z := Zumbi.new()
	z.tipo_fixo = "zumbi_policial"
	z.position = c.global_position + c.global_basis.z * 2.6 + Vector3(0, 0.1, 0)
	z.casa = z.position
	main.zumbis.add_child(z)
	await frames(3)
	z.set_physics_process(false)
	c.motorista = main.multiplayer.get_unique_id()
	c.vel = 9.0
	for i in 10:
		c.dirige(Vector2(0, 1), 1.0 / 60.0)
		await physics_frame
	ok(z.vida < z._vida_max, "carro a 9 m/s atropela o zumbi da frente (vida %d)" % z.vida)
	c.motorista = 0
	# dentro do carro o zumbi não machuca
	var j: Jogador = main.jogador
	j.vida = 100
	j.no_carro = true
	var z2 := Zumbi.new()
	z2.tipo_fixo = "zumbi_policial"
	z2.position = j.global_position + Vector3(0.8, 0.1, 0)
	z2.casa = z2.position
	main.zumbis.add_child(z2)
	await frames(3)
	z2.alvo = j
	await frames(60 * 4)
	ok(j.vida == 100, "dentro do carro o zumbi não tira vida (vida %d)" % j.vida)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
