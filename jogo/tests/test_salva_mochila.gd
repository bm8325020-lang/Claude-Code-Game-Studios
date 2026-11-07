# Mochila salva com a história (07/11): grava num arquivo e volta igual (itens, balas no pente, colete).
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_salva_mochila.gd
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("TesteSalva")
	for i in 10: await physics_frame
	var j: Jogador = main.jogador
	var t: Tarefas = main.controles._tarefas
	j.mochila.adicionar("bandagem", 7)
	j.pistola.balas = 5
	j.colete = 63.0
	var cf := ConfigFile.new()
	t._poe_mochila(cf)
	j.mochila.tirar("bandagem", 7)
	j.pistola.balas = 0
	j.colete = 0.0
	t._tira_mochila(cf)
	var ok: bool = j.mochila.conta("bandagem") == 7 and j.pistola.balas == 5 and absf(j.colete - 63.0) < 0.01
	print("SALVA_MOCHILA: %s (bandagem %d, balas %d, colete %.0f)" % ["PASS" if ok else "FAIL", j.mochila.conta("bandagem"), j.pistola.balas, j.colete])
	quit(0 if ok else 1)
