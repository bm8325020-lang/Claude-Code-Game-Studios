# Bichos da floresta (13/11): lobo vê, persegue e morde; tiro/golpe machuca e mata; morto larga carne crua;
# raposa foge de quem chega perto; Fauna solta bichos em volta (fora dos testes só com a meta "no_teste").
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_bicho.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0
var main: Node3D
var j: Jogador


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func chao(l: Vector2) -> Vector3:
	return Bairro.ORIGEM + Vector3(l.x, main.bairro.altura(l) + 0.4, l.y)


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(30)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	j.vida = 100
	j._jogo_t = Jogador.NOVATO_T
	j.global_position = chao(Vector2(0, 40))  # na trilha do meio da mata
	await frames(10)
	var lobo := Bicho.new()
	lobo.tipo = "lobo"
	main.add_child(lobo)
	lobo.global_position = j.global_position + Vector3(12, 0.3, 0)
	await frames(300)
	ok(lobo._alvo == j, "o lobo viu o jogador")
	ok(j.vida < 100, "o lobo chegou e mordeu (vida %d)" % j.vida)
	var antes: int = lobo.vida
	lobo.levar_golpe(20, Vector3.RIGHT, j)
	ok(lobo.vida == antes - 20, "golpe machuca o lobo")
	var itens0: int = main.soltos.get_child_count()
	lobo.levar_golpe(200, Vector3.RIGHT, j)
	await frames(5)
	ok(lobo._morto and main.soltos.get_child_count() > itens0, "lobo morto larga carne crua")
	var rap := Bicho.new()
	rap.tipo = "raposa"
	main.add_child(rap)
	rap.global_position = j.global_position + Vector3(6, 0.3, 0)
	var d0: float = rap.global_position.distance_to(j.global_position)
	await frames(120)
	ok(rap.global_position.distance_to(j.global_position) > d0 + 3.0, "a raposa fugiu (%.1f -> %.1f m)" % [d0, rap.global_position.distance_to(j.global_position)])
	rap.queue_free()
	var f: Fauna = main.get_node("Fauna")
	f.set_meta("no_teste", true)
	f._jogo = 0.0
	f._t = 0.0
	await frames(200)
	var bs: Array = get_nodes_in_group("bichos").filter(func(b: Node) -> bool: return not (b as Bicho)._morto)
	ok(not bs.is_empty() and bs.all(func(b: Node) -> bool: return (b as Bicho).tipo != "lobo"), "a fauna soltou bicho (sem lobo no começo): %d" % bs.size())
	print("%s: %d/%d" % ["PASS" if falhas == 0 else "FAIL", checks - falhas, checks])
	quit(1 if falhas else 0)
