# Testes do porta-malas (05/11, mods de zumbi do GTA V): todo carro que anda tem um porta-malas revistável atrás;
# de trás do carro o botão acha ele; revistar abre a tampa e dá loot de carro (ou vazio).
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_porta_malas.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	main.iniciar_solo("Teste")
	for i in 10:
		await physics_frame
	var j: Jogador = main.jogador
	main.controles.jogador = null
	var carros: Array = get_nodes_in_group("carros").filter(func(c: Node) -> bool: return c.get_parent() == main.bairro)
	var malas: Array = get_nodes_in_group("gavetas").filter(func(g: Gaveta) -> bool: return g.movel == "porta_malas")
	ok(carros.size() > 0 and malas.size() >= carros.size(), "porta-malas nos carros (%d carros, %d)" % [carros.size(), malas.size()])
	var g: Gaveta = null
	for m: Gaveta in malas:
		if m.get_parent() in carros:
			g = m
			break
	var c: Node3D = g.get_parent() if g else null
	ok(g != null and g.lugar == "carro", "loot de carro")
	if g:
		j.global_position = c.to_global(Vector3(0, 0.1, -2.9))  # atrás do carro
		j.velocity = Vector3.ZERO
		for i in 3:
			await physics_frame
		ok(Gaveta.perto(self, j.global_position) == g, "de trás do carro acha o porta-malas")
		ok(g.acao() == "revistar porta-malas", "botão: %s" % g.acao())
		g.revista_por(j)
		ok(g.aberta, "revistar abre")
		for i in 40:
			await physics_frame
		ok(g._caixa.visible and g._caixa.rotation.x < -0.8, "a tampa levanta (%.2f)" % g._caixa.rotation.x)
	var rng := RandomNumberGenerator.new()
	var tipos: Dictionary = {}
	for i in 200:
		for e: Dictionary in Loot.sorteia_lugar(rng, "carro"):
			tipos[e.tipo] = true
	ok(tipos.has("cabo") or tipos.has("mola"), "carro dá peça (%s)" % ", ".join(tipos.keys()))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
