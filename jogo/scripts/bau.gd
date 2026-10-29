# Baú (mecânica 2 do loop): caixa de madeira com tampa. Quem chega perto vê ABRIR; abrir leva ABRIR_T parado.
# O servidor sorteia o conteúdo (Loot) e manda pela rede; pegar é pedido ao servidor, que confere distância e
# se o item ainda está lá. Vazio, se enche de novo depois de REENCHE segundos (provisório).
class_name Bau
extends StaticBody3D

const ALCANCE: float = 1.8
const ABRIR_T: float = 1.5
const REENCHE: float = 300.0

## cidade inicial: mais comida e água
@export var facil: bool = false
## [{"tipo", "qtd"}] — vai pela rede quando muda
var conteudo: Array = []
var _vazio_t: float = 0.0
var _tampa: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("baus")
	_monta()
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:conteudo"))
	cfg.property_set_replication_mode(NodePath(".:conteudo"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_config = cfg
	add_child(sync)
	if _manda():
		_rng.seed = hash(name) ^ Time.get_ticks_usec()
		conteudo = Loot.sorteia(_rng, facil)


func _manda() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## O baú usável mais perto de `pos` (null se nenhum).
static func perto(arvore: SceneTree, pos: Vector3) -> Bau:
	var melhor: Bau = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("baus"):
		var b := n as Bau
		var d: float = Vector2(b.global_position.x - pos.x, b.global_position.z - pos.z).length()
		if d < dist:
			dist = d
			melhor = b
	return melhor


## Servidor: `j` pega o item `i` (ou todos se i < 0). Confere distância e o que ainda tem.
func pega_por(j: Jogador, i: int) -> void:
	if j.vida <= 0 or Vector2(global_position.x - j.global_position.x, global_position.z - j.global_position.z).length() > ALCANCE + 0.8:
		return
	var novo: Array = conteudo.duplicate(true)
	var idx: Array = range(novo.size()) if i < 0 else [i]
	for k in range(idx.size() - 1, -1, -1):
		var n: int = idx[k]
		if n < 0 or n >= novo.size():
			continue
		j.ganhar(String(novo[n].tipo), int(novo[n].qtd))
		novo.remove_at(n)
	conteudo = novo  # reatribui: a sincronia só manda quando a propriedade muda
	if conteudo.is_empty():
		_vazio_t = REENCHE


func _process(dt: float) -> void:
	_tampa.rotation.x = lerp_angle(_tampa.rotation.x, deg_to_rad(-100.0) if conteudo.is_empty() else 0.0, 1.0 - exp(-6.0 * dt))
	if _manda() and conteudo.is_empty():
		_vazio_t -= dt
		if _vazio_t <= 0.0:
			conteudo = Loot.sorteia(_rng, facil)


# caixa de madeira escura com cantoneiras de metal e tampa (dobradiça atrás)
func _monta() -> void:
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.33, 0.22, 0.13)
	madeira.roughness = 0.85
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.22, 0.23)
	metal.metallic = 0.6
	metal.roughness = 0.5
	var corpo := Vector3(0.95, 0.5, 0.55)
	_bloco(self, Vector3(0, corpo.y * 0.5, 0), corpo, madeira)
	for x in [-1, 1]:
		_bloco(self, Vector3(x * corpo.x * 0.5, corpo.y * 0.5, 0), Vector3(0.03, corpo.y + 0.01, corpo.z + 0.01), metal)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = corpo + Vector3(0, 0.12, 0)
	cs.shape = bs
	cs.position.y = bs.size.y * 0.5
	add_child(cs)
	_tampa = Node3D.new()
	_tampa.position = Vector3(0, corpo.y, -corpo.z * 0.5)  # dobradiça na borda de trás
	add_child(_tampa)
	_bloco(_tampa, Vector3(0, 0.06, corpo.z * 0.5), Vector3(corpo.x + 0.02, 0.12, corpo.z + 0.02), madeira)
	_bloco(_tampa, Vector3(0, 0.02, corpo.z + 0.01), Vector3(0.12, 0.1, 0.03), metal)  # fecho


func _bloco(pai: Node3D, p: Vector3, tam: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	pai.add_child(mi)
