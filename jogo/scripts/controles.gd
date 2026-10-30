# Controles: transforma teclado/mouse (PC) e toque (celular) na `entrada` do Jogador.
# PC: WASD anda, mouse gira a câmera, Shift corre, Alt anda devagar, Ctrl/C agacha, Espaço pula,
# botão esquerdo do mouse golpeia/atira, segurar o botão direito mira, 1/2 escolhe facão/pistola,
# Q troca de arma, R recarrega, Esc solta o mouse.
# Celular: analógico que aparece onde o polegar esquerdo toca (empurrado até o fim para a frente = corre);
# arrastar no lado direito gira a câmera. Poucos botões, só com ícone: ATAQUE/TIRO grande, MIRA, PULAR e
# AGACHAR sempre; RECARREGAR, PEGAR e o seletor da submetralhadora só quando servem. Trocar de arma, comer e
# beber: tocando na barra rápida. HUD limpo: barras finas no canto de cima, relógio curto, munição embaixo.
class_name Controles
extends CanvasLayer

const RAIO_STICK: float = 110.0
const BOTAO: float = 120.0

## O jogador controlado; os controles só aparecem (e o mouse só é capturado) quando a partida começa.
var jogador: Jogador:
	set(v):
		if jogador and jogador.dano_levado.is_connected(_levou_dano):
			jogador.dano_levado.disconnect(_levou_dano)
			jogador.item_pego.disconnect(_pegou)
			jogador.acertou_alvo.disconnect(_acertou)
		jogador = v
		visible = v != null
		if v:
			v.dano_levado.connect(_levou_dano)
			v.item_pego.connect(_pegou)
			v.acertou_alvo.connect(_acertou)
			v.bau_aberto.connect(func(b: Bau) -> void: _tela_bau.abre(v, b))
			v.bancada_aberta.connect(func() -> void: _tela_bancada.abre(v))
			v.loja_aberta.connect(func() -> void: _tela_loja.abre(v))
			v.fabricou.connect(func(a: String, n: int) -> void:
				if n > 0:
					aviso("%s fabricada" % String(Mochila.NOMES.get(a, a)), Color(0.35, 0.6, 0.9)))
		if v != null and not toque:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
var toque: bool = false  # mostra os controles de toque

var _stick_id: int = -1
var _stick_centro: Vector2
var _stick_vec: Vector2 = Vector2.ZERO
var _olhar_id: int = -1
var _olhar_ult: Vector2
var _base: Control
var _pino: Control
var _btn_agachar: Button
var _btn_mira: Button
var _mira: Control
var _btn_atacar: _Icone
var _btn_recarregar: _Icone
var _municao: Label
var _vermelho: ColorRect
var _caiu: Label
var _relogio: Label
var _btn_pegar: Button
var _dica_pegar: Label
var _aviso_item: Label
var _aviso_t: float = 0.0
var _faixa: PanelContainer
var _faixa_texto: Label
var _faixa_estilo: StyleBoxFlat
var _barras: Array[_Barra] = []  # vida, fome, sede
var _faixa_t: float = 0.0
var _pausa: Control
var _barra: Array = []  # espaços 1–6 da barra rápida (TelaMochila.Espaco)
var _mochila: TelaMochila
var _tela_bau: TelaBau
var _tela_bancada: TelaBancada
var _tela_loja: TelaLoja
var _saldo: Label
var _btn_modo: Button
var _estilos_toque: Array[StyleBoxFlat] = []  # fundo dos botões de toque (transparência das configurações)


