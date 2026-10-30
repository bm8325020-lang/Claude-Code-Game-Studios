# Cidade (primeira área do mapa; referência do dono: cidadezinha low-poly vista de cima, só que abandonada): 3 x 3
# quarteirões. No meio a praça; em volta casas comuns (abandonadas, arrombadas ou destruídas, com móveis), posto de
# gasolina, mercado/galpão com o prédio alto, e as MANSÕES (inteiras e luxuosas: muro, portão, jardim, colunas,
# andar de cima, piscina, garagem) — só elas podem ser dominadas por facção (baú da facção e cama dentro).
# Ruas com faixa e faixa de pedestre, calçadas com postes, lixeiras, hidrantes, carros (alguns queimados), barricadas.
# Tudo em código e igual em todos os aparelhos (sorteio com semente fixa); nomes fixos (Casa_k, Mansao_k, Porta_*,
# Bau_*, Item_b*) para a rede achar. Detalhe pequeno some de longe (visibility_range) para o celular não pesar.
class_name Bairro
extends Node3D

const ORIGEM := Vector3(0, 0, -112)  # centro da praça (a pista de teste fica ao norte, em z > -30)
const QUADRA: float = 30.0           # lado de um quarteirão
const RUA: float = 10.0              # largura da rua (com calçadas)
const CALCADA: float = 1.6
const PAREDE: float = 2.8
const TAMANHO: float = QUADRA * 3.0 + RUA * 4.0  # lado da cidade inteira
const LONGE_DETALHE: float = 45.0    # detalhe pequeno some depois disso
## cores sujas de cidade abandonada (parede, telhado)
const PAREDES: Array[Color] = [Color(0.78, 0.74, 0.66), Color(0.7, 0.72, 0.7), Color(0.74, 0.66, 0.58), Color(0.62, 0.66, 0.7), Color(0.8, 0.78, 0.72)]
const TELHADOS: Array[Color] = [Color(0.5, 0.2, 0.14), Color(0.32, 0.22, 0.17), Color(0.26, 0.28, 0.32), Color(0.45, 0.26, 0.17)]
## casa comum: 0 abandonada (porta fechada), 1 arrombada (sem porta, porta no chão), 2 destruída (parede e telhado caídos)
const ABANDONADA: int = 0
const ARROMBADA: int = 1
const DESTRUIDA: int = 2

## onde os zumbis nascem e onde o jogador pode nascer (mundo)
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
## material "sujo" (um shader para a cidade inteira): o tipo muda o desenho
const PAREDE_T: int = 0   # manchas, escorrido, sujeira subindo do chão, rachadura, pichação
const GRAMA_T: int = 1    # falhada, seca e com terra
const TELHADO_T: int = 2  # fileiras de telha e musgo
const ASFALTO_T: int = 3  # rachaduras e manchas de óleo
static var _sujo: Shader
var _n_casa: int = 0
var _n_mansao: int = 0
var _n_item: int = 0


func _ready() -> void:
	_rng.seed = 2024
	position = ORIGEM
	_chapa(Vector3.ZERO, Vector2(TAMANHO, TAMANHO), Color(0.12, 0.12, 0.13), 0.02)  # asfalto de tudo
	for qx in [-1, 0, 1]:
		for qz in [-1, 0, 1]:
			var c := Vector3(qx, 0, qz) * (QUADRA + RUA)
			_chapa(c, Vector2(QUADRA + CALCADA * 2.0, QUADRA + CALCADA * 2.0), Color(0.55, 0.54, 0.5), 0.12, true)  # calçada
			match Vector2i(qx, qz):
				Vector2i(0, 0):
					_praca(c)
				Vector2i(1, -1):
					_quadra_predio(c)
				Vector2i(-1, -1):
					_posto(c)
				Vector2i(1, 1):
					_chapa(c, Vector2(QUADRA, QUADRA), Color(0.3, 0.4, 0.24), 0.14)
					_mansao(c + Vector3(-QUADRA * 0.25, 0, 0), 0.0)
					_mansao(c + Vector3(QUADRA * 0.25, 0, 0), 0.0)
				Vector2i(-1, 1):
					_chapa(c, Vector2(QUADRA, QUADRA), Color(0.36, 0.42, 0.26), 0.14)
					_mansao(c + Vector3(-QUADRA * 0.25, 0, 0), 0.0)
					for lz in [-1, 1]:
						_casa(c + Vector3(QUADRA * 0.25, 0, lz * QUADRA * 0.25), 0.0 if lz == 1 else 180.0)
				_:
					_chapa(c, Vector2(QUADRA, QUADRA), Color(0.36, 0.42, 0.26), 0.14)  # grama seca
					_quadra_casas(c)
			_postes(c)
	_faixas()
	_carros()
	_barricadas()
	pontos_zumbi.append_array([Vector3(0, 0, 0), Vector3(-20, 0, 2), Vector3(22, 0, -1), Vector3(1, 0, 24),
		Vector3(-2, 0, -26), Vector3(-36, 0, 18), Vector3(40, 0, 20), Vector3(-41, 0, -40), Vector3(20, 0, -40),
		Vector3(-20, 0, 40), Vector3(45, 0, -20)].map(func(p: Vector3) -> Vector3: return p + ORIGEM))
	_classifica()


# --- quarteirões ---

# 4 casas comuns, cada uma de frente para a rua mais perto; estado sorteado
func _quadra_casas(c: Vector3) -> void:
	for lx in [-1, 1]:
		for lz in [-1, 1]:
			var lote := c + Vector3(lx, 0, lz) * QUADRA * 0.25
			_casa(lote, 0.0 if lz == 1 else 180.0)
			_arvore(lote + Vector3(-lx * 5.5, 0, lz * 5.0))
			_cerca(lote + Vector3(lx * 6.8, 0, 0), 90.0, 12.0)


