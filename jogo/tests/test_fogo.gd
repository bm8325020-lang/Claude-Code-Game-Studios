# Fogo (plano do dono, 30/10): barris e casas queimadas têm fogo; quem fica dentro dele se queima.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_fogo.gd
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
	for z in main.zumbis.get_children():
		z.free()
	var fogos: Array = main.bairro.find_children("*", "Fogo", false, false)
	ok(fogos.any(func(f: Fogo) -> bool: return not f.coluna) and fogos.any(func(f: Fogo) -> bool: return f.coluna), "fogo nos barris e nas casas queimadas (%d)" % fogos.size())
	var f := Fogo.new()
	f.tamanho = 0.8
	f.position = Vector3(50, 0, 50)
	main.add_child(f)
	j.global_position = Vector3(50, 0.1, 50)
	j.vida = 100
	await frames(70)
	ok(j.vida < 100, "dentro do fogo se queima (vida %d)" % j.vida)
	j.global_position = Vector3(55, 0.1, 50)
	var v: int = j.vida
	await frames(70)
	ok(j.vida == v, "fora do fogo não")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
