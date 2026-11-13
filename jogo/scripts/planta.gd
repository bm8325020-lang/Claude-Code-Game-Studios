# Planta nova da cidade (tools/mapa/cidade_v2.py), o que não é construção: chão da praça, do estacionamento e do
# cemitério; faixas de pedestre; muros e portões das casas (alguns com grade, alguns caídos); árvores, túmulos e peças
# de rua (MultiMesh por modelo e pedaço de 125 m: centenas custam poucas chamadas de desenho no celular); postes de
# concreto com fiação; carros parados; zumbis extras; e a capital destruída ao longe, depois do muro. O servidor sem
# tela só monta as colisões.
class_name Planta

const PEDACO: float = 125.0
const CORES_MURO: Array[Color] = [Color(0.9, 0.86, 0.76), Color(0.86, 0.66, 0.62), Color(0.7, 0.78, 0.66), Color(0.72, 0.72, 0.74),
	Color(0.95, 0.95, 0.92)]
const MURO_ESP: float = 0.15
const GRADE_ALT: float = 0.85
## peças pequenas: sem sombra e somem de longe (as árvores, o coreto e o pórtico ficam)
const PEQUENAS: Array[String] = ["banco_praca", "orelhao", "banca", "ponto_onibus", "tumulo_1", "tumulo_2", "tumulo_3", "traves",
	"cacamba", "poste", "poste_trafo"]
const FIO_X: Array[float] = [-0.95, 0.35, 0.95]  # isoladores da cruzeta (tools/blender/cidade.py, poste)
const FIO_Y: float = 8.58


static func monta(b: Bairro, dados: Dictionary) -> void:
	for a: Dictionary in dados.get("areas", []):
		_area(b, a)
	for f: Dictionary in dados.get("faixas", []):
		_faixa_pedestre(b, f)
	_muros(b, dados.get("muros", []))
	var por: Dictionary = {}  # modelo -> pedaço -> [Transform3D]
	for pr: Dictionary in dados.get("props", []):
		_guarda(b, por, String(pr.m), Vector2(pr.p[0], pr.p[1]), float(pr.r))
	var fios: Array = []  # [de, até, caído]
	for cadeia: Array in dados.get("postes", []):
		var ant: Array = []
		for q: Array in cadeia:
			var t: Transform3D = _guarda(b, por, "poste_trafo" if int(q[3]) == 1 else "poste", Vector2(q[0], q[1]), float(q[2]))
			b.lampadas.append(t * Vector3(0, FIO_Y - 1.2, 0))
			var pontas: Array = FIO_X.map(func(x: float) -> Vector3: return t * Vector3(x, FIO_Y, 0))
			if not ant.is_empty():
				for k in pontas.size():
					fios.append([ant[k], pontas[k], hash(Vector2(q[0], q[1]) + Vector2(k, 0)) % 23 == 0])
			ant = pontas
	b.postes_da_planta = not dados.get("postes", []).is_empty()
	for modelo: String in por:
		_lote(b, modelo, por[modelo])
	if not Rede.servidor_sem_tela:
		_fios(b, fios)
	var n: int = 0
	for v: Dictionary in dados.get("veiculos", []):
		var p := Vector2(v.p[0], v.p[1])
		var cor: Color = Color(v.cor[0], v.cor[1], v.cor[2]) if v.has("cor") else Color(0.45, 0.12, 0.1)
		var m: Node3D = b._veiculo(String(v.m), cor)
		if v.m == "carro_r1":  # o inteiro dá para dirigir
			var c := Carro.new()
			m.name = "Modelo"
			b.add_child(c)
			c.name = "CarroPlanta_%d" % n
			c.position = Vector3(p.x, b.altura(p), p.y)
			c.rotation.y = float(v.r)
			m.transform = Transform3D()
			c.monta(m)
		else:
			m.name = "VeiculoPlanta_%d" % n
			m.position = Vector3(p.x, b.altura(p), p.y)
			m.rotation.y = float(v.r)
			if (v.m == "carro_r2" or v.m == "mundo:queimado") and n % 3 == 0 and not Rede.servidor_sem_tela:  # carro queimado ainda ardendo (terror 06/11)
				var f := Fogo.new()
				f.tamanho = 0.7
				f.coluna = n % 2 == 0
				m.add_child(f)
				f.position = Vector3(0, 0.6, 0.8)
		n += 1
	for z: Array in dados.get("zumbis", []):
		var p := Vector2(z[0], z[1])
		b.pontos_zumbi.append(Bairro.ORIGEM + Vector3(p.x, b.altura(p) + 0.1, p.y))
	if Rede.servidor_sem_tela:
		return
	for l: Dictionary in dados.get("longe", []):
		if not ResourceLoader.exists(String(l.c)):
			continue
		var m: Node3D = (load(String(l.c)) as PackedScene).instantiate()
		m.position = Vector3(l.p[0], -1.0, l.p[1])
		m.rotation.y = float(l.r)
		b.add_child(m)
		for g: GeometryInstance3D in m.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _area(b: Bairro, a: Dictionary) -> void:
	var m: Material
	var y: float = 0.03
	match String(a.m):
		"praca": m = b._mat("calcada", 0.25, Color(0.86, 0.83, 0.78))
		"grama":
			m = b._mat("grama", 0.25, Color(0.8, 0.86, 0.7))
			y = 0.045
		"asfalto":
			m = b._mat("asfalto", 0.15, Color(0.75, 0.75, 0.75))
			y = 0.035
		_: m = b._mat("terra", 0.3, Color(0.85, 0.8, 0.75))
	var poly := PackedVector2Array()
	for q: Array in a.p:
		poly.append(Vector2(q[0], q[1]))
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for i in range(0, tri.size(), 3):
		var v: Array = [b._no_chao(poly[tri[i]], y), b._no_chao(poly[tri[i + 1]], y), b._no_chao(poly[tri[i + 2]], y)]
		b._junta_quad([v[0], v[1], v[2], v[2]], m, Vector3.UP)


