# Braços e arma na tela em primeira pessoa (viewmodel).
# Pistola: animações de animador (Sketchfab, CC BY, 1Matzh, "9mm Pistol | First Person Animations"); o pacote
# foi feito com a câmera num ponto do esqueleto (OLHO_PISTOLA), que é posto na câmera.
# Facão: como na maioria dos jogos em primeira pessoa — parado no canto de baixo à direita, cabo saindo da
# tela, lâmina para cima e para a frente; os 3 golpes são cortes (direita→esquerda, volta na diagonal, de cima
# para baixo) girando em volta do ombro, com preparação e acompanhamento, no tempo do acerto de cada golpe.
# Por cima de tudo: atraso ao virar (balanço), arma baixa correndo e subida ao mirar.
class_name Maos
extends Node3D

const OLHO_PISTOLA := Vector3(0, 1.41, 0.02)
const OLHO_SMG := Vector3(0, 1.4, -0.25)  # "FPS Animations LowPoly MP5" (ccransh, CC BY)
## nomes das animações de cada pacote de arma de fogo
const ANIMS: Dictionary = {
	"pistola": {"idle": "Idle", "walk": "Walk", "run": "Run", "fire": "Fire", "reload": "Reload", "reload_vazio": "Reload_Empty", "equip": "Equip"},
	"smg": {"idle": "Arms_Idle", "walk": "Arms_Walk", "run": "Arms_Run", "fire": "Arms_Fire", "reload": "Arms_notfullreload",
		"reload_vazio": "Arms_fullreload", "equip": "Arms_Draw"},
}
const MIRA_PISTOLA := Vector3(0.0, 0.02, 0.025)  # quanto a pistola vem para o centro/para perto mirando
const OMBRO := Vector3(0.36, -0.5, 0.12)         # pivô dos cortes (atrás e abaixo, à direita da câmera)
const CABO := Vector3(-0.04, 0.16, -0.58)         # onde fica o cabo, a partir do ombro (sai pela borda da tela)
const LAMINA := Vector3(-0.32, 0.72, -0.62)      # para onde a lâmina aponta parada
## giro do ombro (graus x sobe, y vai para a esquerda, z inclina) ao longo de cada golpe (fração do golpe)
const CORTES: Array = [
	[[0.0, Vector3.ZERO], [0.3, Vector3(8, -42, -22)], [0.4, Vector3(6, -46, -24)], [0.46, Vector3(-2, 12, 8)],
		[0.56, Vector3(-14, 62, 26)], [0.75, Vector3(-8, 44, 16)], [1.0, Vector3.ZERO]],
	[[0.0, Vector3.ZERO], [0.2, Vector3(-16, 52, 26)], [0.3, Vector3(-16, 54, 27)], [0.37, Vector3(4, 0, -4)],
		[0.48, Vector3(26, -52, -30)], [0.7, Vector3(14, -30, -15)], [1.0, Vector3.ZERO]],
	[[0.0, Vector3.ZERO], [0.3, Vector3(46, 10, -10)], [0.4, Vector3(52, 12, -10)], [0.45, Vector3(2, 5, 0)],
		[0.56, Vector3(-48, 0, 6)], [0.76, Vector3(-30, 0, 0)], [1.0, Vector3.ZERO]],
]

var alvo: Jogador
var _pistola: Node3D
var _ap_p: AnimationPlayer
var _rigs: Dictionary = {}  # tipo de arma de fogo -> pacote (Node3D)
var _ombro: Node3D
var _arma: String = ""
var _ult_tiro: float = 99.0
var _recarregando: bool = false
var _ult_yaw: float = 0.0
var _ult_pitch: float = 0.0
var _balanco := Vector2.ZERO
var _mira: float = 0.0
var _saca: float = 1.0      # 0 = arma ainda subindo (acabou de trocar), 1 = no lugar
var _respira: float = 0.0
var _parede: float = 0.0    # 0 = livre, 1 = parede colada na frente (arma recolhe e baixa)


func _ready() -> void:
	_pistola = _carrega("pistola_fp", OLHO_PISTOLA)
	_rigs = {"pistola": _pistola, "smg": _carrega("smg_fp", OLHO_SMG)}
	_ap_p = _pistola.find_children("*", "AnimationPlayer", true, false)[0]
	_ombro = Node3D.new()
	_ombro.position = OMBRO
	_ombro.visible = false
	add_child(_ombro)
	_monta_branca("facao")


