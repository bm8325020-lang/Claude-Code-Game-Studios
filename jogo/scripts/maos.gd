# Braços e arma na tela em primeira pessoa (viewmodel). Usa animações feitas por animador (Sketchfab, CC BY,
# 1Matzh): "9mm Pistol | First Person Animations" com a pistola e "Fists (2025)" com o facão na mão direita.
# Cada pacote foi feito com a câmera num ponto do esqueleto (OLHO_*): o pacote é posto de modo que esse ponto
# caia na câmera. Por cima das animações: atraso ao virar (balanço), arma baixa correndo e subida ao mirar.
class_name Maos
extends Node3D

const OLHO_PISTOLA := Vector3(0, 1.41, 0.02)
const OLHO_PUNHOS := Vector3(0, 1.53, 0.02)
const MIRA_PISTOLA := Vector3(0.0, 0.02, 0.025)  # quanto a arma vem para o centro/para perto mirando
const FACAO_TAM: float = 0.42                    # m de ponta a ponta
const FACAO_CABO: float = 0.16                   # m do meio até o cabo (a mão segura o cabo, a lâmina sai do punho)
const FACAO_INCLINA: float = -55.0               # graus: a lâmina deita para a frente (em pé tapava a vista)

var alvo: Jogador
var _pistola: Node3D
var _ap_p: AnimationPlayer
var _punhos: Node3D
var _ap_f: AnimationPlayer
var _arma: String = ""
var _ult_tiro: float = 99.0
var _recarregando: bool = false
var _golpe: int = -1
var _pegando: bool = false
var _soco_esq: bool = false
var _ult_yaw: float = 0.0
var _ult_pitch: float = 0.0
var _balanco := Vector2.ZERO
var _mira: float = 0.0


func _ready() -> void:
	_pistola = _carrega("pistola_fp", OLHO_PISTOLA)
	_ap_p = _pistola.find_children("*", "AnimationPlayer", true, false)[0]
	_punhos = _carrega("punhos_fp", OLHO_PUNHOS)
	_ap_f = _punhos.find_children("*", "AnimationPlayer", true, false)[0]
	# facão (Machete, Belonosoff, CC BY) na mão direita do pacote dos punhos
	var sk: Skeleton3D = _punhos.find_children("*", "Skeleton3D", true, false)[0]
	var mao := BoneAttachment3D.new()
	mao.bone_name = "hand_tweak.R_0559"
	sk.add_child(mao)
	var f: Node3D = (load("res://assets/sketchfab/facao.glb") as PackedScene).instantiate()
	f.scale = Vector3.ONE * FACAO_TAM / 4.98  # 4,98 de comprimento no arquivo (eixo Z)
	f.rotation_degrees.x = FACAO_INCLINA
	f.position = f.basis * Vector3(0, 0, FACAO_CABO)
	mao.add_child(f)
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
			m.metallic = 0.3  # metal puro fica preto sem reflexo de céu
			mi.set_surface_override_material(i, m)
	_sem_sombra(f)


func _carrega(nome: String, olho: Vector3) -> Node3D:
	var r: Node3D = (load("res://assets/sketchfab/fps/%s.glb" % nome) as PackedScene).instantiate()
	add_child(r)
	for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		mi.visible = mi.skin != null  # o pacote traz céu, mira e fundo de vitrine: fica só o que tem esqueleto
	_sem_sombra(r)
	var ap: AnimationPlayer = r.find_children("*", "AnimationPlayer", true, false)[0]
	for a: StringName in ap.get_animation_list():
		if "Idle" in a or "Walk" in a or "Run" in a or "Sprint" in a:
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	r.rotation_degrees.y = 180.0  # o pacote olha para +Z; a câmera olha para -Z
	r.position = -(Basis(Vector3.UP, PI) * olho)
	r.visible = false
	return r


func _sem_sombra(n: Node) -> void:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(dt: float) -> void:
	if alvo == null:
		return
	visible = alvo.vida > 0
	if alvo.arma != _arma:
		_arma = alvo.arma
		_pistola.visible = _arma == "pistola"
		_punhos.visible = _arma != "pistola"
		_toca("Equip" if _arma == "pistola" else "rig|Equip", true)
	var vel: float = Vector2(alvo.velocity.x, alvo.velocity.z).length()
	if _arma == "pistola":
		_pistola_anima(vel)
	else:
		_punhos_anima(vel)
	# balanço: a arma atrasa um pouco atrás do olhar e volta (molinha)
	var cam := get_parent().get_parent() as CameraPrimeira
	if cam:
		var d := Vector2(wrapf(cam.yaw - _ult_yaw, -PI, PI), cam.pitch - _ult_pitch)
		_ult_yaw = cam.yaw
		_ult_pitch = cam.pitch
		_balanco = (_balanco + d * 0.6).limit_length(0.12).lerp(Vector2.ZERO, 1.0 - exp(-9.0 * dt))
	_mira = move_toward(_mira, 1.0 if alvo.mira_travada and _arma == "pistola" else 0.0, dt * 6.0)
	var baixa: float = 0.06 if alvo.correndo else 0.0
	position = Vector3(_balanco.x * 0.25, -_balanco.y * 0.25 - baixa, 0.0) + MIRA_PISTOLA * _mira
	rotation = Vector3(-_balanco.y * 0.5, _balanco.x * 0.5, 0.0)


func _pistola_anima(vel: float) -> void:
	var p: Pistola = alvo.pistola
	if alvo._tiro_t < _ult_tiro:
		_toca("Fire", true)
	_ult_tiro = alvo._tiro_t
	if p.recarregando and not _recarregando:
		var nome: String = "Reload_Empty" if p.balas == 0 else "Reload"
		_toca(nome, true, _ap_p.get_animation(nome).length / Pistola.RECARGA)
	_recarregando = p.recarregando
	if _ocupada(_ap_p):
		return
	_toca("Run" if alvo.correndo else ("Walk" if vel > 0.6 else "Idle"))


func _punhos_anima(vel: float) -> void:
	if alvo._golpe != _golpe and alvo._golpe >= 0:
		_soco_esq = not _soco_esq if alvo._golpe > 0 else false
		_toca("rig|Punch_L" if _soco_esq else "rig|Punch_R", true, 1.3)
	_golpe = alvo._golpe
	var pegando: bool = alvo._pegando > 0.0
	if pegando and not _pegando:
		_toca("rig|Take", true)
	_pegando = pegando
	if _ocupada(_ap_f):
		return
	_toca("rig|Sprint_Type_1" if alvo.correndo else ("rig|Walk" if vel > 0.6 else "rig|Idle"))


# animação de ação (tiro, recarga, golpe, pegar, sacar) ainda tocando: a de andar/parado espera
func _ocupada(ap: AnimationPlayer) -> bool:
	var a: String = ap.current_animation
	return ap.is_playing() and a != "" and not (a.ends_with("Idle") or a.ends_with("Walk") or a.ends_with("Run") or "Sprint" in a)


func _toca(nome: String, de_novo: bool = false, vel: float = 1.0) -> void:
	var ap: AnimationPlayer = _ap_p if _pistola.visible else _ap_f
	if not ap.has_animation(nome):
		return
	if ap.current_animation == nome and not de_novo:
		return
	ap.play(nome, 0.12, vel)
	if de_novo:
		ap.seek(0.0, true)
