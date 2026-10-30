# Zumbi simples (mecânica 5): fica parado até ver ou ouvir alguém, vai até a pessoa desviando dos obstáculos
# (malha de navegação), ataca de perto, cambaleia quando leva golpe ou tiro, morre e levanta de novo no
# mesmo lugar depois de um tempo (por enquanto, para dar para treinar).
# Mecânica 6: ouve tiro (Zumbi.barulho) e vai até o lugar do barulho; chegando, procura em volta e, se não
# achar ninguém, volta para casa.
# Mecânica 7: chama a horda. Ao achar alguém, para e grita; os zumbis a até GRITO_RAIO sem alvo vêm atrás da
# mesma pessoa, mesmo sem ver. Grita no máximo uma vez a cada GRITO_PAUSA (os chamados não gritam de novo).
# Mecânica 8: cercar. Vários atrás da mesma pessoa se espalham em volta dela (cada um vai para um lado, na
# ordem em que já estão, para não se cruzarem) e só fecham quando chegam perto.
# Mecânica 10: tocaia. Zumbi de tocaia fica deitado no chão como morto; levanta e ataca (sem gritar) quando
# alguém passa a menos de EMBOSCA, quando há barulho perto ou quando leva golpe. Depois de morto, deita de novo.
# Mecânica 12: porta fechada no caminho segura o zumbi; ele soca a porta até arrombar.
# Mecânica 17: chefe. Maior (ESCALA_CHEFE), 400 de vida, soco de 35 que empurra longe, mais lento, não foge
# e só cambaleia com golpe forte.
# Mecânica 16: patrulha. Zumbi com `rota` anda de ponto em ponto (parando um pouco em cada) em vez de ficar
# parado em casa; depois de perseguir ou procurar, volta para a rota.
# Mecânica 13: esperto contra tiro. Com alguém mirando a pistola nele de longe, vem em ziguezague; com pouca
# vida, foge um tempo correndo para longe e depois volta.
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
const NOITE_VEL: float = 1.35       # à noite: mais rápido,
const NOITE_DANO: float = 1.6        # bate mais forte
const NOITE_OUVE: float = 2.0        # e ouve mais longe (as notas: "à noite ficam muito mais fortes")
const EMBOSCA: float = 4.0          # m: alguém passando assim perto acorda o zumbi deitado
const ACORDA_BARULHO: float = 10.0  # m: tiro até essa distância acorda o deitado
const VEL_LEVANTAR: float = 1.3
const ZIGUE: float = 2.2          # m/s de desvio para o lado quando alguém mira nele
const ZIGUE_LONGE: float = 4.0     # m: mais perto que isso não desvia, ataca
const FOGE_VIDA: int = 25
const FOGE_POR: float = 4.0
const ESCONDE_POR: float = 8.0     # com cobertura: fica escondido esse tempo (espiando) antes de voltar
const ABRIGO_RAIOS: Array[float] = [3.0, 5.0, 7.0, 9.0]
const CERCO: float = 3.0           # m: distância do ponto de cerco até o alvo
const FECHA: float = 1.8           # m: com o alvo colado assim, ataca mesmo sem ter chegado no seu lado

