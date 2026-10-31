# Rastros de sobreviventes (plano do dono, 30/10): refúgios com barricada e arame farpado (corta e prende), pichações
# nas fachadas e bilhetes que aparecem na tela quando você chega perto.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_sobreviventes.gd
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
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var s: Sobreviventes = main.bairro.get_node("Sobreviventes")
	var refugios: Array = s.find_children("Refugio_*", "Node3D", false, false)
	var pixos: Array = s.find_children("*", "Label3D", false, false)
	var bilhetes: Array = s.get_tree().get_nodes_in_group("bilhetes")
	ok(refugios.size() == Sobreviventes.N_REFUGIOS, "%d refúgios com barricada" % refugios.size())
	ok(pixos.size() >= 10, "pichações nas fachadas (%d)" % pixos.size())
	ok(bilhetes.size() >= 8, "bilhetes espalhados (%d)" % bilhetes.size())
	# bilhete: chegou perto, aparece na tela
	var b: Node3D = bilhetes[0]
	j.global_position = b.global_position + Vector3(0.5, 0.1, 0)
	await frames(30)
	ok(main.controles._lidos.has(b) and main.controles._papel != null and main.controles._papel.visible, "chegou perto do bilhete: lê")
	# arame farpado: corta e prende
	var arame: Area3D = refugios[0].get_node("Arame")
	j.vida = 100
	j.global_position = arame.global_position + Vector3(0, -0.4, 0)
	j.velocity = Vector3.ZERO
	await frames(60)
	ok(j.vida < 100 and j.agarrado_t > 0.0, "arame farpado corta e prende (vida %d)" % j.vida)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
