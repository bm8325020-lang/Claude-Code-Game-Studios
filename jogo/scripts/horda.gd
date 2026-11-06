# Horda andarilha (05/11, dos mods de zumbi do GTA V: GTAZ). De tempos em tempos (e às vezes quando a noite cai) nasce
# um bando fora da vista de todos, do lado de um jogador, e atravessa a área dele andando em bloco atrás de um líder
# (maior, mais vida, não toma dano enquanto houver outro membro vivo). Se um membro acha alguém, os outros vão junto.
# Só no servidor; os zumbis nascem pelo spawner como os outros e o corpo some sozinho (Zumbi.CORPO_HORDA).
class_name Horda
extends RefCounted

const PRIMEIRA: float = 600.0       # s de jogo até a primeira
const INTERVALO: float = 420.0      # s entre uma e outra
const TAMANHO: int = 8              # membros fora o líder
const TAMANHO_NOITE: int = 12
const NOITE_CHANCE: float = 0.5     # ao cair a noite
const NASCE_LONGE: float = 75.0     # m do jogador escolhido
const LONGE_DE_TODOS: float = 55.0  # ninguém mais perto que isso de onde ela nasce
const ATRAVESSA: float = 90.0       # o fim da marcha fica isso depois do jogador
const PASSO: float = 25.0           # m à frente do líder a cada empurrão
const EMPURRA: float = 4.0          # s entre empurrões
const ESPALHA: float = 6.0          # m: cada um mantém o lugar dele em volta do líder
const ATRASADO: float = 20.0        # m do líder: volta para perto
const DURA: float = 360.0           # s; depois disso (ou no fim da marcha) quem está longe de todos some
const SOME_LONGE: float = 90.0

var ativas: Dictionary = {}  # id -> {rumo, fim, t, empurra}
var _t: float = PRIMEIRA
var _id: int = 0
var _noite_antes: bool = false
var _rng := RandomNumberGenerator.new()


func passa(m: Node, dt: float) -> void:
	if m.em_pvp():
		return
	var noite: bool = Ciclo.noite_de(m.get_tree()) > 0.5
	var caiu_noite: bool = noite and not _noite_antes and _t < PRIMEIRA - 60.0  # começar de noite não conta
	_noite_antes = noite
	_t -= dt
	if ativas.is_empty() and (_t <= 0.0 or (caiu_noite and _rng.randf() < NOITE_CHANCE)):
		_t = INTERVALO if solta(m, TAMANHO_NOITE if noite else TAMANHO) else 30.0
	for id: int in ativas.keys():
		_cuida(m, id, dt)


## Solta uma horda do lado de um jogador vivo, fora da vista de todos. Devolve se conseguiu lugar.
func solta(m: Node, n: int) -> bool:
	var vivos: Array = m.jogadores.get_children().filter(func(j: Jogador) -> bool: return j.vida > 0 and not j.segura)
	if vivos.is_empty():
		return false
	var j: Jogador = vivos[_rng.randi() % vivos.size()]
	var mapa: RID = (m as Node3D).get_world_3d().navigation_map
	for tentativa in 10:
		var ang: float = _rng.randf() * TAU
		var quer: Vector3 = j.global_position + Vector3(sin(ang), 0, cos(ang)) * NASCE_LONGE
		if vivos.any(func(o: Jogador) -> bool: return o.global_position.distance_to(quer) < LONGE_DE_TODOS - 8.0):
			continue  # barato antes do ponto na malha (~3 ms cada, varre a malha da cidade)
		var p: Vector3 = NavigationServer3D.map_get_closest_point(mapa, quer)
		if Vector2(p.x - quer.x, p.z - quer.z).length() > 8.0:
			continue  # fora da malha (rio, dentro de prédio)
		if vivos.any(func(o: Jogador) -> bool: return o.global_position.distance_to(p) < LONGE_DE_TODOS):
			continue
		var rumo: Vector3 = j.global_position - p
		rumo.y = 0.0
		rumo = rumo.normalized()
		_id += 1
		ativas[_id] = {"rumo": rumo, "fim": j.global_position + rumo * ATRAVESSA, "t": 0.0, "empurra": 0.0}
		for k in n + 1:
			var d := {"pos": p + Vector3(0, 0.1, 0), "horda": _id}
			if k == 0:
				d.lider = true
				d.tipo = "zumbi_policial"
			else:
				d.pos += Vector3(_rng.randf_range(-4.0, 4.0), 0, _rng.randf_range(-4.0, 4.0))
			m.spawner_zumbis.spawn(d)
		m.aviso_todos.rpc_id(j.get_multiplayer_authority(), "Uma horda vem do %s!" % lado(-rumo))
		return true
	return false


## Nome do lado para onde aponta `v` (o norte da cidade é -Z).
static func lado(v: Vector3) -> String:
	if absf(v.z) >= absf(v.x):
		return "NORTE" if v.z < 0.0 else "SUL"
	return "LESTE" if v.x > 0.0 else "OESTE"


func _cuida(m: Node, id: int, dt: float) -> void:
	var h: Dictionary = ativas[id]
	h.t += dt
	var vivos: Array = m.zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.horda == id and z.vida > 0)
	if vivos.is_empty():
		ativas.erase(id)
		return
	var lideres: Array = vivos.filter(func(z: Zumbi) -> bool: return z.lider)
	var centro: Vector3 = (lideres[0] as Zumbi).global_position if not lideres.is_empty() else (vivos[0] as Zumbi).global_position
	for z: Zumbi in vivos:
		z.imune = z.lider and vivos.size() > 1
	var falta: Vector3 = h.fim - centro
	falta.y = 0.0
	if h.t > DURA or falta.length() < 6.0:  # acabou: some quem está longe de todos
		var jogs: Array = m.jogadores.get_children()
		for z: Zumbi in vivos:
			if z.alvo == null and not jogs.any(func(o: Jogador) -> bool: return o.global_position.distance_to(z.global_position) < SOME_LONGE):
				z.queue_free()
		return
	h.empurra -= dt
	if h.empurra > 0.0:
		return
	h.empurra = EMPURRA
	var achou: Jogador = null  # um membro achou alguém: todos vão
	for z: Zumbi in vivos:
		if z.alvo is Jogador:
			achou = z.alvo
			break
	var ponto: Vector3 = achou.global_position if achou else centro + h.rumo * minf(PASSO, falta.length())
	for z: Zumbi in vivos:
		if z.alvo != null:
			continue
		var meu: Vector3 = z.global_position - centro
		meu.y = 0.0
		z.marcha = centro if meu.length() > ATRASADO else ponto + meu.limit_length(ESPALHA)
