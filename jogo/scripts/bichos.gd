# Coisas que se mexem (plano aprovado pelo dono, 30/10): bandos de corvos rodando alto (de preferência em cima da fumaça
# das casas queimadas), corvos no chão bicando que levantam voo grasnando quando você chega perto, e folhas de papel
# rolando com o vento. Só em volta do jogador e só no aparelho que desenha (nada disso vai pela rede).
class_name Bichos
extends Node3D

const BANDOS: int = 2
const POR_BANDO: int = 6
const NO_CHAO: int = 4
const ESPANTA: float = 7.0   # m: chegou mais perto que isso, o corvo do chão voa
const PAPEIS: int = 6
const VENTO := Vector3(0.9, 0, 0.45)

var principal: Node
var _bandos: Array = []   # [{centro, raio, alto, vel, corvos: [Node3D]}]
var _chao: Array = []     # [{no, voando, vel, t}]
var _papeis: Array = []   # [{no, vel, giro}]
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _preto: StandardMaterial3D
var _som_bando: AudioStreamPlayer3D


func _ready() -> void:
	if Rede.servidor_sem_tela:
		set_process(false)
		return
	_rng.randomize()
	_preto = StandardMaterial3D.new()
	_preto.albedo_color = Color(0.03, 0.03, 0.035)
	_preto.roughness = 0.6
	_preto.cull_mode = BaseMaterial3D.CULL_DISABLED
	for b in BANDOS:
		var corvos: Array = []
		for k in POR_BANDO:
			corvos.append(_corvo())
		_bandos.append({"centro": Vector3.INF, "raio": 10.0, "alto": 24.0, "vel": 0.4, "corvos": corvos})
	for k in NO_CHAO:
		_chao.append({"no": _corvo(), "voando": false, "vel": Vector3.ZERO, "t": 0.0, "pos": Vector3.INF})
	var papel := StandardMaterial3D.new()
	papel.albedo_color = Color(0.82, 0.8, 0.72)
	papel.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in PAPEIS:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.24, 0.32)
		mi.mesh = q
		mi.material_override = papel
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_papeis.append({"no": mi, "vel": 0.0, "giro": Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2), _rng.randf_range(-3, 3)), "pos": Vector3.INF})
	_som_bando = AudioStreamPlayer3D.new()
	_som_bando.stream = load("res://assets/sons/amb/corvos.ogg")
	_som_bando.unit_size = 25.0
	_som_bando.max_distance = 90.0
	add_child(_som_bando)


## Corvo feito em código: corpo, cabeça e bico; as asas batem no _process (filhos "AsaE"/"AsaD").
func _corvo() -> Node3D:
	var c := Node3D.new()
	add_child(c)
	var corpo := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.09
	esf.height = 0.18
	esf.radial_segments = 6
	esf.rings = 3
	corpo.mesh = esf
	corpo.scale = Vector3(1.0, 0.9, 2.2)
	corpo.material_override = _preto
	c.add_child(corpo)
	var cab := MeshInstance3D.new()
	cab.mesh = esf
	cab.scale = Vector3.ONE * 0.6
	cab.position = Vector3(0, 0.04, -0.22)
	cab.material_override = _preto
	c.add_child(cab)
	for lado in [-1.0, 1.0]:
		var asa := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.38, 0.2)
		q.center_offset = Vector3(lado * 0.19, 0, 0)
		q.orientation = PlaneMesh.FACE_Y
		asa.mesh = q
		asa.material_override = _preto
		asa.name = "AsaE" if lado < 0 else "AsaD"
		c.add_child(asa)
	return c


func _process(dt: float) -> void:
	var j: Jogador = principal.jogador if principal else null
	if j == null or not is_instance_valid(j):
		return
	_t += dt
	var p: Vector3 = j.global_position
	_voa_bandos(p, dt)
	_corvos_do_chao(p, dt)
	_papel(p, dt)


func _bate(c: Node3D, rapido: float) -> void:
	var a: float = sin(_t * rapido + c.get_index()) * 0.9
	(c.get_node("AsaE") as Node3D).rotation.z = a
	(c.get_node("AsaD") as Node3D).rotation.z = -a


