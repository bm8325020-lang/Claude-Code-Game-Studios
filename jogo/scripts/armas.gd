# Armas brancas (mecânica 4 do loop): dados de cada uma e o modelo já arrumado — pegada no cabo (origem) e
# lâmina/cabeça apontando para +Z — usado na primeira pessoa (Maos), na mão do corpo e no item do chão.
# Modelos do Sketchfab (CC BY, créditos em LICENCAS.txt). Números provisórios.
class_name Armas
extends RefCounted

## ponta: eixo do arquivo que vai do cabo para a ponta/cabeça (medido); tam: m de ponta a ponta;
## vel: rapidez do golpe (1 = facão); dano: por golpe do combo; alcance: m; empurra: força do empurrão.
const BRANCAS: Dictionary = {
	"facao": {"modelo": "res://assets/sketchfab/facao.glb", "ponta": Vector3(0, 0, 1), "tam": 0.52,
		"vel": 1.0, "dano": [25, 25, 45], "alcance": 1.8, "empurra": 1.0, "som": "knifeSlice"},
	"faca": {"modelo": "res://assets/sketchfab/faca.glb", "ponta": Vector3(-1, 0, 0), "tam": 0.32,
		"vel": 1.45, "dano": [18, 18, 30], "alcance": 1.4, "empurra": 0.6, "som": "knifeSlice"},
	"taco": {"modelo": "res://assets/sketchfab/taco.glb", "ponta": Vector3(0, 0, 1), "tam": 0.86,
		"vel": 0.8, "dano": [35, 35, 50], "alcance": 2.0, "empurra": 2.6, "som": "impactPunch_heavy_000"},
	"machado": {"modelo": "res://assets/sketchfab/machado.glb", "ponta": Vector3(0, 1, 0), "tam": 0.8,
		"vel": 0.65, "dano": [50, 50, 70], "alcance": 1.9, "empurra": 1.3, "som": "knifeSlice2"},
}
const CABO: float = 0.12  # onde a mão segura, a partir do fim do cabo (fração do tamanho)


static func e_branca(tipo: String) -> bool:
	return BRANCAS.has(tipo)


## Modelo pronto: nó com a pegada na origem e a ponta para +Z, do tamanho certo.
static func modelo(tipo: String) -> Node3D:
	var d: Dictionary = BRANCAS[tipo]
	var pega := Node3D.new()
	pega.name = "Arma_" + tipo
	var m := (load(String(d.modelo)) as PackedScene).instantiate() as Node3D
	pega.add_child(m)
	var caixa := AABB()
	var prim := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (m.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb() if m.is_inside_tree() \
			else _caixa_local(m, mi)
		caixa = a if prim else caixa.merge(a)
		prim = false
	var ponta: Vector3 = d.ponta
	var comp: float = absf(caixa.size.dot(ponta))
	var k: float = float(d.tam) / maxf(comp, 0.0001)
	var gira := Basis(Quaternion(ponta, Vector3.BACK))
	m.transform = Transform3D(gira.scaled(Vector3.ONE * k), Vector3.ZERO)
	var centro: Vector3 = m.transform * caixa.get_center()
	m.position = -centro + Vector3(0, 0, float(d.tam) * (0.5 - CABO))
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat and mat.metallic > 0.6:  # metal puro fica preto sem reflexo de céu
				var cp := mat.duplicate() as BaseMaterial3D
				cp.metallic = 0.35
				mi.set_surface_override_material(i, cp)
	return pega


# caixa da malha no espaço do modelo, sem estar na árvore (soma as transformações dos pais)
static func _caixa_local(m: Node3D, mi: MeshInstance3D) -> AABB:
	var t := Transform3D.IDENTITY
	var n: Node = mi
	while n != m and n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t * mi.get_aabb()