## altura (acima dos pés) a partir da qual o tiro conta como na cabeça (o zumbi anda curvado)
var altura_cabeca: float = 1.4
## zumbi chefe (vem nos dados do spawner)
var chefe: bool = false
const ESCALA_CHEFE: float = 1.35
const VIDA_CHEFE: int = 400
const DANO_CHEFE: int = 35
## Tipos de zumbi (vem do modelo): vida, dano, velocidade (× ANDAR/CORRER), animações de andar/correr e habilidade.
## Corredora: rápida e frágil, dá um BOTE de longe. Policial: médio, o soco AGARRA (deixa o jogador lento).
## Soldado: lento e duro, BLINDADO (leva menos dano e não cambaleia com golpe fraco).
const TIPOS: Dictionary = {
	"zumbi_mulher": {"nome": "Corredora", "vida": 70, "dano": 10, "vel": 1.3, "andar": "andar_rapido", "correr": "correr_rapido", "skill": "bote"},
	"zumbi_policial": {"nome": "Policial", "vida": 100, "dano": 15, "vel": 1.0, "andar": "andar", "correr": "correr", "skill": "agarrao"},
	"zumbi_soldado": {"nome": "Soldado", "vida": 180, "dano": 20, "vel": 0.65, "andar": "andar_lento", "correr": "correr_lento", "skill": "blindado"},
}
const BOTE_DE: float = 3.0          # m: distância mínima e máxima para o bote
const BOTE_ATE: float = 6.5
const BOTE_VEL: float = 8.0         # m/s durante o bote
const BOTE_DUR: float = 0.35
const BOTE_INTERVALO: float = 6.0
const AGARRA_T: float = 2.0         # s que o jogador fica lento depois do soco do policial
const BLINDAGEM: float = 0.6        # o soldado leva 60% do dano
const BLINDADO_CAMBALEIA: int = 30  # e só cambaleia com golpe a partir disso
var tipo: String = "zumbi_policial"
## testes: força um tipo para todos os zumbis criados (vazio = escolhe pelo nome)
static var tipo_fixo: String = ""
var _dano: int = DANO
var _vel: float = 1.0
var _skill_t: float = 2.0
var _bote: float = 0.0
## Habilidade do chefe: pancada no chão (em vez do soco, de tempos em tempos): acerta todos em volta, até de costas
const PANCADA_RAIO: float = 4.0
const PANCADA_DANO: int = 25
const PANCADA_INTERVALO: float = 7.0
var _pancada: bool = false
var _pancada_t: float = 3.0  # servidor: tempo até poder dar a próxima
var _vida_max: int = VIDA_MAX
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
## nasce deitado de tocaia (vem nos dados do spawner)
var tocaia: bool = false
## pontos da patrulha (vazio = fica parado em casa)
var rota: Array = []
var _rota_i: int = 0
var _pausa_t: float = 0.0
var _deitado: bool = false
var _levantando: float = -1.0
var _forma: CollisionShape3D
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
var _porta_alvo: Porta            # o soco em andamento é na porta
var _foge_t: float = 0.0           # > 0: fugindo
var _fugiu: bool = false           # já fugiu nesta vida (foge uma vez só)
var _rng_drop := RandomNumberGenerator.new()
var _abrigo: Vector3 = Vector3.INF # onde se esconder (INF = não achou: só corre para longe)
var _exposto_t: float = 0.0
var _zigue_t: float = 0.0
var _grito_t: float = -1.0         # >= 0: gritando (parado)
var _sem_gritar: float = 0.0       # > 0: não grita de novo ainda
var _som: AudioStreamPlayer3D
## gemidos gravados (Darsycho, CC0); um sorteado por grito
const SONS_GRITO: Array[String] = ["res://assets/sons/zumbi_grito_1.ogg", "res://assets/sons/zumbi_grito_2.ogg",
	"res://assets/sons/zumbi_grito_3.ogg"]
var _mat_pele: StandardMaterial3D


