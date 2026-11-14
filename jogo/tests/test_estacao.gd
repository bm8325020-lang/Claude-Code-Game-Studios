# Estação Halverson, etapa 1 (14/11, ESTACAO.md): portas de cartão, o Paciente Zero (ouvir, ver, perseguir, UV,
# esconderijo visto/não visto) e a porta do bunker com os 3 cartões até a fuga.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_estacao.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0
var main: Node3D
var j: Jogador
var e: Estacao
var eventos: Array = []


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _vai(local: Vector3) -> void:
	j.global_position = e.to_global(local) + Vector3(0, 0.2, 0)
	j.velocity = Vector3.ZERO
	await frames(6)


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
	j.item_pego.connect(func(t: String, _q: int) -> void: eventos.append(t))
	e = Estacao.atual
	ok(e != null, "a estação está no mapa")
	if e == null:
		print("test_estacao: %d checks, %d falhas" % [checks, falhas])
		quit(1)
		return

	# portas de cartão
	var lab: Porta = e.get_node("PortaLab")
	ok(lab.cartao == "verde", "porta do laboratório pede o cartão verde")
	await _vai(Vector3(3.0, 0, -0.4))
	j._tenta_pegar()
	await frames(10)
	ok(not lab.aberta and lab.cartao == "verde" and eventos.has("cartao_falta:verde"), "sem cartão não abre")
	j.mochila.adicionar("cartao_verde", 1)
	j._tenta_pegar()
	await frames(10)
	ok(lab.aberta and lab.cartao == "", "com o cartão verde abre e destranca")
	ok(e.get_node_or_null("CartaoAzul") is Item and e.get_node_or_null("FiltroUV") is Item, "cartão azul e filtro UV no laboratório")

	# o Paciente Zero: ouve, vê, persegue
	var pz: PacienteZero = main.spawner_zumbis.spawn({"pos": e.to_global(Vector3(10.0, 0.2, -8.0)), "pz": true})
	await frames(10)
	ok(pz.is_in_group("paciente_zero") and not pz.is_in_group("zumbis"), "Paciente Zero no mapa (fora da conta dos zumbis)")
	await _vai(Vector3(-15.0, 0, 9.0))  # portaria, longe
	Zumbi.barulho(self, e.to_global(Vector3(6.0, 0, -4.0)), 30.0)
	ok(pz.estado == PacienteZero.INVESTIGA, "barulho: ele vai investigar (%s)" % pz.estado_nome)
	await _vai(Vector3(6.0, 0, -6.0))
	pz.modelo.rotation.y = atan2((j.global_position - pz.global_position).x, (j.global_position - pz.global_position).z)
	var viu: bool = false
	for k in 90:
		await physics_frame
		pz.modelo.rotation.y = atan2((j.global_position - pz.global_position).x, (j.global_position - pz.global_position).z)
		if pz.estado == PacienteZero.PERSEGUE:
			viu = true
			break
	ok(viu, "viu de frente e começou a perseguir (%s)" % pz.estado_nome)
	ok(pz.luz_em(pz.global_position) < 0, "dentro da estação é escuro para ele (mais rápido)")
	ok(pz.ve(j), "enxerga o jogador no escuro do laboratório")

	# UV na cara: recua; logo depois fica imune
	j.mochila.adicionar("filtro_uv", 1)
	j.alterna_uv()
	ok(j.uv, "filtro UV liga a luz UV")
	j.carga = 100.0
	pz.set_physics_process(false)  # parado para mirar
	await _vai(Vector3(6.0, 0, -4.0))
	var queimou: bool = false
	for k in 120:
		var cabeca: Vector3 = pz.global_position + Vector3(0, pz.altura_cabeca, 0)
		var d: Vector3 = cabeca - j.camera.cam.global_position
		j.camera.virar(atan2(-d.x, -d.z), -asin(clampf(d.normalized().y, -1.0, 1.0)))
		await process_frame
		if pz.estado == PacienteZero.RECUA:
			queimou = true
			break
	ok(queimou, "UV na cara queima: ele recua (%s, lanterna %s)" % [pz.estado_nome, j.lanterna_acesa])
	ok(j.carga < 100.0 - Jogador.UV_CUSTO + 5.0, "queimar gasta pilha")
	pz.queima()
	ok(pz._imune_t > 0.0, "depois de queimado fica imune um tempo")
	pz.set_physics_process(true)

	# esconderijo: visto entrando = arrancado; sem ser visto = ele não acha
	pz._muda(PacienteZero.PATRULHA)
	pz._imune_t = 0.0
	pz.global_position = e.to_global(Vector3(-3.0, 0.2, 6.0))
	await _vai(Vector3(-4.6, 0, 4.1))
	pz._quem = j
	pz._muda(PacienteZero.PERSEGUE)
	pz._sem_ver = 0.0
	var arm: Esconderijo = e.get_node("ArmarioAloj_1")
	j.esconde(arm)
	ok(j.escondido and not j.modelo.visible, "entrou no armário (some)")
	ok(pz._viu_esconder == j, "ele viu entrar")
	var morreu: bool = false
	for k in 300:
		await physics_frame
		if j.vida <= 0 or eventos.has("arrancado"):
			morreu = true
			break
	ok(morreu, "visto entrando: ele abre e pega")
	await frames(5)
	ok(not j.escondido, "quem foi arrancado não fica escondido")
	j.vida = 100
	pz._viu_esconder = null
	pz._muda(PacienteZero.PATRULHA)
	pz.global_position = e.to_global(Vector3(15.0, 0.2, -10.0))
	await _vai(Vector3(-4.6, 0, 3.0))
	j.esconde(e.get_node("ArmarioAloj_0"))
	pz.global_position = e.to_global(Vector3(-3.5, 0.2, 3.0))
	await frames(20)
	ok(j.escondido and not pz.ve(j), "escondido sem ser visto: ele não acha")
	j.sai_do_esconderijo()
	await frames(3)
	ok(not j.escondido and j.collision_mask != 0, "sai do armário e volta a andar")
	pz.free()

	# bunker: pede os 3 cartões; com eles, abre e foge
	var bk: Bunker = e.get_node("Bunker")
	await _vai(Vector3(3.0, 0, -11.0))
	j.mochila.tirar("cartao_verde", 1)
	j._tenta_pegar()
	await frames(3)
	ok(bk.contagem < 0.0 and eventos.any(func(t: String) -> bool: return t.begins_with("bunker_falta")), "bunker sem os cartões não liga")
	for c: String in Bunker.CARTOES:
		j.mochila.adicionar("cartao_" + c, 1)
	j._tenta_pegar()
	await frames(3)
	ok(bk.contagem > 0.0, "com os 3 cartões o alarme liga (%.0f s)" % bk.contagem)
	bk.contagem = 0.05
	await frames(20)
	ok(bk.aberto, "a porta do bunker abre")
	await _vai(Vector3(3.0, 0, -10.8))
	ok(eventos.has("fugiu"), "quem entra no túnel foge")

	print("test_estacao: %d checks, %d falhas" % [checks, falhas])
	quit(1 if falhas > 0 else 0)
