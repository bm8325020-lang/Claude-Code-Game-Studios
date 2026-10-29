# Jogador-robô para teste de carga: entra no servidor, anda, corre, mira e atira à toa por um tempo.
#   godot --headless --path . -s res://tools/carga.gd -- wss://endereço/jogo [segundos]
# Rodar vários ao mesmo tempo e olhar a página de status do servidor (jogadores, fisica_ms, memória).
extends SceneTree

var main: Node3D
var j: Jogador
var _troca: float = 0.0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var onde: String = args[0]
	var dura: float = float(args[1]) if args.size() > 1 else 120.0
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	main.entrar_partida(onde, "Robo%d" % (randi() % 1000))
	var espera: float = 0.0
	while main.jogador == null and espera < 60.0:
		await process_frame
		espera += 0.016
		OS.delay_msec(16)
	if main.jogador == null:
		print("CARGA: não entrou")
		quit(1)
		return
	j = main.jogador
	main.controles.jogador = null
	print("CARGA: entrou")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < dura * 1000.0 and is_instance_valid(j):
		_joga(0.016)
		await process_frame
		OS.delay_msec(16)
	print("CARGA: fim")
	quit(0)


func _joga(dt: float) -> void:
	_troca -= dt
	if _troca > 0.0:
		return
	_troca = randf_range(0.5, 2.0)
	j.entrada["move"] = Vector2(randf_range(-1, 1), randf_range(-0.3, 1)).limit_length(1.0)
	j.entrada["correr"] = randf() < 0.3
	j.entrada["pular"] = randf() < 0.15
	j.entrada["arma"] = "pistola" if randf() < 0.5 else "facao"
	j.entrada["mira_segurando"] = randf() < 0.4
	j.entrada["atacar"] = randf() < 0.5
	j.camera.virar(randf() * TAU)