func _ready() -> void:
	add_to_group("golpeavel")
	add_to_group("zumbis")
	collision_layer = 8
	collision_mask = 1 | 8 | Porta.CAMADA
	floor_snap_length = 0.4
	var k: float = ESCALA_CHEFE if chefe else 1.0
	if chefe:
		_vida_max = VIDA_CHEFE
		vida = VIDA_CHEFE
		altura_cabeca *= k
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RAIO * k
	cap.height = ALTURA * k
	cs.shape = cap
	cs.position.y = ALTURA * k * 0.5
	add_child(cs)
	_forma = cs
	# o nome é o mesmo em todos os aparelhos: todos veem o mesmo zumbi
	if not chefe:
		aplica_tipo(tipo_fixo if tipo_fixo != "" else Anims.ZUMBIS[hash(String(name)) % Anims.ZUMBIS.size()])
	modelo = Anims.boneco(Anims.CHEFE if chefe else tipo)
	modelo.scale = Vector3.ONE * k
	add_child(modelo)
	_mat_pele = StandardMaterial3D.new()  # por cima da roupa: pisca vermelho ao levar golpe
	_mat_pele.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_pele.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_pele.albedo_color = Color(0.85, 0.15, 0.1, 0.0)
	for m: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _mat_pele
	anim = AnimationPlayer.new()
	modelo.add_child(anim)
	anim.add_animation_library("", Anims.biblioteca_zumbi())
	_agente = NavigationAgent3D.new()
	_agente.radius = RAIO + 0.05
	_agente.height = ALTURA
	_agente.path_desired_distance = 0.3  # 0,6 dava a quina por alcançada cedo e ele raspava na parede
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
	_monta_sincronia()
	_toca("parado", 0.0)
	anim.seek(randf() * 3.0, true)  # cada um num ponto da animação
	if Rede.servidor_sem_tela:
		anim.active = false  # ninguém vê: não mexe nos ossos (os tempos vêm do tamanho dos clipes)
	if tocaia and _manda():
		_deita()


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
	_pancada_t -= dt
	_skill_t -= dt
	_bote -= dt
	if not _manda():
		global_position = global_position.lerp(pos_rede, 1.0 - exp(-14.0 * dt))
		if global_position.distance_to(pos_rede) > 4.0:
			global_position = pos_rede
		modelo.rotation.y = lerp_angle(modelo.rotation.y, rot_rede, 1.0 - exp(-14.0 * dt))
		_toca(clipe_rede, 0.2)
		_forma_deitada(clipe_rede == "deitado")  # o tiro daqui precisa achar o corpo no chão
		return
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
	if vida <= 0:
		_morto_t -= dt
		if _morto_t <= 0.0:
			global_position = casa
			vida = _vida_max
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_publica()
		return
	if _deitado:
		_procura_t -= dt
		if _procura_t <= 0.0:
			_procura_t = 0.2
			_escolhe_alvo()
		if not is_on_floor():
			velocity.y -= GRAVIDADE * dt
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
	if _levantando >= 0.0:
		_levantando -= dt
		if alvo and is_instance_valid(alvo):
			_vira_para(alvo.global_position - global_position, dt)
	elif _cambaleio > 0.0:
		_cambaleio -= dt
	elif _grito_t >= 0.0:
		_grito_t -= dt
		if alvo and is_instance_valid(alvo):
			_vira_para(alvo.global_position - global_position, dt)
	elif _ataque_t >= 0.0:
		_atualiza_ataque(dt)
	elif _foge_t > 0.0 and alvo:
		_foge_t -= dt
		var corre: float = CORRER * 1.2 * (1.0 if chefe else _vel) * Ciclo.forca_noite(get_tree(), NOITE_VEL)
		if _abrigo == Vector3.INF:
			var longe: Vector3 = global_position - alvo.global_position
			longe.y = 0.0
			desejada = _caminho(global_position + longe.normalized() * 6.0, corre, dt)
		elif _plano(_abrigo - global_position) > 0.6:
			desejada = _caminho(_abrigo, corre, dt)
		else:
			# escondido: espia o alvo; se ele der a volta e aparecer, procura outro lugar
			_vira_para(alvo.global_position - global_position, dt)
			_exposto_t = _exposto_t + dt if _ve(alvo) else 0.0
			if _exposto_t > 0.4:
				_exposto_t = 0.0
				_abrigo = _acha_abrigo()
				_foge_t = maxf(_foge_t, 6.0)  # tempo para chegar no novo lugar
	elif alvo:
		var d: Vector3 = alvo.global_position - global_position
		d.y = 0.0
		if not chefe and TIPOS[tipo].skill == "bote" and _skill_t <= 0.0 and _ataque_t < 0.0 and d.length() > BOTE_DE \
				and d.length() < BOTE_ATE and _ve(alvo):
			_bote = BOTE_DUR  # corredora: pula em cima de longe
			_skill_t = BOTE_INTERVALO
		if _bote > 0.0:
			_vira_para(d, dt * 6.0)
			desejada = d.normalized() * BOTE_VEL
			velocity.x = desejada.x
			velocity.z = desejada.z
		elif d.length() < ALCANCE and _porta_na_frente(d) == null:
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
			desejada = _caminho(destino, (CORRER if d.length() < PERTO else ANDAR) * (0.8 if chefe else _vel) * Ciclo.forca_noite(get_tree(), NOITE_VEL), dt)
			# mirando nele de longe: desvia para os lados (troca de lado a cada ~0,7 s, sem ritmo fixo)
			if d.length() > ZIGUE_LONGE and alvo.mirando_em(global_position, 12.0):
				_zigue_t += dt * randf_range(0.8, 1.2)
				var lado := Vector3(d.z, 0, -d.x).normalized()
				desejada += lado * ZIGUE * signf(sin(_zigue_t * 4.5))
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
			desejada = _caminho(_ouvido, VAI_OUVIR * Ciclo.forca_noite(get_tree(), NOITE_VEL), dt)
	elif not rota.is_empty():
		_voltando = false
		desejada = _patrulha(dt)
	elif _voltando:
		if _plano(casa - global_position) < 0.8:
			_voltando = false
		else:
			desejada = _caminho(casa, VOLTA, dt)
	# porta fechada no caminho: para e soca a porta
	var porta: Porta = null
	if _ataque_t < 0.0 and _cambaleio <= 0.0 and _grito_t < 0.0 and _levantando < 0.0:
		var rumo: Vector3 = desejada
		if alvo and rumo.length() < 0.01:
			rumo = alvo.global_position - global_position
			rumo.y = 0.0
		if rumo.length() > 0.01:
			porta = _porta_na_frente(rumo)
	if porta:
		desejada = Vector3.ZERO
		_vira_para(porta.centro() - global_position, dt * 2.0)
		_porta_alvo = porta
		_ataca()
	var plano := Vector3(velocity.x, 0, velocity.z).move_toward(desejada, 12.0 * dt)
	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()
	if _ataque_t < 0.0 and _cambaleio <= 0.0 and _grito_t < 0.0 and _levantando < 0.0:
		var v: float = plano.length()
		var nomes: Dictionary = {"andar": "andar", "correr": "correr"} if chefe else TIPOS[tipo]
		_toca("parado" if v < 0.2 else (nomes.correr if v > 1.6 * (1.0 if chefe else _vel) else nomes.andar), 0.25)
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


