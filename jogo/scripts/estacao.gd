# Estação de Pesquisa Halverson (14/11, ESTACAO.md etapa 1): o prédio térreo no meio da mata, onde o surto começou.
# Montado em código, igual em todo aparelho (Bairro lê "estacao" do cidade.json): paredes e chão juntos numa malha por
# material (poucas chamadas de desenho no celular), colisão em caixas (entra na malha de navegação: grupo "cenario"),
# portas (Porta; as de cartão travadas pela cor), luzes frias que piscam, móveis de bloco, esconderijos (Esconderijo),
# os 3 cartões e o filtro UV (Item do mapa) e a porta do bunker (Bunker). O teto não tem colisão (não entra na malha).
#
# Planta (local, metros; +Z = frente, para a estrada):
#   z  +12 ┌ PORTARIA (-18..-6) │ ALOJAMENTO (-6..6) │ QUARTO OKAFOR (6..12) │ REFEITÓRIO (12..18) ┐
#   z +1.5 ├──────────────────── corredor principal (luz piscando) ─────────────────────────────────┤
#   z -1.5 ├ ENFERMARIA (-18..-6) │ LABORATÓRIO (-6..18) [porta VERDE]  ┌ SEGURANÇA (12..18) [AZUL]  ┤
#   z  -12 └──────────────────────┴──────── porta do BUNKER (x 3) ──────┴─────────────────────────────┘
class_name Estacao
extends Node3D

const LARG: float = 36.0
const FUNDO: float = 24.0
const ALTO: float = 3.2
const ESP: float = 0.3      # parede
const VAO: float = 1.4      # porta
const PAREDE := Color(0.84, 0.85, 0.81)
const AZULEJO := Color(0.62, 0.72, 0.66)
const PISO := Color(0.42, 0.45, 0.44)
const TETO := Color(0.3, 0.31, 0.3)
const ACO := Color(0.6, 0.62, 0.64)
const ESCURO := Color(0.18, 0.19, 0.2)
const CORES: Dictionary = {"verde": Color(0.25, 0.68, 0.35), "azul": Color(0.23, 0.47, 0.82), "amarelo": Color(0.9, 0.76, 0.18)}

static var atual: Estacao   # a do mapa (só uma)
var _sts: Dictionary = {}   # cor -> SurfaceTool
var _corpo: StaticBody3D
var _luzes: Array = []      # [OmniLight3D, energia, pisca]
var _t: float = 0.0


func _ready() -> void:
	atual = self
	add_to_group("estacao")
	_corpo = StaticBody3D.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	var h: float = LARG * 0.5
	var f: float = FUNDO * 0.5
	_caixa(Vector3(0, -0.5, 0), Vector3(LARG, 1.0, FUNDO), PISO)   # laje (desce 1 m: cobre o terreno torto)
	_caixa(Vector3(0, ALTO + 0.1, 0), Vector3(LARG, 0.2, FUNDO), TETO, false)
	# paredes de fora (frente com a entrada da portaria em x -12)
	_parede_x(f, -h, h, [-12.0], true)
	_parede_x(-f, -h, h, [], true)
	_parede_z(-h, -f, f, [])
	_parede_z(h, -f, f, [])
	# corredor
	_parede_x(1.5, -h, h, [-12.0, 0.0, 9.0, 15.0])
	_parede_x(-1.5, -h, h, [-12.0, 3.0])
	for x: float in [-6.0, 6.0, 12.0]:
		_parede_z(x, 1.5, f, [])
	_parede_z(-6.0, -f, -1.5, [])
	_parede_z(12.0, -f, -5.0, [])
	_parede_x(-5.0, 12.0, h, [15.0])
	# portas (as do lado de dentro; a entrada e o refeitório ficam sem folha)
	_porta("PortaAlojamento", Vector3(0.0, 0, 1.5), "")
	_porta("PortaOkafor", Vector3(9.0, 0, 1.5), "")
	_porta("PortaEnfermaria", Vector3(-12.0, 0, -1.5), "")
	_porta("PortaLab", Vector3(3.0, 0, -1.5), "verde")
	_porta("PortaSeguranca", Vector3(15.0, 0, -5.0), "azul")
	_faixas()
	_moveis()
	_luzes_monta()
	var b := Bunker.new()  # porta redonda na parede do fundo do laboratório
	b.name = "Bunker"
	b.position = Vector3(3.0, 0, -f + ESP)
	add_child(b)
	_fecha_malhas()


