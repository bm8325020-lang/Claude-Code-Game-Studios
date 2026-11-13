# Vegetação pronta (Etapa D do prompt do mundo, 05/11): árvores, arbustos, capim e pedras baixados (Sketchfab CC BY,
# LICENCAS em assets/mundo) e acertados por tools/assets/normaliza.py (metros reais, base no chão, uma malha por planta).
# Aqui cada espécie vira malha + material com vento (shader VENTO: balança mais quanto mais alto o vértice; folha recortada
# pelo alfa). Planta._lote usa para os props "veg:<espécie>" do cidade.json (MultiMesh por pedaço, como os outros props).
class_name Vegetacao
extends RefCounted

const PASTA := "res://assets/mundo/vegetation/"
## espécie: [arquivo (pasta/nome), nó do pacote ("" = o modelo todo), tinta, balanço, raio do tronco (0 = sem colisão)]
const ESPECIES: Dictionary = {
	# árvores grandes (perto); a tinta puxa para o verde sujo do fim do mundo
	"arvore": ["trees/arvore", "", Color(0.82, 0.86, 0.74), 0.6, 0.3],
	"betula": ["trees/betula", "", Color(0.8, 0.84, 0.72), 0.7, 0.2],
	"pinheiro": ["trees/pinheiro", "", Color(0.78, 0.82, 0.76), 0.4, 0.3],
	"arvore_velha": ["trees/arvore_velha", "", Color(0.7, 0.68, 0.62), 0.2, 0.3],
	"arvore_morta": ["trees/arvore_morta", "", Color(0.75, 0.72, 0.68), 0.15, 0.3],
	"toco": ["trees/arvore_rachada", "", Color(0.8, 0.8, 0.78), 0.0, 0.6],
	# 07/11 anti-travamento: versões de longe (normaliza.py *_lod: folhas rareadas, tronco simples); Planta troca pela
	# distância. Mesma tinta e balanço da inteira.
	"arvore_lod": ["trees/arvore_lod", "", Color(0.82, 0.86, 0.74), 0.6, 0.0],
	"betula_lod": ["trees/betula_lod", "", Color(0.8, 0.84, 0.72), 0.7, 0.0],
	"pinheiro_lod": ["trees/pinheiro_lod", "", Color(0.78, 0.82, 0.76), 0.4, 0.0],
	"arvore_velha_lod": ["trees/arvore_velha_lod", "", Color(0.7, 0.68, 0.62), 0.2, 0.0],
	"arvore_morta_lod": ["trees/arvore_morta_lod", "", Color(0.75, 0.72, 0.68), 0.15, 0.0],
	"toco_lod": ["trees/arvore_rachada_lod", "", Color(0.8, 0.8, 0.78), 0.0, 0.0],
	# 13/11 (bairro de Los Angeles): palmeiras
	"palmeira": ["trees/palmeira", "", Color(0.85, 0.85, 0.72), 0.5, 0.25],
	"palmeira_lod": ["trees/palmeira_lod", "", Color(0.85, 0.85, 0.72), 0.5, 0.0],
	"palmeira_alta": ["trees/palmeira_alta", "", Color(0.85, 0.85, 0.72), 0.4, 0.2],
	"palmeira_alta_lod": ["trees/palmeira_alta_lod", "", Color(0.85, 0.85, 0.72), 0.4, 0.0],
	# pacote de floresta (poucos triângulos: serve para mata fechada)
	"conifera_1": ["trees/floresta", "floresta_0", Color(0.85, 0.88, 0.82), 0.4, 0.2],
	"outono_1": ["trees/floresta", "floresta_1", Color(0.85, 0.82, 0.75), 0.5, 0.2],
	"conifera_2": ["trees/floresta", "floresta_2", Color(0.85, 0.88, 0.82), 0.4, 0.2],
	"conifera_3": ["trees/floresta", "floresta_3", Color(0.85, 0.88, 0.82), 0.4, 0.2],
	"outono_2": ["trees/floresta", "floresta_4", Color(0.85, 0.82, 0.75), 0.5, 0.2],
	"conifera_4": ["trees/floresta", "floresta_5", Color(0.85, 0.88, 0.82), 0.4, 0.25],
	"conifera_5": ["trees/floresta", "floresta_6", Color(0.85, 0.88, 0.82), 0.4, 0.2],
	"conifera_6": ["trees/floresta", "floresta_7", Color(0.85, 0.88, 0.82), 0.4, 0.2],
	"capim_alto": ["trees/floresta", "floresta_8", Color(0.9, 0.88, 0.78), 1.0, 0.0],
	"pinheirinho": ["trees/floresta", "floresta_9", Color(0.85, 0.88, 0.82), 0.6, 0.0],
	"arbusto": ["trees/floresta", "floresta_10", Color(0.8, 0.8, 0.72), 0.8, 0.0],
	"abeto_baixo": ["trees/floresta", "floresta_11", Color(0.85, 0.88, 0.82), 0.6, 0.0],
	"arbusto_2": ["trees/floresta", "floresta_12", Color(0.8, 0.8, 0.72), 0.8, 0.0],
	"pedras": ["trees/floresta", "floresta_13", Color(0.85, 0.85, 0.85), 0.0, 0.0],
	"pedras_2": ["trees/floresta", "floresta_14", Color(0.85, 0.85, 0.85), 0.0, 0.0],
	"abeto_1": ["trees/floresta", "floresta_16", Color(0.85, 0.88, 0.82), 0.4, 0.25],
	"abeto_2": ["trees/floresta", "floresta_17", Color(0.85, 0.88, 0.82), 0.5, 0.15],
	"abeto_3": ["trees/floresta", "floresta_18", Color(0.85, 0.88, 0.82), 0.4, 0.25],
	"outono_3": ["trees/floresta", "floresta_19", Color(0.85, 0.82, 0.75), 0.5, 0.15],
	# chão
	"capim": ["plants/capim", "", Color(0.75, 0.72, 0.55), 1.0, 0.0],
	"capim_seco": ["plants/capim_seco", "", Color(0.62, 0.55, 0.4), 1.0, 0.0],
	"samambaia": ["plants/samambaia", "", Color(0.6, 0.62, 0.45), 0.8, 0.0],
	"samambaia_baixa": ["plants/samambaia_capim", "", Color(0.6, 0.62, 0.45), 0.8, 0.0],
	"moita": ["plants/moita", "", Color(0.75, 0.72, 0.6), 0.8, 0.0],
}
## o que não precisa de sombra (baixo) e some mais perto
const RASTEIRAS: Array[String] = ["capim", "capim_seco", "samambaia", "samambaia_baixa", "moita",
	"capim_alto", "arbusto", "arbusto_2", "pedras", "pedras_2", "abeto_baixo", "pinheirinho"]

