# Tarefas (31/10): o painel começa em "pegue comida", anda com os eventos certos (e não com os errados) e dá XP.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_tarefas.gd
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
	main.iniciar_solo("TesteTarefas")
	for i in 5: await physics_frame
	var j: Jogador = main.jogador
	var t: Tarefas = main.controles._tarefas
	ok(t._linha.text.contains("comida"), "começa pedindo comida (%s)" % t._linha.text)
	var xp0: int = j.prog.xp + j.prog.nivel * 1000
	t.evento("agua")
	ok(t._i == 0, "evento errado não conta")
	j.ganhar("comida", 1)
	await physics_frame
	ok(t._i == 1 and t._linha.text.contains("gavetas"), "pegou comida: vai para as gavetas (%s)" % t._linha.text)
	ok(j.prog.xp + j.prog.nivel * 1000 > xp0, "tarefa feita dá XP")
	for k in 3:
		j.revistou.emit()
	ok(t._i == 2 and t._linha.text.contains("zumbis"), "3 gavetas: vai para os zumbis (%s)" % t._linha.text)
	print("TAREFAS: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
