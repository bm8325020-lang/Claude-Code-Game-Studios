# PROTOTYPE - NOT FOR PRODUCTION
# Everything on screen: a floating joystick on the left half, round buttons on the right (attack, dodge, potion,
# three skills with a cooldown sweep, interact), the life bar, gold, potions and the room count, banners, the
# blessing cards after a room, and the village panels (hero altar, forge). Keyboard works too.
extends CanvasLayer

const Data = preload("res://data.gd")

var main: Node
var draw: Control
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var held := {}  # action -> true while a finger or key holds it
var fresh := {}  # action -> pressed this frame
var buttons := {}  # action -> [centre, radius]
var banner_text := ""
var banner_sub := ""
var banner_col := Color.WHITE
var banner_t := 0.0
var panel: Control  # cards and village panels (modal)
var fade: ColorRect
const KEYS := {"attack": [KEY_J, KEY_K], "dodge": [KEY_SPACE], "potion": [KEY_Q], "skill0": [KEY_1, KEY_U], "skill1": [KEY_2, KEY_I],
	"skill2": [KEY_3, KEY_O], "interact": [KEY_E], "pause": [KEY_ESCAPE]}

func setup(m: Node) -> void:
	main = m
	layer = 10
	draw = Control.new()
	draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw)
	add_child(draw)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

func _process(dt: float) -> void:
	banner_t -= dt
	draw.queue_redraw()

func late_clear() -> void:
	fresh.clear()

func move_vec() -> Vector2:
	var k := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if k.length() > 0.0:
		return k.normalized()
	return stick_vec

func pressed(a: String) -> bool:
	return fresh.has(a)

func _layout() -> void:
	var vs := draw.get_viewport_rect().size
	buttons = {"attack": [Vector2(vs.x - 190, vs.y - 190), 120.0], "dodge": [Vector2(vs.x - 400, vs.y - 110), 78.0],
		"skill0": [Vector2(vs.x - 380, vs.y - 300), 70.0], "skill1": [Vector2(vs.x - 290, vs.y - 440), 70.0],
		"skill2": [Vector2(vs.x - 140, vs.y - 470), 78.0], "potion": [Vector2(vs.x - 560, vs.y - 100), 60.0],
		"interact": [Vector2(vs.x * 0.5, vs.y - 170), 90.0], "pause": [Vector2(vs.x - 80, 80), 50.0]}

func _input(event: InputEvent) -> void:
	if panel != null:
		return
	_layout()
	if event is InputEventKey and not event.echo:
		for a in KEYS:
			if event.physical_keycode in KEYS[a]:
				if event.pressed:
					fresh[a] = true
	var vs := draw.get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit := _button_at(event.position)
			if hit != "":
				fresh[hit] = true
				held[event.index] = hit
			elif event.position.x < vs.x * 0.5 and stick_id < 0:
				stick_id = event.index
				stick_origin = event.position
				stick_vec = Vector2.ZERO
		else:
			held.erase(event.index)
			if event.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == stick_id:
		var d: Vector2 = event.position - stick_origin
		stick_vec = d.limit_length(110.0) / 110.0
		if d.length() > 140.0:  # the stick follows a thumb that slides far
			stick_origin = event.position - d.normalized() * 140.0

func _button_at(p: Vector2) -> String:
	for a in buttons:
		if not _visible(a):
			continue
		if p.distance_to(buttons[a][0]) < buttons[a][1] + 12.0:
			return a
	return ""

