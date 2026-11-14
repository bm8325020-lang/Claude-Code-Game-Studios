# O Paciente Zero (14/11, ESTACAO.md seção 4): o Dr. Varga tomado pelo fungo. Um só no mapa; o servidor decide e os
# outros veem pela sincronia do Zumbi (corpo, animação, caminho e rede vêm do Zumbi; aqui só o cérebro). Corpo do
# "parasita" do chefe, esticado, com crescimentos de fungo nas costas (protótipo até o modelo próprio).
# Estados: PATRULHA -> INVESTIGA (ouviu) -> CAÇA (viu de relance) -> PERSEGUE (visão firme) -> BUSCA (perdeu) e
# RECUA (luz UV na cara: Jogador._passa_uv). No escuro é mais rápido e vê mais longe; na luz, o contrário.
# Bala não mata: só faz tropeçar. Quem ele viu entrar no esconderijo ele tira de lá.
class_name PacienteZero
extends Zumbi

enum {PATRULHA, INVESTIGA, CACA, PERSEGUE, RECUA, BUSCA}
const NOMES: Array[String] = ["patrulha", "investiga", "caca", "persegue", "recua", "busca"]
const PZ_VISAO: float = 22.0
const PZ_VISAO_ESCURO: float = 30.0   # e você de lanterna acesa no escuro: ele vê de longe
const PZ_VISAO_LUZ: float = 12.0
const CONE: float = 55.0           # graus para cada lado (110 no total)
const FIRME: float = 0.5           # s vendo para perseguir
const PERDE: float = 4.0           # s sem ver para desistir e buscar
const RECUA_T: float = 6.0
const IMUNE_T: float = 8.0         # depois de queimado: a UV não pega de novo nesse tempo
const BUSCA_T: float = 25.0
const FAREJA_T: float = 6.0
const VEL_ANDA: float = 1.4
const VEL_INVESTIGA: float = 2.6
const VEL_CORRE: float = 5.0       # jogador: trote 4,6, correr 7,2 (com fôlego dá para fugir)
const ESCURO_MAIS: float = 1.2
const LUZ_MENOS: float = 0.76
const PZ_OUVE: float = 7.0            # base do Zumbi.ouve_de (correr dobra, agachado corta)
const COMECO_CALMO: float = 180.0  # s: no começo ele fica perto da estação (você vê de longe)
const TROPECA: float = 1.0

var estado: int = PATRULHA
var furia: bool = false            # bunker abrindo: mais rápido e quase não recua
var estado_nome: String = "patrulha"
var _t: float = 0.0
var _ponto: Vector3 = Vector3.INF
var _visto: Vector3 = Vector3.INF
var _firme: float = 0.0
var _sem_ver: float = 0.0
var _imune_t: float = 0.0
var _sente_t: float = 0.0
var _tropeco: float = 0.0
var _vira_t: float = 0.0
var _jogo: float = 0.0
var _busca_n: int = 0
var _recua_t: float = 0.0
var _quem: Jogador                 # quem ele está seguindo agora
var _viu_esconder: Jogador         # viu entrar no esconderijo: vai abrir


func _ready() -> void:
	chefe = true  # corpo e animações do parasita, colisor maior; o resto é daqui
	super._ready()
	add_to_group("paciente_zero")
	remove_from_group("zumbis")  # não conta como zumbi (horda, cerca da base, população)
	_vida_max = 999999
	vida = _vida_max
	chance_grito = 0.0
	if modelo:
		modelo.scale *= Vector3(0.82, 1.12, 0.82)  # mais alto e magro que o chefe
	altura_cabeca *= 1.12
	if not Rede.servidor_sem_tela:
		_fungo()


