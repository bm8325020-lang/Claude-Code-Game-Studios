# População de zumbis em volta de quem está na cidade (05/11, mods de zumbi do GTA V: GTAZ "orçamento + fila de
# nascimento", Simple Zombies "nunca nasce na tela"). Além dos zumbis fixos dos pontos, o servidor mantém uns
# ALVO_PERTO em volta de cada jogador: um grupo de 2-4 por vez (fila), achado na malha de navegação (nunca no ar),
# entre NASCE_MIN e NASCE_MAX de todo mundo e escondido atrás de prédio para quem está mais perto. Teto geral
# ORCAMENTO; quem ficou longe de todos sem alvo some; morto não levanta (o corpo some como o da horda).
class_name Populacao
extends RefCounted

const ORCAMENTO: int = 70          # zumbis no mundo (todos) antes de parar de soltar
const ALVO_PERTO: int = 12         # zumbis vivos a até PERTO de cada jogador
const PERTO: float = 110.0
const NASCE_MIN: float = 65.0      # nunca mais perto que isso de ninguém (GTAZ: 75-80 m)
const NASCE_MAX: float = 130.0
const SOME: float = 200.0          # do ambiente, sem alvo e longe de todos: some (GTAZ: 300 m)
const A_CADA: float = 4.0          # s entre um grupo e outro
const COMECA: float = 90.0         # s de jogo até o primeiro grupo (o mundo já vem com os fixos)

var _t: float = COMECA
var _rng := RandomNumberGenerator.new()


func passa(m: Node, dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = A_CADA
	if m.em_pvp() or m.bairro == null:
		return
	var na_cidade: Array = m.jogadores.get_children().filter(func(j: Jogador) -> bool:
		return j.vida > 0 and not j.segura and dentro(j.global_position))
	var zs: Array = m.zumbis.get_children()
	for z: Zumbi in zs:  # some quem ficou para trás
		if z.horda == Zumbi.AMBIENTE and z.alvo == null and z.vida > 0 \
				and not m.jogadores.get_children().any(func(o: Jogador) -> bool: return o.global_position.distance_to(z.global_position) < SOME):
			z.queue_free()
	if zs.size() >= orcamento() or na_cidade.is_empty():
		return
	var j: Jogador = null  # quem tem menos zumbis perto ganha o grupo
	var menos: int = ALVO_PERTO
	for o: Jogador in na_cidade:
		var n: int = zs.filter(func(z: Zumbi) -> bool: return z.vida > 0 and z.global_position.distance_to(o.global_position) < PERTO).size()
		if n < menos:
			menos = n
			j = o
	if j:
		solta(m, j, mini(_rng.randi_range(2, 4), orcamento() - zs.size()))


## Teto pela qualidade (anti-lag 06/11): celular fraco segura menos zumbis vivos ao mesmo tempo.
static func orcamento() -> int:
	return [35, 50, ORCAMENTO, ORCAMENTO][clampi(int(Config.v.qualidade), 0, 3)] if not Rede.servidor_sem_tela else ORCAMENTO


## Solta `n` zumbis perto de `j`, fora da vista. Devolve se achou lugar.
func solta(m: Node, j: Jogador, n: int) -> bool:
	var mapa: RID = (m as Node3D).get_world_3d().navigation_map
	var espaco: PhysicsDirectSpaceState3D = (m as Node3D).get_world_3d().direct_space_state
	for tentativa in 8:
		var ang: float = _rng.randf() * TAU
		var quer: Vector3 = j.global_position + Vector3(sin(ang), 0, cos(ang)) * _rng.randf_range(NASCE_MIN, NASCE_MAX)
		# 08/11 horda travando: o ponto mais perto na malha custa ~3 ms (varre a malha da cidade); antes dele, o que é
		# barato descarta (fora da cidade, perto de alguém, à vista)
		if not dentro(quer) or _perto_de_alguem(m, quer, NASCE_MIN - 8.0) or _a_vista(espaco, j, quer):
			continue
		var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, quer)
		if Vector2(p.x - quer.x, p.z - quer.z).length() > 8.0 or not dentro(p):
			continue  # fora da malha (rio, dentro de prédio) ou fora da cidade
		if _perto_de_alguem(m, p, NASCE_MIN) or _a_vista(espaco, j, p):
			continue  # dá para ver de onde ele está: nasceria na tela
		for k in n:
			m.spawner_zumbis.spawn({"pos": p + Vector3(_rng.randf_range(-3, 3), 0.1, _rng.randf_range(-3, 3)), "horda": Zumbi.AMBIENTE})
		return true
	return false


static func _perto_de_alguem(m: Node, p: Vector3, dist: float) -> bool:
	return m.jogadores.get_children().any(func(o: Jogador) -> bool: return o.global_position.distance_to(p) < dist)


static func _a_vista(espaco: PhysicsDirectSpaceState3D, j: Jogador, p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(j.global_position + Vector3(0, 1.6, 0), p + Vector3(0, 1.2, 0), 1)
	return espaco.intersect_ray(q).is_empty()


## Está dentro da cidade (Raven Creek)? A pista de teste e o resto ficam de fora.
static func dentro(p: Vector3) -> bool:
	var l: Vector3 = p - Bairro.ORIGEM
	return absf(l.x) < Bairro.TAMANHO * 0.5 - 10.0 and absf(l.z) < Bairro.TAMANHO * 0.5 - 10.0
