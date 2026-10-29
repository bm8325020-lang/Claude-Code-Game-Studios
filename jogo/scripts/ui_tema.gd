# Visual único de todas as telas: painéis escuros meio transparentes, cantos retos, um laranja ferrugem de
# destaque, letra grande para o dedo. As telas usam `tema()` na raiz e os atalhos abaixo; nada de estilo solto.
class_name UiTema
extends RefCounted

const FUNDO := Color(0.055, 0.06, 0.065, 0.9)
const PAINEL := Color(0.1, 0.105, 0.11, 0.94)
const BOTAO := Color(0.16, 0.165, 0.17, 0.96)
const DESTAQUE := Color(0.8, 0.4, 0.15)
const TEXTO := Color(0.9, 0.88, 0.84)
const APAGADO := Color(0.58, 0.56, 0.53)
const PERIGO := Color(0.78, 0.2, 0.16)
const LETRA: int = 26
const ALTURA_BOTAO: int = 76  # dedo: acima de 56 px mesmo em tela pequena

static var _tema: Theme


static func tema() -> Theme:
	if _tema:
		return _tema
	var t := Theme.new()
	t.default_font_size = LETRA
	t.set_color("font_color", "Label", TEXTO)
	for estado: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var cor: Color = {"normal": BOTAO, "hover": BOTAO.lightened(0.08), "pressed": DESTAQUE.darkened(0.25),
			"disabled": BOTAO.darkened(0.3), "focus": BOTAO}[estado]
		var c := _caixa(cor, 0)
		c.border_width_bottom = 3
		c.border_color = DESTAQUE if estado in ["hover", "focus"] else cor.darkened(0.35)
		if estado == "focus":
			c.draw_center = false
		t.set_stylebox(estado, "Button", c)
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", APAGADO)
	var campo := _caixa(Color(0.05, 0.05, 0.055, 0.95), 2)
	campo.border_color = APAGADO.darkened(0.3)
	t.set_stylebox("normal", "LineEdit", campo)
	var campo_foco := campo.duplicate() as StyleBoxFlat
	campo_foco.border_color = DESTAQUE
	t.set_stylebox("focus", "LineEdit", campo_foco)
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("font_placeholder_color", "LineEdit", APAGADO)
	var painel := _caixa(PAINEL, 0)
	painel.content_margin_left = 28
	painel.content_margin_right = 28
	painel.content_margin_top = 24
	painel.content_margin_bottom = 24
	t.set_stylebox("panel", "PanelContainer", painel)
	_tema = t
	return t


static func _caixa(cor: Color, borda: int) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = cor
	c.set_border_width_all(borda)
	c.content_margin_left = 18
	c.content_margin_right = 18
	c.content_margin_top = 10
	c.content_margin_bottom = 10
	return c


static func rotulo(texto: String, tam: int = LETRA, cor: Color = TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func botao(texto: String, destaque: bool = false) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	if destaque:
		for estado: String in ["normal", "hover"]:
			var c := _caixa(DESTAQUE if estado == "normal" else DESTAQUE.lightened(0.1), 0)
			c.border_width_bottom = 3
			c.border_color = DESTAQUE.darkened(0.4)
			b.add_theme_stylebox_override(estado, c)
	return b


static func campo(dica: String, valor: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = dica
	e.text = valor
	e.custom_minimum_size = Vector2(0, 68)
	return e


## Painel centralizado na tela (o que a maioria das telas usa). Devolve a coluna onde pôr o conteúdo.
static func painel_central(pai: Node, largura: float = 620.0) -> VBoxContainer:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	pai.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(largura, 0)
	centro.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	return col
