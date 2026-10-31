# Clima (31/10): sorteio cobre os tipos; chuva/neve ligam as partículas; névoa e sol mudam; tempestade faz relâmpago.
#   godot --headless --path . -s res://tests/test_clima.gd
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
	rng.seed = 3
	var vistos: Dictionary = {}
	for i in 400:
		vistos[Clima.sorteia(rng)] = true
	ok(vistos.size() == Clima.TIPOS.size(), "o sorteio cai em todos os climas (%s)" % str(vistos.keys()))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var ciclo := Ciclo.new()
	ciclo.ambiente = Environment.new()
	ciclo.sol = DirectionalLight3D.new()
	root.add_child(ciclo.sol)
	root.add_child(ciclo)
	await process_frame
	await process_frame
	var nevoa: float = ciclo.ambiente.fog_density
	ciclo.clima = "nevasca"
	await process_frame
	ok(ciclo._clima._neve.emitting and not ciclo._clima._chuva.emitting, "nevasca: neve caindo")
	ok(ciclo.ambiente.fog_density > nevoa * 2.0, "nevasca fecha a névoa")
	ciclo.clima = "tempestade"
	await process_frame
	ok(ciclo._clima._chuva.emitting, "tempestade: chuva")
	ok(ciclo._clima.flash > 0.0, "tempestade: relâmpago")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