## Zebra: listras de 45 cm atravessando a rua, 3 m de comprimento.
static func _faixa_pedestre(b: Bairro, f: Dictionary) -> void:
	var p := Vector2(f.p[0], f.p[1])
	var u := Vector2(cos(float(f.ang)), sin(float(f.ang)))
	var v: Vector2 = u.orthogonal()
	var larg: float = float(f.larg)
	var m: Material = b._cor(Color(0.88, 0.88, 0.85), 0.8)
	for k in int(larg / 0.9):
		var c: Vector2 = p + v * (-larg * 0.5 + 0.45 + k * 0.9)
		b._junta_quad([b._no_chao(c - u * 1.5 - v * 0.22, 0.058), b._no_chao(c + u * 1.5 - v * 0.22, 0.058),
			b._no_chao(c + u * 1.5 + v * 0.22, 0.058), b._no_chao(c - u * 1.5 + v * 0.22, 0.058)], m, Vector3.UP)


## Muros: caixa de reboco pintado (alguns com grade em cima, uns com um pedaço caído); colisão em caixas por pedaço.
static func _muros(b: Bairro, lista: Array) -> void:
	var corpos: Dictionary = {}
	var grade: Material = b._cor(Color(0.09, 0.09, 0.09), 0.6)
	for mu: Dictionary in lista:
		var a := Vector2(mu.a[0], mu.a[1])
		var c := Vector2(mu.b[0], mu.b[1])
		var alt: float = float(mu.alt)
		var comp: float = a.distance_to(c)
		if comp < 0.1:
			continue
		var m: Material = b._mat("reboco", 0.35, CORES_MURO[int(mu.get("cor", 0)) % CORES_MURO.size()])
		var pedacos: Array = [[0.0, comp]]
		if comp > 5.0 and absi(hash(a)) % 9 == 0:  # pedaço caído: dá para pular para dentro
			pedacos = [[0.0, comp * 0.5 - 0.9], [comp * 0.5 + 0.9, comp]]
		var u: Vector2 = (c - a) / comp
		var com_grade: bool = mu.get("grade", false)
		for pd: Array in pedacos:
			var p0: Vector2 = a + u * float(pd[0])
			var p1: Vector2 = a + u * float(pd[1])
			_caixa(b, p0, p1, 0.0, alt, MURO_ESP, m)
			if com_grade:
				var t: float = 0.1
				while t < float(pd[1]) - float(pd[0]):
					var q: Vector2 = p0 + u * t
					_caixa(b, q - u * 0.015, q + u * 0.015, alt, alt + GRADE_ALT, 0.03, grade, false)
					t += 0.2
				_caixa(b, p0, p1, alt + GRADE_ALT - 0.04, alt + GRADE_ALT, 0.05, grade, false)
			var meio: Vector2 = (p0 + p1) * 0.5
			var chave := Vector2i(floori(meio.x / PEDACO), floori(meio.y / PEDACO))
			if not corpos.has(chave):
				var corpo := StaticBody3D.new()
				corpo.name = "Muros_%d_%d" % [chave.x, chave.y]
				b.add_child(corpo)
				corpos[chave] = corpo
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			var h: float = alt + (GRADE_ALT if com_grade else 0.0)
			bx.size = Vector3(MURO_ESP, h, p0.distance_to(p1))
			cs.shape = bx
			cs.position = Vector3(meio.x, b.altura(meio) + h * 0.5, meio.y)
			cs.rotation.y = atan2(u.x, u.y)
			corpos[chave].add_child(cs)


