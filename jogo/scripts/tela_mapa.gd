# Mapa grande (dono 07/11: "quando clica no mapa você pode mexer por ele igual GTA e marca onde quer ir"): toque no
# minimapa (ou M) abre; arrastar mexe o mapa, os botões +/- aproximam, um toque sem arrastar marca o destino (Minimapa.destino,
# aparece no minimapa com a distância), LIMPAR tira a marca. Mostra você, os raids (caveira) e os marcos.
# Imagem: assets/mapa/minimapa.png (1 px = 1 m, centro = origem do Bairro).
class_name TelaMapa
extends Control

const METROS_IMG: float = 1024.0
const ARRASTO: float = 12.0  # px: menos que isso é toque (marca), mais é arrasto (mexe)

var jogador: Jogador
var _img: Texture2D
var _centro: Vector2 = Vector2.ZERO   # metros (local do Bairro) no meio da tela
var _zoom: float = 1.2                # px por metro
var _aperto: Vector2 = Vector2.INF   # onde o dedo/mouse desceu
var _ultimo: Vector2
var _arrastou: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_img = load(Minimapa.IMAGEM) if ResourceLoader.exists(Minimapa.IMAGEM) else null
	var barra := HBoxContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	barra.offset_left = -520
	barra.offset_top = 16
	barra.offset_right = -16
	barra.alignment = BoxContainer.ALIGNMENT_END
	barra.add_theme_constant_override("separation", 10)
	add_child(barra)
	for t: Array in [["+", func() -> void: _zoom = minf(_zoom * 1.4, 6.0)], ["-", func() -> void: _zoom = maxf(_zoom / 1.4, 0.5)],
			["LIMPAR", func() -> void: Minimapa.destino = Vector3.INF], ["FECHAR", func() -> void: abre(false)]]:
		var b: Button = UiTema.botao(String(t[0]))
		b.custom_minimum_size = Vector2(96, 64)
		b.pressed.connect(t[1])
		barra.add_child(b)


func abre(sim: bool) -> void:
	visible = sim
	if sim and jogador:
		var p: Vector3 = jogador.global_position - Bairro.ORIGEM
		_centro = Vector2(p.x, p.z)
		move_to_front()
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if sim else Input.MOUSE_MODE_CAPTURED


## metros (local) -> px na tela
func na_tela(m: Vector2) -> Vector2:
	return size * 0.5 + (m - _centro) * _zoom


func _gui_input(ev: InputEvent) -> void:
	var desce: bool = false
	var sobe: bool = false
	var pos := Vector2.ZERO
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		pos = ev.position
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if ev.pressed:
				_zoom = clampf(_zoom * (1.2 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.2), 0.5, 6.0)
			return
		desce = ev.pressed
		sobe = not ev.pressed
	elif ev is InputEventScreenDrag or (ev is InputEventMouseMotion and _aperto.is_finite()):
		pos = ev.position
		if _aperto.is_finite():
			if pos.distance_to(_aperto) > ARRASTO:
				_arrastou = true
			if _arrastou:
				_centro -= (pos - _ultimo) / _zoom
			_ultimo = pos
		accept_event()
		return
	if desce:
		_aperto = pos
		_ultimo = pos
		_arrastou = false
	elif sobe and _aperto.is_finite():
		if not _arrastou:  # toque: marca o destino aqui
			var m: Vector2 = _centro + (pos - size * 0.5) / _zoom
			Minimapa.destino = Bairro.ORIGEM + Vector3(m.x, 0, m.y)
		_aperto = Vector2.INF
	accept_event()


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.08))
	if _img:
		var meia: float = METROS_IMG * 0.5  # a imagem cobre 1024 m (Minimapa.SHADER), qualquer que seja a resolução
		draw_texture_rect(_img, Rect2(na_tela(Vector2(-meia, -meia)), Vector2.ONE * METROS_IMG * _zoom), false)
	var b: Bairro = get_tree().get_first_node_in_group("principal").bairro if get_tree().get_first_node_in_group("principal") else null
	if b:
		for r: Dictionary in b.raids:
			_ponto(r.pos, Minimapa.COR_RAID, 9.0, true)
		for k: String in b.marcos_pos:
			_ponto(b.marcos_pos[k], Minimapa.COR_MARCO, 7.0, false)
	if Minimapa.destino.is_finite():
		var q: Vector2 = _local(Minimapa.destino)
		draw_circle(q, 12, Color(0, 0, 0, 0.85))
		draw_circle(q, 9, Color(1.0, 0.85, 0.15))
		draw_line(q, q + Vector2(0, -26), Color(1.0, 0.85, 0.15), 3.0)
	if jogador:
		var c: Vector2 = _local(jogador.global_position)
		var f: Vector3 = -jogador.global_basis.z
		var a: float = atan2(f.x, -f.z)
		var seta := PackedVector2Array([Vector2(0, -12), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)])
		for i in seta.size():
			seta[i] = c + seta[i].rotated(a)
		draw_colored_polygon(seta, Color.WHITE)
		draw_polyline(seta + PackedVector2Array([seta[0]]), Color.BLACK, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 24), "Arraste para mexer · toque para marcar o destino", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.8))


func _local(w: Vector3) -> Vector2:
	var p: Vector3 = w - Bairro.ORIGEM
	return na_tela(Vector2(p.x, p.z))


func _ponto(w: Vector3, cor: Color, r: float, caveira: bool) -> void:
	var q: Vector2 = _local(w)
	draw_circle(q, r + 2.0, Color(0, 0, 0, 0.85))
	draw_circle(q, r, cor)
	if caveira:
		draw_circle(q + Vector2(-3, -1.5), 1.8, Color.BLACK)
		draw_circle(q + Vector2(3, -1.5), 1.8, Color.BLACK)
