# Pistola de teste (modelo de blocos provisório). Tiro semiautomático na direção da mira (centro da tela),
# pente + reserva, recarga, dispersão (menor mirando), tiro na cabeça x2, clarão, rastro, coice e som.
# Quem atira manda o efeito para os outros aparelhos (rastro e clarão), o dano é calculado no atirador.
class_name Pistola
extends Node3D

const PENTE: int = 12
const RESERVA_INICIAL: int = 48
const DANO: int = 34
const CADENCIA: float = 0.22          # s entre tiros (semiautomática: um tiro por toque)
const RECARGA: float = 1.6
const ALCANCE: float = 80.0
const DISPERSAO_MIRA: float = 0.4     # graus mirando
const DISPERSAO_QUADRIL: float = 3.0  # graus sem mirar
const DISPERSAO_POR_TIRO: float = 1.2 # cresce a cada tiro e volta sozinha
const COICE: float = 1.3              # graus que a câmera sobe por tiro

var balas: int = PENTE
var reserva: int = RESERVA_INICIAL
var recarregando: bool = false
var dono: Jogador
var cano: Node3D                       # ponta do cano (de onde saem clarão e rastro)

var _espera: float = 0.0
var _recarga_t: float = 0.0
var _abertura: float = 0.0             # dispersão extra que cresce com tiros seguidos
var _som: AudioStreamPlayer3D
var _som_tiro: AudioStreamWAV
var _luz: OmniLight3D


func _ready() -> void:
	_monta_modelo()
	_som = AudioStreamPlayer3D.new()
	_som.max_db = 6.0
	add_child(_som)
	_som_tiro = _gera_estampido()
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1, 0.8, 0.45)
	_luz.omni_range = 4.0
	_luz.light_energy = 0.0
	cano.add_child(_luz)


# pistola de blocos: ferrolho, cano, empunhadura e gatilho
func _monta_modelo() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.16, 0.18)
	metal.metallic = 0.6
	metal.roughness = 0.4
	var cabo := StandardMaterial3D.new()
	cabo.albedo_color = Color(0.22, 0.17, 0.12)
	# eixo +Z = cano para a frente; empunhadura para -Y
	_bloco(Vector3(0, 0.035, 0.07), Vector3(0.032, 0.04, 0.2), metal)     # ferrolho
	_bloco(Vector3(0, 0.02, 0.18), Vector3(0.02, 0.02, 0.04), metal)      # boca do cano
	_bloco(Vector3(0, -0.04, 0.0), Vector3(0.028, 0.1, 0.04), cabo).rotation_degrees.x = -12.0  # empunhadura
	_bloco(Vector3(0, -0.005, 0.04), Vector3(0.006, 0.025, 0.02), metal)  # gatilho
	cano = Node3D.new()
	cano.position = Vector3(0, 0.035, 0.2)
	add_child(cano)


func _bloco(p: Vector3, tam: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(dt: float) -> void:
	_espera -= dt
	_abertura = move_toward(_abertura, 0.0, dt * 4.0)
	_luz.light_energy = move_toward(_luz.light_energy, 0.0, dt * 60.0)
	if recarregando:
		_recarga_t -= dt
		if _recarga_t <= 0.0:
			var falta: int = mini(PENTE - balas, reserva)
			balas += falta
			reserva -= falta
			recarregando = false


## Pode atirar agora? (tem bala, não está recarregando, já passou a cadência)
func pronta() -> bool:
	return balas > 0 and not recarregando and _espera <= 0.0


## Tenta atirar a partir de `origem` na direção `dir` (raio da mira). Pente vazio = recarrega.
## Retorna o resultado: {"atirou": bool, "acertou": Node ou null, "ponto": Vector3, "cabeca": bool}.
func atirar(origem: Vector3, dir: Vector3, mirando: bool) -> Dictionary:
	var res: Dictionary = {"atirou": false, "acertou": null, "ponto": Vector3.ZERO, "cabeca": false}
	if balas <= 0:
		recarregar()
		return res
	if not pronta():
		return res
	balas -= 1
	_espera = CADENCIA
	# dispersão: um pequeno desvio aleatório dentro de um cone
	var graus: float = (DISPERSAO_MIRA if mirando else DISPERSAO_QUADRIL) + _abertura
	_abertura = minf(_abertura + DISPERSAO_POR_TIRO, 4.0)
	var desvio := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	dir = dir.rotated(dir.cross(desvio).normalized(), deg_to_rad(randf() * graus)) if dir.cross(desvio).length() > 0.01 else dir
	var q := PhysicsRayQueryParameters3D.create(origem, origem + dir * ALCANCE, 1)
	q.exclude = [dono.get_rid()] if dono else []
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var ponto: Vector3 = hit.position if not hit.is_empty() else origem + dir * ALCANCE
	res.atirou = true
	res.ponto = ponto
	if not hit.is_empty() and (hit.collider as Node).is_in_group("golpeavel"):
		var alvo: Node3D = hit.collider
		var cabeca: bool = ponto.y - alvo.global_position.y > 1.65
		alvo.call("levar_golpe", DANO * (2 if cabeca else 1), dir, dono)
		res.acertou = alvo
		res.cabeca = cabeca
	efeito(ponto, not hit.is_empty())
	return res


func recarregar() -> void:
	if recarregando or balas == PENTE or reserva <= 0:
		return
	recarregando = true
	_recarga_t = RECARGA


## Clarão, som e rastro até `ponto` (também chamado nos outros aparelhos quando alguém atira).
func efeito(ponto: Vector3, bateu: bool) -> void:
	_luz.light_energy = 3.0
	_som.stream = _som_tiro
	_som.pitch_scale = randf_range(0.95, 1.05)
	_som.play()
	var de: Vector3 = cano.global_position
	var rastro := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.008
	cil.bottom_radius = 0.008
	cil.height = maxf(de.distance_to(ponto), 0.01)
	cil.radial_segments = 4
	cil.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.9, 0.6, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cil.material = m
	rastro.mesh = cil
	rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child(rastro)
	rastro.global_position = (de + ponto) * 0.5
	var eixo: Vector3 = (ponto - de).normalized()
	if absf(eixo.dot(Vector3.UP)) < 0.999:
		rastro.global_basis = Basis(Quaternion(Vector3.UP, eixo))
	var t := rastro.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, 0.08)
	t.tween_callback(rastro.queue_free)
	if bateu:
		_faisca(ponto)


func _faisca(p: Vector3) -> void:
	var f := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = 0.06
	e.height = 0.12
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	e.material = m
	f.mesh = e
	get_tree().root.add_child(f)
	f.global_position = p
	var t := f.create_tween()
	t.tween_property(f, "scale", Vector3.ONE * 2.2, 0.12)
	t.parallel().tween_property(m, "albedo_color:a", 0.0, 0.12)
	t.tween_callback(f.queue_free)


# estampido gerado no código (não há som de tiro nos pacotes grátis): estalo de ruído com queda rápida
func _gera_estampido() -> AudioStreamWAV:
	var taxa: int = 22050
	var n: int = int(taxa * 0.35)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var baixo: float = 0.0
	for i in n:
		var t: float = float(i) / taxa
		var ruido: float = randf_range(-1.0, 1.0)
		baixo = lerpf(baixo, ruido, 0.18)  # filtro passa-baixa: corpo do estampido
		var env: float = exp(-t * 22.0)
		var v: float = (ruido * 0.35 * exp(-t * 60.0) + baixo * 1.6) * env
		v += sin(TAU * 70.0 * t) * 0.5 * exp(-t * 14.0)  # pancada grave
		dados.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	return w
