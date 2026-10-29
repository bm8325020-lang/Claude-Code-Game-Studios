# Controles: transforma teclado/mouse (PC) e toque (celular) na `entrada` do Jogador.
# PC: WASD anda, mouse gira a câmera, Shift corre, Alt anda devagar, Ctrl/C agacha, Espaço pula,
# botão esquerdo do mouse golpeia/atira, segurar o botão direito mira, 1/2 escolhe facão/pistola,
# Q troca de arma, R recarrega, Esc solta o mouse.
# Celular: analógico que aparece onde o polegar esquerdo toca; arrastar no lado direito gira a câmera;
# botões ATACAR/ATIRAR, PULAR, CORRER (liga/desliga), AGACHAR, MIRA (canto inferior direito, liga/desliga
# a mira), TROCAR (arma) e RECARREGAR. Mirando ou com a pistola aparece a mira no centro da tela.
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
		if v != null and not toque:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
var toque: bool = false  # mostra os controles de toque

var _stick_id: int = -1
var _stick_centro: Vector2
var _stick_vec: Vector2 = Vector2.ZERO
var _olhar_id: int = -1
var _olhar_ult: Vector2
var _correr_ligado: bool = false
var _base: Control
var _pino: Control
var _btn_correr: Button
var _btn_agachar: Button
var _btn_mira: Button
var _mira: Control
var _btn_atacar: Button
var _btn_recarregar: Button
var _municao: Label
var _vida_fundo: ColorRect
var _vida_barra: ColorRect
var _vermelho: ColorRect
var _caiu: Label
var _relogio: Label
var _btn_pegar: Button
var _btn_comer: Button
var _btn_beber: Button
var _fome_barra: ColorRect
var _sede_barra: ColorRect
var _bolso: Label
var _dica_pegar: Label
var _aviso_item: Label
var _aviso_t: float = 0.0


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
	# barra de vida no alto, no meio
	_vida_fundo = ColorRect.new()
	_vida_fundo.color = Color(0, 0, 0, 0.45)
	_vida_fundo.anchor_left = 0.5
	_vida_fundo.anchor_right = 0.5
	_vida_fundo.offset_left = -160
	_vida_fundo.offset_right = 160
	_vida_fundo.offset_top = 18
	_vida_fundo.offset_bottom = 34
	_vida_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vida_fundo)
	_vida_barra = ColorRect.new()
	_vida_barra.position = Vector2(2, 2)
	_vida_barra.size = Vector2(316, 12)
	_vida_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vida_fundo.add_child(_vida_barra)
	# fome (laranja) e sede (azul): duas barras finas embaixo da vida, e quantas latas/garrafas tem
	_fome_barra = _barrinha(38, Color(0.85, 0.55, 0.2))
	_sede_barra = _barrinha(46, Color(0.35, 0.6, 0.9))
	_bolso = Label.new()
	_bolso.anchor_left = 0.5
	_bolso.anchor_right = 0.5
	_bolso.offset_left = 168
	_bolso.offset_top = 14
	_bolso.add_theme_font_size_override("font_size", 18)
	_bolso.add_theme_color_override("font_outline_color", Color.BLACK)
	_bolso.add_theme_constant_override("outline_size", 5)
	add_child(_bolso)
	_caiu = Label.new()
	_caiu.text = "VOCÊ CAIU"
	_caiu.set_anchors_preset(Control.PRESET_CENTER)
	_caiu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caiu.add_theme_font_size_override("font_size", 46)
	_caiu.add_theme_color_override("font_outline_color", Color.BLACK)
	_caiu.add_theme_constant_override("outline_size", 8)
	_caiu.visible = false
	add_child(_caiu)
	_relogio = Label.new()
	_relogio.anchor_left = 0.5
	_relogio.anchor_right = 0.5
	_relogio.offset_left = -160
	_relogio.offset_right = 160
	_relogio.offset_top = 54
	_relogio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relogio.add_theme_font_size_override("font_size", 20)
	_relogio.add_theme_color_override("font_outline_color", Color.BLACK)
	_relogio.add_theme_constant_override("outline_size", 5)
	add_child(_relogio)
	# "Pegar munição (24)" embaixo do meio da tela quando tem item perto; aviso "+24 munição" ao pegar
	_dica_pegar = _rotulo(22, 0.72)
	_aviso_item = _rotulo(26, 0.62)
	_municao = Label.new()
	_municao.add_theme_font_size_override("font_size", 30)
	_municao.add_theme_color_override("font_outline_color", Color.BLACK)
	_municao.add_theme_constant_override("outline_size", 6)
	_municao.position = Vector2(24, 70)  # abaixo do aviso da partida
	add_child(_municao)
	visible = jogador != null


