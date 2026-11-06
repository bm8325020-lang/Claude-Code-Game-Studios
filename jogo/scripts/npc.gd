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
			var mapa: RID = get_world_3d().navigation_map
			var cam: PackedVector3Array = NavigationServer3D.map_get_path(mapa, global_position, segue.global_position, true)
			var prox: Vector3 = cam[1] if cam.size() > 1 else segue.global_position
			var dir: Vector3 = prox - global_position
			dir.y = 0.0
			global_position += dir.normalized() * minf(VEL * (1.6 if d > 12.0 else 1.0) * dt, dir.length())
			global_position.y = prox.y
			rotation.y = atan2(dir.x, dir.z)
		if _anim:
			var c: String = "andar" if andando else "parado"
			if _anim.current_animation != c and _anim.has_animation(c):
				_anim.play(c, 0.2)
	var principal := get_tree().get_first_node_in_group("principal")
	var j: Jogador = principal.jogador if principal else null
	if j == null or falou:
		return
	if _i < 0:
		if j.global_position.distance_to(global_position) < PERTO:
			_i = 0
			_t = 0.0
			_diz(principal)
		return
	_t += dt
	if _t >= POR_FALA:
		_t = 0.0
		_i += 1
		if _i >= falas.size():
			falou = true
		else:
			_diz(principal)


func _diz(principal: Node) -> void:
	if principal.controles and _i < falas.size():
		principal.controles._tarefas.legenda(nome, String(falas[_i]), POR_FALA)  # legenda de diálogo embaixo
