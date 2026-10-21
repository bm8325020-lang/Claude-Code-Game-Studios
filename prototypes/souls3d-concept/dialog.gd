# PROTOTYPE - NOT FOR PRODUCTION
# The conversation window: the NPC's name and words, quick questions, a box to ask anything (answered by Claude
# through npcs.gd), and the smith's and merchant's services. The world is paused while it is open.
extends Control

var main: Node
var npc: Dictionary
var title: Label
var text: Label
var quick_row: HBoxContainer
var input: LineEdit
var send: Button

func setup(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	theme = Theme.new()
	theme.default_font_size = 34
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -470
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.03, 0.92)
	sb.border_color = Color(0.6, 0.45, 0.25)
	sb.border_width_top = 3
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.4))
	col.add_child(title)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(0, 130)
	text.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	col.add_child(text)
	quick_row = HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 12)
	col.add_child(quick_row)
	var ask_row := HBoxContainer.new()
	ask_row.add_theme_constant_override("separation", 12)
	col.add_child(ask_row)
	input = LineEdit.new()
	input.placeholder_text = "Pergunte o que quiser..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 80)
	input.text_submitted.connect(func(_t): _ask())
	ask_row.add_child(input)
	send = _button("FALAR", _ask)
	ask_row.add_child(send)
	ask_row.add_child(_button("ADEUS", close_dialog))

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(180, 80)
	b.pressed.connect(cb)
	return b

func open_with(p: Dictionary) -> void:
	npc = p
	visible = true
	main.get_tree().paused = true
	main.ui.visible = false
	title.text = p.name + "  ·  " + p.role
	text.text = p.quick.values()[0]
	_quick_buttons()

func _quick_buttons() -> void:
	for c in quick_row.get_children():
		c.queue_free()
	for q in npc.quick:
		quick_row.add_child(_button(q, func(): _quick(q)))

func _quick(q: String) -> void:
	var a: String = npc.quick[q]
	if a == "__smith":
		close_dialog()
		main.smith_open = true
		main.menu.open("gear")
	elif a == "__shop":
		_shop()
	else:
		text.text = a

func _shop() -> void:
	for c in quick_row.get_children():
		c.queue_free()
	text.text = "Titanita: 300 brasas. Fragmento de Seiva: 1500 brasas, só tenho um. Você tem %d brasas." % main.embers
	quick_row.add_child(_button("Titanita (300)", func():
		if main.embers >= 300:
			main.embers -= 300
			main.titanite += 1
			text.text = "Pedra boa. Tente não morrer antes de usar. (Titanita: %d)" % main.titanite
		else:
			text.text = "Sem brasas, sem pedra."))
	if not main.has_meta("bought_shard"):
		quick_row.add_child(_button("Seiva (1500)", func():
			if main.embers >= 1500 and not main.has_meta("bought_shard"):
				main.embers -= 1500
				main.set_meta("bought_shard", true)
				main.max_flasks += 1
				main.flasks += 1
				text.text = "Mais um gole entre você e a morte. (Frascos: %d)" % main.max_flasks
			else:
				text.text = "Volte quando tiver as brasas."))
	quick_row.add_child(_button("Voltar", _quick_buttons))

func _ask() -> void:
	var line := input.text.strip_edges()
	if line == "" or npc.is_empty():
		return
	input.text = ""
	send.disabled = true
	text.text = "..."
	var who := npc
	main.npcs.ask(who, line, func(reply: String):
		send.disabled = false
		if visible and npc == who:
			text.text = reply)

func close_dialog() -> void:
	visible = false
	main.get_tree().paused = false
	main.ui.visible = true
	main._save()
