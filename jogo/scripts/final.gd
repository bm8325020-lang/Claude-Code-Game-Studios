# Fim da história (07/11): tela preta, boletim final da Dana (muda com o final: bom = com as 5 fitas, a verdade sai;
# amargo = sem elas) e os créditos subindo; CONTINUAR volta para Senoia com tudo aberto.
class_name Final
extends CanvasLayer

const LETRA: float = 0.03
const POR_LINHA: float = 3.6
const BOM: Array[String] = [
	"WSB CHANNEL 2 — EDIÇÃO EXTRAORDINÁRIA", "",
	"Aqui é Dana Price, a bordo de um helicóptero do Exército, saindo de Senoia.",
	"Temos as cinco fitas da doutora Ruth Okafor.",
	"A Febre Cinzenta não foi acidente: a Halverson Agro testou um milho modificado na Hollis Feed.",
	"A Mia está viva. Está fraca, mas está aqui, do meu lado.",
	"Ao Alex, que veio de fora e não desistiu: obrigada.",
	"Senoia ficou para trás. A verdade, não.",
]
const AMARGO: Array[String] = [
	"WSB CHANNEL 2 — EDIÇÃO EXTRAORDINÁRIA", "",
	"Aqui é Dana Price, saindo de Senoia num helicóptero do Exército.",
	"Sem as fitas da doutora Okafor, não temos prova de nada.",
	"A Halverson Agro já soltou uma nota: 'surto de origem desconhecida'.",
	"Saímos vivos. Mas a verdade ficou lá embaixo, com os mortos.",
]

signal novo_jogo_mais
var bom: bool = true
var stats: String = ""  # tempo, mortos, mortes, fitas, troféus (Tarefas)
var _linhas: Array[String] = []
var _i: int = 0
var _t: float = 0.0
var _texto: Label
var _creditos: Label
var _fase: int = 0  # 0 boletim, 1 créditos
var _falou: int = -1
var _dura: float = POR_LINHA


func _ready() -> void:
	layer = 50
	_linhas = BOM if bom else AMARGO
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_texto = UiTema.rotulo("", 30, Color(0.9, 0.9, 0.86))
	_texto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	_texto.custom_minimum_size = Vector2(1000, 120)
	_texto.position -= Vector2(500, 60)
	add_child(_texto)
	_creditos = UiTema.rotulo("DEAD DISTRICT\n\nFIM\n\n" + stats + "\n\n" + Creditos.TEXTO, 20, Color(0.85, 0.85, 0.82))
	_creditos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_creditos.autowrap_mode = TextServer.AUTOWRAP_WORD
	_creditos.size = Vector2(1100, 6000)
	_creditos.visible = false
	add_child(_creditos)
	var b: Button = UiTema.botao("CONTINUAR EM SENOIA")
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position -= Vector2(380, 100)
	b.custom_minimum_size = Vector2(340, 70)
	b.pressed.connect(queue_free)
	add_child(b)
	var ng := UiTema.botao("NOVO JOGO+ (MAIS PERIGOSO)", true)  # 07/11: recomeça a história com a mochila
	ng.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ng.position -= Vector2(760, 100)
	ng.custom_minimum_size = Vector2(360, 70)
	ng.pressed.connect(func() -> void:
		novo_jogo_mais.emit()
		queue_free())
	add_child(ng)
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(dt: float) -> void:
	_t += dt
	if _fase == 0:
		var l: String = _linhas[_i]
		_texto.text = l.left(int(_t / LETRA))
		if _i != _falou:
			_falou = _i
			_dura = maxf(POR_LINHA, Voz.fala(l, self) + 0.4)  # boletim narrado pela Dana
		if _t > _dura or (l == "" and _t > 0.5):
			_t = 0.0
			_i += 1
			if _i >= _linhas.size():
				_fase = 1
				_texto.visible = false
				_creditos.visible = true
				_creditos.position = Vector2((get_viewport().get_visible_rect().size.x - 1100) * 0.5, get_viewport().get_visible_rect().size.y)
	else:
		_creditos.position.y -= dt * 45.0


func _exit_tree() -> void:
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
