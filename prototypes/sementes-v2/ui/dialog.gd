# PROTOTYPE - NOT FOR PRODUCTION
# Conversation window (owner: UI agent): portrait and name of the NPC, their lines (typed out, tap to skip/continue),
# quick choices from the quest system, and a box to ask anything (answered by Claude through ui/npcs.gd).
#
# Use: var dlg := DialogBox.new(); ui_layer.add_child(dlg); dlg.npcs = npcs_node
#   dlg.open(role: String, lines: Array = [], choices: Array = [])   pauses the tree; role = Npcs role id
#        lines: Array[String] said one after the other (e.g. the quest "offer"/"done" text); [] = a greeting line
#        choices: Array of {id: String, text: String} shown after the last line; [] = the NPC's quick questions
#   dlg.say(text: String)                  replace the current line (typed out)
#   dlg.set_choices(choices: Array)        new buttons ({id, text}); quick questions stay after them
#   dlg.close()
#   dlg.context_fn: Callable -> String     game state line for Claude (default: none); e.g.
#        func() -> String: return Npcs.context_line(prog, quests, map.area_name(hero.position))
#   signal choice_made(role: String, id: String)   a quest choice was tapped (quick questions are handled here)
#   signal talked(role: String)                    the player sent a free line (glue may call quests.notify("talk", role))
#   signal closed(role: String)
class_name DialogBox
extends Control

signal choice_made(role: String, id: String)
signal talked(role: String)
signal closed(role: String)

const CPS: float = 55.0   # typed characters per second

var npcs: Npcs
var context_fn: Callable
var role: String = ""
var is_open: bool = false

var _info: Dictionary = {}
var _queue: Array[String] = []
var _choices: Array = []
var _panel: Control
var _portrait: Portrait
var _name: Label
var _title: Label
var _you: Label
var _text: Label
var _more: Label
var _choice_row: HFlowContainer
var _input: LineEdit
var _send: Button
var _was_paused: bool = false
var _typing: float = 0.0
var _waiting: bool = false
var _dots: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Hud.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.0)
	add_child(shade)
	# gradient so the world above stays visible but the panel reads
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.gradient = Gradient.new()
	gt.gradient.set_color(0, Color(0.05, 0.02, 0.01, 0.0))
	gt.gradient.set_color(1, Color(0.05, 0.02, 0.01, 0.7))
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grad.offset_top = -720
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -500
	_panel.offset_bottom = -24
	add_child(_panel)
	var wood := Hud.paper(1, 22.0)
	wood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(wood)
	var page := Hud.paper(0, 14.0)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 14
	page.offset_top = 14
	page.offset_right = -14
	page.offset_bottom = -14
	_panel.add_child(page)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 290)
	m.add_theme_constant_override("margin_right", 44)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 30)
	_panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	_name = _mk_label(40, Hud.INK, true)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	_title = _mk_label(26, Hud.EMBER, false)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var bye := Button.new()
	bye.text = "Adeus"
	bye.custom_minimum_size = Vector2(170, 88)
	bye.pressed.connect(close)
	head.add_child(bye)
	_you = _mk_label(22, Hud.INK_SOFT, false)
	_you.visible = false
	col.add_child(_you)
	_text = _mk_label(32, Hud.INK, false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 120)
	_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_text.gui_input.connect(_on_text_input)
	col.add_child(_text)
	_more = _mk_label(24, Hud.EMBER, true)
	_more.text = "toque para continuar  ▸"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_font_override("font", ThemeDB.fallback_font)
	col.add_child(_more)
	_choice_row = HFlowContainer.new()
	_choice_row.add_theme_constant_override("h_separation", 12)
	_choice_row.add_theme_constant_override("v_separation", 10)
	col.add_child(_choice_row)
	var ask := HBoxContainer.new()
	ask.add_theme_constant_override("separation", 12)
	col.add_child(ask)
	_input = LineEdit.new()
	_input.placeholder_text = "Pergunte o que quiser..."
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 88)
	_input.max_length = 300
	_input.text_submitted.connect(func(_t: String) -> void: _ask())
	ask.add_child(_input)
	_send = Button.new()
	_send.text = "Perguntar"
	_send.custom_minimum_size = Vector2(230, 88)
	_send.pressed.connect(_ask)
	ask.add_child(_send)

	_portrait = Portrait.new()
	_portrait.position = Vector2(26, -70)
	_portrait.size = Vector2(240, 300)
	_panel.add_child(_portrait)