# bando rodando alto; longe demais do jogador, vai para outra fumaça (ou ponto) perto dele
func _voa_bandos(p: Vector3, dt: float) -> void:
	for b: Dictionary in _bandos:
		if b.centro == Vector3.INF or Vector2(b.centro.x - p.x, b.centro.z - p.z).length() > 120.0:
			b.centro = _ponto_do_bando(p)
			b.raio = _rng.randf_range(7.0, 15.0)
			b.alto = _rng.randf_range(16.0, 30.0)
			b.vel = _rng.randf_range(0.25, 0.45) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var n: int = b.corvos.size()
		for k in n:
			var c: Node3D = b.corvos[k]
			var a: float = _t * b.vel + TAU * k / n + sin(_t * 0.3 + k) * 0.4
			var r: float = b.raio * (0.8 + 0.25 * sin(_t * 0.5 + k * 1.7))
			var pos: Vector3 = b.centro + Vector3(cos(a) * r, b.alto + sin(_t * 0.7 + k) * 1.5, sin(a) * r)
			var dir: Vector3 = Vector3(-sin(a), 0, cos(a)) * signf(b.vel)
			c.global_position = pos
			c.look_at(pos + dir, Vector3.UP)
			_bate(c, 9.0 if int(_t * 0.5 + k) % 3 != 0 else 0.0)  # bate e plana
	if not _som_bando.playing and _rng.randf() < dt * 0.05:
		_som_bando.global_position = _bandos[0].centro + Vector3(0, _bandos[0].alto, 0)
		_som_bando.play()


func _ponto_do_bando(p: Vector3) -> Vector3:
	var fumacas: Array = get_tree().get_nodes_in_group("fogo_coluna").filter(func(f: Node3D) -> bool: return f.global_position.distance_to(p) < 110.0)
	if not fumacas.is_empty() and _rng.randf() < 0.7:
		return (fumacas[_rng.randi() % fumacas.size()] as Node3D).global_position
	var a: float = _rng.randf() * TAU
	return p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(30.0, 70.0)


# corvos bicando no chão; espantados voam para cima e para longe grasnando, e depois pousam em outro lugar
func _corvos_do_chao(p: Vector3, dt: float) -> void:
	for c: Dictionary in _chao:
		var no: Node3D = c.no
		if c.pos == Vector3.INF or (not c.voando and Vector2(c.pos.x - p.x, c.pos.z - p.z).length() > 60.0):
			var a: float = _rng.randf() * TAU
			var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(18.0, 40.0)
			var b: Bairro = principal.bairro
			q.y = (b.altura(Vector2(q.x - Bairro.ORIGEM.x, q.z - Bairro.ORIGEM.z)) if b else 0.0) + 0.1
			c.pos = q
			c.voando = false
			no.global_position = q
			no.rotation = Vector3(0, _rng.randf() * TAU, 0)
		if not c.voando:
			no.position.y = c.pos.y + absf(sin(_t * 3.0 + no.get_index())) * 0.03  # bicando
			_bate(no, 0.0)
			if no.global_position.distance_to(p) < ESPANTA:
				c.voando = true
				c.t = 5.0
				var fuga: Vector3 = (no.global_position - p)
				fuga.y = 0.0
				c.vel = fuga.normalized() * 6.0 + Vector3(0, 4.5, 0)
				var s := AudioStreamPlayer3D.new()
				s.stream = load("res://assets/sons/amb/corvo_1.ogg")
				s.pitch_scale = _rng.randf_range(0.85, 1.1)
				s.unit_size = 8.0
				no.add_child(s)
				s.finished.connect(s.queue_free)
				s.play()
		else:
			c.t -= dt
			no.global_position += c.vel * dt
			no.look_at(no.global_position + c.vel, Vector3.UP)
			_bate(no, 16.0)
			if c.t <= 0.0:
				c.pos = Vector3.INF  # pousa em outro lugar


# papel rolando com o vento perto do chão; longe, volta para trás do jogador (contra o vento)
func _papel(p: Vector3, dt: float) -> void:
	var b: Bairro = principal.bairro
	for f: Dictionary in _papeis:
		var no: MeshInstance3D = f.no
		if f.pos == Vector3.INF or f.pos.distance_to(p) > 28.0:
			var lado := Vector3(-VENTO.z, 0, VENTO.x).normalized()
			f.pos = p - VENTO.normalized() * _rng.randf_range(12.0, 24.0) + lado * _rng.randf_range(-14.0, 14.0)
			f.vel = _rng.randf_range(1.5, 3.5)
		f.pos += VENTO.normalized() * f.vel * dt * (0.6 + 0.6 * absf(sin(_t * 0.8 + no.get_index())))  # rajadas
		var chao: float = b.altura(Vector2(f.pos.x - Bairro.ORIGEM.x, f.pos.z - Bairro.ORIGEM.z)) if b else 0.0
		f.pos.y = chao + 0.08 + absf(sin(_t * 1.7 + no.get_index() * 2.0)) * 0.9
		no.global_position = f.pos
		no.rotation += (f.giro as Vector3) * dt
