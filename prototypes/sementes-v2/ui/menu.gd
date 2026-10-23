# PROTOTYPE - NOT FOR PRODUCTION
# Pause menu (owner: UI agent): Personagem (attributes, spend points), Inventário (equip/use), Missões (follow one),
# Mapa (painted from the map's places, roads and river), Opções (volume, camera sensitivity, Claude API key).
#
# Use:  var menu := GameMenu.new(); ui_layer.add_child(menu); menu.bind(progression, quests, items, map)
#   menu.open(tab: String = "char")   tabs: "char", "inv", "quests", "map", "options"; pauses the tree
#   menu.close() / menu.toggle()      close restores the pause state it found; Esc/Start/the menu action closes too
#   menu.player: Node3D               optional, for the "você está aqui" marker and the camera-relative map
#   signal closed
#   signal item_used(id: String, heal: int)     a consumable was used from the bag: glue heals the hero by heal
#   signal options_changed                      after any option changes (already saved and applied)
# Options are static and persist in user://sementes2_options.json (GameMenu.load_options() runs on first use):
#   GameMenu.options = {music: 0..1, sfx: 0..1, sens: 0.3..2.5, api_key: String, ai_model: String}
#   Volumes go to the "Music" and "SFX" audio buses when they exist (music falls back to "Master").
#   The API key never leaves the device except in requests to api.anthropic.com (ui/npcs.gd); never logged.
class_name GameMenu
extends Control

signal closed
signal item_used(id: String, heal: int)
signal options_changed

const OPTIONS_PATH: String = "user://sementes2_options.json"
const TABS: Array = [["char", "PERSONAGEM"], ["inv", "INVENTÁRIO"], ["quests", "MISSÕES"], ["map", "MAPA"], ["options", "OPÇÕES"]]
const KIND_NAME: Dictionary = {"weapon": "Arma", "shield": "Escudo", "outfit": "Roupa", "consumable": "Consumível",
	"seed": "Semente do Dragão", "quest": "Item de missão", "material": "Material", "keepsake": "Lembrança"}

static var options: Dictionary = {"music": 0.8, "sfx": 0.9, "sens": 1.0, "api_key": "", "ai_model": "claude-opus-5-5",
	"auto_points": true}
static var _loaded: bool = false

var prog: Progression
var quests: Quests
var items: Items
var map: Object
var player: Node3D
var tab: String = "char"
var is_open: bool = false

var _body: MarginContainer
var _tab_buttons: Dictionary = {}
var _was_paused: bool = false
var _sel_item: String = ""
var _show_key: bool = false


static func load_options() -> void:
	_loaded = true
	if FileAccess.file_exists(OPTIONS_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(OPTIONS_PATH))
		if d is Dictionary:
			for k: String in options:
				if (d as Dictionary).has(k):
					options[k] = d[k]
	apply_options()


static func save_options() -> void:
	var f := FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(options))


static func apply_options() -> void:
	var music: int = AudioServer.get_bus_index("Music")
	if music < 0:
		music = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(music, linear_to_db(maxf(float(options.music), 0.0001)))
	var sfx: int = AudioServer.get_bus_index("SFX")
	if sfx >= 0:
		AudioServer.set_bus_volume_db(sfx, linear_to_db(maxf(float(options.sfx), 0.0001)))
	Touch.sensitivity = float(options.sens)


static func api_key() -> String:
	if not _loaded:
		load_options()
	return str(options.api_key).strip_edges()


func bind(p: Progression, q: Quests, i: Items, m: Object = null) -> void:
	prog = p
	quests = q
	items = i
	map = m


func _ready() -> void:
	if not _loaded:
		load_options()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Hud.ui_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(outer, 56, 36)
	add_child(outer)
	var frame := _layered(outer, Hud.paper(1, 26.0), 20)
	var page := _layered(frame, Hud.paper(0, 14.0), 0)
	var inner := MarginContainer.new()
	_margins(inner, 34, 22)
	page.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	inner.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	for t: Array in TABS:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 28)
		var id: String = t[0]
		b.pressed.connect(func() -> void: show_tab(id))
		bar.add_child(b)
		_tab_buttons[id] = b
	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(110, 92)
	x.add_theme_font_size_override("font_size", 40)
	x.add_theme_font_override("font", ThemeDB.fallback_font)
	x.pressed.connect(close)
	bar.add_child(x)
	col.add_child(_rule())
	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)