# praça: piso de pedra, chafariz seco com estátua, bancos, canteiros com árvores
func _praca(c: Vector3) -> void:
	_chapa(c, Vector2(QUADRA, QUADRA), Color(0.5, 0.48, 0.44), 0.14)
	_chapa(c, Vector2(QUADRA - 6.0, QUADRA - 6.0), Color(0.44, 0.42, 0.38), 0.15)
	var fonte := Vector3(c.x, 0, c.z)
	_cilindro(self, fonte + Vector3(0, 0.4, 0), 3.2, 0.8, Color(0.6, 0.58, 0.54), true)  # borda do chafariz
	_cilindro(self, fonte + Vector3(0, 0.81, 0), 2.9, 0.02, Color(0.25, 0.27, 0.24), false)  # fundo seco, sujo
	_cilindro(self, fonte + Vector3(0, 1.4, 0), 0.5, 1.4, Color(0.55, 0.53, 0.5), true)  # pedestal
	_peca(self, fonte + Vector3(0, 2.6, 0), Vector3(0.5, 1.1, 0.35), Color(0.35, 0.4, 0.36))  # estátua (bronze velho)
	_peca(self, fonte + Vector3(0, 3.35, 0), Vector3(0.32, 0.36, 0.32), Color(0.35, 0.4, 0.36))
	for k in 4:
		var ang: float = PI * 0.5 * k + PI * 0.25
		var p := fonte + Vector3(sin(ang), 0, cos(ang)) * 8.5
		_banco(p, rad_to_deg(ang) + 90.0)
		_arvore(fonte + Vector3(sin(ang), 0, cos(ang)) * 12.0)
	for k in 4:
		var ang: float = PI * 0.5 * k
		_canteiro(fonte + Vector3(sin(ang), 0, cos(ang)) * 11.5)


# prédio alto (fechado) e o mercado/galpão aberto, com prateleiras
func _quadra_predio(c: Vector3) -> void:
	_chapa(c, Vector2(QUADRA, QUADRA), Color(0.42, 0.42, 0.4), 0.14)  # estacionamento
	var p := c + Vector3(-6, 0, -6)
	_bloco(self, p + Vector3(0, 9, 0), Vector3(10, 18, 10), Color(0.66, 0.7, 0.74))
	for andar in 6:
		for s in [-1, 1]:
			_janela_grande(p + Vector3(s * 5.06, 2.5 + andar * 2.8, 0), Vector2(9.0, 1.3), 90.0)
			_janela_grande(p + Vector3(0, 2.5 + andar * 2.8, s * 5.06), Vector2(9.0, 1.3), 0.0)
	_peca(self, p + Vector3(0, 18.6, 0), Vector3(3, 1.2, 3), Color(0.5, 0.52, 0.54))  # casa de máquinas
	var g := c + Vector3(5, 0, 7)
	var cor := Color(0.6, 0.6, 0.58)
	_bloco(self, g + Vector3(0, 2.5, -5), Vector3(12, 5, 0.3), cor)
	for s in [-1, 1]:
		_bloco(self, g + Vector3(s * 6, 2.5, 0), Vector3(0.3, 5, 10), cor)
		_bloco(self, g + Vector3(s * 3.75, 2.5, 5), Vector3(4.5, 5, 0.3), cor)  # frente com vão de 3 m
	_bloco(self, g + Vector3(0, 5.1, 0), Vector3(12.6, 0.2, 10.6), Color(0.35, 0.42, 0.55))  # telhado azul
	_peca(self, g + Vector3(0, 5.6, 5.2), Vector3(5, 0.9, 0.15), Color(0.7, 0.2, 0.15))  # letreiro do mercado
	for x in [-3.5, 0.0, 3.5]:
		_bloco(self, g + Vector3(x, 0.9, -1.0), Vector3(0.6, 1.8, 6.0), Color(0.5, 0.5, 0.52))  # prateleiras
		for k in 4:
			_detalhe(g + Vector3(x + _rng.randf_range(-0.2, 0.2), 1.0 + (k % 2) * 0.6, -3.0 + k * 1.4), Vector3(0.3, 0.25, 0.3), Color(0.7, 0.5, 0.3).lerp(Color(0.3, 0.5, 0.7), _rng.randf()))
	var b := Bau.new()
	b.name = "Bau_galpao"
	b.position = g + Vector3(-4.5, 0, -3.8)
	add_child(b)
	for k in 3:  # vagas pintadas
		_chapa(c + Vector3(-12 + k * 3.0, 0, 10), Vector2(0.12, 5.0), Color(0.8, 0.8, 0.75), 0.15)


# posto de gasolina: cobertura em 4 pilares, 2 bombas, lojinha aberta, placa alta
func _posto(c: Vector3) -> void:
	_chapa(c, Vector2(QUADRA, QUADRA), Color(0.32, 0.32, 0.33), 0.14)
	var p := c + Vector3(2, 0, 4)
	for x in [-5, 5]:
		for z in [-3.5, 3.5]:
			_bloco(self, p + Vector3(x, 2.2, z), Vector3(0.4, 4.4, 0.4), Color(0.85, 0.85, 0.82))
	_peca(self, p + Vector3(0, 4.6, 0), Vector3(12, 0.5, 9), Color(0.85, 0.85, 0.82))
	_peca(self, p + Vector3(0, 4.6, 4.56), Vector3(12, 0.3, 0.05), Color(0.75, 0.2, 0.15))  # faixa vermelha
	for z in [-1.8, 1.8]:
		_bloco(self, p + Vector3(0, 0.15, z), Vector3(3.5, 0.3, 1.0), Color(0.6, 0.6, 0.58))  # ilha
		for x in [-1, 1]:
			_bloco(self, p + Vector3(x, 0.95, z), Vector3(0.6, 1.3, 0.45), Color(0.8, 0.25, 0.2))  # bomba
			_detalhe(p + Vector3(x, 1.25, z + 0.24), Vector3(0.35, 0.3, 0.02), Color(0.1, 0.12, 0.12))  # visor
	var l := c + Vector3(-8, 0, -8)  # lojinha
	var cor := Color(0.82, 0.8, 0.75)
	_bloco(self, l + Vector3(0, 1.5, -3), Vector3(8, 3, 0.25), cor)
	for s in [-1, 1]:
		_bloco(self, l + Vector3(s * 4, 1.5, 0), Vector3(0.25, 3, 6), cor)
		_bloco(self, l + Vector3(s * 2.5, 1.5, 3), Vector3(3, 3, 0.25), cor)
	_bloco(self, l + Vector3(0, 3.1, 0), Vector3(8.4, 0.2, 6.4), Color(0.3, 0.3, 0.32))
	_bloco(self, l + Vector3(0, 0.5, -1.5), Vector3(3, 1, 0.8), Color(0.45, 0.35, 0.25))  # balcão
	_janela_grande(l + Vector3(-2.5, 1.6, 3.14), Vector2(2.5, 1.4), 0.0)
	var b := Bau.new()
	b.name = "Bau_posto"
	b.facil = true
	b.position = l + Vector3(2.8, 0, -2.2)
	add_child(b)
	var placa := c + Vector3(12, 0, 12)
	_bloco(self, placa + Vector3(0, 3.5, 0), Vector3(0.35, 7, 0.35), Color(0.4, 0.4, 0.42))
	_peca(self, placa + Vector3(0, 7.4, 0), Vector3(2.6, 1.6, 0.3), Color(0.75, 0.2, 0.15))
	_peca(self, placa + Vector3(0, 7.4, 0.16), Vector3(2.0, 0.9, 0.02), Color(0.9, 0.85, 0.7))