static var _cache: Dictionary = {}  # espécie -> [ [Mesh, Transform3D] ], Shape do tronco ou null


## [[Mesh com material de vento, Transform3D dentro do modelo]] da espécie (vazio se não existir).
static func malhas(especie: String) -> Array:
	if _cache.has(especie):
		return _cache[especie][0]
	var e: Array = ESPECIES.get(especie, [])
	var lista: Array = []
	var arq: String = PASTA + "%s/%s.gltf" % [e[0], String(e[0]).get_file()] if not e.is_empty() else ""
	if arq != "" and ResourceLoader.exists(arq):
		var cena: Node3D = (load(arq) as PackedScene).instantiate()
		for mi: MeshInstance3D in cena.find_children("*", "MeshInstance3D", true, false):
			if e[1] != "" and String(mi.name) != e[1] and String(mi.get_parent().name) != e[1]:
				continue
			var t: Transform3D = Planta._rel(mi, cena)
			if e[1] != "":
				t.origin = Vector3.ZERO  # o pacote vem com as plantas lado a lado
			lista.append([_com_vento(mi.mesh, e[2], e[3]), t])
		cena.free()
	var tronco: Shape3D = null
	if not e.is_empty() and float(e[4]) > 0.0:
		var c := CylinderShape3D.new()
		c.radius = float(e[4])
		c.height = 3.0
		tronco = c
	_cache[especie] = [lista, tronco]
	return lista


