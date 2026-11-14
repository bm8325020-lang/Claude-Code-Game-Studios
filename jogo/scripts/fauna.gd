# Solta e recolhe os bichos da floresta em volta dos jogadores (13/11). Servidor/solo; poucos por vez (anti-lag):
# nascem fora da vista (45-75 m), na mata (longe de trilha e água), e somem a mais de SOME m de todos.
# Lobo só depois de LOBO_DEPOIS s de jogo (o começo não pode ser cerco de lobo) e mais de noite.
class_name Fauna
extends Node

const CADA: float = 2.0
const MAX_DIA: int = 5
const MAX_NOITE: int = 8
const SOME: float = 130.0
const LOBO_DEPOIS: float = 240.0
var principal: Node
var _t: float = 3.0
var _jogo: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(dt: float) -> void:
	_jogo += dt
	_t -= dt
	if _t > 0.0 or principal == null or principal.bairro == null or not multiplayer.is_server():
		return
	_t = CADA
	if principal.has_method("_testando") and principal._testando() and not get_meta("no_teste", false):
		return  # testes que não pedem bicho ficam sem
	var jogs: Array = principal.get_tree().get_nodes_in_group("jogadores").filter(func(j: Node) -> bool: return (j as Jogador).vida > 0)
	if jogs.is_empty():
		return
	var bichos: Array = principal.get_tree().get_nodes_in_group("bichos")
	for b: Bicho in bichos:  # some longe de todos; acorda quem dormiu e alguém chegou
		var d: float = INF
		for j: Jogador in jogs:
			d = minf(d, j.global_position.distance_to(b.global_position))
		if d > SOME:
			b.queue_free()
		elif d < Bicho.LONGE_DORME and not b.is_physics_processing() and not b._morto:
			b.set_physics_process(true)
	var noite: float = Ciclo.noite_de(principal.get_tree())
	if bichos.size() >= (MAX_NOITE if noite > 0.5 else MAX_DIA):
		return
	var j: Jogador = jogs[_rng.randi() % jogs.size()]
	var r: float = _rng.randf()
	var tipo: String = "cervo" if r < 0.45 else ("urso" if r < 0.55 else "lobo")  # urso é raro
	if tipo != "cervo" and _jogo < LOBO_DEPOIS:
		tipo = "cervo"
	var p: Vector3 = _ponto(j.global_position)
	if not p.is_finite():
		return
	var n: int = _rng.randi_range(2, 3 if noite < 0.5 else 4) if tipo == "lobo" else 1
	for k in n:  # pelo spawner: aparece em todos os aparelhos da sala
		principal.spawner_bichos.spawn({"tipo": tipo, "pos": p + Vector3(_rng.randf_range(-3, 3), 0.5, _rng.randf_range(-3, 3))})


## Ponto da mata a 45-75 m de `de` (fora de trilha, água e prédio); INF se não achou.
func _ponto(de: Vector3) -> Vector3:
	var b: Bairro = principal.bairro
	for tent in 8:
		var a: float = _rng.randf() * TAU
		var p: Vector3 = de + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(45.0, 75.0)
		var l := Vector2(p.x - Bairro.ORIGEM.x, p.z - Bairro.ORIGEM.z)
		if absf(l.x) > Bairro.TAMANHO * 0.47 or absf(l.y) > Bairro.TAMANHO * 0.47:
			continue
		if b._perto_de_rua(l, 3.0) or b.beira_dagua(p) or b.casa_em(p) != "":
			continue
		return Vector3(p.x, Bairro.ORIGEM.y + b.altura(l) + 0.3, p.z)
	return Vector3.INF
