# Tela de carregamento (plano aprovado pelo dono, 30/10): capa da cidade (tools/foto_capa.gd) escurecida, "CARREGANDO",
# linha fina de progresso e uma DICA verdadeira do jogo. Aparece antes de montar o mundo (criar sala) ou enquanto a
# conexão chega (entrar), e some quando o jogador existe.
class_name Carregando
extends CanvasLayer

const DICAS: Array[String] = [
	"Zumbi armado da delegacia erra mais se você estiver agachado.",
	"Zumbi não atravessa a tábua entre os telhados. Suba pela escada de incêndio.",
	"No rio todo mundo fica lento, inclusive os zumbis.",
	"Fresta entre dois prédios: entre de lado. O zumbi não cabe.",
	"Amanhecer vivo dá XP. Gaste os pontos em HABILIDADES, na pausa.",
	"Arame farpado corta e prende. Não encoste.",
	"Bilhetes no chão contam onde tem coisa boa.",
	"À noite os zumbis correm mais e batem mais forte.",
	"Mordida no pescoço: aperte EMPURRAR no tempo certo para se soltar.",
	"Infectado? Só antibiótico para a barra. Tem no arsenal da delegacia.",
	"Tiro faz barulho: os zumbis em volta vêm ver.",
	"O fogo queima quem entra. Use para cortar caminho de zumbi.",
]

var _linha: ColorRect
var _t: float = 0.0


func _ready() -> void:
	layer = 50
	var capa := TextureRect.new()
	capa.texture = load("res://assets/ui/capa.jpg")
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	capa.modulate = Color(0.75, 0.72, 0.7)
	add_child(capa)
	var sombra := ColorRect.new()  # escurece embaixo, onde fica o texto
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.color = Color(0, 0, 0, 0.35)
	add_child(sombra)
	var titulo := UiTema.titulo("CARREGANDO", 46, UiTema.TEXTO)
	titulo.anchor_top = 1.0
	titulo.anchor_bottom = 1.0
	titulo.anchor_right = 1.0
	titulo.offset_left = 48
	titulo.offset_right = -48
	titulo.offset_top = -190
	titulo.offset_bottom = -130
	add_child(titulo)
	var trilho := ColorRect.new()
	trilho.color = Color(1, 1, 1, 0.12)
	trilho.anchor_top = 1.0
	trilho.anchor_bottom = 1.0
	trilho.anchor_right = 1.0
	trilho.offset_left = 48
	trilho.offset_right = -48
	trilho.offset_top = -120
	trilho.offset_bottom = -117
	add_child(trilho)
	_linha = ColorRect.new()
	_linha.color = UiTema.DESTAQUE
	_linha.size = Vector2(0, 3)
	trilho.add_child(_linha)
	var dica := UiTema.rotulo("DICA: " + DICAS[randi() % DICAS.size()], 24, UiTema.TEXTO)
	dica.anchor_top = 1.0
	dica.anchor_bottom = 1.0
	dica.anchor_right = 1.0
	dica.offset_left = 48
	dica.offset_right = -48
	dica.offset_top = -100
	dica.offset_bottom = -40
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(dica)


func _process(dt: float) -> void:
	# sem medida de verdade (montar o mundo trava a tela): a linha enche devagar e nunca chega ao fim sozinha
	_t += dt
	var trilho: Control = _linha.get_parent()
	_linha.size.x = trilho.size.x * (1.0 - exp(-_t * 0.6)) * 0.95
