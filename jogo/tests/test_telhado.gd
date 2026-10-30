# Telhados ligados (plano do dono, 30/10): a escada de incêndio no fundo da loja leva até o teto; tábuas ligam tetos
# vizinhos da mesma altura e dá para ficar em pé nelas.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_telhado.gd
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
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var b: Bairro = main.bairro
	var tabuas: Array = b.find_children("TabuaTeto_*", "StaticBody3D", false, false)
	ok(tabuas.size() >= 3, "tábuas ligando tetos (%d)" % tabuas.size())
	if not tabuas.is_empty():
		var t: Node3D = tabuas[0]
		j.global_position = t.global_position + Vector3(0, 0.3, 0)
		j.velocity = Vector3.ZERO
		await frames(40)
		ok(j.is_on_floor() and j.global_position.y > t.global_position.y - 0.1, "fica em pé na tábua (y %.1f)" % j.global_position.y)
	# sobe a escada de incêndio de uma loja de 1 andar: pé da escada no fundo, andando ao longo dela
	var loja: Node3D = b.get_children().filter(func(n: Node) -> bool: return n.get_meta("modelo", "") == "loja_r1")[0]
	var m: Node3D = loja.get_child(0)
	var hw: float = b._tam_ruina("loja_r1").x * 0.5
	var hd: float = b._tam_ruina("loja_r1").y * 0.5
	# Blender (x, y) -> Godot (x, -y): o fundo (y > hd) fica em z < -hd
	var pe: Vector3 = b.global_transform * (m.transform * Vector3(-hw + 0.2, 0.1, -(hd + 0.75)))
	var dir: Vector3 = (m.global_basis * Vector3.RIGHT).normalized()
	j.global_position = pe
	j.velocity = Vector3.ZERO
	j.camera.virar(atan2(-dir.x, -dir.z))
	await frames(10)
	j.entrada["move"] = Vector2(0, 1)
	var alto: float = -INF
	for i in 60 * 4:
		await physics_frame
		alto = maxf(alto, j.global_position.y)
	j.entrada["move"] = Vector2.ZERO
	ok(alto > 2.6, "sobe a escada de incêndio até o teto (chegou a %.1f m)" % alto)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
