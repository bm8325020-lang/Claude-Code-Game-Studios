# Grama de verdade (13/11, dono: visual estilizado das prints): tufos de folhinhas balançando no vento, só em volta da
# câmera (pedaços de TAM m; os longe somem). Uma máscara de 1 m (ruas com calçada e prédios) diz onde não nasce; ela é
# montada numa thread a partir das ruas e dos contornos do Bairro. Só cliente com tela; Batata não tem grama.
class_name Grama
extends Node3D

const TAM: float = 10.0
const RAIO: Array[int] = [0, 2, 3, 3]          # pedaços em volta da câmera, por qualidade (Batata .. Ultra)
const TUFOS: Array[int] = [0, 240, 340, 440]   # tufos por pedaço
const LADO: int = 1000

var bairro: Bairro
var _mascara: PackedByteArray
var _pronta: bool = false
var _tarefa: int = -1
var _pedacos: Dictionary = {}  # Vector2i -> MultiMeshInstance3D
var _malha: ArrayMesh
var _mat: ShaderMaterial
var _t: float = 0.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_malha = _tufo()
	_malha.surface_set_material(0, _mat)


func _mascara_de(ruas: Array, polys: Array) -> void:
	var m := PackedByteArray()
	m.resize(LADO * LADO)
	var meio: float = LADO * 0.5
	for r: Array in ruas:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var folga: float = float(r[2]) * 0.5 + 2.2  # calçada
		for z in range(maxi(0, int(minf(a.y, b.y) - folga + meio)), mini(LADO, int(maxf(a.y, b.y) + folga + meio) + 1)):
			for x in range(maxi(0, int(minf(a.x, b.x) - folga + meio)), mini(LADO, int(maxf(a.x, b.x) + folga + meio) + 1)):
				var p := Vector2(x - meio + 0.5, z - meio + 0.5)
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < folga:
					m[z * LADO + x] = 1
	for poly: PackedVector2Array in polys:
		var ret := Rect2(poly[0], Vector2.ZERO)
		for q: Vector2 in poly:
			ret = ret.expand(q)
		for z in range(maxi(0, int(ret.position.y + meio) - 1), mini(LADO, int(ret.end.y + meio) + 2)):
			for x in range(maxi(0, int(ret.position.x + meio) - 1), mini(LADO, int(ret.end.x + meio) + 2)):
				if Geometry2D.is_point_in_polygon(Vector2(x - meio + 0.5, z - meio + 0.5), poly):
					m[z * LADO + x] = 1
	_mascara = m


func _livre(l: Vector2) -> bool:
	var x: int = int(l.x + LADO * 0.5)
	var z: int = int(l.y + LADO * 0.5)
	return x >= 0 and z >= 0 and x < LADO and z < LADO and _mascara[z * LADO + x] == 0


func _process(dt: float) -> void:
	var q: int = clampi(int(Config.v.get("qualidade", 1)), 0, 3)
	if RAIO[q] == 0 or bairro == null:
		return
	if not _pronta:
		if _tarefa < 0:
			var polys: Array = []
			for n: Node in bairro.get_children():
				if n.has_meta("poly"):
					polys.append(PackedVector2Array(n.get_meta("poly")))
				elif n.has_meta("sem_grama"):  # 14/11: chão da Estação (não é casa para o resto do Bairro)
					polys.append(PackedVector2Array(n.get_meta("sem_grama")))
			var ruas: Array = bairro._ruas.duplicate()
			_tarefa = WorkerThreadPool.add_task(_mascara_de.bind(ruas, polys))
		elif WorkerThreadPool.is_task_completed(_tarefa):
			WorkerThreadPool.wait_for_task_completion(_tarefa)
			_pronta = true
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.2
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var l := Vector2(cam.global_position.x - Bairro.ORIGEM.x, cam.global_position.z - Bairro.ORIGEM.z)
	var c := Vector2i(floori(l.x / TAM), floori(l.y / TAM))
	var feitos: int = 0
	for dz in range(-RAIO[q], RAIO[q] + 1):
		for dx in range(-RAIO[q], RAIO[q] + 1):
			var k := c + Vector2i(dx, dz)
			if not _pedacos.has(k) and feitos < 3:  # no máximo 3 por vez: andar não dá tranco
				_pedacos[k] = _pedaco(k, TUFOS[q])
				feitos += 1
	for k: Vector2i in _pedacos.keys():
		if absi(k.x - c.x) > RAIO[q] + 1 or absi(k.y - c.y) > RAIO[q] + 1:
			if _pedacos[k]:
				(_pedacos[k] as Node).queue_free()
			_pedacos.erase(k)


func _pedaco(k: Vector2i, n: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var ts: Array[Transform3D] = []
	for i in n:
		var l := Vector2((k.x + rng.randf()) * TAM, (k.y + rng.randf()) * TAM)
		var gira: float = rng.randf() * TAU
		var esc: float = rng.randf_range(0.7, 1.3)
		if not _livre(l):
			continue
		var p := Vector3(l.x, bairro.altura(l), l.y) + Bairro.ORIGEM
		ts.append(Transform3D(Basis(Vector3.UP, gira).scaled(Vector3(esc, esc, esc)), p))
	if ts.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _malha
	mm.instance_count = ts.size()
	for i in ts.size():
		mm.set_instance_transform(i, ts[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Um tufo: 14 folhas (triângulo fino cada), espalhadas num raio de ~0,45 m; UV.y = altura na folha (0 pé, 1 ponta).
func _tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var o := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var a: float = rng.randf() * TAU
		var lado := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.025, 0.045)
		var alt: float = rng.randf_range(0.25, 0.5)
		var curva := Vector3(-sin(a), 0.0, cos(a)) * rng.randf_range(-0.12, 0.12)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(o - lado)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(o + lado)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(o + curva + Vector3(0, alt, 0))
	return st.commit()


const SHADER := """shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert_wrap;
uniform vec3 base : source_color = vec3(0.2, 0.38, 0.1);
uniform vec3 ponta : source_color = vec3(0.5, 0.72, 0.24);
varying float h;
varying float tom;
void vertex() {
	h = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.7 + w.x * 0.13 + w.z * 0.09;
	VERTEX.x += sin(t) * 0.11 * h * h;
	VERTEX.z += cos(t * 0.8) * 0.07 * h * h;
	tom = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	ALBEDO = mix(base, ponta * (0.88 + tom * 0.24), h);
	ROUGHNESS = 1.0;
}"""
