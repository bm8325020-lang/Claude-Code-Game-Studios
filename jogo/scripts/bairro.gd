# Cidade do mapa: o centro de Monroeville (Alabama, EUA — cidadezinha do sul com a praça do fórum), com ruas e prédios reais do
# OpenStreetMap (© OpenStreetMap contributors, ODbL; convertido por tools/mapa/osm_para_json.py para
# assets/mapa/monroeville.json). Cada lote recebe uma ruína do fim do mundo modelada no Blender (tools/blender/ruinas.py:
# casas com telhado caído, queimadas, de dois andares, lojas e prédio desabado), virada para a rua; a colisão vem do
# próprio modelo (sem parede invisível). As 3 maiores casas são as MANSÕES (só elas dominadas por facção: baú, cama,
# bancada e loja da facção). Rua: asfalto e calçada pelo traçado real, carros largados (alguns queimados), árvores
# mortas, hidrantes, barris com fogo. Tudo determinístico (mesmos nomes em todos os aparelhos).
class_name Bairro
extends Node3D

const ORIGEM := Vector3(0, 0, -300)   # centro do recorte (a pista de teste fica ao norte, em z > -30)
const TAMANHO: float = 500.0          # lado da área usada (o resto do recorte fica de fora)
const PAREDE: float = 3.0             # pé-direito de um andar
const MAPA: String = "res://assets/mapa/cidade.json"  # tools/mapa/cidade_nossa.py
const TEX: String = "res://assets/texturas/%s_%s.jpg"
## Ruínas modeladas no Blender (tools/blender/ruinas.py), do maior para o menor
const RUINAS := "res://assets/ruinas/%s.glb"
const RUINAS_CASA: Array[String] = ["casa_r5", "casa_r2", "casa_r4", "casa_r1", "casa_r3", "casa_r6"]
const RUINAS_MANSAO: Array[String] = ["casa_r5", "casa_r2", "casa_r3"]
const RUINAS_LOJA: Array[String] = ["predio_r1", "loja_r2", "loja_r1"]
const RUINAS_GALPAO: Array[String] = ["galpao_r1", "galpao_r2"]
const VEICULOS: Array[String] = ["carro_r1", "carro_r1", "van_r1", "carro_r2"]  # carro_r2 = queimado
const FRESTA_ALT: float = 4.2  # muros da fresta (mais altos que o pulo)
const LARG_RUA: Dictionary = {"primary": 10.0, "secondary": 9.0, "tertiary": 8.0, "residential": 6.5, "unclassified": 6.0, "service": 4.0}

var pontos_zumbi: Array[Vector3] = []
## raids (lugares cheios de loot e zumbi): [{"pos", "armado"}] dos zumbis e {"nome", "pos"} de cada lugar
var pontos_raid: Array[Dictionary] = []
var raids: Array[Dictionary] = []
var pontos_nascer: Array[Vector3] = []
## nascer (prompt 11): "bom" = baú fácil a até BOM_BAU m e nenhum ponto de zumbi a menos de BOM_ZUMBI m
var pontos_bons: Array[Vector3] = []
var pontos_ruins: Array[Vector3] = []
const BOM_BAU: float = 18.0
const BOM_ZUMBI: float = 14.0
const CHANCE_BOM: float = 0.75
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _ruas: Array = []      # [[a, b, largura]] em coordenadas locais (x, z)
var _n_frestas: int = 0
var _infos: Dictionary = {}  # ruína -> tamanho no chão
var _poligonos: Array = [] # polígonos (PackedVector2Array) de todas as construções, para não pôr nada dentro


func _ready() -> void:
	_rng.seed = 1993
	_janela.size = Vector2(1.1, 1.2)
	position = ORIGEM
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPA))
	_chao()
	for r: Dictionary in dados.ruas:
		_rua(r)
	var predios: Array = dados.predios.filter(func(p: Dictionary) -> bool: return _dentro(_centro(_poly(p.p))))
	# as 3 maiores casas são as mansões
	var casas: Array = predios.filter(_eh_casa)
	casas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(_area(_poly(a.p))) > absf(_area(_poly(b.p))))
	var mansoes: Array = casas.slice(0, 3)
	# raid: a delegacia no lote do centro mais perto do meio da cidade onde ela cabe
	var centro: Array = predios.filter(func(p: Dictionary) -> bool: return p.get("uso", "") == "centro")
	centro.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _centro(_poly(a.p)).length() < _centro(_poly(b.p)).length())
	for p: Dictionary in centro:
		if _ruina(_poly(p.p), "Delegacia", ["delegacia"], false, true):
			predios.erase(p)
			_poligonos.append(_poly(p.p))
			_monta_raid(get_node("Delegacia"), "DELEGACIA")
			break
	var n_casa: int = 0
	var n_mansao: int = 0
	for p: Dictionary in predios:
		var poly := _poly(p.p)
		_poligonos.append(poly)
		if p in mansoes:
			_construcao(poly, "Mansao_%d" % n_mansao, p, true)
			n_mansao += 1
		elif _construcao(poly, "Casa_%d" % n_casa, p, false):
			n_casa += 1
	_carros()
	_barricadas()
	for b: Dictionary in dados.get("bloqueios", []):
		_bloqueio(Vector2(b.p[0], b.p[1]), float(b.ang), float(b.larg))
	for m: Dictionary in dados.get("marcos", []):
		if not ResourceLoader.exists(RUINAS % m.tipo):
			continue  # marco ainda sem modelo
		var mk: Node3D = (load(RUINAS % m.tipo) as PackedScene).instantiate()
		mk.position = Vector3(m.p[0], 0, m.p[1])
		add_child(mk)
		_pinta(mk, Color.WHITE)
	for f: Dictionary in dados.get("frestas", []):
		_fresta(Vector2(f.a[0], f.a[1]), Vector2(f.b[0], f.b[1]), float(f.larg))
	_borda()
	_arvores_mortas()
	_hidrantes_e_fogo()
	_classifica()
	var enfeites := Enfeites.new()
	enfeites.name = "Enfeites"
	add_child(enfeites)
	enfeites.monta(self, _ruas, _poligonos)


# --- chão e ruas ---