func _ready() -> void:
	_acoes()
	toque = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if toque:
		_monta_toque()
	_mira = _Mira.new()
	_mira.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mira)
	_vermelho = ColorRect.new()
	_vermelho.color = Color(0.6, 0.0, 0.0, 0.0)
	_vermelho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vermelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vermelho)
	# vida, fome e sede: três barras finas no canto de cima à esquerda, e o dinheiro embaixo delas
	for i in 3:
		var barra := _Barra.new()
		barra.tipo = i
		barra.position = Vector2(24, 20 + i * 24)
		barra.size = Vector2(210, 16)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(barra)
		_barras.append(barra)
	_caiu = Label.new()
	_caiu.text = "VOCÊ CAIU"
	_caiu.set_anchors_preset(Control.PRESET_CENTER)
	_caiu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caiu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caiu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caiu.add_theme_font_size_override("font_size", 46)
	_caiu.add_theme_color_override("font_outline_color", Color.BLACK)
	_caiu.add_theme_constant_override("outline_size", 8)
	_caiu.visible = false
	add_child(_caiu)
	_relogio = _rotulo(20, 0.0)  # curto, no alto do meio: "DIA 4:12" / "NOITE 2:30"
	_relogio.offset_top = 14
	_relogio.visible = true
	# "Pegar munição (24)" embaixo do meio da tela quando tem item perto; aviso "+24 munição" ao pegar
	_dica_pegar = _rotulo(22, 0.72)
	_aviso_item = _rotulo(26, 0.62)
	_municao = Label.new()
	_municao.add_theme_color_override("font_outline_color", Color.BLACK)
	_municao.add_theme_constant_override("outline_size", 6)
	_municao.anchor_left = 1.0
	_municao.anchor_right = 1.0
	_municao.anchor_top = 1.0
	_municao.anchor_bottom = 1.0
	_municao.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_municao.offset_left = -420
	_municao.offset_right = -60 if toque else -32  # no celular: acima do botão de tiro
	_municao.offset_top = -380 if toque else -84
	_municao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_municao)
	_monta_aviso()
	_monta_barra_rapida()
	_monta_pausa()
	# letras do tema também no HUD
	for l: Label in [_relogio, _municao, _dica_pegar, _aviso_item]:
		l.add_theme_font_override("font", UiTema.tema().default_font)
	_caiu.add_theme_font_override("font", UiTema.fonte_titulo())
	_caiu.add_theme_font_size_override("font_size", 64)
	_municao.add_theme_font_override("font", UiTema.fonte_titulo())
	_municao.add_theme_font_size_override("font_size", 40)
	visible = jogador != null


func _acoes() -> void:
	var mapa: Dictionary = {"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN], "esq": [KEY_A, KEY_LEFT],
		"dir": [KEY_D, KEY_RIGHT], "pular": [KEY_SPACE], "correr": [KEY_SHIFT], "agachar": [KEY_CTRL, KEY_C],
		"andar": [KEY_ALT], "pegar": [KEY_E], "comer": [KEY_F], "beber": [KEY_G], "trocar": [KEY_Q], "recarregar": [KEY_R], "mochila": [KEY_TAB], "modo": [KEY_B],
		"espaco_1": [KEY_1], "espaco_2": [KEY_2], "espaco_3": [KEY_3], "espaco_4": [KEY_4], "espaco_5": [KEY_5], "espaco_6": [KEY_6]}
	for acao: String in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for k: int in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)


