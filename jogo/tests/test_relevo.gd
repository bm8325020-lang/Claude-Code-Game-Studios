# Relevo da cidade (plano do dono, 30/10): rio raso com ponte onde a rua cruza, morro que dá para subir e água que
# deixa lento.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_relevo.gd
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
	var pontes: Array = b.find_children("Ponte_*", "StaticBody3D", false, false)
	ok(pontes.size() >= 3, "pontes onde as ruas cruzam o rio (%d)" % pontes.size())
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Bairro.MAPA))
	var m: Dictionary = dados.terreno.morros[0]
	var topo := Vector2(m.p[0], m.p[1])
	ok(b.altura(topo) > 7.0, "morro alto (%.1f m)" % b.altura(topo))
	# em cima da ponte: fica no nível da rua
	var p: Node3D = pontes[0]
	j.global_position = p.global_position + Vector3(0, 0.5, 0)
	j.velocity = Vector3.ZERO
	await frames(40)
	ok(j.global_position.y > -0.3 and j.is_on_floor(), "anda em cima da ponte (y %.2f)" % j.global_position.y)
	# na água: bem mais lento que na terra
	var rio: Array = dados.terreno.rio.p
	var meio_rio: Vector2 = Vector2(rio[rio.size() / 2][0], rio[rio.size() / 2][1])
	j.global_position = Bairro.ORIGEM + Vector3(meio_rio.x, b.altura(meio_rio) + 0.3, meio_rio.y)
	j.camera.virar(0.0)
	await frames(30)
	j.entrada["move"] = Vector2(0, 1)
	j.entrada["correr"] = true
	await frames(30)
	var v_agua: float = Vector2(j.velocity.x, j.velocity.z).length()
	j.entrada["move"] = Vector2.ZERO
	ok(j.global_position.y < Bairro.AGUA_Y + 0.3 and v_agua < Jogador.ANDAR, "dentro do rio anda devagar (%.1f m/s)" % v_agua)
	# subir o morro andando pela encosta
	var a: float = 0.3
	var pe: Vector2 = topo + Vector2(cos(a), sin(a)) * float(m.raio) * 0.9
	j.global_position = Bairro.ORIGEM + Vector3(pe.x, b.altura(pe) + 0.3, pe.y)
	var para_topo: Vector2 = (topo - pe).normalized()
	j.camera.virar(atan2(-para_topo.x, -para_topo.y))
	await frames(10)
	j.entrada["correr"] = false
	j.entrada["move"] = Vector2(0, 1)
	var mais_alto: float = -INF
	for i in 60 * 16:
		await physics_frame
		mais_alto = maxf(mais_alto, j.global_position.y)
	j.entrada["move"] = Vector2.ZERO
	ok(mais_alto > float(m.alt) * 0.8, "sobe o morro andando (chegou a %.1f m)" % mais_alto)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