func _chao() -> void:
	var corpo := StaticBody3D.new()
	corpo.position = Vector3(0, -0.5, 0)
	add_child(corpo)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(TAMANHO + 40, 1, TAMANHO + 40)
	cs.shape = bs
	corpo.add_child(cs)
	_plano(self, Vector3(0, 0.01, 0), Vector2(TAMANHO + 40, TAMANHO + 40), Enfeites.chao())


# rua: faixa de asfalto pelo traçado; com calçada dos lados nas ruas de carro; trilha de pedestre só calçada
func _rua(r: Dictionary) -> void:
	var larg: float = float(LARG_RUA.get(r.tipo, 0.0))
	var pe: bool = r.tipo in ["footway", "path", "cycleway", "pedestrian"]
	if larg == 0.0 and not pe:
		return
	var pts: Array = r.p
	for i in range(pts.size() - 1):
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[i + 1][0], pts[i + 1][1])
		if not _dentro(a) and not _dentro(b):
			continue
		if pe:
			_faixa(a, b, 2.0, 0.03, _mat("calcada", 0.3))
			continue
		_ruas.append([a, b, larg])
		if r.tipo != "service":
			_faixa(a, b, larg + 3.4, 0.025, _mat("calcada", 0.3))
		_faixa(a, b, larg, 0.04, _mat("asfalto", 0.15, Color(0.75, 0.75, 0.75)))


func _faixa(a: Vector2, b: Vector2, larg: float, y: float, m: Material) -> void:
	var d: Vector2 = b - a
	if d.length() < 0.05:
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(larg, d.length() + larg * 0.5)  # passa um pouco da ponta: emenda nas curvas
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5)
	mi.rotation.y = atan2(d.x, d.y)
	add_child(mi)


# --- construções ---

## Casa de morar: marcada assim no OSM, ou "yes" sem uso e pequena (o resto é loja/prédio).
func _eh_casa(p: Dictionary) -> bool:
	return p.tipo in ["house", "residential", "detached"] or (p.tipo == "yes" and absf(_area(_poly(p.p))) < 260.0)

# paredes pelo contorno real (porta no lado de frente para a rua), janelas, piso, telhado; dentro, móveis e loot
## Ruína do Blender no lote; mansão que não cabe sobe em código (as 3 têm que existir). false = lote vazio.
func _construcao(poly: PackedVector2Array, nome: String, dados: Dictionary, mansao: bool) -> bool:
	var loja: bool = not mansao and not _eh_casa(dados)
	var opcoes: Array = RUINAS_MANSAO if mansao else (RUINAS_GALPAO if dados.tipo == "industrial" else (RUINAS_LOJA if loja else RUINAS_CASA))
	if _ruina(poly, nome, opcoes, mansao, loja):
		return true
	if not mansao:
		return false
	var andares: int = int(dados.andares) if dados.andares > 0 else (2 if loja and absf(_area(poly)) > 150.0 else 1)
	if dados.tipo == "church":
		andares = 3
	var alt: float = PAREDE * andares
	var no := Node3D.new()
	no.name = nome
	add_child(no)
	no.set_meta("poly", poly)
	no.add_to_group("casas")
	if mansao:
		no.set_meta("dominavel", true)
	var parede: Material
	if loja:
		parede = _mat("tijolo", 0.4)
	else:
		parede = [_mat("madeira", 0.35, Color(0.85, 0.82, 0.76)), _mat("reboco", 0.3, Color(0.9, 0.86, 0.78)), _mat("tijolo", 0.4)][_rng.randi() % 3]
	if mansao:
		parede = _mat("reboco", 0.3, Color(0.95, 0.93, 0.88))
	var c: Vector2 = _centro(poly)
	var porta_i: int = _lado_da_rua(poly)
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if i == porta_i:
			_parede_com_porta(no, a, b, PAREDE, parede, nome)
			if alt > PAREDE:
				_parede(no, a, b, PAREDE, alt, parede)
		else:
			_parede(no, a, b, 0.0, alt, parede)
		_janelas(no, a, b, c, alt, i == porta_i)
	_piso(no, poly, 0.06, _mat("madeira" if not loja else "concreto", 0.4, Color(0.7, 0.62, 0.52)))
	if alt > PAREDE:
		_piso(no, poly, PAREDE, _mat("concreto", 0.3), true)  # forro do térreo (o de cima não entra)
	if loja:
		_piso(no, poly, alt, _mat("concreto", 0.3, Color(0.55, 0.55, 0.55)), true)
	else:
		_telhado(no, poly, alt, _mat("telhado", 0.5, Color(0.8, 0.78, 0.75)))
	if absf(_area(poly)) > 90.0:
		_divisoria(no, poly, c, porta_i, alt if loja else PAREDE, parede)
	_recheio(no, poly, porta_i, mansao, loja)
	return true


# frente (onde nasce quem chega), móveis, baú e item; nas mansões, as coisas da facção
func _recheio(no: Node3D, poly: PackedVector2Array, porta_i: int, mansao: bool, loja: bool) -> void:
	var nome: String = no.name
	var c: Vector2 = _centro(poly)
	var a: Vector2 = poly[porta_i]
	var b: Vector2 = poly[(porta_i + 1) % poly.size()]
	var meio: Vector2 = (a + b) * 0.5
	var fora: Vector2 = _normal_fora(poly, porta_i)
	no.set_meta("frente", ORIGEM + Vector3(meio.x + fora.x * 2.5, 0.1, meio.y + fora.y * 2.5))
	pontos_nascer.append(no.get_meta("frente"))
	# dentro: pontos perto dos cantos (puxados para o centro), longe da porta
	var cantos: Array = []
	for i in poly.size():
		if i != porta_i and (i + 1) % poly.size() != porta_i:
			cantos.append(c.lerp(poly[i], 0.62))
	if cantos.is_empty():
		cantos.append(c)
	if mansao:
		_coisas_da_faccao(no, cantos, c)
	else:
		if not no.has_meta("modelo"):  # a ruína do Blender já vem mobiliada
			_moveis(no, cantos, c, loja)
		var k: int = int(nome.trim_prefix("Casa_"))
		if k % 2 == 0:
			var bau := Bau.new()
			bau.name = "Bau_b%d" % k
			bau.facil = k % 4 == 0
			bau.position = _v3(cantos[0])
			no.add_child(bau)
		var it := Item.new()
		it.name = "Item_b%d" % k
		it.tipo = ["comida", "agua", "municao"][k % 3]
		it.quantidade = 12 if it.tipo == "municao" else 1
		it.position = _v3(cantos[cantos.size() - 1].lerp(c, 0.3))
		no.add_child(it)


