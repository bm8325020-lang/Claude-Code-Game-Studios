# Começo da história só no soco (06/11, dono): nasce sem facão/pistola, soco "roubado" (forte, longe) acerta o boneco,
# e a primeira arma branca achada já vai para a mão.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_soco.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	Jogador.inicio_vazio = true
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("TesteSoco")
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.free()
	ok(j.arma == "punhos", "nasce no soco (%s)" % j.arma)
	ok(not j.mochila.tem("facao") and not j.mochila.tem("pistola") and not j.mochila.tem("taco_pregos"), "sem armas na mochila")
	var b: BonecoTreino = null
	for n in main.get_children():
		if n is BonecoTreino and (n as Node3D).global_position.distance_to(Vector3(-3, 0, 4)) < 0.1:
			b = n
	b.vida = BonecoTreino.VIDA_MAX
	j.global_position = Vector3(-3, 0.1, 2.1)  # 1,9 m: o facão (1,8) não alcançaria
	j.camera.virar(PI)
	await frames(10)
	j.entrada["atacar"] = true
	await frames(120)
	ok(b.vida == BonecoTreino.VIDA_MAX - int(Armas.BRANCAS.punhos.dano[0]), "soco acerta longe e forte (vida %d)" % b.vida)
	j.entrada["trocar"] = true  # sem arma de fogo: continua no soco, não trava
	await frames(5)
	ok(j.arma == "punhos" or Pistola.FOGO.has(j.arma) == false, "trocar sem arma não quebra (%s)" % j.arma)
	j.ganhar("taco", 1)
	await frames(3)
	ok(j.arma == "taco", "achou arma: já vai para a mão (%s)" % j.arma)
	Jogador.inicio_vazio = false
	print("SOCO: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