# --- casas ---

# casa comum: paredes com porta na frente, janelas (às vezes tapadas com tábuas), piso, forro, telhado, móveis;
# arrombada fica sem porta (a porta caída no chão); destruída tem um canto da parede e meio telhado no chão
func _casa(lote: Vector3, giro: float) -> void:
	var larg: float = _rng.randf_range(6.5, 8.5)
	var fundo: float = _rng.randf_range(6.0, 7.5)
	var k: int = _n_casa
	_n_casa += 1
	var estado: int = [ABANDONADA, ARROMBADA, ABANDONADA, DESTRUIDA][k % 4]
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
	if estado == DESTRUIDA:
		# fundo pela metade (o resto caiu) e entulho no chão
		_bloco(casa, Vector3(-larg * 0.25, PAREDE * 0.5, -fundo * 0.5), Vector3(larg * 0.5, PAREDE, 0.2), cor)
		_bloco(casa, Vector3(larg * 0.3, 0.6, -fundo * 0.5), Vector3(larg * 0.4, 1.2, 0.2), cor)
		_entulho(casa, Vector3(larg * 0.3, 0, -fundo * 0.5 + 0.8), cor)
	else:
		_bloco(casa, Vector3(0, PAREDE * 0.5, -fundo * 0.5), Vector3(larg, PAREDE, 0.2), cor)
	for s in [-1, 1]:
		_bloco(casa, Vector3(s * larg * 0.5, PAREDE * 0.5, 0), Vector3(0.2, PAREDE, fundo), cor)
		_bloco(casa, Vector3(s * (meio + lado * 0.5), PAREDE * 0.5, fundo * 0.5), Vector3(lado, PAREDE, 0.2), cor)
		_janela(casa, Vector3(s * (meio + lado * 0.5), 1.5, fundo * 0.5 + 0.11), 0.0, _rng.randf() < 0.4)
		_janela(casa, Vector3(s * (larg * 0.5 + 0.11), 1.5, 0), 90.0 * s, _rng.randf() < 0.4)
	_bloco(casa, Vector3(0, (PAREDE + Porta.ALTURA) * 0.5, fundo * 0.5), Vector3(Porta.LARGURA, PAREDE - Porta.ALTURA, 0.2), cor)
	_peca(casa, Vector3(0, 0.08, fundo * 0.5 + 0.5), Vector3(1.6, 0.16, 0.8), Color(0.6, 0.58, 0.54))  # degrau
	_chapa_em(casa, Vector3(0, 0.03, 0), Vector2(larg - 0.2, fundo - 0.2), Color(0.42, 0.32, 0.24))  # piso de tábua
	var telha: Color = TELHADOS[_rng.randi() % TELHADOS.size()]
	if estado == DESTRUIDA:
		_bloco(casa, Vector3(-larg * 0.25, PAREDE + 0.05, 0), Vector3(larg * 0.5 + 0.2, 0.1, fundo + 0.2), cor.darkened(0.3))
		var caido := _peca(casa, Vector3(larg * 0.25, 0.9, -0.5), Vector3(larg * 0.5, 0.15, fundo * 0.9), telha.darkened(0.2))
		caido.rotation_degrees = Vector3(_rng.randf_range(-12, 12), 0, 28)  # pedaço do telhado caído dentro
		_queimado(casa, Vector3(larg * 0.25, 0.04, 0.5), 2.5)
	else:
		_bloco(casa, Vector3(0, PAREDE + 0.05, 0), Vector3(larg + 0.2, 0.1, fundo + 0.2), cor.darkened(0.3))  # forro
		var tel := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(fundo + 0.8, 1.7, larg + 0.6)  # cumeeira de um lado ao outro
		tel.mesh = pm
		tel.material_override = _mat(telha, TELHADO_T)
		tel.position = Vector3(0, PAREDE + 0.95, 0)
		tel.rotation_degrees.y = 90.0
		casa.add_child(tel)
		_peca(casa, Vector3(larg * 0.3, PAREDE + 1.3, -fundo * 0.2), Vector3(0.5, 1.4, 0.5), cor.darkened(0.2))  # chaminé
	if estado == ABANDONADA:
		var porta := Porta.new()
		porta.name = "Porta_b%d" % k
		porta.position = Vector3(-meio, 0, fundo * 0.5)
		casa.add_child(porta)
	else:
		var caida := _peca(casa, Vector3(0.3, 0.05, fundo * 0.5 - 1.3), Vector3(Porta.LARGURA, 0.06, Porta.ALTURA), Color(0.4, 0.28, 0.18))
		caida.rotation_degrees.y = _rng.randf_range(-30, 30)  # porta arrombada no chão
	_moveis(casa, larg, fundo)
	if k % 2 == 0:
		var b := Bau.new()
		b.name = "Bau_b%d" % k
		b.position = Vector3(larg * 0.5 - 0.9, 0, -fundo * 0.5 + 0.7)
		b.facil = k % 4 == 0
		casa.add_child(b)
	_item(casa, Vector3(-larg * 0.5 + 0.8, 0, -fundo * 0.5 + 0.8), ["comida", "agua", "municao"][k % 3])
	_lixo(lote + Basis(Vector3.UP, deg_to_rad(giro)) * Vector3(larg * 0.5 + 1.2, 0, fundo * 0.5 + 1.0))
	pontos_nascer.append(ORIGEM + lote + Basis(Vector3.UP, deg_to_rad(giro)) * Vector3(0, 0.1, fundo * 0.5 + 2.5))


