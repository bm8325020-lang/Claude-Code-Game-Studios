# Sinalizador vermelho (07/11, ideia aprovada do dono): jogado no chão, acende vermelho e faz barulho por DURA s —
# os zumbis vão até ele (tira o bando do caminho). Barulho só no servidor (é quem pensa os zumbis).
class_name Sinalizador
extends Node3D

const DURA: float = 25.0
const RAIO: float = 45.0
var _t: float = 0.0
var _chama_t: float = 0.0
var _luz: OmniLight3D


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.025
	c.height = 0.22
	c.radial_segments = 8
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.1, 0.08)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.15, 0.1)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.rotation_degrees.z = 80
	mi.position.y = 0.03
	add_child(mi)
	if not Rede.servidor_sem_tela:
		_luz = OmniLight3D.new()
		_luz.light_color = Color(1.0, 0.18, 0.12)
		_luz.omni_range = 12.0
		_luz.position.y = 0.4
		add_child(_luz)


func _process(dt: float) -> void:
	_t += dt
	if _luz:
		_luz.light_energy = 3.0 + sin(_t * 23.0) * 0.6 + randf() * 0.5  # chama tremendo
	_chama_t -= dt
	if _chama_t <= 0.0:
		_chama_t = 2.0
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			Zumbi.barulho(get_tree(), global_position, RAIO)
	if _t >= DURA:
		queue_free()
