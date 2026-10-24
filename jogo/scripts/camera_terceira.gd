# Câmera em terceira pessoa por cima do ombro: gira com o mouse/dedo, não atravessa paredes (SpringArm3D),
# abaixa quando agacha e abre um pouco o campo de visão quando corre.
class_name CameraTerceira
extends Node3D

const DISTANCIA: float = 3.4
const DISTANCIA_MIRA: float = 2.3   # mira travada: câmera chega mais perto
const OMBRO_MIRA: float = 1.0       # e vai bem para o lado: o corpo sai do centro (onde fica a mira)
const ALTURA_MIRA: float = 1.8      # e sobe um pouco, por cima do ombro
const FOV_MIRA: float = 58.0        # leve zoom mirando
const OMBRO: float = 0.55           # deslocamento para a direita (por cima do ombro)
const SUAVE_OLHAR: float = 28.0     # filtra o tremido do dedo/mouse sem atrasar o giro
const ALTURA_EM_PE: float = 1.55
const ALTURA_AGACHADO: float = 1.05
const PITCH_MIN: float = -65.0      # olhando para cima
const PITCH_MAX: float = 50.0       # olhando para baixo
const FOV: float = 70.0
const FOV_CORRENDO: float = 77.0

## Quem a câmera segue (um Jogador).
var alvo: Jogador
## Giro horizontal e vertical em radianos.
var yaw: float = 0.0
var pitch: float = deg_to_rad(12.0)
## Sensibilidade em graus por pixel (mouse) ou por pixel de arrasto (toque).
var sensibilidade: float = 0.18

var braco: SpringArm3D
var cam: Camera3D
var _altura: float = ALTURA_EM_PE
var _y_suave: float = 0.0
var _tremor: float = 0.0
var _ombro: float = OMBRO
var _yaw_alvo: float = 0.0
var _pitch_alvo: float = deg_to_rad(12.0)


func _ready() -> void:
	top_level = true  # não herda o balanço do corpo; segue suave
	braco = SpringArm3D.new()
	braco.spring_length = DISTANCIA
	braco.margin = 0.2
	braco.collision_mask = 1
	var bola := SphereShape3D.new()
	bola.radius = 0.25
	braco.shape = bola
	add_child(braco)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.current = true
	braco.add_child(cam)
	if alvo:
		braco.add_excluded_object(alvo.get_rid())
		_y_suave = alvo.global_position.y
	_yaw_alvo = yaw


func _process(dt: float) -> void:
	if alvo == null:
		return
	var olhar: Vector2 = alvo.entrada.get("olhar", Vector2.ZERO)
	alvo.entrada["olhar"] = Vector2.ZERO
	_yaw_alvo -= deg_to_rad(olhar.x * sensibilidade)
	_pitch_alvo = clampf(_pitch_alvo + deg_to_rad(olhar.y * sensibilidade), deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
	var k: float = 1.0 - exp(-SUAVE_OLHAR * dt)
	yaw = lerp_angle(yaw, _yaw_alvo, k)
	pitch = lerpf(pitch, _pitch_alvo, k)
	var p: Vector3 = alvo.get_global_transform_interpolated().origin
	# altura segue com suavidade (degraus e pousos não sacodem a tela); no plano, segue colado
	_y_suave = lerpf(_y_suave, p.y, 1.0 - exp(-14.0 * dt))
	var mira: bool = alvo.mira_travada
	var alt_alvo: float = ALTURA_AGACHADO if alvo.agachado else (ALTURA_MIRA if mira else ALTURA_EM_PE)
	_altura = lerpf(_altura, alt_alvo, 1.0 - exp(-10.0 * dt))
	_ombro = lerpf(_ombro, OMBRO_MIRA if mira else OMBRO, 1.0 - exp(-12.0 * dt))
	# o ombro desloca o pivô (não a câmera): o SpringArm reposiciona a câmera todo quadro
	var direita := Vector3(cos(yaw), 0, -sin(yaw))
	global_position = Vector3(p.x, _y_suave + _altura, p.z) + direita * _ombro
	rotation = Vector3(-pitch, yaw, 0)
	var fov_alvo: float = FOV_MIRA if mira else (FOV_CORRENDO if alvo.correndo else FOV)
	cam.fov = lerpf(cam.fov, fov_alvo, 1.0 - exp(-10.0 * dt))
	braco.spring_length = lerpf(braco.spring_length, DISTANCIA_MIRA if mira else DISTANCIA, 1.0 - exp(-12.0 * dt))
	# tremida do golpe: some rápido
	_tremor = maxf(0.0, _tremor - dt * 1.6)
	cam.h_offset = randf_range(-1.0, 1.0) * _tremor * 0.35
	cam.v_offset = randf_range(-1.0, 1.0) * _tremor * 0.35


## Aponta a câmera na hora (sem suavizar), em radianos.
func virar(novo_yaw: float, novo_pitch: float = NAN) -> void:
	yaw = novo_yaw
	_yaw_alvo = novo_yaw
	if not is_nan(novo_pitch):
		pitch = novo_pitch
		_pitch_alvo = novo_pitch


## Treme a tela (0..1), por exemplo quando um golpe acerta.
func tremer(forca: float) -> void:
	_tremor = maxf(_tremor, forca)
