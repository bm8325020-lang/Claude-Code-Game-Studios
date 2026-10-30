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
	var casas: Array = b.find_children("Casa_*", "Node3D", false, false)
	var mansoes: Array = b.find_children("Mansao_*", "Node3D", false, false)
	var portas: Array = b.find_children("Porta_*", "Porta", true, false)
	var baus: Array = b.find_children("Bau_*", "Bau", true, false)
	ok(casas.size() >= 18 and mansoes.size() == 3 and portas.size() >= 10 and baus.size() >= 8, "cidade: %d casas, %d mansões, %d portas, %d baús" % [casas.size(), mansoes.size(), portas.size(), baus.size()])
	ok(mansoes.all(func(m: Node) -> bool: return b.dominavel(String(m.name)) and b.bau_da(String(m.name)) != null) and not b.dominavel("Casa_0") and b.bau_da("Casa_0") == null, "só as mansões são domináveis (com baú da facção)")
	var j: Jogador = main.jogador
	ok(b.pontos_nascer.any(func(p: Vector3) -> bool: return p.distance_to(j.global_position) < 1.5) and j.is_on_floor(), "nasce no bairro, em pé na frente de uma porta")
	var casa: Node3D = casas.filter(func(c: Node) -> bool: return c.find_children("Porta_*", "Porta", true, false).is_empty() and c.has_meta("frente"))[0]  # arrombada
	var poly: PackedVector2Array = casa.get_meta("poly")
	var c2 := Vector2.ZERO
	for p: Vector2 in poly:
		c2 += p
	c2 /= poly.size()
	# ponto depois da parede do meio (que passa pelo centro): o caminho tem que achar o vão dela
	var fr: Vector3 = casa.get_meta("frente")
	var meio := Bairro.ORIGEM + Vector3(c2.x, 0.1, c2.y)
	var dentro: Vector3 = meio + Vector3(meio.x - fr.x, 0, meio.z - fr.z).normalized() * 1.2
	var mapa: RID = main.get_world_3d().navigation_map
	for i in 900:  # cidade grande: o mapa de navegação demora uns segundos para juntar as regiões
		if NavigationServer3D.map_get_iteration_id(mapa) > 0 and NavigationServer3D.map_get_closest_point(mapa, dentro).distance_to(dentro) < 1.0:
			break
		await physics_frame
	var cam: PackedVector3Array = NavigationServer3D.map_get_path(mapa, casa.get_meta("frente"), dentro, true)  # da rua
	ok(cam.size() > 1 and cam[cam.size() - 1].distance_to(dentro) < 1.5, "zumbi acha caminho da rua até dentro da casa (fim a %.1f m)" % (cam[cam.size() - 1].distance_to(dentro) if cam.size() > 0 else 99.0))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