func _process(dt: float) -> void:
	if jogador == null:
		return
	var e: Dictionary = jogador.entrada
	if toque:
		e["move"] = _stick_vec
		e["correr"] = _stick_vec.length() > 0.92 and _stick_vec.y > 0.6 and not jogador.agachado  # polegar no fim, para a frente
	else:
		e["move"] = Vector2(Input.get_axis("esq", "dir"), Input.get_axis("tras", "frente"))
		e["correr"] = Input.is_action_pressed("correr")
		e["andar"] = Input.is_action_pressed("andar")
		if Input.is_action_just_pressed("pular"):
			e["pular"] = true
		if Input.is_action_just_pressed("agachar"):
			e["agachar"] = true
		if Input.is_action_just_pressed("trocar"):
			e["trocar"] = true
		if Input.is_action_just_pressed("pegar"):
			e["pegar"] = true
		if Input.is_action_just_pressed("comer"):
			e["comer"] = true
		if Input.is_action_just_pressed("beber"):
			e["beber"] = true
		if Input.is_action_just_pressed("recarregar"):
			e["recarregar"] = true
		for k in Mochila.BARRA:
			if Input.is_action_just_pressed("espaco_%d" % (k + 1)):
				jogador.usar_espaco(k)
		if Input.is_action_just_pressed("mochila"):
			abre_mochila(not _mochila.visible)
	for i in _barra.size():
		var it: Variant = jogador.mochila.espacos[i]
		_barra[i].destaque = it != null and it.tipo == jogador.arma
		_barra[i].mostra(it, false)
	for est in _estilos_toque:
		est.bg_color.a = float(Config.v.botoes_opacidade)
	if _btn_agachar:
		_btn_agachar.ligado = jogador.agachado
	if _btn_mira:
		_btn_mira.ligado = jogador.mira_travada
	_barras[0].valor = clampf(float(jogador.vida) / Jogador.VIDA_MAX * 100.0, 0.0, 100.0)
	_barras[1].valor = jogador.fome
	_barras[2].valor = jogador.sede
	_caiu.visible = jogador.vida <= 0
	if _caiu.visible:
		_caiu.text = "VOCÊ CAIU\n" + ("voltando em %d s" % ceili(maxf(jogador._morto_t, 0.0)))
	_faixa_t -= dt
	_faixa.visible = _faixa_t > 0.0
	_faixa.modulate.a = clampf(_faixa_t * 2.0, 0.0, 1.0)
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var f: int = int(ciclo.falta())
		_relogio.text = ("NOITE  %d:%02d" if ciclo.e_noite() else "DIA  %d:%02d") % [f / 60, f % 60]
		_relogio.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0) if ciclo.e_noite() else (Color(1, 0.75, 0.4) if f < 60 else Color.WHITE))
	_vermelho.color.a = move_toward(_vermelho.color.a, 0.35 if jogador.vida <= 0 else 0.0, dt * 0.8)
	var it: Item = jogador.item_perto()
	var bau: Bau = jogador.bau_perto() if it == null else null
	var banc: Bancada = jogador.bancada_perto() if it == null and bau == null else null
	var loja: Lojista = jogador.lojista_perto() if it == null and bau == null and banc == null else null
	var porta: Porta = jogador.porta_perto() if it == null and bau == null and banc == null and loja == null else null
	_dica_pegar.visible = it != null or porta != null or bau != null or banc != null or loja != null
	_saldo.text = "$ %d" % jogador.dinheiro
	if jogador.abrindo:
		_dica_pegar.text = "ABRINDO... %d%%" % roundi((1.0 - jogador.abrindo_t / Bau.ABRIR_T) * 100.0)
	elif banc:
		_dica_pegar.text = ("BANCADA" if toque else "[E] usar a bancada")
	elif loja:
		_dica_pegar.text = ("LOJA" if toque else "[E] falar com o lojista")
	elif bau:
		_dica_pegar.text = ("REVISTAR" if toque else "[E] revistar") if bau.saco else ("ABRIR BAÚ" if toque else "[E] abrir baú")
	elif it:
		_dica_pegar.text = ("PEGAR " if toque else "[E] pegar ") + it.nome()
	elif porta:
		_dica_pegar.text = ("USAR: " if toque else "[E] ") + porta.acao()
	if _btn_pegar:
		_btn_pegar.visible = _dica_pegar.visible
	_aviso_t -= dt
	_aviso_item.visible = _aviso_t > 0.0
	_aviso_item.modulate.a = clampf(_aviso_t, 0.0, 1.0)
	var com_pistola: bool = Jogador.e_fogo(jogador.arma)
	_mira.visible = jogador.mira_travada or com_pistola or (_mira as _Mira).marca_t > 0.0
	_municao.visible = com_pistola
	if _btn_modo:
		_btn_modo.visible = jogador.arma == "smg"
		_btn_modo.ligado = jogador.smg.modo_auto
	if not toque:
		e["atirando"] = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if Input.is_action_just_pressed("modo"):
			e["modo"] = true
	if com_pistola:
		var p: Pistola = jogador.fogo()
		_municao.text = ("..." if p.recarregando else "%d / %d" % [p.balas, p.reserva]) + \
			(("  AUTO" if p.modo_auto else "  SEMI") if p.automatica and not toque else "")
		_municao.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25) if p.balas == 0 else Color(1, 1, 1, 0.92))
	if _btn_atacar:
		_btn_atacar.icone = "tiro" if com_pistola else "corte"
		_btn_recarregar.visible = com_pistola and not jogador.fogo().recarregando and jogador.fogo().balas < jogador.fogo().pente and jogador.fogo().reserva > 0