## Caixa em pé de a até c (sem o fundo), de y0 a y1, juntada na malha do material.
static func _caixa(b: Bairro, a: Vector2, c: Vector2, y0: float, y1: float, esp: float, m: Material, topo: bool = true) -> void:
	var u: Vector2 = (c - a).normalized()
	var l: Vector2 = u.orthogonal() * esp * 0.5
	var h: float = b.altura((a + c) * 0.5)
	var p := func(q: Vector2, y: float) -> Vector3: return Vector3(q.x, h + y, q.y)
	var n := Vector3(l.x, 0, l.y).normalized()
	var f := Vector3(u.x, 0, u.y)
	b._junta_quad([p.call(a + l, y0), p.call(c + l, y0), p.call(c + l, y1), p.call(a + l, y1)], m, n)
	b._junta_quad([p.call(a - l, y0), p.call(c - l, y0), p.call(c - l, y1), p.call(a - l, y1)], m, -n)
	b._junta_quad([p.call(c - l, y0), p.call(c + l, y0), p.call(c + l, y1), p.call(c - l, y1)], m, f)
	b._junta_quad([p.call(a - l, y0), p.call(a + l, y0), p.call(a + l, y1), p.call(a - l, y1)], m, -f)
	if topo:
		b._junta_quad([p.call(a - l, y1), p.call(c - l, y1), p.call(c + l, y1), p.call(a + l, y1)], m, Vector3.UP)


static func _guarda(b: Bairro, por: Dictionary, modelo: String, p: Vector2, rot: float) -> Transform3D:
	var t := Transform3D(Basis(Vector3.UP, rot), Vector3(p.x, b.altura(p), p.y))
	var chave := Vector2i(floori(p.x / PEDACO), floori(p.y / PEDACO))
	if not por.has(modelo):
		por[modelo] = {}
	if not por[modelo].has(chave):
		por[modelo][chave] = []
	por[modelo][chave].append(t)
	return t


