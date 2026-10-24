# Câmera em terceira pessoa por cima do ombro: gira com o mouse/dedo, não atravessa paredes (SpringArm3D),
# abaixa quando agacha e abre um pouco o campo de visão quando corre.
class_name CameraTerceira
extends Node3D

const DISTANCIA: float = 3.4
const DISTANCIA_MIRA: float = 2.3   # mira travada: câmera chega mais perto do ombro
const OMBRO: float = 0.55           # deslocamento para a direita (por cima do ombro)
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
	cam.position.x = OMBRO
	cam.current = true
	braco.add_child(cam)
	if alvo:
		braco.add_excluded_object(alvo.get_rid())
		_y_suave = alvo.global_position.y


func _process(dt: float) -> void:
	if alvo == null:
		return
	var olhar: Vector2 = alvo.entrada.get("olhar", Vector2.ZERO)
	alvo.entrada["olhar"] = Vector2.ZERO
	yaw -= deg_to_rad(olhar.x * sensibilidade)
	pitch = clampf(pitch + deg_to_rad(olhar.y * sensibilidade), deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
	var p: Vector3 = alvo.get_global_transform_interpolated().origin
	# altura segue com suavidade (degraus e pousos não sacodem a tela); no plano, segue colado
	_y_suave = lerpf(_y_suave, p.y, 1.0 - exp(-14.0 * dt))
	_altura = lerpf(_altura, ALTURA_AGACHADO if alvo.agachado else ALTURA_EM_PE, 1.0 - exp(-10.0 * dt))
	global_position = Vector3(p.x, _y_suave + _altura, p.z)
	rotation = Vector3(-pitch, yaw, 0)
	cam.fov = lerpf(cam.fov, FOV_CORRENDO if alvo.correndo else FOV, 1.0 - exp(-6.0 * dt))
	braco.spring_length = lerpf(braco.spring_length, DISTANCIA_MIRA if alvo.mira_travada else DISTANCIA, 1.0 - exp(-10.0 * dt))
