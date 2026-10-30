# Infecção e mordida no pescoço: o policial agarra e tenta morder; acertando o tempo 3 vezes o jogador se solta e o
# zumbi cambaleia; sem reagir é mordido (dano e infecção certa); infectado a barra sobe e em 100 mata; o antibiótico
# tira e para de subir.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_mordida.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	Zumbi.tipo_fixo = "zumbi_policial"
	(load("res://scripts/main.gd") as GDScript).set("nascer_no_bairro", false)
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await physics_frame
	main.iniciar_solo("Teste")
	for i in 10: await physics_frame
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	main.controles.jogador = null
	var j: Jogador = main.jogador
	var z: Zumbi = null
	for n in main.zumbis.get_children():
		if z == null and not (n as Zumbi).chefe:
			z = n
		else:
			n.free()
	j.global_position = Vector3(30, 0.1, -20)
	z.global_position = Vector3(30, 0, -19)
	for i in 5: await physics_frame
	# 1) se solta acertando o tempo
	z.alvo = j
	z._mordendo = Zumbi.MORDIDA_T
	j.comeca_mordida(z)
	ok(j.mordida_t > 0.0 and j.camera.foco == z, "agarrou: a câmera trava no zumbi")
	var vida0: int = j.vida
	for i in 400:
		if j.mordida_t <= 0.0:
			break
		if j.qte_pos >= j.qte_faixa.x + 0.02 and j.qte_pos <= j.qte_faixa.x + j.qte_faixa.y - 0.02:
			j.entrada["soltar"] = true
		await physics_frame
	ok(j.mordida_t <= 0.0 and j.qte_acertos >= Jogador.ACERTOS_SOLTAR and j.camera.foco == null, "3 acertos: se soltou")
	ok(z._mordendo < 0.0 and z._cambaleio > 0.0, "o zumbi cambaleia para trás")
	ok(j.vida == vida0 and not j.infectado, "sem mordida, sem infecção")
	# 2) não reage: é mordido
	for i in 40: await physics_frame
	z._mordendo = Zumbi.MORDIDA_T
	j.comeca_mordida(z)
	for i in 300:
		if j.mordida_t <= 0.0 and z._mordendo < 0.0:
			break
		await physics_frame
	ok(j.vida <= vida0 - Zumbi.MORDIDA_DANO and j.infectado and j.infeccao >= Jogador.MORDIDA_INFECCAO, "não reagiu: mordido e infectado (vida %d, infecção %.0f)" % [j.vida, j.infeccao])
	# 3) a infecção sobe sozinha
	var antes: float = j.infeccao
	for i in 120: await physics_frame
	ok(j.infeccao > antes, "infectado: a barra sobe")
	# 4) antibiótico
	j.mochila.adicionar("antibiotico", 1)
	j.toma_antibiotico()
	var depois: float = j.infeccao
	for i in 60: await physics_frame
	ok(not j.infectado and depois <= antes and j.infeccao == depois and not j.mochila.tem("antibiotico"), "antibiótico: tira e para de subir")
	# 5) em 100 mata
	j.infecta(0.0)
	j.infeccao = 99.95
	for i in 30: await physics_frame
	ok(j.vida <= 0, "infecção em 100 mata")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
