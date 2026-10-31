# Enfeites da cidade (plano aprovado pelo dono em 30/10, "cara do jogo"): o que faz a rua parecer um lugar de verdade
# depois do fim do mundo. Chão misturando grama seca, terra e cascalho; lixo (papel, lata, garrafa, saco preto) na
# calçada e nos lotes; mato no pé das paredes e na beira da rua; manchas no chão (sangue seco, óleo, queimado); sacos de
# corpo; postes com fio (alguns tortos, fio caído); caçambas e lixeiras tombadas.
# Tudo em lote (MultiMesh por pedaço de 64 m, sumindo de longe pela qualidade): milhares de peças custam pouco no
# celular. O servidor sem tela não monta nada disso (só os postes e caçambas, que têm colisão).
class_name Enfeites
extends Node3D

const PEDACO: float = 64.0
## quantidade por nível de qualidade (Batata, Média, Alta, Ultra)
const DENSIDADE: Array[float] = [0.35, 0.6, 1.0, 1.4]
const POSTE_A_CADA: float = 30.0

var _b: Bairro
var _rng := RandomNumberGenerator.new()
var _lotes: Dictionary = {}  # "tipo|cx,cz" -> [Transform3D, Color]
var _malhas: Dictionary = {}  # tipo -> [Mesh, Material, alcance]


func monta(b: Bairro, ruas: Array, poligonos: Array) -> void:
	_b = b
	_rng.seed = 4242
	_postes(ruas)
	_cacambas(ruas)
	if Rede.servidor_sem_tela:
		return
	_prepara_malhas()
	var dens: float = DENSIDADE[clampi(int(Config.v.qualidade), 0, 3)]
	for r: Array in ruas:
		var a: Vector2 = r[0]
		var c: Vector2 = r[1]
		var d: Vector2 = c - a
		var lado := Vector2(d.y, -d.x).normalized()
		var meia: float = float(r[2]) * 0.5
		for k in int(d.length() * 0.35 * dens):  # calçada: lixo e mato no meio-fio
			var p: Vector2 = a.lerp(c, _rng.randf())
			var s: float = 1.0 if _rng.randf() < 0.5 else -1.0
			var fora: float = meia + _rng.randf_range(0.2, 3.2)
			_solta(["papel", "papel", "lata", "garrafa", "saco"][_rng.randi() % 5], p + lado * s * fora)
			if _rng.randf() < 0.6:
				_poe_mato(p + lado * s * (meia + _rng.randf_range(0.1, 0.5)))
			if _rng.randf() < 0.08:
				_mancha(p + lado * _rng.randf_range(-meia, meia), ["oleo", "sangue"][_rng.randi() % 2])
	for poly: PackedVector2Array in poligonos:  # pé das paredes e o lote em volta
		var c: Vector2 = _b._centro(poly)
		for i in poly.size():
			var a: Vector2 = poly[i]
			var e: Vector2 = poly[(i + 1) % poly.size()]
			var fora: Vector2 = (a.lerp(e, 0.5) - c).normalized()
			for k in int(a.distance_to(e) * 1.3 * dens):
				_poe_mato(a.lerp(e, _rng.randf()) + fora * _rng.randf_range(0.15, 0.6))
			for k in int(a.distance_to(e) * 0.15 * dens):
				_solta(["papel", "saco", "lata", "tabua"][_rng.randi() % 4], a.lerp(e, _rng.randf()) + fora * _rng.randf_range(0.5, 2.5))
		for k in int(4 * dens):  # lixo dentro
			_solta(["papel", "papel", "lata", "garrafa"][_rng.randi() % 4], c + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)))
	for k in int(260 * dens):  # mato e terra solta pelo campo
		var p := Vector2(_rng.randf_range(-230, 230), _rng.randf_range(-230, 230))
		if not _b._perto_de_rua(p, 1.0):
			for q in 6:
				_poe_mato(p + Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-2.5, 2.5)))
	for k in 40:  # sacos de corpo na rua, com a mancha embaixo
		var r: Array = ruas[_rng.randi() % ruas.size()]
		var p: Vector2 = (r[0] as Vector2).lerp(r[1], _rng.randf())
		_solta("corpo", p)
		_mancha(p, "sangue")
	_fecha_lotes()


# --- peças soltas em lote ---

