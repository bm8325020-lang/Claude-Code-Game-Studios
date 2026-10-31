# Clima (31/10, dono: "chuvas, nevasca e etc"): o servidor sorteia a cada amanhecer (Ciclo.clima vai pela rede) e cada
# aparelho desenha: chuva/neve em volta da câmera (CPUParticles: leve no celular), névoa mais fechada, sol mais fraco e,
# na tempestade, relâmpagos.
class_name Clima
extends Node3D

## nome -> [chance, partículas ("" / "chuva" / "neve"), névoa ×, sol ×]
const TIPOS: Dictionary = {
	"limpo": [0.4, "", 1.0, 1.0],
	"chuva": [0.22, "chuva", 1.6, 0.7],
	"tempestade": [0.12, "chuva", 2.2, 0.5],
	"neblina": [0.14, "", 4.0, 0.8],
	"nevasca": [0.12, "neve", 3.0, 0.8],
}
var _chuva: CPUParticles3D
var _neve: CPUParticles3D
var _raio_t: float = 0.0
var flash: float = 0.0  # 0..1: o Ciclo soma na luz


static func sorteia(rng: RandomNumberGenerator) -> String:
	var r: float = rng.randf()
	for k: String in TIPOS:
		r -= float(TIPOS[k][0])
		if r <= 0.0:
			return k
	return "limpo"


func _ready() -> void:
	_chuva = _particulas(1400, Vector2(0.025, 0.8), Color(0.75, 0.8, 0.85, 0.6), Vector3(0, -22, 0), 0.7)
	_neve = _particulas(1200, Vector2(0.14, 0.14), Color(1, 1, 1, 1), Vector3(1.2, -2.0, 0.5), 5.0)


func _particulas(n: int, tam: Vector2, cor: Color, grav: Vector3, vida: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 1, 13)
	p.gravity = grav
	p.direction = Vector3.DOWN
	p.spread = 4.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.local_coords = false
	p.emitting = false
	var q := QuadMesh.new()
	q.size = tam
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = cor
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if tam.y > tam.x * 2.0 else BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Chamado pelo Ciclo a cada quadro: liga as partículas do clima atual em volta da câmera.
func passa(tipo: String, dt: float) -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var part: String = TIPOS.get(tipo, TIPOS.limpo)[1]
	_chuva.emitting = part == "chuva" and cam != null
	_neve.emitting = part == "neve" and cam != null
	if cam:
		global_position = cam.global_position + Vector3(0, 9, 0)
	flash = maxf(flash - dt * 4.0, 0.0)
	if tipo == "tempestade":
		_raio_t -= dt
		if _raio_t <= 0.0:
			_raio_t = randf_range(6.0, 18.0)
			flash = 1.0
