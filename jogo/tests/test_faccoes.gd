# Facções (prompt 12): dominar casa — começa com MIN_CRIAR dentro, falha se todos saem, sucesso cria a facção com quem
# está dentro, facção existente redomina mais rápido, outro grupo tira a casa (não a facção), limite de membros; e no
# jogo: dentro de uma casa do bairro, DOMINAR anuncia para todos e, acabando o tempo, cria a facção.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_faccoes.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var f := Faccoes.new()
	ok(f.comecar("Casa_1", "ana", []) != "" or Faccoes.MIN_CRIAR == 0, "ninguém dentro: não começa")
	ok(f.comecar("Casa_1", "ana", ["ana"]) == "" and f.tentativas.Casa_1.total == Faccoes.DOMINAR_T, "1 dentro já começa (%d min)" % int(Faccoes.DOMINAR_T / 60))
	var ev: Array = f.passa(1.0, {})
	ok(ev == [["falha", "Casa_1"]] and f.tentativas.is_empty(), "saiu todo mundo: falha")
	f.comecar("Casa_1", "ana", ["ana"])
	f.passa(100.0, {"Casa_1": ["ana", "bia"]})
	ev = f.passa(Faccoes.DOMINAR_T, {"Casa_1": ["ana", "bia"]})
	ok(ev.size() == 1 and ev[0][0] == "sucesso" and f.faccao_de("bia") == ev[0][2] and f.dona("Casa_1") == ev[0][2], "tempo acabou: facção criada com quem estava dentro, dona da casa")
	var nome: String = ev[0][2]
	ok(f.comecar("Casa_2", "ana", ["ana"]) != "", "uma facção = uma casa")
	# outro grupo domina a casa dela: a facção perde a casa, mas continua
	f.comecar("Casa_1", "caio", ["caio"])
	ev = f.passa(Faccoes.DOMINAR_T + 1.0, {"Casa_1": ["caio"]})
	ok(f.dona("Casa_1") != nome and f.faccoes.has(nome) and f.faccoes[nome].casa == "", "outro grupo tomou: perde a área, não a facção")
	ok(f.comecar("Casa_3", "bia", ["bia"]) == "" and f.tentativas.Casa_3.total == Faccoes.REDOMINAR_T, "facção que já existe redomina com 1 membro em %d min" % int(Faccoes.REDOMINAR_T / 60))
	for k in Faccoes.LIMITE - 2:
		f.adicionar("ana", "m%d" % k)
	ok(f.faccoes[nome].membros.size() == Faccoes.LIMITE and f.adicionar("ana", "extra") != "", "limite de %d membros" % Faccoes.LIMITE)
	# no jogo
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("Dono")
	for i in 10: await physics_frame
	var j: Jogador = main.jogador
	for z in main.zumbis.get_children():
		z.free()
	var casa: Node3D = main.bairro.get_node("Casa_3")
	j.global_position = casa.global_position + Vector3(0, 0.1, 0)
	for i in 5: await physics_frame
	ok(main.bairro.casa_em(j.global_position) == "Casa_3", "sabe que o jogador está dentro da casa")
	main.pede_dominar()
	for i in 3: await physics_frame
	ok(main.faccoes.tentativas.has("Casa_3") and main.controles._faixa_texto.text.contains("DOMINAR"), "DOMINAR começa e avisa todos (%s)" % main.controles._faixa_texto.text)
	main.faccoes.tentativas.Casa_3.t = 0.3
	for i in 60: await physics_frame
	ok(main.faccao_de("Dono") != "" and main._faccoes_cli.f[main.faccao_de("Dono")].casa == "Casa_3", "tempo acabou: o jogador tem facção e a casa (%s)" % main.faccao_de("Dono"))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