func _fungo() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.5)
	m.roughness = 1.0
	var m2 := StandardMaterial3D.new()  # veios do fungo: brilham roxo na UV (queima)
	m2.albedo_color = Color(0.35, 0.3, 0.38)
	m2.emission_enabled = true
	m2.emission = Color(0.55, 0.2, 1.0)
	m2.emission_energy_multiplier = 0.0
	m2.resource_name = "veio"
	var r := RandomNumberGenerator.new()
	r.seed = 117
	for k in 9:  # "coroa" de cogumelos nos ombros e costas
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r.randf_range(0.09, 0.2)
		s.height = s.radius * r.randf_range(0.8, 1.4)
		s.radial_segments = 8
		s.rings = 4
		mi.mesh = s
		mi.material_override = m if k % 3 else m2
		var a: float = r.randf_range(-1.2, 1.2)
		mi.position = Vector3(sin(a) * 0.28, r.randf_range(1.45, 1.85), -0.12 - cos(a) * 0.12) * Vector3(1, 1.12, 1)
		mi.set_meta("sem_estilo", true)
		mi.add_to_group("pz_veio" if k % 3 == 0 else "pz_fungo")
		modelo.add_child(mi)


func _muda(e: int) -> void:
	estado = e
	estado_nome = NOMES[e]
	_t = 0.0


## Luz do lugar: -1 escuro (noite, dentro da estação), 0 normal, 1 claro (portaria, fogueira, refúgio, base acesa).
func luz_em(p: Vector3) -> int:
	var est: Estacao = Estacao.atual
	if est and est.seguro(p):
		return 1
	for f: Node3D in get_tree().get_nodes_in_group("fogueiras"):
		if f.global_position.distance_to(p) < 6.0:
			return 1
	for c: Node3D in get_tree().get_nodes_in_group("camas_refugio"):
		if c.global_position.distance_to(p) < 4.0:
			return 1
	if (est and est.dentro(p)) or Ciclo.noite_de(get_tree()) > 0.5:
		return -1
	return 0


func _fator() -> float:
	var l: int = luz_em(global_position)
	return (ESCURO_MAIS if l < 0 else (LUZ_MENOS if l > 0 else 1.0)) * (1.25 if furia else 1.0)


## Vê `j` agora? (cone, alcance pela luz, parede no meio)
func ve(j: Jogador) -> bool:
	if j == null or j.vida <= 0 or j.escondido:
		return false
	var d: Vector3 = j.global_position - global_position
	var dist: float = d.length()
	if dist < 2.5:
		return true
	var alcance: float = PZ_VISAO
	var luz_dele: int = luz_em(j.global_position)
	if luz_dele < 0:
		alcance = PZ_VISAO_ESCURO if j.lanterna_acesa else PZ_VISAO * 0.6
	elif luz_dele > 0:
		alcance = PZ_VISAO_LUZ
	if j.agachado and not (j.lanterna_acesa):
		alcance *= 0.5
	if dist > alcance:
		return false
	var frente: Vector3 = modelo.global_basis.z
	frente.y = 0.0
	d.y = 0.0
	if rad_to_deg(frente.angle_to(d)) > CONE and dist > 5.0:
		return false
	return _ve(j)


func _vivos() -> Array:
	return get_tree().get_nodes_in_group("jogadores").filter(func(n: Node) -> bool: return (n as Jogador).vida > 0)


func _sente() -> void:
	var melhor: Jogador = null
	for j: Jogador in _vivos():
		if ve(j) and (melhor == null or j.global_position.distance_to(global_position) < melhor.global_position.distance_to(global_position)):
			melhor = j
	if melhor:
		_quem = melhor
		_visto = melhor.global_position
		_sem_ver = 0.0
		if estado in [PATRULHA, INVESTIGA, BUSCA]:
			_muda(CACA)
		return
	if estado in [PATRULHA, BUSCA, INVESTIGA]:  # ouvir: correr, tiro de perto, porta (escondido não faz barulho)
		for j: Jogador in _vivos():
			if j.escondido:
				continue
			var dist: float = j.global_position.distance_to(global_position)
			if dist < Zumbi.ouve_de(j, PZ_OUVE):
				ouve(j.global_position, dist + 1.0)
				return


## Barulho (Zumbi.barulho: tiro, alarme, porta, cartão...): vai ver.
func ouve(ponto: Vector3, raio: float) -> void:
	if vida <= 0 or global_position.distance_to(ponto) > raio or estado in [PERSEGUE, RECUA, CACA]:
		return
	_ponto = ponto
	_muda(INVESTIGA)