## Casa de verdade (modelo do Sketchfab com cômodos), virada com a porta para a rua no lugar do contorno do OSM.
## Colisão = malhas do modelo (menos vidro e portas); portas internas tiradas; a da frente vira Porta (2 de 3) ou
## fica arrombada. Não cabe (encosta na rua) -> false e a casa é feita em código.
## Ruína modelada no Blender (tools/blender/ruinas.py) no lote `poly`, frente (+Z do modelo) virada para a rua.
## Escolhe pelo nome, entre os `opcoes` que cabem (área até 1,3x a do lote e sem encostar na rua). false = não coube.
func _ruina(poly: PackedVector2Array, nome: String, opcoes: Array, mansao: bool, loja: bool) -> bool:
	var area: float = absf(_area(poly))
	var cabem: Array = opcoes.filter(func(a: String) -> bool: var t: Vector2 = _tam_ruina(a); return t.x * t.y <= area * 1.05)
	if cabem.is_empty():
		cabem = [opcoes[-1]]  # o menor
	var porta_i: int = _lado_da_rua(poly)
	var fora: Vector2 = _normal_fora(poly, porta_i)
	var c: Vector2 = _centro(poly)
	var ang: float = Vector2(0, 1).angle_to(fora)
	var h: int = absi(hash(nome))
	for k in cabem.size():
		var arq: String = cabem[(h + k) % cabem.size()]
		var tam: Vector2 = _tam_ruina(arq)
		var ret: PackedVector2Array = []
		for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			ret.append(c + (q * tam * 0.5).rotated(ang))
		if Array(ret).all(func(p: Vector2) -> bool: return not _perto_de_rua(p, 0.5)):
			_poe_ruina(ret, nome, arq, ang, c, mansao, loja)
			return true
	return false


## Raid: lê os pontos marcados no modelo (zumbi_k, zumbi_arm_k, bau_k), põe baús de loot raro e viaturas na frente.
func _monta_raid(no: Node3D, titulo: String) -> void:
	var m: Node3D = no.get_child(0)
	raids.append({"nome": titulo, "pos": no.global_position if no.is_inside_tree() else ORIGEM + no.position + m.position})
	for e: Node in m.get_children():
		var n: String = e.name
		if not e is Node3D or e is MeshInstance3D:
			continue
		var p: Vector3 = ORIGEM + m.transform * (e as Node3D).position
		if n.begins_with("zumbi_"):
			pontos_raid.append({"pos": p + Vector3(0, 0.1, 0), "armado": n.begins_with("zumbi_arm_")})
		elif n.begins_with("bau_"):
			var bau := Bau.new()
			bau.name = "Bau_raid_%s" % n.trim_prefix("bau_")
			bau.raid = true
			bau.position = m.transform * (e as Node3D).position
			no.add_child(bau)
	var frente: Vector3 = no.get_meta("frente") - ORIGEM
	for k in 2:  # viaturas largadas na frente
		var v: Node3D = _veiculo("carro_r1", Color(0.08, 0.08, 0.1))
		v.position = frente + Vector3(-4.0 + k * 7.0, -0.1, k * 1.5)
		v.rotation.y = m.rotation.y + PI * 0.5 + _rng.randf_range(-0.4, 0.4)


func _tam_ruina(arq: String) -> Vector2:
	if not _infos.has(arq):
		var m: Node3D = (load(RUINAS % arq) as PackedScene).instantiate()
		var cx := AABB()
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			if mi.name.begins_with("ext"):
				var a: AABB = mi.transform * mi.get_aabb()
				cx = a if cx.size == Vector3.ZERO else cx.merge(a)
		m.free()
		_infos[arq] = Vector2(cx.size.x, cx.size.z)
	return _infos[arq]


func _poe_ruina(ret: PackedVector2Array, nome: String, arq: String, ang: float, c: Vector2, mansao: bool, loja: bool) -> void:
	var no := Node3D.new()
	no.name = nome
	add_child(no)
	no.set_meta("poly", ret)
	no.set_meta("modelo", arq)
	no.add_to_group("casas")
	if mansao:
		no.set_meta("dominavel", true)
	var m: Node3D = (load(RUINAS % arq) as PackedScene).instantiate()
	m.rotation.y = -ang  # no plano o ângulo é anti-horário em (x, z); em 3D o giro em Y é ao contrário
	m.position = _v3(c)
	no.add_child(m)
	_pinta(m, [Color(0.82, 0.8, 0.76), Color(0.7, 0.74, 0.72), Color(0.8, 0.7, 0.62), Color(0.72, 0.72, 0.76)][absi(hash(nome)) % 4])
	var marca: Node3D = m.get_node_or_null("porta")
	if marca and absi(hash(nome)) % 3 != 0:  # 1 em 3 com a porta arrombada
		var porta := Porta.new()
		porta.name = "Porta_" + nome
		porta.largura = 1.2
		porta.position = m.transform * marca.position
		porta.rotation.y = m.rotation.y
		no.add_child(porta)
	if nome != "Delegacia":  # a raid tem o recheio dela (marcado no modelo)
		_recheio(no, ret, _lado_da_rua(ret), mansao, loja)
	else:
		var a: Vector2 = ret[_lado_da_rua(ret)]
		var b2: Vector2 = ret[(_lado_da_rua(ret) + 1) % ret.size()]
		var fora: Vector2 = _normal_fora(ret, _lado_da_rua(ret))
		no.set_meta("frente", ORIGEM + _v3((a + b2) * 0.5 + fora * 6.0) + Vector3(0, 0.1, 0))


## Troca os materiais do modelo do Blender pelas texturas do jogo (tinta: parede e madeira; lataria: cor do carro).
func _pinta(m: Node3D, tinta: Color, lataria: Color = Color(0.4, 0.15, 0.12)) -> void:
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mm: Material = mi.mesh.surface_get_material(s)
			var n: String = mm.resource_name if mm else ""
			mi.set_surface_override_material(s, _cor(lataria, 0.45) if n == "lataria" else _mat_ruina(n, tinta))


