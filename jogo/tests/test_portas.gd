# Testes da mecânica 12 (portas): abre/fecha com USAR, fechada segura o jogador, zumbi arromba e entra.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_portas.gd
extends SceneTree

var main: Node3D
var j: Jogador
var checks: int = 0
var falhas: int = 0


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


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
	var porta: Porta = main.get_node("Porta_0")
	j.global_position = Vector3(-20.0, 0.1, -2.0)
	await frames(10)
	ok(j.porta_perto() == porta and porta.acao() == "abrir porta", "na frente da porta: USAR abre")
	# fechada: andando para dentro, não passa
	j.camera.virar(PI * 0.5)  # câmera olhando para -X (para dentro da casa)
	j.entrada["move"] = Vector2(0, 1)
	await frames(90)
	ok(j.global_position.x > -21.0, "porta fechada segura o jogador (x=%.2f)" % j.global_position.x)
	j.entrada["move"] = Vector2.ZERO
	j.global_position = Vector3(-20.0, 0.1, -2.0)
	await frames(5)
	j.entrada["pegar"] = true
	await frames(40)
	ok(porta.aberta and porta.acao() == "fechar porta", "USAR abre a porta")
	j.entrada["move"] = Vector2(0, 1)
	await frames(90)
	ok(j.global_position.x < -22.0, "porta aberta deixa entrar (x=%.2f)" % j.global_position.x)
	j.entrada["move"] = Vector2.ZERO
	# lá dentro, fecha a porta e um zumbi vem: soca até arrombar e entra
	j.global_position = Vector3(-21.6, 0.1, -2.0)
	await frames(5)
	j.entrada["pegar"] = true
	await frames(40)
	ok(not porta.aberta, "fecha a porta por dentro")
	j.global_position = Vector3(-25.5, 0.1, -1.5)
	j.vida = 100000
	var z := Zumbi.new()
	z.position = Vector3(-16, 0, -2)
	main.zumbis.add_child(z)
	await frames(2)
	z._sem_gritar = INF
	z.alvo = j
	var socou: bool = false
	for i in 60 * 30:
		await physics_frame
		if porta.vida < Porta.VIDA_MAX:
			socou = true
		if porta.arrombada() and Vector2(z.global_position.x - j.global_position.x, z.global_position.z - j.global_position.z).length() < 2.0:
			break
	ok(socou, "o zumbi soca a porta fechada")
	ok(porta.arrombada() and porta.aberta, "arromba a porta (vida %d)" % porta.vida)
	ok(Vector2(z.global_position.x - j.global_position.x, z.global_position.z - j.global_position.z).length() < 2.0, "entra e chega no jogador")
	ok(j.porta_perto() == null or j.porta_perto() != porta, "porta arrombada não fecha")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
