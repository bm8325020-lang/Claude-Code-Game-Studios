# Peça da base (14/11, dono: item 2 "base que cresce"): o que o jogador monta na mata com o que juntou.
# Fogueira -> barraca -> cabana; e em volta: cerca de estacas, torre de vigia, baú da base e horta.
# Feita na mão (Receitas "mao"), colocada à frente (Jogador.usar_espaco -> main.pede_peca). Nasce pelo spawner da base
# (todos os aparelhos veem) e o servidor guarda tudo em user://base.cfg (volta quando o jogo abre de novo).
# Desenho de blocos lisos (combina com o Estilo); a cerca leva dano de zumbi colado nela (servidor).
class_name Peca
extends Node3D

const TIPOS: Array[String] = ["barraca", "estacas", "torre", "bau_base", "horta", "cabana"]
const VIDA_ESTACAS: int = 250
const DANO_ZUMBI: int = 6           # por zumbi colado, a cada segundo
const HORTA_VOLTA: float = 150.0    # s até a horta dar fruta de novo
const MADEIRA := Color(0.42, 0.3, 0.2)
const LONA := Color(0.36, 0.42, 0.28)

var tipo: String = "barraca"
var dono: String = ""                # nick de quem montou (barraca: renasce nela)
var vida: int = VIDA_ESTACAS
var colhida_t: float = -HORTA_VOLTA  # horta: quando deu fruta pela última vez (s de jogo)
var bau: Bau                         # bau_base: o baú de verdade (filho)
var _t: float = 0.0


func _ready() -> void:
	add_to_group("pecas_base")
	add_to_group("base_" + tipo)
	match tipo:
		"barraca":
			_barraca()
		"estacas":
			_estacas()
		"torre":
			_torre()
		"bau_base":
			bau = Bau.new()
			bau.name = "Bau"
			bau.de_faccao = true  # começa vazio e não reenche
			bau.da_base = true    # qualquer um abre e guarda
			add_child(bau)
		"horta":
			_horta()
		"cabana":
			_cabana()
	set_process(tipo == "estacas")


func _bloco(pos: Vector3, tam: Vector3, cor: Color, corpo: bool = false, rot: Vector3 = Vector3.ZERO, desenha: bool = true) -> void:
	if desenha and not Rede.servidor_sem_tela:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = tam
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor
		mat.roughness = 1.0
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		add_child(mi)
	if corpo:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var f := BoxShape3D.new()
		f.size = tam
		cs.shape = f
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		add_child(sb)


func _cama(pos: Vector3) -> void:
	var c := Node3D.new()  # Jogador.cama_perto: deitar aqui dorme e passa a noite
	c.add_to_group("camas_refugio")
	c.position = pos
	add_child(c)
	_bloco(pos + Vector3(0, 0.06, 0), Vector3(0.8, 0.12, 1.9), Color(0.25, 0.32, 0.45))


func _barraca() -> void:
	if not Rede.servidor_sem_tela:
		var mi := MeshInstance3D.new()  # lona em V (prisma), aberta na frente
		var m := PrismMesh.new()
		m.size = Vector3(2.2, 1.4, 2.4)
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = LONA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.position = Vector3(0, 0.7, 0)
		add_child(mi)
	_cama(Vector3(0, 0, 0))


func _estacas() -> void:
	for k in 7:  # troncos fincados com a ponta para fora
		var x: float = -1.5 + k * 0.5
		_bloco(Vector3(x, 1.0, 0), Vector3(0.22, 2.0, 0.22), MADEIRA.darkened(0.1 * (k % 2)), false, Vector3(0.25, 0, 0))
	_bloco(Vector3(0, 1.0, 0.0), Vector3(3.4, 2.0, 0.5), MADEIRA, true, Vector3.ZERO, false)  # corpo sem desenho
	_bloco(Vector3(0, 0.7, -0.15), Vector3(3.4, 0.12, 0.1), MADEIRA.darkened(0.3))


