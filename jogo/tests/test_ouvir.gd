# Testes do barulho de quem se mexe (05/11, mods de zumbi do GTA V): correr ouve de mais longe, agachado de mais perto,
# dentro do carro vale o motor; de noite o zumbi "noturno" corre de longe.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_ouvir.gd
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
	for i in 5:
		await physics_frame
	var j: Jogador = main.jogador
	main.controles.jogador = null
	var b: float = Zumbi.OUVE
	ok(is_equal_approx(Zumbi.ouve_de(j, b), b), "andando: ouve a %.1f m" % b)
	j.correndo = true
	ok(is_equal_approx(Zumbi.ouve_de(j, b), b * Zumbi.OUVE_CORRENDO), "correndo: ouve a %.1f m" % Zumbi.ouve_de(j, b))
	j.correndo = false
	j.agachado = true
	ok(Zumbi.ouve_de(j, b) < b, "agachado: ouve a %.1f m" % Zumbi.ouve_de(j, b))
	j.agachado = false
	j.no_carro = true
	ok(Zumbi.ouve_de(j, b) >= Zumbi.OUVE_CARRO, "no carro: ouve o motor a %.1f m" % Zumbi.ouve_de(j, b))
	j.no_carro = false
	# noturno (05/11): de noite corre de longe (fora de PERTO); o comum anda
	main.ciclo.set_process(false)
	main.ciclo.tempo = Ciclo.DIA + 60.0
	main.ciclo._process(0.0)
	var zs: Array = main.zumbis.get_children().filter(func(q: Zumbi) -> bool: return not q.de_raid)
	var z: Zumbi = zs[0]
	for outro in main.zumbis.get_children():
		if outro != z:
			outro.free()
	z._sem_gritar = INF
	j.vida = 100000
	for noturno: bool in [true, false]:
		z.noturno = noturno
		j.global_position = Vector3(30, 0.1, -25)
		j.velocity = Vector3.ZERO
		z.global_position = Vector3(30, 0, 5)
		z.velocity = Vector3.ZERO
		z.alvo = j
		var maxv: float = 0.0
		for i in 90:
			await physics_frame
			maxv = maxf(maxv, Vector2(z.velocity.x, z.velocity.z).length())
		var andando: float = Zumbi.ANDAR * z._vel * Zumbi.NOITE_VEL * 1.1
		if noturno:
			ok(maxv > andando, "noturno corre de longe à noite (%.1f m/s)" % maxv)
		else:
			ok(maxv <= andando, "comum anda de longe à noite (%.1f m/s)" % maxv)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
