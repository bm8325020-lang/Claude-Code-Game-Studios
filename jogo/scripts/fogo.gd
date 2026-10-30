# Fogo (plano aprovado pelo dono, 30/10: "fogo de verdade"): chama animada (shader com ruído subindo, sem textura),
# luz que treme, fumaça subindo e se abrindo, faíscas, crepitar e dano a quem fica dentro. `tamanho` = raio da base em
# metros (barril ~0,35; casa queimada ~1,5). `coluna` = fumaça alta, que se vê de longe (casa queimada). O servidor sem
# tela só monta a área de dano. Barato no celular: poucas partículas, somem de longe.
class_name Fogo
extends Node3D

const DANO: int = 6
const DANO_A_CADA: float = 0.5

@export var tamanho: float = 0.35
@export var coluna: bool = false
var _luz: OmniLight3D
var _t: float = 0.0
var _dano_t: float = 0.0
var _area: Area3D
static var _mat_chama: ShaderMaterial
static var _mat_fumaca: ShaderMaterial


func _ready() -> void:
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2  # jogadores
	var cs := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = tamanho * 0.8
	cil.height = 1.2
	cs.shape = cil
	cs.position.y = 0.6
	_area.add_child(cs)
	add_child(_area)
	if Rede.servidor_sem_tela:
		return
	_t = randf() * 10.0
	_chama()
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.55, 0.22)
	_luz.omni_range = 5.0 + tamanho * 5.0
	_luz.position.y = 0.6 + tamanho
	_luz.distance_fade_enabled = true
	_luz.distance_fade_begin = 40.0
	add_child(_luz)
	_fumaca()
	_faiscas()
	var som := AudioStreamPlayer3D.new()
	var s: AudioStreamOggVorbis = (load("res://assets/sons/amb/fogo.ogg") as AudioStreamOggVorbis).duplicate()
	s.loop = true
	som.stream = s
	som.unit_size = 2.0 + tamanho * 2.0
	som.max_distance = 15.0 + tamanho * 8.0
	som.autoplay = true
	som.position.y = 0.5
	add_child(som)


func _process(dt: float) -> void:
	_t += dt
	if _luz:  # tremor: duas ondas e um ruído, nunca apaga
		_luz.light_energy = (2.4 + tamanho * 1.2) * (0.8 + 0.12 * sin(_t * 11.0) + 0.08 * sin(_t * 23.7 + 1.3) + randf_range(-0.06, 0.06))


func _physics_process(dt: float) -> void:
	_dano_t -= dt
	if _dano_t > 0.0:
		return
	for c: Node3D in _area.get_overlapping_bodies():
		var j := c as Jogador
		if j and j.local and j.vida > 0:
			_dano_t = DANO_A_CADA
			j.levar_dano(DANO, (j.global_position - global_position).normalized() * 0.5)


func _chama() -> void:
	if _mat_chama == null:
		_mat_chama = ShaderMaterial.new()
		_mat_chama.shader = Shader.new()
		_mat_chama.shader.code = CHAMA
	for k in 2:  # duas chamas cruzadas, um pouco diferentes (não parece cartaz)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(tamanho * 3.0, tamanho * 4.2 + 0.5)
		q.center_offset = Vector3(0, q.size.y * 0.5, 0)
		mi.mesh = q
		mi.material_override = _mat_chama
		mi.rotation.y = k * PI * 0.5 + 0.3
		mi.set_instance_shader_parameter("semente", randf() * 10.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 120.0
		add_child(mi)


func _fumaca() -> void:
	if _mat_fumaca == null:
		_mat_fumaca = ShaderMaterial.new()
		_mat_fumaca.shader = Shader.new()
		_mat_fumaca.shader.code = FUMACA
	var p := CPUParticles3D.new()
	p.amount = 24 if coluna else 8
	p.lifetime = 9.0 if coluna else 3.5
	p.preprocess = p.lifetime
	p.position.y = tamanho * 2.5 + 0.3
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.4, 1.2 if coluna else 0.6, 0.2)  # sobe e o vento leva
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.scale_amount_min = tamanho * 2.0
	p.scale_amount_max = tamanho * (6.0 if coluna else 3.0)
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.3))
	curva.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curva
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	p.material_override = _mat_fumaca
	p.visibility_range_end = 400.0 if coluna else 60.0
	p.color_ramp = Gradient.new()
	p.color_ramp.set_color(0, Color(0.15, 0.13, 0.12, 0.0))
	p.color_ramp.add_point(0.15, Color(0.13, 0.12, 0.11, 0.55))
	p.color_ramp.set_color(p.color_ramp.get_point_count() - 1, Color(0.3, 0.29, 0.28, 0.0))
	add_child(p)


func _faiscas() -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.position.y = tamanho
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = tamanho * 0.6
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.8, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.8
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.15)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	p.mesh = m
	p.visibility_range_end = 35.0
	add_child(p)


const CHAMA := """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
instance uniform float semente = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);  // 0 embaixo
	float t = TIME * 1.5 + semente;
	float n = ruido(vec2(uv.x * 6.0, uv.y * 4.0 - t * 3.0)) * 0.6 + ruido(vec2(uv.x * 13.0, uv.y * 9.0 - t * 5.0)) * 0.4;
	// fogo = ruído subindo, apagando com a altura e para os lados: vira línguas que sobem e se soltam
	float fogo = n * (1.15 - uv.y) * 1.9 - abs(uv.x - 0.5) * 2.6 - uv.y * 0.35;
	float a = smoothstep(0.18, 0.42, fogo);
	if (a < 0.02) discard;
	float calor = smoothstep(0.3, 0.9, fogo);
	vec3 cor = mix(vec3(0.75, 0.12, 0.02), vec3(1.0, 0.7, 0.25), calor);
	ALBEDO = cor * a * 1.4;
}"""

const FUMACA := """shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c) * 2.0;
	float borda = 1.0 - smoothstep(0.35, 1.0, d + sin(atan(c.y, c.x) * 5.0 + COLOR.a * 20.0) * 0.08);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * borda;
}"""
