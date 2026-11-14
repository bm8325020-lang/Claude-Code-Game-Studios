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
## 14/11: fogueira de acampamento: lenha cruzada e brasa no chão por baixo da chama
@export var lenha: bool = false
var _luz: OmniLight3D
var _t: float = 0.0
var _dano_t: float = 0.0
var _area: Area3D
static var _mat_chama: ShaderMaterial
static var _mat_fumaca: ShaderMaterial


func _ready() -> void:
	if coluna:
		add_to_group("fogo_coluna")  # os corvos rodam em cima da fumaça
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
	if lenha:
		_lenha()
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


# 14/11 (dono: "fogo bosta"): as placas cruzadas viravam cartaz de perto. Agora são línguas de fogo soltas (partículas
# viradas para a câmera) que nascem claras embaixo, ficam laranja e vermelhas e somem subindo, mais um miolo quente.
func _chama() -> void:
	if _mat_chama == null:
		_mat_chama = ShaderMaterial.new()
		_mat_chama.shader = Shader.new()
		_mat_chama.shader.code = CHAMA
	var k: float = clampf(tamanho / 0.35, 0.6, 4.0)
	for miolo: bool in [false, true]:
		var p := CPUParticles3D.new()
		p.amount = int(round((10.0 if not miolo else 5.0) * sqrt(k)))
		p.lifetime = (0.75 if not miolo else 0.45) * sqrt(k)
		p.preprocess = p.lifetime
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = tamanho * (0.55 if not miolo else 0.3)
		p.position.y = tamanho * 0.25
		p.direction = Vector3.UP
		p.spread = 8.0
		p.gravity = Vector3(0, 2.2, 0)
		p.initial_velocity_min = 0.5 * sqrt(k)
		p.initial_velocity_max = 1.2 * sqrt(k)
		p.angle_min = -15.0
		p.angle_max = 15.0
		p.scale_amount_min = tamanho * (1.5 if not miolo else 1.1)
		p.scale_amount_max = tamanho * (2.3 if not miolo else 1.5)
		var curva := Curve.new()  # cresce rápido e afina subindo
		curva.add_point(Vector2(0, 0.55))
		curva.add_point(Vector2(0.25, 1.0))
		curva.add_point(Vector2(1, 0.15))
		p.scale_amount_curve = curva
		p.color_ramp = Gradient.new()
		if miolo:
			p.color_ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
			p.color_ramp.set_color(1, Color(1.0, 0.6, 0.15, 0.0))
		else:
			p.color_ramp.set_color(0, Color(1.0, 0.8, 0.35, 0.9))
			p.color_ramp.add_point(0.35, Color(1.0, 0.45, 0.08, 0.85))
			p.color_ramp.add_point(0.7, Color(0.8, 0.15, 0.03, 0.5))
			p.color_ramp.set_color(p.color_ramp.get_point_count() - 1, Color(0.3, 0.05, 0.02, 0.0))
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		p.mesh = q
		p.material_override = _mat_chama
		p.draw_order = CPUParticles3D.DRAW_ORDER_LIFETIME  # as novas (claras) por cima
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_range_end = 120.0
		p.set_meta("sem_estilo", true)
		add_child(p)


func _lenha() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.14, 0.09)
	m.roughness = 1.0
	var c := CylinderMesh.new()
	c.top_radius = tamanho * 0.13
	c.bottom_radius = tamanho * 0.15
	c.height = tamanho * 2.2
	c.radial_segments = 6
	c.rings = 1
	for k in 4:  # lenha em cruz, encostada no meio
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = m
		var a: float = k * PI * 0.5 + 0.4
		mi.rotation = Vector3(0, a, 0)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5 - 0.45)
		mi.position = Vector3(sin(a), 0, cos(a)) * tamanho * 0.45 + Vector3(0, tamanho * 0.25, 0)
		add_child(mi)
	var brasa := MeshInstance3D.new()  # brasa no chão: disco vermelho que pulsa (shader BRASA)
	var d := CylinderMesh.new()
	d.top_radius = tamanho * 0.75
	d.bottom_radius = tamanho * 0.8
	d.height = 0.04
	d.radial_segments = 12
	d.rings = 1
	brasa.mesh = d
	var mb := ShaderMaterial.new()
	mb.shader = Shader.new()
	mb.shader.code = BRASA
	brasa.material_override = mb
	brasa.position.y = 0.02
	brasa.set_meta("sem_estilo", true)
	add_child(brasa)


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
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {  // virada para a câmera, mas em pé (a ponta da chama sempre para cima)
	vec3 x = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x * s, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(cross(x, vec3(0, 1, 0)) * s, 0.0), MODEL_MATRIX[3]);
}
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 c = vec2(UV.x - 0.5, 1.0 - UV.y);  // y: 0 embaixo, 1 em cima
	float n = ruido(vec2(UV.x * 5.0 + COLOR.a * 7.0, c.y * 4.0 - TIME * 4.0));
	c.x += (n - 0.5) * 0.18 * c.y;  // a ponta balança
	// gota de cabeça para baixo: redonda embaixo, afina para a ponta
	float larg = mix(0.34, 0.02, pow(c.y, 0.8));
	float forma = 1.0 - smoothstep(larg * 0.55, larg, abs(c.x));
	forma *= smoothstep(0.0, 0.18, c.y) * (1.0 - smoothstep(0.75, 1.0, c.y));
	if (forma < 0.01) discard;
	float quente = 1.0 - smoothstep(0.0, larg, abs(c.x)) * 0.6;  // miolo mais claro
	ALBEDO = min(COLOR.rgb * (0.85 + quente * 0.45), vec3(1.0));  // mistura (não soma): de dia não estoura no branco
	ALPHA = clamp(forma * COLOR.a * 1.3, 0.0, 1.0);
}"""

const BRASA := """shader_type spatial;
render_mode unshaded, shadows_disabled;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float pisca = 0.7 + 0.3 * sin(TIME * 3.0 + h(floor(UV * 9.0)) * 6.28);
	float g = h(floor(UV * 14.0));
	vec3 cinza = vec3(0.12, 0.1, 0.09);
	vec3 brasa = mix(vec3(0.7, 0.12, 0.02), vec3(1.0, 0.45, 0.1), g) * pisca * 1.6;
	ALBEDO = mix(cinza, brasa, step(0.45, g) * (1.0 - smoothstep(0.25, 0.5, length(c))));
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
