# Tela do baú aberto: uma linha por item (ícone, nome na cor da raridade, quantidade, PEGAR) e PEGAR TUDO.
# Lê o conteúdo do baú a cada quadro (vem do servidor) e fecha sozinha se o jogador se afastar.
class_name TelaBau
extends Control

var jogador: Jogador
var bau: Bau
var _lista: VBoxContainer
var _visto: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTema.tema()
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.75)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var col := UiTema.painel_central(self, 640.0)
	col.add_child(UiTema.titulo("BAÚ", 44, UiTema.DESTAQUE))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 8)
	col.add_child(_lista)
	var tudo := UiTema.botao("PEGAR TUDO", true)
	tudo.pressed.connect(func() -> void: jogador.pega_do_bau(bau, -1))
	col.add_child(tudo)
	var voltar := UiTema.botao_voltar()
	voltar.position = Vector2(36, 28)
	voltar.pressed.connect(func() -> void: visible = false)
	add_child(voltar)


func abre(j: Jogador, b: Bau) -> void:
	jogador = j
	bau = b
	_visto = []
	visible = true
	move_to_front()


func _process(_dt: float) -> void:
	if not visible or bau == null or jogador == null:
		return
	if jogador.bau_perto() != bau:
		visible = false
		return
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
