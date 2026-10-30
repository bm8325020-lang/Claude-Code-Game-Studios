# Visual único de todas as telas (referência do dono: Decay): painéis escuros meio transparentes, cantos retos,
# letra condensada (Oswald) e títulos em Bebas Neue espaçados, laranja ferrugem de destaque, letra grande para o
# dedo. As telas usam `tema()` na raiz e os atalhos abaixo; nada de estilo solto. Letras: OFL (assets/fontes).
class_name UiTema
extends RefCounted

const FUNDO := Color(0.055, 0.06, 0.065, 0.9)
const PAINEL := Color(0.1, 0.105, 0.11, 0.94)
const BOTAO := Color(0.16, 0.165, 0.17, 0.96)
const DESTAQUE := Color(0.8, 0.4, 0.15)
const TEXTO := Color(0.9, 0.88, 0.84)
const APAGADO := Color(0.58, 0.56, 0.53)
const PERIGO := Color(0.78, 0.2, 0.16)
const LETRA: int = 23
const ALTURA_BOTAO: int = 60  # dedo: acima de 56 px mesmo em tela pequena

static var _tema: Theme
static var _titulo: FontVariation


## Letra dos títulos: Bebas Neue com espaço entre as letras ("I N F O R M A Ç Õ E S").
static func fonte_titulo() -> Font:
	if _titulo == null:
		_titulo = FontVariation.new()
		_titulo.base_font = load("res://assets/fontes/BebasNeue-Regular.ttf")
		_titulo.spacing_glyph = 3
	return _titulo


static func titulo(texto: String, tam: int = 40, cor: Color = TEXTO) -> Label:
	var l := rotulo(texto, tam, cor)
	l.add_theme_font_override("font", fonte_titulo())
	return l


## Botão redondo de voltar (seta), para o canto de cima à esquerda das telas.
static func botao_voltar() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 84)
	b.focus_mode = Control.FOCUS_NONE
	for estado: String in ["normal", "hover", "pressed"]:
		var c := StyleBoxFlat.new()
		c.bg_color = Color(0, 0, 0, 0.25 if estado != "pressed" else 0.5)
		c.set_corner_radius_all(42)
		c.set_border_width_all(3)
		c.border_color = Color(1, 1, 1, 0.75 if estado == "normal" else 1.0)
		b.add_theme_stylebox_override(estado, c)
	var seta := _Seta.new()
	seta.set_anchors_preset(Control.PRESET_FULL_RECT)
	seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(seta)
	return b


class _Seta:
	extends Control

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var cor := Color(1, 1, 1, 0.85)
		draw_line(c + Vector2(-18, 0), c + Vector2(16, 0), cor, 4.0, true)
		draw_line(c + Vector2(-18, 0), c + Vector2(-6, -12), cor, 4.0, true)
		draw_line(c + Vector2(-18, 0), c + Vector2(-6, 12), cor, 4.0, true)


static func tema() -> Theme:
	if _tema:
		return _tema
	var t := Theme.new()
	var oswald := FontVariation.new()
	oswald.base_font = load("res://assets/fontes/Oswald.ttf")
	oswald.variation_opentype = {"wght": 450}
	oswald.spacing_glyph = 1
	t.default_font = oswald
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
	var painel := _caixa(PAINEL, 1)
	painel.border_color = Color(DESTAQUE, 0.25)
	painel.set_corner_radius_all(16)
	painel.shadow_color = Color(0, 0, 0, 0.45)
	painel.shadow_size = 18
	painel.content_margin_left = 26
	painel.content_margin_right = 26
	painel.content_margin_top = 20
	painel.content_margin_bottom = 20
	t.set_stylebox("panel", "PanelContainer", painel)
	# chave (pública/privada) e lista de opções com a mesma cara dos botões
	for tipo: String in ["CheckButton", "OptionButton"]:
		for estado: String in ["normal", "hover", "pressed", "focus"]:
			var c := _caixa(BOTAO if estado != "hover" else BOTAO.lightened(0.08), 0)
			c.draw_center = estado != "focus"
			t.set_stylebox(estado, tipo, c)
		t.set_color("font_color", tipo, TEXTO)
		t.set_color("font_pressed_color", tipo, TEXTO)
		t.set_color("font_hover_color", tipo, Color.WHITE)
		t.set_color("font_hover_pressed_color", tipo, Color.WHITE)
	# barra de rolagem fina e laranja (dá para arrastar o conteúdo com o dedo também)
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color(1, 1, 1, 0.06)
	trilho.set_corner_radius_all(4)
	trilho.content_margin_left = 6
	trilho.content_margin_right = 6
	var pega := StyleBoxFlat.new()
	pega.bg_color = Color(DESTAQUE, 0.8)
	pega.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", trilho)
	t.set_stylebox("grabber", "VScrollBar", pega)
	t.set_stylebox("grabber_highlight", "VScrollBar", pega)
	t.set_stylebox("grabber_pressed", "VScrollBar", pega)
	var menu := _caixa(PAINEL.lightened(0.05), 1)
	menu.border_color = Color(DESTAQUE, 0.3)
	t.set_stylebox("panel", "PopupMenu", menu)
	t.set_font_size("font_size", "PopupMenu", LETRA)
	_tema = t
	return t


static func _caixa(cor: Color, borda: int) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = cor
	c.set_border_width_all(borda)
	c.content_margin_left = 18
	c.content_margin_right = 18
	c.content_margin_top = 8
	c.content_margin_bottom = 8
	c.set_corner_radius_all(10)
	c.anti_aliasing = true
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
	e.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	return e


## Painel centralizado na tela (o que a maioria das telas usa). Devolve a coluna onde pôr o conteúdo.
static func painel_central(pai: Node, largura: float = 620.0) -> VBoxContainer:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	pai.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(largura, 0)
	centro.add_child(p)
	# rola quando não cabe na tela (celular deitado é baixo); a altura acompanha o conteúdo até 90% da tela
	var rola := ScrollContainer.new()
	rola.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(rola)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rola.add_child(col)
	col.set_meta("pagina", centro)
	var ajusta := func() -> void:
		if col.is_inside_tree():
			rola.custom_minimum_size.y = minf(col.get_combined_minimum_size().y, col.get_viewport_rect().size.y * 0.9 - 40.0)
	col.minimum_size_changed.connect(ajusta)
	col.tree_entered.connect(ajusta, CONNECT_DEFERRED)
	col.resized.connect(ajusta)
	return col


## Duas colunas lado a lado dentro de `col` (tela deitada: usa a largura em vez da altura). Devolve [esquerda, direita].
static func duas_colunas(col: Control, separacao: int = 28) -> Array[VBoxContainer]:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separacao)
	col.add_child(h)
	var r: Array[VBoxContainer] = []
	for i in 2:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 10)
		h.add_child(v)
		r.append(v)
	return r


## Título pequeno de seção (laranja, com uma linha embaixo).
static func secao(texto: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(rotulo(texto, 19, DESTAQUE))
	var linha := ColorRect.new()
	linha.color = Color(DESTAQUE, 0.25)
	linha.custom_minimum_size = Vector2(0, 2)
	v.add_child(linha)
	return v


## A página inteira (o que se mostra/esconde) de uma coluna feita por painel_central.
static func pagina(col: Control) -> Control:
	return col.get_meta("pagina")
