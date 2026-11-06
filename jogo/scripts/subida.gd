# Subida (07/11, E5): escada da torre de água. Pisar no pé dela leva ao alto (ver a cidade de longe); pisar na beira
# lá em cima desce. Igual ao alçapão do porão (Porao): áreas nos dois pontos, só o jogador local, com espera.
class_name Subida
extends Node3D

const ESPERA: float = 1.0

var baixo: Vector3  # global
var cima: Vector3   # global (em cima do teto da torre)
var lado: Vector3 = Vector3.RIGHT  # para onde fica a escada (a área de descer fica na beira desse lado)


func _ready() -> void:
	_area(baixo + Vector3(0, 0.8, 0), Vector3(1.4, 1.6, 1.4)).body_entered.connect(_vai.bind(true))
	_area(cima + lado * 3.2 + Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 1.2)).body_entered.connect(_vai.bind(false))
	if Rede.servidor_sem_tela:
		return
	var esc := MeshInstance3D.new()  # escada encostada (só aparência)
	var m := BoxMesh.new()
	m.size = Vector3(0.6, cima.y - baixo.y, 0.12)
	esc.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.3, 0.26)
	esc.material_override = mat
	add_child(esc)
	esc.global_position = baixo + Vector3(0, (cima.y - baixo.y) * 0.5, 0) - lado * 0.4


func _area(pos: Vector3, tam: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = tam
	cs.shape = f
	a.add_child(cs)
	add_child(a)
	a.global_position = pos
	return a


func _vai(corpo: Node3D, subir: bool) -> void:
	var j := corpo as Jogador
	if j == null or not j.local or j.vida <= 0 or j.carro != null:
		return
	var agora: int = Engine.get_physics_frames()
	if agora < int(j.get_meta("subida_t", 0)):
		return
	j.set_meta("subida_t", agora + int(ESPERA * Engine.physics_ticks_per_second))
	j.global_position = (cima + Vector3(0, 0.2, 0)) if subir else (baixo + lado * 1.6 + Vector3(0, 0.2, 0))
	j.velocity = Vector3.ZERO
