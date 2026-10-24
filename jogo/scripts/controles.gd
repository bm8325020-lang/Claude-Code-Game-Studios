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
		jogador = v
		visible = v != null
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


func _ready() -> void:
	_acoes()
	toque = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if toque:
		_monta_toque()
	_mira = _Mira.new()
	_mira.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mira)
	_municao = Label.new()
	_municao.add_theme_font_size_override("font_size", 30)
	_municao.add_theme_color_override("font_outline_color", Color.BLACK)
	_municao.add_theme_constant_override("outline_size", 6)
	_municao.position = Vector2(24, 20)
	add_child(_municao)
	visible = jogador != null


func _acoes() -> void:
	var mapa: Dictionary = {"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN], "esq": [KEY_A, KEY_LEFT],
		"dir": [KEY_D, KEY_RIGHT], "pular": [KEY_SPACE], "correr": [KEY_SHIFT], "agachar": [KEY_CTRL, KEY_C],
		"andar": [KEY_ALT], "trocar": [KEY_Q], "recarregar": [KEY_R], "arma_1": [KEY_1], "arma_2": [KEY_2]}
	for acao: String in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for k: int in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)


func _process(_dt: float) -> void:
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
	var com_pistola: bool = jogador.arma == "pistola"
	_mira.visible = jogador.mira_travada or com_pistola
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


func _em_botao(p: Vector2) -> bool:
	for b: Control in [_btn_correr, _btn_agachar, _btn_mira, _btn_atacar, _btn_recarregar,
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

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var cor := Color(1, 1, 1, 0.9)
		draw_circle(c, 2.5, cor)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * 8.0, c + d * 18.0, cor, 2.5)
		draw_arc(c, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)