## UV na cara (servidor). O jogador chama `pede_queima`.
func queima() -> void:
	if _imune_t > 0.0 or estado == RECUA:
		return
	_imune_t = IMUNE_T
	_ataque_t = -1.0
	_muda(RECUA)
	_recua_t = 2.0 if furia else RECUA_T
	_queimado_fx.rpc()
	for n: Node in get_tree().get_nodes_in_group("zumbis"):  # o grito acorda os infectados em volta
		(n as Zumbi).ouve(global_position, 25.0)


func pede_queima() -> void:
	if _manda():
		queima()
	else:
		_pede_queima.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _pede_queima() -> void:
	if multiplayer.is_server():
		queima()


## Luz branca na cara: só vira o rosto um instante.
func irrita() -> void:
	if _manda() and estado == PERSEGUE and _vira_t <= 0.0:
		_vira_t = 1.0


@rpc("authority", "call_local", "unreliable")
func _queimado_fx() -> void:
	if Rede.servidor_sem_tela or modelo == null:
		return
	for v: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		if v.is_in_group("pz_veio"):
			var m := (v as MeshInstance3D).material_override as StandardMaterial3D
			m.emission_energy_multiplier = 3.0
			create_tween().tween_property(m, "emission_energy_multiplier", 0.0, 2.5)
	var p := CPUParticles3D.new()  # fumaça branca chiando do fungo
	p.amount = 24
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var q := SphereMesh.new()
	q.radius = 0.5
	q.height = 1.0
	q.radial_segments = 6
	q.rings = 3
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.9, 0.88, 0.95, 0.5)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = mt
	p.mesh = q
	p.position = Vector3(0, altura_cabeca, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)
	if _som:
		_grita()


## Bala e golpe: não morre; tropeça um instante.
func _aplica(dano: int, _dir: Vector3) -> void:
	_desperta()
	if dano >= 15 and estado != RECUA:
		_tropeco = TROPECA
	if estado in [PATRULHA, BUSCA] and _ultimo is Jogador:
		_visto = (_ultimo as Jogador).global_position
		_ponto = _visto
		_muda(INVESTIGA)


func _ataca() -> void:
	super._ataca()
	_pancada = false  # agarra, não soca o chão


func _destino_patrulha() -> Vector3:
	var est: Estacao = Estacao.atual
	var perto: Jogador = null
	for j: Jogador in _vivos():
		if perto == null or j.global_position.distance_to(global_position) < perto.global_position.distance_to(global_position):
			perto = j
	var centro: Vector3 = est.global_position if est else global_position
	var raio: float = 14.0
	if perto and _jogo > COMECO_CALMO:
		centro = perto.global_position  # perto de você, sem cair em cima: 20-35 m
		raio = 28.0
	var mapa: RID = get_world_3d().navigation_map
	for tent in 6:
		var a: float = randf() * TAU
		var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, centro + Vector3(cos(a), 0, sin(a)) * randf_range(raio * 0.7, raio * 1.25))
		if perto == null or p.distance_to(perto.global_position) > 18.0 or _jogo <= COMECO_CALMO:
			return p
	return centro


