# Bairro (primeira área do mapa; referência do dono: cidadezinha low-poly vista de cima): 4 quarteirões em volta de
# um cruzamento, casas de telhado colorido que dá para entrar (porta, baú, comida), um prédio alto, um galpão, ruas
# com faixa amarela, calçadas, grama, árvores e carros largados. Tudo feito em código e igual em todos os aparelhos
# (sorteio com semente fixa); os nomes (Porta_b*, Bau_b*, Item_b*) são fixos para a rede achar.
class_name Bairro
extends Node3D

const ORIGEM := Vector3(0, 0, -78)  # centro do cruzamento (a pista de teste fica ao norte, em z > -30)
const QUADRA: float = 30.0          # lado de um quarteirão
const RUA: float = 10.0             # largura da rua (com calçadas)
const CALCADA: float = 1.6
const PAREDE: float = 2.8
## cores sujas de cidade abandonada (parede, telhado)
const PAREDES: Array[Color] = [Color(0.78, 0.74, 0.66), Color(0.7, 0.72, 0.7), Color(0.74, 0.66, 0.58), Color(0.62, 0.66, 0.7), Color(0.8, 0.78, 0.72)]
const TELHADOS: Array[Color] = [Color(0.5, 0.2, 0.14), Color(0.32, 0.22, 0.17), Color(0.26, 0.28, 0.32), Color(0.45, 0.26, 0.17)]

## onde os zumbis do bairro nascem e onde o jogador pode nascer (mundo)
var pontos_zumbi: Array[Vector3] = []
var pontos_nascer: Array[Vector3] = []
## nascer (prompt 11): "bom" = baú fácil a até BOM_BAU m e nenhum ponto de zumbi a menos de BOM_ZUMBI m
var pontos_bons: Array[Vector3] = []
var pontos_ruins: Array[Vector3] = []
const BOM_BAU: float = 18.0
const BOM_ZUMBI: float = 14.0
const CHANCE_BOM: float = 0.75
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _n_casa: int = 0


func _ready() -> void:
	_rng.seed = 2024
	position = ORIGEM
	var lado: float = QUADRA * 2.0 + RUA * 3.0
	_chapa(Vector3.ZERO, Vector2(lado, lado), Color(0.12, 0.12, 0.13), 0.02)  # asfalto de tudo
	for qx in [-1, 1]:
		for qz in [-1, 1]:
			var c := Vector3(qx, 0, qz) * (QUADRA + RUA) * 0.5
			_chapa(c, Vector2(QUADRA + CALCADA * 2.0, QUADRA + CALCADA * 2.0), Color(0.55, 0.54, 0.5), 0.12, true)  # calçada
			_chapa(c, Vector2(QUADRA, QUADRA), Color(0.36, 0.42, 0.26), 0.14)  # grama seca
			if qx == 1 and qz == -1:
				_quadra_predio(c)
			else:
				_quadra_casas(c, qx, qz)
	_faixas(lado)
	_carros()
	pontos_zumbi.append_array([Vector3(0, 0, 0), Vector3(-20, 0, 2), Vector3(22, 0, -1), Vector3(1, 0, 24),
		Vector3(-2, 0, -26), Vector3(-36, 0, 18)].map(func(p: Vector3) -> Vector3: return p + ORIGEM))
	_classifica()


## Nome da casa (Casa_k) em que o ponto está dentro, ou "".
func casa_em(p: Vector3) -> String:
	for casa: Node3D in get_tree().get_nodes_in_group("casas"):
		var l: Vector3 = casa.to_local(p)
		var tam: Vector2 = casa.get_meta("tam")
		if absf(l.x) < tam.x * 0.5 and absf(l.z) < tam.y * 0.5 and l.y > -0.5 and l.y < PAREDE:
			return String(casa.name)
	return ""