func _input(ev: InputEvent) -> void:
	if jogador == null:
		return
	if (_pausa.visible or _mochila.visible or _tela_bau.visible or _tela_bancada.visible or _tela_loja.visible) and toque:
		return  # na pausa/mochila o toque é dos botões da tela, não do analógico nem da câmera
	if (_mochila.visible or _tela_bau.visible or _tela_bancada.visible or _tela_loja.visible) and ev is InputEventMouseMotion:
		return
	if not toque:
		if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			jogador.entrada["olhar"] = (jogador.entrada["olhar"] as Vector2) + (ev as InputEventMouseMotion).relative
		elif ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
			pausa(not _pausa.visible)
		elif ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				if mb.pressed:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				jogador.entrada["mira_segurando"] = mb.pressed  # segura para mirar
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				jogador.entrada["atacar"] = true
		return
	var tela: Vector2 = get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			if t.position.x < tela.x * 0.42 and _stick_id == -1 and not _em_botao(t.position):
				_stick_id = t.index
				_stick_centro = t.position
				_base.position = t.position - _base.size * 0.5
				_base.visible = true
			elif t.position.x >= tela.x * 0.42 and _olhar_id == -1 and not _em_botao(t.position):
				_olhar_id = t.index
				_olhar_ult = t.position
		else:
			if t.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
				_base.visible = false
			elif t.index == _olhar_id:
				_olhar_id = -1
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if d.index == _stick_id:
			var v: Vector2 = (d.position - _stick_centro).limit_length(RAIO_STICK)
			_pino.position = _base.size * 0.5 + v - _pino.size * 0.5
			_stick_vec = Vector2(v.x, -v.y) / RAIO_STICK
		elif d.index == _olhar_id:
			jogador.entrada["olhar"] = (jogador.entrada["olhar"] as Vector2) + (d.position - _olhar_ult) * 1.6
			_olhar_ult = d.position


func _rotulo(tam: int, altura: float) -> Label:
	var l := Label.new()
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = altura
	l.anchor_bottom = altura
	l.offset_left = -220
	l.offset_right = 220
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l


## Faixa de aviso no alto da tela que some sozinha (servidor, itens, facção...).
## `cor` é a barrinha da esquerda: laranja = aviso, vermelho = perigo, azul = informação.
func aviso(texto: String, cor: Color = UiTema.DESTAQUE, tempo: float = 3.0) -> void:
	_faixa_texto.text = texto.to_upper()
	_faixa_estilo.border_color = cor
	_faixa_t = tempo


## Abre/fecha a pausa. O jogo não para (é em rede): só tira os controles da mão e mostra o mouse.
func pausa(abrir: bool) -> void:
	_pausa.visible = abrir
	if not toque:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if abrir else Input.MOUSE_MODE_CAPTURED
	if jogador and abrir:
		jogador.entrada["move"] = Vector2.ZERO