func _visible(a: String) -> bool:
	if a == "interact":
		return main.interact_label() != ""
	if a.begins_with("skill") or a == "potion":
		return main.in_run()
	return true

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	_layout()
	var vs := draw.get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var h: Node = main.hero
	if h == null:
		return
	# life bar
	var w := 520.0
	draw.draw_rect(Rect2(40, 36, w, 34), Color(0, 0, 0, 0.55))
	draw.draw_rect(Rect2(44, 40, (w - 8) * clampf(h.hp / h.max_hp, 0.0, 1.0), 26), Color(0.85, 0.15, 0.2))
	_text("%d / %d" % [int(h.hp), int(h.max_hp)], Vector2(56, 64), 24, Color.WHITE)
	_text("%s  Nv %d" % [Data.HEROES[h.id].name, main.hero_level(h.id)], Vector2(40, 112), 30, Color(1, 0.85, 0.6))
	_text("Ouro %d" % main.gold_now(), Vector2(vs.x - 330, 70), 36, Color(1, 0.85, 0.3))
	if main.in_run():
		_text("Poções %d" % main.run.potions, Vector2(40, 156), 28, Color(1, 0.5, 0.6))
		_text(main.room_title(), Vector2(vs.x * 0.5 - 260, 60), 30, Color(0.9, 0.9, 1))
		var xb: float = float(main.run.xp_run)
		_text("XP +%d" % int(xb), Vector2(40, 196), 24, Color(0.7, 0.9, 1))
	# joystick
	if stick_id >= 0:
		draw.draw_circle(stick_origin, 110, Color(1, 1, 1, 0.08))
		draw.draw_arc(stick_origin, 110, 0, TAU, 48, Color(1, 1, 1, 0.3), 3)
		draw.draw_circle(stick_origin + stick_vec * 110, 46, Color(1, 1, 1, 0.35))
	elif main.hero != null:
		_text("arraste aqui para andar", Vector2(80, vs.y - 60), 24, Color(1, 1, 1, 0.25))
	# buttons
	for a in buttons:
		if not _visible(a):
			continue
		var c: Vector2 = buttons[a][0]
		var r: float = buttons[a][1]
		var label: String = {"attack": "ATACAR", "dodge": "ESQUIVA", "potion": "POÇÃO", "interact": main.interact_label(), "pause": "II"}.get(a, "")
		var col := Color(1, 1, 1)
		var frac := 0.0
		if a.begins_with("skill"):
			var i := int(a.substr(5))
			var sk: Array = Data.HEROES[h.id].skills[i]
			label = sk[1]
			col = [Color(0.6, 0.85, 1), Color(0.7, 1, 0.6), Color(1, 0.7, 0.3)][i]
			frac = clampf(h.cds[i] / sk[2], 0.0, 1.0)
		elif a == "dodge":
			frac = clampf(h.dodge_cd / 0.6, 0.0, 1.0)
		draw.draw_circle(c, r, Color(col, 0.18))
		draw.draw_arc(c, r, 0, TAU, 48, Color(col, 0.7), 4)
		if frac > 0.0:
			draw.draw_circle(c, r * frac, Color(0, 0, 0, 0.5))
		var fs := 26 if a != "interact" else 24
		draw.draw_string_outline(font, c + Vector2(-r, 9), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 6, Color(0, 0, 0, 0.8))
		draw.draw_string(font, c + Vector2(-r, 9), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.95))
	# boss bar
	var b = main.boss_node()
	if b != null:
		var bw := vs.x * 0.5
		_text(b.bdef.name, Vector2((vs.x - bw) / 2, vs.y - 96), 30, Color(1, 0.85, 0.7))
		draw.draw_rect(Rect2((vs.x - bw) / 2, vs.y - 80, bw, 20), Color(0, 0, 0, 0.6))
		draw.draw_rect(Rect2((vs.x - bw) / 2 + 3, vs.y - 77, (bw - 6) * clampf(b.hp / b.max_hp, 0, 1), 14), Color(0.8, 0.2, 0.1))
	if banner_t > 0.0:
		var a2 := clampf(banner_t, 0.0, 1.0)
		draw.draw_rect(Rect2(0, vs.y * 0.3, vs.x, 140), Color(0, 0, 0, 0.45 * a2))
		draw.draw_string_outline(font, Vector2(0, vs.y * 0.3 + 78), banner_text, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 68, 10, Color(0, 0, 0, a2))
		draw.draw_string(font, Vector2(0, vs.y * 0.3 + 78), banner_text, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 68, Color(banner_col, a2))
		draw.draw_string(font, Vector2(0, vs.y * 0.3 + 122), banner_sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, Color(0.95, 0.95, 0.95, a2))

func _text(s: String, p: Vector2, size: int, col: Color) -> void:
	draw.draw_string_outline(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8))
	draw.draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func banner(t: String, sub: String, col: Color, secs := 2.5) -> void:
	banner_text = t
	banner_sub = sub
	banner_col = col
	banner_t = secs

