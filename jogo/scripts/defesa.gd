# Noite de defesa (14/11, dono: item 1 "ciclo do dia com objetivo"): de dia você sai para juntar e fazer raid; quando
# a noite cai e você tem base (Peca), vem uma onda contra o acampamento: zumbis de todos os lados, depois lobos e,
# mais para frente, saqueadores. Os zumbis são chamados para o meio da base (barulho) a noite inteira.
# Amanheceu com alguém vivo: o rádio larga uma caixa de suprimento (loot de raid) do lado da base. Cada noite
# segurada deixa a próxima mais pesada. Só no servidor; a conta das noites vai junto no save da base.
class_name Defesa
extends RefCounted

const ONDA_BASE: int = 6        # zumbis na primeira noite
const ONDA_MAIS: int = 2        # a mais por noite segurada
const ONDA_MAX: int = 18
const NASCE: float = 55.0       # m do meio da base
const PERTO: float = 150.0      # alguém vivo a menos disso da base para a onda vir
const CHAMA: float = 90.0       # m: o barulho que puxa os zumbis para a base
const CHAMA_CADA: float = 15.0
const LOBOS_DEPOIS: int = 1     # noites seguradas antes de vir lobo
const SAQUEADORES_DEPOIS: int = 2

var noites: int = 0
var em_onda: bool = false
var centro: Vector3 = Vector3.INF
var _noite: bool = false
var _chama_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Meio das peças da base (INF sem base).
static func meio(arvore: SceneTree) -> Vector3:
	var pecas: Array = arvore.get_nodes_in_group("pecas_base")
	if pecas.is_empty():
		return Vector3.INF
	var s := Vector3.ZERO
	for p: Node3D in pecas:
		s += p.global_position
	return s / pecas.size()


func passa(m: Node, dt: float) -> void:
	if m.em_pvp() or m.bairro == null:
		return
	var n: bool = Ciclo.noite_de(m.get_tree()) > 0.5
	if n and not _noite:
		_anuncia(m)
		cai_noite(m)
	elif not n and _noite:
		amanhece(m)
	_noite = n
	if em_onda:
		_chama_t -= dt
		if _chama_t <= 0.0:
			_chama_t = CHAMA_CADA
			Zumbi.barulho(m.get_tree(), centro, CHAMA)


## 14/11 (item 6): noite diferente avisa pelo rádio quando cai.
func _anuncia(m: Node) -> void:
	var clima: String = m.ciclo.clima if m.ciclo else ""
	if clima == "neblina_vermelha":
		m.aviso_todos.rpc("RÁDIO: \"Neblina vermelha subindo... hoje eles estão mais rápidos. Não sai sozinho.\"")
	elif clima == "lua_cheia":
		m.aviso_todos.rpc("RÁDIO: \"Lua cheia. Os lobos caçam em bando hoje... fica perto do fogo.\"")


func _vivos_perto(m: Node, p: Vector3) -> bool:
	for j: Jogador in m.jogadores.get_children():
		if j.vida > 0 and j.global_position.distance_to(p) < PERTO:
			return true
	return false


func _ponto(m: Node, ang: float, dist: float) -> Vector3:
	var quer: Vector3 = centro + Vector3(cos(ang), 0, sin(ang)) * dist
	var mapa: RID = (m as Node3D).get_world_3d().navigation_map
	var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, quer)
	return (p if p.is_finite() and p != Vector3.ZERO else quer) + Vector3(0, 0.1, 0)


func cai_noite(m: Node) -> bool:
	centro = meio(m.get_tree())
	if not centro.is_finite() or not _vivos_perto(m, centro):
		return false
	em_onda = true
	_chama_t = 20.0  # dá tempo de nascerem
	var n: int = mini(ONDA_BASE + ONDA_MAIS * noites, ONDA_MAX)
	for k in n:
		m.zumbi_na_fila({"pos": _ponto(m, TAU * k / n + _rng.randf() * 0.4, _rng.randf_range(NASCE, NASCE + 15.0)), "horda": Zumbi.DO_MORTO})
	if noites >= LOBOS_DEPOIS and m.spawner_bichos:
		var a: float = _rng.randf() * TAU
		for k in mini(2 + noites / 2, 4):
			m.spawner_bichos.spawn({"tipo": "lobo", "pos": _ponto(m, a + k * 0.15, NASCE) + Vector3(0, 0.4, 0)})
	if noites >= SAQUEADORES_DEPOIS:
		var a2: float = _rng.randf() * TAU
		for k in mini(1 + noites / 2, 4):
			m.zumbi_na_fila({"pos": _ponto(m, a2 + k * 0.2, NASCE + 5.0), "armado": true, "tipo": "corvo", "de_raid": true})
	m.aviso_todos.rpc("RÁDIO: \"Tem coisa vindo pro seu acampamento... segura a noite.\"")
	return true


func amanhece(m: Node) -> bool:
	if not em_onda:
		return false
	em_onda = false
	if not _vivos_perto(m, centro):
		return false
	noites += 1
	var d := {"saco": Loot.sorteia(_rng, false, true), "pos": _ponto(m, _rng.randf() * TAU, 6.0), "caixa": true}
	if Suprimento.multiplayer_ativo(m):
		m.spawner_itens.spawn(d)
	else:
		m.soltos.add_child(m._cria_item_solto(d))
	m.aviso_todos.rpc("RÁDIO: \"Vocês seguraram a noite %d. Larguei uma caixa do lado do acampamento.\"" % noites)
	m.base_mudou()
	return true
