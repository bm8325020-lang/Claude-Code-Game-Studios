# Tela de configurações (a mesma no menu e na pausa): controles deslizantes e chaves que mudam e salvam na hora.
class_name TelaConfig
extends ScrollContainer


func _ready() -> void:
	custom_minimum_size = Vector2(0, 430)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_secao(col, "CONTROLE")
	_desliza(col, "Sensibilidade", "sens", 0.05, 0.6, 0.01)
	_desliza(col, "Mirando com a pistola", "sens_mira_pistola", 0.2, 1.5, 0.05, true)
	_desliza(col, "Mirando com o facão", "sens_mira_facao", 0.2, 1.5, 0.05, true)
	_chave(col, "Inverter olhar para cima/baixo", "inverter_y")
	_desliza(col, "Campo de visão", "fov", 60.0, 90.0, 1.0)
	_secao(col, "SOM")
	_desliza(col, "Volume", "volume", 0.0, 1.0, 0.05, true)
	_secao(col, "IMAGEM")
	_chave(col, "Sombras", "sombras")
	_desliza(col, "Resolução 3D", "resolucao", 0.5, 1.0, 0.05, true)
	_escolhe(col, "Quadros por segundo", "fps", ["30", "60"], [30, 60])
	_secao(col, "TELA DE TOQUE")
	_desliza(col, "Tamanho dos botões", "botoes_tamanho", 0.7, 1.4, 0.05, true)
	_desliza(col, "Transparência dos botões", "botoes_opacidade", 0.1, 0.8, 0.05, true)
	_escolhe(col, "Cor da mira", "mira_cor", Config.NOMES_MIRA, [0, 1, 2, 3])
	var b := UiTema.botao("VOLTAR AO PADRÃO")
	b.pressed.connect(func() -> void:
		Config.padrao(get_tree())
		for c in get_children():
			c.queue_free()
		_ready())
	col.add_child(b)


func _secao(col: VBoxContainer, t: String) -> void:
	col.add_child(UiTema.titulo(t, 30, UiTema.DESTAQUE))


func _linha(col: VBoxContainer, t: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UiTema.rotulo(t, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	col.add_child(h)
	return h


func _desliza(col: VBoxContainer, t: String, chave: String, mini: float, maxi: float, passo: float, porcento: bool = false) -> void:
	var h := _linha(col, t)
	var s := HSlider.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = passo
	s.value = float(Config.v[chave])
	s.custom_minimum_size = Vector2(260, 56)
	h.add_child(s)
	var n := UiTema.rotulo("", 22, UiTema.APAGADO)
	n.custom_minimum_size.x = 70
	h.add_child(n)
	var mostra := func(x: float) -> void: n.text = ("%d%%" % roundi(x * 100.0)) if porcento else str(snappedf(x, passo))
	mostra.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		mostra.call(x)
		Config.muda(chave, x, get_tree()))


func _chave(col: VBoxContainer, t: String, chave: String) -> void:
	var h := _linha(col, t)
	var c := CheckButton.new()
	c.button_pressed = bool(Config.v[chave])
	c.toggled.connect(func(on: bool) -> void: Config.muda(chave, on, get_tree()))
	h.add_child(c)


func _escolhe(col: VBoxContainer, t: String, chave: String, nomes: Array, valores: Array) -> void:
	var h := _linha(col, t)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(170, 56)
	for i in nomes.size():
		o.add_item(String(nomes[i]), i)
	o.selected = maxi(0, valores.find(Config.v[chave]))
	o.item_selected.connect(func(i: int) -> void: Config.muda(chave, valores[i], get_tree()))
	h.add_child(o)
