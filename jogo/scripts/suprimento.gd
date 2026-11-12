# Caixa de suprimento que cai do céu (06/11, engenharia reversa do Simple Zombies do GTA V com Rea + Ghidra: "Crate
# Drop" com marca no mapa). Mecânica recriada aqui, nada do código do mod: de tempos em tempos o servidor larga uma caixa
# militar com loot de raid perto de um jogador na cidade, com fumaça vermelha subindo (dá para ver de longe), aviso para
# todos com o lado e a distância, marca no minimapa (grupo "suprimento") e um estrondo que chama os zumbis em volta.
# A caixa some sozinha como um saco (Bau.saco).
class_name Suprimento
extends RefCounted

const PRIMEIRA: float = 480.0     # s de jogo até a primeira
const INTERVALO: float = 600.0    # s entre uma e outra
const LONGE_MIN: float = 90.0     # m do jogador escolhido
const LONGE_MAX: float = 170.0
const CHAMA: float = 70.0         # m: zumbis que ouvem a queda e vão ver

var _t: float = PRIMEIRA
## 07/11 (E6, rádio com chamados): pedido de socorro pelo rádio. Às vezes é verdade (sobrevivente cercado: zumbis em
## volta de um baú com loot de raid que ele deixou); às vezes é EMBOSCADA dos Corvos (o rádio é isca: saqueadores
## armados esperando em volta da caixa). Mesma marca no mapa (fumaça e grupo "suprimento"), mesma voz no rádio.
const CHAMADO_PRIMEIRA: float = 240.0
const CHAMADO_INTERVALO: float = 540.0
const CHAMADO_ZUMBIS: int = 5
const CHAMADO_CORVOS: int = 3
const EMBOSCADA: float = 0.4      # chance de o socorro ser armadilha dos Corvos
var _t_chamado: float = CHAMADO_PRIMEIRA
var _rng := RandomNumberGenerator.new()


func passa(m: Node, dt: float) -> void:
	_t_chamado -= dt
	if _t_chamado <= 0.0:
		_t_chamado = CHAMADO_INTERVALO if chamado(m) else 30.0
	_t -= dt
	if _t > 0.0:
		return
	_t = INTERVALO if solta(m) else 30.0


## Pedido de socorro pelo rádio (ver CHAMADO_*). Devolve se achou lugar.
func chamado(m: Node, armadilha: int = -1) -> bool:
	var pj: Array = _lugar(m)
	if pj.is_empty():
		return false
	var p: Vector3 = pj[0]
	var d := {"saco": Loot.sorteia(_rng, false, true), "pos": p + Vector3(0, 0.05, 0), "caixa": true}
	if multiplayer_ativo(m):
		m.spawner_itens.spawn(d)
	else:
		m.soltos.add_child(m._cria_item_solto(d))
	var corvos: bool = _rng.randf() < EMBOSCADA if armadilha < 0 else armadilha == 1
	for k in (CHAMADO_CORVOS if corvos else CHAMADO_ZUMBIS):
		var a: float = TAU * k / 5.0 + _rng.randf() * 0.5
		var q: Vector3 = p + Vector3(cos(a), 0.1, sin(a)) * _rng.randf_range(4.0, 9.0)
		if corvos:
			m.zumbi_na_fila({"pos": q, "armado": true, "tipo": "corvo", "de_raid": true})
		else:
			m.zumbi_na_fila({"pos": q, "horda": Zumbi.DO_MORTO})  # não renascem
	var rumo: Vector3 = p - (pj[1] as Node3D).global_position
	m.aviso_todos.rpc("RÁDIO: \"Socorro! Estou cercado ao %s, uns %d m... tem suprimento aqui!\"" % [Horda.lado(rumo), int(rumo.length() / 10.0) * 10])
	return true


## [ponto na rua perto de um jogador vivo, o jogador] ou [] (mesma regra da caixa).
func _lugar(m: Node) -> Array:
	if m.em_pvp() or m.bairro == null:
		return []
	var vivos: Array = m.jogadores.get_children().filter(func(j: Jogador) -> bool:
		return j.vida > 0 and Populacao.dentro(j.global_position))
	if vivos.is_empty():
		return []
	var j: Jogador = vivos[_rng.randi() % vivos.size()]
	var mapa: RID = (m as Node3D).get_world_3d().navigation_map
	for tentativa in 10:
		var ang: float = _rng.randf() * TAU
		var quer: Vector3 = j.global_position + Vector3(sin(ang), 0, cos(ang)) * _rng.randf_range(LONGE_MIN, LONGE_MAX)
		var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, quer)
		if Vector2(p.x - quer.x, p.z - quer.z).length() <= 6.0 and Populacao.dentro(p):
			return [p, j]
	return []


## Larga uma caixa perto de um jogador vivo na cidade. Devolve se achou lugar.
func solta(m: Node) -> bool:
	if m.em_pvp() or m.bairro == null:
		return false
	var vivos: Array = m.jogadores.get_children().filter(func(j: Jogador) -> bool:
		return j.vida > 0 and Populacao.dentro(j.global_position))
	if vivos.is_empty():
		return false
	var j: Jogador = vivos[_rng.randi() % vivos.size()]
	var mapa: RID = (m as Node3D).get_world_3d().navigation_map
	for tentativa in 10:
		var ang: float = _rng.randf() * TAU
		var quer: Vector3 = j.global_position + Vector3(sin(ang), 0, cos(ang)) * _rng.randf_range(LONGE_MIN, LONGE_MAX)
		var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, quer)
		if Vector2(p.x - quer.x, p.z - quer.z).length() > 6.0 or not Populacao.dentro(p):
			continue  # dentro de prédio, no rio ou fora da cidade
		var loot: Array = Loot.sorteia(_rng, false, true)  # loot de raid
		var d := {"saco": loot, "pos": p + Vector3(0, 0.05, 0), "caixa": true}
		if multiplayer_ativo(m):
			m.spawner_itens.spawn(d)
		else:
			m.soltos.add_child(m._cria_item_solto(d))
		Zumbi.barulho(m.get_tree(), p, CHAMA)
		var rumo: Vector3 = p - j.global_position
		m.aviso_todos.rpc("Suprimento caindo ao %s, uns %d m!" % [Horda.lado(rumo), int(rumo.length() / 10.0) * 10])
		return true
	return false


static func multiplayer_ativo(m: Node) -> bool:
	return m.multiplayer.has_multiplayer_peer()
