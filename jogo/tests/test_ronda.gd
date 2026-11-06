# Ronda (07/11, dono: "coloca eles pra rondar, meio mortos"): zumbi sem alvo anda devagar em volta de casa; e só vê o
# jogador na frente (de costas, a 10 m, não vê).
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_ronda.gd
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
	await frames(10)
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	var j: Jogador = main.jogador
	j.vida = 100000
	j.global_position = Vector3(30, 0.1, -40)  # longe (20 m+), mas perto o bastante para o zumbi não dormir
	var z := Zumbi.new()
	z.tipo_fixo = "zumbi_policial"
	z.position = Vector3(30, 0, -12)
	z.casa = z.position
	main.zumbis.add_child(z)
	await frames(2)
	z.come = false  # comendo um corpo não ronda (o sorteio do nome às vezes dá)
	await frames(60 * 25)
	var andou: float = Vector2(z.global_position.x - 30, z.global_position.z + 12).length()
	ok(andou > 1.0 and andou < Zumbi.RONDA_RAIO + 3.0, "ronda em volta de casa (%.1f m)" % andou)
	ok(z.alvo == null, "rondando não acha o jogador longe")
	j.global_position = z.global_position + z.modelo.global_basis.z * -10.0 + Vector3(0, 0.1, 0)  # atrás dele
	Zumbi.ronda_ligada = false
	z._indo_ouvir = false
	z.velocity = Vector3.ZERO
	await frames(30)
	ok(z.alvo == null, "de costas não vê o jogador a 10 m")
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
