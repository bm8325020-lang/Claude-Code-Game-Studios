# Personagem da história (07/11, modo história: Dana, Mia): parado no lugar, nome em cima, fala quando você chega perto
# (as falas passam na faixa de aviso, uma de cada vez). `falou` = já disse tudo (Historia avança). Só no aparelho.
class_name Npc
extends Node3D

const PERTO: float = 3.5
const POR_FALA: float = 4.5

var nome: String = ""
var falas: Array = []
var falou: bool = false
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
	var l := Label3D.new()
	l.text = nome
	l.modulate = Color(0.55, 0.85, 1.0)
	l.font_size = 44
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 2.2
	add_child(l)


func _process(dt: float) -> void:
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
		principal.controles.aviso("%s: %s" % [nome, falas[_i]], Color(0.6, 0.88, 1.0), POR_FALA)