# vai para o ponto atual da rota, devagar; chegando, para de 1,5 a 3,5 s e segue para o próximo
func _patrulha(dt: float) -> Vector3:
	if _pausa_t > 0.0:
		_pausa_t -= dt
		return Vector3.ZERO
	var alvo_p: Vector3 = rota[_rota_i]
	if _plano(alvo_p - global_position) < 0.8:
		_rota_i = (_rota_i + 1) % rota.size()
		_pausa_t = randf_range(1.5, 3.5)
		return Vector3.ZERO
	return _caminho(alvo_p, ANDAR * 0.8 * (1.0 if chefe else _vel), dt)


static func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Um barulho em `ponto`: os zumbis vivos a até `raio` metros, sem alvo, vão ver o que foi. Só no servidor.
static func barulho(arvore: SceneTree, ponto: Vector3, raio: float) -> void:
	for n: Node in arvore.get_nodes_in_group("zumbis"):
		(n as Zumbi).ouve(ponto, raio)


func ouve(ponto: Vector3, raio: float) -> void:
	if vida <= 0 or alvo != null or global_position.distance_to(ponto) > raio:
		return
	if _deitado:
		if global_position.distance_to(ponto) > ACORDA_BARULHO:
			return
		_acorda()
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
	if _deitado:  # deitado não olha em volta: só sente quem passa bem perto
		for n: Node in get_tree().get_nodes_in_group("jogadores"):
			var jd := n as Jogador
			if jd and jd.vida > 0 and jd.global_position.distance_to(global_position) < EMBOSCA:
				alvo = jd
				_acorda()
				return
		return
	var melhor: float = INF
	var ouve: float = OUVE * Ciclo.forca_noite(get_tree(), NOITE_OUVE)
	for n: Node in get_tree().get_nodes_in_group("jogadores"):
		var j := n as Jogador
		if j == null or j.vida <= 0:
			continue
		var dist: float = j.global_position.distance_to(global_position)
		if dist < melhor and (dist < ouve or (dist < VISAO and _ve(j))):
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


