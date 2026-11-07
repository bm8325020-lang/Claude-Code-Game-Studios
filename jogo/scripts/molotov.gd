# Coquetel molotov (07/11, ideia aprovada do dono): onde cai vira fogo por DURA s; zumbi a até RAIO m queima
# (DANO a cada 0,5 s, quem jogou leva o crédito). Jogador também queima se entrar (o Fogo cuida disso).
class_name Molotov
extends Node3D

const DURA: float = 12.0
const RAIO: float = 2.5
const DANO: int = 18
var dono: Node = null
var _t: float = 0.0
var _tick: float = 0.0


func _ready() -> void:
	var f := Fogo.new()
	f.tamanho = 1.0
	add_child(f)


func _process(dt: float) -> void:
	_t += dt
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.5
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			for n: Node in get_tree().get_nodes_in_group("zumbis"):
				var z := n as Zumbi
				if z and z.vida > 0 and z.global_position.distance_to(global_position) < RAIO:
					z.levar_golpe(DANO, (z.global_position - global_position).normalized() * 0.4, dono)
	if _t >= DURA:
		queue_free()