## Textura do jogo para o material do Blender (só o nome vem do modelo).
func _mat_ruina(n: String, tinta: Color) -> Material:
	match n:
		"parede": return _mat("reboco", 0.3, tinta, true)
		"tijolo": return _mat("tijolo", 0.4, Color(0.8, 0.74, 0.7), true)
		"madeira": return _mat("madeira", 0.35, tinta * 0.9, true)
		"tabua": return _mat("madeira", 0.5, Color(0.6, 0.5, 0.4), true)
		"telhado": return _mat("telhado", 0.5, Color(0.7, 0.68, 0.66), true)
		"queimado": return _mat("concreto", 0.4, Color(0.14, 0.12, 0.11), true)
		"metal": return _cor(Color(0.3, 0.29, 0.27), 0.6)
		"pano": return _mat("reboco", 0.8, Color(0.4, 0.36, 0.33), true)  # estofado sujo
		"branco": return _cor(Color(0.7, 0.69, 0.64), 0.5)
		"papelao": return _cor(Color(0.5, 0.4, 0.28))
		"vidro": return _cor(Color(0.05, 0.06, 0.07), 0.15)
		"pneu": return _cor(Color(0.04, 0.04, 0.04))
		"ferrugem": return _mat("concreto", 0.6, Color(0.5, 0.28, 0.14), true)
	return _mat("concreto", 0.4, Color(0.7, 0.68, 0.64), true)

func _coisas_da_faccao(no: Node3D, cantos: Array, c: Vector2) -> void:
	var pega := func(k: int) -> Vector3: return _v3(cantos[k % cantos.size()].lerp(c, 0.15 * (k / cantos.size())))
	var bf := Bau.new()
	bf.name = "BauFac"
	bf.de_faccao = true
	bf.position = pega.call(0)
	no.add_child(bf)
	var cama := StaticBody3D.new()
	cama.name = "Cama"
	cama.position = pega.call(1)
	cama.add_to_group("camas")
	no.add_child(cama)
	_peca(cama, Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 2.1), _mat("madeira", 0.6, Color(0.5, 0.36, 0.26)))
	_peca(cama, Vector3(0, 0.56, 0.05), Vector3(1.5, 0.14, 1.9), _cor(Color(0.78, 0.76, 0.7)))
	_peca(cama, Vector3(0, 0.64, 0.5), Vector3(1.5, 0.08, 0.9), _cor(Color(0.42, 0.2, 0.18)))
	_peca(cama, Vector3(0, 0.7, -0.8), Vector3(1.2, 0.12, 0.3), _cor(Color(0.9, 0.88, 0.84)))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 0.6, 2.1)
	cs.shape = bs
	cs.position.y = 0.3
	cama.add_child(cs)
	var banc := Bancada.new()
	banc.name = "BancadaFac"
	banc.position = pega.call(2)
	no.add_child(banc)
	var loja := Lojista.new()
	loja.name = "LojaFac"
	loja.so_balcao = true
	loja.position = pega.call(3)
	no.add_child(loja)


# móveis de um de quatro jeitos (sala, quarto, cozinha, depósito); loja: prateleiras e balcão
# parede interna paralela à fachada da porta, passando pelo centro, com um vão fora do meio (o centro tem móvel);
# anda de 0,5 em 0,5 m e junta os trechos dentro do contorno em paredes inteiras
func _divisoria(no: Node3D, poly: PackedVector2Array, c: Vector2, porta_i: int, alt: float, m: Material) -> void:
	var d: Vector2 = (poly[(porta_i + 1) % poly.size()] - poly[porta_i]).normalized()
	var ini: int = 999
	for k in range(-60, 61):
		var p: Vector2 = c + d * (k * 0.5)
		var ok: bool = k < 60 and (k < 4 or k > 7) and Geometry2D.is_point_in_polygon(p, poly) and not _perto_da_borda(p, poly, 0.15)
		if ok and ini == 999:
			ini = k
		elif not ok and ini != 999:
			if k - 1 > ini:
				_parede(no, c + d * (ini * 0.5 - 0.3), c + d * ((k - 1) * 0.5 + 0.3), 0.0, alt, m)
			ini = 999


func _perto_da_borda(p: Vector2, poly: PackedVector2Array, dist: float) -> bool:
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < dist:
			return true
	return false


func _vidro() -> Material:
	if not _mats.has("vidro"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.15, 0.17)
		m.metallic = 0.6
		m.roughness = 0.12
		_mats["vidro"] = m
	return _mats["vidro"]


func _moveis(no: Node3D, cantos: Array, c: Vector2, loja: bool) -> void:
	var mad := _mat("madeira", 0.6, Color(0.55, 0.42, 0.3))
	if loja:
		for k in mini(3, cantos.size()):
			var p: Vector2 = cantos[k].lerp(c, 0.25)
			_bloco(no, _v3(p) + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 2.4), _cor(Color(0.45, 0.45, 0.47)))
		_bloco(no, _v3(c) + Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.7), mad)
		return
	var jeito: int = _rng.randi() % 4
	var p0: Vector3 = _v3(cantos[0].lerp(c, 0.2))
	var p1: Vector3 = _v3(cantos[min(1, cantos.size() - 1)].lerp(c, 0.25))
	match jeito:
		0:  # sala: sofá, mesinha, estante tombada
			_bloco(no, p1 + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.9), _cor(Color(0.3, 0.32, 0.36)))
			_bloco(no, _v3(c) + Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 0.6), mad)
			var e := _peca(no, _v3(c.lerp(cantos[0], 0.4)) + Vector3(0, 0.2, 0), Vector3(1.8, 0.4, 0.4), mad)
			e.rotation_degrees.y = _rng.randf_range(0, 180)
		1:  # quarto: cama de solteiro e guarda-roupa
			_bloco(no, p1 + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 2.0), _cor(Color(0.62, 0.6, 0.55)))
			_bloco(no, p0 + Vector3(0, 0.95, 0), Vector3(1.2, 1.9, 0.6), mad)
		2:  # cozinha: balcão, geladeira, mesa
			_bloco(no, p1 + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.6), _cor(Color(0.75, 0.73, 0.68)))
			_bloco(no, p0 + Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.7), _cor(Color(0.85, 0.85, 0.82)))
			_bloco(no, _v3(c) + Vector3(0, 0.38, 0), Vector3(1.2, 0.08, 0.8), mad)
		_:  # depósito: caixas empilhadas
			for k in 4:
				_bloco(no, p1 + Vector3(_rng.randf_range(-0.8, 0.8), 0.3 + (k / 2) * 0.6, _rng.randf_range(-0.6, 0.6)), Vector3(0.6, 0.6, 0.6), mad)
	_mancha(no, _v3(c.lerp(cantos[0], 0.5)))