## Forma de colisão do tronco (cilindro de 3 m, base no chão) ou null.
static func tronco(especie: String) -> Shape3D:
	malhas(especie)
	return _cache[especie][1]


static func _com_vento(origem: Mesh, tinta: Color, balanco: float) -> Mesh:
	var mesh: Mesh = origem.duplicate()
	var alt: float = maxf(origem.get_aabb().end.y, 0.5)
	for s in mesh.get_surface_count():
		var m: Material = mesh.surface_get_material(s)
		var sm := ShaderMaterial.new()
		sm.shader = _shader()
		sm.set_shader_parameter("cor", tinta)
		sm.set_shader_parameter("balanco", balanco)
		sm.set_shader_parameter("altura", alt)
		if m is BaseMaterial3D:
			var b: BaseMaterial3D = m
			sm.set_shader_parameter("tex", b.albedo_texture)
			sm.set_shader_parameter("tem_tex", b.albedo_texture != null)
			sm.set_shader_parameter("cor_base", b.albedo_color)
			if Estilo.LIGADO:  # 13/11: folha e tronco em cor lisa (só o recorte da folha usa a textura)
				var mc: Color = Estilo.cor_de(b.albedo_texture)
				if mc.v > 0.5:
					mc *= 0.55  # tronco claro (casca quase branca na média) ficava branco no sol
				sm.set_shader_parameter("liso", true)
				sm.set_shader_parameter("cor_lisa", Color(mc.r * b.albedo_color.r, mc.g * b.albedo_color.g, mc.b * b.albedo_color.b))
			if b.normal_enabled and b.normal_texture:
				sm.set_shader_parameter("tex_n", b.normal_texture)
				sm.set_shader_parameter("tem_n", true)
			var recorta: bool = b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			sm.set_shader_parameter("corte", (b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.4) if recorta else 0.0)
		mesh.surface_set_material(s, sm)
	return mesh


static var _vento: Shader


static func _shader() -> Shader:
	if _vento == null:
		_vento = Shader.new()
		_vento.code = VENTO
	return _vento


const VENTO := """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool tem_tex = false;
uniform bool tem_n = false;
uniform bool liso = false;
uniform vec3 cor_lisa : source_color = vec3(0.4, 0.6, 0.25);
uniform vec4 cor : source_color = vec4(1.0);
uniform vec4 cor_base : source_color = vec4(1.0);
uniform float corte = 0.0;
uniform float balanco = 0.5;
uniform float altura = 10.0;
void vertex() {
	vec3 w = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / altura, 0.0, 1.0);
	float t = TIME * 1.1 + w.x * 0.05 + w.z * 0.07;
	// o corpo todo balança devagar (mais em cima); as pontas tremem rápido
	VERTEX.xz += vec2(sin(t), cos(t * 0.73)) * balanco * h * h * min(altura, 12.0) * 0.012;
	VERTEX.x += sin(TIME * 3.7 + VERTEX.y * 1.7 + w.z) * balanco * h * 0.025;
}
void fragment() {
	vec4 c = tem_tex ? texture(tex, UV) : vec4(1.0);
	if (corte > 0.0 && c.a < corte) discard;
	ALBEDO = (liso ? cor_lisa * (0.85 + 0.3 * UV.y) : c.rgb * cor_base.rgb * cor.rgb) * COLOR.rgb;
	if (tem_n && !liso) NORMAL_MAP = texture(tex_n, UV).rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}"""
