# Armadilha de latas (07/11, ideia aprovada): fio com latas no chão; zumbi a menos de RAIO m faz barulho e avisa
# quem armou (vibra, aviso, som). Uma vez só (as latas caem). Cada aparelho desenha; o aviso é de quem armou.
class_name Armadilha
extends Node3D

const RAIO: float = 2.5
var dono: Jogador
var _t: float = 0.0


func _ready() -> void:
	for k in 4:  # 4 latas penduradas no fio
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.035
		c.bottom_radius = 0.035
		c.height = 0.11
		c.radial_segments = 8
		mi.mesh = c
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.7, 0.68)
		m.metallic = 0.7
		m.roughness = 0.35
		mi.material_override = m
		mi.position = Vector3(-0.45 + k * 0.3, 0.06, 0)
		add_child(mi)
	var fio := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.2, 0.005, 0.005)
	fio.mesh = b
	fio.position.y = 0.12
	add_child(fio)


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.3
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z and z.vida > 0 and not z.humano() and z.global_position.distance_to(global_position) < RAIO:
			_dispara()
			return


func _dispara() -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = load("res://assets/sons/latas.wav")
	s.unit_size = 14.0
	get_parent().add_child(s)
	s.global_position = global_position
	s.finished.connect(s.queue_free)
	s.play()
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and dono and principal.jogador == dono and principal.controles:
		Input.vibrate_handheld(300)
		principal.controles.aviso("ALARME! ALGO PASSOU NA ARMADILHA", Color(1.0, 0.75, 0.2), 3.0)
	queue_free()