## Está dentro do prédio? (escuro: a lanterna acende; o Paciente Zero fica mais forte)
func dentro(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	return absf(l.x) < LARG * 0.5 and absf(l.z) < FUNDO * 0.5 and l.y > -1.0 and l.y < ALTO + 1.0


## Portaria acesa: o único canto seguro do prédio.
func seguro(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	return l.x < -6.0 and l.z > 1.5 and dentro(p)


func _st(cor: Color) -> SurfaceTool:
	if not _sts.has(cor):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts[cor] = st
	return _sts[cor]


## Caixa: desenho (junto com as da mesma cor) e, se `solida`, colisão.
func _caixa(pos: Vector3, tam: Vector3, cor: Color, solida: bool = true, rot_y: float = 0.0) -> void:
	if not Rede.servidor_sem_tela:
		Bairro._caixa_st(_st(cor), Transform3D(Basis(Vector3.UP, rot_y), pos), tam)
	if solida:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = tam
		cs.shape = b
		cs.position = pos
		cs.rotation.y = rot_y
		_corpo.add_child(cs)


func _fecha_malhas() -> void:
	for cor: Color in _sts:
		var st: SurfaceTool = _sts[cor]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # o teto e o chão são vistos dos dois lados
		mi.material_override = m
		mi.set_meta("sem_estilo", true)
		add_child(mi)
	_sts.clear()


## Parede ao longo de X na altura `z`, de `x0` a `x1`, com vãos de porta centrados em `vaos`. Azulejo até 1,4 m.
func _parede_x(z: float, x0: float, x1: float, vaos: Array, fora: bool = false) -> void:
	var cortes: Array = [x0]
	for v: float in vaos:
		cortes.append_array([v - VAO * 0.5, v + VAO * 0.5])
	cortes.append(x1)
	for k in range(0, cortes.size(), 2):
		var a: float = cortes[k]
		var b: float = cortes[k + 1]
		if b - a < 0.05:
			continue
		_caixa(Vector3((a + b) * 0.5, ALTO * 0.5, z), Vector3(b - a, ALTO, ESP), PAREDE if fora else PAREDE)
		_caixa(Vector3((a + b) * 0.5, 0.7, z), Vector3(b - a, 1.4, ESP + 0.02), AZULEJO, false)
	for v: float in vaos:  # verga em cima de cada vão
		_caixa(Vector3(v, (ALTO + Porta.ALTURA) * 0.5 + 0.05, z), Vector3(VAO, ALTO - Porta.ALTURA - 0.1, ESP), PAREDE)


func _parede_z(x: float, z0: float, z1: float, vaos: Array) -> void:
	var cortes: Array = [z0]
	for v: float in vaos:
		cortes.append_array([v - VAO * 0.5, v + VAO * 0.5])
	cortes.append(z1)
	for k in range(0, cortes.size(), 2):
		var a: float = cortes[k]
		var b: float = cortes[k + 1]
		if b - a < 0.05:
			continue
		_caixa(Vector3(x, ALTO * 0.5, (a + b) * 0.5), Vector3(ESP, ALTO, b - a), PAREDE)
		_caixa(Vector3(x, 0.7, (a + b) * 0.5), Vector3(ESP + 0.02, 1.4, b - a), AZULEJO, false)


func _porta(nome: String, meio: Vector3, cartao: String) -> void:
	var p := Porta.new()
	p.name = nome
	p.cartao = cartao
	p.cor = Color(0.55, 0.57, 0.58) if cartao == "" else (CORES[cartao] as Color).darkened(0.35)
	p.position = meio - Vector3(Porta.LARGURA * 0.5, 0, 0)  # dobradiça na ponta esquerda do vão
	add_child(p)
	if cartao != "":  # leitor de cartão do lado: luz da cor da tranca
		_caixa(meio + Vector3(VAO * 0.5 + 0.25, 1.3, 0.2), Vector3(0.14, 0.22, 0.05), CORES[cartao], false)


## Faixas de cor no chão do corredor até cada porta de cartão (o lugar mostra o caminho, sem seta na tela).
func _faixas() -> void:
	_caixa(Vector3(-4.5, 0.01, 0.6), Vector3(15.0, 0.02, 0.18), CORES.verde, false)
	_caixa(Vector3(3.0, 0.01, -1.0), Vector3(0.18, 0.02, 1.2), CORES.verde, false)
	_caixa(Vector3(15.0, 0.01, -3.25), Vector3(0.18, 0.02, 3.3), CORES.azul, false)
	_caixa(Vector3(9.0, 0.01, -2.0), Vector3(12.0, 0.02, 0.18), CORES.azul, false)
	_caixa(Vector3(3.0, 0.01, -7.0), Vector3(0.18, 0.02, 9.6), CORES.amarelo, false)


func _item(nome: String, tipo: String, pos: Vector3) -> void:
	var it := Item.new()
	it.name = nome
	it.tipo = tipo
	it.quantidade = 1
	it.position = pos
	add_child(it)


func _esconde(nome: String, pos: Vector3, saida: Vector3, tipo: String) -> void:
	var e := Esconderijo.new()
	e.name = nome
	e.tipo = tipo
	e.position = pos
	e.saida = saida
	add_child(e)


func _moveis() -> void:
	# PORTARIA: balcão e bancos (acesa: canto seguro)
	_caixa(Vector3(-12, 0.55, 6.5), Vector3(4.0, 1.1, 0.7), ESCURO)
	for x: float in [-16.5, -15.0]:
		_caixa(Vector3(x, 0.25, 10.8), Vector3(1.2, 0.5, 0.5), ACO)
	# ALOJAMENTO: 4 beliches e 3 armários (armário e debaixo do beliche escondem)
	for k in 4:
		var x: float = -4.5 + k * 3.0
		for y: float in [0.45, 1.55]:
			_caixa(Vector3(x, y, 10.6), Vector3(0.95, 0.18, 2.0), Color(0.35, 0.33, 0.3))
		for dx: float in [-0.45, 0.45]:
			_caixa(Vector3(x + dx, 1.0, 9.65), Vector3(0.06, 2.0, 0.06), ACO, false)
		if k % 2 == 0:
			_esconde("Beliche_%d" % k, Vector3(x, 0.15, 10.6), Vector3(x, 0, 8.9), "beliche")
	for k in 3:
		var z: float = 3.0 + k * 1.1
		_caixa(Vector3(-5.5, 1.0, z), Vector3(0.6, 2.0, 1.0), Color(0.4, 0.45, 0.42))
		_esconde("ArmarioAloj_%d" % k, Vector3(-5.5, 0.0, z), Vector3(-4.6, 0, z), "armario")
	# QUARTO DA OKAFOR: cama, mesa (cartão verde e a fita), armário
	_caixa(Vector3(10.6, 0.3, 9.5), Vector3(1.0, 0.6, 2.0), Color(0.45, 0.32, 0.3))
	_caixa(Vector3(7.2, 0.4, 10.8), Vector3(1.2, 0.8, 0.7), Color(0.38, 0.3, 0.24))
	_item("CartaoVerde", "cartao_verde", Vector3(7.2, 0.82, 10.8))
	_caixa(Vector3(11.4, 1.0, 3.2), Vector3(0.6, 2.0, 1.0), Color(0.4, 0.45, 0.42))
	_esconde("ArmarioOkafor", Vector3(11.4, 0.0, 3.2), Vector3(10.5, 0, 3.2), "armario")
	# REFEITÓRIO: mesas compridas
	for k in 2:
		_caixa(Vector3(15.0, 0.4, 5.0 + k * 4.0), Vector3(3.0, 0.8, 1.0), Color(0.5, 0.48, 0.44))
	# ENFERMARIA: macas e cortinas (debaixo da maca esconde)
	for k in 4:
		var x: float = -16.5 + k * 3.0
		_caixa(Vector3(x, 0.75, -9.5), Vector3(0.9, 0.12, 2.0), Color(0.78, 0.8, 0.78))
		_caixa(Vector3(x, 0.35, -9.5), Vector3(0.1, 0.7, 1.6), ACO, false)
		_caixa(Vector3(x + 1.45, 1.1, -9.0), Vector3(0.04, 2.2, 3.0), Color(0.55, 0.68, 0.62), false)  # cortina
		if k % 2 == 1:
			_esconde("Maca_%d" % k, Vector3(x, 0.15, -9.5), Vector3(x, 0, -7.6), "maca")
	# LABORATÓRIO: bancadas, tanques de amostra, freezers, mesa de necropsia; cartão azul e filtro UV
	for k in 3:
		_caixa(Vector3(-2.0 + k * 4.5, 0.45, -4.5), Vector3(3.0, 0.9, 1.0), ACO)
	_item("CartaoAzul", "cartao_azul", Vector3(7.0, 0.92, -4.5))
	_item("FiltroUV", "filtro_uv", Vector3(-2.0, 0.92, -4.5))
	for k in 3:
		_tanque(Vector3(-4.6, 0, -6.5 - k * 2.0))
	_caixa(Vector3(10.6, 1.0, -10.8), Vector3(1.4, 2.0, 0.8), Color(0.85, 0.87, 0.88))
	_esconde("Freezer", Vector3(10.6, 0.0, -10.8), Vector3(10.6, 0, -9.8), "freezer")
	_caixa(Vector3(7.0, 1.0, -10.8), Vector3(1.4, 2.0, 0.8), Color(0.85, 0.87, 0.88))
	_caixa(Vector3(-1.0, 0.85, -9.0), Vector3(0.9, 0.1, 2.1), ACO)  # mesa de necropsia
	_caixa(Vector3(-1.0, 0.4, -9.0), Vector3(0.3, 0.8, 0.3), ACO)
	# SEGURANÇA: mesa com monitores, arquivo, armário; cartão amarelo
	_caixa(Vector3(15.0, 0.4, -11.0), Vector3(2.4, 0.8, 0.8), ESCURO)
	_caixa(Vector3(15.0, 1.05, -11.2), Vector3(1.6, 0.5, 0.15), Color(0.2, 0.45, 0.35), false)
	_item("CartaoAmarelo", "cartao_amarelo", Vector3(14.2, 0.82, -10.9))
	_caixa(Vector3(17.3, 1.0, -7.5), Vector3(0.6, 2.0, 1.0), Color(0.4, 0.45, 0.42))
	_esconde("ArmarioSeg", Vector3(17.3, 0.0, -7.5), Vector3(16.4, 0, -7.5), "armario")


func _tanque(p: Vector3) -> void:
	_caixa(p + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9), ESCURO)
	if Rede.servidor_sem_tela:
		return
	var mi := MeshInstance3D.new()  # vidro com líquido verde fraco (luz dos tanques)
	var c := CylinderMesh.new()
	c.top_radius = 0.38
	c.bottom_radius = 0.38
	c.height = 1.5
	c.radial_segments = 12
	c.rings = 1
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.8, 0.55, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.2, 0.7, 0.45)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.position = p + Vector3(0, 1.35, 0)
	mi.set_meta("sem_estilo", true)
	add_child(mi)


