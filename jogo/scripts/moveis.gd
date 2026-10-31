# Móveis realistas (31/10, dono: "casas realistas, não caixas"): os móveis das ruínas do Blender são caixas que dão a
# colisão e o lugar; aqui cada caixa some e no lugar entra um modelo de verdade (Poly Haven, CC0, assets/moveis) do mesmo
# tamanho, virado para o mesmo lado. Escolhe pelo nome da caixa (tools/blender/ruinas.py: "<movel>_<comodo><k>") e
# sorteia o modelo pelo nome da casa (igual em todo aparelho). Só quem desenha (o servidor sem tela não monta nada).
class_name Moveis

const PASTA: String = "res://assets/moveis/%s/%s.gltf"
## pedaço do nome da caixa -> modelos possíveis (o primeiro que aparecer no nome vale)
const TROCA: Array = [
	["cadeira", ["dining_chair_02", "SchoolChair_01"]],
	["escrivaninha", ["metal_office_desk"]],
	["mesa_centro", ["CoffeeTable_01"]],
	["mesa", ["WoodenTable_01"]],
	["sofa", ["Sofa_01", "sofa_02", "sofa_03"]],
	["poltrona", ["ArmChair_01", "modern_arm_chair_01"]],
	["estante", ["wooden_bookshelf_worn", "Shelf_01"]],
	["despensa", ["steel_frame_shelves_02"]],
	["cama", ["old_bed_frame"]],
	["criado", ["painted_wooden_nightstand", "ClassicNightstand_01"]],
	["guarda_roupa", ["painted_wooden_cabinet"]],
	["fogao", ["electric_stove"]],
	["quadro", ["hanging_picture_frame_01", "hanging_picture_frame_02"]],
	["tv_", ["Television_01"]],
]
const LONGE: float = 38.0  # m: mais longe que isso o móvel não é desenhado (celular)
static var _cenas: Dictionary = {}


static func _cena(nome: String) -> PackedScene:
	if not _cenas.has(nome):
		var c: String = PASTA % [nome, nome]
		_cenas[nome] = load(c) if ResourceLoader.exists(c) else null
	return _cenas[nome]


## Troca as caixas de móvel desta casa (ruína) pelos modelos. Devolve quantos trocou.
static func troca(casa: Node3D) -> int:
	if Rede.servidor_sem_tela:
		return 0
	var n: int = 0
	var h: int = absi(hash(String(casa.name)))
	for mi: MeshInstance3D in casa.find_children("*", "MeshInstance3D", true, false):
		var nome: String = String(mi.name)
		for par: Array in TROCA:
			if not nome.contains(par[0]):
				continue
			var lista: Array = par[1]
			var modelo: String = lista[(h + n) % lista.size()]
			if _poe(mi, modelo, par[0] == "quadro"):
				mi.visible = false
				n += 1
			break
		if nome.begins_with("balcao"):
			_em_cima(mi, "vintage_microwave", 0.5)
		elif nome.begins_with("criado"):
			_em_cima(mi, "vintage_oil_lamp", 0.0)
	return n


# põe o modelo no lugar da caixa: mesmo giro, cabe no chão da caixa (escala igual nos três eixos), apoiado no chão dela
# (quadro: no meio da caixa, que está na parede)
static func _poe(mi: MeshInstance3D, modelo: String, na_parede: bool) -> bool:
	var cena: PackedScene = _cena(modelo)
	if cena == null or mi.mesh == null:
		return false
	var m: Node3D = cena.instantiate()
	var caixa: AABB = mi.get_aabb()
	var ma: AABB = _aabb(m)
	if ma.size.x < 0.01 or ma.size.z < 0.01:
		m.free()
		return false
	var s: float = clampf(minf(caixa.size.x / ma.size.x, caixa.size.z / ma.size.z), 0.5, 1.6)
	if na_parede:
		s = clampf(minf(caixa.size.x / ma.size.x, caixa.size.y / ma.size.y), 0.5, 1.6)
	var base := Vector3(caixa.get_center().x, caixa.get_center().y if na_parede else caixa.position.y, caixa.get_center().z)
	var desl := Vector3(ma.get_center().x, ma.get_center().y if na_parede else ma.position.y, ma.get_center().z) * s
	var suporte := Node3D.new()
	suporte.name = "Real_" + mi.name
	mi.get_parent().add_child(suporte)
	suporte.transform = Transform3D(mi.transform.basis.orthonormalized(), mi.transform * base)
	m.scale = Vector3.ONE * s
	m.position = -desl
	suporte.add_child(m)
	_leve(m)
	return true


# coisa pequena em cima do móvel (micro-ondas no balcão, lampião no criado)
static func _em_cima(mi: MeshInstance3D, modelo: String, ponta: float) -> void:
	var cena: PackedScene = _cena(modelo)
	if cena == null:
		return
	var caixa: AABB = mi.get_aabb()
	var m: Node3D = cena.instantiate()
	var ma: AABB = _aabb(m)
	var s: float = clampf(minf(0.45 / maxf(ma.size.x, 0.01), 1.0), 0.3, 1.0)
	var topo := Vector3(caixa.get_center().x + caixa.size.x * 0.3 * ponta, caixa.end.y, caixa.get_center().z)
	var suporte := Node3D.new()
	mi.get_parent().add_child(suporte)
	suporte.transform = Transform3D(mi.transform.basis.orthonormalized(), mi.transform * topo)
	m.scale = Vector3.ONE * s
	m.position = -Vector3(ma.get_center().x, ma.position.y, ma.get_center().z) * s
	suporte.add_child(m)
	_leve(m)


static func _aabb(n: Node3D) -> AABB:
	var a := AABB()
	var prim: bool = true
	for g: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = g.transform * g.get_aabb()
		var p: Node = g.get_parent()
		while p != n and p is Node3D:
			b = (p as Node3D).transform * b
			p = p.get_parent()
		a = b if prim else a.merge(b)
		prim = false
	return a


# celular: sem sombra, some de longe
static func _leve(n: Node3D) -> void:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = LONGE
