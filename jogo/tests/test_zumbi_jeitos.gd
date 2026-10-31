# Zumbis diferentes (31/10): cada um anda/fica parado do seu jeito; rastejante baixo; alguns comendo um corpo e quase
# não percebem; golpe forte derruba e ele levanta; tiro no carro dispara o alarme e chama os zumbis.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_zumbi_jeitos.gd
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
	j._jogo_t = Jogador.NOVATO_T
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	var zs: Array = main.zumbis.get_children()
	# variedade: jeitos de ficar parado e de andar diferentes entre os zumbis
	var parados: Dictionary = {}
	var andares: Dictionary = {}
	var tipos: Dictionary = {}
	var comendo: Zumbi = null
	for z: Zumbi in zs:
		parados[z._real("parado")] = true
		andares[z._real(Zumbi.TIPOS[z.tipo].andar)] = true
		tipos[z.tipo] = true
		if z.come and comendo == null:
			comendo = z
	ok(parados.size() >= 5, "jeitos de ficar parado (%d)" % parados.size())
	ok(andares.size() >= 5, "jeitos de andar (%d)" % andares.size())
	ok(tipos.has("zumbi_rastejante"), "tem rastejante")
	for z: Zumbi in zs:
		ok(z.anim.has_animation(z._real("parado")) and z.anim.has_animation(z._real(Zumbi.TIPOS[z.tipo].andar)), "animação existe (%s)" % z.name)
		break
	# comendo: parado em casa come e quase não percebe
	ok(comendo != null, "alguns zumbis estão comendo um corpo")
	for z in zs:
		if z != comendo:
			z.free()
	comendo.global_position = comendo.casa
	j.global_position = comendo.casa + Vector3(6, 0.1, 0)  # perto o bastante para um zumbi normal ouvir (OUVE 9 m)
	await frames(100)  # zumbi longe de todos dorme e só reconfere a cada 1 s
	ok(comendo.clipe_atual() == "comendo", "parado em casa, come (%s)" % comendo.clipe_atual())
	ok(comendo.alvo == null, "comendo não ouve a 6 m")
	j.global_position = comendo.casa + Vector3(2.5, 0.1, 0)
	await frames(40)
	ok(comendo.alvo == j, "chegou bem perto: larga o corpo e vem")
	# golpe forte derruba
	comendo.alvo = null
	var derrubou: bool = false
	for k in 12:
		comendo.vida = 500
		comendo._deitado = false
		comendo._no_chao_t = 0.0
		comendo.levar_golpe(40, Vector3.FORWARD, j)
		if comendo._no_chao_t > 0.0:
			derrubou = true
			break
	ok(derrubou and comendo.clipe_atual() == "deitado", "golpe forte derruba")
	var v0: int = comendo.vida
	comendo.levar_golpe(10, Vector3.FORWARD, j)
	ok(v0 - comendo.vida == 15, "caído leva mais dano (%d)" % (v0 - comendo.vida))
	await frames(int(Zumbi.NO_CHAO_T * 60) + 10)
	ok(not comendo._deitado, "levanta sozinho")
	# rastejante: colisor baixo
	Zumbi.tipo_fixo = "zumbi_rastejante"
	var r := Zumbi.new()
	r.name = "Rastejante_teste"
	main.zumbis.add_child(r)
	r.global_position = Vector3(40, 0.1, 40)
	await frames(5)
	Zumbi.tipo_fixo = ""
	ok((r._forma.shape as CapsuleShape3D).height < 1.0 and r._real("parado") == "rastejar", "rastejante é baixo e se arrasta")
	# alarme
	var car: Carro = get_nodes_in_group("carros")[0]
	comendo.global_position = car.global_position + Vector3(30, 0, 0)
	comendo.alvo = null
	comendo._ouvido = Vector3.INF
	j.global_position = car.global_position + Vector3(0, 0.1, 8)
	car.dispara_alarme()
	await frames(3)
	ok(comendo._ouvido.distance_to(car.global_position) < 1.0, "alarme de carro chama o zumbi a 30 m")
	print("JEITOS: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