func _monta_barra_rapida() -> void:
	var caixa := HBoxContainer.new()
	caixa.anchor_left = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_top = 1.0
	caixa.anchor_bottom = 1.0
	var lado: float = 60.0 if toque else 66.0
	caixa.offset_left = -(lado + 6.0) * (Mochila.BARRA + 1) * 0.5 - (150.0 if toque else 0.0)  # celular: longe dos botões
	caixa.offset_top = -lado - 14.0
	caixa.add_theme_constant_override("separation", 6)
	add_child(caixa)
	for i in Mochila.BARRA:
		var e := TelaMochila.Espaco.new()
		e.indice = i
		e.numero = str(i + 1)
		e.pressed.connect(func() -> void:
			if jogador:
				jogador.usar_espaco(i))
		e.lado = lado
		e.discreto = true
		caixa.add_child(e)
		_barra.append(e)
	var b := _Icone.new()
	b.name = "Mochila"
	b.icone = "mochila"
	b.redondo = false
	b.custom_minimum_size = Vector2(lado, lado)
	b.pressed.connect(func() -> void: abre_mochila(not _mochila.visible))
	caixa.add_child(b)
	_mochila = TelaMochila.new()
	_mochila.visible = false
	add_child(_mochila)
	_tela_bau = TelaBau.new()
	_tela_bau.visible = false
	add_child(_tela_bau)
	_tela_loja = TelaLoja.new()
	_tela_loja.visible = false
	add_child(_tela_loja)
	_tela_loja.visibility_changed.connect(func() -> void:
		if not toque:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tela_loja.visible else Input.MOUSE_MODE_CAPTURED)
	_saldo = Label.new()
	_saldo.add_theme_font_override("font", UiTema.fonte_titulo())
	_saldo.add_theme_font_size_override("font_size", 24)
	_saldo.add_theme_color_override("font_color", Color(0.85, 0.8, 0.55))
	_saldo.add_theme_color_override("font_outline_color", Color.BLACK)
	_saldo.add_theme_constant_override("outline_size", 6)
	_saldo.position = Vector2(24, 92)
	add_child(_saldo)
	_tela_bancada = TelaBancada.new()
	_tela_bancada.visible = false
	add_child(_tela_bancada)
	_tela_bancada.visibility_changed.connect(func() -> void:
		if not toque:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tela_bancada.visible else Input.MOUSE_MODE_CAPTURED)
	_tela_bau.visibility_changed.connect(func() -> void:
		if not toque:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tela_bau.visible else Input.MOUSE_MODE_CAPTURED)


## Abre/fecha a tela da mochila (Tab no PC, botão MOCHILA no celular).
func abre_mochila(abrir: bool) -> void:
	_mochila.jogador = jogador
	_mochila.visible = abrir
	_mochila.move_to_front()  # por cima do HUD
	if not toque:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if abrir else Input.MOUSE_MODE_CAPTURED
	if jogador and abrir:
		jogador.entrada["move"] = Vector2.ZERO


func _monta_aviso() -> void:
	_faixa = PanelContainer.new()
	_faixa.theme = UiTema.tema()
	_faixa_estilo = StyleBoxFlat.new()
	_faixa_estilo.bg_color = Color(0.12, 0.13, 0.14, 0.9)
	_faixa_estilo.border_width_left = 6
	_faixa_estilo.content_margin_left = 28
	_faixa_estilo.content_margin_right = 28
	_faixa_estilo.content_margin_top = 12
	_faixa_estilo.content_margin_bottom = 12
	_faixa.add_theme_stylebox_override("panel", _faixa_estilo)
	_faixa.anchor_left = 0.5
	_faixa.anchor_right = 0.5
	_faixa.offset_left = -330
	_faixa.offset_right = 330
	_faixa.offset_top = 96
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.visible = false
	add_child(_faixa)
	_faixa_texto = UiTema.titulo("", 28)
	_faixa_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faixa.add_child(_faixa_texto)


func _monta_pausa() -> void:
	var b := _Icone.new()
	b.icone = "pausa"
	b.name = "Pausa"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -76
	b.offset_right = -20
	b.offset_top = 14
	b.offset_bottom = 70
	b.pressed.connect(func() -> void: pausa(true))
	add_child(b)
	_pausa = Control.new()
	_pausa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pausa.theme = UiTema.tema()
	_pausa.visible = false
	add_child(_pausa)
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.7)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pausa.add_child(fundo)
	var col := UiTema.painel_central(_pausa, 520.0)
	col.add_child(UiTema.rotulo("PAUSA", 34, UiTema.DESTAQUE))
	col.add_child(UiTema.rotulo("O jogo continua para os outros.", 20, UiTema.APAGADO))
	var cont := UiTema.botao("CONTINUAR", true)
	cont.pressed.connect(func() -> void: pausa(false))
	col.add_child(cont)
	var cfg := UiTema.botao("CONFIGURAÇÕES")
	col.add_child(cfg)
	var col_cfg := UiTema.painel_central(_pausa, 760.0)
	col_cfg.add_child(UiTema.titulo("CONFIGURAÇÕES", 40, UiTema.DESTAQUE))
	col_cfg.add_child(TelaConfig.new())
	var volta := UiTema.botao("VOLTAR", true)
	col_cfg.add_child(volta)
	var p_menu: Control = col.get_parent().get_parent()
	var p_cfg: Control = col_cfg.get_parent().get_parent()
	p_cfg.visible = false
	cfg.pressed.connect(func() -> void:
		p_menu.visible = false
		p_cfg.visible = true)
	volta.pressed.connect(func() -> void:
		p_cfg.visible = false
		p_menu.visible = true)
	var sair := UiTema.botao("SAIR DA PARTIDA")
	sair.pressed.connect(func() -> void:
		pausa(false)
		get_tree().get_first_node_in_group("principal")._caiu_conexao(""))
	col.add_child(sair)