# a black fade in the middle of which cb runs (room changes)
func transition(cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(cb)
	tw.tween_property(fade, "color:a", 0.0, 0.35)

# ------------------------------------------------------------------ modal panels
func _modal(title: String) -> VBoxContainer:
	close_panel()
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 60)
	panel.add_child(mc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	mc.add_child(col)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", Color(1, 0.75, 0.35))
	col.add_child(l)
	held.clear()
	stick_id = -1
	stick_vec = Vector2.ZERO
	return col

func close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null

func _card(parent: Control, title: String, body: String, col: Color, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = "%s\n\n%s" % [title, body]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(480, 320)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", col)
	b.disabled = not enabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# pick one of three blessings
func blessings(options: Array, cb: Callable) -> void:
	if main.autoplay:
		cb.call(options[0])
		return
	var col := _modal("ESCOLHA UMA BÊNÇÃO")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	col.add_child(row)
	for o in options:
		_card(row, o.name, o.desc, o.col, func():
			close_panel()
			cb.call(o))

func message(title: String, body: String, button: String, cb: Callable) -> void:
	if main.autoplay:
		print("MESSAGE ", title, " | ", body.replace("\n", " / "))
		return
	var col := _modal(title)
	var l := Label.new()
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 36)
	col.add_child(l)
	var b := Button.new()
	b.text = button
	b.custom_minimum_size = Vector2(0, 110)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func():
		close_panel()
		cb.call())
	col.add_child(b)

# the hero altar: choose a hero (unlock with gold) and an armour colour
func heroes_panel() -> void:
	var col := _modal("ALTAR DOS HERÓIS")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	for id in Data.HEROES:
		var hd: Dictionary = Data.HEROES[id]
		var owned: bool = main.save.unlocked.has(id)
		var title := "%s%s" % [hd.name, "  ✔" if main.save.hero == id else ""]
		var body := "%s\n\nNível %d\n%s" % [hd.desc, main.hero_level(id), "" if owned else "Liberar: %d ouro" % hd.unlock]
		var c := _card(row, title, body, Color(1, 0.85, 0.5) if owned else Color(0.7, 0.7, 0.7), func():
			if main.choose_hero(id):
				heroes_panel())
		c.custom_minimum_size = Vector2(330, 420)
		c.add_theme_font_size_override("font_size", 26)
	var tints := HBoxContainer.new()
	tints.alignment = BoxContainer.ALIGNMENT_CENTER
	tints.add_theme_constant_override("separation", 12)
	col.add_child(tints)
	for i in Data.TINTS.size():
		var b := Button.new()
		b.text = Data.TINT_NAMES[i] + ("  ✔" if main.save.tint == i else "")
		b.custom_minimum_size = Vector2(190, 90)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Data.TINTS[i].clamp(Color(0.3, 0.3, 0.3), Color(1, 1, 1)))
		b.pressed.connect(func():
			main.choose_tint(i)
			heroes_panel())
		tints.add_child(b)
	_close_button(col)

# the forge: permanent upgrades for gold
func forge_panel() -> void:
	var col := _modal("FORJA  ·  ouro: %d" % main.save.gold)
	for u in Data.UPGRADES:
		var lv: int = main.save.upgrades.get(u[0], 0)
		var cost := Data.upgrade_cost(u[3], lv)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		col.add_child(row)
		var l := Label.new()
		l.text = "%s  (%d/%d)\n%s" % [u[1], lv, u[4], u[2]]
		l.add_theme_font_size_override("font_size", 30)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.text = "MÁXIMO" if lv >= u[4] else "%d ouro" % cost
		b.disabled = lv >= u[4] or main.save.gold < cost
		b.custom_minimum_size = Vector2(260, 90)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(func():
			main.buy_upgrade(u[0], cost)
			forge_panel())
		row.add_child(b)
	_close_button(col)

func pause_panel() -> void:
	var col := _modal("PAUSA")
	for opt in [["CONTINUAR", func(): close_panel()], ["VOLTAR À VILA", func():
			close_panel()
			main.end_run(false)]]:
		if opt[0] == "VOLTAR À VILA" and not main.in_run():
			continue
		var b := Button.new()
		b.text = opt[0]
		b.custom_minimum_size = Vector2(0, 110)
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(opt[1])
		col.add_child(b)

func _close_button(col: VBoxContainer) -> void:
	var b := Button.new()
	b.text = "FECHAR"
	b.custom_minimum_size = Vector2(0, 100)
	b.add_theme_font_size_override("font_size", 36)
	b.pressed.connect(close_panel)
	col.add_child(b)
