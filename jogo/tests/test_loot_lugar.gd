# Loot pelo lugar (05/11): farmácia e banheiro dão mais antibiótico, cozinha mais comida; o Bairro acha o lugar pelo nome.
#   godot --headless --path . -s res://tests/test_loot_lugar.gd
extends SceneTree
var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func conta(lugar: String, tipo: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n: int = 0
	for i in 3000:
		var a: Array = Loot.sorteia_lugar(rng, lugar)
		n += int(not a.is_empty() and a[0].tipo == tipo)
	return n


func _init() -> void:
	ok(conta("farmacia", "antibiotico") > conta("", "antibiotico") * 4, "farmácia dá bem mais antibiótico")
	ok(conta("banheiro", "antibiotico") > conta("sala", "antibiotico") * 3, "banheiro dá mais antibiótico que a sala")
	ok(conta("cozinha", "comida") > conta("quarto", "comida") * 1.5, "cozinha dá mais comida que o quarto")
	ok(Bairro.lugar_de("balcao_cozinha0", "casa_r2") == "cozinha" and Bairro.lugar_de("criado_quarto1", "casa_r5") == "quarto", "cômodo pelo nome do móvel")
	ok(Bairro.lugar_de("balcao_loja", "sobrado_1") == "farmacia" and Bairro.lugar_de("estante_h3_2", "hospital") == "hospital", "loja e hospital pelo modelo")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
