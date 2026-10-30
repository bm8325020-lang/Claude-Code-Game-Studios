# Câmera em primeira pessoa (decisão do dono: em terceira pessoa a animação aparecia demais). Fica nos olhos
# do jogador (desce ao agachar), gira com o mouse/dedo, balança de leve ao andar e leva os braços com a arma
# (Maos). O corpo do próprio jogador só faz sombra; os outros veem o corpo inteiro animado.
class_name CameraPrimeira
extends Node3D

const ALTURA_EM_PE: float = 1.62
const ALTURA_AGACHADO: float = 1.05
const SUAVE_OLHAR: float = 28.0     # filtra o tremido do dedo/mouse sem atrasar o giro
const PITCH_MIN: float = -85.0      # olhando para cima
const PITCH_MAX: float = 85.0       # olhando para baixo
const FOV: float = 70.0             # proporções do padrão; o valor de verdade vem das configurações
const FOV_MIRA: float = 52.0
const FOV_CORRENDO: float = 76.0
const BALANCO: float = 0.022        # m que a cabeça sobe e desce andando

## Quem a câmera segue (um Jogador).
var alvo: Jogador
## Giro horizontal e vertical em radianos (pitch > 0 = olhando para baixo).
var yaw: float = 0.0
var pitch: float = 0.0
## Sensibilidade em graus por pixel (mouse) ou por pixel de arrasto (toque).
var sensibilidade: float = 0.18

var cam: Camera3D
var maos: Maos
var _altura: float = ALTURA_EM_PE
var _y_suave: float = 0.0
var _tremor: float = 0.0
var _recuo: float = 0.0  # coice do tiro (radianos para cima), volta sozinho
var _yaw_alvo: float = 0.0
## Zumbi mordendo: a câmera trava na cara dele e fecha o quadro (cena de briga); null = olhar livre.
var foco: Node3D
var _pitch_alvo: float = 0.0
var _passo: float = 0.0


func _ready() -> void:
	top_level = true  # gira sozinha; o corpo só acompanha o giro horizontal
	cam = Camera3D.new()
	cam.far = Config.qualidade().longe
	cam.near = 0.03
	cam.fov = FOV
	add_child(cam)
	cam.current = true
	maos = Maos.new()
	maos.alvo = alvo
	cam.add_child(maos)
	if alvo:
		_y_suave = alvo.global_position.y
		_yaw_alvo = yaw
		_pitch_alvo = pitch


func _process(dt: float) -> void:
	if alvo == null:
		return
	var olhar: Vector2 = alvo.entrada.get("olhar", Vector2.ZERO)
	alvo.entrada["olhar"] = Vector2.ZERO
	var sens: float = Config.sensibilidade(alvo.arma, alvo.mira_travada) * sensibilidade / Config.PADRAO.sens
	var y: float = -olhar.y if Config.v.inverter_y else olhar.y
	_yaw_alvo -= deg_to_rad(olhar.x * sens)
	_pitch_alvo = clampf(_pitch_alvo + deg_to_rad(y * sens), deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
	if foco and is_instance_valid(foco):
		var d: Vector3 = foco.global_position + Vector3(0, 1.55, 0) - global_position
		_yaw_alvo = atan2(-d.x, -d.z)
		_pitch_alvo = atan2(d.y, Vector2(d.x, d.z).length())
		_tremor = maxf(_tremor, 0.12)
	if alvo.fresta:  # de lado na fresta: de frente para a parede, olhando no máximo ~55° para cada ponta
		_yaw_alvo = alvo.yaw_fresta + clampf(angle_difference(alvo.yaw_fresta, _yaw_alvo), -0.95, 0.95)
	var k: float = 1.0 - exp(-SUAVE_OLHAR * dt)
	yaw = lerp_angle(yaw, _yaw_alvo, k)
	pitch = lerpf(pitch, _pitch_alvo, k)
	var p: Vector3 = alvo.get_global_transform_interpolated().origin
	_y_suave = lerpf(_y_suave, p.y, 1.0 - exp(-14.0 * dt))  # degraus e pousos não sacodem a tela
	_altura = lerpf(_altura, ALTURA_AGACHADO if alvo.agachado else ALTURA_EM_PE, 1.0 - exp(-10.0 * dt))
	# balanço da cabeça ao andar (some parado, no ar e mirando)
	var vel: float = Vector2(alvo.velocity.x, alvo.velocity.z).length() if alvo.is_on_floor() else 0.0
	_passo += dt * vel * 1.9
	var forca: float = clampf(vel / 4.0, 0.0, 1.0) * (0.35 if alvo.mira_travada else 1.0)
	global_position = Vector3(p.x, _y_suave + _altura + absf(sin(_passo)) * BALANCO * forca, p.z)
	_recuo = move_toward(_recuo, 0.0, dt * deg_to_rad(9.0))
	rotation = Vector3(-(pitch - _recuo), yaw, 0)
	var base: float = float(Config.v.fov)
	var fov_alvo: float = base * (FOV_MIRA if alvo.mira_travada else (FOV_CORRENDO if alvo.correndo else FOV)) / FOV
	if foco:
		fov_alvo = base * 0.72
	cam.fov = lerpf(cam.fov, fov_alvo, 1.0 - exp(-10.0 * dt))
	_tremor = maxf(0.0, _tremor - dt * 1.6)
	cam.h_offset = randf_range(-1.0, 1.0) * _tremor * 0.12 + sin(_passo * 0.5) * BALANCO * 0.6 * forca
	cam.v_offset = randf_range(-1.0, 1.0) * _tremor * 0.12


## Aponta a câmera na hora (sem suavizar), em radianos.
func virar(novo_yaw: float, novo_pitch: float = NAN) -> void:
	yaw = novo_yaw
	_yaw_alvo = novo_yaw
	if not is_nan(novo_pitch):
		pitch = clampf(novo_pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		_pitch_alvo = pitch


## Coice do tiro: a mira sobe `graus` e volta sozinha.
func coice(graus: float) -> void:
	_recuo += deg_to_rad(graus)


## Tremida curta (golpe acertando, explosão...).
func tremer(forca: float) -> void:
	_tremor = maxf(_tremor, forca)
