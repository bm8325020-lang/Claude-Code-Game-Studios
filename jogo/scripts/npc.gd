# Personagem da história (07/11, modo história: Dana, Mia): parado no lugar, nome em cima, fala quando você chega perto
# (as falas passam na faixa de aviso, uma de cada vez). `falou` = já disse tudo (Historia avança). Só no aparelho.
class_name Npc
extends Node3D

const PERTO: float = 3.5
const POR_FALA: float = 4.5

var nome: String = ""
var falas: Array = []
var falou: bool = false
## Escolta (07/11): seguindo alguém pela malha de navegação, a 2,5 m dele.
var segue: Node3D
const VEL: float = 4.6
var _anim: AnimationPlayer
var _i: int = -1
var _t: float = 0.0
var _dura: float = POR_FALA
var _cam: PackedVector3Array = []
var _cam_i: int = 1
var _refaz_t: float = 0.0  # a fala atual (com voz dura o que a voz durar)


func _ready() -> void:
	add_to_group("npcs")
	if Rede.servidor_sem_tela:
		return
	var m: Node3D = Anims.boneco(Anims.JOGADOR)
	add_child(m)
	var anim := AnimationPlayer.new()
	m.add_child(anim)
	anim.add_animation_library("", Anims.adaptada(Anims.biblioteca(), Anims.JOGADOR))
	if anim.has_animation("parado"):
		anim.play("parado")
	_anim = anim
	Anims.poe_mochila(m)
	var l := Label3D.new()
	l.text = nome
	l.modulate = Color(0.55, 0.85, 1.0)
	l.font_size = 44
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 2.2
	add_child(l)


func _process(dt: float) -> void:
	if segue and is_instance_valid(segue):
		var d: float = global_position.distance_to(segue.global_position)
		var andando: bool = d > 2.5
		if andando:
			_refaz_t -= dt
			if _refaz_t <= 0.0 or _cam.size() < 2:  # anti-lag (06/11): caminho refeito 4x por segundo, não todo quadro
				_refaz_t = 0.25
				_cam = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, segue.global_position, true)
				_cam_i = 1
			while _cam_i < _cam.size() - 1 and Vector2(_cam[_cam_i].x - global_position.x, _cam[_cam_i].z - global_position.z).length() < 0.3:
				_cam_i += 1
			var prox: Vector3 = _cam[_cam_i] if _cam_i < _cam.size() else segue.global_position
			var dir: Vector3 = prox - global_position
			dir.y = 0.0
			if dir.length() < 0.05:  # já está na esquina do caminho: mira direto em quem segue (antes ficava parado)
				prox = segue.global_position
				dir = Vector3(prox.x - global_position.x, 0.0, prox.z - global_position.z)
			global_position += dir.normalized() * minf(VEL * (1.6 if d > 12.0 else 1.0) * dt, dir.length())
			global_position.y = prox.y
			rotation.y = atan2(dir.x, dir.z)
		if _anim:
			var c: String = "andar" if andando else "parado"
			if _anim.current_animation != c and _anim.has_animation(c):
				_anim.play(c, 0.2)
	var principal := get_tree().get_first_node_in_group("principal")
	var j: Jogador = principal.jogador if principal and is_instance_valid(principal.jogador) else null
	if j == null or falou:
		return
	if _i < 0:
		if j.global_position.distance_to(global_position) < PERTO:
			_i = 0
			_t = 0.0
			_diz(principal)
		return
	_t += dt
	if _t >= _dura:
		_t = 0.0
		_i += 1
		if _i >= falas.size():
			falou = true
		else:
			_diz(principal)


func _diz(principal: Node) -> void:
	if principal.controles and _i < falas.size():
		_dura = principal.controles._tarefas.legenda(nome, String(falas[_i]), POR_FALA, false) + 0.3  # fala do seu lado (no painel do rádio, sem apito)
