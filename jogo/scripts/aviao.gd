# Avião de carga (14/11, dono: item 6 "eventos que quebram a rotina"): cruza o céu por cima de onde a caixa de
# suprimento vai cair, roncando, e some do outro lado. Só aparência e som; cada aparelho desenha o seu
# (main.aviao_passa, pelo servidor). Blocos lisos (combina com o Estilo); o ronco é gerado aqui (sem arquivo).
class_name Aviao
extends Node3D

const ALTURA: float = 75.0  # acima das sequoias (~60 m); a câmera do celular vê só 100-120 m: mais alto some
const VEL: float = 45.0      # m/s
const LONGE: float = 650.0   # m antes e depois do ponto

var alvo: Vector3            # onde a caixa cai (o avião passa por cima)
var rumo: Vector3 = Vector3.FORWARD
var _som: AudioStreamPlayer3D
static var _ronco: AudioStreamWAV


func _ready() -> void:
	rumo.y = 0.0
	rumo = rumo.normalized()
	global_position = alvo - rumo * LONGE + Vector3(0, ALTURA, 0)
	look_at(global_position + rumo, Vector3.UP)
	var cinza := Color(0.32, 0.35, 0.33)
	_bloco(Vector3(0, 0, 0), Vector3(2.6, 2.6, 16.0), cinza)                       # fuselagem
	_bloco(Vector3(0, 0.3, 1.0), Vector3(26.0, 0.35, 3.4), cinza.darkened(0.1))   # asa
	_bloco(Vector3(0, 0.6, 7.2), Vector3(9.0, 0.3, 2.0), cinza.darkened(0.1))     # leme de trás
	_bloco(Vector3(0, 2.3, 7.4), Vector3(0.3, 3.4, 2.2), cinza.darkened(0.2))     # deriva
	for x: float in [-5.5, 5.5, -9.5, 9.5]:                                         # motores
		_bloco(Vector3(x, -0.4, 0.2), Vector3(1.1, 1.1, 2.6), cinza.darkened(0.3))
	_som = AudioStreamPlayer3D.new()
	_som.stream = _gera_ronco()
	_som.unit_size = 60.0
	_som.max_distance = 900.0
	_som.volume_db = 6.0
	_som.autoplay = true
	add_child(_som)


func _bloco(pos: Vector3, tam: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 1.0
	mat.disable_fog = true  # a névoa da mata apagava ele: fica a silhueta no céu
	mi.material_override = mat
	mi.position = pos  # -Z é a frente (look_at): o rabo fica em +Z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(dt: float) -> void:
	global_position += rumo * VEL * dt
	if (global_position - alvo).dot(rumo) > LONGE:
		queue_free()


## Ronco grave em laço: ruído marrom com a batida dos motores (60 e 90 Hz).
static func _gera_ronco() -> AudioStreamWAV:
	if _ronco:
		return _ronco
	var taxa: int = 22050
	var n: int = taxa * 2
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var marrom: float = 0.0
	for i in n:
		var t: float = float(i) / taxa
		marrom = clampf(marrom + randf_range(-0.08, 0.08), -1.0, 1.0) * 0.995
		var v: float = marrom * 0.55 + sin(TAU * 60.0 * t) * 0.25 + sin(TAU * 90.0 * t) * 0.15 * (0.6 + 0.4 * sin(TAU * 3.0 * t))
		dados.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	_ronco = AudioStreamWAV.new()
	_ronco.format = AudioStreamWAV.FORMAT_16_BITS
	_ronco.mix_rate = taxa
	_ronco.data = dados
	_ronco.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ronco.loop_end = n
	return _ronco
