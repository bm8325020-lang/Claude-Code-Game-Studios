# Carro dirigível (prompt 18, primeira parte; pedido do dono, 31/10): entra e sai pelo botão USAR (E), dirige com o
# analógico (frente acelera, trás freia/dá ré, lado vira). Os carros inteiros largados no Bairro viram Carro.
# Rede: o servidor decide quem dirige (`motorista`, peer id; 0 = vazio). Quem dirige roda a física no aparelho dele e
# manda a posição ao servidor (`_estado`), que confere e repassa a todos pelo sincronizador (`pos_rede`/`rot_rede`).
# Frente do modelo = +Z. Rodas: raios de separação (sobe meio-fio sem travar a caixa).
class_name Carro
extends CharacterBody3D

const ALCANCE: float = 3.2         # m do centro do carro para o botão ENTRAR aparecer
const TAM: Vector3 = Vector3(1.8, 1.1, 4.4)
const VAO: float = 0.35            # altura da caixa acima do chão (as rodas seguram)
const BANCO: Vector3 = Vector3(0.0, 0.1, -1.6)  # onde fica o jogador: olhos acima do porta-malas (o modelo é fechado por dentro)
const VEL_MAX: float = 14.0        # m/s (~50 km/h)
const VEL_RE: float = 4.0
const ACEL: float = 6.0
const FREIO: float = 16.0
const ATRITO: float = 2.5
const GIRO: float = 1.6            # rad/s com o volante todo
const GRAVIDADE: float = 24.0
const MANDA_A_CADA: float = 0.05
const PULO_MAX: float = 30.0       # servidor: mais que isso por pacote é trapaça/erro e é ignorado

var motorista: int = 0:
	set(v):
		if v == motorista:
			return
		var antes: int = motorista
		motorista = v
		_mudou_motorista(antes)
var pos_rede: Vector3
var rot_rede: float = 0.0
var vel: float = 0.0               # m/s para a frente (negativo = ré)
var _manda_t: float = 0.0


## Bairro: põe o modelo do Blender dentro e troca a colisão parada dele pela do carro.
func monta(visual: Node3D) -> void:
	for n: Node in visual.find_children("*_col", "StaticBody3D", true, false):
		n.free()
	visual.reparent(self, false)


func _ready() -> void:
	add_to_group("carros")
	collision_layer = 1
	collision_mask = 1  # só o mundo: zumbi e jogador são empurrados para fora, não param o carro
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = 0.5
	var caixa := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = TAM
	caixa.shape = b
	caixa.position.y = VAO + TAM.y * 0.5
	add_child(caixa)
	for x: float in [-0.8, 0.8]:
		for z: float in [-1.4, 1.35]:
			var roda := CollisionShape3D.new()
			var r := SeparationRayShape3D.new()
			r.length = VAO + 0.1
			r.slide_on_slope = true
			roda.shape = r
			roda.position = Vector3(x, VAO + 0.1, z)
			roda.rotation.x = PI * 0.5  # o raio vai pelo +Z da forma: aponta para baixo
			add_child(roda)
	pos_rede = position
	rot_rede = rotation.y
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:motorista", ".:pos_rede", ".:rot_rede"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.delta_interval = MANDA_A_CADA
	sync.replication_config = cfg
	add_child(sync)


## O carro vazio mais perto de `pos` a até ALCANCE, ou null.
static func perto(arvore: SceneTree, pos: Vector3) -> Carro:
	var melhor: Carro = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("carros"):
		var c := n as Carro
		var d: float = Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
		if c.motorista == 0 and d < dist:
			dist = d
			melhor = c
	return melhor


func _eu() -> int:
	return multiplayer.get_unique_id()


func _dirijo() -> bool:
	return motorista != 0 and motorista == _eu()


# todos: quem entrou é o jogador daqui? então ele senta; se era ele e o servidor tirou, ele sai
func _mudou_motorista(antes: int) -> void:
	vel = 0.0
	velocity = Vector3.ZERO
	var principal := get_tree().get_first_node_in_group("principal") if is_inside_tree() else null
	var j: Jogador = principal.jogador if principal else null
	if j == null or not is_instance_valid(j):
		return
	if _dirijo() and j.carro == null:
		j.entra_no_carro(self)
	elif antes == _eu() and j.carro == self:
		j.sai_do_carro()


