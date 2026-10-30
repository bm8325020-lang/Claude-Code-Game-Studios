# Som do mundo (plano aprovado pelo dono, 30/10): vento grave sempre (mais forte à noite), sustos ao longe (rangido,
# ruídos sombrios, tiro distante, gemido de zumbi) vindos de uma direção, passos do jogador que mudam com o chão
# (madeira dentro de casa, concreto na rua, terra no resto), eco dentro das casas, coração acelerando com pouca vida ou
# zumbi colado, e os zumbis gemendo/rosnando perto de você. Sons CC0 do OpenGameArt (assets/sons/amb/CREDITOS.txt).
# Só no aparelho que desenha (o servidor sem tela não toca nada).
class_name SomAmbiente
extends Node

const PASTA := "res://assets/sons/amb/%s.ogg"
const SUSTO_DE: float = 9.0    # s entre sustos ao longe (sorteado entre DE e ATE)
const SUSTO_ATE: float = 26.0
const PASSO_ANDANDO: float = 0.75  # m entre um passo e outro
const PASSO_CORRENDO: float = 1.15
const GEME_PERTO: float = 22.0  # m: zumbi a essa distância geme/rosna de vez em quando

var principal: Node
var _vento: AudioStreamPlayer
var _coracao: AudioStreamPlayer
var _passo: AudioStreamPlayer
var _sons: Dictionary = {}
var _susto_t: float = 6.0
var _andado: float = 0.0
var _ultima: Vector3 = Vector3.INF
var _geme_t: float = 0.0
var _vozes: Dictionary = {}  # Zumbi -> AudioStreamPlayer3D
var _eco: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Rede.servidor_sem_tela:
		set_process(false)
		return
	_rng.randomize()
	_vento = _toca_sempre("vento", -14.0)
	_coracao = _toca_sempre("coracao", -80.0)
	_passo = AudioStreamPlayer.new()
	add_child(_passo)
	# eco: reverb no bus principal, ligado só dentro das casas
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.6
	rev.wet = 0.22
	rev.dry = 1.0
	AudioServer.add_bus_effect(0, rev)
	_eco = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _eco, false)


func _exit_tree() -> void:
	if _eco >= 0 and _eco < AudioServer.get_bus_effect_count(0):
		AudioServer.remove_bus_effect(0, _eco)


func som(nome: String) -> AudioStream:
	if not _sons.has(nome):
		_sons[nome] = load(PASTA % nome)
	return _sons[nome]


