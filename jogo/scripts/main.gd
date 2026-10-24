# Pista de teste da mecânica 1 (andar + câmera): chão xadrez, caixas, rampas de 15°, 30° e 50° (íngreme demais),
# escada, túnel baixo para agachar, muros para testar a câmera contra paredes e um "carro" parado.
extends Node3D

var jogador: Jogador
var controles: Controles


func _ready() -> void:
	_luz()
	_chao()
	_obstaculos()
	jogador = Jogador.new()
	jogador.name = "Jogador"
	add_child(jogador)
	jogador.global_position = Vector3(0, 0.1, 0)
	controles = Controles.new()
	controles.jogador = jogador
	add_child(controles)


func _luz() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 40.0
	add_child(sol)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.68)  # céu cinza de apocalipse
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.66, 0.68)
	env.fog_density = 0.008
	amb.environment = env
	add_child(amb)


func _mat(cor: Color, xadrez: bool = false) -> Material:
	if not xadrez:
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.9
		return m
	# xadrez de 1 m: dá para ver a velocidade e a distância andando
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec3 a; uniform vec3 b;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = floor(wp.xz);
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(a, b, k);
	ROUGHNESS = 0.95;
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("a", Vector3(cor.r, cor.g, cor.b))
	sm.set_shader_parameter("b", Vector3(cor.r * 0.82, cor.g * 0.82, cor.b * 0.82))
	return sm


## Bloco sólido com colisão (centro, tamanho, giro em graus).
func bloco(c: Vector3, tam: Vector3, cor: Color, rot: Vector3 = Vector3.ZERO, xadrez: bool = false) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.position = c
	corpo.rotation_degrees = rot
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor, xadrez)
	corpo.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	corpo.add_child(cs)
	add_child(corpo)
	return corpo


func _chao() -> void:
	bloco(Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color(0.42, 0.41, 0.38), Vector3.ZERO, true)


func _rampa(base: Vector3, graus: float, comprimento: float, largura: float, cor: Color) -> void:
	# rampa subindo para +Z a partir de `base`, seguida de uma plataforma no topo
	var h: float = sin(deg_to_rad(graus)) * comprimento
	var meio: Vector3 = base + Vector3(0, h * 0.5, cos(deg_to_rad(graus)) * comprimento * 0.5)
	bloco(meio - Vector3(0, 0.1, 0), Vector3(largura, 0.2, comprimento), cor, Vector3(-graus, 0, 0), true)
	var topo_z: float = base.z + cos(deg_to_rad(graus)) * comprimento
	bloco(Vector3(base.x, h * 0.5 - 0.01, topo_z + 2.0), Vector3(largura, h, 4.0), cor, Vector3.ZERO, true)


func _obstaculos() -> void:
	var concreto := Color(0.55, 0.53, 0.5)
	var ferrugem := Color(0.5, 0.33, 0.22)
	# caixas: 0,4 m (pulo fácil), 1,0 m (pulo no limite), 2,5 m (não dá)
	bloco(Vector3(-4, 0.2, -6), Vector3(1.2, 0.4, 1.2), ferrugem)
	bloco(Vector3(-6, 0.5, -6), Vector3(1.2, 1.0, 1.2), ferrugem)
	bloco(Vector3(-8.5, 1.25, -6), Vector3(1.5, 2.5, 1.5), ferrugem)
	# rampas
	_rampa(Vector3(6, 0, -14), 15.0, 8.0, 3.0, concreto)
	_rampa(Vector3(11, 0, -14), 30.0, 6.0, 3.0, concreto)
	_rampa(Vector3(16, 0, -14), 50.0, 4.0, 3.0, Color(0.6, 0.4, 0.38))  # íngreme demais: escorrega
	# escada: degraus de 0,2 m; uma rampa invisível embaixo deixa subir sem pular
	for i in 8:
		var alto: float = (i + 1) * 0.2
		bloco(Vector3(-14, alto * 0.5, -10 - i * 0.35), Vector3(2.4, alto, 0.35), concreto)
	var ang: float = rad_to_deg(atan2(1.6, 2.8))
	var rampa_escada := bloco(Vector3(-14, 0.78, -10.875), Vector3(2.4, 0.05, Vector2(2.8, 1.6).length()), concreto, Vector3(ang, 0, 0))
	(rampa_escada.get_child(0) as MeshInstance3D).visible = false
	# túnel baixo (1,4 m): só passa agachado
	bloco(Vector3(0, 1.6, 12), Vector3(3, 0.4, 6), concreto)
	bloco(Vector3(-1.7, 0.7, 12), Vector3(0.4, 1.4, 6), concreto)
	bloco(Vector3(1.7, 0.7, 12), Vector3(0.4, 1.4, 6), concreto)
	# muros e um corredor estreito: a câmera tem que chegar perto sem atravessar
	bloco(Vector3(12, 2, 8), Vector3(0.5, 4, 14), concreto)
	bloco(Vector3(15, 2, 8), Vector3(0.5, 4, 14), concreto)
	bloco(Vector3(-12, 3, 10), Vector3(8, 6, 8), Color(0.48, 0.47, 0.46))  # "prédio"
	# "carro" abandonado
	bloco(Vector3(5, 0.7, 6), Vector3(1.9, 1.0, 4.2), Color(0.3, 0.35, 0.4), Vector3(0, 20, 0))
	bloco(Vector3(5, 1.45, 6), Vector3(1.7, 0.6, 2.2), Color(0.25, 0.3, 0.35), Vector3(0, 20, 0))