# a margin container with a full-size background behind its content
func _layered(parent: Control, bg: Control, margin: int) -> MarginContainer:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(m, margin, margin)
	holder.add_child(m)
	return m


func _margins(m: MarginContainer, h: int, v: int) -> void:
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)


func open(which: String = "char") -> void:
	if not is_open:
		_was_paused = get_tree().paused
	is_open = true
	visible = true
	get_tree().paused = true
	show_tab(which)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = _was_paused
	save_options()
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open(tab)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func show_tab(which: String) -> void:
	tab = which
	for k: String in _tab_buttons:
		var b: Button = _tab_buttons[k]
		if k == tab:
			var sb := Hud.box(Color(0.66, 0.32, 0.1), Hud.WOOD_DARK, 3, 12, 14.0, 4)
			sb.border_width_bottom = 7
			sb.border_color = Color(0.36, 0.16, 0.05)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_color_override("font_color")
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match tab:
		"char":
			_tab_char()
		"inv":
			_tab_inv()
		"quests":
			_tab_quests()
		"map":
			_tab_map()
		"options":
			_tab_options()


func _refresh() -> void:
	if is_open:
		show_tab(tab)


# ------------------------------------------------------------------ small builders
func _label(text: String, size: int = 28, col: Color = Hud.INK, bold: bool = false, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", Hud.font(true))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _card(parent: Control, highlight: bool = false) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := Hud.box(Color(0.99, 0.95, 0.84, 0.55) if not highlight else Color(1.0, 0.9, 0.62, 0.8),
		Color(Hud.WOOD, 0.55) if not highlight else Hud.EMBER, 2 if not highlight else 3, 10, 18.0)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(Hud.WOOD, 0.45)
	r.custom_minimum_size = Vector2(0, 3)
	return r