## Todas as cópias de um modelo: uma MultiMesh por malha e pedaço; colisão de cada cópia com as formas do modelo.
static func _lote(b: Bairro, modelo: String, pedacos: Dictionary) -> void:
	var malhas: Array = []  # [Mesh pintada, Transform3D dentro do modelo]
	var formas: Array = []  # [Shape3D, Transform3D]
	var pequena: bool = modelo in PEQUENAS
	if modelo.begins_with("veg:"):  # vegetação pronta (Vegetacao): material com vento, tronco de cilindro
		var esp: String = modelo.substr(4)
		if not Rede.servidor_sem_tela:
			malhas = Vegetacao.malhas(esp)
		var tr: Shape3D = Vegetacao.tronco(esp)
		if tr:
			formas.append([tr, Transform3D(Basis(), Vector3(0, 1.5, 0))])
		pequena = esp in Vegetacao.RASTEIRAS
	elif modelo.begins_with("mundo:"):  # 07/11 (E3): enfeite pronto (normaliza.py, assets/mundo/props): textura dele, colisão em caixa
		var arq: String = "res://assets/mundo/props/%s/%s.gltf" % [modelo.substr(6), modelo.substr(6)]
		if not ResourceLoader.exists(arq):
			return
		var cena: Node3D = (load(arq) as PackedScene).instantiate()
		var cx := AABB()
		for g: MeshInstance3D in cena.find_children("*", "MeshInstance3D", true, false):
			var t: Transform3D = _rel(g, cena)
			if not Rede.servidor_sem_tela:
				malhas.append([g.mesh, t])
			cx = t * g.get_aabb() if cx.size == Vector3.ZERO else cx.merge(t * g.get_aabb())
		cena.free()
		if cx.size.y > 0.5:  # o que é baixo (saco) não trava ninguém
			var bx := BoxShape3D.new()
			var f: float = 1.0 if maxf(cx.size.x, cx.size.z) > 4.0 else 0.8  # muro de contêiner não pode ter fresta
			bx.size = cx.size * Vector3(f, 1.0, f)
			formas.append([bx, Transform3D(Basis(), cx.get_center())])
		pequena = true
	elif ResourceLoader.exists(Bairro.RUINAS % modelo):
		var cena: Node3D = (load(Bairro.RUINAS % modelo) as PackedScene).instantiate()
		if not Rede.servidor_sem_tela:
			for g: MeshInstance3D in cena.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = g.mesh.duplicate()
				for s in mesh.get_surface_count():
					var mm: Material = mesh.surface_get_material(s)
					mesh.surface_set_material(s, b._mat_ruina(mm.resource_name if mm else "", Color(0.82, 0.8, 0.76)))
				malhas.append([mesh, _rel(g, cena)])
		for cs: CollisionShape3D in cena.find_children("*", "CollisionShape3D", true, false):
			formas.append([cs.shape, _rel(cs, cena)])
		cena.free()
	else:
		return
	# 07/11 anti-travamento: árvore grande com versão de longe vai em quadrados de SUB m: perto a inteira, longe a leve
	var leves: Array = Vegetacao.malhas(modelo.substr(4) + "_lod") if modelo.begins_with("veg:") and not pequena and not Rede.servidor_sem_tela else []
	if not leves.is_empty():
		var perto: float = float(Config.qualidade().detalhe) * 1.5 + SUB * 0.71
		var fim: float = float(Config.qualidade().longe) * 0.6 + SUB * 0.71  # 13/11 floresta densa: a névoa da mata esconde além disso
		var subs: Dictionary = {}
		for chave: Vector2i in pedacos:
			for t: Transform3D in pedacos[chave]:
				var k := Vector2i(floori(t.origin.x / SUB), floori(t.origin.z / SUB))
				if not subs.has(k):
					subs[k] = []
				subs[k].append(t)
		for k: Vector2i in subs:
			_mm(b, "Lote_%s_%d_%d" % [modelo, k.x, k.y], malhas, subs[k], 0.0, perto, true)
			_mm(b, "Longe_%s_%d_%d" % [modelo, k.x, k.y], leves, subs[k], perto, fim, false)
		malhas = []  # já postas; o laço de baixo só põe a colisão
	for chave: Vector2i in pedacos:
		var ts: Array = pedacos[chave]
		for par: Array in malhas:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = par[0]
			mm.instance_count = ts.size()
			for i in ts.size():
				mm.set_instance_transform(i, (ts[i] as Transform3D) * (par[1] as Transform3D))
			var mi := MultiMeshInstance3D.new()
			mi.name = "Lote_%s_%d_%d" % [modelo, chave.x, chave.y]
			mi.multimesh = mm
			if pequena:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = clampf(float(Config.qualidade().detalhe) * 3.0, 70.0, 220.0) + PEDACO * 0.7
			elif modelo.begins_with("veg:"):  # árvore: some na névoa (anti-lag 06/11)
				mi.visibility_range_end = float(Config.qualidade().longe) * 0.6 + PEDACO * 0.7
			b.add_child(mi)
		if formas.is_empty():
			continue
		if modelo.begins_with("veg:"):  # 13/11 floresta densa (30 mil árvores): um corpo por pedaço, troncos direto no servidor de física
			var rid: RID = PhysicsServer3D.body_create()
			PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_space(rid, b.get_world_3d().space)
			PhysicsServer3D.body_set_collision_layer(rid, 1)
			PhysicsServer3D.body_set_collision_mask(rid, 0)
			for t: Transform3D in ts:
				for f: Array in formas:
					PhysicsServer3D.body_add_shape(rid, (f[0] as Shape3D).get_rid(), t * (f[1] as Transform3D))
			_corpos.append(rid)
			if not b.tree_exiting.is_connected(_solta_corpos):
				b.tree_exiting.connect(_solta_corpos)
			continue
		for t: Transform3D in ts:
			var corpo := StaticBody3D.new()
			corpo.transform = t
			for f: Array in formas:
				var cs := CollisionShape3D.new()
				cs.shape = f[0]
				cs.transform = f[1]
				corpo.add_child(cs)
			b.add_child(corpo)


