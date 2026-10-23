# PROTOTYPE - NOT FOR PRODUCTION
# HUD of Sementes do Dragão v2 (owner: UI agent). Also holds the shared hand-made look (colours, serif fonts,
# parchment/wood shader, Godot Theme) that menu.gd, dialog.gd and touch.gd reuse: Hud.ui_theme(), Hud.paper(), ...
#
# Use: var hud := Hud.new(); some_canvas_layer.add_child(hud)   (full rect, ignores the mouse, base size 1920x1080)
# Setters (call whenever the value changes; calling every frame is fine, they only animate on change):
#   set_life(cur: float, max_v: float)         red bar with a delayed "ghost" of the damage taken
#   set_stamina(cur: float, max_v: float)      green-gold bar under it
#   set_xp(cur: int, need: int)                gold ring around the level medallion
#   set_level(n: int)                          number in the medallion
#   set_gold(n: int)                           coin counter; increases pop a "+n"
#   set_quest(title: String, step: String, target: Variant = null)   tracker; target is a Vector3 or null
#   clear_quest()
#   set_player(pos: Vector3, cam_yaw: float)   every frame: hero position and camera global yaw (rotation.y),
#                                              drives the tracker arrow and distance
#   show_area(name: String)                    banner "Vila de Brasalume"; same name again is ignored, so main can
#                                              call it every frame with map.area_name(pos); "" resets
#   boss_show(name: String, cur: float, max_v: float) / boss_set(cur: float, max_v: float) / boss_hide()
#   toast(title: String, sub: String = "", kind: String = "info")   kinds: info, level, reward, quest
#   level_up(n: int, points: int)              shortcut: set_level + golden toast
#   bind(progression: Progression, quests: Quests, map: Object = null)  optional: follows the systems by itself
#   Hud.quest_pos(Quests.current(), map) -> Variant   map position of the tracked objective (Vector3 or null)
# First-time hints (move, attack, follow the arrow, talk to "!"): each shown once, done ids saved in
#   GameMenu.options.hints; "Pular" on the hint (Touch.tap_zone) skips them all. Places walked into are saved as
#   Progression unlocks "place_seen:<id>" (the menu map shows only those).
class_name Hud
extends Control

# ------------------------------------------------------------------ shared look
const INK: Color = Color(0.24, 0.15, 0.08)
const INK_SOFT: Color = Color(0.45, 0.32, 0.19)
const PARCH: Color = Color(0.94, 0.86, 0.68)
const PARCH_LIGHT: Color = Color(0.98, 0.94, 0.82)
const WOOD: Color = Color(0.42, 0.26, 0.13)
const WOOD_LIGHT: Color = Color(0.56, 0.36, 0.18)
const WOOD_DARK: Color = Color(0.2, 0.12, 0.06)
const GOLD: Color = Color(0.97, 0.77, 0.36)
const CREAM: Color = Color(1.0, 0.95, 0.84)
const EMBER: Color = Color(0.86, 0.38, 0.12)
const LIFE: Color = Color(0.8, 0.17, 0.12)
const STAMINA: Color = Color(0.62, 0.74, 0.25)
const SHADOW: Color = Color(0.08, 0.04, 0.02, 0.55)
const QUEST_W: float = 540.0  # quest card width (base 1920x1080)

const PAPER_SHADER: String = """
shader_type canvas_item;
uniform int kind = 0; // 0 parchment, 1 wood
uniform vec4 base : source_color = vec4(0.94, 0.86, 0.68, 1.0);
uniform vec4 edge : source_color = vec4(0.6, 0.42, 0.22, 1.0);
uniform vec2 rect_size = vec2(800.0, 600.0);
uniform float radius = 18.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 px = UV * rect_size;
	vec2 q = abs(px - rect_size * 0.5) - rect_size * 0.5 + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float n = noise(px * 0.018) * 0.5 + noise(px * 0.07) * 0.3 + noise(px * 0.35) * 0.2;
	vec3 c;
	if (kind == 0) {
		float fib = noise(vec2(px.x * 0.8, px.y * 0.04));
		c = base.rgb * (0.9 + 0.17 * n) - fib * 0.03;
		float stain = smoothstep(0.6, 0.78, noise(px * 0.007 + 3.1));
		c = mix(c, edge.rgb, stain * 0.14);
		float burn = smoothstep(-70.0 - n * 40.0, 0.0, d);
		c = mix(c, edge.rgb, burn * 0.7);
	} else {
		float g = sin((px.y + noise(px * vec2(0.006, 0.05)) * 26.0) * 0.55) * 0.5 + 0.5;
		float knot = noise(px * vec2(0.01, 0.08));
		c = base.rgb * (0.78 + 0.22 * g + 0.12 * knot);
		c = mix(c, edge.rgb, smoothstep(-10.0, 0.0, d) * 0.8);
	}
	float a = 1.0 - smoothstep(-1.0, 1.0, d);
	COLOR = vec4(c, a * base.a);
}
"""