func _bar(frac: float, col: Color, h: float = 18.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.value = clampf(frac, 0.0, 1.0)
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("background", Hud.box(Color(Hud.WOOD_DARK, 0.85), Color.TRANSPARENT, 0, 6))
	b.add_theme_stylebox_override("fill", Hud.box(col, Color.TRANSPARENT, 0, 6))
	return b


func _stat_row(parent: Control, name: String, value: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var n := _label(name, 26, Hud.INK_SOFT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(_label(value, 26, Hud.INK, true))


func _scroll(parent: Control) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	s.add_child(v)
	return v


func _columns(ratio: Array[float]) -> Array[VBoxContainer]:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	_body.add_child(h)
	var out: Array[VBoxContainer] = []
	for r: float in ratio:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_stretch_ratio = r
		v.add_theme_constant_override("separation", 12)
		h.add_child(v)
		out.append(v)
	return out


func _missing(what: String) -> void:
	_body.add_child(_label("(%s ainda não está ligado ao jogo)" % what, 28, Hud.INK_SOFT))


# ------------------------------------------------------------------ Personagem
func _tab_char() -> void:
	if prog == null:
		_missing("Progressão")
		return
	var cols := _columns([1.0, 1.25])
	var left := _card(cols[0])
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_label("Pé-Molhado", 44, Hud.INK, true))
	left.add_child(_label("Forasteiro das Terras Frias", 24, Hud.INK_SOFT))
	left.add_child(_rule())
	var need: int = Progression.xp_to_next(prog.level)
	left.add_child(_label("Nível %d" % prog.level, 32, Hud.EMBER, true))
	left.add_child(_bar(float(prog.xp) / float(need), Hud.GOLD, 20.0))
	left.add_child(_label("%d / %d XP para o próximo nível" % [prog.xp, need], 22, Hud.INK_SOFT))
	var armor: int = items.armor() if items != null else 0
	var st: Dictionary = prog.stats(armor)
	_stat_row(left, "Vida máxima", str(roundi(float(st.max_hp))))
	_stat_row(left, "Estamina máxima", str(roundi(float(st.max_stamina))))
	var dmg: int = items.weapon_damage() if items != null else Items.UNARMED_DMG
	_stat_row(left, "Dano do golpe", str(roundi(dmg * float(st.dmg_mult))))
	_stat_row(left, "Armadura", str(armor))
	if items != null and items.block_mult() > 0.0:
		_stat_row(left, "Bloqueio", "%d%%" % roundi(items.block_mult() * 100.0))
	_stat_row(left, "Ouro", str(prog.gold))
	_stat_row(left, "Sementes do Dragão", "%d / %d" % [prog.seeds.size(), Progression.SEEDS_TOTAL])
	var right := cols[1]
	var head := HBoxContainer.new()
	right.add_child(head)
	var t := _label("Atributos", 36, Hud.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var pts := _label(("%d ponto%s para gastar" % [prog.points, "" if prog.points == 1 else "s"]) if prog.points > 0
		else "Suba de nível para ganhar pontos", 26, Hud.EMBER if prog.points > 0 else Hud.INK_SOFT, prog.points > 0)
	head.add_child(pts)
	for a: String in Progression.ATTRS:
		var row := _card(right, false)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		row.add_child(h)
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_constant_override("separation", 0)
		h.add_child(txt)
		txt.add_child(_label(str(Progression.ATTR_NAME[a]), 30, Hud.INK, true))
		txt.add_child(_label(str(Progression.ATTR_DESC[a]), 22, Hud.INK_SOFT))
		var v := _label(str(prog.attrs[a]), 44, Hud.INK, true)
		v.custom_minimum_size = Vector2(70, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(v)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(96, 84)
		plus.add_theme_font_size_override("font_size", 44)
		plus.disabled = prog.points <= 0
		plus.pressed.connect(func() -> void:
			if prog.spend_point(a):
				_refresh())
		h.add_child(plus)
	var sk: Array[String] = []
	for id: String in prog.unlocks:
		if Progression.UNLOCKS.has(id):
			sk.append(str(Progression.UNLOCKS[id].name))
	right.add_child(_label("Aprendido: " + (", ".join(sk) if not sk.is_empty() else "nada ainda. O vale vai ensinar."),
		22, Hud.INK_SOFT, false, true))


# ------------------------------------------------------------------ Inventário
func _tab_inv() -> void:
	if items == null:
		_missing("Inventário")
		return
	var cols := _columns([1.0, 1.6])
	cols[0].add_child(_label("Equipado", 34, Hud.INK, true))
	for sl: Array in [["weapon", "Arma", "mãos vazias"], ["shield", "Escudo", "nenhum"], ["outfit", "Roupa", "—"]]:
		var id: String = str(items.slots.get(sl[0], ""))
		var c := _card(cols[0], id != "" and id == _sel_item)
		c.add_child(_label(str(sl[1]).to_upper(), 20, Hud.EMBER, true))
		c.add_child(_label(Items.item_name(id) if id != "" else str(sl[2]), 28, Hud.INK if id != "" else Hud.INK_SOFT, true))
		var d: Dictionary = Items.def(id)
		var info: String = ""
		if d.has("dmg"):
			info = "Dano %d" % int(d.dmg)
		elif d.has("block"):
			info = "Para %d%% do golpe" % roundi(float(d.block) * 100.0)
		elif d.has("armor"):
			info = "Armadura %d" % int(d.armor)
		if info != "":
			c.add_child(_label(info, 22, Hud.INK_SOFT))
	# detail of the selected item, under the slots
	var det := _card(cols[0], true) if _sel_item != "" and items.has(_sel_item) else null
	if det != null:
		var d: Dictionary = Items.def(_sel_item)
		det.add_child(_label(Items.item_name(_sel_item), 30, Hud.INK, true))
		det.add_child(_label(str(d.get("desc", "")), 22, Hud.INK_SOFT, false, true))
		if d.has("memory"):
			det.add_child(_label("Lembrança: " + str(d.memory), 22, Hud.EMBER, false, true))
		if d.has("heal"):
			det.add_child(_label("Cura %d de vida" % int(d.heal), 22, Hud.INK))
		var slot: String = Items.slot_of(_sel_item)
		var act := Button.new()
		act.custom_minimum_size = Vector2(0, 84)
		if slot != "":
			var on: bool = str(items.slots.get(slot, "")) == _sel_item
			act.text = "Tirar" if on else "Equipar"
			act.disabled = on and slot == "outfit"
			act.pressed.connect(func() -> void:
				if on:
					items.unequip(slot)
				else:
					items.equip(_sel_item)
				_refresh())
			det.add_child(act)
		var price: int = items.sell_price(_sel_item)
		if price > 0:
			var sell := Button.new()
			sell.custom_minimum_size = Vector2(0, 72)
			sell.text = "Vender (+%d ouro)" % price
			sell.pressed.connect(func() -> void:
				items.sell(_sel_item, prog)
				if not items.has(_sel_item):
					_sel_item = ""
				_refresh())
			det.add_child(sell)
		if slot != "":
			pass
		elif str(d.get("kind", "")) == "consumable":
			act.text = "Usar"
			act.pressed.connect(func() -> void:
				var heal: int = items.use(_sel_item)
				if heal > 0:
					item_used.emit(_sel_item, heal)
				if not items.has(_sel_item):
					_sel_item = ""
				_refresh())
			det.add_child(act)
	var head := HBoxContainer.new()
	cols[1].add_child(head)
	var t := _label("Bolsa", 34, Hud.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var dup := Button.new()
	dup.text = "Vender comuns repetidos"
	dup.custom_minimum_size = Vector2(0, 64)
	dup.pressed.connect(func() -> void:
		var g: int = items.sell_duplicate_commons(prog)
		dup.text = ("+%d ouro" % g) if g > 0 else "Nada repetido"
		_refresh())
	head.add_child(dup)
	var list := _scroll(cols[1])
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	list.add_child(grid)
	var entries: Array = items.list()
	var order: Array[String] = ["weapon", "shield", "outfit", "consumable", "seed", "quest", "material", "keepsake"]
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return order.find(str(x.kind)) < order.find(str(y.kind)) or (x.kind == y.kind and str(x.name) < str(y.name)))
	for e: Dictionary in entries:
		grid.add_child(_item_tile(e))
	if entries.is_empty():
		list.add_child(_label("A bolsa está vazia.", 26, Hud.INK_SOFT))


func _item_tile(e: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel: bool = str(e.id) == _sel_item
	var bg: Color = Color(1, 0.97, 0.88, 0.75) if not sel else Color(1, 0.88, 0.6)
	var sb := Hud.box(bg, Hud.EMBER if (sel or e.equipped) else Color(Hud.WOOD, 0.5), 3 if (sel or e.equipped) else 2, 10, 12.0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 10
	v.offset_right = -12
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var kind: String = str(e.kind)
	var rar: String = str(e.get("rarity", ""))
	var top_col: Color = Hud.EMBER if (kind == "seed" or e.equipped) else Hud.INK_SOFT
	if rar != "" and rar != "comum":
		top_col = (Loot.COLOR[rar] as Color).darkened(0.35)  # loot rarity reads at a glance on parchment
	var top := _label(str(KIND_NAME.get(kind, kind)).to_upper() + ("  · " + str(Loot.NAME[rar]).to_upper() if rar != "" else "")
		+ ("  · EQUIPADO" if e.equipped else ""), 17, top_col, true)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var n := _label(str(e.name) + ("  ×%d" % int(e.count) if int(e.count) > 1 else ""), 25, Hud.INK, true)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var id: String = str(e.id)
	b.pressed.connect(func() -> void:
		_sel_item = "" if _sel_item == id else id
		_refresh())
	return b


# ------------------------------------------------------------------ Missões
func _tab_quests() -> void:
	if quests == null:
		_missing("Missões")
		return
	var list := _scroll(_body)
	var cur: Dictionary = quests.current()
	var j: Array = quests.journal()
	var done: Array = j.filter(func(e: Dictionary) -> bool: return e.state == "done")
	var open_q: Array = j.filter(func(e: Dictionary) -> bool: return e.state != "done")
	if open_q.is_empty():
		list.add_child(_label("Nenhuma missão em aberto. Converse com os moradores.", 28, Hud.INK_SOFT))
	for e: Dictionary in open_q:
		var following: bool = str(cur.get("id", "")) == str(e.id)
		var c := _card(list, following)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		c.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		v.add_child(_label(("PRINCIPAL" if e.kind == "main" else "SECUNDÁRIA") + ("  ·  NOVA" if e.state == "offered" else ""),
			18, Hud.EMBER, true))
		v.add_child(_label(str(e.title), 32, Hud.INK, true))
		var text: String = str(cur.get("text", e.text)) if following else str(e.text)
		v.add_child(_label(text, 24, Hud.INK_SOFT, false, true))
		if e.state == "active":
			var q: Dictionary = Quests.quest(str(e.id))
			var at: int = int(quests.step_i.get(str(e.id), 0))
			var steps: Array = q.get("steps", [])
			var parts: PackedStringArray = []
			for i in steps.size():
				parts.append(("✓ " if i < at else ("▸ " if i == at else "· ")) + str(Quests.step_of(q, i).text))
			var sl := _label("\n".join(parts), 21, Color(Hud.INK_SOFT, 0.85), false, true)
			v.add_child(sl)
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 84)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.text = "Seguindo" if following else "Seguir"
		b.disabled = following
		var id: String = str(e.id)
		b.pressed.connect(func() -> void:
			quests.track(id)
			_refresh())
		h.add_child(b)
	if not done.is_empty():
		list.add_child(_label("Concluídas", 30, Hud.INK_SOFT, true))
		for e: Dictionary in done:
			list.add_child(_label("✓  " + str(e.title), 26, Color(Hud.INK_SOFT, 0.8)))


# ------------------------------------------------------------------ Mapa
func _tab_map() -> void:
	var cols := _columns([1.0, 2.2])
	var c := _card(cols[0])
	c.add_child(_label("Vale de Lume", 34, Hud.INK, true))
	var here: String = ""
	if map != null and player != null and is_instance_valid(player) and map.has_method("area_name"):
		here = str(map.call("area_name", player.global_position))
	c.add_child(_label("Você está em: " + (here if here != "" else "estrada aberta"), 24, Hud.INK_SOFT, false, true))
	if quests != null:
		var q: Dictionary = quests.current()
		if not q.is_empty():
			c.add_child(_rule())
			c.add_child(_label("★  " + str(q.title), 26, Hud.EMBER, true, true))
			c.add_child(_label(str(q.text), 23, Hud.INK_SOFT, false, true))
	c.add_child(_rule())
	c.add_child(_label("▲  você        ● lugar        ★ objetivo", 21, Hud.INK_SOFT, false, true))
	var mv := MapView.new()
	mv.menu = self
	mv.clip_contents = true
	mv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols[1].add_child(mv)


class MapView extends Control:
	const WORLD: Rect2 = Rect2(-300, -380, 760, 760)  # the valley plus the Pastos da Cauda to the east
	var menu: GameMenu

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _to(r: Rect2, x: float, z: float) -> Vector2:
		return r.position + Vector2((x - WORLD.position.x) / WORLD.size.x, (z - WORLD.position.y) / WORLD.size.y) * r.size

	func _draw() -> void:
		var side: float = minf(size.x, size.y)
		var frame := Rect2((size.x - side) * 0.5, 0, side, side)
		draw_style_box(Hud.box(Color(0.9, 0.8, 0.6), Hud.WOOD, 4, 8, 0.0, 0), frame)
		var r := frame.grow(-6)
		var fb: Font = Hud.font(true)
		var m: Object = menu.map
		# relief hints: mountains along the north, hills south
		var col_m := Color(0.48, 0.36, 0.24, 0.55)
		for i in 15:
			var x: float = -290.0 + i * 41.0
			var p := _to(r, x, -262.0 + 8.0 * sin(i * 1.7))
			var hgt: float = 26.0 + 10.0 * sin(i * 2.3)
			draw_polyline(PackedVector2Array([p + Vector2(-22, 0), p + Vector2(0, -hgt), p + Vector2(22, 0)]), col_m, 3.0, true)
			draw_line(p + Vector2(0, -hgt), p + Vector2(8, -hgt * 0.4), col_m, 2.0, true)
		if m == null:
			draw_string(fb, r.get_center() + Vector2(-200, 0), "(mapa ainda não carregado)", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 28, Hud.INK_SOFT)
			return
		# river and lake
		var river: Array = m.get("river_ctrl") if m.get("river_ctrl") is Array else []
		if river.size() > 1:
			var pts := PackedVector2Array()
			for v: Vector3 in river:
				pts.append(_to(r, v.x, v.z))
			draw_polyline(pts, Color(0.35, 0.55, 0.68, 0.9), 9.0, true)
			draw_polyline(pts, Color(0.55, 0.75, 0.85, 0.9), 4.0, true)
		for p: Dictionary in m.get("places"):
			if str(p.id) == "lake":
				var c := _to(r, p.pos.x, p.pos.z)
				var rad: float = float(p.radius) / WORLD.size.x * r.size.x
				draw_circle(c, rad * 0.75, Color(0.45, 0.66, 0.78, 0.9))
				draw_arc(c, rad * 0.75, 0.0, TAU, 48, Color(0.3, 0.45, 0.55), 3.0, true)
			if str(p.id) == "forest":
				var c := _to(r, p.pos.x, p.pos.z)
				for i in 22:
					var o := Vector2(sin(i * 2.4) * 70.0 + cos(i * 1.3) * 30.0, cos(i * 3.1) * 70.0)
					var tc := c + o * (r.size.x / 1000.0)
					draw_colored_polygon(PackedVector2Array([tc + Vector2(0, -16), tc + Vector2(10, 6), tc + Vector2(-10, 6)]),
						Color(0.35, 0.45, 0.22, 0.75))
		# roads as dashed ink
		var roads: Array = m.get("road_defs") if m.get("road_defs") is Array else []
		for rd: Dictionary in roads:
			var pts := PackedVector2Array()
			for v: Vector2 in rd.pts:
				pts.append(_to(r, v.x, v.y))
			for i in pts.size() - 1:
				draw_dashed_line(pts[i], pts[i + 1], Color(0.45, 0.3, 0.15, 0.85), 3.0, 10.0, true)
		# places
		var target: Variant = null
		if menu.quests != null:
			target = Hud.quest_pos(menu.quests.current(), m)
		for p: Dictionary in m.get("places"):
			var c := _to(r, p.pos.x, p.pos.z)
			draw_circle(c, 12.0, Hud.WOOD_DARK)
			draw_circle(c, 8.0, Hud.EMBER if str(p.id) == "castle" else Hud.PARCH)
			var name: String = str(p.name)
			var w: float = fb.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			var lp := c + Vector2(-w * 0.5, -20)
			lp.x = clampf(lp.x, r.position.x + 8.0, r.end.x - w - 8.0)
			draw_string_outline(fb, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0.95, 0.88, 0.7, 0.9))
			draw_string(fb, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Hud.INK)
		if target is Vector3:
			var t := _to(r, (target as Vector3).x, (target as Vector3).z)
			var star := PackedVector2Array()
			for i in 10:
				star.append(t + Vector2.from_angle(-PI * 0.5 + i * TAU / 10.0) * (20.0 if i % 2 == 0 else 8.0))
			draw_colored_polygon(star, Hud.GOLD)
			star.append(star[0])
			draw_polyline(star, Hud.WOOD_DARK, 2.0, true)
		if menu.player != null and is_instance_valid(menu.player):
			var pp: Vector3 = menu.player.global_position
			var c := _to(r, pp.x, pp.z)
			var fwd: Vector3 = -menu.player.global_basis.z
			var ang: float = Vector2(fwd.x, fwd.z).angle()
			draw_circle(c, 24.0, Color(0.9, 0.2, 0.1, 0.25))
			var tri := PackedVector2Array([c + Vector2.from_angle(ang) * 22.0, c + Vector2.from_angle(ang + 2.4) * 15.0,
				c + Vector2.from_angle(ang - 2.4) * 15.0])
			draw_colored_polygon(tri, Color(0.75, 0.12, 0.08))
			tri.append(tri[0])
			draw_polyline(tri, Hud.CREAM, 2.5, true)
		# compass rose
		var cr := Vector2(r.end.x - 70, r.end.y - 80)
		draw_circle(cr, 40.0, Color(0.95, 0.88, 0.7, 0.6))
		for i in 4:
			var a: float = -PI * 0.5 + i * PI * 0.5
			draw_colored_polygon(PackedVector2Array([cr + Vector2.from_angle(a) * 36.0, cr + Vector2.from_angle(a + 0.5) * 9.0,
				cr + Vector2.from_angle(a - 0.5) * 9.0]), Hud.INK if i == 0 else Hud.INK_SOFT)
		draw_string(fb, cr + Vector2(-20, -44), "N", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, Hud.INK)
		draw_style_box(Hud.box(Color.TRANSPARENT, Hud.WOOD, 4, 8), frame)


# ------------------------------------------------------------------ Opções
func _tab_options() -> void:
	var cols := _columns([1.0, 1.25])
	cols[0].add_child(_label("Som e controles", 34, Hud.INK, true))
	_slider(cols[0], "Música", "music", 0.0, 1.0, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_slider(cols[0], "Efeitos", "sfx", 0.0, 1.0, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_slider(cols[0], "Sensibilidade da câmera", "sens", 0.3, 2.5, func(v: float) -> String: return "%.1f×" % v)
	var auto := CheckButton.new()
	auto.text = "Distribuir pontos sozinho"
	auto.add_theme_font_size_override("font_size", 26)
	auto.custom_minimum_size = Vector2(0, 72)
	auto.button_pressed = bool(options.get("auto_points", true))
	auto.toggled.connect(func(on: bool) -> void:
		options.auto_points = on
		save_options())
	cols[0].add_child(auto)
	var c := _card(cols[1])
	c.add_child(_label("Conversa livre com os moradores", 32, Hud.INK, true))
	c.add_child(_label("Os moradores do vale podem responder qualquer pergunta usando o Claude, da Anthropic. Para isso, "
		+ "cole aqui a sua própria chave da API Anthropic (começa com sk-ant-). A chave fica guardada só neste aparelho e "
		+ "só é enviada para a Anthropic, na hora da conversa. Cada conversa usa créditos da sua conta. Sem chave, os "
		+ "moradores respondem com falas prontas.", 23, Hud.INK_SOFT, false, true))
	var key := LineEdit.new()
	key.placeholder_text = "sk-ant-..."
	key.secret = not _show_key
	key.text = str(options.api_key)
	key.custom_minimum_size = Vector2(0, 84)
	key.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if not _show_key else LineEdit.KEYBOARD_TYPE_DEFAULT
	c.add_child(key)
	var status := _label("", 22, Hud.INK_SOFT, false, true)
	var upd := func() -> void:
		var k: String = str(options.api_key)
		if k == "":
			status.text = "Nenhuma chave salva."
		elif k.begins_with("sk-ant-"):
			status.text = "Chave salva neste aparelho (termina em …%s)." % k.right(4)
		else:
			status.text = "Isso não parece uma chave da Anthropic (deveria começar com sk-ant-)."
	key.text_changed.connect(func(t: String) -> void:
		options.api_key = t.strip_edges()
		save_options()
		upd.call())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	for spec: Array in [["Colar", "paste"], ["Mostrar" if not _show_key else "Esconder", "show"], ["Apagar", "clear"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var what: String = spec[1]
		b.pressed.connect(func() -> void:
			match what:
				"paste":
					options.api_key = DisplayServer.clipboard_get().strip_edges()
				"show":
					_show_key = not _show_key
				"clear":
					options.api_key = ""
			save_options()
			_refresh())
		row.add_child(b)
	upd.call()
	c.add_child(status)
	c.add_child(_label("Modelo: " + str(options.ai_model), 20, Color(Hud.INK_SOFT, 0.8)))


func _slider(parent: Control, title: String, key: String, lo: float, hi: float, fmt: Callable) -> void:
	var c := _card(parent)
	var h := HBoxContainer.new()
	c.add_child(h)
	var t := _label(title, 28, Hud.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var val := _label(fmt.call(float(options[key])), 28, Hud.EMBER, true)
	h.add_child(val)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(options[key])
	s.custom_minimum_size = Vector2(0, 64)
	s.value_changed.connect(func(v: float) -> void:
		options[key] = v
		val.text = fmt.call(v)
		apply_options()
		options_changed.emit())
	s.drag_ended.connect(func(_c: bool) -> void: save_options())
	c.add_child(s)
