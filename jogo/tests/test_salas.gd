# Salas de PvP (só os dados): criar, código, pública/privada, entrar, limite, dono, começar, valer o tiro só na mesma
# sala jogando, placar, fim e volta a esperar.
#   godot --headless --path . -s res://tests/test_salas.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var s := Salas.new(7)
	var cod: String = s.criar(10, "Sala do Ana", true, 2, 5)
	ok(cod.length() == 4 and s.sala_de(10) == cod and s.salas[cod].dono == 10, "cria com código de 4 letras e o dono dentro")
	var priv: String = s.criar(20, "Secreta", false, 8, 10)
	ok(s.lista_publica().size() == 1 and s.lista_publica()[0].codigo == cod, "só a pública aparece na lista")
	ok(s.entrar(30, "zzzz") != "" and s.entrar(30, priv.to_lower()) == "" and s.sala_de(30) == priv, "privada: entra pelo código (maiúscula ou não)")
	ok(s.comecar(30) != "", "só o dono começa")
	ok(s.comecar(10) != "", "precisa de 2 para começar")
	ok(s.entrar(11, cod) == "" and s.entrar(12, cod) != "", "limite da sala")
	ok(s.lista_publica().is_empty(), "sala cheia sai da lista")
	ok(not s.mesma(10, 20) and s.mesma(10, 11) and s.mesma(1, 2), "só se veem na mesma sala (ou os dois fora)")
	ok(not s.vale(10, 11), "antes de começar o tiro não vale")
	ok(s.comecar(10) == "" and s.vale(10, 11) and not s.vale(10, 20) and not s.vale(10, 10), "jogando: vale só na mesma sala")
	s.abate(cod, "ana", "bia")
	s.abate(cod, "ana", "bia")
	s.abate(cod, "bia", "ana")
	ok(s.placar(cod) == [["ana", 2, 1], ["bia", 1, 2]], "placar por abates")
	ok(s.passa(299.0).is_empty() and s.passa(2.0) == [["fim", cod]] and s.salas[cod].estado == "fim" and not s.vale(10, 11), "tempo acaba: fim")
	ok(s.passa(Salas.FIM_T + 0.1) == [["espera", cod]], "depois do placar volta a esperar")
	s.sair(10)
	ok(s.salas[cod].dono == 11, "dono saiu: passa para o próximo")
	s.sair(11)
	ok(not s.salas.has(cod) and s.sala_de(11) == "", "vazia: some")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
