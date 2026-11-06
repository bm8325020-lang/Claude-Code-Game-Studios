# Armas de fogo novas (05/11): espingarda (8 chumbos, cartucho), fuzil (automático, munição de fuzil), sniper (luneta),
# cada uma com o pacote de braços dela na tela; munição separada por arma; saco junta a munição certa; minimapa.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_armas_fogo.gd
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
	for z in main.zumbis.get_children():
		z.free()
	ok(j.fogos.size() == Pistola.FOGO.size(), "uma Pistola por arma de fogo (%d)" % j.fogos.size())
	for t: String in ["espingarda", "fuzil", "sniper"]:
		ok(Jogador.e_fogo(t), t + " é arma de fogo")
		ok(Mochila.NOMES.has(t) and Mochila.TEXTOS.has(t), t + " tem nome e texto na mochila")
		var ap: Array = j.camera.maos._rigs[t].find_children("*", "AnimationPlayer", true, false)
		ok(not ap.is_empty() and (ap[0] as AnimationPlayer).has_animation(Maos.ANIMS[t].fire), t + ": pacote de braços com a animação de tiro")
		ok((ap[0] as AnimationPlayer).has_animation(Maos.ANIMS[t].reload), t + ": animação de recarga")
	ok(j.fogos.espingarda.municao == "cartucho" and j.fogos.fuzil.municao == "municao_fuzil" and j.pistola.municao == "municao", "munição de cada arma")
	# espingarda: saca, atira num zumbi de perto: vários chumbos acertam, gasta 1 cartucho
	j.global_position = Vector3(-20, 0.1, 30)
	j.camera.virar(0.0, 0.0)
	j.mochila.adicionar("espingarda", 1)
	j.mochila.adicionar("cartucho", 12)
	j.entrada["arma"] = "espingarda"
	await frames(3)
	ok(j.arma == "espingarda" and j.fogos.espingarda.visible and not j.pistola.visible, "saca a espingarda")
	var z: Zumbi = main.spawner_zumbis.spawn({"pos": j.global_position + Vector3(0, 0, -3.5), "tipo": "zumbi_policial"})
	await frames(5)
	if z:
		z.set_physics_process(false)
		z.global_position = j.global_position + Vector3(0, 0, -3.5)
		var v0: int = z.vida
		var e: Pistola = j.fogos.espingarda
		var b0: int = e.balas
		var r: Array[Vector3] = j.raio_mira()
		var res: Dictionary = e.atirar(r[0], (z.global_position + Vector3(0, 1.0, 0) - r[0]).normalized(), true)
		await frames(2)
		ok(res.atirou and e.balas == b0 - 1, "um tiro gasta um cartucho")
		ok(v0 - z.vida > e.dano, "vários chumbos acertam de perto (dano %d > %d de um chumbo)" % [v0 - z.vida, e.dano])
	# recarga usa cartucho, não a munição 9 mm
	var e2: Pistola = j.fogos.espingarda
	e2.balas = 0
	var nove: int = j.mochila.conta("municao")
	var c0: int = j.mochila.conta("cartucho")
	e2.recarregar()
	await frames(int(e2.recarga * 60) + 10)
	ok(e2.balas > 0 and j.mochila.conta("cartucho") < c0 and j.mochila.conta("municao") == nove, "recarrega com cartucho (%d)" % e2.balas)
	# fuzil: tem seletor (MODO)
	j.mochila.adicionar("fuzil", 1)
	j.entrada["arma"] = "fuzil"
	await frames(3)
	ok(j.arma == "fuzil" and j.fogo().automatica, "fuzil sacado e com seletor")
	j.entrada["modo"] = true
	await frames(2)
	ok(not j.fogos.fuzil.modo_auto, "MODO troca o fuzil para tiro a tiro")
	# sniper: mirando abre a luneta (braços somem, fov fecha)
	j.mochila.adicionar("sniper", 1)
	j.entrada["arma"] = "sniper"
	await frames(3)
	j.mira_travada = true
	await frames(30)
	ok(j.camera.maos.luneta() and not j.camera.maos.visible, "sniper mirando: luneta, braços somem")
	ok(j.camera.cam.fov < 30.0, "luneta fecha o fov (%.0f)" % j.camera.cam.fov)
	j.mira_travada = false
	# saco: as balas dos pentes vão como a munição de cada arma
	var cont: Array = Jogador.conteudo_para_saco(j.mochila, {"cartucho": 3, "municao_fuzil": 5})
	var tem: Dictionary = {}
	for d: Dictionary in cont:
		tem[d.tipo] = d.qtd
	ok(int(tem.get("cartucho", 0)) >= 3 and int(tem.get("municao_fuzil", 0)) == 5, "saco junta cartucho e munição de fuzil dos pentes")
	# minimapa: frente (norte, -Z) aparece acima da seta; à direita (+X) aparece à direita
	var mm := Minimapa.new()
	mm.jogador = j
	var c: Vector2 = Minimapa.CENTRO * Minimapa.TAM
	ok(mm.no_quadro(j.global_position + Vector3(0, 0, -20)).y < c.y - 5.0, "minimapa: norte para cima olhando para o norte")
	ok(mm.no_quadro(j.global_position + Vector3(20, 0, 0)).x > c.x + 5.0, "minimapa: leste à direita")
	mm._ang = PI / 2.0  # olhando para o oeste (-X): o oeste fica para cima
	ok(mm.no_quadro(j.global_position + Vector3(-20, 0, 0)).y < c.y - 5.0, "minimapa gira com a câmera")
	mm.free()
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(1 if falhas else 0)