func _luzes_monta() -> void:
	if Rede.servidor_sem_tela:
		return
	# [posição, cor, energia, alcance, pisca]
	for l: Array in [[Vector3(-12, 2.9, 7), Color(1.0, 0.85, 0.65), 1.6, 9.0, false],   # portaria: segura
			[Vector3(-12, 2.9, 0), Color(0.62, 0.85, 0.8), 1.0, 7.0, true],
			[Vector3(3, 2.9, 0), Color(0.62, 0.85, 0.8), 1.0, 7.0, true],
			[Vector3(14, 2.9, 0), Color(0.62, 0.85, 0.8), 0.9, 7.0, true],
			[Vector3(-4.6, 1.5, -8.5), Color(0.3, 0.9, 0.55), 0.7, 5.0, false],          # tanques
			[Vector3(15, 2.8, -8.5), Color(1.0, 0.15, 0.1), 1.2, 6.0, true]]:            # emergência
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = l[2]
		o.omni_range = l[3]
		o.shadow_enabled = false
		o.distance_fade_enabled = true
		o.distance_fade_begin = 30.0
		add_child(o)
		_luzes.append([o, l[2], l[4]])
	set_process(true)


func _process(dt: float) -> void:  # fluorescente velha: pisca de vez em quando, às vezes apaga um tempo
	_t += dt
	for l: Array in _luzes:
		if not l[2]:
			continue
		var o: OmniLight3D = l[0]
		var falha: bool = fmod(_t * 0.37 + o.position.x * 0.13, 7.0) < 0.6
		o.light_energy = 0.0 if falha and randf() < 0.7 else float(l[1]) * (0.85 + randf() * 0.15)
