# Tela do lojista: à esquerda o que ele vende (COMPRAR), à direita o que você tem e quanto ele paga (VENDER).
# Saldo no alto. Tudo no aparelho por enquanto (dinheiro e mochila vão para o servidor com a conta, prompt 16).
class_name TelaLoja
extends Control

var jogador: Jogador
var _saldo: Label
var _comprar: VBoxContainer
var _vender: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTema.tema()
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.94)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var voltar := UiTema.botao_voltar()
	voltar.position = Vector2(36, 28)
	voltar.pressed.connect(func() -> void: visible = false)
	add_child(voltar)
	_saldo = UiTema.titulo("", 40, UiTema.DESTAQUE)
	_saldo.position = Vector2(150, 40)
	add_child(_saldo)
	var linha := HBoxContainer.new()
	linha.set_anchors_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 60
	linha.offset_right = -40
	linha.offset_top = 120
	linha.offset_bottom = -30
	linha.add_theme_constant_override("separation", 40)
	add_child(linha)
	var c1 := VBoxContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_child(UiTema.titulo("COMPRAR", 34))
	_comprar = VBoxContainer.new()
	_comprar.add_theme_constant_override("separation", 8)
	c1.add_child(_comprar)
	linha.add_child(c1)
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.add_child(UiTema.titulo("VENDER", 34))
	var rolar := ScrollContainer.new()
	rolar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vender = VBoxContainer.new()
	_vender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vender.add_theme_constant_override("separation", 8)
	rolar.add_child(_vender)
	c2.add_child(rolar)
	linha.add_child(c2)


func abre(j: Jogador) -> void:
	jogador = j
	visible = true
	move_to_front()
	if not j.mochila.mudou.is_connected(_atualiza):
		j.mochila.mudou.connect(_atualiza)
	_atualiza()


func _process(_dt: float) -> void:
	if visible and jogador and jogador.lojista_perto() == null:
		visible = false


func _linha(pai: Control, tipo: String, texto: String, preco: String, botao: String, acao: Callable, pode: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var ic := TextureRect.new()
	ic.texture = Icones.de(tipo)
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var n := UiTema.rotulo(texto, 22)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	var p := UiTema.titulo(preco, 28, UiTema.DESTAQUE)
	p.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(p)
	var b := UiTema.botao(botao)
	b.custom_minimum_size = Vector2(150, 64)
	b.disabled = not pode
	b.pressed.connect(func() -> void:
		acao.call()
		_atualiza())
	h.add_child(b)
	pai.add_child(h)


func _atualiza() -> void:
	if jogador == null:
		return
	_saldo.text = "$ %d" % jogador.dinheiro
	for c in _comprar.get_children() + _vender.get_children():
		c.queue_free()
	for t: String in Lojista.VENDE:
		var v: Array = Lojista.VENDE[t]
		_linha(_comprar, t, "%s  X%d" % [Mochila.NOMES.get(t, t), v[0]], "$ %d" % v[1], "COMPRAR",
			func() -> void: jogador.comprar(t), jogador.dinheiro >= int(v[1]))
	for i in Mochila.ESPACOS:
		var e: Variant = jogador.mochila.espacos[i]
		if e == null or e.tipo in Mochila.PRESOS or Lojista.paga(e.tipo, 1) <= 0:
			continue
		_linha(_vender, e.tipo, "%s  X%d" % [Mochila.NOMES.get(e.tipo, e.tipo), e.qtd], "$ %d" % Lojista.paga(e.tipo, int(e.qtd)), "VENDER",
			func() -> void: jogador.vender(i), true)
	if _vender.get_child_count() == 0:
		_vender.add_child(UiTema.rotulo("Nada para vender.", 22, UiTema.APAGADO))
