# Telhados dos sobrados (05/11, engenharia reversa Dying Light 2): escada de metal nos fundos sobe até o patamar; do
# patamar o jogador agarra a mureta e fica em pé no teto; tetos vizinhos têm tábua.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_escada_telhado.gd
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


func anda(j: Jogador, dir: Vector3, s: float) -> float:
	j.camera.virar(atan2(-dir.x, -dir.z), 0.0)
	j.entrada["move"] = Vector2(0, 1)
	var alto: float = -INF
	for i in int(60 * s):
		await physics_frame
		alto = maxf(alto, j.global_position.y)
	j.entrada["move"] = Vector2.ZERO
	return alto


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	for z in main.zumbis.get_children():
		z.free()
	main.ciclo.set_process(false)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	j._jogo_t = Jogador.NOVATO_T
	var b: Bairro = main.bairro
	var escadas: Array = b.find_children("EscadaFundos", "StaticBody3D", true, false)
	ok(escadas.size() >= 10 and b.find_children("TabuaTeto_*", "", false, false).size() >= 10, "escadas (%d) e tábuas nos tetos" % escadas.size())
	var esc: StaticBody3D = escadas[0]
	var m: Node3D = esc.get_parent()
	var no: Node3D = m.get_parent()
	var tam: Vector2 = b._tam_ruina(String(no.get_meta("modelo")))
	var hw: float = tam.x * 0.5
	var hd: float = tam.y * 0.5
	var teto: float = float(no.get_meta("teto")) + no.position.y
	var x_local: Vector3 = m.global_basis * Vector3.RIGHT
	j.global_position = m.to_global(Vector3(-hw + 0.1, 0.1, -hd - 0.75))
	j.velocity = Vector3.ZERO
	await frames(10)
	var alto: float = await anda(j, x_local, 3.0)
	ok(alto > 2.0, "sobe o primeiro lance da escada (chegou a %.1f m)" % alto)
	# do patamar de cima, de frente para a parede dos fundos: agarra a mureta e fica no teto
	var n: int = maxi(1, roundi((teto - no.position.y - 0.7) / Bairro.PAREDE))
	var x_pat: float = (-hw + 5.2 + 0.55) if n % 2 == 1 else (-hw + 0.6 - 0.55)
	j.global_position = m.to_global(Vector3(x_pat, teto - no.position.y - 0.7 + 0.2, -hd - 0.4))
	j.velocity = Vector3.ZERO
	await frames(5)
	await anda(j, m.global_basis * Vector3.BACK, 3.0)
	await frames(20)
	ok(j.is_on_floor() and j.global_position.y > teto - 0.8, "do patamar sobe no teto (pés a %.1f, teto %.1f)" % [j.global_position.y, teto - 0.6])
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
