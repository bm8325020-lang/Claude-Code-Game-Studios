# Quarteirão de verdade (bloco 1), ao lado da pista de teste: cruzamento de duas ruas de asfalto, calçadas e
# quatro lotes (prédio em ruína, correio, quarto de tijolo com estante, terreno baldio). Modelos do Sketchfab
# (créditos em assets/LICENCAS.txt). Colisão: caixa para prédios e peças pesadas, malha para as peças leves.
class_name Quarteirao
extends RefCounted

const CENTRO: Vector3 = Vector3(70, 0, 60)
const RUA: float = 8.0        # largura das duas ruas
const LADO: float = 60.0      # o quarteirão vai de CENTRO - 30 a CENTRO + 30
const CALCADA: float = 0.15   # altura do meio-fio
const PASTA: String = "res://assets/sketchfab/"


static func monta(main: Node3D) -> void:
	var c := CENTRO
	var asfalto := StandardMaterial3D.new()
	asfalto.albedo_texture = load(PASTA + "asfalto.jpg")
	asfalto.uv1_triplanar = true
	asfalto.uv1_scale = Vector3.ONE * 0.25  # textura a cada 4 m
	asfalto.albedo_color = Color(0.5, 0.5, 0.52)  # a foto é clara demais ao sol
	asfalto.roughness = 0.95
	_laje(main, c + Vector3(0, 0.01, 0), Vector3(LADO, 0.02, RUA), asfalto)
	_laje(main, c + Vector3(0, 0.01, 0), Vector3(RUA, 0.02, LADO), asfalto)
	# calçadas/lotes: uma laje de concreto por esquina
	var concreto := StandardMaterial3D.new()
	concreto.albedo_color = Color(0.3, 0.29, 0.28)
	concreto.roughness = 0.9
	var q: float = (LADO - RUA) * 0.5
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_laje(main, c + Vector3(sx * (RUA + q) * 0.5, CALCADA * 0.5, sz * (RUA + q) * 0.5), Vector3(q, CALCADA, q), concreto)
	var chao: float = CALCADA
	# prédios (colisão em caixa: não dá para entrar)
	modelo(main, "predio_props.glb", c + Vector3(15, chao, 14), 180.0, 20.0, "caixa", 1)          # altura 20 m
	modelo(main, "correio.glb", c + Vector3(-15, chao, 14), 180.0, 18.0, "caixa", 0)              # 18 m de frente
	# quarto de tijolo (dá para entrar) com estante e entulho dentro
	# a parede dos fundos (z = -5,41 no arquivo, dois retângulos de ponta a ponta) desabou: é a entrada, virada
	# para o lote; entulho num canto da abertura
	modelo(main, "quarto_tijolo.glb", c + Vector3(-15, chao, -14), 0.0, 10.0, "malha", 0,
		AABB(Vector3(-6.0, -1.0, -5.7), Vector3(12.0, 10.0, 0.6)), true)
	modelo(main, "entulho.glb", c + Vector3(-18.5, chao, -19.6), 15.0, 2.8, "caixa", 0)
	modelo(main, "estante.glb", c + Vector3(-18, chao, -17), 90.0, 1.8, "caixa", 1)
	# terreno baldio: muro de tijolo, grades e entulho
	modelo(main, "cerca_b.glb", c + Vector3(18, chao, -27), 0.0, 17.5, "malha", 0)
	modelo(main, "cerca_a.glb", c + Vector3(9.5, chao, -18), 90.0, 5.0, "caixa", 0)
	modelo(main, "cerca_a.glb", c + Vector3(9.5, chao, -10), 90.0, 5.0, "caixa", 0)
	modelo(main, "entulho.glb", c + Vector3(16, chao, -16), 30.0, 3.2, "caixa", 0)
	modelo(main, "entulho.glb", c + Vector3(21, chao, -11), 200.0, 2.6, "caixa", 0)
	# rua: barreiras de concreto fechando a saída leste, grades e cancela na saída sul, objetos na calçada
	modelo(main, "barreiras_myjato.glb", c + Vector3(24, 0, 0), 90.0, 8.0, "malha", 0)
	modelo(main, "barreira_aco.glb", c + Vector3(-2, 0, -22), 10.0, 2.2, "caixa", 0)
	modelo(main, "barreira_aco.glb", c + Vector3(2.3, 0, -22.4), -15.0, 2.2, "caixa", 0)
	modelo(main, "barreira_estrada.glb", c + Vector3(-4.5, 0, -27), 90.0, 12.0, "malha", 2)
	modelo(main, "objetos_rua.glb", c + Vector3(-12, chao, 6), 0.0, 7.0, "malha", 0)


# laje com colisão (faz parte do cenário da malha de navegação)
static func _laje(main: Node3D, centro: Vector3, tam: Vector3, mat: Material) -> void:
	var b := StaticBody3D.new()
	b.position = centro
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = mat
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tam
	cs.shape = s
	b.add_child(cs)
	main.add_child(b)


## Põe um modelo com a medida `tam` (m) no eixo `eixo` (0 x, 1 y, 2 z, antes de girar), apoiado em `pos.y` e
## centrado em `pos`. colisao: "caixa" (caixa do tamanho do modelo), "malha" (a própria malha) ou "" (nenhuma).
## abre: tira os triângulos com centro nessa caixa (coordenadas do arquivo), para abrir uma passagem.
## dois_lados: desenha as faces dos dois lados (modelos de interior, que de fora ficariam transparentes).
static func modelo(main: Node3D, arquivo: String, pos: Vector3, giro: float, tam: float, colisao: String, eixo: int,
		abre: AABB = AABB(), dois_lados: bool = false) -> Node3D:
	var m := (load(PASTA + arquivo) as PackedScene).instantiate() as Node3D
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation_degrees.y = giro
	main.add_child(b)
	b.add_child(m)
	for n: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if abre.has_volume():
			mi.mesh = _tira(mi.mesh, m.global_transform.affine_inverse() * mi.global_transform, abre)
		if dois_lados:
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, mat)
	var caixa := AABB()
	var primeiro := true
	var malhas: Array[MeshInstance3D] = []
	for n: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		malhas.append(mi)
		var a: AABB = (m.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		caixa = a if primeiro else caixa.merge(a)
		primeiro = false
	var k: float = tam / maxf(caixa.size[eixo], 0.0001)
	m.scale = Vector3.ONE * k
	m.position = -Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z) * k
	if colisao == "caixa":
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = caixa.size * k
		cs.shape = s
		cs.position.y = s.size.y * 0.5
		b.add_child(cs)
	elif colisao == "malha":
		for mi in malhas:
			var cs := CollisionShape3D.new()
			var forma := mi.mesh.create_trimesh_shape()
			forma.backface_collision = true  # parede de um lado só: colide vindo de fora também
			cs.shape = forma
			b.add_child(cs)
			cs.global_transform = mi.global_transform
	return m


# cópia da malha sem os triângulos com centro dentro de `caixa` (em coordenadas do modelo; `xf` leva a malha até lá)
static func _tira(malha: Mesh, xf: Transform3D, caixa: AABB) -> ArrayMesh:
	var nova := ArrayMesh.new()
	for s in malha.get_surface_count():
		var arr: Array = malha.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var fica := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var centro: Vector3 = xf * ((v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0)
			if not caixa.has_point(centro):
				fica.append_array([idx[t], idx[t + 1], idx[t + 2]])
		arr[Mesh.ARRAY_INDEX] = fica
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nova.surface_set_material(s, malha.surface_get_material(s))
	return nova