const SUB: float = 50.0
static var _corpos: Array[RID] = []


static func _solta_corpos() -> void:
	for rid: RID in _corpos:
		PhysicsServer3D.free_rid(rid)
	_corpos.clear()


## Uma MultiMesh por malha das cópias `ts`, aparecendo de `ini` a `fim` m (do meio do quadrado).
static func _mm(b: Bairro, nome: String, malhas: Array, ts: Array, ini: float, fim: float, sombra: bool) -> void:
	for par: Array in malhas:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = par[0]
		mm.instance_count = ts.size()
		for i in ts.size():
			mm.set_instance_transform(i, (ts[i] as Transform3D) * (par[1] as Transform3D))
		var mi := MultiMeshInstance3D.new()
		mi.name = nome
		mi.multimesh = mm
		mi.visibility_range_begin = ini
		mi.visibility_range_end = fim
		if not sombra:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)


static func _rel(n: Node3D, raiz: Node) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != raiz and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Fiação: linhas finas pretas barrigudas de poste a poste (uma malha só); fio partido cai até o chão.
static func _fios(b: Bairro, fios: Array) -> void:
	if fios.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for f: Array in fios:
		var a: Vector3 = f[0]
		var c: Vector3 = f[1]
		var queda: float = 6.5 if f[2] else 0.55
		var ant: Vector3 = a
		for k in range(1, 9):
			var t: float = k / 8.0
			var p: Vector3 = a.lerp(c, t)
			p.y = maxf(p.y - 4.0 * t * (1.0 - t) * queda, b.altura(Vector2(p.x, p.z)) + 0.03)
			st.add_vertex(ant)
			st.add_vertex(p)
			ant = p
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.02, 0.02, 0.02)
	var mi := MeshInstance3D.new()
	mi.name = "Fiacao"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(mi)