# mansão (dominável): lote murado com portão, jardim com arbustos, casa grande de 2 andares (só o térreo entra),
# varanda com colunas, janelas grandes, garagem, piscina vazia no fundo; dentro: sala com sofá, tapete, lareira,
# quarto com cama (cura quem é da facção) e o baú da facção
func _mansao(lote: Vector3, giro: float) -> void:
	var k: int = _n_mansao
	_n_mansao += 1
	var larg: float = 11.0
	var fundo: float = 9.0
	var alt: float = 3.4
	var m := Node3D.new()
	m.name = "Mansao_%d" % k
	m.position = lote
	m.rotation_degrees.y = giro
	m.set_meta("tam", Vector2(larg, fundo))
	m.set_meta("dominavel", true)
	m.add_to_group("casas")
	add_child(m)
	var creme := Color(0.88, 0.84, 0.74)
	var escuro := Color(0.24, 0.22, 0.22)
	# muro baixo com portão aberto e pilares
	var lw: float = QUADRA * 0.5 - 1.0
	var ld: float = QUADRA - 2.0
	for s in [-1, 1]:
		_bloco(m, Vector3(s * lw * 0.5, 0.55, 0), Vector3(0.25, 1.1, ld), creme)  # lados
		_bloco(m, Vector3(s * (lw * 0.25 + 1.0), 0.55, ld * 0.5), Vector3(lw * 0.5 - 2.0, 1.1, 0.25), creme)  # frente
		_bloco(m, Vector3(s * 1.6, 0.8, ld * 0.5), Vector3(0.45, 1.6, 0.45), creme.darkened(0.1))  # pilares do portão
	_bloco(m, Vector3(0, 0.55, -ld * 0.5), Vector3(lw, 1.1, 0.25), creme)  # fundo
	_chapa_em(m, Vector3(0, 0.15, 0), Vector2(lw - 0.3, ld - 0.3), Color(0.32, 0.44, 0.24))  # gramado bem cuidado
	_chapa_em(m, Vector3(0, 0.16, ld * 0.25 + 1.0), Vector2(2.2, ld * 0.5 - 4.0), Color(0.62, 0.6, 0.55))  # caminho
	var corpo := Vector3(0, 0, 1.0)  # centro da casa no lote
	# paredes do térreo com porta na frente
	var meio: float = Porta.LARGURA * 0.5
	var lado: float = (larg - Porta.LARGURA) * 0.5
	_bloco(m, corpo + Vector3(0, alt * 0.5, -fundo * 0.5), Vector3(larg, alt, 0.25), creme)
	for s in [-1, 1]:
		_bloco(m, corpo + Vector3(s * larg * 0.5, alt * 0.5, 0), Vector3(0.25, alt, fundo), creme)
		_bloco(m, corpo + Vector3(s * (meio + lado * 0.5), alt * 0.5, fundo * 0.5), Vector3(lado, alt, 0.25), creme)
		_janela_grande_em(m, corpo + Vector3(s * (meio + lado * 0.5), 1.7, fundo * 0.5 + 0.14), Vector2(2.2, 1.8), 0.0)
		_janela_grande_em(m, corpo + Vector3(s * (larg * 0.5 + 0.14), 1.7, 0), Vector2(3.0, 1.8), 90.0)
	_bloco(m, corpo + Vector3(0, (alt + Porta.ALTURA) * 0.5, fundo * 0.5), Vector3(Porta.LARGURA, alt - Porta.ALTURA, 0.25), creme)
	_bloco(m, corpo + Vector3(0, alt + 0.1, 0), Vector3(larg + 0.3, 0.2, fundo + 0.3), creme.darkened(0.15))  # laje
	# andar de cima (só de fora): um pouco menor, janelas, telhado escuro
	_bloco(m, corpo + Vector3(0, alt + 1.7, -0.6), Vector3(larg - 1.6, 3.0, fundo - 2.2), creme)
	for s in [-1, 1]:
		_janela_grande_em(m, corpo + Vector3(s * 2.2, alt + 1.9, -0.6 + (fundo - 2.2) * 0.5 + 0.02), Vector2(1.6, 1.4), 0.0)
	var tel := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(larg - 0.8, 1.6, fundo - 1.4)
	tel.mesh = pm
	tel.material_override = _mat(escuro, TELHADO_T)
	tel.position = corpo + Vector3(0, alt + 4.0, -0.6)
	m.add_child(tel)
	# varanda: laje na frente sobre 4 colunas brancas
	_peca(m, corpo + Vector3(0, alt - 0.1, fundo * 0.5 + 1.6), Vector3(5.0, 0.25, 3.2), Color(0.92, 0.9, 0.86))
	for x in [-2.2, -0.9, 0.9, 2.2]:
		_cilindro(m, corpo + Vector3(x, alt * 0.5, fundo * 0.5 + 2.9), 0.18, alt, Color(0.95, 0.94, 0.9), true)
	_peca(m, corpo + Vector3(0, 0.1, fundo * 0.5 + 1.6), Vector3(5.0, 0.2, 3.2), Color(0.6, 0.58, 0.55))  # piso da varanda
	var porta := Porta.new()
	porta.name = "Porta_m%d" % k
	porta.position = corpo + Vector3(-meio, 0, fundo * 0.5)
	m.add_child(porta)
	# dentro
	_chapa_em(m, corpo + Vector3(0, 0.04, 0), Vector2(larg - 0.3, fundo - 0.3), Color(0.5, 0.36, 0.24))  # taco
	_chapa_em(m, corpo + Vector3(0.5, 0.05, 1.0), Vector2(3.2, 2.2), Color(0.45, 0.16, 0.14))  # tapete
	_bloco(m, corpo + Vector3(2.0, 0.4, 2.6), Vector3(2.6, 0.8, 0.9), Color(0.25, 0.3, 0.38))  # sofá
	_peca(m, corpo + Vector3(2.0, 0.85, 3.0), Vector3(2.6, 0.6, 0.2), Color(0.22, 0.27, 0.35))  # encosto
	_bloco(m, corpo + Vector3(0.5, 0.25, 1.0), Vector3(1.2, 0.5, 0.7), Color(0.35, 0.25, 0.18))  # mesinha
	_bloco(m, corpo + Vector3(0.5, 0.9, -fundo * 0.5 + 0.45), Vector3(1.8, 1.8, 0.6), Color(0.5, 0.48, 0.45))  # lareira
	_peca(m, corpo + Vector3(0.5, 0.5, -fundo * 0.5 + 0.76), Vector3(0.9, 0.8, 0.04), Color(0.06, 0.05, 0.05))  # boca
	var bf := Bau.new()
	bf.name = "BauFac"
	bf.de_faccao = true
	bf.position = corpo + Vector3(larg * 0.5 - 0.9, 0, -fundo * 0.5 + 0.8)
	m.add_child(bf)
	var cama := StaticBody3D.new()
	cama.name = "Cama"
	cama.position = corpo + Vector3(-larg * 0.5 + 1.2, 0, -fundo * 0.5 + 1.6)
	cama.add_to_group("camas")
	m.add_child(cama)
	_peca(cama, Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 2.1), Color(0.36, 0.26, 0.18))  # estrado de casal
	_peca(cama, Vector3(0, 0.55, 0.05), Vector3(1.5, 0.14, 1.9), Color(0.8, 0.78, 0.72))  # lençol
	_peca(cama, Vector3(0, 0.62, 0.5), Vector3(1.5, 0.08, 0.9), Color(0.45, 0.2, 0.18))  # coberta
	_peca(cama, Vector3(0, 0.7, -0.8), Vector3(1.2, 0.12, 0.3), Color(0.9, 0.88, 0.84))  # travesseiros
	_peca(cama, Vector3(0, 0.9, -1.03), Vector3(1.6, 0.9, 0.08), Color(0.3, 0.2, 0.14))  # cabeceira
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 0.6, 2.1)
	cs.shape = bs
	cs.position.y = 0.3
	cama.add_child(cs)
	# garagem ao lado (fechada) e piscina vazia no fundo
	var gar := Vector3(-lw * 0.5 + 2.4, 0, 9.5)
	_bloco(m, gar + Vector3(0, 1.4, 0), Vector3(3.6, 2.8, 5.0), creme.darkened(0.08))
	_peca(m, gar + Vector3(0, 1.1, 2.52), Vector3(2.8, 2.2, 0.06), Color(0.55, 0.55, 0.56))  # portão da garagem
	var pisc := Vector3(0, 0, -ld * 0.5 + 4.0)
	_chapa_em(m, pisc + Vector3(0, 0.17, 0), Vector2(7.0, 4.0), Color(0.75, 0.75, 0.72))  # borda
	_chapa_em(m, pisc + Vector3(0, 0.18, 0), Vector2(6.2, 3.2), Color(0.22, 0.35, 0.33))  # água podre
	for s in [-1, 1]:
		_arbusto(m, Vector3(s * 3.5, 0, ld * 0.5 - 1.6))
		_arbusto(m, Vector3(s * (lw * 0.5 - 1.2), 0, -3.0))
	pontos_nascer.append(ORIGEM + lote + Basis(Vector3.UP, deg_to_rad(giro)) * Vector3(0, 0.1, ld * 0.5 + 1.5))


