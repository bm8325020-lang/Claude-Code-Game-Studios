# Receitas e bancada (prompt 6 do loop): aprender usando a receita, sem peças não fabrica, longe da bancada não
# fabrica, com peças consome e cria em 3 s, sair da bancada cancela, a bancada muda de lugar e avisa.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_receitas.gd
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
	var b: Bancada = main.bancada
	ok(b != null and main.PONTOS_BANCADA.has(b.position), "bancada num dos pontos da cidade")
	# perde a pistola e aprende a receita
	j.mochila.tirar("pistola", 1)
	j.mochila.adicionar("receita_pistola", 1)
	ok(not j.comeca_fabricar("pistola", 1), "sem saber a receita não fabrica")
	j.usar_espaco(j.mochila.onde("receita_pistola"))
	ok("pistola" in j.receitas and not j.mochila.tem("receita_pistola"), "usar a receita ensina e ela some")
	j.global_position = b.global_position + Vector3(0, 0.1, 1.3)
	await frames(5)
	ok(j.bancada_perto() == b, "perto da bancada")
	ok(not j.comeca_fabricar("pistola", 1), "sem peças não fabrica")
	for p: String in Receitas.LISTA.pistola.pecas:
		j.mochila.adicionar(p, int(Receitas.LISTA.pistola.pecas[p]))
	ok(Receitas.quantas(j.mochila, "pistola") == 1, "com as peças dá para 1")
	ok(j.comeca_fabricar("pistola", 1), "começa a fabricar")
	await frames(60)
	j.global_position += Vector3(0, 0, 6)  # saiu da bancada: cancela
	await frames(5)
	ok(j.fabrica_t == 0.0 and not j.mochila.tem("pistola") and j.mochila.tem("cano"), "sair de perto cancela e não gasta as peças")
	j.global_position = b.global_position + Vector3(0, 0.1, 1.3)
	await frames(5)
	ok(j.comeca_fabricar("pistola", 1), "começa de novo")
	await frames(int(Receitas.FABRICAR_T * 60) + 10)
	ok(j.mochila.tem("pistola") and not j.mochila.tem("cano") and j.mochila.conta("mola") == 0, "em %d s a pistola fica pronta e as peças são gastas" % int(Receitas.FABRICAR_T))
	# longe da bancada
	for p: String in Receitas.LISTA.pistola.pecas:
		j.mochila.adicionar(p, int(Receitas.LISTA.pistola.pecas[p]))
	j.mochila.tirar("pistola", 1)
	j.global_position = Vector3(-20, 0.1, 30)
	await frames(5)
	ok(not j.comeca_fabricar("pistola", 1), "longe da bancada não fabrica")
	# muda de lugar e avisa
	var antes: Vector3 = b.position
	var avisos: Array = [0]
	b.mudou_de_lugar.connect(func() -> void: avisos[0] += 1)
	b._muda_t = 0.05
	await frames(10)
	ok(not b.position.is_equal_approx(antes) and main.PONTOS_BANCADA.has(b.position) and avisos[0] == 1, "depois de 10 min muda de lugar e avisa")
	ok(main.controles._faixa_texto.text.contains("BANCADA"), "aviso na tela: %s" % main.controles._faixa_texto.text)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
