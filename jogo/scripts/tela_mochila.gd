# Tela da mochila (referência do dono: Decay): à esquerda o nome e fome/sede; no meio "INVENTÁRIO" com a grade
# (espaços 7–24) e a barra rápida 1–6 embaixo; à direita o painel do item (nome, quantidade, ícone, texto,
# USAR / LARGAR / DIVIDIR). Toque num espaço seleciona; tocando em outro com um selecionado, move/junta.
class_name TelaMochila
extends Control

const COLUNAS: int = 6

var jogador: Jogador
var _espacos: Array[Espaco] = []
var _sel: int = -1
var _nome: Label
var _qtd: Label
var _icone: TextureRect
var _texto: Label
var _usar: Button
var _largar: Button
var _dividir: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # já dentro da árvore: âncoras e margens juntas
	theme = UiTema.tema()
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.94)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var voltar := UiTema.botao_voltar()
	voltar.position = Vector2(36, 28)
	voltar.pressed.connect(func() -> void: visible = false)
	add_child(voltar)
	var linha := HBoxContainer.new()
	linha.set_anchors_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 140
	linha.offset_right = -30
	linha.offset_top = 40
	linha.offset_bottom = -30
	linha.add_theme_constant_override("separation", 24)
	add_child(linha)
	# esquerda: nome e status
	var esq := VBoxContainer.new()
	esq.custom_minimum_size.x = 120
	esq.add_theme_constant_override("separation", 14)
	linha.add_child(esq)
	_status = UiTema.rotulo("", 24)
	esq.add_child(_status)
	# meio: grade + barra rápida
	var meio := VBoxContainer.new()
	meio.add_theme_constant_override("separation", 10)
	linha.add_child(meio)
	meio.add_child(UiTema.titulo("INVENTÁRIO", 40, UiTema.TEXTO))
	var grade := GridContainer.new()
	grade.columns = COLUNAS
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	meio.add_child(grade)
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 10)
	var sep := Control.new()
	sep.custom_minimum_size.y = 14
	_espacos.resize(Mochila.ESPACOS)
	for i in range(Mochila.BARRA, Mochila.ESPACOS):
		_espacos[i] = _novo_espaco(i, grade)
	meio.add_child(sep)
	meio.add_child(barra)
	for i in Mochila.BARRA:
		_espacos[i] = _novo_espaco(i, barra)
	# direita: painel do item
	var dir := PanelContainer.new()
	dir.custom_minimum_size = Vector2(330, 0)
	dir.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	linha.add_child(dir)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	dir.add_child(col)
	var topo := HBoxContainer.new()
	col.add_child(topo)
	_nome = UiTema.titulo("", 36)
	_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_nome)
	_qtd = UiTema.titulo("", 24, UiTema.APAGADO)
	_qtd.autowrap_mode = TextServer.AUTOWRAP_OFF
	topo.add_child(_qtd)
	_icone = TextureRect.new()
	_icone.custom_minimum_size = Vector2(0, 140)
	_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(_icone)
	_texto = UiTema.rotulo("", 22, UiTema.APAGADO)
	col.add_child(_texto)
	var bots := HBoxContainer.new()
	bots.add_theme_constant_override("separation", 10)
	col.add_child(bots)
	_usar = _bot(bots, "USAR", func() -> void:
		jogador.usar_espaco(_sel)
		if _sel >= 0 and jogador.mochila.espacos[_sel] and (Armas.e_branca(jogador.mochila.espacos[_sel].tipo) or jogador.mochila.espacos[_sel].tipo == "pistola"):
			visible = false)
	_largar = _bot(bots, "LARGAR", func() -> void:
		jogador.largar(_sel)
		_sel = -1)
	_dividir = _bot(bots, "DIVIDIR", func() -> void: jogador.mochila.dividir(_sel))
	visibility_changed.connect(func() -> void:
		_sel = -1
		if visible:
			_atualiza())


func _bot(pai: Control, t: String, acao: Callable) -> Button:
	var b := UiTema.botao(t)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(acao)
	pai.add_child(b)
	return b


func _novo_espaco(i: int, pai: Control) -> Espaco:
	var e := Espaco.new()
	e.lado = 82.0
	e.indice = i
	e.numero = str(i + 1) if i < Mochila.BARRA else ""
	e.pressed.connect(_toque.bind(i))
	pai.add_child(e)
	return e


func _toque(i: int) -> void:
	if _sel >= 0 and _sel != i:
		jogador.mochila.mover(_sel, i)
		_sel = -1
	else:
		_sel = i if jogador.mochila.espacos[i] != null else -1
	_atualiza()


func _process(_dt: float) -> void:
	if visible and jogador:
		_status.text = "%s\n\nFOME  %d\nSEDE  %d\nVIDA  %d" % [jogador.nick.to_upper(), roundi(jogador.fome), roundi(jogador.sede), jogador.vida]


func _atualiza() -> void:
	if jogador == null:
		return
	if not jogador.mochila.mudou.is_connected(_atualiza):
		jogador.mochila.mudou.connect(_atualiza)
	for i in Mochila.ESPACOS:
		_espacos[i].mostra(jogador.mochila.espacos[i], i == _sel)
	var e: Variant = jogador.mochila.espacos[_sel] if _sel >= 0 else null
	_nome.text = String(Mochila.NOMES.get(e.tipo, e.tipo)).to_upper() if e else "TOQUE NUM ITEM"
	_qtd.text = "X%d" % e.qtd if e else ""
	_icone.texture = Icones.de(e.tipo) if e else null
	_texto.text = String(Mochila.TEXTOS.get(e.tipo, "")) if e else "Toque num item para ver. Com um item escolhido, toque em outro espaço para mover."
	_usar.disabled = e == null or not (Armas.e_branca(e.tipo) or e.tipo in ["pistola", "comida", "agua"])
	_largar.disabled = e == null or e.tipo in Mochila.PRESOS
	_dividir.disabled = e == null or int(e.qtd) < 2


## Um quadrado da mochila/barra: ícone do item, número no canto de cima e quantidade "X3" embaixo.
class Espaco:
	extends Button

	var indice: int = 0
	var numero: String = ""
	var _item: Variant = null
	var _sel: bool = false
	var destaque: bool = false  # barra do HUD: arma na mão
	var lado: float = 96.0

	func _ready() -> void:
		custom_minimum_size = Vector2(lado, lado)
		focus_mode = Control.FOCUS_NONE
		for estado: String in ["normal", "hover", "pressed"]:
			var c := StyleBoxFlat.new()
			c.bg_color = Color(0.32, 0.33, 0.34, 0.85)
			add_theme_stylebox_override(estado, c)

	func mostra(item: Variant, selecionado: bool) -> void:
		_item = item
		_sel = selecionado
		queue_redraw()

	func _draw() -> void:
		if _sel or destaque:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.5, 0.7, 0.9))
		if _item:
			draw_texture_rect(Icones.de(String(_item.tipo)), Rect2(size * 0.08, size * 0.84), false)
			if int(_item.qtd) > 1:
				var f: Font = UiTema.tema().default_font
				draw_string(f, Vector2(size.x - 44, size.y - 8), "X%d" % int(_item.qtd), HORIZONTAL_ALIGNMENT_RIGHT, 40, 20, Color(1, 1, 1, 0.95))
		if numero != "":
			var f2: Font = UiTema.fonte_titulo()
			draw_string(f2, Vector2(8, 24), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.9))
