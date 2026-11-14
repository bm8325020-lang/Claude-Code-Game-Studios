# Porta (mecânica 12): o jogador abre e fecha (botão USAR / tecla E); fechada, segura os zumbis, que socam
# até arrombar. Arrombada fica aberta e não fecha até ser consertada sozinha depois de CONSERTO segundos
# (provisório, para testar). Quem decide é o servidor; "aberta" e "vida" vão pela rede.
# Fica na camada 16 (fora da malha de navegação): o zumbi planeja o caminho pela entrada e só descobre a
# porta fechada quando chega nela.
class_name Porta
extends Node3D

const CAMADA: int = 16
const ALCANCE: float = 1.8
const VIDA_MAX: int = 100
const CONSERTO: float = 90.0
const LARGURA: float = 1.3
const ALTURA: float = 2.15
## Largura desta porta (a das casas de modelo segue o vão do modelo).
var largura: float = LARGURA
## Portão blindado (quarentena, 07/11): não abre com USAR nem quebra com soco; só a bomba arromba (Bomba).
var blindada: bool = false
## 14/11 (Estação Halverson): porta trancada por cartão ("verde", "azul", "amarelo"); "" = sem tranca. Quem tem o
## cartão destranca para todos (vai pela sincronia); trancada não abre nem quebra.
var cartao: String = ""
## Cor da folha (madeira; o portão da quarentena é grade de metal escura).
var cor: Color = Color(0.36, 0.25, 0.16)

var aberta: bool = false:
	set(v):
		aberta = v
		_anima()
var vida: int = VIDA_MAX:
	set(v):
		vida = v
		set_process(v <= 0)  # anti-travamento: só conta o conserto quando está arrombada
		if _mat:
			_mat.albedo_color = cor.lerp(cor * 0.55, 1.0 - float(v) / VIDA_MAX)
var _folha: AnimatableBody3D
var _mat: StandardMaterial3D
var _conserto_t: float = 0.0
var _tw: Tween


func _ready() -> void:
	add_to_group("portas")
	set_process(vida <= 0)
	# dobradiça na origem; a folha vai para +X e abre girando para dentro (-Z local)
	_folha = AnimatableBody3D.new()
	_folha.collision_layer = CAMADA
	_folha.collision_mask = 0
	_folha.sync_to_physics = false
	add_child(_folha)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(largura, ALTURA, 0.06)
	cs.shape = b
	cs.position = Vector3(largura * 0.5, ALTURA * 0.5, 0)
	_folha.add_child(cs)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = cor
	_mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = b.size
	mi.mesh = m
	mi.material_override = _mat
	mi.position = cs.position
	_folha.add_child(mi)
	var mac := MeshInstance3D.new()  # maçaneta
	var e := SphereMesh.new()
	e.radial_segments = 12  # anti-lag: o padrão do Godot é 64
	e.rings = 6
	e.radius = 0.035
	e.height = 0.07
	mac.mesh = e
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.52, 0.45)
	metal.metallic = 0.7
	mac.material_override = metal
	mac.position = Vector3(largura - 0.12, 1.0, 0.06)
	_folha.add_child(mac)
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:aberta", ".:vida", ".:cartao"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_config = cfg
	add_child(sync)


func _anima() -> void:
	if _folha == null:
		return
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_folha, "rotation:y", deg_to_rad(-100.0) if aberta else 0.0, 0.45).set_trans(Tween.TRANS_SINE)


## Centro da passagem (para saber se alguém está perto).
func centro() -> Vector3:
	return global_transform * Vector3(largura * 0.5, 0, 0)


## 07/11 (ideia aprovada): barricada de tábuas (item "tabuas" perto da porta fechada). Vale em todo aparelho.
var barricada: bool = false
var _tabuas: Array[MeshInstance3D] = []


@rpc("any_peer", "call_local", "reliable")
func barrica() -> void:
	if arrombada() or blindada or barricada:
		return
	aberta = false
	barricada = true
	vida = VIDA_MAX
	if Rede.servidor_sem_tela:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.33, 0.2)
	m.roughness = 1.0
	for k in 3:  # três tábuas cruzando a porta
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(LARGURA + 0.3, 0.16, 0.05)
		mi.mesh = b
		mi.material_override = m
		mi.position = Vector3(0, 0.55 + k * 0.55, 0.08)
		mi.rotation.z = [0.25, -0.2, 0.15][k]
		add_child(mi)
		_tabuas.append(mi)


@rpc("any_peer", "call_local", "reliable")
func _tira_tabuas() -> void:
	barricada = false
	for t: MeshInstance3D in _tabuas:
		t.queue_free()
	_tabuas.clear()


func arrombada() -> bool:
	return vida <= 0


## Texto do botão USAR.
func acao() -> String:
	if arrombada():
		return ""
	if blindada:
		return "trancado: precisa de BOMBA"
	return "fechar porta" if aberta else "abrir porta"


## A porta usável mais perto de `pos` a até ALCANCE, ou null.
static func perto(arvore: SceneTree, pos: Vector3) -> Porta:
	var melhor: Porta = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("portas"):
		var p := n as Porta
		var d: float = Vector2(p.centro().x - pos.x, p.centro().z - pos.z).length()
		if not p.arrombada() and d < dist:
			dist = d
			melhor = p
	return melhor


## Servidor: alguém pediu para abrir/fechar.
func alterna_por(j: Jogador) -> void:
	if arrombada() or j.vida <= 0 or blindada:
		return
	if cartao != "":
		cartao = ""  # shortcut: o servidor confia que o cliente tem o cartão (Jogador confere antes de pedir)
	if barricada:  # quem está dentro arranca as tábuas para sair
		_tira_tabuas.rpc() if multiplayer.has_multiplayer_peer() else _tira_tabuas()
	var d: Vector3 = centro() - j.global_position
	if Vector2(d.x, d.z).length() > ALCANCE + 0.6:
		return
	aberta = not aberta


## Servidor: soco de zumbi na porta fechada.
func leva_soco(dano: int) -> void:
	if aberta or arrombada() or blindada or cartao != "":
		return
	if barricada:
		dano = maxi(1, dano / 4)  # 07/11: tábuas pregadas: o zumbi demora 4x mais
	vida = maxi(0, vida - dano)
	if vida <= 0 and barricada:
		_tira_tabuas()
	var t := create_tween()  # treme
	t.tween_property(_folha, "rotation:y", deg_to_rad(-4.0), 0.05)
	t.tween_property(_folha, "rotation:y", 0.0, 0.1)
	if vida == 0:
		aberta = true
		_conserto_t = CONSERTO


func _process(dt: float) -> void:
	if arrombada() and not blindada and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):  # explodido fica aberto
		_conserto_t -= dt
		if _conserto_t <= 0.0:
			vida = VIDA_MAX
			aberta = false
