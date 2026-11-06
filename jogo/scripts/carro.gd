# Carro dirigível (prompt 18, primeira parte; pedido do dono, 31/10): entra e sai pelo botão USAR (E), dirige com o
# analógico (frente acelera, trás freia/dá ré, lado vira). Os carros inteiros largados no Bairro viram Carro.
# Rede: o servidor decide quem dirige (`motorista`, peer id; 0 = vazio). Quem dirige roda a física no aparelho dele e
# manda a posição ao servidor (`_estado`), que confere e repassa a todos pelo sincronizador (`pos_rede`/`rot_rede`).
# Frente do modelo = +Z. Rodas: raios de separação (sobe meio-fio sem travar a caixa).
# 06/11 (dono: "coloque carros já prontos"): sedã pronto ("Medium sized sedan", MaG80, Sketchfab CC BY;
# assets/mundo/veiculos/sedan.glb) com as rodas girando e virando, e vidro que estoura com tiro (`leva_tiro`).
class_name Carro
extends CharacterBody3D

const ALCANCE: float = 3.2         # m do centro do carro para o botão ENTRAR aparecer
const TAM: Vector3 = Vector3(1.8, 1.1, 4.4)
const VAO: float = 0.35            # altura da caixa acima do chão (as rodas seguram)
const BANCO: Vector3 = Vector3(0.0, 0.3, 0.0)  # onde fica o jogador (some; a câmera vai atrás do carro: CameraPrimeira)
const VEL_MAX: float = 14.0        # m/s (~50 km/h)
const VEL_RE: float = 4.0
const ACEL: float = 6.0
const FREIO: float = 16.0
const ATRITO: float = 2.5
const GIRO: float = 1.7            # rad/s com o volante todo (menos em alta: GIRO_ALTA)
const GIRO_ALTA: float = 0.55      # parte do giro que sobra na velocidade máxima
const VOLANTE: float = 3.5         # quão rápido o volante chega aonde o dedo manda (sem tranco)
var volante: float = 0.0
const GRAVIDADE: float = 24.0
const MANDA_A_CADA: float = 0.05
const PULO_MAX: float = 30.0       # servidor: mais que isso por pacote é trapaça/erro e é ignorado
const MODELO := "res://assets/mundo/veiculos/sedan.glb"
const ESCALA: float = 0.465        # o arquivo vem em outra unidade: 9,9 de comprimento -> 4,6 m
const RAIO_RODA: float = 0.35
## vidro estourado (vai pela rede): some o vidro e fica caco no chão
var vidro_quebrado: bool = false:
	set(v):
		if v and not vidro_quebrado and is_inside_tree():
			_estoura()
		vidro_quebrado = v
