# Testes do barulho de quem se mexe (05/11, mods de zumbi do GTA V): correr ouve de mais longe, agachado de mais perto,
# dentro do carro vale o motor.
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_ouvir.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	main.iniciar_solo("Teste")
	for i in 5:
		await physics_frame
	var j: Jogador = main.jogador
	main.controles.jogador = null
	var b: float = Zumbi.OUVE
	ok(is_equal_approx(Zumbi.ouve_de(j, b), b), "andando: ouve a %.1f m" % b)
	j.correndo = true
	ok(is_equal_approx(Zumbi.ouve_de(j, b), b * Zumbi.OUVE_CORRENDO), "correndo: ouve a %.1f m" % Zumbi.ouve_de(j, b))
	j.correndo = false
	j.agachado = true
	ok(Zumbi.ouve_de(j, b) < b, "agachado: ouve a %.1f m" % Zumbi.ouve_de(j, b))
	j.agachado = false
	j.no_carro = true
	ok(Zumbi.ouve_de(j, b) >= Zumbi.OUVE_CARRO, "no carro: ouve o motor a %.1f m" % Zumbi.ouve_de(j, b))
	j.no_carro = false
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