func _torre() -> void:
	for x: float in [-1.1, 1.1]:
		for z: float in [-1.1, 1.1]:
			_bloco(Vector3(x, 2.1, z), Vector3(0.2, 4.2, 0.2), MADEIRA, true)
	_bloco(Vector3(0, 4.1, 0), Vector3(2.6, 0.2, 2.6), MADEIRA.lightened(0.1), true)
	for k in 3:  # parapeito (o lado +X fica aberto para a escada)
		var lados: Array = [[Vector3(0, 4.7, -1.25), Vector3(2.6, 0.9, 0.1)], [Vector3(0, 4.7, 1.25), Vector3(2.6, 0.9, 0.1)],
			[Vector3(-1.25, 4.7, 0), Vector3(0.1, 0.9, 2.6)]]
		_bloco(lados[k][0], lados[k][1], MADEIRA.darkened(0.15), true)
	var sb := Subida.new()  # a Subida lê os pontos no _ready: preenche antes de pôr na árvore
	sb.beira = 1.0
	var lado: Vector3 = global_basis.x.normalized()
	sb.lado = lado
	sb.baixo = global_position + lado * 1.8
	sb.cima = global_position + Vector3(0, 4.2, 0)
	add_child(sb)


func _horta() -> void:
	_bloco(Vector3(0, 0.12, 0), Vector3(2.4, 0.24, 1.4), Color(0.28, 0.19, 0.12))
	for k in 6:
		_bloco(Vector3(-0.9 + (k % 3) * 0.9, 0.4, -0.35 + (k / 3) * 0.7), Vector3(0.45, 0.35, 0.45), Color(0.3, 0.55, 0.25))


func _cabana() -> void:
	var w := Vector2(4.2, 3.6)  # chão 4,2 x 3,6 m; porta na frente (+Z)
	_bloco(Vector3(0, 0.1, 0), Vector3(w.x, 0.2, w.y), MADEIRA.darkened(0.2), true)
	_bloco(Vector3(0, 1.4, -w.y * 0.5), Vector3(w.x, 2.6, 0.2), MADEIRA, true)
	_bloco(Vector3(-w.x * 0.5, 1.4, 0), Vector3(0.2, 2.6, w.y), MADEIRA, true)
	_bloco(Vector3(w.x * 0.5, 1.4, 0), Vector3(0.2, 2.6, w.y), MADEIRA, true)
	for x: float in [-1.4, 1.4]:  # frente com o vão da porta no meio
		_bloco(Vector3(x, 1.4, w.y * 0.5), Vector3(1.4, 2.6, 0.2), MADEIRA, true)
	_bloco(Vector3(0, 2.35, w.y * 0.5), Vector3(1.4, 0.7, 0.2), MADEIRA, true)
	for s: float in [-1.0, 1.0]:  # telhado de duas águas
		_bloco(Vector3(s * w.x * 0.26, 3.05, 0), Vector3(w.x * 0.58, 0.14, w.y + 0.6), Color(0.3, 0.22, 0.17), true, Vector3(0, 0, -s * 0.5))
	_cama(Vector3(-1.2, 0.2, -0.6))


## Horta pronta para colher? (Jogador.coleta_perto)
func horta_pronta() -> bool:
	return tipo == "horta" and Time.get_ticks_msec() / 1000.0 - colhida_t >= HORTA_VOLTA


func _process(dt: float) -> void:  # só a cerca: zumbi colado vai quebrando (servidor)
	_t -= dt
	if _t > 0.0 or (multiplayer.has_multiplayer_peer() and not multiplayer.is_server()):
		return
	_t = 1.0
	for n: Node in get_tree().get_nodes_in_group("zumbis"):
		var z := n as Zumbi
		if z == null or z.vida <= 0 or z.amigavel or z.dono != null:
			continue
		var l: Vector3 = to_local(z.global_position)
		if absf(l.x) < 1.9 and absf(l.z) < 1.1:
			vida -= DANO_ZUMBI
	if vida <= 0:
		var principal := get_tree().get_first_node_in_group("principal")
		if principal:
			principal.base_mudou()
		queue_free()
