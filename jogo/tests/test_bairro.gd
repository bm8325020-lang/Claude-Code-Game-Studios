# Bairro (primeira área do mapa): casas com porta e baú, o jogador nasce na frente de uma porta (fora da parede),
# e a malha dos zumbis do bairro leva da rua até dentro de uma casa pela porta.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_bairro.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("Teste")
	for i in 30: await physics_frame
	var b: Bairro = main.bairro
	var portas: Array = b.find_children("Porta_b*", "Porta", true, false)
	var baus: Array = b.find_children("Bau_*", "Bau", true, false)
	ok(portas.size() == 12 and baus.size() >= 6, "12 casas com porta e baús (%d portas, %d baús)" % [portas.size(), baus.size()])
	var j: Jogador = main.jogador
	ok(b.pontos_nascer.any(func(p: Vector3) -> bool: return p.distance_to(j.global_position) < 1.5) and j.is_on_floor(), "nasce no bairro, em pé na frente de uma porta")
	var casa: Node3D = b.get_node("Casa_0")
	var dentro: Vector3 = casa.global_position
	var mapa: RID = main.get_world_3d().navigation_map
	var cam: PackedVector3Array = NavigationServer3D.map_get_path(mapa, Bairro.ORIGEM + Vector3(0, 0.1, 0), dentro, true)
	ok(cam.size() > 1 and cam[cam.size() - 1].distance_to(dentro) < 1.0, "zumbi acha caminho da rua até dentro da casa (fim a %.1f m)" % (cam[cam.size() - 1].distance_to(dentro) if cam.size() > 0 else 99.0))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