# ponto perto (na malha) onde o alvo não enxerga o peito do zumbi, sem chegar mais perto dele; INF = nenhum
func _acha_abrigo() -> Vector3:
	var mapa: RID = _agente.get_navigation_map()
	var olho: Vector3 = alvo.global_position + Vector3(0, 1.5, 0)
	var espaco := get_world_3d().direct_space_state
	var melhor := Vector3.INF
	var custo: float = INF
	for raio: float in ABRIGO_RAIOS:
		for k in 16:
			var a: float = TAU * k / 16.0
			var p: Vector3 = global_position + Vector3(sin(a), 0, cos(a)) * raio
			if mapa.is_valid():
				p = NavigationServer3D.map_get_closest_point(mapa, p)
			if _plano(p - alvo.global_position) < maxf(4.0, _plano(global_position - alvo.global_position) - 1.0):
				continue  # não se esconde indo na direção de quem atira
			var q := PhysicsRayQueryParameters3D.create(olho, p + Vector3(0, 1.0, 0), 1 | Porta.CAMADA, [alvo.get_rid()])
			if espaco.intersect_ray(q).is_empty():
				continue  # dali o alvo vê
			var c: float = _custo_caminho(mapa, p)
			if c < custo:
				custo = c
				melhor = p
		if melhor != Vector3.INF:
			break  # o mais perto que serve
	return melhor


# comprimento do caminho até `p`; INF se o caminho passa a menos de 3 m do alvo (não corre do lado de quem atira)
func _custo_caminho(mapa: RID, p: Vector3) -> float:
	if not mapa.is_valid():
		return _plano(p - global_position)
	var cam: PackedVector3Array = NavigationServer3D.map_get_path(mapa, global_position, p, true)
	var total: float = 0.0
	for i in range(1, cam.size()):
		var meio: Vector3 = Geometry3D.get_closest_point_to_segment(alvo.global_position, cam[i - 1], cam[i])
		if _plano(meio - alvo.global_position) < 3.0:
			return INF
		total += cam[i - 1].distance_to(cam[i])
	return total


func _ve(j: Jogador) -> bool:
	var olho: Vector3 = global_position + Vector3(0, 1.5, 0)
	var q := PhysicsRayQueryParameters3D.create(olho, j.global_position + Vector3(0, 1.4, 0), 1 | Porta.CAMADA)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _ataca() -> void:
	_ataque_t = 0.0
	_acertou = false
	anim.speed_scale = 1.0
	_pancada = chefe and _pancada_t <= 0.0
	if _pancada:
		_pancada_t = PANCADA_INTERVALO
		anim.speed_scale = 0.75  # mais devagar: dá para ver vindo e fugir
	_toca("ataque", 0.12, true)


# porta fechada a menos de 1 m na direção `dir`, ou null
func _porta_na_frente(dir: Vector3) -> Porta:
	var de: Vector3 = global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(de, de + dir.normalized() * 1.0, Porta.CAMADA)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var p := (hit.collider as Node).get_parent() as Porta
	return p if p and not p.aberta else null


func _atualiza_ataque(dt: float) -> void:
	_ataque_t += dt * anim.speed_scale
	var dur: float = anim.get_animation("ataque").length
	if not _acertou and _ataque_t >= dur * ACERTO:
		_acertou = true
		if _pancada:
			_pancada_no_chao()
		elif _porta_alvo:
			_porta_alvo.leva_soco(_dano)
			_porta_alvo = null
		elif alvo and is_instance_valid(alvo):
			var d: Vector3 = alvo.global_position - global_position
			d.y = 0.0
			var frente: Vector3 = modelo.global_basis.z
			if d.length() < ALCANCE_ACERTO and rad_to_deg(Vector3(frente.x, 0, frente.z).angle_to(d)) < 70.0:
				# o chefe empurra longe (o empurrão do jogador é proporcional ao tamanho de `dir`)
				alvo.levar_dano(roundi((DANO_CHEFE if chefe else _dano) * Ciclo.forca_noite(get_tree(), NOITE_DANO)), d.normalized() * (2.5 if chefe else 1.0))
				if not chefe and TIPOS[tipo].skill == "agarrao":
					alvo.agarrar(AGARRA_T)
	if _ataque_t >= dur:
		_ataque_t = -1.0