func _mk_label(size: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", Hud.font(true))
	return l


func open(npc_role: String, lines: Array = [], choices: Array = []) -> void:
	if not is_open:
		_was_paused = get_tree().paused
	role = npc_role
	_info = Npcs.info(role)
	is_open = true
	visible = true
	get_tree().paused = true
	_name.text = str(_info.name)
	_title.text = str(_info.title)
	_portrait.set_person(str(_info.name), role)
	_you.visible = false
	_input.text = ""
	_queue.clear()
	for l: Variant in lines:
		_queue.append(str(l))
	if _queue.is_empty():
		_queue.append(str((_info.lines as Array)[0]))
	_choices = choices
	_next_line()


func say(text: String) -> void:
	_queue.clear()
	_show(text)


func set_choices(choices: Array) -> void:
	_choices = choices
	_build_choices()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_input.release_focus()
	get_tree().paused = _was_paused
	closed.emit(role)


func _show(text: String) -> void:
	_text.text = text
	_text.visible_ratio = 0.0
	_typing = 0.0
	_waiting = false
	_build_choices()


func _next_line() -> void:
	if _queue.is_empty():
		return
	_show(_queue.pop_front())


func _build_choices() -> void:
	for c in _choice_row.get_children():
		_choice_row.remove_child(c)
		c.queue_free()
	var more: bool = not _queue.is_empty()
	_more.visible = more
	if more:
		return
	for ch: Variant in _choices:
		if ch is Dictionary:
			var id: String = str(ch.get("id", ""))
			_choice_row.add_child(_choice_button("▸ " + str(ch.get("text", id)), true, func() -> void: choice_made.emit(role, id)))
	var quick: Dictionary = _info.get("quick", {})
	for q: String in quick:
		var ans: String = str(quick[q])
		_choice_row.add_child(_choice_button(q, false, func() -> void:
			_you.text = "Você: " + q
			_you.visible = true
			_show(ans)))


func _choice_button(text: String, quest: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_size_override("font_size", 26)
	if quest:
		var sb := Hud.box(Color(0.66, 0.32, 0.1), Color(0.36, 0.16, 0.05), 3, 12, 14.0, 4)
		sb.border_width_bottom = 7
		b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(cb)
	return b


func _on_text_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if not tap:
		return
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
	elif not _queue.is_empty():
		_next_line()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_on_text_input(_fake_tap())
		get_viewport().set_input_as_handled()


func _fake_tap() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.pressed = true
	return e


func _ask() -> void:
	var line: String = _input.text.strip_edges()
	if line == "" or role == "" or _waiting:
		return
	_input.text = ""
	_input.release_focus()
	_you.text = "Você: " + line
	_you.visible = true
	talked.emit(role)
	if npcs == null:
		_show(str((_info.lines as Array).pick_random()))
		return
	_waiting = true
	_send.disabled = true
	_text.text = "…"
	_text.visible_ratio = 1.0
	var who: String = role
	var ctx: String = str(context_fn.call()) if context_fn.is_valid() else ""
	npcs.ask(who, line, ctx, func(reply: String) -> void:
		_send.disabled = false
		_waiting = false
		if is_open and role == who:
			_show(reply))


func _process(dt: float) -> void:
	if not is_open:
		return
	if _waiting:
		_dots += dt
		_text.text = str(_info.name).split(" ")[0] + " pensa" + ".".repeat(1 + int(_dots * 3.0) % 3)
	elif _text.visible_ratio < 1.0:
		_typing += dt
		var n: int = _text.get_total_character_count()
		_text.visible_ratio = 1.0 if n == 0 else minf(1.0, _typing * CPS / float(n))
	# Android keyboard covers the bottom half in landscape: lift the panel above it
	var kb: float = float(DisplayServer.virtual_keyboard_get_height()) if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0.0
	var lift: float = 0.0
	if kb > 0.0:
		var win: Vector2 = Vector2(DisplayServer.window_get_size())
		lift = kb * get_viewport_rect().size.y / maxf(win.y, 1.0)
	_panel.offset_bottom = lerpf(_panel.offset_bottom, -24.0 - lift, 1.0 - exp(-dt * 18.0))
	_panel.offset_top = _panel.offset_bottom - 476.0


# Medallion with the person's initials and a small emblem of their trade (no 3D render needed).
class Portrait extends Control:
	var initials: String = ""
	var role: String = ""

	func set_person(person: String, r: String) -> void:
		var words: PackedStringArray = person.replace(",", "").split(" ", false)
		var skip: Array[String] = ["Mestra", "Seu", "Vó", "Dona", "Capitão", "Frei", "o", "a", "de"]
		initials = ""
		for w: String in words:
			if not (w in skip) and initials.length() < 2:
				initials += w.left(1).to_upper()
		role = r
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 130)
		var r: float = 112.0
		draw_circle(c + Vector2(0, 8), r + 10.0, Color(0, 0, 0, 0.35))
		draw_circle(c, r + 8.0, Hud.WOOD_DARK)
		draw_circle(c, r, Hud.WOOD)
		draw_arc(c, r - 6.0, 0.0, TAU, 64, Hud.GOLD, 4.0, true)
		draw_circle(c, r - 14.0, Hud.PARCH)
		var col: Color = {"blacksmith": Color(0.55, 0.22, 0.12), "merchant": Color(0.55, 0.42, 0.1), "elder": Color(0.35, 0.3, 0.5),
			"farmer": Color(0.35, 0.45, 0.15), "fisher": Color(0.15, 0.38, 0.5), "guard_captain": Color(0.45, 0.12, 0.1),
			"innkeeper": Color(0.6, 0.25, 0.2), "miner": Color(0.3, 0.27, 0.24), "priest": Color(0.4, 0.33, 0.2)}.get(role, Hud.INK)
		# a little sunset hill behind the letters
		draw_circle(c + Vector2(0, 40), r - 30.0, Color(col, 0.12))
		var f: Font = Hud.font(true)
		draw_string(f, c + Vector2(-r, 30), initials, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 84, col)
		# ribbon under the medallion
		var y: float = c.y + r - 4.0
		var pts := PackedVector2Array([Vector2(c.x - 118, y), Vector2(c.x + 118, y), Vector2(c.x + 100, y + 24),
			Vector2(c.x + 118, y + 48), Vector2(c.x - 118, y + 48), Vector2(c.x - 100, y + 24)])
		draw_colored_polygon(pts, Hud.EMBER.darkened(0.15))
		pts.append(pts[0])
		draw_polyline(pts, Hud.WOOD_DARK, 3.0, true)
		var title: String = str(Npcs.info(role).get("title", "")).to_upper()
		draw_string(Hud.font(true), Vector2(c.x - 110, y + 33), title, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 20, Hud.CREAM)