func _classifica() -> void:
	var faceis: Array = find_children("Bau_*", "Bau", true, false).filter(func(b: Bau) -> bool: return b.facil)
	for p: Vector3 in pontos_nascer:
		var perto_bau: bool = faceis.any(func(b: Bau) -> bool: return b.global_position.distance_to(p) <= BOM_BAU)
		var longe_zumbi: bool = pontos_zumbi.all(func(z: Vector3) -> bool: return z.distance_to(p) >= BOM_ZUMBI)
		(pontos_bons if perto_bau and longe_zumbi else pontos_ruins).append(p)


## Sorteia onde nascer: CHANCE_BOM de cair num ponto bom (se houver), senão num ruim.
static func sorteia(rng: RandomNumberGenerator, bons: Array[Vector3], ruins: Array[Vector3], chance: float = CHANCE_BOM) -> Vector3:
	var lista: Array[Vector3] = bons if (rng.randf() < chance and not bons.is_empty()) or ruins.is_empty() else ruins
	return lista[rng.randi() % lista.size()]


# quarteirão com 4 casas, cada uma de frente para a rua mais perto
func _quadra_casas(c: Vector3, qx: int, qz: int) -> void:
	for lx in [-1, 1]:
		for lz in [-1, 1]:
			var lote := c + Vector3(lx, 0, lz) * QUADRA * 0.25
			# a frente vira para a rua de fora (lz) ou para a rua do meio, alternando
			var frente: float = 0.0 if lz == 1 else 180.0
			_casa(lote, frente, _rng.randf_range(6.5, 8.5), _rng.randf_range(6.0, 7.5))
			_arvore(lote + Vector3(-lx * 5.5, 0, lz * 5.0))
			if _rng.randf() < 0.5:
				_arvore(lote + Vector3(lx * 5.5, 0, -lz * 4.0))


# casa: 4 paredes com porta na frente (Porta de verdade), janelas escuras, piso, forro e telhado de duas águas;
# dentro, um baú (às vezes) e comida/água
func _casa(lote: Vector3, giro: float, larg: float, fundo: float) -> void:
	var k: int = _n_casa
	_n_casa += 1
	var casa := Node3D.new()
	casa.name = "Casa_%d" % k
	casa.position = lote
	casa.rotation_degrees.y = giro
	casa.set_meta("tam", Vector2(larg, fundo))
	casa.add_to_group("casas")
	add_child(casa)
	var cor: Color = PAREDES[_rng.randi() % PAREDES.size()]
	var meio: float = Porta.LARGURA * 0.5
	var lado: float = (larg - Porta.LARGURA) * 0.5
	_bloco(casa, Vector3(0, PAREDE * 0.5, -fundo * 0.5), Vector3(larg, PAREDE, 0.2), cor)  # fundo
	for s in [-1, 1]:
		_bloco(casa, Vector3(s * larg * 0.5, PAREDE * 0.5, 0), Vector3(0.2, PAREDE, fundo), cor)  # lados
		_bloco(casa, Vector3(s * (meio + lado * 0.5), PAREDE * 0.5, fundo * 0.5), Vector3(lado, PAREDE, 0.2), cor)  # frente
		_janela(casa, Vector3(s * (meio + lado * 0.5), 1.5, fundo * 0.5 + 0.11), 0.0)
		_janela(casa, Vector3(s * (larg * 0.5 + 0.11), 1.5, 0), 90.0)
	_bloco(casa, Vector3(0, (PAREDE + Porta.ALTURA) * 0.5, fundo * 0.5), Vector3(Porta.LARGURA, PAREDE - Porta.ALTURA, 0.2), cor)
	_bloco(casa, Vector3(0, PAREDE + 0.05, 0), Vector3(larg + 0.2, 0.1, fundo + 0.2), cor.darkened(0.3))  # forro
	_chapa_em(casa, Vector3(0, 0.03, 0), Vector2(larg - 0.2, fundo - 0.2), Color(0.42, 0.32, 0.24))  # piso de tábua
	var tel := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(fundo + 0.8, 1.7, larg + 0.6)  # cumeeira de um lado ao outro, caindo para frente e fundo
	tel.mesh = pm
	tel.material_override = _mat(TELHADOS[_rng.randi() % TELHADOS.size()])
	tel.position = Vector3(0, PAREDE + 0.95, 0)
	tel.rotation_degrees.y = 90.0
	casa.add_child(tel)
	var porta := Porta.new()
	porta.name = "Porta_b%d" % k
	porta.position = Vector3(-meio, 0, fundo * 0.5)
	casa.add_child(porta)
	# dentro: baú encostado no fundo em metade das casas, e uma lata ou garrafa
	if k % 2 == 0:
		var b := Bau.new()
		b.name = "Bau_b%d" % k
		b.position = Vector3(larg * 0.5 - 0.9, 0, -fundo * 0.5 + 0.7)
		b.facil = k % 4 == 0
		casa.add_child(b)
	var it := Item.new()
	it.name = "Item_b%d" % k
	it.tipo = ["comida", "agua", "municao"][k % 3]
	it.quantidade = 12 if it.tipo == "municao" else 1
	it.position = Vector3(-larg * 0.5 + 0.8, 0, -fundo * 0.5 + 0.8)
	casa.add_child(it)
	pontos_nascer.append(ORIGEM + lote + Basis(Vector3.UP, deg_to_rad(giro)) * Vector3(0, 0.1, fundo * 0.5 + 2.5))  # na frente da porta


