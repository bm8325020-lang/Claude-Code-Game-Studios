# Jogador em terceira pessoa: andar, correr, agachar e pular, relativo à câmera.
# A entrada vem de `entrada` (teclado/mouse, toque ou bot de teste preenchem o mesmo dicionário),
# assim a mecânica é a mesma em qualquer aparelho e dá para testar sem tela.
class_name Jogador
extends CharacterBody3D

# --- valores de ajuste (m/s, m/s², s) ---
const ANDAR: float = 1.9
const TROTE: float = 4.6
const CORRER: float = 7.2
const AGACHADO: float = 1.7
const ACEL_CHAO: float = 22.0
const ACEL_AR: float = 6.0
const FREIO: float = 28.0
const GIRO: float = 12.0          # quão rápido o corpo vira para onde anda
const GRAVIDADE: float = 24.0
const PULO: float = 7.9           # ~1,3 m de altura: sobe em capô e caixa de 1 m
const COYOTE: float = 0.12        # ainda pula logo depois de sair da borda
const BUFFER_PULO: float = 0.15   # aperto um pouco antes de tocar o chão também vale
const ALTURA_EM_PE: float = 1.8
const ALTURA_AGACHADO: float = 1.15
const RAIO: float = 0.32

## Entrada do frame: move (Vector2, -1..1, y = frente), olhar (Vector2, graus), pular (bool, apertou agora),
## correr (bool, segurando), agachar (bool, alternou agora), andar (bool, segurando: passo lento no PC).
var entrada: Dictionary = {"move": Vector2.ZERO, "olhar": Vector2.ZERO, "pular": false, "correr": false,
	"agachar": false, "andar": false}

var agachado: bool = false
var correndo: bool = false
var camera: CameraTerceira
var modelo: Node3D
var anim: AnimationPlayer

var _forma: CapsuleShape3D
var _colisor: CollisionShape3D
var _teto: ShapeCast3D
var _coyote: float = 0.0
var _buffer: float = 0.0
var _no_ar_desde: float = 0.0
var _pousando: float = 0.0
var _clipe: String = ""


func _ready() -> void:
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	collision_layer = 2
	collision_mask = 1
	_forma = CapsuleShape3D.new()
	_forma.radius = RAIO
	_forma.height = ALTURA_EM_PE
	_colisor = CollisionShape3D.new()
	_colisor.shape = _forma
	_colisor.position.y = ALTURA_EM_PE * 0.5
	add_child(_colisor)
	# confere se cabe ficar em pé antes de levantar (túnel baixo, debaixo de carro)
	_teto = ShapeCast3D.new()
	var s := SphereShape3D.new()
	s.radius = RAIO * 0.95
	_teto.shape = s
	_teto.position.y = ALTURA_AGACHADO
	_teto.target_position = Vector3(0, ALTURA_EM_PE - ALTURA_AGACHADO - RAIO + 0.05, 0)
	_teto.collision_mask = 1
	_teto.enabled = true
	add_child(_teto)
	_monta_modelo()
	camera = CameraTerceira.new()
	camera.alvo = self
	add_child(camera)


func _monta_modelo() -> void:
	modelo = (load(Anims.MODELO) as PackedScene).instantiate()
	add_child(modelo)
	anim = AnimationPlayer.new()
	modelo.add_child(anim)
	anim.add_animation_library("", Anims.biblioteca())
	_toca("parado", 0.0)


func _physics_process(dt: float) -> void:
	var mov: Vector2 = entrada.get("move", Vector2.ZERO)
	if mov.length() > 1.0:
		mov = mov.normalized()
	if entrada.get("agachar", false):
		_alterna_agachar()
		entrada["agachar"] = false
	if entrada.get("pular", false):
		_buffer = BUFFER_PULO
		entrada["pular"] = false
	correndo = bool(entrada.get("correr", false)) and not agachado and mov.y > 0.3

	# direção relativa à câmera (só o giro horizontal)
	var yaw: float = camera.yaw if camera else 0.0
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	var direita := Vector3(cos(yaw), 0, -sin(yaw))
	var dir: Vector3 = (direita * mov.x + frente * mov.y)
	var forca: float = mov.length()

	var alvo_vel: float
	if agachado:
		alvo_vel = AGACHADO
	elif correndo:
		alvo_vel = CORRER
	elif entrada.get("andar", false) or forca < 0.55:
		alvo_vel = ANDAR  # stick meio empurrado = andar devagar
	else:
		alvo_vel = TROTE
	var desejada: Vector3 = dir.normalized() * alvo_vel * clampf(forca / 0.55, 0.0, 1.0) if forca > 0.08 else Vector3.ZERO

	var plano := Vector3(velocity.x, 0, velocity.z)
	var acel: float = (ACEL_CHAO if desejada.length() > plano.length() else FREIO) if is_on_floor() else ACEL_AR
	plano = plano.move_toward(desejada, acel * dt)
	velocity.x = plano.x
	velocity.z = plano.z

	# pulo com coyote time e buffer
	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote -= dt
	_buffer -= dt
	if _buffer > 0.0 and _coyote > 0.0:
		if agachado and not _cabe_em_pe():
			_buffer = 0.0
		else:
			if agachado:
				_alterna_agachar()
			velocity.y = PULO
			_buffer = 0.0
			_coyote = 0.0
			_toca("pulo_inicio", 0.08)
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
		_no_ar_desde += dt
	var estava_no_ar: bool = not is_on_floor()
	move_and_slide()
	if estava_no_ar and is_on_floor() and _no_ar_desde > 0.35:
		_pousando = 0.22
	if is_on_floor():
		_no_ar_desde = 0.0

	# o corpo vira para onde está andando
	if plano.length() > 0.3:
		var ang: float = atan2(plano.x, plano.z)
		modelo.rotation.y = lerp_angle(modelo.rotation.y, ang, 1.0 - exp(-GIRO * dt))
	_anima(dt, plano.length())


func _alterna_agachar() -> void:
	if agachado and not _cabe_em_pe():
		return  # tem teto em cima: continua agachado
	agachado = not agachado
	_forma.height = ALTURA_AGACHADO if agachado else ALTURA_EM_PE
	_colisor.position.y = _forma.height * 0.5


func _cabe_em_pe() -> bool:
	_teto.force_shapecast_update()
	return not _teto.is_colliding()


func _anima(dt: float, vel: float) -> void:
	_pousando -= dt
	var clipe: String
	if not is_on_floor() and (_no_ar_desde > 0.12 or velocity.y > 0.5):
		clipe = "no_ar" if _clipe != "pulo_inicio" or not anim.is_playing() else "pulo_inicio"
	elif _pousando > 0.0:
		clipe = "pouso"
	elif agachado:
		clipe = "agachado" if vel < 0.2 else "agachado_andar"
	elif vel < 0.15:
		clipe = "parado"
	elif vel < 3.0:
		clipe = "andar"
	elif vel < 6.0:
		clipe = "trote"
	else:
		clipe = "correr"
	_toca(clipe, 0.18)
	# pés acompanham o chão: escala a velocidade do clipe pela velocidade real
	var base: float = float(Anims.VELOCIDADE.get(clipe, 0.0))
	anim.speed_scale = clampf(vel / base, 0.7, 1.5) if base > 0.1 and vel > 0.15 else 1.0


func _toca(clipe: String, mistura: float) -> void:
	if clipe == _clipe:
		return
	_clipe = clipe
	anim.play(clipe, mistura)


## Clipe tocando agora (para testes e depuração).
func clipe_atual() -> String:
	return _clipe
