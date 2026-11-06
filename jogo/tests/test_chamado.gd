# Rádio com chamados (07/11, E6): pedido de socorro com caixa de loot de raid; verdadeiro = zumbis em volta (não
# renascem), armadilha = saqueadores dos Corvos armados em volta.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_chamado.gd
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


func _conta(main: Node, f: Callable) -> int:
	return main.zumbis.get_children().filter(f).size()


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(30)
	main.jogador.vida = 100000
	main.jogador.global_position = Bairro.ORIGEM + Vector3(-12, 0.3, 300)  # no centro, dentro da cidade
	await frames(5)
	var caixas0: int = get_nodes_in_group("suprimento").size()
	var mortos0: int = _conta(main, func(z: Zumbi) -> bool: return z.horda == Zumbi.DO_MORTO)
	ok(main.suprimento.chamado(main, 0), "acha lugar para o socorro")
	await frames(5)
	ok(get_nodes_in_group("suprimento").size() > caixas0, "socorro deixa a caixa marcada no mapa")
	ok(_conta(main, func(z: Zumbi) -> bool: return z.horda == Zumbi.DO_MORTO) - mortos0 == Suprimento.CHAMADO_ZUMBIS, "socorro verdadeiro: zumbis em volta")
	var corvos0: int = _conta(main, func(z: Zumbi) -> bool: return z.humano())
	ok(main.suprimento.chamado(main, 1), "acha lugar para a emboscada")
	await frames(5)
	ok(_conta(main, func(z: Zumbi) -> bool: return z.humano()) - corvos0 == Suprimento.CHAMADO_CORVOS, "emboscada: Corvos armados em volta")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