func _acoes() -> void:
	var mapa: Dictionary = {"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN], "esq": [KEY_A, KEY_LEFT],
		"dir": [KEY_D, KEY_RIGHT], "pular": [KEY_SPACE], "correr": [KEY_SHIFT], "agachar": [KEY_CTRL, KEY_C],
		"andar": [KEY_ALT], "pegar": [KEY_E], "comer": [KEY_F], "beber": [KEY_G], "trocar": [KEY_Q], "recarregar": [KEY_R], "arma_1": [KEY_1], "arma_2": [KEY_2]}
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
		e["correr"] = _correr_ligado
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
		if Input.is_action_just_pressed("arma_1"):
			e["arma"] = "facao"
		if Input.is_action_just_pressed("arma_2"):
			e["arma"] = "pistola"
	if _btn_agachar:
		_btn_agachar.modulate = Color(1, 0.85, 0.4) if jogador.agachado else Color.WHITE
	if _btn_correr:
		_btn_correr.modulate = Color(1, 0.85, 0.4) if _correr_ligado else Color.WHITE
	if _btn_mira:
		_btn_mira.modulate = Color(1, 0.85, 0.4) if jogador.mira_travada else Color.WHITE
	var frac: float = clampf(float(jogador.vida) / Jogador.VIDA_MAX, 0.0, 1.0)
	_vida_barra.size.x = 316.0 * frac
	_vida_barra.color = Color(0.75, 0.12, 0.1) if frac < 0.3 else Color(0.85, 0.82, 0.78)
	_caiu.visible = jogador.vida <= 0
	_fome_barra.size.x = 316.0 * jogador.fome / 100.0
	_sede_barra.size.x = 316.0 * jogador.sede / 100.0
	_fome_barra.modulate.a = 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.006)) if jogador.fome < 15.0 else 1.0
	_sede_barra.modulate.a = 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.006)) if jogador.sede < 15.0 else 1.0
	_bolso.text = "comida %d  água %d" % [jogador.comida, jogador.agua]
	if _btn_comer:
		_btn_comer.visible = jogador.comida > 0 and jogador.fome < 80.0
		_btn_beber.visible = jogador.agua > 0 and jogador.sede < 80.0
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var f: int = int(ciclo.falta())
		_relogio.text = ("NOITE — amanhece em %d:%02d" if ciclo.e_noite() else "DIA — escurece em %d:%02d") % [f / 60, f % 60]
		_relogio.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0) if ciclo.e_noite() else (Color(1, 0.75, 0.4) if f < 60 else Color.WHITE))
	_vermelho.color.a = move_toward(_vermelho.color.a, 0.35 if jogador.vida <= 0 else 0.0, dt * 0.8)
	var it: Item = jogador.item_perto()
	var porta: Porta = jogador.porta_perto() if it == null else null
	_dica_pegar.visible = it != null or porta != null
	if it:
		_dica_pegar.text = ("PEGAR " if toque else "[E] pegar ") + it.nome()
	elif porta:
		_dica_pegar.text = ("USAR: " if toque else "[E] ") + porta.acao()
	if _btn_pegar:
		_btn_pegar.visible = _dica_pegar.visible
		_btn_pegar.text = "PEGAR" if it else "USAR"
	_aviso_t -= dt
	_aviso_item.visible = _aviso_t > 0.0
	_aviso_item.modulate.a = clampf(_aviso_t, 0.0, 1.0)
	var com_pistola: bool = jogador.arma == "pistola"
	_mira.visible = jogador.mira_travada or com_pistola or (_mira as _Mira).marca_t > 0.0
	_municao.visible = com_pistola
	if com_pistola:
		var p: Pistola = jogador.pistola
		_municao.text = ("RECARREGANDO" if p.recarregando else "%d | %d" % [p.balas, p.reserva])
	if _btn_atacar:
		_btn_atacar.text = "ATIRAR" if com_pistola else "ATACAR"
		_btn_recarregar.visible = com_pistola


func _input(ev: InputEvent) -> void:
	if jogador == null:
		return
	if not toque:
		if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			jogador.entrada["olhar"] = (jogador.entrada["olhar"] as Vector2) + (ev as InputEventMouseMotion).relative
		elif ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
			if t.position.x < tela.x * 0.42 and _stick_id == -1:
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


func _barrinha(topo: float, cor: Color) -> ColorRect:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.anchor_left = 0.5
	fundo.anchor_right = 0.5
	fundo.offset_left = -160
	fundo.offset_right = 160
	fundo.offset_top = topo
	fundo.offset_bottom = topo + 6
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var b := ColorRect.new()
	b.color = cor
	b.position = Vector2(2, 1)
	b.size = Vector2(316, 4)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(b)
	return b


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