static var _fonts: Dictionary = {}
static var _theme: Theme
static var _shader: Shader


static func font(bold: bool = false) -> Font:
	var k: String = "b" if bold else "r"
	if not _fonts.has(k):
		var f := SystemFont.new()
		# Android resolves "Noto Serif"/"serif"; desktop Linux gets DejaVu Serif; Windows Georgia.
		f.font_names = PackedStringArray(["Noto Serif", "Georgia", "DejaVu Serif", "Liberation Serif", "serif"])
		f.font_weight = 700 if bold else 500
		_fonts[k] = f
	return _fonts[k]


static func box(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 0, radius: int = 10, margin: float = 0.0,
		shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = SHADOW
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	return sb


# A parchment (kind 0) or wood (kind 1) background with soft burnt edges; a ColorRect with its own material.
static func paper(kind: int = 0, radius: float = 18.0, tint: Color = Color(-1, 0, 0)) -> ColorRect:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PAPER_SHADER
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("radius", radius)
	if kind == 1:
		m.set_shader_parameter("base", WOOD if tint.r < 0.0 else tint)
		m.set_shader_parameter("edge", WOOD_DARK)
	elif tint.r >= 0.0:
		m.set_shader_parameter("base", tint)
	r.material = m
	r.resized.connect(func() -> void: m.set_shader_parameter("rect_size", r.size))
	return r


static func circle_texture(radius: int, fill: Color, ring: Color, ring_w: float) -> ImageTexture:
	var s: int = radius * 2 + 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s, s) * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a: float = clampf(radius - d + 0.5, 0.0, 1.0)
			var col: Color = ring if d > radius - ring_w else fill
			col.a *= a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func ui_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font(false)
	t.default_font_size = 30
	# wooden buttons: dark bottom edge reads as a raised plank
	var bn := box(WOOD, WOOD_DARK, 3, 12, 14.0, 4)
	bn.border_width_bottom = 7
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = WOOD_LIGHT
	var bp := bn.duplicate() as StyleBoxFlat
	bp.bg_color = WOOD_DARK
	bp.border_width_bottom = 3
	bp.border_width_top = 6
	bp.shadow_size = 0
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.42, 0.34, 0.25, 0.8)
	bd.border_color = Color(0.3, 0.24, 0.18, 0.6)
	bd.shadow_size = 0
	for st in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd], ["hover_pressed", bp]]:
		t.set_stylebox(st[0], "Button", st[1])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color(1, 0.98, 0.9))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(1.0, 0.94, 0.82, 0.85))
	t.set_color("font_outline_color", "Button", Color(0.1, 0.05, 0.02, 0.8))
	t.set_constant("outline_size", "Button", 4)
	t.set_font("font", "Button", font(true))
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", font(false))
	# writing field: lighter parchment sunk into the page
	var le := box(PARCH_LIGHT, INK_SOFT, 2, 8, 16.0)
	var lef := box(Color(1, 0.98, 0.9), EMBER, 3, 8, 16.0)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK_SOFT, 0.65))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(EMBER, 0.35))
	t.set_font_size("font_size", "LineEdit", 30)
	# sliders: wooden groove, brass knob
	var track := box(WOOD_DARK, Color.TRANSPARENT, 0, 6)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill := box(EMBER, Color.TRANSPARENT, 0, 6)
	fill.content_margin_top = 7
	fill.content_margin_bottom = 7
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := circle_texture(20, GOLD, WOOD_DARK, 4.0)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", circle_texture(20, Color(1, 0.88, 0.55), WOOD_DARK, 4.0))
	# thin wooden scroll bar
	t.set_stylebox("scroll", "VScrollBar", box(Color(WOOD_DARK, 0.25), Color.TRANSPARENT, 0, 6, 4.0))
	t.set_stylebox("grabber", "VScrollBar", box(WOOD, Color.TRANSPARENT, 0, 6, 6.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(WOOD_LIGHT, Color.TRANSPARENT, 0, 6, 6.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(EMBER, Color.TRANSPARENT, 0, 6, 6.0))
	t.set_stylebox("panel", "PanelContainer", box(Color(PARCH, 0.0)))
	_theme = t
	return t


# ------------------------------------------------------------------ HUD state
var life: float = 100.0
var life_max: float = 100.0
var stamina: float = 100.0
var stamina_max: float = 100.0
var xp: int = 0
var xp_need: int = 100
var level: int = 1
var gold: int = 0
var quest_title: String = ""
var quest_step: String = ""
var quest_target: Variant = null
static var route_fn: Callable  # optional: turns the quest's goal into the next road waypoint toward it (main.gd)
static var note_fn: Callable   # optional: extra line for the quest card, e.g. the recommended level (main.gd)
static var idle_fn: Callable   # optional: {title, step, pos} for the card and arrow when no quest is running
static var taken: Dictionary = {}  # interactable ids already used up (main.gd shares its _taken)

var _life_ghost: float = 100.0
var _life_show: float = 100.0
var _stam_show: float = 100.0
var _xp_show: float = 0.0
var _gold_pops: Array[Dictionary] = []
var _player: Vector3 = Vector3.ZERO
var _cam_yaw: float = 0.0
var _area: String = ""
var _area_t: float = 99.0
var _boss_name: String = ""
var _boss: float = 0.0
var _boss_max: float = 1.0
var _boss_ghost: float = 0.0
var _boss_a: float = 0.0
var _toasts: Array[Dictionary] = []
var _toast_t: float = 0.0
var _hurt: float = 0.0
var _quest_a: float = 0.0
var _quest_pulse: float = 0.0
var _time: float = 0.0
var _prog: Progression
var _quests: Quests
var _map: Object
var _hint: String = ""
var _hint_a: float = 0.0
var _hint_t: float = 0.0
var _hint_moved: float = 0.0
var _hint_last: Vector3 = Vector3.ZERO
var _seen_t: float = 0.0

const HINTS: Dictionary = {
	"move": "Arraste o dedo aqui para andar",
	"attack": "Toque em ATACAR para golpear",
	"arrow": "A seta no cartão aponta a missão. Siga!",
	"talk": "Toque em FALAR para conversar com quem tem \"!\"",
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		queue_redraw()
	# the talk opened the dialog (which pauses the tree): that was the lesson
	if what == NOTIFICATION_PAUSED and _hint == "talk" and Touch._interact_label == "Falar":
		_hint_done("talk")


# First hint not seen yet whose moment has come; "" = none. Move and attack come first, in that order.
static func next_hint(done: Array, has_target: bool, can_talk: bool) -> String:
	for id: String in ["move", "attack", "arrow", "talk"]:
		if done.has(id):
			continue
		if id == "arrow" and not has_target:
			continue
		if id == "talk" and not can_talk:
			continue
		return id
	return ""


func _hints_done() -> Array:
	var h: Variant = GameMenu.options.get("hints", [])
	return h if h is Array else []


func _hint_done(id: String) -> void:
	var h: Array = _hints_done().duplicate()
	if id == "all":
		h = HINTS.keys()
	elif not h.has(id):
		h.append(id)
	GameMenu.options.hints = h
	GameMenu.save_options()
	_hint = ""
	_hint_t = 0.0
	_hint_moved = 0.0


func _update_hint(dt: float) -> void:
	if get_tree().paused:
		return
	var done: Array = _hints_done()
	var want: String = next_hint(done, quest_target is Vector3, Touch._interact_label == "Falar")
	if want != _hint:
		_hint = want
		_hint_t = 0.0
		_hint_moved = 0.0
		_hint_last = _player
	if Touch.pressed("hint_skip"):
		_hint_done("all")
		return
	if _hint == "":
		return
	_hint_t += dt
	_hint_moved += _player.distance_to(_hint_last)
	_hint_last = _player
	match _hint:
		"move":
			if _hint_moved > 4.0:
				_hint_done("move")
		"attack":
			if Touch.pressed("attack") or Touch.held("attack"):
				_hint_done("attack")
		"arrow":
			if _hint_moved > 25.0 or _hint_t > 16.0:
				_hint_done("arrow")
		"talk":
			if Touch._interact_label != "Falar" and _hint_t > 1.0:
				_hint = ""  # walked away: comes back next time someone has a "!"


# Places the hero has walked into, saved with the game (the menu map draws only those).
func _mark_places(dt: float) -> void:
	_seen_t += dt
	if _seen_t < 0.5 or _prog == null or _map == null:
		return
	_seen_t = 0.0
	for p: Dictionary in _map.get("places"):
		if Vector2(_player.x - p.pos.x, _player.z - p.pos.z).length() < float(p.radius):
			_prog.unlock("place_seen:" + str(p.id))


# ------------------------------------------------------------------ setters
func set_life(cur: float, max_v: float) -> void:
	if cur < life - 0.01:
		_hurt = 1.0
	if cur > life:
		_life_ghost = maxf(_life_ghost, cur)
	life = clampf(cur, 0.0, maxf(max_v, 1.0))
	life_max = maxf(max_v, 1.0)


func set_stamina(cur: float, max_v: float) -> void:
	stamina = clampf(cur, 0.0, maxf(max_v, 1.0))
	stamina_max = maxf(max_v, 1.0)


func set_xp(cur: int, need: int) -> void:
	xp = cur
	xp_need = maxi(need, 1)


func set_level(n: int) -> void:
	level = n


func set_gold(n: int) -> void:
	if n > gold and is_inside_tree() and _time > 0.5:
		_gold_pops.append({"text": "+%d" % (n - gold), "t": 0.0})
	gold = n


func set_quest(title: String, step: String, target: Variant = null) -> void:
	if title != quest_title or step != quest_step:
		_quest_pulse = 1.0
	quest_title = title
	quest_step = step
	quest_target = target if target is Vector3 else null


func clear_quest() -> void:
	quest_title = ""
	quest_step = ""
	quest_target = null


func set_player(pos: Vector3, cam_yaw: float) -> void:
	_player = pos
	_cam_yaw = cam_yaw


func show_area(area: String) -> void:
	if area == _area:
		return
	_area = area
	if area != "":
		_area_t = 0.0


func boss_show(boss_name: String, cur: float, max_v: float) -> void:
	_boss_name = boss_name
	_boss_max = maxf(max_v, 1.0)
	_boss = cur
	_boss_ghost = cur


func boss_set(cur: float, max_v: float) -> void:
	_boss = clampf(cur, 0.0, maxf(max_v, 1.0))
	_boss_max = maxf(max_v, 1.0)


func boss_hide() -> void:
	_boss_name = ""


func toast(title: String, sub: String = "", kind: String = "info") -> void:
	_toasts.append({"title": title, "sub": sub, "kind": kind})


func level_up(n: int, points: int) -> void:
	set_level(n)
	toast("NÍVEL %d" % n, ("+%d pontos de atributo" % points) if points > 0 else "Você está mais forte", "level")


# Optional wiring to systems/ (Progression, Quests) and the map (GameMap or anything with npc_spots, places,
# interactables, spawns). Follows: level, xp, gold (polled every frame), Quests.current() for the tracker (target
# resolved to a map position from pos_kind/pos_key), toasts on leveled_up, unlocked, quest_started and quest_done.
func bind(progression: Progression, quests: Quests, map: Object = null) -> void:
	_prog = progression
	_quests = quests
	_map = map
	if _prog != null:
		_prog.leveled_up.connect(func(n: int) -> void: level_up(n, Progression.POINTS_PER_LEVEL))
		_prog.unlocked.connect(func(id: String) -> void:
			var u: Dictionary = Progression.UNLOCKS.get(id, {}) as Dictionary
			if not u.is_empty():
				toast(str(u.name), str(u.desc), "reward"))
	if _quests != null:
		_quests.quest_started.connect(func(id: String) -> void:
			toast("NOVA MISSÃO", str(Quests.quest(id).get("title", "")), "info"))
		_quests.quest_done.connect(func(id: String, rewards: Dictionary) -> void:
			var parts: PackedStringArray = []
			if int(rewards.get("xp", 0)) > 0:
				parts.append("+%d XP" % int(rewards.xp))
			if int(rewards.get("gold", 0)) > 0:
				parts.append("+%d ouro" % int(rewards.gold))
			for it: String in (rewards.get("items", {}) as Dictionary):
				parts.append(Items.item_name(it))
			var sub: String = str(Quests.quest(id).get("title", ""))
			if not parts.is_empty():
				sub += "  ·  " + " · ".join(parts)
			toast("MISSÃO CONCLUÍDA", sub, "quest"))


# world position of a Quests.current() target, or null
static func quest_pos(q: Dictionary, map: Object) -> Variant:
	var base: Variant = _quest_base_pos(q, map)
	# "defeat N X": point at the nearest living X to the quest area, not at the empty middle of the area
	if str(q.get("type", "")) == "kill" and map is Node and (map as Node).is_inside_tree():
		var anchor: Vector3 = base if base is Vector3 else Vector3.ZERO
		var want: String = str(q.get("target", ""))
		var best: Variant = null
		var bd: float = 1e12
		for n in (map as Node).get_tree().get_nodes_in_group("enemies"):
			var is_boss: bool = n.get_script() != null and str((n.get_script() as Script).get_global_name()) == "Boss"
			if (want == "boss" and not is_boss) or (want != "boss" and (is_boss or str(n.get("kind")) != want)) or bool(n.get("dead")):
				continue
			var d: float = (n as Node3D).global_position.distance_squared_to(anchor)
			if d < bd:
				bd = d
				best = (n as Node3D).global_position
		if best != null:
			return best
	# "find N X" scattered over several areas: point at the nearest one still lying around
	if str(q.get("type", "")) == "collect" and map != null:
		var anchor: Vector3 = base if base is Vector3 else Vector3.ZERO
		var best: Variant = null
		var bd: float = 1e12
		for it: Dictionary in map.get("interactables"):
			if str(it.get("item", "")) != str(q.get("target", "")) or taken.has(str(it.get("id", ""))):
				continue
			var d: float = (it.pos as Vector3).distance_squared_to(anchor)
			if d < bd:
				bd = d
				best = it.pos
		if best != null:
			return best
	return base


static func _quest_base_pos(q: Dictionary, map: Object) -> Variant:
	if map == null or q.is_empty():
		return null
	var key: String = str(q.get("pos_key", ""))
	match str(q.get("pos_kind", "")):
		"npc":
			for s: Dictionary in map.get("npc_spots"):
				if str(s.get("role", "")) == key or str(s.get("id", "")) == key:
					return s.pos
		"interactable":
			for s: Dictionary in map.get("interactables"):
				if str(s.get("id", "")) == key:
					return s.pos
	var spawns: Dictionary = map.get("spawns") if map.get("spawns") is Dictionary else {}
	for k: String in [key, str(q.get("where", ""))]:
		for p: Dictionary in map.get("places"):
			if str(p.id) == k:
				return p.pos
		if spawns.has(k):
			return spawns[k]
	return null


func _poll_systems() -> void:
	if _prog != null:
		level = _prog.level
		xp = _prog.xp
		xp_need = Progression.xp_to_next(_prog.level)
		set_gold(_prog.gold)
	if _quests != null:
		var q: Dictionary = _quests.current()
		var idle: Dictionary = idle_fn.call() if q.is_empty() and idle_fn.is_valid() else {}
		if not idle.is_empty():
			var at: Variant = idle.get("pos")
			if at is Vector3 and route_fn.is_valid():
				at = route_fn.call(at)
			set_quest(str(idle.title), str(idle.step), at)
		elif q.is_empty():
			clear_quest()
		else:
			var goal: Variant = quest_pos(q, _map)
			if goal is Vector3 and route_fn.is_valid():
				goal = route_fn.call(goal)
			var step: String = str(q.text)
			if note_fn.is_valid():
				var note: String = str(note_fn.call(q))
				if note != "":
					step += "\n" + note
			set_quest(str(q.title), step, goal)


# ------------------------------------------------------------------ animation
func _process(dt: float) -> void:
	_time += dt
	if (_prog != null or _quests != null) and Engine.get_process_frames() % 3 == 0:  # 20 Hz at 60 fps: quest lookup + GPS route is too much per frame on a phone
		_poll_systems()
	_update_hint(dt)
	_mark_places(dt)
	_hint_a = move_toward(_hint_a, 1.0 if _hint != "" else 0.0, dt * 4.0)
	_life_show = lerpf(_life_show, life, 1.0 - exp(-dt * 14.0))
	if _life_ghost > life:
		_life_ghost = maxf(life, _life_ghost - life_max * dt * (0.0 if _hurt > 0.55 else 0.6))
	else:
		_life_ghost = life
	_stam_show = lerpf(_stam_show, stamina, 1.0 - exp(-dt * 16.0))
	var frac: float = clampf(float(xp) / float(xp_need), 0.0, 1.0)
	_xp_show = lerpf(_xp_show, frac, 1.0 - exp(-dt * 6.0)) if frac >= _xp_show - 0.001 else frac
	_hurt = maxf(0.0, _hurt - dt * 1.6)
	_area_t += dt
	_quest_a = move_toward(_quest_a, 1.0 if quest_title != "" else 0.0, dt * 4.0)
	_quest_pulse = maxf(0.0, _quest_pulse - dt * 0.8)
	_boss_a = move_toward(_boss_a, 1.0 if _boss_name != "" else 0.0, dt * 3.0)
	_boss_ghost = maxf(_boss, _boss_ghost - _boss_max * dt * 0.25) if _boss_ghost > _boss else _boss
	for p in _gold_pops:
		p.t += dt
	_gold_pops = _gold_pops.filter(func(p: Dictionary) -> bool: return p.t < 1.4)
	if not _toasts.is_empty():
		_toast_t += dt
		var dur: float = 3.2 if _toasts[0].kind == "level" else 2.6
		if _toast_t > dur:
			_toasts.pop_front()
			_toast_t = 0.0
	queue_redraw()


# ------------------------------------------------------------------ drawing
func _text(pos: Vector2, s: String, size: int, col: Color, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0, outline: int = 0, outline_col: Color = Color(0.08, 0.04, 0.02, 0.85)) -> void:
	var f: Font = font(bold)
	if outline > 0:
		draw_string_outline(f, pos, s, align, width, size, outline, outline_col)
	draw_string(f, pos, s, align, width, size, col)


func _bar(r: Rect2, frac: float, ghost: float, col: Color, ghost_col: Color) -> void:
	draw_style_box(box(Color(0.1, 0.06, 0.03, 0.85), WOOD_DARK, 3, 7, 0.0, 4), r.grow(3))
	var inner := r.grow(-2)
	if ghost > frac:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ghost, inner.size.y)), ghost_col)
	if frac > 0.0:
		var f := Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y))
		draw_rect(f, col)
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.35)), Color(1, 1, 1, 0.18))
		draw_rect(Rect2(f.position + Vector2(0, f.size.y * 0.75), Vector2(f.size.x, f.size.y * 0.25)), Color(0, 0, 0, 0.18))
	# brass studs at both ends
	for x: float in [r.position.x - 1.0, r.end.x + 1.0]:
		draw_circle(Vector2(x, r.get_center().y), 6.0, GOLD)
		draw_circle(Vector2(x, r.get_center().y), 3.0, WOOD_DARK)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	_draw_hurt(w, h)
	_draw_status()
	if _quest_a > 0.01:
		_draw_quest(w)
	if is_inside_tree() and get_tree().paused:
		return  # a menu or dialog is open: frozen banners and toasts would sit under it
	if _area != "" and _area_t < 4.2:
		_draw_area(w)
	if _boss_a > 0.01:
		_draw_boss(w, h)
	if not _toasts.is_empty():
		_draw_toast(w)
	if _hint_a > 0.01 and _hint != "":
		_draw_hint(w, h)
	else:
		Touch.tap_zone = Rect2()


