# Gaveta / porta de armário dos móveis das casas (31/10, ideias do teste com novato): perto, o USAR revista. O servidor
# sorteia na hora: às vezes nada, às vezes um achado (Loot fácil). Fica aberta até REENCHE e fecha de novo.
# `chave`: guarda a chave de um cofre (Bau trancado) e a entrega na primeira revista; o bilhete do cofre diz onde é.
# O Bairro cria uma em cada móvel com gaveta (pelo nome da malha do Blender: criado, balcao, estante, guarda_roupa, tv).
class_name Gaveta
extends Node3D

const ALCANCE: float = 1.5
const REENCHE: float = 600.0
const CHANCE_VAZIA: float = 0.35
## altura da gaveta e quanto o móvel avança para a frente (+Z local = frente do móvel)
const MOVEIS: Dictionary = {
	"criado": [0.42, 0.2, "gaveta"], "balcao": [0.7, 0.3, "gaveta"], "estante": [0.5, 0.2, "gaveta"],
	"guarda_roupa": [0.45, 0.28, "armário"], "tv": [0.3, 0.23, "gaveta"],
}

var movel: String = "criado"
var sem_caixa: bool = false:  # móvel realista (Moveis): a gaveta de caixa fica escondida, mas abre e soa igual
	set(v):
		sem_caixa = v
		if _caixa:
			_caixa.visible = not v
var chave: bool = false
var aberta: bool = false:
	set(v):
		if v == aberta:
			return
		aberta = v
		_anima()
var _t: float = 0.0
var _caixa: Node3D
var _som: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("gavetas")
	var m: Array = MOVEIS[movel]
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.3, 0.22, 0.15)
	madeira.roughness = 0.9
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.5, 0.4)
	metal.metallic = 0.6
	_caixa = Node3D.new()
	_caixa.position = Vector3(0, float(m[0]), float(m[1]) - 0.16)
	add_child(_caixa)
	var frente := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.4, 0.13, 0.33)
	frente.mesh = b
	frente.material_override = madeira
	_caixa.add_child(frente)
	var puxador := MeshInstance3D.new()
	var p := BoxMesh.new()
	p.size = Vector3(0.12, 0.025, 0.025)
	puxador.mesh = p
	puxador.material_override = metal
	puxador.position = Vector3(0, 0, 0.18)
	_caixa.add_child(puxador)
	if not Rede.servidor_sem_tela:
		_som = AudioStreamPlayer3D.new()
		_som.stream = load("res://assets/sons/amb/rangido.ogg")
		_som.max_distance = 12.0
		add_child(_som)
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:aberta"))
	cfg.property_set_replication_mode(NodePath(".:aberta"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_config = cfg
	add_child(sync)
	_rng.seed = hash(name) ^ Time.get_ticks_usec()


## Texto do botão USAR.
func acao() -> String:
	return "revistar " + String(MOVEIS[movel][2])


func ponto() -> Vector3:
	return _caixa.global_position


## A gaveta fechada mais perto de `pos` a até ALCANCE (null se nenhuma).
static func perto(arvore: SceneTree, pos: Vector3) -> Gaveta:
	var melhor: Gaveta = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("gavetas"):
		var g := n as Gaveta
		if g.aberta:
			continue
		var q: Vector3 = g.ponto()
		var d: float = Vector2(q.x - pos.x, q.z - pos.z).length()
		if d < dist and absf(q.y - pos.y - 0.6) < 1.4:
			dist = d
			melhor = g
	return melhor


## Servidor: `j` revista. Confere distância; sorteia o que tem (ou entrega a chave do cofre).
func revista_por(j: Jogador) -> void:
	var q: Vector3 = ponto()
	if aberta or j.vida <= 0 or Vector2(q.x - j.global_position.x, q.z - j.global_position.z).length() > ALCANCE + 0.8:
		return
	aberta = true
	_t = REENCHE
	if chave:
		chave = false
		j.ganhar("chave", 1)
		return
	if _rng.randf() < CHANCE_VAZIA:
		j.ganhar("vazio", 0)
		return
	var achado: Array = Loot.sorteia(_rng, true)
	if achado.is_empty():
		j.ganhar("vazio", 0)
		return
	j.ganhar(String(achado[0].tipo), int(achado[0].qtd))


func _process(dt: float) -> void:
	if aberta and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_t -= dt
		if _t <= 0.0:
			aberta = false


func _anima() -> void:
	if _caixa == null:
		return
	var z: float = float(MOVEIS[movel][1]) - 0.16 + (0.26 if aberta else 0.0)
	create_tween().tween_property(_caixa, "position:z", z, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _som and aberta:
		_som.pitch_scale = _rng.randf_range(1.2, 1.6)
		_som.play()