func _acertou(forte: bool) -> void:
	(_mira as _Mira).marca(forte)


func _pegou(tipo: String, qtd: int) -> void:
	_aviso_item.text = "+%d munição" % qtd if tipo == "municao" else "Lanterna"
	_aviso_t = 1.6


func _levou_dano(dano: int) -> void:
	_vermelho.color.a = clampf(0.15 + dano * 0.012, 0.0, 0.45)


func _em_botao(p: Vector2) -> bool:
	for b: Control in [_btn_correr, _btn_agachar, _btn_mira, _btn_atacar, _btn_recarregar, _btn_pegar, _btn_comer, _btn_beber,
			get_node_or_null("Pular") as Control, get_node_or_null("Trocar") as Control]:
		if b and b.get_global_rect().grow(10).has_point(p):
			return true
	return false


func _monta_toque() -> void:
	_base = _circulo(RAIO_STICK * 2.0, Color(1, 1, 1, 0.18))
	_base.visible = false
	add_child(_base)
	_pino = _circulo(90.0, Color(1, 1, 1, 0.45))
	_base.add_child(_pino)
	_pino.position = _base.size * 0.5 - _pino.size * 0.5
	# MIRA no canto inferior direito; ATACAR grande ao lado; os outros em arco em volta
	_btn_mira = _botao("MIRA", Vector2(-140, -140))
	_btn_mira.button_down.connect(func() -> void:
		jogador.entrada["mirar"] = true
		_correr_ligado = false)
	_btn_atacar = _botao("ATACAR", Vector2(-320, -175), 150.0)
	_btn_atacar.button_down.connect(func() -> void: jogador.entrada["atacar"] = true)
	var trocar := _botao("TROCAR", Vector2(-130, -420), 100.0)
	trocar.name = "Trocar"
	trocar.button_down.connect(func() -> void: jogador.entrada["trocar"] = true)
	_btn_comer = _botao("COMER", Vector2(-140, -560), 90.0)
	_btn_comer.add_theme_font_size_override("font_size", 16)
	_btn_comer.button_down.connect(func() -> void: jogador.entrada["comer"] = true)
	_btn_beber = _botao("BEBER", Vector2(-245, -560), 90.0)
	_btn_beber.add_theme_font_size_override("font_size", 16)
	_btn_beber.button_down.connect(func() -> void: jogador.entrada["beber"] = true)
	_btn_pegar = _botao("PEGAR", Vector2(-620, -175), 110.0)
	_btn_pegar.button_down.connect(func() -> void: jogador.entrada["pegar"] = true)
	_btn_pegar.visible = false
	_btn_recarregar = _botao("RECARREGAR", Vector2(-450, -330), 110.0)
	_btn_recarregar.add_theme_font_size_override("font_size", 16)
	_btn_recarregar.button_down.connect(func() -> void: jogador.entrada["recarregar"] = true)
	var pular := _botao("PULAR", Vector2(-140, -290))
	pular.name = "Pular"
	pular.button_down.connect(func() -> void: jogador.entrada["pular"] = true)
	_btn_agachar = _botao("AGACHAR", Vector2(-290, -335))
	_btn_agachar.button_down.connect(func() -> void:
		jogador.entrada["agachar"] = true
		_correr_ligado = false)
	_btn_correr = _botao("CORRER", Vector2(-470, -140))
	_btn_correr.button_down.connect(func() -> void: _correr_ligado = not _correr_ligado)


func _botao(texto: String, desloc: Vector2, tam: float = BOTAO) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(tam, tam)
	b.size = Vector2(tam, tam)
	b.add_theme_font_size_override("font_size", 22)
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0, 0, 0, 0.35)
	est.set_corner_radius_all(int(tam * 0.5))
	est.border_color = Color(1, 1, 1, 0.5)
	est.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", est)
	b.add_theme_stylebox_override("pressed", est)
	b.add_theme_stylebox_override("hover", est)
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
		var cor := Color(1, 1, 1, 0.9)
		draw_circle(c, 2.5, cor)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * 8.0, c + d * 18.0, cor, 2.5)
		draw_arc(c, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)
		if marca_t > 0.0:
			var a: float = clampf(marca_t / 0.25, 0.0, 1.0)
			var mc := Color(0.95, 0.15, 0.1, a) if marca_forte else Color(1, 1, 1, a)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				draw_line(c + d.normalized() * 10.0, c + d.normalized() * 19.0, mc, 3.0)
