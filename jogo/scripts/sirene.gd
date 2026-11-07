# Sirene da cidade (07/11, ideia aprovada): toca DURA s num ponto; a cada 3 s o barulho chama os mortos num raio grande.
class_name Sirene
extends Node3D

const DURA: float = 40.0
const RAIO: float = 110.0
var _t: float = 0.0
var _chama: float = 0.0
var _som: AudioStreamPlayer3D


func _ready() -> void:
	if not Rede.servidor_sem_tela:
		_som = AudioStreamPlayer3D.new()
		var st: AudioStreamWAV = load("res://assets/sons/sirene.wav")
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = st.data.size() / 2
		_som.stream = st
		_som.unit_size = 60.0
		_som.max_distance = 400.0
		_som.position.y = 6.0
		add_child(_som)
		_som.play()


func _process(dt: float) -> void:
	_t += dt
	_chama -= dt
	if _chama <= 0.0:
		_chama = 3.0
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			Zumbi.barulho(get_tree(), global_position, RAIO)
	if _t >= DURA:
		queue_free()
