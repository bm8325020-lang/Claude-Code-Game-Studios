# Progressão (plano do dono, 30/10): XP por zumbi morto e por noite sobrevivida, nível dá ponto, habilidades mudam o
# jogo (Vigor: vida; Força: dano de arma branca) e tudo fica salvo.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_progresso.gd
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
	# só dados
	var p := Progresso.new()
	ok(p.ganha(Progresso.xp_para(1) - 1) == 0 and p.nivel == 1, "XP abaixo do nível não sobe")
	ok(p.ganha(1) == 1 and p.nivel == 2 and p.pontos == 1, "XP completo sobe de nível e dá ponto")
	ok(Progresso.xp_para(5) > Progresso.xp_para(2) * 2, "cada nível pede mais XP")
	ok(p.gasta("vigor") and not p.gasta("vigor"), "gasta ponto só se tiver")
	p.salva("user://teste_prog.cfg")
	var q := Progresso.new()
	q.carrega("user://teste_prog.cfg")
	ok(q.nivel == 2 and int(q.hab.vigor) == 1, "salva e carrega")
	# no jogo
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
	j.prog = Progresso.new()
	var z := Zumbi.new()
	z.position = Vector3(40, 0, 40)
	z.casa = z.position
	main.zumbis.add_child(z)
	await frames(2)
	z.levar_golpe(100000, Vector3.FORWARD, j)
	await frames(5)
	ok(j.prog.xp == Progresso.XP_ZUMBI, "matar zumbi dá XP (%d)" % j.prog.xp)
	j.prog.pontos = 2
	var v0: int = j.vida_max()
	ok(j.aprende("vigor") and j.vida_max() == v0 + 8, "Vigor aumenta a vida máxima")
	ok(j.aprende("forca") and j.mult_forca() > 1.0, "Força aumenta o dano de arma branca")
	# noite sobrevivida
	var xp0: int = j.prog.xp
	main.ciclo.tempo = Ciclo.DIA + Ciclo.NOITE - 1.0
	main.ciclo._process(0.1)
	main.ciclo._process(2.0)
	ok(j.prog.xp > xp0, "amanhecer vivo dá XP")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Progresso.arquivo("Teste")))  # não vaza para os outros testes
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_prog.cfg"))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
