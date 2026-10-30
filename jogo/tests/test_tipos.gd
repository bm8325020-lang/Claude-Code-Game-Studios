# Tipos de zumbi (Zumbi.TIPOS): cada um com vida, dano, velocidade, andar e habilidade próprios. Corredora dá o bote
# de longe, o soco do policial agarra (jogador fica lento), o soldado é blindado (menos dano, não cambaleia à toa).
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_tipos.gd
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
	var tipos: Dictionary = {}
	for z: Zumbi in main.zumbis.get_children():
		if not z.chefe:
			tipos[z.tipo] = true
	ok(tipos.size() >= 2, "a pista tem tipos diferentes de zumbi (%s)" % ", ".join(tipos.keys()))
	var lento: float = Zumbi.TIPOS.zumbi_soldado.vel
	ok(Zumbi.TIPOS.zumbi_mulher.vel > 1.0 and lento < 1.0 and Zumbi.TIPOS.zumbi_soldado.vida > Zumbi.TIPOS.zumbi_mulher.vida, "corredora rápida e frágil, soldado lento e duro")
	# deixa um só zumbi na pista
	var z: Zumbi = null
	for c: Zumbi in main.zumbis.get_children():
		if z == null and not c.chefe:
			z = c
		else:
			c.free()
	z._sem_gritar = INF
	# soldado blindado: leva 60% e não cambaleia com golpe fraco
	z.aplica_tipo("zumbi_soldado")
	z.levar_golpe(20, Vector3.FORWARD, j)
	ok(z.vida == 180 - 12 and z._cambaleio <= 0.0, "soldado leva 12 de um golpe de 20 e não cambaleia (vida %d)" % z.vida)
	# corredora: bote de 5 m
	z.aplica_tipo("zumbi_mulher")
	z.global_position = Vector3(40, 0.05, 40)
	j.global_position = Vector3(40, 0.05, 45)
	z._skill_t = 0.0
	z.alvo = j
	await frames(30)
	ok(z._skill_t > 0.0 and z.global_position.distance_to(Vector3(40, 0.05, 40)) > 2.0, "corredora dá o bote (andou %.1f m em 0,5 s)" % z.global_position.distance_to(Vector3(40, 0.05, 40)))
	# policial: o soco agarra (jogador lento)
	z.aplica_tipo("zumbi_policial")
	j.agarrado_t = 0.0
	z.global_position = j.global_position + Vector3(0, 0, -1.0)
	z.alvo = j
	var v0: int = j.vida
	for i in 240:
		await physics_frame
		if j.vida < v0:
			break
	await frames(2)
	ok(j.vida < v0 and j.agarrado_t > 1.5, "o soco do policial agarra (vida %d -> %d, agarrado %.1f s)" % [v0, j.vida, j.agarrado_t])
	# longe de todos e sem nada para fazer: dorme no servidor (não pensa nem anda); alguém chega perto: acorda
	z.alvo = null
	z.global_position = j.global_position + Vector3(Zumbi.DORME_DIST + 20.0, 0, 0)
	z.casa = z.global_position
	z._voltando = false
	z._indo_ouvir = false
	z._procura_t = 0.0
	await frames(90)
	var dormiu: bool = z._dormindo
	j.global_position = z.global_position + Vector3(30, 0, 0)
	await frames(90)
	ok(dormiu and not z._dormindo, "zumbi longe de todos dorme e acorda quando alguém chega a %d m" % int(Zumbi.DORME_DIST))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
