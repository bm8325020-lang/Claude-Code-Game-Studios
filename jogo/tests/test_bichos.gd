# Corvos e papel (plano do dono, 30/10): bando rodando alto perto do jogador, corvo do chão voa quando você chega
# perto, papel rolando com o vento.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_bichos.gd
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
		await process_frame


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(10)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	var b: Bichos = main.get_node("Bichos")
	var c0: Node3D = b._bandos[0].corvos[0]
	ok(c0.global_position.y - j.global_position.y > 10.0 and c0.global_position.distance_to(j.global_position) < 140.0, "bando de corvos rodando alto perto do jogador")
	var antes: Vector3 = c0.global_position
	await frames(30)
	ok(c0.global_position.distance_to(antes) > 0.5, "o bando se mexe")
	# corvo do chão: chega perto e ele voa
	var cc: Dictionary = b._chao[0]
	j.global_position = (cc.no as Node3D).global_position + Vector3(2, 0.2, 0)
	await frames(30)
	ok(cc.voando and (cc.no as Node3D).global_position.y > cc.pos.y + 1.0, "corvo do chão levanta voo quando você chega perto")
	var papel: Dictionary = b._papeis[0]
	var pp: Vector3 = (papel.no as Node3D).global_position
	await frames(60)
	ok((papel.no as Node3D).global_position.distance_to(pp) > 0.5, "papel rola com o vento")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
