# Boneco de treino para testar o facão: leva golpe, pisca, balança, mostra o dano, cai com a vida zerada
# e volta de pé depois de uns segundos. Fica no grupo "golpeavel" (o que o golpe do Jogador procura).
class_name BonecoTreino
extends StaticBody3D

const VIDA_MAX: int = 100
const VOLTA_EM: float = 3.0

var vida: int = VIDA_MAX
var caido: bool = false
var _corpo: Node3D
var _mat: StandardMaterial3D
var _tw: Tween


func _ready() -> void:
	add_to_group("golpeavel")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_corpo = Node3D.new()
	add_child(_corpo)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.72, 0.6, 0.42)  # saco de estopa
	var poste := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.06
	cil.bottom_radius = 0.08
	cil.height = 1.9
	poste.mesh = cil
	poste.position.y = 0.95
	_corpo.add_child(poste)
	var tronco := MeshInstance3D.new()
	var cap_m := CapsuleMesh.new()
	cap_m.radius = 0.3
	cap_m.height = 1.0
	tronco.mesh = cap_m
	tronco.position.y = 1.2
	tronco.material_override = _mat
	_corpo.add_child(tronco)
	var cabeca := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.18
	esf.height = 0.36
	cabeca.mesh = esf
	cabeca.position.y = 1.88
	cabeca.material_override = _mat
	_corpo.add_child(cabeca)


## Chamado pelo golpe: tira vida, balança para longe de quem bateu e mostra o número.
func levar_golpe(dano: int, dir: Vector3, _quem: Node) -> void:
	if caido:
		return
	vida = maxi(0, vida - dano)
	_numero(dano)
	_mat.albedo_color = Color(1, 0.35, 0.3)
	var eixo: Vector3 = Vector3.UP.cross(dir).normalized()
	if _tw:
		_tw.kill()
	_tw = create_tween()
	if vida <= 0:
		caido = true
		_tw.tween_property(_corpo, "quaternion", Quaternion(eixo, deg_to_rad(80)), 0.35).set_ease(Tween.EASE_IN)
		_tw.parallel().tween_property(_mat, "albedo_color", Color(0.5, 0.42, 0.3), 0.3)
		_tw.tween_interval(VOLTA_EM)
		_tw.tween_property(_corpo, "quaternion", Quaternion.IDENTITY, 0.6).set_trans(Tween.TRANS_BACK)
		_tw.parallel().tween_property(_mat, "albedo_color", Color(0.72, 0.6, 0.42), 0.6)
		_tw.tween_callback(func() -> void:
			vida = VIDA_MAX
			caido = false)
	else:
		_tw.tween_property(_corpo, "quaternion", Quaternion(eixo, deg_to_rad(18)), 0.08)
		_tw.parallel().tween_property(_mat, "albedo_color", Color(0.72, 0.6, 0.42), 0.25)
		_tw.tween_property(_corpo, "quaternion", Quaternion(eixo, deg_to_rad(-7)), 0.15)
		_tw.tween_property(_corpo, "quaternion", Quaternion.IDENTITY, 0.2)


func _numero(dano: int) -> void:
	var l := Label3D.new()
	l.text = str(dano)
	l.font_size = 64
	l.pixel_size = 0.005
	l.outline_size = 12
	l.modulate = Color(1, 0.9, 0.3) if dano < 40 else Color(1, 0.45, 0.2)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.position = Vector3(randf_range(-0.2, 0.2), 2.2, 0)
	var t := create_tween()
	t.tween_property(l, "position:y", 2.9, 0.6)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	t.tween_callback(l.queue_free)
