# Porão (07/11, plano D2 do dono: "pegada de terror"): em ~1 de cada CADA casas com cozinha, um alçapão aberto no chão da
# cozinha leva a um porão escuro (só a lanterna e uma lâmpada fria falhando), com baú de loot raro e 1-2 zumbis que
# ficam mortos. O porão é uma sala de verdade FUNDO m abaixo da casa (sem buraco no terreno nem malha de navegação
# nova: os zumbis vão reto numa sala pequena); pisar no alçapão desce, pisar no pé da escada sobe.
# Montado igual em todo aparelho (servidor também: colisão, baú e zumbis).
class_name Porao
extends Node3D

const CADA: int = 8          # 1 casa com cozinha em cada CADA ganha porão (pelo nome: igual em todo aparelho)
const FUNDO: float = 40.0    # m abaixo do chão da casa
const LARG: float = 7.0      # sala (x)
const COMP: float = 6.0      # sala (z)
const ALTO: float = 2.4
const ESPERA: float = 1.0    # s sem descer/subir de novo (o jogador chega fora da área)

var alcapao: Vector3         # chão da cozinha (global), acertado pelo raio depois que a física acorda
var sala: Vector3            # meio do chão do porão (global)
var _alcapao_area: Area3D
var _rumo: Vector3 = Vector3.FORWARD  # da cozinha para o meio da casa (subindo, sai para esse lado)

static var _mat: StandardMaterial3D


## Casas que ganham porão: a primeira gaveta de cozinha de cada casa sorteada pelo nome.
static func escolhe(cozinhas: Dictionary) -> Array:
	var r: Array = []
	for casa: Node3D in cozinhas:
		if absi(hash(String(casa.name) + "porao")) % CADA == 0 and not casa.has_meta("refugio"):
			r.append([casa, cozinhas[casa]])
	return r


## `b` é o Bairro; `ponto` a gaveta da cozinha; `meio` o meio da casa (o alçapão fica entre os dois).
static func monta(b: Bairro, casa: Node3D, ponto: Vector3, meio: Vector3, k: int) -> Porao:
	var p := Porao.new()
	p.name = "Porao_%d" % k
	var rumo := Vector3(meio.x - ponto.x, 0, meio.z - ponto.z)
	if rumo.length() > 0.1:
		p._rumo = rumo.normalized()
	p.alcapao = ponto + p._rumo * 1.3
	p.alcapao.y = casa.global_position.y + 0.5  # acertado no _ready pelo raio
	p.sala = Vector3(p.alcapao.x, p.alcapao.y - FUNDO, p.alcapao.z)
	b.add_child(p)
	# zumbis do porão (mortos ficam mortos) e o baú de loot raro
	for z in 1 + absi(hash(String(casa.name))) % 2:
		b.pontos_raid.append({"pos": p.sala + Vector3(-LARG * 0.3 + z * 1.4, 0.2, -COMP * 0.25), "armado": false, "tipo": ""})
	return p


func _ready() -> void:
	_sala()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var q := PhysicsRayQueryParameters3D.create(alcapao + Vector3(0, 2.0, 0), alcapao + Vector3(0, -2.0, 0))
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		alcapao.y = (h.position as Vector3).y
	_poe_alcapao()


func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.16, 0.15, 0.14)  # concreto velho e úmido
		_mat.roughness = 1.0
	return _mat


func _caixa(tam: Vector3, pos: Vector3, solida: bool = true) -> void:
	if solida:
		var c := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var f := BoxShape3D.new()
		f.size = tam
		cs.shape = f
		c.add_child(cs)
		add_child(c)
		c.global_position = pos
	if Rede.servidor_sem_tela:
		return
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos


