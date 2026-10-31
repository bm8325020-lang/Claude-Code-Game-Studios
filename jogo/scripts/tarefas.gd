# Tarefas (31/10, print do dono + agente: "objetivo sempre claro"): painel no canto de cima com a tarefa da vez. Começa
# ensinando o jogo (comida, gavetas, zumbis, sala segura, bilhete, cofre, um marco, a noite) e depois sorteia. Cada uma
# dá XP. Só no aparelho do jogador (não vai pela rede).
class_name Tarefas
extends Control

const XP: int = 20
const ROTEIRO: Array = [
	["comida", 1, "Pegue uma lata de comida"],
	["revistou", 3, "Revistar gavetas ou armários (%d/%d)"],
	["abateu", 3, "Mate zumbis (%d/%d)"],
	["segura", 1, "Ache uma sala segura (lampião aceso)"],
	["bilhete", 1, "Leia um bilhete"],
	["destrancou", 1, "Ache uma chave e abra um armário de metal"],
	["marco", 1, "Vá até o %s"],
	["amanheceu", 1, "Sobreviva até amanhecer"],
]
const DEPOIS: Array = [["abateu", 5, "Mate zumbis (%d/%d)"], ["revistou", 5, "Revistar gavetas ou armários (%d/%d)"],
	["agua", 2, "Pegue garrafas de água (%d/%d)"], ["comida", 2, "Pegue latas de comida (%d/%d)"]]
const MARCOS: Dictionary = {"posto": "posto de gasolina", "helicoptero": "helicóptero caído", "quarentena": "posto de quarentena do exército"}

var _j: Jogador
var _i: int = 0
var _feito: int = 0
var _atual: Array = []
var _marco: String = ""
var _titulo: Label
var _linha: Label
var _t: float = 0.0
var _era_noite: bool = false


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.35)
	fundo.size = Vector2(330, 62)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_titulo = UiTema.rotulo("TAREFAS", 22, Color(1.0, 0.68, 0.2))
	_titulo.position = Vector2(10, 2)
	add_child(_titulo)
	_linha = UiTema.rotulo("", 18, Color(1, 1, 1, 0.95))
	_linha.position = Vector2(14, 30)
	_linha.size = Vector2(312, 28)
	_linha.clip_text = true
	add_child(_linha)
	_comeca(ROTEIRO[0])


func liga(j: Jogador) -> void:
	_j = j
	j.item_pego.connect(func(t: String, _q: int) -> void: evento(t))
	j.revistou.connect(func() -> void: evento("revistou"))
	j.abateu.connect(func() -> void: evento("abateu"))
	j.entrou_segura.connect(func(sim: bool) -> void:
		if sim:
			evento("segura"))


func _comeca(t: Array) -> void:
	_atual = t
	_feito = 0
	if t[0] == "marco":
		_marco = _marco_perto()
	_mostra()


func _mostra() -> void:
	var texto: String = String(_atual[2])
	if _atual[0] == "marco":
		texto = texto % MARCOS.get(_marco, "marco")
	elif texto.contains("%d"):
		texto = texto % [_feito, int(_atual[1])]
	_linha.text = "•  " + texto


func evento(tipo: String) -> void:
	if _atual.is_empty() or tipo != String(_atual[0]):
		return
	_feito += 1
	if _feito < int(_atual[1]):
		_mostra()
		return
	if _j and is_instance_valid(_j):
		_j._recebe("xp", XP)
	var c := get_parent()
	if c and c.has_method("aviso"):
		c.aviso("TAREFA FEITA  +%d XP" % XP, UiTema.DESTAQUE, 2.0)
	_i += 1
	_comeca(ROTEIRO[_i] if _i < ROTEIRO.size() else DEPOIS[randi() % DEPOIS.size()])


func _marco_perto() -> String:
	var principal := get_tree().get_first_node_in_group("principal") if is_inside_tree() else null
	if principal == null or principal.bairro == null or _j == null:
		return "posto"
	var melhor: String = "posto"
	var dist: float = INF
	for k: String in MARCOS:
		if principal.bairro.marcos_pos.has(k):
			var d: float = (principal.bairro.marcos_pos[k] as Vector3).distance_to(_j.global_position)
			if d < dist:
				dist = d
				melhor = k
	return melhor


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or _j == null or not is_instance_valid(_j):
		return
	_t = 1.0
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var noite: bool = ciclo.e_noite()
		if _era_noite and not noite:
			evento("amanheceu")
		_era_noite = noite
	if not _atual.is_empty() and _atual[0] == "marco":
		var principal := get_tree().get_first_node_in_group("principal")
		if principal and principal.bairro and principal.bairro.marcos_pos.has(_marco):
			if (principal.bairro.marcos_pos[_marco] as Vector3).distance_to(_j.global_position) < 18.0:
				evento("marco")