func _acertou(forte: bool) -> void:
	(_mira as _Mira).marca(forte)


func _pegou(tipo: String, qtd: int) -> void:
	if tipo == "aprendeu":
		aviso("Receita aprendida", Color(0.35, 0.6, 0.9))
		return
	if tipo == "dinheiro":
		_aviso_item.text = "+$ %d" % qtd
		_aviso_t = 1.2
		return
	if tipo.begins_with("modo_"):
		aviso("Automático" if tipo == "modo_auto" else "Tiro a tiro", Color(0.35, 0.6, 0.9), 1.2)
		return
	var nome: String = String(Mochila.NOMES.get(tipo, tipo))
	_aviso_item.text = ("+%d %s" % [qtd, nome.to_lower()]) if qtd > 1 else nome
	_aviso_t = 1.6


func _levou_dano(dano: int) -> void:
	_vermelho.color.a = clampf(0.15 + dano * 0.012, 0.0, 0.45)


func _em_botao(p: Vector2) -> bool:
	for b: Control in [_btn_agachar, _btn_mira, _btn_atacar, _btn_recarregar, _btn_pegar, get_node_or_null("Pular") as Control,
			get_node_or_null("Pausa") as Control, get_node_or_null("Mochila") as Control, _btn_modo] + _barra:
		if b and b.is_visible_in_tree() and b.get_global_rect().grow(10).has_point(p):
			return true
	return false


# botões de toque em arco em volta do de ataque, no canto de baixo à direita; só ícone, sem texto
func _monta_toque() -> void:
	_base = _circulo(RAIO_STICK * 2.0, Color(1, 1, 1, 0.12))
	_base.visible = false
	add_child(_base)
	_pino = _circulo(80.0, Color(1, 1, 1, 0.35))
	_base.add_child(_pino)
	_pino.position = _base.size * 0.5 - _pino.size * 0.5
	_btn_atacar = _botao("corte", Vector2(-210, -210), 150.0)
	_btn_atacar.button_down.connect(func() -> void:
		jogador.entrada["atacar"] = true
		jogador.entrada["atirando"] = true)
	_btn_atacar.button_up.connect(func() -> void: jogador.entrada["atirando"] = false)
	_btn_mira = _botao("mira", Vector2(-350, -128), 92.0)
	_btn_mira.button_down.connect(func() -> void: jogador.entrada["mirar"] = true)
	var pular := _botao("pular", Vector2(-128, -350), 92.0)
	pular.name = "Pular"
	pular.button_down.connect(func() -> void: jogador.entrada["pular"] = true)
	_btn_agachar = _botao("agachar", Vector2(-300, -300), 80.0)
	_btn_agachar.button_down.connect(func() -> void: jogador.entrada["agachar"] = true)
	_btn_recarregar = _botao("recarga", Vector2(-410, -250), 72.0)
	_btn_recarregar.button_down.connect(func() -> void: jogador.entrada["recarregar"] = true)
	_btn_modo = _botao("modo", Vector2(-410, -350), 72.0)
	_btn_modo.name = "Modo"
	_btn_modo.button_down.connect(func() -> void: jogador.entrada["modo"] = true)
	_btn_modo.visible = false
	_btn_pegar = _botao("pegar", Vector2(-540, -170), 100.0)
	_btn_pegar.button_down.connect(func() -> void: jogador.entrada["pegar"] = true)
	_btn_pegar.visible = false