func _parede(no: Node3D, a: Vector2, b: Vector2, y0: float, y1: float, m: Material) -> void:
	var d: Vector2 = b - a
	var corpo := StaticBody3D.new()
	corpo.position = Vector3((a.x + b.x) * 0.5, (y0 + y1) * 0.5, (a.y + b.y) * 0.5)
	corpo.rotation.y = -atan2(d.y, d.x)
	no.add_child(corpo)
	_caixa(corpo, Vector3(d.length() + 0.2, y1 - y0, 0.2), m)


# parede com o vão da porta no meio (porta de verdade em 2 de cada 3) e a verga em cima
func _parede_com_porta(no: Node3D, a: Vector2, b: Vector2, alt: float, m: Material, nome: String) -> void:
	var d: Vector2 = (b - a).normalized()
	var L: float = a.distance_to(b)
	var v0: float = L * 0.5 - Porta.LARGURA * 0.5
	var v1: float = L * 0.5 + Porta.LARGURA * 0.5
	if L < Porta.LARGURA + 0.6:
		_parede(no, a, b, 0.0, alt, m)
		return
	_parede(no, a, a + d * v0, 0.0, alt, m)
	_parede(no, a + d * v1, b, 0.0, alt, m)
	_parede(no, a + d * v0, a + d * v1, Porta.ALTURA, alt, m)
	if hash(nome) % 3 != 0:
		var porta := Porta.new()
		porta.name = "Porta_" + nome
		porta.position = Vector3((a + d * v0).x, 0, (a + d * v0).y)
		porta.rotation.y = -atan2(d.y, d.x)
		no.add_child(porta)


# janelas pela fachada a cada ~3 m, no meio de cada andar; 1 em 3 tapada com tábuas
func _janelas(no: Node3D, a: Vector2, b: Vector2, c: Vector2, alt: float, com_porta: bool) -> void:
	if Rede.servidor_sem_tela:
		return  # só enfeite: o servidor não vê
	var d: Vector2 = b - a
	var L: float = d.length()
	var n: int = int(L / 3.0)
	if n < 1:
		return
	var fora := Vector2(d.y, -d.x).normalized()
	if fora.dot((a + b) * 0.5 - c) < 0.0:
		fora = -fora
	for andar in int(alt / PAREDE):
		for k in n:
			var t: float = (k + 0.5) / n
			if com_porta and andar == 0 and absf(t - 0.5) < 0.2:
				continue
			var p: Vector2 = a + d * t + fora * 0.12
			var y: float = andar * PAREDE + 1.6
			var rot: float = atan2(fora.x, fora.y)
			var j := MeshInstance3D.new()
			j.mesh = _janela
			# vidro reflete o céu; 1 em 4 quebrada (só o buraco escuro)
			j.material_override = _cor(Color(0.06, 0.07, 0.08)) if _rng.randf() < 0.25 else _vidro()
			j.position = Vector3(p.x, y, p.y)
			j.rotation.y = rot
			no.add_child(j)
			# moldura, travessa e peitoril
			var f := Vector3(fora.x, 0, fora.y) * 0.03
			var pv := Vector3(p.x, y, p.y) + f
			var lado := Vector3(-fora.y, 0, fora.x)
			var mold := _cor(Color(0.86, 0.85, 0.8), 0.7)
			for peca: Array in [[Vector3(0, 0.63, 0), Vector3(1.3, 0.09, 0.08)], [Vector3(0, -0.66, 0) + f * 2.0, Vector3(1.4, 0.08, 0.2)], [lado * 0.6, Vector3(0.09, 1.3, 0.08)], [-lado * 0.6, Vector3(0.09, 1.3, 0.08)], [Vector3.ZERO, Vector3(1.1, 0.05, 0.05)], [Vector3.ZERO, Vector3(0.05, 1.2, 0.05)]]:
				var pc := _peca(no, pv + peca[0], peca[1], mold)
				pc.rotation.y = rot
				pc.visibility_range_end = Config.qualidade().detalhe
			if _rng.randf() < 0.33:
				for t2 in 3:
					var tb := _peca(no, Vector3(p.x, andar * PAREDE + 1.25 + t2 * 0.35, p.y) + Vector3(fora.x, 0, fora.y) * 0.03, Vector3(1.3, 0.18, 0.04), _mat("madeira", 1.0, Color(0.6, 0.5, 0.4)))
					tb.rotation = Vector3(0, atan2(fora.x, fora.y), _rng.randf_range(-0.2, 0.2))
					tb.visibility_range_end = Config.qualidade().detalhe


func _piso(no: Node3D, poly: PackedVector2Array, y: float, m: Material, solido: bool = false) -> void:
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tri.size(), 3):
		var ordem: Array = [0, 2, 1] if _area(poly) > 0 else [0, 1, 2]
		for k in ordem:
			st.add_vertex(Vector3(poly[tri[i + k]].x, y, poly[tri[i + k]].y))
		if solido:  # forro/laje: aparece também de baixo
			for k in [ordem[0], ordem[2], ordem[1]]:
				st.add_vertex(Vector3(poly[tri[i + k]].x, y - 0.02, poly[tri[i + k]].y))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	no.add_child(mi)
	if solido:
		var corpo := StaticBody3D.new()
		var cp := CollisionPolygon3D.new()
		cp.polygon = poly
		cp.depth = 0.2
		cp.rotation_degrees.x = 90.0
		cp.position.y = y
		corpo.add_child(cp)
		no.add_child(corpo)