# quarteirão do prédio alto (fechado, só de fundo) e do galpão aberto (sem porta, dá para entrar)
func _quadra_predio(c: Vector3) -> void:
	var p := c + Vector3(-6, 0, -6)
	_bloco(self, p + Vector3(0, 9, 0), Vector3(10, 18, 10), Color(0.66, 0.7, 0.74))
	for andar in 6:
		for s in [-1, 1]:
			_chapa_parede(p + Vector3(s * 5.06, 2.5 + andar * 2.8, 0), Vector2(9.0, 1.3), 90.0)
			_chapa_parede(p + Vector3(0, 2.5 + andar * 2.8, s * 5.06), Vector2(9.0, 1.3), 0.0)
	var g := c + Vector3(5, 0, 7)
	var cor := Color(0.6, 0.6, 0.58)
	_bloco(self, g + Vector3(0, 2.5, -5), Vector3(12, 5, 0.3), cor)
	for s in [-1, 1]:
		_bloco(self, g + Vector3(s * 6, 2.5, 0), Vector3(0.3, 5, 10), cor)
		_bloco(self, g + Vector3(s * 3.75, 2.5, 5), Vector3(4.5, 5, 0.3), cor)  # frente com vão de 3 m
	_bloco(self, g + Vector3(0, 5.1, 0), Vector3(12.6, 0.2, 10.6), Color(0.35, 0.42, 0.55))  # telhado azul
	var b := Bau.new()
	b.name = "Bau_galpao"
	b.position = g + Vector3(-4.5, 0, -3.8)
	add_child(b)
	_arvore(c + Vector3(10, 0, -10))
	_arvore(c + Vector3(-12, 0, 10))


# faixa amarela tracejada no meio das duas ruas
func _faixas(lado: float) -> void:
	var amarelo := Color(0.85, 0.7, 0.2)
	var n: int = int(lado / 4.0)
	for i in n:
		var t: float = -lado * 0.5 + 2.0 + i * 4.0
		if absf(t) < RUA * 0.5:
			continue  # sem faixa no cruzamento
		_chapa(Vector3(t, 0, 0), Vector2(2.0, 0.18), amarelo, 0.035)
		_chapa(Vector3(0, 0, t), Vector2(0.18, 2.0), amarelo, 0.035)


