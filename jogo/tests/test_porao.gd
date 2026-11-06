# Porão (07/11, D2): casas com alçapão na cozinha; pisar desce para a sala escura, pisar no pé da escada sobe.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_porao.gd
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
	await frames(10)
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	var b: Bairro = main.bairro
	var poroes: Array = b.find_children("Porao_*", "Porao", false, false)
	ok(b.poroes >= 10 and poroes.size() == b.poroes, "cidade tem porões (%d)" % b.poroes)
	var p: Porao = poroes[0]
	ok(p.find_children("Bau_porao", "Bau", true, false).size() == 1, "porão tem baú de loot raro")
	var do_porao: int = 0
	for r: Dictionary in b.pontos_raid:
		if (r.pos as Vector3).y < p.alcapao.y - Porao.FUNDO * 0.5:
			do_porao += 1
	ok(do_porao >= b.poroes, "zumbis no porão (%d)" % do_porao)
	for z in main.zumbis.get_children():
		z.free()
	var j: Jogador = main.jogador
	j.vida = 100000
	j.global_position = p.alcapao + p._rumo * 2.5 + Vector3(0, 0.3, 0)
	await frames(20)
	j.global_position = p.alcapao + Vector3(0, 0.3, 0)
	await frames(20)
	ok(j.global_position.y < p.alcapao.y - Porao.FUNDO * 0.8, "pisar no alçapão desce (y %.1f, alçapão %.1f)" % [j.global_position.y, p.alcapao.y])
	await frames(90)
	ok(j.global_position.y > p.sala.y - 0.5 and j.is_on_floor(), "fica em pé no chão do porão")
	j.global_position = p.sala + Vector3(-Porao.LARG / 2 + 0.8, 0.3, Porao.COMP / 2 - 0.5)  # pé da escada
	await frames(20)
	ok(absf(j.global_position.y - p.alcapao.y) < 1.5, "pé da escada sobe para a cozinha (y %.1f)" % j.global_position.y)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
