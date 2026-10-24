# Zumbi simples (mecânica 5): fica parado até ver ou ouvir alguém, vai até a pessoa desviando dos obstáculos
# (malha de navegação), ataca de perto, cambaleia quando leva golpe ou tiro, morre e levanta de novo no
# mesmo lugar depois de um tempo (por enquanto, para dar para treinar).
# Mecânica 6: ouve tiro (Zumbi.barulho) e vai até o lugar do barulho; chegando, procura em volta e, se não
# achar ninguém, volta para casa.
# Mecânica 7: chama a horda. Ao achar alguém, para e grita; os zumbis a até GRITO_RAIO sem alvo vêm atrás da
# mesma pessoa, mesmo sem ver. Grita no máximo uma vez a cada GRITO_PAUSA (os chamados não gritam de novo).
# Mecânica 8: cercar. Vários atrás da mesma pessoa se espalham em volta dela (cada um vai para um lado, na
# ordem em que já estão, para não se cruzarem) e só fecham quando chegam perto.
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
const VAI_OUVIR: float = 2.0       # m/s indo até um barulho
const PROCURA: float = 4.0         # s olhando em volta onde ouviu
const VOLTA: float = 0.9           # m/s voltando para casa
const GRITO_RAIO: float = 22.0
const GRITO_PAUSA: float = 20.0
const CERCO: float = 3.0           # m: distância do ponto de cerco até o alvo
const FECHA: float = 1.8           # m: com o alvo colado assim, ataca mesmo sem ter chegado no seu lado

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
var _ouvido: Vector3               # onde ouviu o último barulho
var _indo_ouvir: bool = false
var _olhando_t: float = 0.0        # > 0: chegou no barulho e está procurando em volta
var _voltando: bool = false
var _cerco_ang: float = NAN        # ângulo (em volta do alvo) do lado que este zumbi pegou; NAN = vai direto
var _fechando: bool = false        # já chegou no seu lado do cerco: agora vai direto no alvo
var _grito_t: float = -1.0         # >= 0: gritando (parado)
var _sem_gritar: float = 0.0       # > 0: não grita de novo ainda
var _som: AudioStreamPlayer3D
static var _som_grito: AudioStreamWAV
var _mat_pele: StandardMaterial3D


func _ready() -> void:
	add_to_group("golpeavel")
	add_to_group("zumbis")
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
	_som = AudioStreamPlayer3D.new()
	_som.max_db = 6.0
	_som.unit_size = 6.0
	add_child(_som)
	if _som_grito == null:
		_som_grito = _gera_grito()
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
	_sem_gritar -= dt
	if _procura_t <= 0.0:
		_procura_t = 0.3
		_escolhe_alvo()
		_calcula_cerco()
	var desejada := Vector3.ZERO
	if _cambaleio > 0.0:
		_cambaleio -= dt
	elif _grito_t >= 0.0:
		_grito_t -= dt
		if alvo and is_instance_valid(alvo):
			_vira_para(alvo.global_position - global_position, dt)
	elif _ataque_t >= 0.0:
		_atualiza_ataque(dt)
	elif alvo:
		var d: Vector3 = alvo.global_position - global_position
		d.y = 0.0
		if d.length() < ALCANCE:
			_vira_para(d, dt * 2.0)
			_ataca()
		else:
			var destino: Vector3 = alvo.global_position
			if d.length() > CERCO * 2.5:
				_fechando = false  # o alvo fugiu: monta o cerco de novo
			if not is_nan(_cerco_ang) and not _fechando and d.length() > FECHA:
				var lado: Vector3 = destino + Vector3(sin(_cerco_ang), 0, cos(_cerco_ang)) * CERCO
				if _plano(lado - global_position) < 1.0:
					_fechando = true
				else:
					destino = lado
			desejada = _caminho(destino, CORRER if d.length() < PERTO else ANDAR, dt)
	elif _olhando_t > 0.0:
		_olhando_t -= dt
		modelo.rotation.y += dt * 1.2 * signf(sin(_olhando_t * 1.5))  # vira de um lado para o outro
		if _olhando_t <= 0.0:
			_voltando = true
	elif _indo_ouvir:
		if _plano(_ouvido - global_position) < 1.5:
			_indo_ouvir = false
			_olhando_t = PROCURA
		else:
			desejada = _caminho(_ouvido, VAI_OUVIR, dt)
	elif _voltando:
		if _plano(casa - global_position) < 0.8:
			_voltando = false
		else:
			desejada = _caminho(casa, VOLTA, dt)
	var plano := Vector3(velocity.x, 0, velocity.z).move_toward(desejada, 12.0 * dt)
	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()
	if _ataque_t < 0.0 and _cambaleio <= 0.0 and _grito_t < 0.0:
		var v: float = plano.length()
		_toca("parado" if v < 0.2 else ("correr" if v > 1.6 else "andar"), 0.25)
		var base: float = float(Anims.VELOCIDADE_ZUMBI.get(_clipe, 0.0))
		anim.speed_scale = clampf(v / base, 0.6, 2.2) if base > 0.0 and v > 0.2 else 1.0
	_publica()


