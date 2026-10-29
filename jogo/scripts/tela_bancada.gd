# Tela da bancada (referência do dono: fabricação do Decay): abas de categoria no alto, lista das receitas
# aprendidas (ícone, nome, X1), painel INFORMAÇÕES (ícone, nome, texto, peças — em vermelho as que faltam,
# "1X CANO (X0)"), seletor − xN + MAX e FABRICAR (3 s por unidade, perto da bancada).
class_name TelaBancada
extends Control

var jogador: Jogador
var _aba: String = "ARMAS"
var _sel: String = ""
var _n: int = 1
var _lista: VBoxContainer
var _abas: HBoxContainer
var _nome: Label
var _icone: TextureRect
var _texto: Label
var _pecas: VBoxContainer
var _qtd: Label
var _fabricar: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTema.tema()
	var fundo := ColorRect.new()
	fundo.color = Color(0.2, 0.06, 0.05, 0.92)  # o vermelho escuro da referência
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var voltar := UiTema.botao_voltar()
	voltar.position = Vector2(36, 28)
	voltar.pressed.connect(func() -> void: visible = false)
	add_child(voltar)
	var linha := HBoxContainer.new()
	linha.set_anchors_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 60
	linha.offset_right = -40
	linha.offset_top = 120
	linha.offset_bottom = -30
	linha.add_theme_constant_override("separation", 28)
	add_child(linha)
	_abas = HBoxContainer.new()
	_abas.position = Vector2(150, 40)
	_abas.add_theme_constant_override("separation", 8)
	add_child(_abas)
	for c: String in Receitas.CATEGORIAS:
		var b := UiTema.botao(c)
		b.custom_minimum_size = Vector2(150, 62)
		b.pressed.connect(func() -> void:
			_aba = c
			_sel = ""
			_atualiza())
		_abas.add_child(b)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	linha.add_child(_lista)
	var dir := VBoxContainer.new()
	dir.custom_minimum_size.x = 440
	dir.add_theme_constant_override("separation", 10)
	linha.add_child(dir)
	dir.add_child(UiTema.titulo("INFORMAÇÕES", 34))
	var painel := PanelContainer.new()
	painel.custom_minimum_size.y = 330
	dir.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	painel.add_child(col)
	var topo := HBoxContainer.new()
	col.add_child(topo)
	_icone = TextureRect.new()
	_icone.custom_minimum_size = Vector2(96, 96)
	_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	topo.add_child(_icone)
	_nome = UiTema.titulo("", 30)
	_nome.autowrap_mode = TextServer.AUTOWRAP_OFF
	_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(_nome)
	_texto = UiTema.rotulo("", 22, UiTema.APAGADO)
	col.add_child(_texto)
	_pecas = VBoxContainer.new()
	col.add_child(_pecas)
	var baixo := HBoxContainer.new()
	baixo.add_theme_constant_override("separation", 8)
	dir.add_child(baixo)
	var menos := UiTema.botao("−")
	menos.custom_minimum_size.x = 70
	menos.pressed.connect(func() -> void:
		_n = maxi(1, _n - 1)
		_atualiza())
	baixo.add_child(menos)
	_qtd = UiTema.titulo("X1", 30)
	_qtd.custom_minimum_size.x = 60
	_qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qtd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	baixo.add_child(_qtd)
	var mais := UiTema.botao("+")
	mais.custom_minimum_size.x = 70
	mais.pressed.connect(func() -> void:
		_n += 1
		_atualiza())
	baixo.add_child(mais)
	var maximo := UiTema.botao("MAX")
	maximo.pressed.connect(func() -> void:
		_n = maxi(1, Receitas.quantas(jogador.mochila, _sel)) if _sel != "" else 1
		_atualiza())
	baixo.add_child(maximo)
	_fabricar = UiTema.botao("FABRICAR", true)
	_fabricar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fabricar.pressed.connect(func() -> void:
		if jogador.comeca_fabricar(_sel, _n):
			_atualiza())
	baixo.add_child(_fabricar)
	visibility_changed.connect(func() -> void:
		if visible:
			_n = 1
			_atualiza())


func abre(j: Jogador) -> void:
	jogador = j
	visible = true
	move_to_front()
	if not j.mochila.mudou.is_connected(_atualiza):
		j.mochila.mudou.connect(_atualiza)


func _process(_dt: float) -> void:
	if not visible or jogador == null:
		return
	if jogador.bancada_perto() == null:
		visible = false
		return
	if jogador.fabrica_t > 0.0:
		_fabricar.text = "FABRICANDO %d%%" % roundi((1.0 - jogador.fabrica_t / (Receitas.FABRICAR_T * jogador._fabrica_n)) * 100.0)
		_fabricar.disabled = true
	elif _fabricar.text.begins_with("FABRICANDO"):
		_atualiza()


func _atualiza() -> void:
	if jogador == null:
		return
	for b: Button in _abas.get_children():
		b.modulate = Color(1, 1, 1) if b.text == _aba else Color(0.65, 0.65, 0.65)
	for c in _lista.get_children():
		c.queue_free()
	var minhas: Array = jogador.receitas.filter(func(r: String) -> bool: return Receitas.LISTA[r].categoria == _aba)
	if minhas.is_empty():
		_lista.add_child(UiTema.rotulo("Nenhuma receita aqui. Ache receitas em baús e zumbis e use para aprender.", 24, UiTema.APAGADO))
	if _sel == "" and not minhas.is_empty():
		_sel = minhas[0]
	for r: String in minhas:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 96)
		b.text = String(Mochila.NOMES.get(r, r)).to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiTema.fonte_titulo())
		b.add_theme_font_size_override("font_size", 34)
		var est := StyleBoxFlat.new()
		est.bg_color = Color(0.35, 0.58, 0.65, 0.95) if r == _sel else Color(0.25, 0.26, 0.27, 0.9)
		est.content_margin_left = 110  # espaço do ícone
		b.add_theme_stylebox_override("normal", est)
		b.add_theme_stylebox_override("hover", est)
		b.pressed.connect(func() -> void:
			_sel = r
			_n = 1
			_atualiza())
		var ic := TextureRect.new()
		ic.texture = Icones.de(r)
		ic.custom_minimum_size = Vector2(80, 80)
		ic.position = Vector2(10, 8)
		ic.size = Vector2(80, 80)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		_lista.add_child(b)
	for c in _pecas.get_children():
		c.queue_free()
	_fabricar.text = "FABRICAR"
	if _sel == "":
		_nome.text = ""
		_icone.texture = null
		_texto.text = ""
		_fabricar.disabled = true
		return
	_nome.text = String(Mochila.NOMES.get(_sel, _sel)).to_upper()
	_icone.texture = Icones.de(_sel)
	_texto.text = String(Mochila.TEXTOS.get(_sel, ""))
	var pecas: Dictionary = Receitas.LISTA[_sel].pecas
	for p: String in pecas:
		var precisa: int = int(pecas[p]) * _n
		var tem: int = jogador.mochila.conta(p)
		_pecas.add_child(UiTema.titulo("%dX %s (X%d)" % [precisa, String(Mochila.NOMES.get(p, p)).to_upper(), tem], 26,
			UiTema.TEXTO if tem >= precisa else Color(0.9, 0.3, 0.3)))
	_qtd.text = "X%d" % _n
	_fabricar.disabled = Receitas.quantas(jogador.mochila, _sel) < _n
