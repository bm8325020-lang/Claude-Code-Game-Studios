# Bancada de trabalho (mecânica 6 do loop): mesa com morsa e ferramentas num ponto sorteado da cidade; a cada
# MUDA segundos o servidor leva para outro ponto e avisa todo mundo. Perto dela dá para fabricar (TelaBancada).
class_name Bancada
extends StaticBody3D

const MUDA: float = 600.0  # 10 min reais (dá tempo de se espalhar e procurar, até de carro)
const ALCANCE: float = 2.2

## onde ela pode aparecer (pontos da cidade)
var pontos: Array = []
var _muda_t: float = MUDA
var _rng := RandomNumberGenerator.new()
## avisa quando mudou de lugar (o principal manda o aviso para todos)
signal mudou_de_lugar


func _ready() -> void:
	add_to_group("bancada")
	_monta()
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	cfg.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_config = cfg
	add_child(sync)
	_rng.randomize()
	if _manda() and not pontos.is_empty():
		position = pontos[_rng.randi() % pontos.size()]


func _manda() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func perto(pos: Vector3) -> bool:
	return Vector2(global_position.x - pos.x, global_position.z - pos.z).length() < ALCANCE


## Servidor: leva a bancada para outro ponto (nunca o mesmo).
func muda_de_lugar() -> void:
	if pontos.size() < 2:
		return
	var agora: Vector3 = position
	while position.is_equal_approx(agora):
		position = pontos[_rng.randi() % pontos.size()]
	_muda_t = MUDA
	mudou_de_lugar.emit()


func _process(dt: float) -> void:
	if _manda():
		_muda_t -= dt
		if _muda_t <= 0.0:
			muda_de_lugar()


# mesa de madeira grossa, morsa de ferro numa ponta, chaves e martelo em cima
func _monta() -> void:
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.4, 0.28, 0.17)
	madeira.roughness = 0.9
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.2, 0.22, 0.24)
	ferro.metallic = 0.5
	ferro.roughness = 0.55
	var azul := StandardMaterial3D.new()
	azul.albedo_color = Color(0.15, 0.27, 0.45)  # morsa pintada
	azul.roughness = 0.6
	_bloco(Vector3(0, 0.88, 0), Vector3(1.6, 0.08, 0.7), madeira)  # tampo
	for x in [-0.72, 0.72]:
		for z in [-0.28, 0.28]:
			_bloco(Vector3(x, 0.42, z), Vector3(0.08, 0.84, 0.08), madeira)
	_bloco(Vector3(0, 0.25, 0), Vector3(1.5, 0.04, 0.6), madeira)  # prateleira de baixo
	_bloco(Vector3(0.55, 0.98, 0.18), Vector3(0.22, 0.12, 0.14), azul)  # morsa
	_bloco(Vector3(0.55, 1.06, 0.18), Vector3(0.24, 0.04, 0.05), ferro)
	_bloco(Vector3(-0.3, 0.935, -0.1), Vector3(0.3, 0.025, 0.04), ferro).rotation_degrees.y = 20.0  # chave
	_bloco(Vector3(-0.05, 0.94, 0.15), Vector3(0.05, 0.04, 0.12), ferro)  # cabeça do martelo
	_bloco(Vector3(-0.05, 0.935, 0.0), Vector3(0.025, 0.025, 0.24), madeira)  # cabo do martelo
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 0.95, 0.7)
	cs.shape = b
	cs.position.y = 0.475
	add_child(cs)


func _bloco(p: Vector3, tam: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	add_child(mi)
	return mi
