# Postes queimando (06/11, pegada de terror): de noite os postes mais perto do jogador acendem com lâmpada velha que
# pisca, falha e às vezes apaga de vez por uns segundos. Só POOL luzes (OmniLight sem sombra) andam de poste em poste:
# o celular não aguenta uma luz por poste. Metade dos postes está morta (sorteio pelo lugar).
class_name PostesPiscam
extends Node

const POOL: int = 4
const PERTO: float = 70.0      # m: só poste a essa distância acende
const A_CADA: float = 0.5      # s entre escolher os postes de novo

var principal: Node
var _luzes: Array[OmniLight3D] = []
var _fase: Array[float] = []
var _t: float = 0.0
var _tempo: float = 0.0


func _ready() -> void:
	if Rede.servidor_sem_tela:
		set_process(false)
		return
	for k in POOL:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.omni_range = 16.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_luzes.append(l)
		_fase.append(randf() * 100.0)


static func vivo(p: Vector3) -> bool:  # metade dos postes queimou
	return hash(Vector2i(roundi(p.x), roundi(p.z))) % 2 == 0


# brilho 0..1 da lâmpada velha no instante t (fase = jeito de cada uma)
static func brilho(t: float, fase: float) -> float:
	var ciclo: float = fmod(t + fase, 11.0)
	if ciclo > 9.0:
		return 0.0  # apagou de vez uns 2 s
	var b: float = 0.75 + 0.25 * sin(t * 37.0 + fase) * sin(t * 13.0)
	if fmod(t * 7.3 + fase, 1.0) < 0.12:
		b *= 0.1  # falha rápida
	return clampf(b, 0.0, 1.0)


func _process(dt: float) -> void:
	_tempo += dt
	var b: Bairro = principal.bairro if principal else null
	var cam := get_viewport().get_camera_3d()
	var noite: float = principal.ciclo.noite() if principal and principal.ciclo else 0.0
	if b == null or cam == null or b.lampadas.is_empty() or noite < 0.3:
		for l in _luzes:
			l.visible = false
		return
	_t -= dt
	if _t <= 0.0:
		_t = A_CADA
		var c: Vector3 = cam.global_position
		var perto: Array = []
		for p: Vector3 in b.lampadas:
			var d: float = p.distance_squared_to(c)
			if d < PERTO * PERTO and vivo(p):
				perto.append([d, p])
		perto.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		for k in POOL:
			_luzes[k].visible = k < perto.size()
			if k < perto.size():
				_luzes[k].global_position = perto[k][1]
	for k in POOL:
		if _luzes[k].visible:
			_luzes[k].light_energy = 2.2 * noite * brilho(_tempo, _fase[k])