# móveis de casa comum: mesa com cadeiras, sofá, armário, um caixote tombado
func _moveis(casa: Node3D, larg: float, fundo: float) -> void:
	var mad := Color(0.38, 0.27, 0.19)
	var mesa := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.8, 0.4))
	_bloco(casa, mesa + Vector3(0, 0.38, 0), Vector3(1.2, 0.08, 0.8), mad)
	for s in [-1, 1]:
		_detalhe_em(casa, mesa + Vector3(s * 0.8, 0.25, 0), Vector3(0.4, 0.5, 0.4), mad.darkened(0.1))
	_bloco(casa, Vector3(larg * 0.5 - 0.5, 0.9, 0.6), Vector3(0.5, 1.8, 1.2), mad.darkened(0.2))  # armário
	_bloco(casa, Vector3(-larg * 0.5 + 0.6, 0.35, 1.2), Vector3(0.8, 0.7, 1.9), Color(0.4, 0.35, 0.3))  # sofá velho
	var cx := _peca(casa, Vector3(0.6, 0.2, fundo * 0.5 - 1.6), Vector3(0.5, 0.4, 0.5), mad)
	cx.rotation_degrees = Vector3(0, 30, 90)  # caixote tombado
	cx.visibility_range_end = LONGE_DETALHE


func _item(pai: Node3D, p: Vector3, tipo: String) -> void:
	var it := Item.new()
	it.name = "Item_b%d" % _n_item
	_n_item += 1
	it.tipo = tipo
	it.quantidade = 12 if tipo == "municao" else 1
	it.position = p
	pai.add_child(it)


# --- rua ---

