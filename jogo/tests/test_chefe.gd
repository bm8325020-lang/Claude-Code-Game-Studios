# Personagens e habilidade do chefe: zumbis usam os modelos novos (o mesmo zumbi em todos os aparelhos), o chefe é
# o parasita, e a pancada no chão acerta quem está perto até de costas, empurra para fora e espera o intervalo.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_chefe.gd
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
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	var j: Jogador = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	var chefe: Zumbi = null
	var comuns: int = 0
	for z: Zumbi in main.zumbis.get_children():
		if z.chefe:
			chefe = z
		else:
			comuns += 1
	ok(chefe != null and chefe.modelo.scene_file_path.ends_with(Anims.CHEFE + ".fbx"), "o chefe é o parasita")
	ok(comuns > 0 and main.zumbis.get_children().all(func(z: Zumbi) -> bool: return z.chefe or Array(Anims.MODELOS_TIPO[z.tipo]).any(func(n: String) -> bool: return (z.modelo.scene_file_path.ends_with(n + ".fbx") or z.modelo.scene_file_path.ends_with(n + ".glb")))), "zumbis comuns com os modelos do tipo deles")
	ok(j.modelo.scene_file_path.ends_with(Anims.JOGADOR + ".fbx"), "jogador é o sobrevivente")
	for z: Zumbi in main.zumbis.get_children():
		if z != chefe:
			z.free()
	chefe._sem_gritar = INF
	chefe.set_physics_process(false)
	# de costas para o jogador, a 2,5 m: a pancada acerta mesmo assim e empurra para longe
	j.global_position = chefe.global_position - chefe.modelo.global_basis.z * 2.5 + Vector3(0, 0.1, 0)
	await frames(3)
	var v0: int = j.vida
	var d0: float = j.global_position.distance_to(chefe.global_position)
	chefe._pancada_t = 0.0
	chefe._ataca()
	ok(chefe._pancada and chefe._pancada_t > 0.0, "o chefe escolhe a pancada quando o intervalo passou")
	for i in 240:
		chefe._atualiza_ataque(1.0 / 60.0)
		await physics_frame
		if chefe._acertou:
			break
	await frames(20)
	ok(j.vida < v0, "a pancada acerta quem está atrás dele (%d -> %d)" % [v0, j.vida])
	ok(j.global_position.distance_to(chefe.global_position) > d0 + 0.5, "e empurra para fora (%.1f -> %.1f m)" % [d0, j.global_position.distance_to(chefe.global_position)])
	chefe._ataca()
	ok(not chefe._pancada, "logo depois volta ao soco (espera %d s)" % int(Zumbi.PANCADA_INTERVALO))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