# carros largados pela rua: carroceria, cabine e rodas escuras, cada um de um jeito
func _carros() -> void:
	var cores: Array[Color] = [Color(0.55, 0.15, 0.12), Color(0.2, 0.3, 0.45), Color(0.75, 0.72, 0.65), Color(0.25, 0.3, 0.22)]
	for p: Vector3 in [Vector3(-8, 0, 2.2), Vector3(3, 0, -18), Vector3(-2.5, 0, 30), Vector3(26, 0, 2.5), Vector3(-30, 0, -2.2)]:
		var carro := StaticBody3D.new()
		carro.position = p
		carro.rotation_degrees.y = (90.0 if absf(p.x) > absf(p.z) else 0.0) + _rng.randf_range(-25.0, 25.0)
		add_child(carro)
		var cor: Color = cores[_rng.randi() % cores.size()]
		_peca(carro, Vector3(0, 0.65, 0), Vector3(1.8, 0.7, 4.1), cor)
		_peca(carro, Vector3(0, 1.25, -0.2), Vector3(1.6, 0.55, 2.0), cor.darkened(0.15))
		_peca(carro, Vector3(0, 1.25, -0.2), Vector3(1.62, 0.4, 1.6), Color(0.08, 0.09, 0.1))  # vidros
		for r in [Vector3(-0.85, 0.32, 1.3), Vector3(0.85, 0.32, 1.3), Vector3(-0.85, 0.32, -1.3), Vector3(0.85, 0.32, -1.3)]:
			_peca(carro, r, Vector3(0.25, 0.64, 0.64), Color(0.06, 0.06, 0.06))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.8, 1.5, 4.1)
		cs.shape = bs
		cs.position.y = 0.75
		carro.add_child(cs)


# árvore low-poly: tronco e copa de 2 bolas achatadas (só o tronco bate)
func _arvore(p: Vector3) -> void:
	var a := StaticBody3D.new()
	a.position = p
	add_child(a)
	var h: float = _rng.randf_range(2.6, 4.0)
	var tronco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.12
	cil.bottom_radius = 0.18
	cil.height = h
	cil.radial_segments = 6
	tronco.mesh = cil
	tronco.material_override = _mat(Color(0.32, 0.24, 0.18))
	tronco.position.y = h * 0.5
	a.add_child(tronco)
	for k in 2:
		var copa := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = _rng.randf_range(1.0, 1.5)
		esf.height = esf.radius * 1.6
		esf.radial_segments = 7
		esf.rings = 4
		copa.mesh = esf
		copa.material_override = _mat(Color(0.3, 0.42, 0.22).lerp(Color(0.45, 0.42, 0.22), _rng.randf()))
		copa.position = Vector3(_rng.randf_range(-0.4, 0.4), h + k * 0.7, _rng.randf_range(-0.4, 0.4))
		a.add_child(copa)
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.2
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	a.add_child(cs)


func _janela(pai: Node3D, p: Vector3, giro: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.9)
	mi.mesh = q
	mi.material_override = _mat(Color(0.12, 0.14, 0.16))
	mi.position = p
	mi.rotation_degrees.y = giro
	pai.add_child(mi)


func _chapa_parede(p: Vector3, tam: Vector2, giro: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = tam
	mi.mesh = q
	mi.material_override = _mat(Color(0.2, 0.26, 0.32))
	mi.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.position = p
	mi.rotation_degrees.y = giro
	add_child(mi)


# chapa no chão (só visual, ou com colisão para calçada)
func _chapa(c: Vector3, tam: Vector2, cor: Color, y: float, solida: bool = false) -> void:
	if solida:
		_bloco(self, c + Vector3(0, y * 0.5, 0), Vector3(tam.x, y, tam.y), cor)
		return
	_chapa_em(self, c + Vector3(0, y, 0), tam, cor)


func _chapa_em(pai: Node3D, c: Vector3, tam: Vector2, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = tam
	mi.mesh = pl
	mi.material_override = _mat(cor)
	mi.position = c
	pai.add_child(mi)


# bloco sólido (colisão + malha) dentro de `pai`
func _bloco(pai: Node3D, c: Vector3, tam: Vector3, cor: Color) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = c
	pai.add_child(corpo)
	_peca(corpo, Vector3.ZERO, tam, cor)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	corpo.add_child(cs)


func _peca(pai: Node3D, p: Vector3, tam: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor)
	mi.position = p
	pai.add_child(mi)


func _mat(cor: Color) -> StandardMaterial3D:
	if not _mats.has(cor):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.9
		_mats[cor] = m
	return _mats[cor]