# faixas amarelas tracejadas no meio das ruas e faixas de pedestre em volta da praça
func _faixas() -> void:
	var amarelo := Color(0.85, 0.7, 0.2)
	var branco := Color(0.82, 0.82, 0.78)
	var ruas: Array = [-1.5, -0.5, 0.5, 1.5]
	var n: int = int(TAMANHO / 4.0)
	for r: float in ruas:
		var linha: float = r * (QUADRA + RUA)
		for i in n:
			var t: float = -TAMANHO * 0.5 + 2.0 + i * 4.0
			if ruas.any(func(q: float) -> bool: return absf(t - q * (QUADRA + RUA)) < RUA * 0.5):
				continue  # sem faixa no cruzamento
			_chapa(Vector3(t, 0, linha), Vector2(2.0, 0.18), amarelo, 0.035)
			_chapa(Vector3(linha, 0, t), Vector2(0.18, 2.0), amarelo, 0.035)
	for cx in [-0.5, 0.5]:
		var c := Vector3(cx * (QUADRA + RUA), 0, 0)
		for k in 6:
			_chapa(c + Vector3(0, 0, -1.8 + k * 0.72) + Vector3(0, 0, QUADRA * 0.5 - 1.5), Vector2(2.2, 0.4), branco, 0.036)


# postes em duas esquinas do quarteirão, lixeira e hidrante (detalhe some de longe)
func _postes(c: Vector3) -> void:
	var m: float = QUADRA * 0.5 + CALCADA * 0.5
	for p: Vector3 in [Vector3(-m, 0, -m), Vector3(m, 0, m)]:
		var q := c + p
		_cilindro(self, q + Vector3(0, 2.6, 0), 0.08, 5.2, Color(0.3, 0.32, 0.33), true)
		_peca(self, q + Vector3(0, 5.1, 0.5), Vector3(0.08, 0.08, 1.0), Color(0.3, 0.32, 0.33)).visibility_range_end = LONGE_DETALHE * 1.5
		_detalhe(q + Vector3(0, 5.0, 0.95), Vector3(0.35, 0.12, 0.25), Color(0.75, 0.75, 0.6))
	_detalhe(c + Vector3(m, 0.45, -m + 2.0), Vector3(0.5, 0.9, 0.5), Color(0.2, 0.35, 0.22))  # lixeira
	_detalhe(c + Vector3(-m, 0.35, m - 2.0), Vector3(0.25, 0.7, 0.25), Color(0.7, 0.15, 0.1))  # hidrante


# carros largados (alguns queimados: pretos, sem vidro), cada um de um jeito
func _carros() -> void:
	var cores: Array[Color] = [Color(0.55, 0.15, 0.12), Color(0.2, 0.3, 0.45), Color(0.75, 0.72, 0.65), Color(0.25, 0.3, 0.22), Color(0.08, 0.08, 0.08)]
	var lugares: Array = [Vector3(-8, 0, 21.5), Vector3(3, 0, -18.5), Vector3(18.5, 0, 30), Vector3(26, 0, 18.5), Vector3(-30, 0, -21.5),
		Vector3(-58.5, 0, 12), Vector3(41, 0, 58.5), Vector3(-19, 0, -58.5), Vector3(58.5, 0, -30), Vector3(10, 0, 58.5), Vector3(-41, 0, 21.5)]
	for p: Vector3 in lugares:
		var carro := StaticBody3D.new()
		carro.position = p
		var na_rua_x: bool = absf(absf(p.z) - 20.0) < 2.0 or absf(absf(p.z) - 60.0) < 2.0  # rua que corre em x
		carro.rotation_degrees.y = (90.0 if na_rua_x else 0.0) + _rng.randf_range(-25.0, 25.0)
		add_child(carro)
		var cor: Color = cores[_rng.randi() % cores.size()]
		var queimado: bool = cor.v < 0.1
		_peca(carro, Vector3(0, 0.65, 0), Vector3(1.8, 0.7, 4.1), cor)
		_peca(carro, Vector3(0, 1.25, -0.2), Vector3(1.6, 0.55, 2.0), cor.darkened(0.15))
		if not queimado:
			_peca(carro, Vector3(0, 1.25, -0.2), Vector3(1.62, 0.4, 1.6), Color(0.08, 0.09, 0.1))  # vidros
			_detalhe_em(carro, Vector3(0, 0.75, 2.06), Vector3(1.4, 0.15, 0.02), Color(0.8, 0.8, 0.7))  # faróis
		else:
			_queimado(self, p, 2.6)
		for r in [Vector3(-0.85, 0.32, 1.3), Vector3(0.85, 0.32, 1.3), Vector3(-0.85, 0.32, -1.3), Vector3(0.85, 0.32, -1.3)]:
			_peca(carro, r, Vector3(0.25, 0.64, 0.64), Color(0.06, 0.06, 0.06))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.8, 1.5, 4.1)
		cs.shape = bs
		cs.position.y = 0.75
		carro.add_child(cs)


# barricadas de sacos de areia (com colisão) e cones em duas entradas da cidade
func _barricadas() -> void:
	var meia: float = TAMANHO * 0.5 - 3.0
	for p: Vector3 in [Vector3(-20, 0, meia), Vector3(meia, 0, 20)]:
		var gira: bool = absf(p.x) > absf(p.z)
		for k in 5:
			for camada in 2:
				var ao_longo: float = -2.4 + k * 1.0 + camada * 0.5
				var pos := p + (Vector3(0, 0.18 + camada * 0.3, ao_longo) if gira else Vector3(ao_longo, 0.18 + camada * 0.3, 0))
				_peca(self, pos, Vector3(0.5, 0.3, 0.9) if gira else Vector3(0.9, 0.3, 0.5), Color(0.55, 0.5, 0.38)).visibility_range_end = LONGE_DETALHE * 1.5
		var corpo := StaticBody3D.new()
		corpo.position = p + Vector3(0, 0.4, 0)
		add_child(corpo)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.6, 0.8, 5.2) if gira else Vector3(5.2, 0.8, 0.6)
		cs.shape = bs
		corpo.add_child(cs)
		for k in 3:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.03
			cm.bottom_radius = 0.18
			cm.height = 0.5
			cm.radial_segments = 6
			cone.mesh = cm
			cone.material_override = _mat(Color(0.9, 0.4, 0.1))
			cone.position = p + (Vector3(-1.5, 0.25, -3.5 + k * 3.5) if gira else Vector3(-3.5 + k * 3.5, 0.25, -1.5))
			cone.visibility_range_end = LONGE_DETALHE
			add_child(cone)