## Vida, dano e velocidade do tipo (o nome do nó escolhe; os testes podem forçar).
func aplica_tipo(t: String) -> void:
	tipo = t
	var d: Dictionary = TIPOS[t]
	_vida_max = d.vida
	vida = d.vida
	_dano = d.dano
	_vel = d.vel


# servidor: a pancada do chefe acerta todos os jogadores no raio (dano cai com a distância) e empurra para fora
func _pancada_no_chao() -> void:
	for j: Jogador in get_tree().get_nodes_in_group("jogadores"):
		var d: Vector3 = j.global_position - global_position
		d.y = 0.0
		if j.vida > 0 and d.length() < PANCADA_RAIO:
			var f: float = 1.0 - d.length() / PANCADA_RAIO * 0.5
			j.levar_dano(roundi(PANCADA_DANO * f * Ciclo.forca_noite(get_tree(), NOITE_DANO)), (d.normalized() if d.length() > 0.1 else -modelo.global_basis.z) * 3.0)
	_poeira.rpc()


# todos: anel de poeira se abrindo no chão em volta do chefe
@rpc("authority", "call_local", "unreliable")
func _poeira() -> void:
	if Rede.servidor_sem_tela:
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 0.5, 0.42, 0.7)
	mi.material_override = m
	get_parent().add_child(mi)
	mi.global_position = global_position + Vector3(0, 0.1, 0)
	mi.scale = Vector3(0.5, 0.3, 0.5)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(PANCADA_RAIO, 0.3, PANCADA_RAIO), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)


## Golpe ou tiro (o facão e a pistola chamam isto). No cliente vira pedido ao servidor.
## Dinheiro do jogo por zumbi morto (provisório); à noite vale mais.
const DINHEIRO: int = 10
const DINHEIRO_CHEFE: int = 300
const DINHEIRO_NOITE: float = 1.5
var _ultimo: Jogador  # servidor: quem bateu por último (ganha o dinheiro)


func levar_golpe(dano: int, dir: Vector3, quem: Node) -> void:
	if vida <= 0:
		return
	_pisca()
	if _manda():
		if quem is Jogador:
			_ultimo = quem
		_aplica(dano, dir)
	else:
		_pede_golpe.rpc_id(1, dano, dir)


@rpc("any_peer", "call_remote", "reliable")
func _pede_golpe(dano: int, dir: Vector3) -> void:
	# shortcut: o servidor confia no dano que o cliente manda; conferir alcance/arma quando houver servidor de verdade
	if multiplayer.is_server() and vida > 0:
		var principal := get_tree().get_first_node_in_group("principal")
		var quem: Node = principal.jogadores.get_node_or_null(str(multiplayer.get_remote_sender_id())) if principal else null
		if quem is Jogador:
			_ultimo = quem
		_aplica(clampi(dano, 0, 100), dir)


func _aplica(dano: int, dir: Vector3) -> void:
	if _deitado:
		_acorda()
	var blindado: bool = not chefe and TIPOS[tipo].skill == "blindado"
	if blindado:
		dano = maxi(1, roundi(dano * BLINDAGEM))
	vida = maxi(0, vida - dano)
	if vida > 0 and vida <= FOGE_VIDA and not _fugiu and alvo and not chefe:
		_fugiu = true
		_abrigo = _acha_abrigo()
		_foge_t = FOGE_POR if _abrigo == Vector3.INF else ESCONDE_POR
	if vida > 0 and (not chefe or dano >= 40) and (not blindado or dano >= roundi(BLINDADO_CAMBALEIA * BLINDAGEM)):
		_cambaleio = CAMBALEIO
		_ataque_t = -1.0
		_grito_t = -1.0
		_toca("dano", 0.08, true)
		velocity += Vector3(dir.x, 0, dir.z).normalized() * 2.0 * clampf(dir.length(), 0.5, 3.0)  # empurrão (taco empurra mais)
		if alvo == null:  # quem bate chama a atenção
			_procura_t = 0.0


