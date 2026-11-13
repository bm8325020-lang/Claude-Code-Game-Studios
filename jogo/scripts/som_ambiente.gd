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
var _passaros: AudioStreamPlayer
var _pingos: AudioStreamPlayer
var _agua: AudioStreamPlayer
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
var _radio: AudioStreamPlayer3D
var _radio_t: float = 0.0
var _trovejou: bool = false
var _rio: AudioStreamPlayer
var _grilos: AudioStreamPlayer
var _vento_mata: AudioStreamPlayer
var _agua_t: float = 0.0
var _agua_d: float = INF


func _ready() -> void:
	if Rede.servidor_sem_tela:
		set_process(false)
		return
	_rng.randomize()
	_vento = _toca_sempre("vento", -14.0)
	# 06/11: pássaros de dia lá fora, pingos dentro de casa, água escorrendo nas calhas quando chove (OpenGameArt CC0)
	_passaros = _toca_sempre("passaros", -80.0)
	_pingos = _toca_sempre("pingos", -80.0)
	_agua = _toca_sempre("agua", -80.0)
	_coracao = _toca_sempre("coracao", -80.0)
	# 13/11 floresta (OpenGameArt CC0): água correndo perto do rio/lago, grilos de noite, vento nas folhas
	_rio = _toca_sempre("rio", -80.0)
	_grilos = _toca_sempre("grilos", -80.0)
	_vento_mata = _toca_sempre("vento_mata", -80.0)
	# 13/11 (dono: "músicas de fundo"): trilha de dia e de noite (OpenGameArt CC0), trocando devagar com o ciclo
	_mus_dia = _musica("dia")
	_mus_noite = _musica("noite")
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


# volume vai devagar até o alvo (entrar em casa não corta o som de uma vez)
func _suave(p: AudioStreamPlayer, alvo: float, dt: float) -> void:
	p.volume_db = move_toward(p.volume_db, alvo, dt * 25.0)


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


var _mus_dia: AudioStreamPlayer
var _mus_noite: AudioStreamPlayer
const MUSICA_DB: float = -17.0