# Hint bubble low in the middle (between the thumbs), a pulsing ring on the thing to touch and a "Pular" pill.
func _draw_hint(w: float, h: float) -> void:
	var a: float = _hint_a
	var target: Vector2
	match _hint:
		"move":
			target = Vector2(250.0, h - 250.0)
		"attack":
			target = Vector2(w - 215.0, h - 205.0)
		"arrow":
			target = Vector2(w - 26.0 - QUEST_W + 58.0, 198.0)
		"talk":
			target = Vector2(w - 700.0, h - 480.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	draw_arc(target, 120.0 + 14.0 * pulse if _hint != "arrow" else 56.0 + 8.0 * pulse, 0.0, TAU, 64,
		Color(GOLD, a * (0.55 + 0.45 * pulse)), 7.0, true)
	var text: String = HINTS[_hint]
	var f: Font = font(true)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var bw: float = tw + 80.0
	var skip := Rect2(0, 0, 170, 96)
	var r := Rect2(w * 0.5 - (bw + skip.size.x + 16.0) * 0.5, h - 330.0, bw, 96)
	skip.position = Vector2(r.end.x + 16.0, r.position.y)
	var from := Vector2(clampf(target.x, r.position.x + 30.0, r.end.x - 30.0), r.position.y if target.y < r.position.y else r.end.y)
	if target.x < r.position.x:
		from = Vector2(r.position.x, r.get_center().y)
	elif target.x > skip.end.x:
		from = Vector2(skip.end.x, r.get_center().y)
	draw_dashed_line(from, target, Color(GOLD, 0.8 * a), 4.0, 14.0, true)
	var sb := box(Color(PARCH, 0.96 * a), Color(GOLD, a), 4, 16, 0.0, 8)
	sb.shadow_color = Color(SHADOW, 0.5 * a)
	draw_style_box(sb, r)
	_text(Vector2(r.position.x, r.position.y + 60.0), text, 34, Color(INK, a), true, HORIZONTAL_ALIGNMENT_CENTER, bw)
	draw_style_box(box(Color(WOOD, 0.95 * a), Color(WOOD_DARK, a), 3, 16, 0.0, 6), skip)
	_text(Vector2(skip.position.x, skip.position.y + 60.0), "Pular", 30, Color(CREAM, a), true, HORIZONTAL_ALIGNMENT_CENTER,
		skip.size.x)
	Touch.tap_zone = skip


func _draw_hurt(w: float, h: float) -> void:
	var low: float = clampf(1.0 - life / life_max / 0.3, 0.0, 1.0) * (0.5 + 0.5 * sin(_time * 5.0)) * 0.6
	var a: float = maxf(_hurt * 0.55, low * 0.5)
	if a <= 0.01:
		return
	var c := Color(0.55, 0.02, 0.0, a)
	var t := Color(0.55, 0.02, 0.0, 0.0)
	var e: float = 140.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, e), Vector2(0, e)]), PackedColorArray([c, c, t, t]))
	draw_polygon(PackedVector2Array([Vector2(0, h - e), Vector2(w, h - e), Vector2(w, h), Vector2(0, h)]), PackedColorArray([t, t, c, c]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, h), Vector2(0, h)]), PackedColorArray([c, t, t, c]))
	draw_polygon(PackedVector2Array([Vector2(w - e, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - e, h)]), PackedColorArray([t, c, c, t]))