func _botao(icone: String, desloc: Vector2, tam: float = BOTAO) -> _Icone:
	var k: float = float(Config.v.botoes_tamanho)
	desloc *= k
	tam *= k
	var b := _Icone.new()
	b.icone = icone
	b.custom_minimum_size = Vector2(tam, tam)
	b.size = Vector2(tam, tam)
	_estilos_toque.append(b.estilo)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = desloc.x
	b.offset_top = desloc.y
	b.offset_right = desloc.x + tam
	b.offset_bottom = desloc.y + tam
	add_child(b)
	return b


func _circulo(diam: float, cor: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(diam, diam)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var est := StyleBoxFlat.new()
	est.bg_color = cor
	est.set_corner_radius_all(int(diam * 0.5))
	p.add_theme_stylebox_override("panel", est)
	return p


# mira no centro da tela: ponto + quatro tracinhos
class _Mira:
	extends Control

	## tempo restante da marca de acerto (X em volta do centro)
	var marca_t: float = 0.0
	var marca_forte: bool = false

	func marca(forte: bool) -> void:
		marca_t = 0.25
		marca_forte = forte
		queue_redraw()

	func _process(dt: float) -> void:
		if marca_t > 0.0:
			marca_t -= dt
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var cor := Color(Config.cor_mira(), 0.9)
		draw_circle(c, 2.5, cor)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * 8.0, c + d * 18.0, cor, 2.5)
		draw_arc(c, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)
		if marca_t > 0.0:
			var a: float = clampf(marca_t / 0.25, 0.0, 1.0)
			var mc := Color(0.95, 0.15, 0.1, a) if marca_forte else Color(1, 1, 1, a)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				draw_line(c + d.normalized() * 10.0, c + d.normalized() * 19.0, mc, 3.0)


# barra fina de vida/fome/sede: ícone pequeno à esquerda e a barra; pisca quando está baixa
class _Barra:
	extends Control

	const CORES: Array[Color] = [Color(0.82, 0.84, 0.8), Color(0.85, 0.6, 0.3), Color(0.4, 0.62, 0.85)]
	## 0 vida, 1 fome, 2 sede
	var tipo: int = 0
	var valor: float = 100.0:
		set(v):
			if absf(v - valor) > 0.2 or (v < 20.0) != (valor < 20.0):
				queue_redraw()
			valor = v

	func _process(_dt: float) -> void:
		if valor < 20.0:
			queue_redraw()  # piscando

	func _draw() -> void:
		var h: float = size.y
		var x0: float = h + 8.0
		var w: float = size.x - x0
		var y: float = h * 0.5 - 3.0
		draw_rect(Rect2(x0, y, w, 6), Color(0, 0, 0, 0.45))
		var cor: Color = CORES[tipo]
		if valor < 20.0:
			cor = Color(0.85, 0.2, 0.15)
			cor.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
		draw_rect(Rect2(x0, y, w * clampf(valor / 100.0, 0.0, 1.0), 6), cor)
		_icone(Vector2(h * 0.5, h * 0.5), h * 0.45, Color(cor, 0.95))

	# cruz, garfo e gota em traços simples (sem imagem)
	func _icone(c: Vector2, r: float, b: Color) -> void:
		match tipo:
			0:
				draw_rect(Rect2(c.x - r * 0.3, c.y - r, r * 0.6, r * 2), b)
				draw_rect(Rect2(c.x - r, c.y - r * 0.3, r * 2, r * 0.6), b)
			1:
				draw_line(c + Vector2(0, -r), c + Vector2(0, r), b, 2.0)
				for dx in [-r * 0.5, r * 0.5]:
					draw_line(c + Vector2(dx, -r), c + Vector2(dx, -r * 0.2), b, 1.5)
				draw_line(c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(r * 0.5, -r * 0.2), b, 1.5)
			_:
				draw_circle(c + Vector2(0, r * 0.3), r * 0.62, b)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.1), c + Vector2(r * 0.55, r * 0.1), c + Vector2(0, -r)]), b)