func _musica(nome: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = (load("res://assets/musica/%s.ogg" % nome) as AudioStreamOggVorbis).duplicate()
	s.loop = true
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _process(dt: float) -> void:
	var j: Jogador = principal.jogador if principal else null
	var ciclo: Ciclo = principal.ciclo if principal else null
	var noite: float = ciclo.noite() if ciclo else 0.0
	_suave(_mus_dia, MUSICA_DB if noite < 0.5 else -80.0, dt * 0.15)
	_suave(_mus_noite, MUSICA_DB + 2.0 if noite >= 0.5 else -80.0, dt * 0.15)
	if ciclo and ciclo.get_node_or_null("Clima"):
		var cl: Node = ciclo.get_node("Clima")
		if cl.flash > 0.95 and not _trovejou:  # relâmpago: o trovão chega um pouco depois
			_trovejou = true
			get_tree().create_timer(_rng.randf_range(0.6, 2.0)).timeout.connect(func() -> void:
				var t := AudioStreamPlayer.new()
				t.stream = som("trovao")
				t.volume_db = -4.0
				t.pitch_scale = _rng.randf_range(0.8, 1.05)
				add_child(t)
				t.finished.connect(t.queue_free)
				t.play())
		elif cl.flash < 0.5:
			_trovejou = false
	_vento.volume_db = lerpf(-15.0, -9.0, noite)
	if j == null or not is_instance_valid(j) or not j.is_inside_tree():
		return
	var dentro: bool = principal.bairro != null and principal.bairro.casa_em(j.global_position) != ""
	AudioServer.set_bus_effect_enabled(0, _eco, dentro)
	var chuva: bool = ciclo != null and ciclo.clima in ["chuva", "tempestade"]
	_suave(_passaros, (-17.0 if not dentro else -30.0) if noite < 0.5 and not chuva else -80.0, dt)
	_suave(_pingos, -16.0 if dentro else -80.0, dt)
	_suave(_agua, (-14.0 if not dentro else -24.0) if chuva else -80.0, dt)
	_agua_t -= dt
	if _agua_t <= 0.0 and principal.bairro:
		_agua_t = 0.5
		_agua_d = principal.bairro.dist_agua(j.global_position)
	_suave(_rio, lerpf(-5.0, -55.0, clampf(_agua_d / 45.0, 0.0, 1.0)) if _agua_d < 45.0 else -80.0, dt)
	_suave(_grilos, (-15.0 if not dentro else -28.0) if noite > 0.5 and not chuva else -80.0, dt)
	_suave(_vento_mata, (-17.0 if not dentro else -32.0), dt)
	_passos(j, dentro)
	_coracao_bate(j, dt)
	_sustos(j, dt, noite)
	_radio_perto(j, dt)
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
	if noite > 0.5 and r < 0.2:  # 13/11 floresta: de noite coruja e lobo uivando longe
		nome = "coruja" if r < 0.12 else "lobo_%d" % _rng.randi_range(1, 2)
	elif r < 0.22:
		nome = "sombra_%d" % _rng.randi_range(1, 5)
	elif r < 0.36:
		nome = "rangido"
	elif r < 0.6:
		nome = "gemido_%d" % _rng.randi_range(0, 5)
	elif r < 0.7 + noite * 0.08:  # 06/11 terror: grito de gente ao longe (mais de noite)
		nome = "grito"
	elif r < 0.76:
		nome = "porta_bate"
	elif r < 0.8:
		nome = "explosao_longe"
	elif r < 0.85:  # 13/11: cachorro latindo, vidro quebrando e metal batendo ao longe
		nome = "cachorro"
	elif r < 0.9:
		nome = "vidro"
	elif r < 0.94:
		nome = "metal"
	else:
		nome = ""  # tiro distante
	if nome == "":
		s.stream = load("res://assets/sons/armas/%s_1.ogg" % ["pistola", "fuzil", "espingarda"][_rng.randi() % 3])
		s.pitch_scale = 0.8
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


# 06/11 terror: rádio esquecido ligado numa casa em cada RADIO_CADA, chiando e dando a notícia da Febre Cinzenta em
# loop; um só tocador muda para a casa com rádio mais perto (até RADIO_PERTO m)
const RADIO_CADA: int = 7
const RADIO_PERTO: float = 30.0
func _radio_perto(j: Jogador, dt: float) -> void:
	_radio_t -= dt
	if _radio_t > 0.0:
		return
	_radio_t = 1.0
	if _radio == null:
		_radio = AudioStreamPlayer3D.new()
		var st: AudioStreamOggVorbis = som("radio").duplicate()
		st.loop = true
		_radio.stream = st
		_radio.unit_size = 4.0
		_radio.max_distance = RADIO_PERTO
		_radio.volume_db = -4.0
		var chiado := AudioStreamPlayer3D.new()
		var ch: AudioStreamOggVorbis = som("chiado").duplicate()
		ch.loop = true
		chiado.stream = ch
		chiado.unit_size = 3.0
		chiado.max_distance = RADIO_PERTO
		chiado.volume_db = -12.0
		_radio.add_child(chiado)
		add_child(_radio)
	var melhor: Node3D = null
	var md: float = RADIO_PERTO * RADIO_PERTO
	for casa: Node3D in get_tree().get_nodes_in_group("casas"):
		if absi(hash(casa.name)) % RADIO_CADA != 0:
			continue
		var d: float = casa.global_position.distance_squared_to(j.global_position)
		if d < md:
			md = d
			melhor = casa
	var chiado: AudioStreamPlayer3D = _radio.get_child(0)
	if melhor == null:
		if _radio.playing:
			_radio.stop()
			chiado.stop()
		return
	_radio.global_position = melhor.global_position + Vector3(0, 1.0, 0)
	if not _radio.playing:
		_radio.play(_rng.randf() * 60.0)
		chiado.play()


# zumbis perto gemem (sem alvo) ou rosnam (vindo atrás de alguém); a voz fica presa no zumbi
func _gemidos(j: Jogador, dt: float) -> void:
	_geme_t -= dt
	if _geme_t > 0.0:
		return
	_geme_t = 0.4
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z.vida <= 0 or z.humano() or z.global_position.distance_to(j.global_position) > GEME_PERTO:
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
