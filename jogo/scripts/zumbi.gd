# Zumbi simples (mecânica 5): fica parado até ver ou ouvir alguém, vai até a pessoa desviando dos obstáculos
# (malha de navegação), ataca de perto, cambaleia quando leva golpe ou tiro, morre e levanta de novo no
# mesmo lugar depois de um tempo (por enquanto, para dar para treinar).
# Quem decide tudo é o servidor (ou o aparelho jogando sozinho); os outros só recebem posição, giro,
# animação e vida. Golpe e tiro de um cliente viram um pedido para o servidor.
class_name Zumbi
extends CharacterBody3D

const VIDA_MAX: int = 100
const VISAO: float = 18.0          # m: vê o jogador a essa distância (se nada tapa)
const OUVE: float = 5.0            # m: percebe mesmo sem ver (passos, barulho)
const DESISTE: float = 28.0        # m: perde o alvo
const ANDAR: float = 1.0           # m/s: alvo longe
const CORRER: float = 2.6          # m/s: alvo a menos de PERTO
const PERTO: float = 10.0
const ALCANCE: float = 1.35        # m: começa o ataque
const ALCANCE_ACERTO: float = 1.8  # m: o soco ainda pega se o alvo estiver até aqui na hora
const DANO: int = 15
const ACERTO: float = 0.45         # fração do clipe de ataque em que o soco pega
const CAMBALEIO: float = 0.45      # s parado depois de levar golpe
const MORTO_POR: float = 8.0       # s até levantar de novo
const GIRO: float = 7.0
const GRAVIDADE: float = 24.0
const RAIO: float = 0.35
const ALTURA: float = 1.75

## altura (acima dos pés) a partir da qual o tiro conta como na cabeça (o zumbi anda curvado)
var altura_cabeca: float = 1.4
var vida: int = VIDA_MAX:
	set(v):
		var antes: int = vida
		vida = v
		if is_inside_tree() and v <= 0 and antes > 0:
			_morre()
		elif is_inside_tree() and v > 0 and antes <= 0:
			_levanta()
var clipe_rede: String = "parado"
var pos_rede: Vector3
var rot_rede: float
var casa: Vector3                  # onde nasce e onde levanta
var alvo: Jogador

var modelo: Node3D
var anim: AnimationPlayer
var _agente: NavigationAgent3D
var _clipe: String = ""
var _ataque_t: float = -1.0
var _acertou: bool = false
var _cambaleio: float = 0.0
var _morto_t: float = 0.0
var _procura_t: float = 0.0
var _mat_pele: StandardMaterial3D


func _ready() -> void:
	add_to_group("golpeavel")
	collision_layer = 8
	collision_mask = 1 | 8
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RAIO
	cap.height = ALTURA
	cs.shape = cap
	cs.position.y = ALTURA * 0.5
	add_child(cs)
	modelo = (load(Anims.MODELO) as PackedScene).instantiate()
	add_child(modelo)
	_mat_pele = StandardMaterial3D.new()
	_mat_pele.albedo_color = Color(0.46, 0.5, 0.41)
	_mat_pele.roughness = 0.9
	var roupa := StandardMaterial3D.new()
	roupa.albedo_color = Color(0.24, 0.17, 0.14)
	roupa.roughness = 1.0
	for m: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		m.material_override = roupa if m.name.contains("Joints") else _mat_pele
	anim = AnimationPlayer.new()
	modelo.add_child(anim)
	anim.add_animation_library("", Anims.biblioteca_zumbi())
	_agente = NavigationAgent3D.new()
	_agente.radius = RAIO + 0.05
	_agente.height = ALTURA
	_agente.path_desired_distance = 0.6
	_agente.target_desired_distance = 0.5
	add_child(_agente)
	if casa == Vector3.ZERO:
		casa = global_position
	pos_rede = global_position
	rot_rede = modelo.rotation.y
	_monta_sincronia()
	_toca("parado", 0.0)
	anim.seek(randf() * 3.0, true)  # cada um num ponto da animação


func _monta_sincronia() -> void:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:pos_rede", ".:rot_rede"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for p: String in [".:clipe_rede", ".:vida"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_interval = 1.0 / 20.0
	sync.replication_config = cfg
	add_child(sync)


func _manda() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _physics_process(dt: float) -> void:
	if not _manda():
		global_position = global_position.lerp(pos_rede, 1.0 - exp(-14.0 * dt))
		if global_position.distance_to(pos_rede) > 4.0:
			global_position = pos_rede
		modelo.rotation.y = lerp_angle(modelo.rotation.y, rot_rede, 1.0 - exp(-14.0 * dt))
		_toca(clipe_rede, 0.2)
		return
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
	if vida <= 0:
		_morto_t -= dt
		if _morto_t <= 0.0:
			global_position = casa
			vida = VIDA_MAX
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_publica()
		return
	_procura_t -= dt
	if _procura_t <= 0.0:
		_procura_t = 0.3
		_escolhe_alvo()
	var desejada := Vector3.ZERO
	if _cambaleio > 0.0:
		_cambaleio -= dt
	elif _ataque_t >= 0.0:
		_atualiza_ataque(dt)
	elif alvo:
		var d: Vector3 = alvo.global_position - global_position
		d.y = 0.0
		if d.length() < ALCANCE:
			_vira_para(d, dt * 2.0)
			_ataca()
		else:
			_agente.target_position = alvo.global_position
			var prox: Vector3 = _agente.get_next_path_position() - global_position
			prox.y = 0.0
			if prox.length() < 0.05:
				prox = d  # sem malha (ou já no fim do caminho): vai reto
			var vel: float = CORRER if d.length() < PERTO else ANDAR
			desejada = prox.normalized() * vel
			_vira_para(prox, dt)
	var plano := Vector3(velocity.x, 0, velocity.z).move_toward(desejada, 12.0 * dt)
	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()
	if _ataque_t < 0.0 and _cambaleio <= 0.0:
		var v: float = plano.length()
		_toca("parado" if v < 0.2 else ("correr" if v > 1.6 else "andar"), 0.25)
		var base: float = float(Anims.VELOCIDADE_ZUMBI.get(_clipe, 0.0))
		anim.speed_scale = clampf(v / base, 0.6, 2.2) if base > 0.0 and v > 0.2 else 1.0
	_publica()