# telhado de 4 águas: do contorno (com beiral) até um ponto alto no meio
func _telhado(no: Node3D, poly: PackedVector2Array, alt: float, m: Material) -> void:
	var c: Vector2 = _centro(poly)
	var topo := Vector3(c.x, alt + clampf(sqrt(absf(_area(poly))) * 0.28, 1.2, 3.0), c.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in poly.size():
		var a: Vector2 = c + (poly[i] - c) * 1.08
		var b: Vector2 = c + (poly[(i + 1) % poly.size()] - c) * 1.08
		var va := Vector3(a.x, alt, a.y)
		var vb := Vector3(b.x, alt, b.y)
		if _area(poly) > 0:
			st.add_vertex(va)
			st.add_vertex(topo)
			st.add_vertex(vb)
		else:
			st.add_vertex(va)
			st.add_vertex(vb)
			st.add_vertex(topo)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	no.add_child(mi)


# --- rua ---

# carros largados nas ruas (alinhados com a rua, encostados de um lado); 1 em 4 queimado
func _carros() -> void:
	var cores: Array[Color] = [Color(0.45, 0.12, 0.1), Color(0.18, 0.25, 0.38), Color(0.62, 0.6, 0.55), Color(0.22, 0.26, 0.2), Color(0.35, 0.33, 0.3)]
	var n: int = 0
	for r: Array in _espalhados(22, 0.0):
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		n += 1
		var d: Vector2 = (b - a).normalized()
		var p: Vector2 = a.lerp(b, _rng.randf_range(0.3, 0.7)) + Vector2(d.y, -d.x) * float(r[2]) * 0.25 * (1 if _rng.randf() < 0.5 else -1)
		var carro: Node3D = _veiculo(VEICULOS[n % VEICULOS.size()], cores[_rng.randi() % cores.size()])
		carro.name = "Carro_%d" % n
		carro.position = Vector3(p.x, 0, p.y)
		carro.rotation.y = atan2(d.x, d.y) + _rng.randf_range(-0.35, 0.35)
		if _rng.randf() < 0.5:
			pontos_zumbi.append(ORIGEM + Vector3(p.x, 0.1, p.y) + Vector3(d.y, 0, -d.x) * 3.0)


func _veiculo(arq: String, cor: Color) -> Node3D:
	var v: Node3D = (load(RUINAS % arq) as PackedScene).instantiate()
	add_child(v)
	_pinta(v, Color.WHITE, cor)
	return v


## Rua fechada: ônibus tombado ou carros batidos atravessados, sem passagem (tem que dar a volta).
func _bloqueio(p: Vector2, ang: float, larg: float) -> void:
	var lado := Vector2(cos(ang), sin(ang))
	if _rng.randf() < 0.4:
		var o: Node3D = _veiculo("onibus_r1", Color.WHITE)
		o.position = _v3(p)
		o.rotation.y = -ang + PI * 0.5
		return
	var n: int = ceili(larg / 2.0)
	for k in n:
		var q: Vector2 = p + lado * ((k - (n - 1) * 0.5) * 2.0)
		var c: Node3D = _veiculo(VEICULOS[(k + 1) % VEICULOS.size()], Color(0.3, 0.3, 0.32).lerp(Color(0.5, 0.2, 0.15), _rng.randf()))
		c.position = _v3(q)
		c.rotation.y = -ang + _rng.randf_range(-0.3, 0.3)


## Fresta entre dois prédios: muros dos dois lados, larga só para passar de lado (Jogador entra esgueirando).
## Zumbi (raio 0,35) não cabe: é rota de fuga.
func _fresta(a: Vector2, b: Vector2, larg: float) -> void:
	var d: Vector2 = b - a
	var lado := Vector2(d.y, -d.x).normalized()
	var meio: Vector2 = (a + b) * 0.5
	var tij := _mat("tijolo", 0.4, Color(0.75, 0.68, 0.64))
	for s in [-1.0, 1.0]:
		var c: Vector2 = meio + lado * s * (larg * 0.5 + 0.15)
		var corpo := StaticBody3D.new()
		corpo.position = Vector3(c.x, FRESTA_ALT * 0.5, c.y)
		corpo.rotation.y = atan2(d.x, d.y)
		add_child(corpo)
		_caixa(corpo, Vector3(0.3, FRESTA_ALT, d.length() + 0.6), tij)
	var f := Area3D.new()
	f.name = "Fresta_%d" % _n_frestas
	_n_frestas += 1
	f.add_to_group("frestas")
	f.collision_layer = 0
	f.collision_mask = 2  # jogadores
	f.position = Vector3(meio.x, 1.0, meio.y)
	f.rotation.y = atan2(d.x, d.y)
	f.set_meta("eixo", Vector3(d.x, 0, d.y).normalized())
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(larg + 0.2, 2.0, d.length() + 1.6)  # pega um pouco antes da boca
	cs.shape = bx
	f.add_child(cs)
	add_child(f)


## Borda do mapa: muro do exército (barreira de concreto com tela em cima) e mata seca do lado de fora.
func _borda() -> void:
	var conc := _mat("concreto", 0.4, Color(0.62, 0.6, 0.56))
	var meio: float = TAMANHO * 0.5 - 4.0
	for lado in 4:
		var corpo := StaticBody3D.new()
		var v: bool = lado % 2 == 0
		corpo.position = Vector3(0 if v else (meio if lado == 1 else -meio), 1.8, (meio if lado == 0 else -meio) if v else 0)
		add_child(corpo)
		_caixa(corpo, Vector3(TAMANHO if v else 0.6, 3.6, 0.6 if v else TAMANHO), conc)


# bloqueio do exército largado: barreiras de concreto atravessando a rua, sacos de areia e entulho
func _barricadas() -> void:
	var conc := _mat("concreto", 0.5, Color(0.72, 0.7, 0.66))
	var saco := _cor(Color(0.42, 0.38, 0.28))
	var n: int = 0
	for r: Array in _espalhados(5, 7.0):
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		n += 1
		var d: Vector2 = (b - a).normalized()
		var lado := Vector2(d.y, -d.x)
		var p: Vector2 = a.lerp(b, 0.5)
		var rot: float = atan2(d.x, d.y)
		var corpo := StaticBody3D.new()
		corpo.name = "Barricada_%d" % n
		add_child(corpo)
		# uma faixa fica aberta (alguém passou com um carro)
		var meia: int = int(float(r[2]) * 0.5 / 1.6)
		var aberta: int = _rng.randi_range(-meia, meia)
		for k in range(-meia, meia + 1):
			if k == aberta:
				continue
			var q: Vector2 = p + lado * (k * 1.6)
			var bl := StaticBody3D.new()
			bl.position = Vector3(q.x, 0.45, q.y)
			bl.rotation.y = rot + PI * 0.5 + _rng.randf_range(-0.15, 0.15)
			corpo.add_child(bl)
			_caixa(bl, Vector3(1.5, 0.9, 0.5), conc)
		for k in 6:
			var q: Vector2 = p + d * 1.5 + lado * _rng.randf_range(-2.5, 2.5)
			var sc := _peca(corpo, Vector3(q.x, 0.15 + (k % 2) * 0.28, q.y), Vector3(0.7, 0.28, 0.4), saco)
			sc.rotation.y = rot + _rng.randf_range(-0.4, 0.4)
		pontos_zumbi.append(ORIGEM + Vector3(p.x, 0.1, p.y) - Vector3(d.x, 0, d.y) * 4.0)


# árvores secas na grama, fora das construções e das ruas
func _arvores_mortas() -> void:
	var feitas: int = 0
	for k in 400:
		if feitas >= 60:
			break
		var p := Vector2(_rng.randf_range(-TAMANHO * 0.45, TAMANHO * 0.45), _rng.randf_range(-TAMANHO * 0.45, TAMANHO * 0.45))
		if _perto_de_rua(p, 5.0) or _poligonos.any(func(pl: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, pl) or _centro(pl).distance_to(p) < 8.0):
			continue
		feitas += 1
		var a := StaticBody3D.new()
		a.position = Vector3(p.x, 0, p.y)
		add_child(a)
		var h: float = _rng.randf_range(4.0, 7.0)
		var casca := _cor(Color(0.22, 0.18, 0.15))
		_cilindro(a, Vector3(0, h * 0.5, 0), 0.2, h, casca)
		for g in 4:  # galhos tortos sem folha
			var galho := _cilindro(a, Vector3(0, h * _rng.randf_range(0.5, 0.9), 0), 0.06, _rng.randf_range(1.2, 2.2), casca)
			galho.rotation = Vector3(_rng.randf_range(0.6, 1.1), _rng.randf() * TAU, 0)
			galho.visibility_range_end = Config.qualidade().detalhe * 2.0
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.25
		cy.height = h
		cs.shape = cy
		cs.position.y = h * 0.5
		a.add_child(cs)


# hidrantes (vermelhos, de verdade: corpo, tampa redonda e bocais) na beira das ruas; barris com fogo aceso
func _hidrantes_e_fogo() -> void:
	var feitos: int = 0
	for r: Array in _ruas:
		if feitos >= 12 or _rng.randf() < 0.6:
			continue
		feitos += 1
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var d: Vector2 = (b - a).normalized()
		var p: Vector2 = a + Vector2(d.y, -d.x) * (float(r[2]) * 0.5 + 0.9)
		var h := Node3D.new()
		h.position = Vector3(p.x, 0, p.y)
		add_child(h)
		var verm := _cor(Color(0.62, 0.1, 0.07), 0.4)
		_cilindro(h, Vector3(0, 0.35, 0), 0.14, 0.7, verm)
		var tampa := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = 0.16
		esf.height = 0.2
		tampa.mesh = esf
		tampa.material_override = verm
		tampa.position.y = 0.72
		h.add_child(tampa)
		_cilindro(h, Vector3(0, 0.07, 0), 0.2, 0.14, verm)
		for s in [-1, 1]:
			var boca := _cilindro(h, Vector3(s * 0.17, 0.48, 0), 0.06, 0.14, verm)
			boca.rotation.z = PI * 0.5
		if feitos % 3 == 0:  # barril com fogo
			var q: Vector2 = p + d * 3.0
			_cilindro(self, Vector3(q.x, 0.45, q.y), 0.3, 0.9, _cor(Color(0.25, 0.18, 0.12), 0.5))
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.55, 0.25)
			luz.light_energy = 1.6
			luz.omni_range = 7.0
			luz.position = Vector3(q.x, 1.3, q.y)
			add_child(luz)
			var chama := MeshInstance3D.new()
			var cm := SphereMesh.new()
			cm.radius = 0.25
			cm.height = 0.6
			chama.mesh = cm
			var mf := StandardMaterial3D.new()
			mf.emission_enabled = true
			mf.emission = Color(1.0, 0.45, 0.1)
			mf.emission_energy_multiplier = 3.0
			mf.albedo_color = Color(1.0, 0.5, 0.1)
			chama.material_override = mf
			chama.position = Vector3(q.x, 1.05, q.y)
			add_child(chama)
			if not Rede.servidor_sem_tela:  # crepitar do fogo
				var crepita := AudioStreamPlayer3D.new()
				var fogo: AudioStreamOggVorbis = (load("res://assets/sons/amb/fogo.ogg") as AudioStreamOggVorbis).duplicate()
				fogo.loop = true
				crepita.stream = fogo
				crepita.unit_size = 3.0
				crepita.max_distance = 18.0
				crepita.autoplay = true
				crepita.position = Vector3(q.x, 0.9, q.y)
				add_child(crepita)