func _physics_process(dt: float) -> void:
	if not _pensa_aqui():
		global_position = global_position.lerp(pos_rede, 1.0 - exp(-14.0 * dt))
		if global_position.distance_to(pos_rede) > 4.0:
			global_position = pos_rede
		modelo.rotation.y = lerp_angle(modelo.rotation.y, rot_rede, 1.0 - exp(-14.0 * dt))
		_toca(clipe_rede, 0.2)
		return
	_jogo += dt
	_t += dt
	_imune_t -= dt
	_vira_t -= dt
	_tropeco -= dt
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
	_sente_t -= dt
	if _sente_t <= 0.0:
		_sente_t = 0.2
		_sente()
	var desejada := Vector3.ZERO
	var f: float = _fator()
	if _ataque_t >= 0.0:
		_atualiza_ataque(dt)
	elif _tropeco > 0.0 or _vira_t > 0.0:
		pass
	else:
		match estado:
			PATRULHA:
				if not _ponto.is_finite() or _plano(_ponto - global_position) < 1.2:
					if _t > 2.5:  # para e escuta antes do próximo ponto
						_ponto = _destino_patrulha()
						_t = 0.0
				else:
					desejada = _caminho(_ponto, VEL_ANDA * f, dt)
			INVESTIGA:
				if _plano(_ponto - global_position) < 1.5:
					modelo.rotation.y += dt * 1.4 * signf(sin(_t * 1.3))  # fareja virando a cabeça
					if _t > FAREJA_T:
						_comeca_busca()
				else:
					_t = 0.0
					desejada = _caminho(_ponto, VEL_INVESTIGA * f, dt)
			CACA:
				_firme = _firme + dt if _quem and ve(_quem) else 0.0
				if _firme >= FIRME:
					_firme = 0.0
					_muda(PERSEGUE)
				elif _t > 5.0:
					_comeca_busca()
				else:
					desejada = _caminho(_visto, VEL_INVESTIGA * 0.8 * f, dt)
			PERSEGUE:
				desejada = _persegue(dt, f)
			RECUA:
				var longe: Vector3 = global_position - (_quem.global_position if is_instance_valid(_quem) else global_position + modelo.global_basis.z)
				longe.y = 0.0
				desejada = _caminho(global_position + longe.normalized() * 8.0, VEL_CORRE * 1.1, dt)
				_recua_t -= dt
				if _recua_t <= 0.0:
					_comeca_busca()
			BUSCA:
				if not _ponto.is_finite() or _plano(_ponto - global_position) < 1.5:
					_busca_n += 1
					var mapa: RID = get_world_3d().navigation_map
					var base: Vector3 = _visto if _visto.is_finite() else global_position
					_ponto = NavigationServer3D.map_get_closest_point(mapa, base + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
				desejada = _caminho(_ponto, VEL_INVESTIGA * f, dt)
				if _t > BUSCA_T or _busca_n > 4:
					_ponto = Vector3.INF
					_muda(PATRULHA)
	# porta fechada sem tranca no caminho: ele abre (trancada por cartão segura)
	if desejada.length() > 0.1:
		var porta: Porta = _porta_na_frente(desejada)
		if porta and porta.cartao == "" and not porta.aberta:
			porta.aberta = true
	var plano := Vector3(velocity.x, 0, velocity.z).move_toward(desejada, 18.0 * dt)
	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()
	if _ataque_t < 0.0:
		var v: float = plano.length()
		_toca("parado" if v < 0.2 else ("correr" if v > 2.2 else "andar"), 0.25)
		var base_v: float = float(Anims.VELOCIDADE_ZUMBI.get(_real(_clipe), 0.0))
		anim.speed_scale = clampf(v / base_v, 0.6, 2.2) if base_v > 0.0 and v > 0.2 else 1.0
	_publica()


func _comeca_busca() -> void:
	_busca_n = 0
	_ponto = _visto if _visto.is_finite() else Vector3.INF
	_muda(BUSCA)


func _persegue(dt: float, f: float) -> Vector3:
	if not is_instance_valid(_quem) or _quem.vida <= 0:
		_comeca_busca()
		return Vector3.ZERO
	if _quem.escondido:
		if _viu_esconder == _quem:  # viu entrar: vai lá e tira
			var d0: Vector3 = _quem.global_position - global_position
			if Vector2(d0.x, d0.z).length() < ALCANCE + 0.6:
				_viu_esconder = null
				_quem.arranca_do_esconderijo()
				return Vector3.ZERO
			return _caminho(_quem.global_position, VEL_CORRE * f, dt)
		_comeca_busca()
		return Vector3.ZERO
	if ve(_quem):
		_visto = _quem.global_position
		_sem_ver = 0.0
	else:
		_sem_ver += dt
		if _sem_ver > PERDE:
			_comeca_busca()
			return Vector3.ZERO
	var d: Vector3 = _quem.global_position - global_position
	d.y = 0.0
	alvo = _quem  # o ataque do Zumbi usa `alvo`
	if d.length() < ALCANCE and absf(_quem.global_position.y - global_position.y) < ALTURA_ATAQUE:
		_vira_para(d, dt * 3.0)
		_ataca()
		return Vector3.ZERO
	return _caminho(_visto, VEL_CORRE * f, dt)


## Jogador entrou no esconderijo: se ele estava vendo, guarda (vai abrir).
func viu_esconder(j: Jogador) -> void:
	if estado == PERSEGUE and _quem == j and _sem_ver < 0.5:
		_viu_esconder = j