func _draw_status() -> void:
	var m := Vector2(112, 108)
	var r: float = 62.0
	draw_circle(m + Vector2(0, 5), r + 12.0, SHADOW)
	draw_circle(m, r + 11.0, WOOD_DARK)
	draw_arc(m, r + 4.0, 0.0, TAU, 64, Color(0.35, 0.22, 0.1), 8.0, true)
	if _xp_show > 0.002:
		draw_arc(m, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * _xp_show, 64, GOLD, 8.0, true)
	draw_circle(m, r - 1.0, WOOD)
	draw_circle(m, r - 9.0, PARCH)
	draw_arc(m, r - 9.0, 0.0, TAU, 48, Color(INK_SOFT, 0.5), 2.0, true)
	_text(m + Vector2(-60, -12), "NÍVEL", 20, INK_SOFT, true, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	_text(m + Vector2(-60, 33), str(level), 50, INK, true, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# life and stamina grow a little with their maximum, like the classics
	var x0: float = 196.0
	var lw: float = clampf(330.0 + life_max * 1.4, 380.0, 640.0)
	var lr := Rect2(x0, 52, lw, 32)
	_bar(lr, _life_show / life_max, _life_ghost / life_max, LIFE, Color(1.0, 0.82, 0.55))
	_text(Vector2(lr.position.x + 12, lr.end.y - 7), "%d / %d" % [roundi(life), roundi(life_max)], 23, CREAM, true,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var sw: float = clampf(250.0 + stamina_max * 1.2, 290.0, 540.0)
	var tired: bool = stamina < stamina_max * 0.2
	var sc: Color = STAMINA.lerp(Color(0.95, 0.6, 0.2), 0.5 + 0.5 * sin(_time * 10.0)) if tired else STAMINA
	_bar(Rect2(x0, 98, sw, 18), _stam_show / stamina_max, 0.0, sc, Color.TRANSPARENT)
	# gold
	var g := Vector2(x0 + 16, 148)
	draw_circle(g + Vector2(0, 2), 15.0, SHADOW)
	draw_circle(g, 14.0, Color(0.72, 0.5, 0.15))
	draw_circle(g, 11.0, GOLD)
	draw_circle(g + Vector2(-3, -3), 4.0, Color(1, 0.95, 0.7))
	_text(g + Vector2(24, 10), str(gold), 30, CREAM, true, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	for p in _gold_pops:
		var k: float = p.t / 1.4
		_text(g + Vector2(110, 6 - 40.0 * k), p.text, 28, Color(GOLD, 1.0 - k * k), true, HORIZONTAL_ALIGNMENT_LEFT, -1, 5,
			Color(0.1, 0.05, 0.0, 0.8 * (1.0 - k * k)))


func _draw_quest(w: float) -> void:
	var a: float = _quest_a
	var pw: float = QUEST_W
	var f: Font = font(false)
	var step_h: float = f.get_multiline_string_size(quest_step, HORIZONTAL_ALIGNMENT_LEFT, pw - 132.0, 26).y
	var ph: float = maxf(150.0, 98.0 + step_h)
	var r := Rect2(w - pw - 26.0 + (1.0 - a) * 60.0, 140, pw, ph)
	draw_set_transform(Vector2.ZERO)
	var sb := box(Color(PARCH, 0.93 * a), Color(WOOD, a), 4, 12, 0.0, 6)
	sb.shadow_color = Color(SHADOW, 0.45 * a)
	draw_style_box(sb, r)
	if _quest_pulse > 0.0:
		draw_style_box(box(Color.TRANSPARENT, Color(GOLD, _quest_pulse * a), 5, 14), r.grow(5))
	# compass medallion with the arrow to the objective
	var c := Vector2(r.position.x + 58, r.position.y + 58)
	draw_circle(c, 40.0, Color(WOOD_DARK, a))
	draw_circle(c, 34.0, Color(0.33, 0.21, 0.1, a))
	for i in 8:
		var ang: float = TAU * i / 8.0
		draw_line(c + Vector2.from_angle(ang) * 28.0, c + Vector2.from_angle(ang) * 33.0, Color(GOLD, 0.5 * a), 2.0)
	var dist_text: String = "—"
	if quest_target is Vector3:
		var d: Vector3 = (quest_target as Vector3) - _player
		d.y = 0.0
		var fwd := Vector3(-sin(_cam_yaw), 0, -cos(_cam_yaw))
		var right := Vector3(cos(_cam_yaw), 0, -sin(_cam_yaw))
		var v := Vector2(d.dot(right), -d.dot(fwd))
		var ang: float = v.angle() if v.length() > 0.01 else -PI * 0.5
		var tip := c + Vector2.from_angle(ang) * 27.0
		var bl := c + Vector2.from_angle(ang + 2.5) * 16.0
		var br := c + Vector2.from_angle(ang - 2.5) * 16.0
		var tail := c + Vector2.from_angle(ang + PI) * 8.0
		draw_colored_polygon(PackedVector2Array([tip, bl, tail, br]), Color(EMBER.lightened(0.15), a))
		draw_polyline(PackedVector2Array([tip, bl, tail, br, tip]), Color(1, 0.9, 0.6, a), 2.0, true)
		var m: float = d.length()
		dist_text = ("%d m" % roundi(m)) if m < 1000.0 else ("%.1f km" % (m / 1000.0))
		if m < 6.0:
			dist_text = "aqui"
	else:
		draw_circle(c, 7.0, Color(GOLD, a))
	_text(Vector2(c.x - 50, r.position.y + 134), dist_text, 26, Color(INK, a), true, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	var tx: float = r.position.x + 116.0
	_text(Vector2(tx, r.position.y + 32), "MISSÃO", 20, Color(EMBER, a), true)
	_text(Vector2(tx, r.position.y + 66), quest_title, 30, Color(INK, a), true, HORIZONTAL_ALIGNMENT_LEFT, pw - 132.0)
	draw_multiline_string(f, Vector2(tx, r.position.y + 102), quest_step, HORIZONTAL_ALIGNMENT_LEFT, pw - 132.0, 26, -1,
		Color(INK, a))


func _draw_area(w: float) -> void:
	var t: float = _area_t
	var a: float = clampf(t / 0.6, 0.0, 1.0) * clampf((4.2 - t) / 1.0, 0.0, 1.0)
	var y: float = 330.0
	var f: Font = font(true)
	var tw: float = f.get_string_size(_area, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
	var cx: float = w * 0.5
	var spread: float = 60.0 + 40.0 * ease(clampf(t / 1.2, 0.0, 1.0), 0.4)
	var line_col := Color(GOLD, a * 0.9)
	for s: float in [-1.0, 1.0]:
		var x0: float = cx + s * (tw * 0.5 + 24.0)
		var x1: float = x0 + s * spread * 2.4
		draw_line(Vector2(x0, y - 20), Vector2(x1, y - 20), Color(0, 0, 0, a * 0.4), 5.0, true)
		draw_line(Vector2(x0, y - 20), Vector2(x1, y - 20), line_col, 2.5, true)
		var dm := Vector2(x1 + s * 9.0, y - 20)
		draw_colored_polygon(PackedVector2Array([dm + Vector2(-9, 0), dm + Vector2(0, -7), dm + Vector2(9, 0), dm + Vector2(0, 7)]), line_col)
	_text(Vector2(cx - 400, y), _area, 60, Color(CREAM, a), true, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 12, Color(0.12, 0.06, 0.02, 0.75 * a))


func _draw_boss(w: float, h: float) -> void:
	var a: float = _boss_a
	var bw: float = minf(1000.0, w * 0.52)
	var r := Rect2((w - bw) * 0.5, h - 92.0, bw, 26)
	_text(Vector2(r.position.x, r.position.y - 16), _boss_name, 34, Color(CREAM, a), true, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(0.1, 0.03, 0.02, 0.8 * a))
	var outer := r.grow(5)
	draw_style_box(box(Color(0.06, 0.03, 0.02, 0.85 * a), Color(GOLD, 0.85 * a), 2, 4, 0.0, 6), outer)
	var inner := r.grow(-1)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * _boss_ghost / _boss_max, inner.size.y)), Color(1.0, 0.8, 0.5, a))
	var fr := Rect2(inner.position, Vector2(inner.size.x * _boss / _boss_max, inner.size.y))
	draw_rect(fr, Color(0.62, 0.08, 0.06, a))
	draw_rect(Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.35)), Color(1, 0.6, 0.4, 0.2 * a))
	for x: float in [outer.position.x, outer.end.x]:
		var c := Vector2(x, outer.get_center().y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(0, -12), c + Vector2(12, 0), c + Vector2(0, 12)]), Color(GOLD, a))
		draw_circle(c, 4.0, Color(WOOD_DARK, a))


