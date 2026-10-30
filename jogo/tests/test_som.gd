# Som do mundo (plano do dono, 30/10): vento tocando, passos ao andar (som diferente dentro de casa), eco só dentro
# de casa e coração com pouca vida.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_som.gd
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
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	var s: SomAmbiente = main.get_node("SomAmbiente")
	ok(s._vento.playing, "vento tocando")
	# anda na pista (fora de casa): passos
	j.global_position = Vector3(40, 0.1, 40)
	await frames(20)
	var tocou: int = 0
	var pitch_fora: float = 0.0
	j.entrada["move"] = Vector2(0, 1)
	for i in 120:
		await process_frame
		if s._passo.playing and s._passo.get_playback_position() < 0.02:
			tocou += 1
			pitch_fora = s._passo.pitch_scale
	j.entrada["move"] = Vector2.ZERO
	ok(tocou >= 2, "andando toca passos (%d)" % tocou)
	ok(not AudioServer.is_bus_effect_enabled(0, s._eco), "fora de casa sem eco")
	# dentro de casa: eco e passo de tábua (grave)
	var casa: Node3D = main.bairro.get_node("Casa_1")
	j.global_position = main.bairro.dentro_da("Casa_1") + Vector3(0, 0.1, 0)
	await frames(5)
	ok(AudioServer.is_bus_effect_enabled(0, s._eco), "dentro de casa tem eco")
	s._ultima = j.global_position
	s._andado = 10.0
	j.global_position += Vector3(0.05, 0, 0)
	await frames(2)
	ok(s._passo.pitch_scale < 0.85 and pitch_fora >= 0.95, "passo dentro de casa é grave (tábua) e fora não (%.2f / %.2f)" % [s._passo.pitch_scale, pitch_fora])
	# pouca vida: coração
	j.vida = 15
	await frames(90)
	ok(s._coracao.volume_db > -20.0, "com pouca vida o coração bate alto (%.0f dB)" % s._coracao.volume_db)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
