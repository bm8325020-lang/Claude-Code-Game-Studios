# História completa (07/11): zera do capítulo 1 ao helicóptero fazendo cada ação na ordem; cada passo só fecha com a
# ação dele (a ordem é obrigatória) e o fim abre a tela Final.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_historia.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0
var main: Node3D
var j: Jogador
var t: Tarefas


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func vai(p: Vector3) -> void:
	j.global_position = p + Vector3(0, 0.4, 0)
	j.velocity = Vector3.ZERO
	await frames(40)


## Luta obrigatória: mata o que nasce até o passo fechar (ou desiste em 60 s).
func limpa() -> void:
	var antes: int = t._i
	for k in 60:
		for z: Variant in t._onda_nos.duplicate():
			if z and is_instance_valid(z) and (z as Zumbi).vida > 0:
				(z as Zumbi).levar_golpe(1000000, Vector3.FORWARD, j)
		await frames(60)
		if t._i != antes:
			return


func passo(esperado: int, msg: String) -> void:
	ok(t._i == esperado, "%s (passo %d, está no %d: %s)" % [msg, esperado, t._i, t._linha.text])


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("TesteHistoria%d" % randi())
	await frames(30)
	j = main.jogador
	j.vida = 1000000
	t = main.controles._tarefas
	Zumbi.chance_mordida = 0.0
	j.mochila.tirar("facao", 1)  # teste nasce com facão/pistola; a história começa sem
	j.mochila.tirar("pistola", 1)
	passo(1, "teste começa no capítulo 1 (pegar o facão)")
	t.evento("segura")
	passo(1, "fora de ordem não conta")
	ok(t._itens.has("facao") and Minimapa.destino.is_finite(), "facão marcado no mapa")
	j.ganhar("facao", 1)
	await frames(2)
	passo(2, "facão -> raid na delegacia")
	ok(t._itens.has("pistola"), "pistola no arsenal da delegacia")
	j.ganhar("pistola", 1)
	await frames(2)
	passo(3, "pistola -> refúgio")
	j.entrou_segura.emit(true)
	await frames(2)
	passo(4, "refúgio -> defender o refúgio (luta obrigatória)")
	ok(t._onda_total > 0, "luta tem ondas de zumbis")
	await vai(j.global_position + Vector3(300, 0, 0))
	ok(t._onda_centro.distance_to(j.global_position) < float(t._cfg.raio) * 2.3, "fugir da luta te traz de volta")
	await limpa()
	passo(5, "defendeu o refúgio -> Dana")
	ok(t._npc.has("dana"), "Dana nasce na van")
	await vai(t._npc.dana.global_position + Vector3(1.5, 0, 0))
	for k in 120:  # a Dana fala tudo (com voz cada fala dura o que a voz durar)
		await frames(30)
		if t._i != 5:
			break
	passo(6, "Dana falou -> salvar o Tommy")
	ok(t._npc.has("tommy"), "Tommy cercado na rua")
	await vai(t._npc.tommy.global_position + Vector3(3, 0, 0))
	await limpa()
	passo(7, "salvou o Tommy -> escolta")
	await vai(t._npc.dana.global_position + Vector3(2, 0, 2))
	for k in 40:
		await frames(30)
		if t._i == 8:
			break
	passo(8, "Tommy chegou vivo na van -> hospital")
	ok(j.mochila.tem("espingarda"), "recompensa: espingarda")
	await vai(t._alvo)
	await frames(60 * 6)  # a cena de cinema do hospital
	passo(9, "chegou no hospital -> diário (com susto)")
	ok(t._itens.has("diario"), "diário da Mia no hospital")
	j.ganhar("diario", 1)
	await frames(2)
	passo(10, "diário -> Wade")
	var wade: Zumbi = t._chefe.get("wade")
	ok(wade != null and wade.humano(), "Wade Harlan nasce no mercado (saqueador)")
	wade.levar_golpe(1000000, Vector3.FORWARD, j)
	await frames(30)
	passo(11, "Wade morto -> pegar a bomba")
	ok(t._itens.has("bomba"), "Wade larga a bomba")
	j.ganhar("bomba", 1)
	await frames(2)
	passo(12, "bomba -> portão")
	var portao: Porta = main.bairro.get_node("Portao_0")
	portao.vida = 0
	portao.aberta = true
	await frames(30)
	passo(13, "portão explodido -> limpar as tendas")
	await vai(t._onda_centro + Vector3(4, 0, 0))
	await limpa()
	passo(14, "tendas limpas -> Mia")
	await vai(t._npc.mia.global_position + Vector3(1.5, 0, 0))
	for k in 120:  # a Mia fala tudo (com voz)
		await frames(30)
		if t._i != 14:
			break
	passo(15, "Mia falou -> antibiótico contra o tempo")
	ok(t._timer_t > 0.0, "o remédio tem relógio")
	j.ganhar("antibiotico", 1)
	await frames(30)
	passo(16, "antibiótico na Mia -> Mercer")
	var mercer: Zumbi = t._chefe.get("mercer")
	ok(mercer != null and mercer.chefe, "Sargento Mercer (chefe) na quarentena")
	await vai(mercer.global_position + Vector3(6, 0, 0))
	mercer.levar_golpe(mercer.vida - 10, Vector3.FORWARD, j)
	await frames(30)
	ok(t._chefe_fase, "chefe na metade chama reforço")
	mercer.levar_golpe(1000000, Vector3.FORWARD, j)
	await frames(30)
	passo(17, "Mercer morto -> peças do rádio")
	ok(t._itens.has("peca_radio"), "peças do rádio no mundo")
	for k in 3:
		j.ganhar("peca_radio", 1)
	await frames(2)
	passo(18, "3 peças -> torre")
	var sb: Subida = main.bairro.get_node("Subida_0")
	await vai(sb.cima)
	await frames(60 * 6)  # a cena de cinema da torre
	passo(19, "chamou do alto da torre -> fitas e heliponto")
	ok(t._heliponto.is_finite(), "heliponto marcado")
	await vai(t._heliponto)
	passo(20, "chegou no heliponto -> última noite")
	main.ciclo.tempo = Ciclo.DIA + 60.0
	await frames(30)
	t._resiste_t = Tarefas.NOITE_FINAL_T - 2.0
	await frames(60 * 4)
	passo(21, "aguentou -> helicóptero")
	ok(t._heli != null, "helicóptero vem")
	await frames(60 * 9)
	ok(t._i == 21, "não embarca antes de pousar")
	await vai(t._heli.global_position)
	passo(22, "entrou no helicóptero: fim")
	ok(t._trofeus.size() >= 3, "troféus (%d)" % t._trofeus.size())
	ok(root.get_children().any(func(n: Node) -> bool: return n is Final), "tela final com boletim e créditos")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
