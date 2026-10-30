# Armas brancas (prompt 4 do loop): dano de cada uma no boneco, rapidez do golpe, empurrão do taco, achar no mapa.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_armas.gd
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
	var b: BonecoTreino = null
	for n in main.get_children():
		if n is BonecoTreino and (n as Node3D).global_position.distance_to(Vector3(-3, 0, 4)) < 0.1:
			b = n
	var dur: Dictionary = {}
	for tipo: String in ["facao", "faca", "taco", "machado"]:
		j.mochila.adicionar(tipo, 1)
		j.usar_espaco(j.mochila.onde(tipo))
		await frames(3)
		ok(j.arma == tipo, "barra rápida: %s na mão" % tipo)
		ok(j.modelo.find_children("*", "GeometryInstance3D", true, false).all(func(g: GeometryInstance3D) -> bool:
			return g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "%s da mão do corpo não aparece na própria tela" % tipo)
		b.vida = BonecoTreino.VIDA_MAX
		b.caido = false
		j.global_position = Vector3(-3, 0.1, 2.6)
		j.camera.virar(PI)
		await frames(10)
		j.entrada["atacar"] = true
		await frames(3)
		dur[tipo] = j._golpe_dur
		await frames(120)
		ok(b.vida == BonecoTreino.VIDA_MAX - int(Armas.BRANCAS[tipo].dano[0]), "%s tira %d (vida %d)" % [tipo, Armas.BRANCAS[tipo].dano[0], b.vida])
		await frames(240)
	ok(dur.faca < dur.facao and dur.facao < dur.taco and dur.taco < dur.machado, "faca é a mais rápida e o machado o mais lento (%s)" % str(dur))
	# empurrão: taco empurra mais que faca
	var empurro: Dictionary = {}
	for tipo: String in ["faca", "taco"]:
		var z := Zumbi.new()
		main.zumbis.add_child(z)
		await frames(2)
		z._sem_gritar = INF
		z.global_position = Vector3(30, 0, -18.8)
		z.vida = 1000
		await frames(5)
		var p0: Vector3 = z.global_position
		z.levar_golpe(10, Vector3.FORWARD * float(Armas.BRANCAS[tipo].empurra), j)
		await frames(10)
		empurro[tipo] = Vector2(z.global_position.x - p0.x, z.global_position.z - p0.z).length()
		z.free()
	ok(empurro.taco > empurro.faca * 1.5, "o taco empurra mais que a faca (%.2f x %.2f m)" % [empurro.taco, empurro.faca])
	# achar no mapa
	j.mochila.tirar("faca", 1)
	var it: Item = main.get_node("Item_branca_0")
	j.global_position = it.global_position + Vector3(0.6, 0.1, 0)
	await frames(5)
	j.entrada["pegar"] = true
	await frames(int(Jogador.PEGAR_DUR * 60) + 10)
	ok(j.mochila.tem("faca") and not it.ativo, "acha a faca no chão e guarda")
	# colado numa parede a arma recolhe (não atravessa); longe dela volta
	var m: Maos = root.find_children("*", "Maos", true, false)[0] if not root.find_children("*", "Maos", true, false).is_empty() else null
	if m:
		var paredes: Array = []  # caixa fechada em volta: olhando para qualquer lado tem parede
		for d: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			paredes.append(main.bloco(Vector3(40, 1.5, 40) + d * 0.6, Vector3(1.6, 3, 0.2) if d.x == 0 else Vector3(0.2, 3, 1.6), Color.GRAY))
		j.global_position = Vector3(40, 0.1, 40)
		await frames(40)
		var colado: float = m._parede
		for p: Node in paredes:
			p.free()
		await frames(40)
		ok(colado > 0.3 and m._parede < 0.1, "arma recolhe colada na parede (%.2f) e volta longe (%.2f)" % [colado, m._parede])
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
