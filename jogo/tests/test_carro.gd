# Carro (prompt 18, primeira parte; 31/10): perto do carro o USAR entra; o analógico acelera, vira e dá ré;
# o carro bate em parede e para; USAR sai do lado, com o corpo de volta.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_carro.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0
var main: Node3D
var j: Jogador


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var carros: Array[Node] = get_nodes_in_group("carros")
	ok(carros.size() >= 5, "a cidade tem carros para dirigir (%d)" % carros.size())
	var c: Carro = carros[0]
	# pátio aberto: carro olhando para +X, parede 25 m à frente
	c.global_position = Vector3(60, 0, 80)
	c.rotation.y = PI * 0.5
	c.pos_rede = c.position
	c.rot_rede = c.rotation.y
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1, 4, 12)
	cs.shape = bx
	parede.add_child(cs)
	parede.position = Vector3(85, 2, 80)
	main.add_child(parede)
	j.global_position = Vector3(60, 0.1, 82.2)
	j.velocity = Vector3.ZERO
	await frames(10)
	ok(j.carro_perto() == c, "o carro aparece como perto")
	j.entrada["pegar"] = true
	await frames(3)
	ok(j.carro == c and c.motorista == main.multiplayer.get_unique_id() and j.no_carro, "USAR entra no carro")
	ok(j._colisor.disabled, "sentado o corpo não colide")
	await frames(30)
	ok(absf(c.global_position.y) < 0.15, "as rodas seguram o carro no chão (y %.2f)" % c.global_position.y)
	j.entrada["move"] = Vector2(0, 1)
	await frames(60 * 2)
	ok(c.global_position.x > 66.0 and absf(c.global_position.z - 80.0) < 1.0, "acelera para a frente (x %.1f)" % c.global_position.x)
	ok(j.global_position.distance_to(c.global_transform * Carro.BANCO) < 0.05, "o jogador vai junto no banco")
	j.entrada["move"] = Vector2(0, 1)
	await frames(60 * 3)
	ok(c.global_position.x < 84.0 and absf(c.vel) < 2.0, "bate na parede e para (x %.1f, vel %.1f)" % [c.global_position.x, c.vel])
	j.entrada["move"] = Vector2(0, -1)
	await frames(60 * 2)
	ok(c.vel < -1.0, "trás dá ré (vel %.1f)" % c.vel)
	var r0: float = c.rotation.y
	var yaw0: float = j.camera.yaw
	j.entrada["move"] = Vector2(1, 1)
	await frames(60)
	ok(absf(angle_difference(r0, c.rotation.y)) > 0.3, "o volante vira o carro")
	ok(absf(angle_difference(yaw0, j.camera.yaw)) > 0.25, "a câmera vira junto")
	j.entrada["move"] = Vector2.ZERO
	await frames(90)
	j.entrada["pegar"] = true
	await frames(3)
	ok(j.carro == null and c.motorista == 0 and not j.no_carro and not j._colisor.disabled, "USAR sai do carro")
	ok(j.global_position.distance_to(c.global_position) < 3.5 and j.global_position.distance_to(c.global_position) > 1.0, "desce do lado do carro")
	var p0: Vector3 = c.global_position
	await frames(30)
	ok(c.global_position.distance_to(p0) < 0.2, "vazio o carro fica parado onde ficou")
	print("CARRO: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