func _mancha(no: Node3D, p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = _rng.randf_range(0.5, 1.0)
	cm.bottom_radius = cm.top_radius
	cm.height = 0.01
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.04, 0.03, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = p + Vector3(0, 0.08, 0)
	no.add_child(mi)


# --- API usada pelo jogo ---

## Ponto na frente da porta da casa/mansão (renascer na casa da facção).
func frente_da(casa: String) -> Vector3:
	var c := get_node_or_null(casa)
	return c.get_meta("frente") if c else ORIGEM


## Ponto dentro da casa, uns 1,5 m depois da porta.
func dentro_da(casa: String) -> Vector3:
	var fr: Vector3 = frente_da(casa)
	var c: Vector2 = _centro(get_node(casa).get_meta("poly"))
	var meio: Vector3 = ORIGEM + Vector3(c.x, 0.1, c.y)
	return fr + (meio - fr).normalized() * 4.0


## Baú da facção da mansão (null nas casas comuns).
func bau_da(casa: String) -> Bau:
	var c := get_node_or_null(casa)
	return c.get_node_or_null("BauFac") as Bau if c else null


## Só as mansões podem ser dominadas por facção.
func dominavel(casa: String) -> bool:
	var c := get_node_or_null(casa)
	return c != null and c.has_meta("dominavel")


## Nome da construção (Casa_k / Mansao_k) em que o ponto está dentro, ou "".
func casa_em(p: Vector3) -> String:
	var l := Vector2(p.x - ORIGEM.x, p.z - ORIGEM.z)
	for casa: Node3D in get_tree().get_nodes_in_group("casas"):
		if p.y - ORIGEM.y < PAREDE + 0.6 and Geometry2D.is_point_in_polygon(l, casa.get_meta("poly")):
			return String(casa.name)
	return ""


## `n` pedaços de rua (de largura >= `larg_min`) espalhados por igual pelo comprimento de todas as ruas: as ruas
## curvas são feitas de pedacinhos de ~6 m, então escolher por pedaço comprido não serve.
func _espalhados(n: int, larg_min: float) -> Array:
	var ok: Array = _ruas.filter(func(r: Array) -> bool: return float(r[2]) >= larg_min)
	var total: float = 0.0
	for r: Array in ok:
		total += (r[0] as Vector2).distance_to(r[1])
	var passo: float = total / maxf(n, 1)
	var proximo: float = _rng.randf() * passo
	var corre: float = 0.0
	var out: Array = []
	for r: Array in ok:
		corre += (r[0] as Vector2).distance_to(r[1])
		if corre >= proximo and out.size() < n:
			out.append(r)
			proximo += passo * _rng.randf_range(0.7, 1.3)
	return out


func _classifica() -> void:
	for r: Array in _espalhados(30, 0.0):  # zumbis pelas ruas (fora os dos carros)
		pontos_zumbi.append(ORIGEM + _v3((r[0] as Vector2).lerp(r[1], 0.5)) + Vector3(0, 0.1, 0))
	var faceis: Array = find_children("Bau_*", "Bau", true, false).filter(func(b: Bau) -> bool: return b.facil)
	for p: Vector3 in pontos_nascer:
		var perto_bau: bool = faceis.any(func(b: Bau) -> bool: return b.global_position.distance_to(p) <= BOM_BAU)
		var longe_zumbi: bool = pontos_zumbi.all(func(z: Vector3) -> bool: return z.distance_to(p) >= BOM_ZUMBI)
		(pontos_bons if perto_bau and longe_zumbi else pontos_ruins).append(p)


## Sorteia onde nascer: CHANCE_BOM de cair num ponto bom (se houver), senão num ruim.
static func sorteia(rng: RandomNumberGenerator, bons: Array[Vector3], ruins: Array[Vector3], chance: float = CHANCE_BOM) -> Vector3:
	var lista: Array[Vector3] = bons if (rng.randf() < chance and not bons.is_empty()) or ruins.is_empty() else ruins
	return lista[rng.randi() % lista.size()]


# --- geometria ---

func _poly(pts: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q: Array in pts:
		p.append(Vector2(q[0], q[1]))
	return p


func _area(p: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return s * 0.5


func _centro(p: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in p:
		c += q
	return c / maxf(p.size(), 1)


func _dentro(p: Vector2) -> bool:
	return absf(p.x) < TAMANHO * 0.5 and absf(p.y) < TAMANHO * 0.5


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0, p.y)


func _normal_fora(poly: PackedVector2Array, i: int) -> Vector2:
	var a: Vector2 = poly[i]
	var b: Vector2 = poly[(i + 1) % poly.size()]
	var n := Vector2(b.y - a.y, a.x - b.x).normalized()
	return n if n.dot((a + b) * 0.5 - _centro(poly)) > 0.0 else -n


# lado do contorno mais perto de uma rua (é onde fica a porta)
func _lado_da_rua(poly: PackedVector2Array) -> int:
	var melhor: int = 0
	var dist: float = INF
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if a.distance_to(b) < Porta.LARGURA + 0.6:
			continue
		var m: Vector2 = (a + b) * 0.5
		for r: Array in _ruas:
			var d: float = m.distance_to(Geometry2D.get_closest_point_to_segment(m, r[0], r[1]))
			if d < dist:
				dist = d
				melhor = i
	return melhor


func _perto_de_rua(p: Vector2, folga: float) -> bool:
	return _ruas.any(func(r: Array) -> bool: return p.distance_to(Geometry2D.get_closest_point_to_segment(p, r[0], r[1])) < float(r[2]) * 0.5 + folga)


# --- construção ---

## Caixa de 1 m dividida por todas as peças (cada uma esticada com `scale`): uma malha por peça pesava centenas de MB.
var _cubo := BoxMesh.new()
var _janela := QuadMesh.new()  # 1,1 x 1,2 m (no _ready)


func _caixa(corpo: Node3D, tam: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cubo
	mi.scale = tam
	mi.material_override = m
	corpo.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	corpo.add_child(cs)


func _bloco(pai: Node3D, c: Vector3, tam: Vector3, m: Material) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = c
	pai.add_child(corpo)
	_caixa(corpo, tam, m)


## Peça só de enfeite (sem colisão). Quem gira a peça depois mexe em `rotation`; o tamanho fica no `scale`.
func _peca(pai: Node3D, p: Vector3, tam: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cubo
	mi.scale = tam
	mi.material_override = m
	mi.position = p
	pai.add_child(mi)
	return mi


func _cilindro(pai: Node3D, p: Vector3, raio: float, alt: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raio
	cm.bottom_radius = raio
	cm.height = alt
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = m
	mi.position = p
	pai.add_child(mi)
	return mi


func _plano(pai: Node3D, p: Vector3, tam: Vector2, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = tam
	mi.mesh = pm
	mi.material_override = m
	mi.position = p
	pai.add_child(mi)


# material com textura realista (cor + relevo) projetada pelo mundo: emenda sozinha entre peças
## sombra = usa a sombra de canto assada nas cores dos vértices (ruínas do Blender)
func _mat(nome: String, escala: float, tinta: Color = Color(0.82, 0.8, 0.76), sombra: bool = false) -> Material:
	var chave: String = "%s_%s_%s_%s" % [nome, escala, tinta, sombra]
	if not _mats.has(chave):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(TEX % [nome, "cor"])
		m.normal_enabled = true
		m.normal_texture = load(TEX % [nome, "normal"])
		m.albedo_color = tinta  # um pouco mais escuro e sujo
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * escala
		m.roughness = 0.95
		m.vertex_color_use_as_albedo = sombra
		_mats[chave] = m
	return _mats[chave]


func _cor(cor: Color, rug: float = 0.9) -> Material:
	var chave: String = "c_%s_%s" % [cor, rug]
	if not _mats.has(chave):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = rug
		_mats[chave] = m
	return _mats[chave]
