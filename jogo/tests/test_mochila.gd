# Mochila (só dados): pôr, empilhar, limite, tirar, dividir, mover, largar e itens presos.
#   godot --headless --path . -s res://tests/test_mochila.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var m := Mochila.new()
	var avisos: Array[int] = [0]
	m.mudou.connect(func() -> void: avisos[0] += 1)
	ok(m.adicionar("facao", 1) == 1 and m.espacos[0].tipo == "facao", "facão vai no primeiro espaço (barra 1)")
	ok(m.adicionar("municao", 30) == 30 and m.conta("municao") == 30, "pega 30 balas")
	ok(m.adicionar("municao", 30) == 30 and m.conta("municao") == 60, "empilha até 48 e abre outra pilha (60)")
	var pilhas: int = m.espacos.filter(func(e: Variant) -> bool: return e != null and e.tipo == "municao").size()
	ok(pilhas == 2, "60 balas = 2 pilhas (%d)" % pilhas)
	ok(m.adicionar("municao", 100) == 36 and m.conta("municao") == Mochila.LIMITE.municao, "não passa do limite de %d" % Mochila.LIMITE.municao)
	ok(m.adicionar("lanterna", 1) == 1 and m.adicionar("lanterna", 1) == 0, "só uma lanterna")
	ok(m.tirar("municao", 50) == 50 and m.conta("municao") == 46, "gasta 50 balas")
	m.definir("comida", 3)
	ok(m.conta("comida") == 3, "definir o total de comida")
	m.definir("comida", 1)
	ok(m.conta("comida") == 1, "definir para menos tira")
	var i_mun: int = m.onde("municao")
	ok(m.dividir(i_mun) and m.conta("municao") == 46, "dividir não muda o total")
	var i_fac: int = m.onde("facao")
	ok(m.tirar_espaco(i_fac).is_empty() and m.tem("facao"), "facão não sai da mochila")
	var i_lan: int = m.onde("lanterna")
	var saiu: Dictionary = m.tirar_espaco(i_lan)
	ok(saiu.get("tipo", "") == "lanterna" and not m.tem("lanterna"), "larga a lanterna")
	m.mover(0, 5)
	ok(m.espacos[5] and m.espacos[5].tipo == "facao", "move o facão para o espaço 6")
	# juntar duas pilhas ao mover
	var a: int = m.onde("municao")
	var b: int = -1
	for k in range(a + 1, Mochila.ESPACOS):
		if m.espacos[k] and m.espacos[k].tipo == "municao":
			b = k
			break
	m.mover(b, a)
	ok(m.conta("municao") == 46 and m.espacos[a].qtd == 46, "mover pilha em cima de outra junta (%d)" % m.espacos[a].qtd)
	var cheia := Mochila.new()
	for k in Mochila.ESPACOS:
		cheia.espacos[k] = {"tipo": "pedra%d" % k, "qtd": 1}
	ok(cheia.adicionar("comida", 1) == 0, "mochila cheia não pega mais nada")
	ok(avisos[0] > 5, "avisa a tela quando muda")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
