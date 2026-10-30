# Fresta (pedido do dono, 30/10): andando para a boca do vão estreito, entra de lado e afina; o analógico para o
# lado leva pelo comprido até sair do outro lado com o corpo normal; o zumbi não cabe e fica de fora.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_fresta.gd
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
	# fresta de 8 m ao longo de +X, em (60, 60) do mundo (o Bairro está em ORIGEM)
	var b: Bairro = main.bairro
	var a := Vector2(56, 60) - Vector2(Bairro.ORIGEM.x, Bairro.ORIGEM.z)
	b._fresta(a, a + Vector2(8, 0), 0.55)
	await frames(2)
	j.global_position = Vector3(54.5, 0.05, 60)
	j.velocity = Vector3.ZERO
	j.camera.virar(-PI * 0.5)  # olhando para +X (frente = (-sin, -cos))
	await frames(10)
	j.entrada["move"] = Vector2(0, 1)
	for i in 60:
		await physics_frame
		if j.fresta:
			break
	ok(j.fresta != null, "andando para a boca entra na fresta")
	ok(is_equal_approx(j._forma.radius, Jogador.ESGUEIRA_RAIO), "corpo afina para caber")
	j.entrada["move"] = Vector2.ZERO
	await frames(30)
	ok(absf(angle_difference(j.camera.yaw, j.yaw_fresta)) < 1.0, "fica de frente para a parede")
	# o analógico para o lado que leva para dentro (+X)
	var direita := Vector3(cos(j.yaw_fresta), 0, -sin(j.yaw_fresta))
	j.entrada["move"] = Vector2(signf(direita.x), 0)
	var x0: float = j.global_position.x
	await frames(60 * 4)
	ok(j.global_position.x > x0 + 2.5 and absf(j.global_position.z - 60.0) < 0.15, "anda de lado pelo comprido (%.1f -> %.1f)" % [x0, j.global_position.x])
	await frames(60 * 8)
	ok(j.fresta == null and j.global_position.x > 63.5, "sai do outro lado (x %.1f)" % j.global_position.x)
	ok(is_equal_approx(j._forma.radius, Jogador.RAIO), "e volta ao corpo normal")
	j.entrada["move"] = Vector2.ZERO
	# zumbi atrás do jogador do outro lado: não passa pela fresta
	j.global_position = Vector3(66, 0.05, 60)
	j.vida = 100000
	var z := Zumbi.new()
	z.position = Vector3(53, 0, 60)
	z.casa = z.position
	main.zumbis.add_child(z)
	await frames(2)
	z.alvo = j
	await frames(60 * 6)
	ok(z.global_position.x < 56.5, "o zumbi não cabe na fresta (x %.1f)" % z.global_position.x)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