func _solta(tipo: String, p: Vector2) -> void:
	var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, 0.0, p.y))
	var h: float = _b.altura(p)
	var cor := Color.WHITE
	match tipo:
		"papel":
			t.basis = t.basis * Basis(Vector3.RIGHT, _rng.randf_range(-0.08, 0.08))
			t.origin.y = 0.03
			cor = Color(0.85, 0.83, 0.76).darkened(_rng.randf() * 0.4)
		"lata":
			t.basis = t.basis * Basis(Vector3.FORWARD, PI * 0.5)  # deitada
			t.origin.y = 0.04
			cor = [Color(0.6, 0.12, 0.1), Color(0.65, 0.65, 0.68), Color(0.15, 0.3, 0.55)][_rng.randi() % 3]
		"garrafa":
			t.basis = t.basis * Basis(Vector3.FORWARD, PI * 0.5)
			t.origin.y = 0.05
			cor = [Color(0.15, 0.35, 0.18), Color(0.4, 0.25, 0.1), Color(0.6, 0.7, 0.68)][_rng.randi() % 3]
		"saco":
			t.basis = t.basis.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3))
			t.origin.y = 0.15
			cor = Color(0.06, 0.06, 0.07)
		"tabua":
			t.origin.y = 0.03
			cor = Color(0.42, 0.33, 0.24).darkened(_rng.randf() * 0.3)
		"corpo":
			t.origin.y = 0.18
			cor = [Color(0.12, 0.14, 0.12), Color(0.2, 0.2, 0.22)][_rng.randi() % 2]
	t.origin.y += h
	_guarda(tipo, t, cor)


var _casas: Array = []  # contorno (local do Bairro) de cada casa


func _poe_mato(p: Vector2) -> void:
	if _b._poligonos.any(func(pl: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, pl)):
		return  # nada de mato crescendo dentro de casa (dono, 31/10)
	if _casas.is_empty():
		for c: Node in _b.get_tree().get_nodes_in_group("casas"):  # a casa pode passar um pouco do lote
			_casas.append((c.get_meta("poly") as PackedVector2Array).duplicate())
	for pl: PackedVector2Array in _casas:
		if Geometry2D.is_point_in_polygon(p, pl):
			return
	var h: float = _b.altura(p)
	if h < Bairro.AGUA_Y + 0.1:
		return  # nada de mato debaixo d'água
	var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.4)), Vector3(p.x, h, p.y))
	_guarda("mato", t, Color(0.55, 0.5, 0.3).lerp(Color(0.35, 0.38, 0.2), _rng.randf()))


func _mancha(p: Vector2, tipo: String) -> void:
	var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 2.2)), Vector3(p.x, 0.045, p.y))
	var cor: Color = {"oleo": Color(0.02, 0.02, 0.02, 0.8), "sangue": Color(0.18, 0.02, 0.01, 0.85)}[tipo]
	_guarda("mancha", t, cor)


func _guarda(tipo: String, t: Transform3D, cor: Color) -> void:
	var chave: String = "%s|%d,%d" % [tipo, floori(t.origin.x / PEDACO), floori(t.origin.z / PEDACO)]
	if not _lotes.has(chave):
		_lotes[chave] = []
	_lotes[chave].append([t, cor])