func _pisca() -> void:
	var t := create_tween()
	t.tween_property(_mat_pele, "albedo_color:a", 0.45, 0.04)
	t.tween_property(_mat_pele, "albedo_color:a", 0.0, 0.18)


func _morre() -> void:
	remove_from_group("golpeavel")
	collision_layer = 0
	_ataque_t = -1.0
	_cambaleio = 0.0
	alvo = null
	_foge_t = 0.0
	_fugiu = false
	_abrigo = Vector3.INF
	_deitado = false
	_levantando = -1.0
	_grito_t = -1.0
	_indo_ouvir = false
	_olhando_t = 0.0
	_voltando = false
	_morto_t = MORTO_POR
	anim.speed_scale = 1.0
	_toca("morte", 0.1, true)
	if _manda():
		_larga_drop()
		if _ultimo and is_instance_valid(_ultimo):
			var noite: bool = Ciclo.forca_noite(get_tree(), 2.0) > 1.5
			_ultimo.ganhar("dinheiro", roundi((DINHEIRO_CHEFE if chefe else DINHEIRO) * (DINHEIRO_NOITE if noite else 1.0)))
			_ultimo.ganhar("abate", 1)
		_ultimo = null


const DROP_SOME: float = 180.0  # s até o que o zumbi largou sumir


# servidor: sorteia o que o zumbi larga (Loot.drop) e põe no chão em volta do corpo
func _larga_drop() -> void:
	var principal := get_tree().get_first_node_in_group("principal")
	if principal == null:
		return
	var coisas: Array = Loot.drop(_rng_drop, chefe)
	for k in coisas.size():
		var a: float = TAU * k / maxf(coisas.size(), 1.0) + _rng_drop.randf()
		var p: Vector3 = global_position + Vector3(cos(a), 0, sin(a)) * 0.5
		principal.solta_item(String(coisas[k].tipo), int(coisas[k].qtd), Vector3(p.x, global_position.y, p.z), DROP_SOME)


func _levanta() -> void:
	add_to_group("golpeavel")
	collision_layer = 8
	_toca("parado", 0.3)
	if tocaia and _manda():
		_deita()


# deitado no chão, parecendo morto (o colisor deita junto para o tiro acertar o corpo)
func _deita() -> void:
	_deitado = true
	alvo = null
	_forma_deitada(true)
	_toca("deitado", 0.0)


func _forma_deitada(sim: bool) -> void:
	_forma.rotation.x = PI * 0.5 if sim else 0.0
	_forma.position = Vector3(0, RAIO if sim else ALTURA * 0.5, 0)


func _acorda() -> void:
	if not _deitado:
		return
	_deitado = false
	_forma_deitada(false)
	_sem_gritar = GRITO_PAUSA  # emboscada é calada
	_levantando = anim.get_animation("levantar").length / VEL_LEVANTAR
	_toca("levantar", 0.1, true)
	anim.speed_scale = VEL_LEVANTAR


func _toca(clipe: String, mistura: float, de_novo: bool = false) -> void:
	if clipe == _clipe and not de_novo:
		return
	_clipe = clipe
	if clipe == "grito":  # toca aqui para tocar também nos clientes (que recebem só o nome do clipe)
		_som.stream = load(SONS_GRITO.pick_random())
		_som.pitch_scale = randf_range(0.9, 1.05)
		_som.play()
	if anim.has_animation(clipe):
		anim.play(clipe, mistura)
		if de_novo:
			anim.seek(0.0, true)


## Clipe tocando agora (testes).
func clipe_atual() -> String:
	return _clipe

