# Visual de desenho (13/11, dono: "faça um jogo estilizado, completo... quero tudo estilizado"): todo material com
# textura vira cor lisa com sombra de desenho (toon). A cor é a média da textura (tabela assets/estilo_cores.json, feita
# por tools/estilo_cores.gd) vezes a tinta do material; a sombra de canto assada nas cores dos vértices continua.
# main._ready liga o gancho: cada GeometryInstance3D que entra na árvore entra na fila e é convertido no próximo quadro.
class_name Estilo
extends RefCounted

const LIGADO: bool = true
const TABELA := "res://assets/estilo_cores.json"
const SEM_COR := Color(0.7, 0.68, 0.64)
const CLAREIA: float = 1.35

static var _cores: Dictionary = {}
static var _lidas: bool = false
static var _mats: Dictionary = {}    # id do material velho -> material liso
static var _malhas: Dictionary = {}  # id da malha velha -> cópia com materiais lisos
static var fila: Array = []


static func cor_de(tex: Texture2D) -> Color:
	if not _lidas:
		_lidas = true
		var f := FileAccess.open(TABELA, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cores = d
	if tex == null:
		return SEM_COR
	var c: Variant = _cores.get(tex.resource_path)
	return Color(c[0], c[1], c[2]) if c is Array else SEM_COR


## Material liso no lugar de `m` (o mesmo `m` quando não tem textura, é transparente ou é shader).
static func liso(m: Material) -> Material:
	var b := m as BaseMaterial3D
	if b == null or b.albedo_texture == null or b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return m
	var k: int = m.get_instance_id()
	if _mats.has(k):
		return _mats[k]
	var n := StandardMaterial3D.new()
	var t: Color = cor_de(b.albedo_texture)
	var k2: float = CLAREIA if b.albedo_color.v < 0.75 else 1.0  # tintas escurecidas do realista (Bairro.ESCURO) voltam
	n.albedo_color = Color(minf(t.r * b.albedo_color.r * k2, 1.0), minf(t.g * b.albedo_color.g * k2, 1.0), minf(t.b * b.albedo_color.b * k2, 1.0))
	n.vertex_color_use_as_albedo = b.vertex_color_use_as_albedo
	n.shading_mode = b.shading_mode
	n.cull_mode = b.cull_mode
	n.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP  # sombra macia (toon deixava o lado da sombra preto)
	n.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	n.roughness = 1.0
	n.disable_receive_shadows = b.disable_receive_shadows
	_mats[k] = n
	return n


static func _malha(me: Mesh) -> Mesh:
	var am := me as ArrayMesh
	if am == null:
		return me
	var k: int = me.get_instance_id()
	if _malhas.has(k):
		return _malhas[k]
	var muda: bool = false
	for i in am.get_surface_count():
		var m: Material = am.surface_get_material(i)
		if m and liso(m) != m:
			muda = true
	var r: Mesh = me
	if muda:
		var c := am.duplicate() as ArrayMesh
		for i in c.get_surface_count():
			var m: Material = c.surface_get_material(i)
			if m:
				c.surface_set_material(i, liso(m))
		r = c
	_malhas[k] = r
	return r


static func converte(g: Node) -> void:
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.material_override:
			mi.material_override = liso(mi.material_override)
		if mi.mesh == null:
			return
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m:
				var n: Material = liso(m)
				if n != m:
					mi.set_surface_override_material(i, n)
	elif g is MultiMeshInstance3D:
		var mmi := g as MultiMeshInstance3D
		if mmi.material_override:
			mmi.material_override = liso(mmi.material_override)
		if mmi.multimesh and mmi.multimesh.mesh:
			mmi.multimesh.mesh = _malha(mmi.multimesh.mesh)


## main: chamado em todo nó que entra na árvore.
static func entrou(n: Node) -> void:
	if n is GeometryInstance3D and not n.has_meta("sem_estilo"):
		fila.append(n)


## Tudo embaixo de `raiz` (o mundo pronto: pega o que ganhou malha ou material depois de entrar na árvore).
static func tudo(raiz: Node) -> void:
	fila.append_array(raiz.find_children("*", "GeometryInstance3D", true, false).filter(func(n: Node) -> bool: return not n.has_meta("sem_estilo")))


## main._process: converte o que entrou desde o último quadro.
static func passa() -> void:
	if fila.is_empty():
		return
	var f: Array = fila
	fila = []
	for n: Variant in f:  # sem tipo: nó já liberado não pode ir para uma variável Object
		if is_instance_valid(n):
			converte(n)