func _draw_toast(w: float) -> void:
	var tdat: Dictionary = _toasts[0]
	var kind: String = tdat.kind
	var dur: float = 3.2 if kind == "level" else 2.6
	var t: float = _toast_t
	var a: float = clampf(t / 0.2, 0.0, 1.0) * clampf((dur - t) / 0.45, 0.0, 1.0)
	var sc: float = 0.7 + 0.3 * ease(clampf(t / 0.28, 0.0, 1.0), -2.4)
	var big: bool = kind == "level"
	var tsize: int = 58 if big else 38
	var f: Font = font(true)
	var tw: float = f.get_string_size(tdat.title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
	var sw: float = font(false).get_string_size(tdat.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var bw: float = maxf(tw, sw) + 120.0
	var bh: float = (tsize + 34.0) + (40.0 if tdat.sub != "" else 0.0)
	var c := Vector2(w * 0.5, 432.0)
	draw_set_transform(c, 0.0, Vector2(sc, sc))
	var r := Rect2(-bw * 0.5, -bh * 0.5, bw, bh)
	var bg: Color = PARCH
	var fg: Color = INK
	var border: Color = WOOD
	match kind:
		"level":
			bg = Color(0.24, 0.13, 0.05)
			fg = GOLD
			border = GOLD
			# rays behind the plaque
			for i in 16:
				var ang: float = TAU * i / 16.0 + _time * 0.3
				var p1 := Vector2.from_angle(ang) * (bw * 0.42)
				var p2 := Vector2.from_angle(ang + 0.08) * (bw * 0.62)
				var p3 := Vector2.from_angle(ang - 0.08) * (bw * 0.62)
				draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(GOLD, 0.22 * a))
		"quest":
			border = EMBER
		"reward":
			border = GOLD
	var sb := box(Color(bg, 0.95 * a), Color(border, a), 4, 14, 0.0, 10)
	sb.shadow_color = Color(SHADOW, 0.5 * a)
	draw_style_box(sb, r)
	draw_style_box(box(Color.TRANSPARENT, Color(border, 0.45 * a), 2, 10), r.grow(-9))
	var ty: float = r.position.y + tsize + 10.0
	_text(Vector2(r.position.x, ty), tdat.title, tsize, Color(fg, a), true, HORIZONTAL_ALIGNMENT_CENTER, bw)
	if tdat.sub != "":
		_text(Vector2(r.position.x, ty + 44.0), tdat.sub, 30, Color(CREAM if big else INK, a), false, HORIZONTAL_ALIGNMENT_CENTER, bw)
	draw_set_transform(Vector2.ZERO)
