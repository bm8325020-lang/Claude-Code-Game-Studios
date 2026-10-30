# Nascer em lugar aleatório (prompt 11): pontos bons (baú fácil perto, zumbi longe) e ruins; o sorteio cai em bom
# ~75% das vezes; morreu: renasce num ponto sorteado do bairro.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_nascer.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bons: Array[Vector3] = [Vector3(1, 0, 0), Vector3(2, 0, 0)]
	var ruins: Array[Vector3] = [Vector3(9, 0, 0)]
	var n_bom: int = 0
	for k in 4000:
		if Bairro.sorteia(rng, bons, ruins).x < 5.0:
			n_bom += 1
	ok(absf(n_bom / 4000.0 - Bairro.CHANCE_BOM) < 0.03, "cai em ponto bom %.1f%% das vezes (alvo %d%%)" % [n_bom / 40.0, roundi(Bairro.CHANCE_BOM * 100)])
	ok(Bairro.sorteia(rng, [] as Array[Vector3], ruins) == ruins[0] and Bairro.sorteia(rng, bons, [] as Array[Vector3]).x < 5.0, "sem bons (ou sem ruins) usa o que tem")
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("Teste")
	for i in 10: await physics_frame
	var b: Bairro = main.bairro
	ok(not b.pontos_bons.is_empty() and not b.pontos_ruins.is_empty(), "o bairro tem pontos bons (%d) e ruins (%d)" % [b.pontos_bons.size(), b.pontos_ruins.size()])
	var faceis: Array = b.find_children("Bau_*", "Bau", true, false).filter(func(x: Bau) -> bool: return x.facil)
	ok(b.pontos_bons.all(func(p: Vector3) -> bool: return faceis.any(func(x: Bau) -> bool: return x.global_position.distance_to(p) <= Bairro.BOM_BAU) and b.pontos_zumbi.all(func(z: Vector3) -> bool: return z.distance_to(p) >= Bairro.BOM_ZUMBI)), "bom = baú fácil perto e zumbi longe")
	var j: Jogador = main.jogador
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	j.global_position = Vector3(30, 0.1, 30)
	j.levar_dano(1000, Vector3.FORWARD)
	j._morto_t = 0.02
	for i in 10: await physics_frame
	ok(j.vida > 0 and b.pontos_nascer.any(func(p: Vector3) -> bool: return p.distance_to(j.global_position) < 1.5), "morreu: renasce num ponto sorteado do bairro")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