func _publica() -> void:
	pos_rede = global_position
	rot_rede = modelo.rotation.y
	clipe_rede = _clipe


func _vira_para(d: Vector3, dt: float) -> void:
	if d.length() > 0.01:
		modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(d.x, d.z), 1.0 - exp(-GIRO * dt))


# o jogador vivo mais perto que dá para ver (ou que está bem perto)
func _escolhe_alvo() -> void:
	if alvo and (not is_instance_valid(alvo) or alvo.vida <= 0 or alvo.global_position.distance_to(global_position) > DESISTE):
		alvo = null
	if alvo:
		return
	var melhor: float = INF
	for n: Node in get_tree().get_nodes_in_group("jogadores"):
		var j := n as Jogador
		if j == null or j.vida <= 0:
			continue
		var dist: float = j.global_position.distance_to(global_position)
		if dist < melhor and (dist < OUVE or (dist < VISAO and _ve(j))):
			melhor = dist
			alvo = j


func _ve(j: Jogador) -> bool:
	var olho: Vector3 = global_position + Vector3(0, 1.5, 0)
	var q := PhysicsRayQueryParameters3D.create(olho, j.global_position + Vector3(0, 1.4, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _ataca() -> void:
	_ataque_t = 0.0
	_acertou = false
	anim.speed_scale = 1.0
	_toca("ataque", 0.12, true)


func _atualiza_ataque(dt: float) -> void:
	_ataque_t += dt
	var dur: float = anim.get_animation("ataque").length
	if not _acertou and _ataque_t >= dur * ACERTO:
		_acertou = true
		if alvo and is_instance_valid(alvo):
			var d: Vector3 = alvo.global_position - global_position
			d.y = 0.0
			var frente: Vector3 = modelo.global_basis.z
			if d.length() < ALCANCE_ACERTO and rad_to_deg(Vector3(frente.x, 0, frente.z).angle_to(d)) < 70.0:
				alvo.levar_dano(DANO, d.normalized())
	if _ataque_t >= dur:
		_ataque_t = -1.0


## Golpe ou tiro (o facão e a pistola chamam isto). No cliente vira pedido ao servidor.
func levar_golpe(dano: int, dir: Vector3, _quem: Node) -> void:
	if vida <= 0:
		return
	_pisca()
	if _manda():
		_aplica(dano, dir)
	else:
		_pede_golpe.rpc_id(1, dano, dir)


@rpc("any_peer", "call_remote", "reliable")
func _pede_golpe(dano: int, dir: Vector3) -> void:
	# shortcut: o servidor confia no dano que o cliente manda; conferir alcance/arma quando houver servidor de verdade
	if multiplayer.is_server() and vida > 0:
		_aplica(clampi(dano, 0, 100), dir)


func _aplica(dano: int, dir: Vector3) -> void:
	vida = maxi(0, vida - dano)
	if vida > 0:
		_cambaleio = CAMBALEIO
		_ataque_t = -1.0
		_toca("dano", 0.08, true)
		velocity += Vector3(dir.x, 0, dir.z).normalized() * 2.0  # empurrão
		if alvo == null:  # quem bate chama a atenção
			_procura_t = 0.0


func _pisca() -> void:
	var t := create_tween()
	t.tween_property(_mat_pele, "albedo_color", Color(0.85, 0.3, 0.25), 0.04)
	t.tween_property(_mat_pele, "albedo_color", Color(0.46, 0.5, 0.41), 0.18)


func _morre() -> void:
	remove_from_group("golpeavel")
	collision_layer = 0
	_ataque_t = -1.0
	_cambaleio = 0.0
	alvo = null
	_morto_t = MORTO_POR
	anim.speed_scale = 1.0
	_toca("morte", 0.1, true)


func _levanta() -> void:
	add_to_group("golpeavel")
	collision_layer = 8
	_toca("parado", 0.3)


func _toca(clipe: String, mistura: float, de_novo: bool = false) -> void:
	if clipe == _clipe and not de_novo:
		return
	_clipe = clipe
	if anim.has_animation(clipe):
		anim.play(clipe, mistura)
		if de_novo:
			anim.seek(0.0, true)


## Clipe tocando agora (testes).
func clipe_atual() -> String:
	return _clipe