# troca a arma branca na mão: o modelo vem pronto de Armas (pegada na origem, ponta para +Z)
func _monta_branca(tipo: String) -> void:
	for c in _ombro.get_children():
		c.queue_free()
	var pega: Node3D = Armas.modelo(tipo)
	var z: Vector3 = LAMINA.normalized()
	var x: Vector3 = (Vector3.BACK - z * z.dot(Vector3.BACK)).normalized()  # lado chato da lâmina para a câmera
	pega.basis = Basis(x, z.cross(x), z)
	pega.position = CABO
	_ombro.add_child(pega)
	for mi: MeshInstance3D in pega.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := (mi.get_surface_override_material(i) if mi.get_surface_override_material(i) else mi.mesh.surface_get_material(i)).duplicate() as BaseMaterial3D
			m.emission_enabled = true
			m.emission = Color(0.08, 0.08, 0.09)  # lâmina escura: um mínimo de brilho para ler na tela
			mi.set_surface_override_material(i, m)
	_sem_sombra(pega)


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
		for t: String in _rigs:
			(_rigs[t] as Node3D).visible = t == _arma
		_ombro.visible = not Jogador.e_fogo(_arma)
		if Armas.e_branca(_arma):
			_monta_branca(_arma)
		_saca = 0.0
		if _rigs.has(_arma):
			_ap_p = (_rigs[_arma] as Node3D).find_children("*", "AnimationPlayer", true, false)[0]
			_toca(ANIMS[_arma].equip, true)
	_saca = move_toward(_saca, 1.0, dt * 3.5)
	var vel: float = Vector2(alvo.velocity.x, alvo.velocity.z).length()
	if _rigs.has(_arma):
		_pistola_anima(vel)
	else:
		_facao_anima(dt)
	# balanço: a arma atrasa um pouco atrás do olhar e volta (molinha)
	var cam := get_parent().get_parent() as CameraPrimeira
	if cam:
		var d := Vector2(wrapf(cam.yaw - _ult_yaw, -PI, PI), cam.pitch - _ult_pitch)
		_ult_yaw = cam.yaw
		_ult_pitch = cam.pitch
		_balanco = (_balanco + d * 0.6).limit_length(0.12).lerp(Vector2.ZERO, 1.0 - exp(-9.0 * dt))
	_mira = move_toward(_mira, 1.0 if alvo.mira_travada and Jogador.e_fogo(_arma) else 0.0, dt * 6.0)
	var baixa: float = (0.06 if alvo.correndo else 0.0) + (1.0 - _saca) * 0.35
	if alvo._pegando > Jogador.PEGAR_DUR * 0.4:
		baixa += 0.3  # pegando do chão: a arma sai da frente
	_parede = move_toward(_parede, _perto_parede(cam), dt * 5.0)
	baixa += _parede * 0.22
	position = position.lerp(Vector3(_balanco.x * 0.25, -_balanco.y * 0.25 - baixa, _parede * 0.18) + MIRA_PISTOLA * _mira, 1.0 - exp(-14.0 * dt))
	rotation = Vector3(-_balanco.y * 0.5 - _parede * 0.5, _balanco.x * 0.5 + _parede * 0.35, 0.0)


# parede/caixa a menos de 0,7 m na frente do olho: 0..1 (mais perto = mais recolhida)
func _perto_parede(cam: CameraPrimeira) -> float:
	if cam == null or cam.cam == null:
		return 0.0
	var o: Vector3 = cam.cam.global_position
	var q := PhysicsRayQueryParameters3D.create(o, o - cam.cam.global_basis.z * 0.7, 1)
	q.exclude = [alvo.get_rid()]
	var r: Dictionary = alvo.get_world_3d().direct_space_state.intersect_ray(q)
	return 0.0 if r.is_empty() else clampf(1.0 - (o.distance_to(r.position) - 0.25) / 0.45, 0.0, 1.0)


# facão: parado respira de leve; correndo deita; golpe = corte em volta do ombro (CORTES)
func _facao_anima(dt: float) -> void:
	_respira += dt
	var giro := Vector3(sin(_respira * 1.6) * 1.2, 0, 0)
	if alvo.correndo:
		giro = Vector3(-18, -8, 14)
	if alvo._golpe >= 0 and alvo._golpe_dur > 0.0:
		var chaves: Array = CORTES[clampi(alvo._golpe, 0, CORTES.size() - 1)]
		var t: float = clampf(alvo._golpe_t / alvo._golpe_dur, 0.0, 1.0)
		for i in range(1, chaves.size()):
			if t <= float(chaves[i][0]):
				var t0: float = chaves[i - 1][0]
				var u: float = smoothstep(0.0, 1.0, (t - t0) / maxf(float(chaves[i][0]) - t0, 0.001))
				giro = (chaves[i - 1][1] as Vector3).lerp(chaves[i][1], u)
				break
		_ombro.rotation_degrees = giro  # golpe: sem suavizar, para o corte sair seco
	else:
		_ombro.rotation_degrees = _ombro.rotation_degrees.lerp(giro, 1.0 - exp(-10.0 * dt))


# arma de fogo: tiro, recarga (no tempo da recarga da arma), andar/correr/parado com o pacote dela
func _pistola_anima(vel: float) -> void:
	var p: Pistola = alvo.fogo()
	var nomes: Dictionary = ANIMS[_arma]
	if alvo._tiro_t < _ult_tiro:
		_toca(nomes.fire, true, 1.0 if not p.automatica else _ap_p.get_animation(nomes.fire).length / maxf(p.cadencia * 1.6, 0.05))
	_ult_tiro = alvo._tiro_t
	if p.recarregando and not _recarregando:
		var nome: String = nomes.reload_vazio if p.balas == 0 else nomes.reload
		_toca(nome, true, _ap_p.get_animation(nome).length / p.recarga)
	_recarregando = p.recarregando
	if _ocupada(_ap_p):
		return
	_toca(nomes.run if alvo.correndo else (nomes.walk if vel > 0.6 else nomes.idle))


# animação de ação (tiro, recarga, golpe, pegar, sacar) ainda tocando: a de andar/parado espera
func _ocupada(ap: AnimationPlayer) -> bool:
	var a: String = ap.current_animation
	return ap.is_playing() and a != "" and not (a.ends_with("Idle") or a.ends_with("Walk") or a.ends_with("Run") or "Sprint" in a)


func _toca(nome: String, de_novo: bool = false, vel: float = 1.0) -> void:
	var ap: AnimationPlayer = _ap_p
	if not ap.has_animation(nome):
		return
	if ap.current_animation == nome and not de_novo:
		return
	ap.play(nome, 0.12, vel)
	if de_novo:
		ap.seek(0.0, true)