# --- peças pequenas ---

func _banco(p: Vector3, giro: float) -> void:
	var b := Node3D.new()
	b.position = p
	b.rotation_degrees.y = giro
	add_child(b)
	_bloco(b, Vector3(0, 0.42, 0), Vector3(1.8, 0.08, 0.5), Color(0.42, 0.3, 0.2))
	_peca(b, Vector3(0, 0.8, -0.22), Vector3(1.8, 0.4, 0.06), Color(0.42, 0.3, 0.2))
	for s in [-1, 1]:
		_peca(b, Vector3(s * 0.75, 0.2, 0), Vector3(0.08, 0.4, 0.5), Color(0.2, 0.2, 0.22))


func _canteiro(p: Vector3) -> void:
	_bloco(self, p + Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 1.2), Color(0.55, 0.53, 0.5))
	_peca(self, p + Vector3(0, 0.52, 0), Vector3(2.8, 0.06, 1.0), Color(0.3, 0.24, 0.18))
	for k in 3:
		_arbusto(self, p + Vector3(-0.9 + k * 0.9, 0.3, 0), 0.4)


func _arbusto(pai: Node3D, p: Vector3, raio: float = 0.8) -> void:
	var a := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = raio
	e.height = raio * 1.4
	e.radial_segments = 7
	e.rings = 4
	a.mesh = e
	a.material_override = _mat(Color(0.25, 0.38, 0.2))
	a.position = p + Vector3(0, raio * 0.7, 0)
	a.visibility_range_end = LONGE_DETALHE * 1.5
	pai.add_child(a)


# cerca de madeira baixa, com tábuas faltando
func _cerca(p: Vector3, giro: float, comp: float) -> void:
	var c := Node3D.new()
	c.position = p
	c.rotation_degrees.y = giro
	add_child(c)
	var mad := Color(0.45, 0.35, 0.25)
	_peca(c, Vector3(0, 0.75, 0), Vector3(comp, 0.08, 0.05), mad).visibility_range_end = LONGE_DETALHE
	for k in int(comp / 0.5):
		if _rng.randf() < 0.2:
			continue  # tábua faltando
		_detalhe_em(c, Vector3(-comp * 0.5 + k * 0.5 + 0.25, 0.5, 0), Vector3(0.12, 1.0, 0.04), mad)


func _lixo(p: Vector3) -> void:
	for k in _rng.randi_range(1, 3):
		_detalhe(p + Vector3(_rng.randf_range(-0.6, 0.6), 0.22, _rng.randf_range(-0.6, 0.6)), Vector3(0.5, 0.45, 0.45), Color(0.1, 0.1, 0.1))


# entulho: pedaços de parede no chão
func _entulho(pai: Node3D, p: Vector3, cor: Color) -> void:
	for k in 7:
		var e := _peca(pai, p + Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(0.1, 0.3), _rng.randf_range(-0.5, 1.2)), Vector3(_rng.randf_range(0.3, 0.9), _rng.randf_range(0.15, 0.4), _rng.randf_range(0.3, 0.7)), cor.darkened(_rng.randf_range(0.0, 0.3)))
		e.rotation_degrees = Vector3(_rng.randf_range(-25, 25), _rng.randf_range(0, 180), _rng.randf_range(-25, 25))
		e.visibility_range_end = LONGE_DETALHE


# mancha preta de queimado no chão
func _queimado(pai: Node3D, p: Vector3, raio: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raio
	cm.bottom_radius = raio
	cm.height = 0.01
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = p + Vector3(0, 0.05, 0)
	pai.add_child(mi)


# árvore low-poly: tronco e copa de 2 bolas (só o tronco bate)
func _arvore(p: Vector3) -> void:
	var a := StaticBody3D.new()
	a.position = p
	add_child(a)
	var h: float = _rng.randf_range(2.6, 4.0)
	_cilindro(a, Vector3(0, h * 0.5, 0), 0.15, h, Color(0.32, 0.24, 0.18), false)
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


# janela de casa: vidro escuro com peitoril; `tabuas` = tapada com tábuas pregadas
func _janela(pai: Node3D, p: Vector3, giro: float, tabuas: bool) -> void:
	var j := Node3D.new()
	j.position = p
	j.rotation_degrees.y = giro
	pai.add_child(j)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 0.9)
	q.mesh = qm
	q.material_override = _mat(Color(0.12, 0.14, 0.16))
	j.add_child(q)
	_peca(j, Vector3(0, -0.5, 0.04), Vector3(1.2, 0.08, 0.1), Color(0.85, 0.83, 0.78)).visibility_range_end = LONGE_DETALHE
	if tabuas:
		for k in 3:
			var t := _peca(j, Vector3(0, -0.28 + k * 0.28, 0.05), Vector3(1.25, 0.16, 0.04), Color(0.48, 0.36, 0.24))
			t.rotation_degrees.z = _rng.randf_range(-12, 12)
			t.visibility_range_end = LONGE_DETALHE


func _janela_grande(p: Vector3, tam: Vector2, giro: float) -> void:
	_janela_grande_em(self, p, tam, giro)