func _sala() -> void:
	var s: Vector3 = sala
	_caixa(Vector3(LARG, 0.4, COMP), s - Vector3(0, 0.2, 0))                       # chão
	_caixa(Vector3(LARG, 0.4, COMP), s + Vector3(0, ALTO + 0.2, 0))                # teto
	_caixa(Vector3(0.4, ALTO, COMP), s + Vector3(-LARG / 2 - 0.2, ALTO / 2, 0))
	_caixa(Vector3(0.4, ALTO, COMP), s + Vector3(LARG / 2 + 0.2, ALTO / 2, 0))
	_caixa(Vector3(LARG, ALTO, 0.4), s + Vector3(0, ALTO / 2, -COMP / 2 - 0.2))
	_caixa(Vector3(LARG, ALTO, 0.4), s + Vector3(0, ALTO / 2, COMP / 2 + 0.2))
	# prateleiras velhas e caixas pelo chão
	_caixa(Vector3(0.5, 1.8, 2.4), s + Vector3(LARG / 2 - 0.3, 0.9, -1.0))
	_caixa(Vector3(0.6, 0.5, 0.6), s + Vector3(-1.0, 0.25, 1.2))
	_caixa(Vector3(0.5, 0.4, 0.5), s + Vector3(-0.4, 0.2, 1.6))
	# escada encostada na parede do fundo (+z): pisar no pé dela sobe
	for d in 7:
		_caixa(Vector3(0.7, 0.05, 0.08), s + Vector3(-LARG / 2 + 0.8, 0.3 + d * 0.33, COMP / 2 - 0.15), false)
	_caixa(Vector3(0.06, ALTO, 0.06), s + Vector3(-LARG / 2 + 0.45, ALTO / 2, COMP / 2 - 0.15), false)
	_caixa(Vector3(0.06, ALTO, 0.06), s + Vector3(-LARG / 2 + 1.15, ALTO / 2, COMP / 2 - 0.15), false)
	var sobe := _area(Vector3(1.0, 1.6, 0.9), s + Vector3(-LARG / 2 + 0.8, 0.8, COMP / 2 - 0.5))
	sobe.body_entered.connect(_sobe)
	var bau := Bau.new()
	bau.name = "Bau_porao"
	bau.raid = true
	add_child(bau)
	bau.global_position = s + Vector3(LARG / 2 - 0.9, 0.0, COMP / 2 - 0.9)
	if not Rede.servidor_sem_tela:  # lâmpada fria pendurada que falha (PostesPiscam faz piscar)
		var luz := OmniLight3D.new()
		luz.light_color = Color(0.8, 0.9, 1.0)
		luz.omni_range = 5.5
		luz.light_energy = 0.7
		luz.shadow_enabled = false
		luz.set_meta("jeito", "fria")
		luz.add_to_group("treme")
		add_child(luz)
		luz.global_position = s + Vector3(0.5, ALTO - 0.3, -0.5)


func _area(tam: Vector3, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_mask = 2  # jogadores
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = tam
	cs.shape = f
	a.add_child(cs)
	add_child(a)
	a.global_position = pos
	return a


func _poe_alcapao() -> void:
	_alcapao_area = _area(Vector3(0.8, 1.0, 0.8), alcapao + Vector3(0, 0.5, 0))
	_alcapao_area.body_entered.connect(_desce)
	if Rede.servidor_sem_tela:
		return
	var buraco := MeshInstance3D.new()  # boca preta no chão e a tampa aberta encostada
	var q := BoxMesh.new()
	q.size = Vector3(0.9, 0.02, 0.9)
	buraco.mesh = q
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color(0.01, 0.01, 0.01)
	preto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	buraco.material_override = preto
	add_child(buraco)
	buraco.global_position = alcapao + Vector3(0, 0.02, 0)
	var tampa := MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(0.9, 0.9, 0.05)
	tampa.mesh = t
	tampa.material_override = _material()
	add_child(tampa)
	tampa.global_position = alcapao + Vector3(0, 0.45, -0.48)


func _pode(corpo: Node3D) -> Jogador:
	var j := corpo as Jogador
	if j == null or not j.local or j.vida <= 0 or j.carro != null:
		return null
	var agora: int = Engine.get_physics_frames()  # quadros de física (o relógio de parede corre diferente nos testes)
	if agora < int(j.get_meta("porao_t", 0)):
		return null
	j.set_meta("porao_t", agora + int(ESPERA * Engine.physics_ticks_per_second))
	return j


func _desce(corpo: Node3D) -> void:
	var j := _pode(corpo)
	if j == null:
		return
	j.global_position = sala + Vector3(-LARG / 2 + 0.8, 0.1, COMP / 2 - 1.8)  # ao pé da escada, fora da área de subir
	j.velocity = Vector3.ZERO
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and principal.controles:
		principal.controles.aviso("PORÃO — silêncio...")


func _sobe(corpo: Node3D) -> void:
	var j := _pode(corpo)
	if j == null:
		return
	var fora: Vector3 = alcapao + _rumo * 1.1 + Vector3(0, 0.15, 0)
	j.global_position = fora
	j.velocity = Vector3.ZERO
