# Tela do baú aberto: uma linha por item (ícone, nome na cor da raridade, quantidade, PEGAR) e PEGAR TUDO.
# Lê o conteúdo do baú a cada quadro (vem do servidor) e fecha sozinha se o jogador se afastar.
class_name TelaBau
extends Control

var jogador: Jogador
var bau: Bau
var _lista: VBoxContainer
var _visto: Array = []
var _titulo: Label
var _guardar: VBoxContainer  # baú da facção: o que tem na mochila, com GUARDAR
var _mochila_vista: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTema.tema()
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.75)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var col := UiTema.painel_central(self, 640.0)
	_titulo = UiTema.titulo("BAÚ", 44, UiTema.DESTAQUE)
	col.add_child(_titulo)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 8)
	col.add_child(_lista)
	var tudo := UiTema.botao("PEGAR TUDO", true)
	tudo.pressed.connect(func() -> void: jogador.pega_do_bau(bau, -1))
	col.add_child(tudo)
	_guardar = VBoxContainer.new()
	_guardar.add_theme_constant_override("separation", 6)
	col.add_child(_guardar)
	var voltar := UiTema.botao_voltar()
	voltar.position = Vector2(36, 28)
	voltar.pressed.connect(func() -> void: visible = false)
	add_child(voltar)


func abre(j: Jogador, b: Bau) -> void:
	jogador = j
	bau = b
	_visto = []
	visible = true
	_titulo.text = "MOCHILA NO CHÃO" if b.saco else ("BAÚ DA FACÇÃO" if b.de_faccao else "BAÚ")
	_mochila_vista = []
	move_to_front()


func _process(_dt: float) -> void:
	if not visible or bau == null or jogador == null:
		return
	if jogador.bau_perto() != bau:
		visible = false
		return
	_lista_guardar()
	if bau.conteudo == _visto:
		return
	_visto = bau.conteudo.duplicate(true)
	for c in _lista.get_children():
		c.queue_free()
	if _visto.is_empty():
		_lista.add_child(UiTema.rotulo("Vazio.", 24, UiTema.APAGADO))
	for i in _visto.size():
		var e: Dictionary = _visto[i]
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 14)
		var ic := TextureRect.new()
		ic.texture = Icones.de(String(e.tipo))
		ic.custom_minimum_size = Vector2(72, 72)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		linha.add_child(ic)
		var nome := UiTema.titulo(String(Mochila.NOMES.get(e.tipo, e.tipo)).to_upper(), 28, Loot.CORES[Loot.raridade(String(e.tipo))])
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		linha.add_child(nome)
		var q := UiTema.titulo("X%d" % int(e.qtd), 28, UiTema.APAGADO)
		q.autowrap_mode = TextServer.AUTOWRAP_OFF
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		linha.add_child(q)
		var b := UiTema.botao("PEGAR")
		b.custom_minimum_size.x = 150
		b.pressed.connect(func() -> void: jogador.pega_do_bau(bau, i))
		linha.add_child(b)
		_lista.add_child(linha)


# baú da facção: os itens da mochila (menos os presos) com GUARDAR
func _lista_guardar() -> void:
	_guardar.visible = bau.de_faccao
	if not bau.de_faccao:
		return
	var agora: Array = jogador.mochila.espacos.map(func(e: Variant) -> Variant: return null if e == null else [e.tipo, e.qtd])
	if agora == _mochila_vista:
		return
	_mochila_vista = agora
	for c in _guardar.get_children():
		c.queue_free()
	_guardar.add_child(UiTema.rotulo("GUARDAR DA MOCHILA", 22, UiTema.APAGADO))
	for i in jogador.mochila.espacos.size():
		var e: Variant = jogador.mochila.espacos[i]
		if e == null or e.tipo in Mochila.PRESOS:
			continue
		var b := UiTema.botao("GUARDAR  %s  X%d" % [String(Mochila.NOMES.get(e.tipo, e.tipo)).to_upper(), int(e.qtd)])
		b.pressed.connect(func() -> void: jogador.guarda_no_bau(bau, i))
		_guardar.add_child(b)
