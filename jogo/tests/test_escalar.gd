# Escalar (sugestão do dono): pulou contra um muro que quase alcança, agarra a beirada e sobe; muro alto demais
# não; parado (sem empurrar para a frente) não.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_escalar.gd
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


# muro de altura `h` 1,5 m na frente da câmera (yaw 0 = +Z); pula andando (ou não) para ele e devolve a altura dos pés no fim
func tenta(h: float, anda: bool) -> float:
	var muro: StaticBody3D = main.bloco(Vector3(60, h * 0.5, 63.0), Vector3(4, h, 4.0), Color.GRAY)  # largo: para em cima
	j.global_position = Vector3(60, 0.05, 60)
	j.velocity = Vector3.ZERO
	j.camera.yaw = 0.0
	j.camera.pitch = 0.0
	await frames(20)
	j.entrada["move"] = Vector2(0, 1) if anda else Vector2.ZERO
	await frames(12)
	j.entrada["pular"] = true
	for i in 22:
		await frames(5)
		if OS.get_environment("DBG") != "":
			print("t=%d pos=%s vy=%.2f chao=%s sub=%.2f fr=%s" % [i * 5, j.global_position, j.velocity.y, j.is_on_floor(), j._subindo, -j.camera.cam.global_basis.z])
	j.entrada["move"] = Vector2.ZERO
	await frames(10)
	var y: float = j.global_position.y
	muro.free()
	await frames(5)
	return y


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("Teste")
	await frames(5)
	j = main.jogador
	main.controles.jogador = null
	for z in main.zumbis.get_children():
		z.free()
	var y: float = await tenta(1.6, true)
	ok(y > 1.5, "muro de 1,6 m: agarra e sobe (pés a %.2f m)" % y)
	y = await tenta(3.8, true)
	ok(y < 0.5, "muro de 3,8 m: alto demais, não sobe (%.2f m)" % y)
	y = await tenta(1.6, false)
	ok(y < 0.5, "pulando parado não sobe (%.2f m)" % y)
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