func _janela_grande_em(pai: Node3D, p: Vector3, tam: Vector2, giro: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = tam
	mi.mesh = q
	if not _mats.has("vidro"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.26, 0.32)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.3
		_mats["vidro"] = m
	mi.material_override = _mats["vidro"]
	mi.position = p
	mi.rotation_degrees.y = giro
	pai.add_child(mi)


# --- API usada pelo jogo ---

## Ponto na frente da porta da casa/mansão (renascer na casa da facção).
func frente_da(casa: String) -> Vector3:
	var c := get_node_or_null(casa) as Node3D
	if c == null:
		return ORIGEM
	var tam: Vector2 = c.get_meta("tam")
	var frente: float = (QUADRA - 2.0) * 0.5 + 1.5 if c.has_meta("dominavel") else tam.y * 0.5 + 2.5
	return c.global_position + c.global_basis.z * frente + Vector3(0, 0.1, 0)


## Baú da facção da mansão (null nas casas comuns).
func bau_da(casa: String) -> Bau:
	var c := get_node_or_null(casa)
	return c.get_node_or_null("BauFac") as Bau if c else null


## Só as mansões podem ser dominadas por facção.
func dominavel(casa: String) -> bool:
	var c := get_node_or_null(casa)
	return c != null and c.has_meta("dominavel")


## Nome da casa (Casa_k / Mansao_k) em que o ponto está dentro, ou "".
func casa_em(p: Vector3) -> String:
	for casa: Node3D in get_tree().get_nodes_in_group("casas"):
		var l: Vector3 = casa.to_local(p)
		var tam: Vector2 = casa.get_meta("tam")
		var cz: float = 1.0 if casa.has_meta("dominavel") else 0.0
		if absf(l.x) < tam.x * 0.5 and absf(l.z - cz) < tam.y * 0.5 and l.y > -0.5 and l.y < PAREDE + 0.6:
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


# --- construção ---

func _cilindro(pai: Node3D, p: Vector3, raio: float, alt: float, cor: Color, solido: bool) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raio
	cm.bottom_radius = raio
	cm.height = alt
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(cor)
	if not solido:
		mi.position = p
		pai.add_child(mi)
		return
	var corpo := StaticBody3D.new()
	corpo.position = p
	pai.add_child(corpo)
	corpo.add_child(mi)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = raio
	cy.height = alt
	cs.shape = cy
	corpo.add_child(cs)


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
	var tipo: int = GRAMA_T if cor.g > cor.r * 1.1 and cor.g > cor.b * 1.3 else (ASFALTO_T if cor.v < 0.16 else PAREDE_T)
	mi.material_override = _mat(cor, tipo)
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


func _peca(pai: Node3D, p: Vector3, tam: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor)
	mi.position = p
	pai.add_child(mi)
	return mi


# detalhe pequeno (só visual): some de longe
func _detalhe(p: Vector3, tam: Vector3, cor: Color) -> void:
	_detalhe_em(self, p, tam, cor)


func _detalhe_em(pai: Node3D, p: Vector3, tam: Vector3, cor: Color) -> void:
	_peca(pai, p, tam, cor).visibility_range_end = LONGE_DETALHE


func _mat(cor: Color, tipo: int = PAREDE_T) -> Material:
	var chave: String = "%s_%d" % [cor, tipo]
	if not _mats.has(chave):
		if _sujo == null:
			_sujo = Shader.new()
			_sujo.code = SUJO
		var m := ShaderMaterial.new()
		m.shader = _sujo
		m.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
		m.set_shader_parameter("tipo", tipo)
		_mats[chave] = m
	return _mats[chave]


# desenho feito no shader (nada baixado), em coordenadas do mundo: emenda sozinho entre peças
const SUJO: String = """shader_type spatial;
uniform vec3 cor;
uniform int tipo;
varying vec3 wp;
varying vec3 wn;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float r(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return r(p) * 0.5 + r(p * 2.1) * 0.3 + r(p * 4.3) * 0.2; }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	bool chao = abs(wn.y) > 0.5;
	vec2 uv = chao ? wp.xz : (abs(wn.x) > 0.5 ? wp.zy : wp.xy);
	vec3 c = cor;
	float n = fbm(uv * 0.8);
	if (tipo == 1) {
		float seco = smoothstep(0.45, 0.7, fbm(uv * 0.35 + 7.0));
		float terra = smoothstep(0.64, 0.8, fbm(uv * 0.6 + 3.0));
		c = mix(c, vec3(0.45, 0.4, 0.24), seco * 0.7);
		c = mix(c, vec3(0.28, 0.22, 0.16), terra);
		c *= 0.8 + h(floor(uv * 22.0)) * 0.35;
	} else if (tipo == 2) {
		float fileira = fract(wp.y * 3.2);
		c *= 0.82 + 0.18 * step(0.18, fileira);
		c *= 0.82 + h(floor(vec2(uv.x * 2.5, wp.y * 3.2))) * 0.3;
		c = mix(c, vec3(0.2, 0.26, 0.14), smoothstep(0.62, 0.8, fbm(uv * 0.5 + 11.0)) * 0.55);
	} else if (tipo == 3) {
		c *= 0.8 + n * 0.4;
		float rach = 1.0 - smoothstep(0.0, 0.008, abs(fbm(uv * 0.3) - 0.5));
		c *= 1.0 - rach * 0.5 * step(0.55, r(uv * 0.05 + 3.0));
		c = mix(c, c * 0.55, smoothstep(0.66, 0.8, fbm(uv * 0.15 + 5.0)));
	} else {
		c *= 0.8 + n * 0.32;
		if (!chao) {
			float baixo = 1.0 - smoothstep(0.0, 1.1, wp.y);
			c = mix(c, c * vec3(0.5, 0.46, 0.38), baixo * 0.7);
			float escorre = smoothstep(0.6, 0.8, r(vec2(uv.x * 3.0, uv.y * 0.12) + 9.0));
			c *= 1.0 - escorre * 0.25;
			float rach = 1.0 - smoothstep(0.0, 0.007, abs(fbm(uv * 0.9 + 2.0) - 0.5));
			c *= 1.0 - rach * 0.4 * step(0.72, r(uv * 0.2 + 4.0));
			float pinta = step(0.9, h(floor(uv / 2.5) + 31.0)) * step(0.45, fbm(uv * 1.8)) * (1.0 - smoothstep(1.4, 2.0, wp.y));
			vec3 tinta = vec3(h(floor(uv / 2.5)), h(floor(uv / 2.5) + 5.0), h(floor(uv / 2.5) + 9.0)) * 0.7 + 0.1;
			c = mix(c, tinta, pinta * 0.8);
		} else {
			c = mix(c, c * 0.7, smoothstep(0.6, 0.78, fbm(uv * 0.4 + 1.0)));
		}
	}
	ALBEDO = c;
	ROUGHNESS = 0.92;
}"""