var _vidros: Array[MeshInstance3D] = []
var _rodas: Array[Node3D] = []  # FL, FR, RL, RR (as da frente esterçam)
var _giro_roda: float = 0.0
var _pintura: Color = Color(0.45, 0.12, 0.1)

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
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.get_active_material(0)
		if m is BaseMaterial3D:
			_pintura = (m as BaseMaterial3D).albedo_color
			break
	if not ResourceLoader.exists(MODELO):  # sem o sedã: fica o modelo velho
		for n: Node in visual.find_children("*_col", "StaticBody3D", true, false):
			n.free()
		visual.reparent(self, false)
		return
	visual.free()
	var modelo: Node3D = (load(MODELO) as PackedScene).instantiate()
	modelo.scale = Vector3.ONE * ESCALA
	modelo.position.y = 0.34  # roda do arquivo no chão
	add_child(modelo)
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		var nome: String = String(mi.name)
		if nome.begins_with("Shadow"):
			mi.visible = false  # sombra pintada do Sketchfab: o jogo tem sombra de verdade
		elif nome.contains("Glass") and not nome.contains("Light"):
			_vidros.append(mi)
		elif nome.contains("CarPaint"):
			var p := (mi.get_active_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
			p.albedo_color = _pintura.lerp(Color(0.5, 0.5, 0.5), 0.2)
			p.roughness = 0.75  # pintura velha, sem brilho de concessionária
			mi.set_surface_override_material(0, p)
	for n: String in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var r: Node3D = modelo.find_child(n, true, false)
		if r:
			_rodas.append(r)
	if vidro_quebrado:
		for v: MeshInstance3D in _vidros:
			v.visible = false


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
	for p: String in [".:motorista", ".:pos_rede", ".:rot_rede", ".:vidro_quebrado"]:
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
	volante = move_toward(volante, mov.x, VOLANTE * dt)
	var giro: float = -volante * GIRO * lerpf(1.0, GIRO_ALTA, clampf(absf(vel) / VEL_MAX, 0.0, 1.0)) * clampf(absf(vel) / 3.0, 0.0, 1.0) * signf(vel) * dt
	rotation.y += giro
	var frente: Vector3 = global_basis.z
	velocity.x = frente.x * vel
	velocity.z = frente.z * vel
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVIDADE * dt
	move_and_slide()
	vel = get_real_velocity().dot(frente)  # bateu: perde a velocidade que não andou
	_gira_rodas(dt)
	if multiplayer.is_server():
		pos_rede = position
		rot_rede = rotation.y
	else:
		_manda_t -= dt
		if _manda_t <= 0.0:
			_manda_t = MANDA_A_CADA
			_estado.rpc_id(1, position, rotation.y)
	return giro


## Alarme (tiro no carro): toca ALARME_T s em todos e chama os zumbis a até ALARME_RAIO; cada carro uma vez por
## ALARME_PAUSA (no aparelho de quem atirou).
const ALARME_T: float = 9.0
const ALARME_RAIO: float = 55.0
const ALARME_PAUSA: float = 90.0
var _alarme_pausa: float = 0.0
var _alarme: AudioStreamPlayer3D


func dispara_alarme() -> void:
	if Time.get_ticks_msec() / 1000.0 < _alarme_pausa:
		return
	_alarme_pausa = Time.get_ticks_msec() / 1000.0 + ALARME_PAUSA
	_toca_alarme.rpc()


@rpc("any_peer", "call_local", "reliable")
func _toca_alarme() -> void:
	Zumbi.barulho(get_tree(), global_position, ALARME_RAIO)
	if Rede.servidor_sem_tela:
		return
	if _alarme == null:
		_alarme = AudioStreamPlayer3D.new()
		_alarme.stream = load("res://assets/sons/alarme.wav")
		_alarme.max_db = 6.0
		_alarme.unit_size = 14.0
		_alarme.max_distance = 120.0
		add_child(_alarme)
	_alarme.play()
	get_tree().create_timer(ALARME_T).timeout.connect(func() -> void:
		if is_instance_valid(_alarme):
			_alarme.stop())


## Tiro pegou no carro em `ponto`: na altura das janelas o vidro estoura (em todos os aparelhos).
func leva_tiro(ponto: Vector3) -> void:
	if not vidro_quebrado and (ponto - global_position).dot(global_basis.y) > VAO + TAM.y * 0.55:
		_quebra.rpc()


@rpc("any_peer", "call_local", "reliable")
func _quebra() -> void:
	if multiplayer.is_server():
		vidro_quebrado = true  # o servidor guarda e o sincronizador espalha (quem entrar depois vê quebrado)
	elif not vidro_quebrado:
		_estoura()


# vidro some, cacos voam e o barulho de vidro estourando chama zumbi perto
func _estoura() -> void:
	for v: MeshInstance3D in _vidros:
		v.visible = false
	Zumbi.barulho(get_tree(), global_position, 18.0)
	if Rede.servidor_sem_tela:
		return
	var cacos := CPUParticles3D.new()
	cacos.one_shot = true
	cacos.emitting = true
	cacos.amount = 40
	cacos.lifetime = 1.2
	cacos.explosiveness = 0.95
	cacos.position = Vector3(0, VAO + TAM.y * 0.8, 0)
	cacos.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cacos.emission_box_extents = Vector3(0.9, 0.2, 1.2)
	cacos.direction = Vector3.UP
	cacos.spread = 80.0
	cacos.initial_velocity_min = 1.5
	cacos.initial_velocity_max = 4.0
	cacos.gravity = Vector3(0, -9.8, 0)
	var q := BoxMesh.new()
	q.size = Vector3(0.03, 0.005, 0.03)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.8, 0.85, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.5
	m.roughness = 0.1
	q.material = m
	cacos.mesh = q
	add_child(cacos)
	var som := AudioStreamPlayer3D.new()
	som.stream = Carro.som_vidro()
	som.unit_size = 10.0
	add_child(som)
	som.play()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(cacos):
			cacos.queue_free()
		if is_instance_valid(som):
			som.queue_free())


static var _som_vidro: AudioStream


## Estouro de vidro: arquivo gravado se existir (assets/sons/vidro.ogg), senão chiado curto.
static func som_vidro() -> AudioStream:
	if _som_vidro == null:
		if ResourceLoader.exists("res://assets/sons/vidro.ogg"):
			_som_vidro = load("res://assets/sons/vidro.ogg")
		else:
			var w := AudioStreamWAV.new()
			w.mix_rate = 22050
			w.format = AudioStreamWAV.FORMAT_8_BITS
			var d := PackedByteArray()
			var n: int = int(22050 * 0.35)
			d.resize(n)
			for i in n:
				d[i] = int(randf_range(-1, 1) * 110.0 * exp(-float(i) / n * 6.0)) & 0xFF
			w.data = d
			_som_vidro = w
	return _som_vidro


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
	if position.distance_squared_to(pos_rede) < 0.0001 and absf(angle_difference(rotation.y, rot_rede)) < 0.001:
		if vel != 0.0:
			vel = 0.0
		return  # parado onde devia: não mexe no corpo (62 carros mexendo todo quadro pesavam na física)
	var antes: Vector3 = position
	if position.distance_to(pos_rede) > 8.0:
		position = pos_rede
	else:
		position = position.lerp(pos_rede, 1.0 - exp(-12.0 * dt))
	rotation.y = lerp_angle(rotation.y, rot_rede, 1.0 - exp(-12.0 * dt))
	vel = (position - antes).dot(global_basis.z) / maxf(dt, 0.001) if position.distance_to(antes) < 2.0 else vel
	_gira_rodas(dt)


# rodas do modelo pronto: rolam com a velocidade e as da frente esterçam com o volante
func _gira_rodas(dt: float) -> void:
	if _rodas.size() < 4:
		return
	_giro_roda += vel * dt / RAIO_RODA
	for k in 4:
		var esterco: float = -volante * 0.5 if k < 2 else 0.0
		_rodas[k].rotation = Vector3(_giro_roda, esterco, 0)