# velocidade desejada para ir até `destino` pela malha de navegação
func _caminho(destino: Vector3, vel: float, dt: float) -> Vector3:
	_agente.target_position = destino
	var prox: Vector3 = _agente.get_next_path_position() - global_position
	prox.y = 0.0
	if prox.length() < 0.05:
		prox = destino - global_position  # sem malha (ou já no fim do caminho): vai reto
		prox.y = 0.0
	_vira_para(prox, dt)
	return prox.normalized() * vel


static func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Um barulho em `ponto`: os zumbis vivos a até `raio` metros, sem alvo, vão ver o que foi. Só no servidor.
static func barulho(arvore: SceneTree, ponto: Vector3, raio: float) -> void:
	for n: Node in arvore.get_nodes_in_group("zumbis"):
		(n as Zumbi).ouve(ponto, raio)


func ouve(ponto: Vector3, raio: float) -> void:
	if vida <= 0 or alvo != null or global_position.distance_to(ponto) > raio:
		return
	_ouvido = ponto
	_indo_ouvir = true
	_olhando_t = 0.0
	_voltando = false


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
		if is_instance_valid(alvo) and alvo.vida > 0:
			ouve(alvo.global_position, INF)  # perdeu de vista: vai procurar onde viu por último
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
	if alvo:
		_indo_ouvir = false
		_olhando_t = 0.0
		_voltando = false
		_fechando = false
		if _sem_gritar <= 0.0:
			_grita()


# divide a volta do alvo entre os zumbis que estão atrás dele: ordena pelo ângulo em que cada um já está e
# espalha por igual, girando o conjunto o mínimo possível
func _calcula_cerco() -> void:
	_cerco_ang = NAN
	if alvo == null:
		return
	var angs: Array[float] = []
	var meu: float = 0.0
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z.vida <= 0 or z.alvo != alvo:
			continue
		var d: Vector3 = z.global_position - alvo.global_position
		var a: float = atan2(d.x, d.z)
		angs.append(a)
		if z == self:
			meu = a
	if angs.size() < 2:
		return
	angs.sort()
	var passo: float = TAU / angs.size()
	var giro := Vector2.ZERO  # média circular de (ângulo atual - posição na volta)
	for k in angs.size():
		giro += Vector2.from_angle(angs[k] - k * passo)
	_cerco_ang = giro.angle() + angs.find(meu) * passo


# para, grita e chama os zumbis em volta para o mesmo alvo
func _grita() -> void:
	_sem_gritar = GRITO_PAUSA
	_grito_t = anim.get_animation("grito").length
	anim.speed_scale = 1.0
	_toca("grito", 0.15, true)
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z == self or z.vida <= 0 or z.alvo != null or z.global_position.distance_to(global_position) > GRITO_RAIO:
			continue
		z.alvo = alvo
		z._fechando = false
		z._sem_gritar = GRITO_PAUSA
		z._indo_ouvir = false
		z._olhando_t = 0.0
		z._voltando = false


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
		_grito_t = -1.0
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
	_grito_t = -1.0
	_indo_ouvir = false
	_olhando_t = 0.0
	_voltando = false
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
	if clipe == "grito":  # toca aqui para tocar também nos clientes (que recebem só o nome do clipe)
		_som.stream = _som_grito
		_som.pitch_scale = randf_range(0.85, 1.1)
		_som.play()
	if anim.has_animation(clipe):
		anim.play(clipe, mistura)
		if de_novo:
			anim.seek(0.0, true)


## Clipe tocando agora (testes).
func clipe_atual() -> String:
	return _clipe


# grito rouco gerado no código (os pacotes grátis não têm voz de zumbi): dente-de-serra grave que sobe e
# desce, com tremido, ruído de garganta e distorção
static func _gera_grito() -> AudioStreamWAV:
	var taxa: int = 22050
	var dur: float = 1.5
	var n: int = int(taxa * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var fase: float = 0.0
	var fase2: float = 0.0
	var ruido_f: float = 0.0
	var saida: float = 0.0
	for i in n:
		var t: float = float(i) / taxa
		var x: float = t / dur
		var freq: float = lerpf(95.0, 165.0, sin(x * PI) ** 0.6) * (1.0 + 0.04 * sin(TAU * 7.0 * t))
		fase = fmod(fase + freq / taxa, 1.0)
		fase2 = fmod(fase2 + freq * 2.03 / taxa, 1.0)
		var serra: float = 2.0 * fase - 1.0
		ruido_f = lerpf(ruido_f, randf_range(-1.0, 1.0), 0.35)
		var v: float = serra * 0.6 + (2.0 * fase2 - 1.0) * 0.25 + ruido_f * 0.55
		v = tanh(v * 2.2)
		saida = lerpf(saida, v, 0.45)  # tira o chiado agudo
		var env: float = minf(t / 0.08, 1.0) * clampf((dur - t) / 0.35, 0.0, 1.0)
		dados.encode_s16(i * 2, int(clampf(saida * env * 0.8, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	return w
