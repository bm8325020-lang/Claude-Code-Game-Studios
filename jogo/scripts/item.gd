# Item largado no chão (mecânica 11): caixa de munição ou lanterna. Fica parado no chão, sem brilho nem giro;
# quem chega perto vê o botão PEGAR. Quem decide se pegou é o servidor (ou o aparelho jogando sozinho):
# o item some para todos e volta no mesmo lugar depois de VOLTA segundos (provisório, para testar).
# Os itens fazem parte do mapa (mesmo nome em todos os aparelhos); só o "ativo" vai pela rede.
class_name Item
extends Node3D

const ALCANCE: float = 1.6   # m: perto assim aparece o PEGAR
const VOLTA: float = 60.0

## "municao" ou "lanterna"
@export var tipo: String = "municao"
@export var quantidade: int = 24
## false = já pegaram (escondido até voltar)
var ativo: bool = true:
	set(v):
		ativo = v
		visible = v
var _volta_t: float = 0.0


func _ready() -> void:
	add_to_group("itens")
	_monta_modelo()
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:ativo"))
	cfg.property_set_replication_mode(NodePath(".:ativo"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_config = cfg
	add_child(sync)


## Nome para o botão ("munição (24)", "lanterna").
func nome() -> String:
	return "munição (%d)" % quantidade if tipo == "municao" else "lanterna"


## O item ativo mais perto de `pos` a até ALCANCE, ou null.
static func perto(arvore: SceneTree, pos: Vector3) -> Item:
	var melhor: Item = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("itens"):
		var it := n as Item
		var d: float = it.global_position.distance_to(pos)
		if it.ativo and d < dist:
			dist = d
			melhor = it
	return melhor


## Servidor: `j` quer pegar este item. Confere e entrega. Retorna se pegou.
func pegar_por(j: Jogador) -> bool:
	if not ativo or j.vida <= 0 or j.global_position.distance_to(global_position) > ALCANCE + 0.6:
		return false
	if tipo == "lanterna" and j.tem_lanterna:
		return false
	ativo = false
	_volta_t = VOLTA
	j.ganhar(tipo, quantidade)
	return true


func _process(dt: float) -> void:
	if not ativo and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_volta_t -= dt
		if _volta_t <= 0.0:
			ativo = true


func _monta_modelo() -> void:
	if tipo == "municao":
		# caixa de munição de lata, verde-oliva, com tampa
		var lata := StandardMaterial3D.new()
		lata.albedo_color = Color(0.29, 0.33, 0.2)
		lata.roughness = 0.6
		lata.metallic = 0.3
		_bloco(Vector3(0, 0.07, 0), Vector3(0.3, 0.14, 0.14), lata)
		var tampa := StandardMaterial3D.new()
		tampa.albedo_color = Color(0.24, 0.27, 0.16)
		_bloco(Vector3(0, 0.145, 0), Vector3(0.31, 0.012, 0.15), tampa)
		var alca := StandardMaterial3D.new()
		alca.albedo_color = Color(0.1, 0.1, 0.1)
		_bloco(Vector3(0, 0.158, 0), Vector3(0.12, 0.012, 0.025), alca)

	else:
		# lanterna deitada no chão
		var corpo := StandardMaterial3D.new()
		corpo.albedo_color = Color(0.12, 0.12, 0.13)
		var c := CylinderMesh.new()
		c.top_radius = 0.032
		c.bottom_radius = 0.02
		c.height = 0.2
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = corpo
		mi.rotation.z = PI * 0.5
		mi.position.y = 0.032
		add_child(mi)


func _bloco(p: Vector3, tam: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = m
	mi.position = p
	add_child(mi)
