# Testes da mecânica 11 (pegar item do chão): munição, lanterna, some ao pegar, volta depois.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_itens.gd
extends SceneTree

var main: Node3D
var j: Jogador
var checks: int = 0
var falhas: int = 0


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	var caixa: Item = main.get_node("Item_0")
	# longe: nada para pegar
	j.global_position = caixa.global_position + Vector3(3, 0.1, 0)
	await frames(10)
	ok(j.item_perto() == null, "longe da caixa não aparece PEGAR")
	j.global_position = caixa.global_position + Vector3(0.8, 0.1, 0)
	await frames(10)
	ok(j.item_perto() == caixa, "perto da caixa aparece PEGAR")
	var antes: int = j.pistola.reserva
	j.entrada["pegar"] = true
	j.entrada["move"] = Vector2(0, 1)
	await frames(6)
	ok(j.clipe_atual() == "pegar" and Vector2(j.velocity.x, j.velocity.z).length() < 0.5, "abaixa para pegar e não anda (%s)" % j.clipe_atual())
	ok(j.pistola.reserva == antes + 24 and not caixa.ativo and not caixa.visible, "pega 24 balas e a caixa some (%d)" % j.pistola.reserva)
	j.entrada["move"] = Vector2.ZERO
	await frames(60)
	ok(j.item_perto() == null, "não pega de novo a caixa que sumiu")
	await frames(int(Item.VOLTA * 60) + 10)
	ok(caixa.ativo and caixa.visible, "a caixa volta depois de %d s" % int(Item.VOLTA))
	j.pistola.reserva = Pistola.RESERVA_MAX - 5
	j.entrada["pegar"] = true
	await frames(60)
	ok(j.pistola.reserva == Pistola.RESERVA_MAX, "a reserva não passa de %d" % Pistola.RESERVA_MAX)
	# lanterna
	j.tem_lanterna = false
	var l := Item.new()
	l.tipo = "lanterna"
	l.position = j.global_position + Vector3(0.5, -0.1, 0.5)
	main.add_child(l)
	await frames(5)
	j.entrada["pegar"] = true
	await frames(60)
	ok(j.tem_lanterna and not l.ativo, "acha a lanterna e passa a ter lanterna")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