## Jogador daqui quer entrar (o servidor confere).
func pede() -> void:
	if multiplayer.is_server():
		pede_entrar()
	else:
		pede_entrar.rpc_id(1)


## Jogador daqui saiu: manda onde o carro ficou.
func larga() -> void:
	if not _dirijo():
		return
	if multiplayer.is_server():
		pede_sair(position, rotation.y)
	else:
		pede_sair.rpc_id(1, position, rotation.y)


@rpc("any_peer", "call_local", "reliable")
func pede_entrar() -> void:
	if not multiplayer.is_server() or motorista != 0:
		return
	var id: int = _quem()
	var principal := get_tree().get_first_node_in_group("principal")
	var j := principal.jogadores.get_node_or_null(str(id)) as Jogador if principal else null
	if principal and principal.jogador and id == _eu():
		j = principal.jogador
	if j == null or j.vida <= 0 or j.global_position.distance_to(global_position) > ALCANCE + 1.5:
		return
	motorista = id


@rpc("any_peer", "call_local", "reliable")
func pede_sair(p: Vector3, r: float) -> void:
	if not multiplayer.is_server() or _quem() != motorista:
		return
	_estado_srv(p, r)
	motorista = 0


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _estado(p: Vector3, r: float) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == motorista:
		_estado_srv(p, r)


func _estado_srv(p: Vector3, r: float) -> void:
	if p.distance_to(position) > PULO_MAX:
		return
	position = p
	rotation.y = r
	pos_rede = p
	rot_rede = r


func _quem() -> int:
	var id: int = multiplayer.get_remote_sender_id()
	return id if id != 0 else _eu()


## Quem dirige: um passo da física com o analógico (y acelera/freia, x vira). Devolve quanto o carro girou.
func dirige(mov: Vector2, dt: float) -> float:
	var gas: float = mov.y
	if gas > 0.1:
		vel = move_toward(vel, VEL_MAX * gas, (ACEL if vel >= 0.0 else FREIO) * dt)
	elif gas < -0.1:
		vel = move_toward(vel, VEL_RE * gas, (FREIO if vel > 0.0 else ACEL) * dt)
	else:
		vel = move_toward(vel, 0.0, ATRITO * dt)
	# vira mais quanto mais anda (parado não gira); de ré o volante inverte, como num carro de verdade
	var giro: float = -mov.x * GIRO * clampf(absf(vel) / 4.0, 0.0, 1.0) * signf(vel) * dt
	rotation.y += giro
	var frente: Vector3 = global_basis.z
	velocity.x = frente.x * vel
	velocity.z = frente.z * vel
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVIDADE * dt
	move_and_slide()
	vel = get_real_velocity().dot(frente)  # bateu: perde a velocidade que não andou
	if multiplayer.is_server():
		pos_rede = position
		rot_rede = rotation.y
	else:
		_manda_t -= dt
		if _manda_t <= 0.0:
			_manda_t = MANDA_A_CADA
			_estado.rpc_id(1, position, rotation.y)
	return giro


## Onde o jogador desce: do lado do motorista, do outro lado, atrás ou na frente (o primeiro livre).
func saida() -> Vector3:
	var forma := CapsuleShape3D.new()
	forma.radius = Jogador.RAIO
	forma.height = Jogador.ALTURA_EM_PE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	q.exclude = [get_rid()]
	for o: Vector3 in [Vector3(1.5, 0, -0.2), Vector3(-1.5, 0, -0.2), Vector3(0, 0, -3.0), Vector3(0, 0, 3.0)]:
		var p: Vector3 = global_transform * o + Vector3(0, 0.05, 0)
		q.transform = Transform3D(Basis(), p + Vector3(0, Jogador.ALTURA_EM_PE * 0.5 + 0.05, 0))
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return p
	return global_position + Vector3(0, VAO + TAM.y + 0.1, 0)  # tudo fechado: sai pelo teto


func _physics_process(dt: float) -> void:
	if _dirijo():
		return  # o Jogador chama dirige()
	if position.distance_to(pos_rede) > 8.0:
		position = pos_rede
	else:
		position = position.lerp(pos_rede, 1.0 - exp(-12.0 * dt))
	rotation.y = lerp_angle(rotation.y, rot_rede, 1.0 - exp(-12.0 * dt))