func _fecha_lotes() -> void:
	var fator: float = Config.qualidade().detalhe / 45.0
	for chave: String in _lotes:
		var tipo: String = chave.get_slice("|", 0)
		var info: Array = _malhas[tipo]
		var lista: Array = _lotes[chave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = info[0]
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i][0])
			mm.set_instance_color(i, lista[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Lote_" + chave.replace("|", "_").replace(",", "_").replace("-", "m")
		mi.multimesh = mm
		mi.material_override = info[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = float(info[2]) * fator + PEDACO * 0.7
		add_child(mi)
	_lotes.clear()


func _prepara_malhas() -> void:
	var cor := StandardMaterial3D.new()  # cor vem de cada peça
	cor.vertex_color_use_as_albedo = true
	cor.roughness = 0.8
	var papel := BoxMesh.new()
	papel.size = Vector3(0.3, 0.005, 0.22)
	var lata := CylinderMesh.new()
	lata.top_radius = 0.033
	lata.bottom_radius = 0.033
	lata.height = 0.12
	lata.radial_segments = 8
	lata.rings = 1
	var garrafa := CylinderMesh.new()
	garrafa.top_radius = 0.015
	garrafa.bottom_radius = 0.04
	garrafa.height = 0.3
	garrafa.radial_segments = 8
	garrafa.rings = 1
	var saco := SphereMesh.new()
	saco.radius = 0.32
	saco.height = 0.38
	saco.radial_segments = 8
	saco.rings = 4
	var tabua := BoxMesh.new()
	tabua.size = Vector3(1.4, 0.03, 0.14)
	var corpo := CapsuleMesh.new()  # saco de corpo deitado
	corpo.radius = 0.28
	corpo.height = 1.85
	corpo.radial_segments = 8
	corpo.rings = 2
	var deitado := ArrayMesh.new()  # a cápsula em pé deitada no chão
	var arr: Array = corpo.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in v.size():
		v[i] = Vector3(v[i].x, v[i].z * 0.6, v[i].y)
		n[i] = Vector3(n[i].x, n[i].z, n[i].y).normalized()
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TANGENT] = null
	deitado.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mancha := QuadMesh.new()
	mancha.size = Vector2(1, 1)
	mancha.orientation = PlaneMesh.FACE_Y
	var m_mancha := ShaderMaterial.new()
	m_mancha.shader = Shader.new()
	m_mancha.shader.code = MANCHA
	var m_mato := ShaderMaterial.new()
	m_mato.shader = Shader.new()
	m_mato.shader.code = MATO
	_malhas = {"papel": [papel, cor, 25.0], "lata": [lata, cor, 18.0], "garrafa": [garrafa, cor, 18.0],
		"saco": [saco, cor, 45.0], "tabua": [tabua, cor, 35.0], "corpo": [deitado, cor, 60.0],
		"mancha": [mancha, m_mancha, 35.0], "mato": [_tufo(), m_mato, 30.0]}


## Tufo de mato: 3 folhas cruzadas (o shader recorta as lâminas e balança com o vento).
func _tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a: float = k * PI / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.35
		var h: float = 0.7
		var q: Array[Vector3] = [-d, d, d + Vector3(0, h, 0), -d + Vector3(0, h, 0)]
		var uv: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[i])
			st.add_vertex(q[i])
	return st.commit()


const MATO := """shader_type spatial;
render_mode cull_disabled;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float vento = sin(TIME * 1.7 + w.x * 0.3 + w.z * 0.2) * 0.07 * (1.0 - UV.y);
	VERTEX.x += vento;
}
void fragment() {
	// lâminas finas e de altura diferente; o resto é recortado
	float x = UV.x * 9.0;
	float lamina = abs(fract(x) - 0.5) * 2.0;
	float alto = 0.35 + 0.65 * fract(sin(floor(x) * 12.9898) * 43758.5);
	float topo = 1.0 - UV.y;
	if (topo > alto || lamina > 0.8 * (1.0 - topo / alto)) discard;
	ALBEDO = COLOR.rgb * (0.55 + 0.45 * topo);
	ROUGHNESS = 0.9;
}"""

const MANCHA := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
void fragment() {
	vec2 c = UV - 0.5;
	float ang = atan(c.y, c.x);
	float borda = 0.38 + 0.07 * sin(ang * 5.0 + COLOR.r * 40.0) + 0.04 * sin(ang * 11.0);
	float d = length(c);
	if (d > borda) discard;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * smoothstep(borda, borda - 0.12, d);
}"""


# --- coisas grandes (com colisão): postes com fio e caçambas ---

func _postes(ruas: Array) -> void:
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.25, 0.2, 0.16)
	madeira.roughness = 0.9
	var fio := StandardMaterial3D.new()
	fio.albedo_color = Color(0.03, 0.03, 0.03)
	var ant: Vector3 = Vector3.INF
	var corre: float = 0.0
	for r: Array in ruas:
		if float(r[2]) < 7.0:  # só nas ruas grandes
			ant = Vector3.INF
			continue
		var a: Vector2 = r[0]
		var c: Vector2 = r[1]
		var d: Vector2 = c - a
		var lado := Vector2(d.y, -d.x).normalized()
		corre += d.length()
		if corre < POSTE_A_CADA:
			continue
		corre = 0.0
		var p2: Vector2 = c + lado * (float(r[2]) * 0.5 + 1.3)
		var torto: float = _rng.randf_range(-0.03, 0.03) if _rng.randf() < 0.8 else _rng.randf_range(0.12, 0.3)
		var poste := StaticBody3D.new()
		poste.position = Vector3(p2.x, 0, p2.y)
		poste.rotation = Vector3(torto, atan2(d.x, d.y), 0)
		_b.add_child(poste)
		var cs := CollisionShape3D.new()
		var cil := CylinderShape3D.new()
		cil.radius = 0.15
		cil.height = 8.0
		cs.shape = cil
		cs.position.y = 4.0
		poste.add_child(cs)
		if Rede.servidor_sem_tela:
			continue
		_b._cilindro(poste, Vector3(0, 4.0, 0), 0.13, 8.0, madeira)
		var trave := _b._peca(poste, Vector3(0, 7.4, 0), Vector3(1.8, 0.12, 0.12), madeira)
		trave.rotation.y = PI * 0.5
		var topo: Vector3 = poste.transform * Vector3(0, 7.4, 0)  # no espaço do Bairro
		if ant != Vector3.INF and ant.distance_to(topo) < POSTE_A_CADA * 2.0:
			_fio(ant, topo, fio, torto > 0.1)
		ant = topo


## Fio entre dois postes, barrigudo (ou caído no chão quando o poste tombou).
func _fio(a: Vector3, b: Vector3, m: Material, caido: bool) -> void:
	var pts: Array[Vector3] = []
	for k in 7:
		var t: float = k / 6.0
		var p: Vector3 = a.lerp(b, t)
		p.y -= (4.0 * t * (1.0 - t)) * (6.5 if caido else 0.9)
		pts.append(Vector3(p.x, maxf(p.y, 0.03), p.z))
	for k in 6:
		var s: Vector3 = pts[k + 1] - pts[k]
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.012
		cm.height = s.length()
		cm.radial_segments = 4
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = Config.qualidade().detalhe * 2.5
		# o eixo do cilindro (Y) apontando ao longo do pedaço de fio
		var olha := Basis.looking_at(s.normalized(), Vector3.UP if absf(s.normalized().y) < 0.99 else Vector3.RIGHT)
		mi.transform = Transform3D(olha * Basis(Vector3.RIGHT, -PI * 0.5), (pts[k] + pts[k + 1]) * 0.5)
		_b.add_child(mi)


func _cacambas(ruas: Array) -> void:
	var verde := StandardMaterial3D.new()
	verde.albedo_color = Color(0.16, 0.24, 0.17)
	verde.roughness = 0.6
	var n: int = 0
	for r: Array in ruas:
		if n >= 30 or _rng.randf() < 0.75:
			continue
		var a: Vector2 = r[0]
		var c: Vector2 = r[1]
		var d: Vector2 = (c - a).normalized()
		var p: Vector2 = a.lerp(c, _rng.randf()) + Vector2(d.y, -d.x) * (float(r[2]) * 0.5 + 2.2) * (1.0 if _rng.randf() < 0.5 else -1.0)
		if _b._poligonos.any(func(pl: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, pl)):
			continue
		n += 1
		var corpo := StaticBody3D.new()
		corpo.position = Vector3(p.x, 0.7, p.y)
		corpo.rotation.y = atan2(d.x, d.y) + _rng.randf_range(-0.3, 0.3)
		_b.add_child(corpo)
		if Rede.servidor_sem_tela:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.8, 1.4, 1.2)
			cs.shape = bs
			corpo.add_child(cs)
			continue
		_b._caixa(corpo, Vector3(1.8, 1.4, 1.2), verde)  # caçamba
		var tampa := _b._peca(corpo, Vector3(0, 0.75, -0.2), Vector3(1.8, 0.05, 1.0), verde)
		tampa.rotation.x = -_rng.randf_range(0.2, 1.2)  # tampa meio aberta
		for k in 3:  # sacos transbordando
			_solta("saco", p + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2)))


## Chão do mapa: grama seca, terra e cascalho misturados por manchas grandes (sem o marrom liso até o horizonte).
static func chao() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = CHAO
	m.set_shader_parameter("grama", load("res://assets/texturas/grama_cor.jpg"))
	m.set_shader_parameter("terra", load("res://assets/texturas/terra_cor.jpg"))
	m.set_shader_parameter("cascalho", load("res://assets/texturas/asfalto_cor.jpg"))
	var ruido := NoiseTexture2D.new()
	ruido.seamless = true
	ruido.width = 256
	ruido.height = 256
	ruido.noise = FastNoiseLite.new()
	(ruido.noise as FastNoiseLite).frequency = 0.02
	m.set_shader_parameter("ruido", ruido)
	return m


const CHAO := """shader_type spatial;
uniform sampler2D grama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cascalho : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido : filter_linear, repeat_enable;
varying vec3 w;
void vertex() { w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = w.xz * 0.2;
	float n = texture(ruido, w.xz * 0.004).r;
	float n2 = texture(ruido, w.xz * 0.021 + 0.37).r;
	vec3 g = texture(grama, uv).rgb * vec3(0.72, 0.66, 0.5);
	vec3 t = texture(terra, uv * 0.7).rgb * vec3(0.8, 0.72, 0.62);
	vec3 c = texture(cascalho, uv * 1.6).rgb * vec3(0.75, 0.72, 0.68);
	vec3 cor = mix(g, t, smoothstep(0.42, 0.58, n));
	cor = mix(cor, c, smoothstep(0.62, 0.72, n2) * 0.7);
	cor *= 0.85 + 0.3 * texture(ruido, w.xz * 0.09).r;  // manchas de sujeira miúdas
	ALBEDO = cor;
	ROUGHNESS = 0.95;
}"""