func _toca_sempre(nome: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = som(nome).duplicate()
	s.loop = true
	p.stream = s
	p.volume_db = db
	add_child(p)
	p.play()
	return p


func _process(dt: float) -> void:
	var j: Jogador = principal.jogador if principal else null
	var ciclo: Ciclo = principal.ciclo if principal else null
	var noite: float = ciclo.noite() if ciclo else 0.0
	_vento.volume_db = lerpf(-15.0, -9.0, noite)
	if j == null or not is_instance_valid(j):
		return
	var dentro: bool = principal.bairro != null and principal.bairro.casa_em(j.global_position) != ""
	AudioServer.set_bus_effect_enabled(0, _eco, dentro)
	_passos(j, dentro)
	_coracao_bate(j, dt)
	_sustos(j, dt, noite)
	_gemidos(j, dt)


# passo a cada PASSO_* metros andados no chão; o chão escolhe o jeito do som
func _passos(j: Jogador, dentro: bool) -> void:
	var p: Vector3 = j.global_position
	if _ultima == Vector3.INF or not j.is_on_floor() or j.vida <= 0:
		_ultima = p
		return
	_andado += Vector2(p.x - _ultima.x, p.z - _ultima.z).length()
	_ultima = p
	var passo: float = PASSO_CORRENDO if j.correndo else PASSO_ANDANDO
	if _andado < passo:
		return
	_andado = 0.0
	var rua: bool = principal.bairro != null and principal.bairro._perto_de_rua(Vector2(p.x - Bairro.ORIGEM.x, p.z - Bairro.ORIGEM.z), 0.5)
	_passo.stream = som("passo_%d" % _rng.randi_range(1, 6))
	if dentro:  # tábua: grave e oco
		_passo.pitch_scale = _rng.randf_range(0.72, 0.82)
		_passo.volume_db = -6.0
	elif rua:  # concreto: seco
		_passo.pitch_scale = _rng.randf_range(0.95, 1.08)
		_passo.volume_db = -8.0
	else:  # terra e mato: abafado
		_passo.pitch_scale = _rng.randf_range(1.1, 1.25)
		_passo.volume_db = -13.0
	if j.agachado:
		_passo.volume_db -= 8.0
	elif j.correndo:
		_passo.volume_db += 3.0
	_passo.play()


# coração: com vida abaixo de 35% ou zumbi a menos de 5 m, cada vez mais alto e mais rápido
func _coracao_bate(j: Jogador, dt: float) -> void:
	var medo: float = clampf((0.35 - float(j.vida) / j.vida_max()) / 0.25, 0.0, 1.0)
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z.vida > 0 and z.alvo == j and z.global_position.distance_to(j.global_position) < 5.0:
			medo = maxf(medo, 0.6)
			break
	var alvo_db: float = -80.0 if medo <= 0.0 else lerpf(-16.0, -2.0, medo)
	_coracao.volume_db = move_toward(_coracao.volume_db, alvo_db, dt * 90.0)
	_coracao.pitch_scale = lerpf(0.95, 1.25, medo)


# de vez em quando um som ao longe, de uma direção (o fone mostra de onde veio)
func _sustos(j: Jogador, dt: float, noite: float) -> void:
	_susto_t -= dt * (1.0 + noite * 0.6)
	if _susto_t > 0.0:
		return
	_susto_t = _rng.randf_range(SUSTO_DE, SUSTO_ATE)
	var a: float = _rng.randf() * TAU
	var p: Vector3 = j.global_position + Vector3(cos(a), 0.5, sin(a)) * _rng.randf_range(25.0, 45.0)
	var s := AudioStreamPlayer3D.new()
	var r: float = _rng.randf()
	var nome: String
	if r < 0.3:
		nome = "sombra_%d" % _rng.randi_range(1, 5)
	elif r < 0.5:
		nome = "rangido"
	elif r < 0.8:
		nome = "gemido_%d" % _rng.randi_range(0, 5)
	else:
		nome = ""  # tiro distante
	if nome == "":
		s.stream = Pistola._gera_estampido()
		s.pitch_scale = 0.75
		s.volume_db = -6.0
	else:
		s.stream = som(nome)
		s.pitch_scale = _rng.randf_range(0.85, 1.0)
	s.unit_size = 20.0
	s.max_distance = 80.0
	add_child(s)
	s.global_position = p
	s.finished.connect(s.queue_free)
	s.play()


# zumbis perto gemem (sem alvo) ou rosnam (vindo atrás de alguém); a voz fica presa no zumbi
func _gemidos(j: Jogador, dt: float) -> void:
	_geme_t -= dt
	if _geme_t > 0.0:
		return
	_geme_t = 0.4
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z.vida <= 0 or z.global_position.distance_to(j.global_position) > GEME_PERTO:
			continue
		var cacando: bool = z.alvo != null
		if _rng.randf() > (0.12 if cacando else 0.04):
			continue
		var v: AudioStreamPlayer3D = _vozes.get(z)
		if v == null or not is_instance_valid(v):
			v = AudioStreamPlayer3D.new()
			v.unit_size = 6.0
			v.max_distance = 40.0
			v.position.y = 1.5
			z.add_child(v)
			_vozes[z] = v
		if v.playing:
			continue
		v.stream = som("rosnado_%d" % _rng.randi_range(1, 16)) if cacando else som("gemido_%d" % _rng.randi_range(0, 5))
		v.pitch_scale = _rng.randf_range(0.75, 0.95)
		v.volume_db = -2.0 if cacando else -6.0
		v.play()