# botão só com ícone desenhado (círculo escuro com borda fina); `ligado` acende (agachado, mira, automático)
class _Icone:
	extends Button

	var icone: String = "":
		set(v):
			if v != icone:
				icone = v
				queue_redraw()
	var ligado: bool = false:
		set(v):
			if v != ligado:
				ligado = v
				queue_redraw()
	var redondo: bool = true
	var estilo := StyleBoxFlat.new()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		estilo.bg_color = Color(0, 0, 0, 0.3)
		estilo.border_color = Color(1, 1, 1, 0.35)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(int(size.x * 0.5) if redondo else 4)
		for e: String in ["normal", "pressed", "hover"]:
			add_theme_stylebox_override(e, estilo)
		button_down.connect(func() -> void: modulate = Color(1, 1, 1, 0.6))
		button_up.connect(func() -> void: modulate = Color.WHITE)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.24
		var b := Color(1.0, 0.78, 0.35) if ligado else Color(1, 1, 1, 0.9)
		var g: float = maxf(2.5, size.x * 0.035)
		match icone:
			"corte":  # lâmina na diagonal com o cabo
				draw_line(c + Vector2(-r, r), c + Vector2(r * 1.1, -r * 1.1), b, g * 2.2)
				draw_line(c + Vector2(-r * 1.3, r * 0.3), c + Vector2(-r * 0.3, r * 1.3), b, g)
			"tiro":  # bala
				draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.3, r * 0.7, r * 1.3), b)
				draw_circle(c + Vector2(0, -r * 0.3), r * 0.35, b)
				draw_rect(Rect2(c.x - r * 0.45, c.y + r * 1.0, r * 0.9, r * 0.2), b)
			"mira":
				draw_arc(c, r, 0, TAU, 32, b, g)
				for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + d * r * 0.4, c + d * r * 1.35, b, g)
			"pular":
				for k in 2:
					var y: float = c.y - r * 0.15 + k * r * 0.7
					draw_polyline(PackedVector2Array([Vector2(c.x - r, y), Vector2(c.x, y - r * 0.8), Vector2(c.x + r, y)]), b, g)
			"agachar":
				draw_polyline(PackedVector2Array([Vector2(c.x - r, c.y - r * 0.5), Vector2(c.x, c.y + r * 0.3), Vector2(c.x + r, c.y - r * 0.5)]), b, g)
				draw_line(Vector2(c.x - r, c.y + r * 0.9), Vector2(c.x + r, c.y + r * 0.9), b, g)
			"recarga":  # seta em volta
				draw_arc(c, r, -PI * 0.35, PI * 1.35, 24, b, g)
				var p: Vector2 = c + Vector2.from_angle(-PI * 0.35) * r
				draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, -r * 0.1), p + Vector2(r * 0.3, -r * 0.45), p + Vector2(r * 0.25, r * 0.4)]), b)
			"modo":  # três balinhas = automático
				for k in 3:
					draw_rect(Rect2(c.x - r + k * r * 0.75, c.y - r * 0.6, r * 0.45, r * 1.2), b if ligado or k == 1 else Color(b, 0.3))
			"pegar":  # seta para baixo entrando na mão aberta
				draw_line(c + Vector2(0, -r * 1.1), c + Vector2(0, r * 0.3), b, g)
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.15), c + Vector2(0, r * 0.35), c + Vector2(r * 0.45, -r * 0.15)]), b, g)
				draw_polyline(PackedVector2Array([c + Vector2(-r, r * 0.4), c + Vector2(-r, r), c + Vector2(r, r), c + Vector2(r, r * 0.4)]), b, g)
			"mochila":
				draw_rect(Rect2(c.x - r, c.y - r * 0.6, r * 2, r * 1.7), b, false, g)
				draw_arc(c + Vector2(0, -r * 0.6), r * 0.5, PI, TAU, 12, b, g)
				draw_line(c + Vector2(-r, r * 0.1), c + Vector2(r, r * 0.1), b, g)
			"pausa":
				draw_rect(Rect2(c.x - r * 0.7, c.y - r * 0.8, r * 0.5, r * 1.6), b)
				draw_rect(Rect2(c.x + r * 0.2, c.y - r * 0.8, r * 0.5, r * 1.6), b)
