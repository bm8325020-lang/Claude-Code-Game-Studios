# PROTOTYPE - NOT FOR PRODUCTION
# Touch controls (owner: UI agent): floating left stick, thumb buttons on the right, camera drag on the free right
# side, and the same API for keyboard and gamepad so desktop testing works without a touch screen.
#
# Add one node to a CanvasLayer above the HUD:  var touch := Touch.new(); layer.add_child(touch)
# Read it from anywhere (static, no autoload needed; works even if the node is absent: keyboard/gamepad only):
#   Touch.move_vector() -> Vector2      stick, length 0..1; x right, y down (forward = negative y, like Input.get_vector)
#   Touch.pressed(action) -> bool       went down this frame (correct in _process and in _physics_process)
#   Touch.held(action) -> bool          is down now
#   Touch.look_delta() -> Vector2       camera drag this frame in screen pixels x sensitivity (plus gamepad right stick)
# Actions: attack, heavy, dodge, block, skill, potion, interact, lock, jump, menu.
# Keyboard/gamepad: each action uses the project input action of the same name, or the alias below (dodge=roll,
#   skill=seed, potion=flask); missing actions (heavy) and gamepad events are added at runtime, never removed.
#   Keys: WASD move, J attack, I heavy, Space dodge, U block, K skill, H potion, E interact, L lock, F jump, Esc menu.
#   Pad: left stick, RB attack, RT heavy, B dodge, LB block, Y skill, X potion, A jump, D-pad up interact,
#   R3 lock, Start menu, right stick camera.
# Context and state (static, call from main/hero):
#   Touch.show_interact(label: String)  big contextual button ("Falar", "Abrir", "Descansar"); Touch.hide_interact()
#   Touch.set_button(action, shown: bool, enabled: bool = true)   e.g. hide heavy/block/skill until unlocked
#   Touch.set_badge(action, text)       small counter on a button (potions left), "" clears
#   Touch.set_cooldown(action, frac)    0..1 dark pie over a button (skill recharge)
#   Touch.sensitivity                   camera drag multiplier (menu options write it)
#   Touch.release_all()                 forget every finger (called on pause and on focus loss)
class_name Touch
extends Control

const ACTIONS: Array[String] = ["attack", "heavy", "dodge", "block", "skill", "potion", "interact", "lock", "jump", "menu"]
const ALIASES: Dictionary = {"dodge": "roll", "skill": "seed", "potion": "flask"}
static var label_override: Dictionary = {}  # action -> text, e.g. the skill button names the move it does now
const LABELS: Dictionary = {"attack": "ATACAR", "heavy": "FORTE", "dodge": "ESQUIVA", "block": "DEFESA", "skill": "SOPRO",
	"potion": "POÇÃO", "lock": "MIRA", "jump": "PULAR", "menu": ""}
const STICK_R: float = 135.0

static var sensitivity: float = 1.0
static var _inst: Touch
static var _held: Dictionary = {}
static var _edge_proc: Dictionary = {}
static var _edge_phys: Dictionary = {}
static var _pending_proc: Array[String] = []
static var _pending_phys: Array[String] = []
static var _stick: Vector2 = Vector2.ZERO
static var _look_acc: Vector2 = Vector2.ZERO
static var _look_frame: Vector2 = Vector2.ZERO
static var _actions_ready: bool = false
static var _interact_label: String = ""
static var _shown: Dictionary = {}
static var _enabled: Dictionary = {}
static var _badges: Dictionary = {}
static var _cooldowns: Dictionary = {}

var _fingers: Dictionary = {}     # touch index -> {kind: "stick"|"btn"|"look", action, origin, pos}
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO
var _stick_on: bool = false
var _interact_a: float = 0.0
var _press_fx: Dictionary = {}    # action -> 0..1 flash


# ------------------------------------------------------------------ static API
static func move_vector() -> Vector2:
	if _stick.length_squared() > 0.0001:
		return _stick
	_ensure_actions()
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


static func pressed(action: String) -> bool:
	if Engine.is_in_physics_frame():
		if int(_edge_phys.get(action, -1)) == Engine.get_physics_frames():
			return true
	elif int(_edge_proc.get(action, -1)) == Engine.get_process_frames():
		return true
	var a: String = _input_action(action)
	return a != "" and Input.is_action_just_pressed(a)


static func held(action: String) -> bool:
	if _held.get(action, false):
		return true
	var a: String = _input_action(action)
	return a != "" and Input.is_action_pressed(a)


static func look_delta() -> Vector2:
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if pad.length() < 0.2:
		pad = Vector2.ZERO
	var tree := Engine.get_main_loop() as SceneTree
	var dt: float = tree.root.get_process_delta_time() if tree != null else 0.016
	return (_look_frame + pad * 900.0 * dt) * sensitivity


static func show_interact(label: String) -> void:
	_interact_label = label


static func hide_interact() -> void:
	_interact_label = ""


static func set_button(action: String, shown: bool, enabled: bool = true) -> void:
	_shown[action] = shown
	_enabled[action] = enabled
	if not shown or not enabled:
		_held[action] = false


static func set_badge(action: String, text: String) -> void:
	_badges[action] = text


static func set_cooldown(action: String, frac: float) -> void:
	_cooldowns[action] = clampf(frac, 0.0, 1.0)


static func release_all() -> void:
	_held.clear()
	_stick = Vector2.ZERO
	_look_acc = Vector2.ZERO
	_look_frame = Vector2.ZERO
	if _inst != null:
		_inst._fingers.clear()
		_inst._stick_on = false


static func _input_action(action: String) -> String:
	_ensure_actions()
	var a: String = ALIASES.get(action, action)
	if InputMap.has_action(a):
		return a
	return action if InputMap.has_action(action) else ""


static func _ensure_actions() -> void:
	if _actions_ready:
		return
	_actions_ready = true
	if not InputMap.has_action("heavy"):
		InputMap.add_action("heavy", 0.3)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_I
		InputMap.action_add_event("heavy", k)
	var pad: Dictionary = {"attack": JOY_BUTTON_RIGHT_SHOULDER, "dodge": JOY_BUTTON_B, "block": JOY_BUTTON_LEFT_SHOULDER,
		"skill": JOY_BUTTON_Y, "potion": JOY_BUTTON_X, "jump": JOY_BUTTON_A, "interact": JOY_BUTTON_DPAD_UP,
		"lock": JOY_BUTTON_RIGHT_STICK, "menu": JOY_BUTTON_START}
	for act: String in pad:
		var name: String = ALIASES.get(act, act)
		if InputMap.has_action(name) and not _has_pad(name):
			var b := InputEventJoypadButton.new()
			b.button_index = pad[act]
			InputMap.action_add_event(name, b)
	if not _has_pad("heavy"):
		var trig := InputEventJoypadMotion.new()
		trig.axis = JOY_AXIS_TRIGGER_RIGHT
		trig.axis_value = 1.0
		InputMap.action_add_event("heavy", trig)
	var axes: Dictionary = {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for name: String in axes:
		if not InputMap.has_action(name):
			InputMap.add_action(name, 0.2)
		if not _has_pad(name):
			var m := InputEventJoypadMotion.new()
			m.axis = axes[name][0]
			m.axis_value = axes[name][1]
			InputMap.action_add_event(name, m)


static func _has_pad(action: String) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


static func _fire(action: String) -> void:
	_pending_proc.append(action)
	_pending_phys.append(action)
	_held[action] = true


# ------------------------------------------------------------------ node
func _ready() -> void:
	_inst = self
	_ensure_actions()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = -1000
	process_physics_priority = -1000


func _exit_tree() -> void:
	if _inst == self:
		_inst = null
	release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		release_all()
	# menus and dialogs pause the tree: the thumbs' buttons fade out under them
	if what == NOTIFICATION_PAUSED:
		self_modulate.a = 0.0
	elif what == NOTIFICATION_UNPAUSED:
		self_modulate.a = 1.0


func _process(dt: float) -> void:
	var f: int = Engine.get_process_frames()
	for a in _pending_proc:
		_edge_proc[a] = f
	_pending_proc.clear()
	_look_frame = _look_acc
	_look_acc = Vector2.ZERO
	_interact_a = move_toward(_interact_a, 1.0 if _interact_label != "" else 0.0, dt * 6.0)
	for k in _press_fx.keys():
		_press_fx[k] = maxf(0.0, float(_press_fx[k]) - dt * 4.0)
	queue_redraw()


func _physics_process(_dt: float) -> void:
	var f: int = Engine.get_physics_frames()
	for a in _pending_phys:
		_edge_phys[a] = f
	_pending_phys.clear()


# Button layout in this control's coordinates (base 1920x1080, anchored to the bottom-right for the right thumb).
func _buttons() -> Array[Dictionary]:
	var w: float = size.x
	var h: float = size.y
	var a := Vector2(w - 215.0, h - 205.0)
	var list: Array[Dictionary] = [
		{"id": "attack", "c": a, "r": 108.0},
		{"id": "dodge", "c": a + Vector2.from_angle(deg_to_rad(176.0)) * 238.0, "r": 78.0},
		{"id": "heavy", "c": a + Vector2.from_angle(deg_to_rad(218.0)) * 232.0, "r": 70.0},
		{"id": "block", "c": a + Vector2.from_angle(deg_to_rad(262.0)) * 228.0, "r": 70.0},
		{"id": "jump", "c": a + Vector2.from_angle(deg_to_rad(310.0)) * 215.0, "r": 56.0},
		{"id": "skill", "c": a + Vector2.from_angle(deg_to_rad(232.0)) * 410.0, "r": 64.0},
		{"id": "potion", "c": a + Vector2.from_angle(deg_to_rad(183.0)) * 430.0, "r": 60.0},
		{"id": "lock", "c": a + Vector2.from_angle(deg_to_rad(272.0)) * 420.0, "r": 56.0},
		{"id": "menu", "c": Vector2(w - 76.0, 74.0), "r": 50.0},
	]
	if _interact_label != "":
		list.append({"id": "interact", "c": Vector2(w - 700.0, h - 480.0), "r": 82.0})
	return list


func _hit(p: Vector2) -> String:
	for b in _buttons():
		var id: String = b.id
		if not _shown.get(id, true) or not _enabled.get(id, true):
			continue
		if p.distance_to(b.c) <= float(b.r) * 1.18:  # forgiving: thumbs miss
			return id
	return ""


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var idx: int = -1
	var pos: Vector2
	var down: bool = false
	var up: bool = false
	var drag: bool = false
	if event is InputEventScreenTouch:
		idx = event.index
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag:
		idx = event.index
		pos = event.position
		drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not DisplayServer.is_touchscreen_available():
		idx = 99  # desktop: the mouse plays one finger
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion and _fingers.has(99):
		idx = 99
		pos = event.position
		drag = true
	else:
		return
	pos = get_global_transform_with_canvas().affine_inverse() * pos
	if down:
		_finger_down(idx, pos)
	elif up:
		_finger_up(idx)
	elif drag:
		_finger_move(idx, pos)
	if _fingers.has(idx) or up:
		get_viewport().set_input_as_handled()


func _finger_down(idx: int, p: Vector2) -> void:
	var b: String = _hit(p)
	if b != "":
		_fingers[idx] = {"kind": "btn", "action": b}
		_fire(b)
		_press_fx[b] = 1.0
		return
	if p.x < size.x * 0.42 and p.y > size.y * 0.22 and not _stick_on:
		_fingers[idx] = {"kind": "stick"}
		_stick_on = true
		_stick_origin = p
		_stick_pos = p
		_stick = Vector2.ZERO
		return
	_fingers[idx] = {"kind": "look", "last": p}


func _finger_move(idx: int, p: Vector2) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	match f.kind:
		"stick":
			var d: Vector2 = p - _stick_origin
			if d.length() > STICK_R:  # drag the base along so the thumb never runs out of stick
				_stick_origin = p - d.normalized() * STICK_R
				d = p - _stick_origin
			_stick_pos = p
			var v: Vector2 = d / STICK_R
			_stick = v.normalized() * clampf(inverse_lerp(0.12, 1.0, v.length()), 0.0, 1.0) if v.length() > 0.12 else Vector2.ZERO
		"look":
			_look_acc += p - Vector2(f.last)
			f.last = p
		"btn":
			pass


func _finger_up(idx: int) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	if f.kind == "stick":
		_stick_on = false
		_stick = Vector2.ZERO
	elif f.kind == "btn":
		_held[f.action] = false
	_fingers.erase(idx)


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	# stick: faint resting ring bottom-left; live where the thumb landed
	var base: Vector2 = _stick_origin if _stick_on else Vector2(250.0, size.y - 250.0)
	var knob: Vector2 = base + _stick * STICK_R if _stick_on else base
	var a: float = 0.85 if _stick_on else 0.42
	draw_circle(base, STICK_R + 6.0, Color(0.08, 0.04, 0.02, 0.28 * a))
	draw_arc(base, STICK_R, 0.0, TAU, 64, Color(Hud.GOLD, 0.55 * a), 4.0, true)
	draw_arc(base, STICK_R - 12.0, 0.0, TAU, 64, Color(Hud.CREAM, 0.18 * a), 2.0, true)
	for i in 4:
		var ang: float = TAU * i / 4.0 - PI * 0.5
		var tip := base + Vector2.from_angle(ang) * (STICK_R - 22.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2.from_angle(ang + 2.6) * 12.0,
			tip + Vector2.from_angle(ang - 2.6) * 12.0]), Color(Hud.CREAM, 0.4 * a))
	draw_circle(knob + Vector2(0, 4), 58.0, Color(0, 0, 0, 0.3 * a))
	draw_circle(knob, 56.0, Color(Hud.WOOD_DARK, 0.85 * a))
	draw_circle(knob, 48.0, Color(Hud.WOOD, 0.95 * a))
	draw_arc(knob, 48.0, 0.0, TAU, 48, Color(Hud.GOLD, 0.8 * a), 3.0, true)
	draw_circle(knob + Vector2(-14, -14), 12.0, Color(1, 1, 1, 0.12 * a))
	for b in _buttons():
		var id: String = b.id
		if not _shown.get(id, true):
			continue
		if id == "interact":
			_draw_interact(b.c, b.r)
		else:
			_draw_button(id, b.c, b.r)


func _draw_button(id: String, c: Vector2, r: float) -> void:
	var on: bool = _held.get(id, false) or float(_press_fx.get(id, 0.0)) > 0.0
	var en: bool = _enabled.get(id, true)
	var alpha: float = 1.0 if en else 0.4
	var s: float = r * (0.93 if on else 1.0)
	draw_circle(c + Vector2(0, 5), s + 4.0, Color(0, 0, 0, 0.3 * alpha))
	draw_circle(c, s, Color(Hud.WOOD_DARK, 0.82 * alpha))
	draw_circle(c, s - 6.0, Color(0.27, 0.16, 0.08, 0.72 * alpha) if not on else Color(Hud.EMBER, 0.9))
	draw_arc(c, s - 3.0, 0.0, TAU, 64, Color(Hud.GOLD, 0.9 * alpha), 3.5, true)
	draw_arc(c, s - 11.0, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.14 * alpha), 3.0, true)
	var cd: float = float(_cooldowns.get(id, 0.0))
	if cd > 0.0:
		var pts := PackedVector2Array([c])
		for i in 33:
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * cd * i / 32.0) * (s - 6.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	var ink := Color(Hud.CREAM, alpha)
	_glyph(id, c + Vector2(0, -6 if LABELS.get(id, "") != "" and r > 60.0 else 0), s * 0.42, ink)
	var lbl: String = label_override.get(id, LABELS.get(id, ""))
	if lbl != "" and r > 60.0:
		var f: Font = Hud.font(true)
		var fs: int = 20 if r > 90.0 else 16
		draw_string_outline(f, c + Vector2(-r, s * 0.62), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 4, Color(0, 0, 0, 0.6 * alpha))
		draw_string(f, c + Vector2(-r, s * 0.62), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(Hud.GOLD, alpha))
	var badge: String = _badges.get(id, "")
	if badge != "":
		var bc := c + Vector2(s * 0.72, -s * 0.72)
		draw_circle(bc, 22.0, Hud.WOOD_DARK)
		draw_circle(bc, 18.0, Hud.EMBER)
		draw_string(Hud.font(true), bc + Vector2(-22, 8), badge, HORIZONTAL_ALIGNMENT_CENTER, 44.0, 22, Hud.CREAM)


func _draw_interact(c: Vector2, r: float) -> void:
	var k: float = ease(_interact_a, -2.0)
	if k <= 0.01:
		return
	var pulse: float = 1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.006)
	var s: float = r * k * pulse
	var on: bool = _held.get("interact", false)
	draw_circle(c + Vector2(0, 6), s + 6.0, Color(0, 0, 0, 0.3 * k))
	draw_circle(c, s + 3.0, Color(Hud.WOOD_DARK, k))
	draw_circle(c, s - 4.0, Color(Hud.PARCH, 0.97 * k) if not on else Color(Hud.GOLD, k))
	draw_arc(c, s - 1.0, 0.0, TAU, 64, Color(Hud.GOLD, k), 4.0, true)
	draw_arc(c, s + 14.0, -PI * 0.5, -PI * 0.5 + TAU * fmod(Time.get_ticks_msec() * 0.0004, 1.0), 48,
		Color(Hud.GOLD, 0.5 * k), 3.0, true)
	# a pointing hand reads as "do something here" in any language
	_glyph("interact", c + Vector2(0, -14) * k, s * 0.34, Color(Hud.INK, k))
	var f: Font = Hud.font(true)
	var lbl: String = _interact_label.to_upper()
	var fs: int = 26 if lbl.length() <= 9 else 21
	draw_string(f, c + Vector2(-s, s * 0.52), lbl, HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, fs, Color(Hud.INK, k))


func _glyph(id: String, c: Vector2, u: float, col: Color) -> void:
	var w: float = maxf(3.0, u * 0.16)
	match id:
		"attack":
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y, -d.x)
			var tip := c + d * u * 1.15
			var guard := c - d * u * 0.35
			draw_colored_polygon(PackedVector2Array([tip, guard + n * u * 0.17, guard - n * u * 0.17]), col)
			draw_line(guard + n * u * 0.48, guard - n * u * 0.48, col, w * 1.2, true)
			draw_line(guard, guard - d * u * 0.55, col, w * 1.3, true)
			draw_circle(guard - d * u * 0.68, w * 1.0, col)
		"heavy":
			draw_line(c + Vector2(0, u * 0.95), c + Vector2(0, -u * 0.2), col, w * 1.4, true)
			var head := PackedVector2Array([c + Vector2(-u * 0.75, -u * 0.95), c + Vector2(u * 0.75, -u * 0.95),
				c + Vector2(u * 0.75, -u * 0.25), c + Vector2(-u * 0.75, -u * 0.25)])
			draw_colored_polygon(head, col)
			for i in 3:
				var ang: float = -PI * 0.5 + (i - 1) * 0.6
				var o := c + Vector2(0, -u * 0.6)
				draw_line(o + Vector2.from_angle(ang) * u * 1.0, o + Vector2.from_angle(ang) * u * 1.3, col, w * 0.7, true)
		"dodge":
			draw_arc(c + Vector2(0, u * 0.2), u * 0.75, PI * 0.95, PI * 2.15, 24, col, w * 1.2, true)
			var e := c + Vector2(0, u * 0.2) + Vector2.from_angle(PI * 2.15) * u * 0.75
			draw_colored_polygon(PackedVector2Array([e + Vector2(u * 0.35, -u * 0.05), e + Vector2(-u * 0.25, -u * 0.35),
				e + Vector2(-u * 0.15, u * 0.3)]), col)
			for i in 3:
				var y: float = c.y + u * (0.55 + i * 0.22)
				draw_line(Vector2(c.x - u * (0.9 - i * 0.2), y), Vector2(c.x - u * (0.3 - i * 0.1), y), Color(col, 0.6), w * 0.6)
		"block":
			var pts := PackedVector2Array([c + Vector2(-u * 0.8, -u * 0.85), c + Vector2(u * 0.8, -u * 0.85),
				c + Vector2(u * 0.75, u * 0.05), c + Vector2(0, u * 1.0), c + Vector2(-u * 0.75, u * 0.05)])
			draw_colored_polygon(pts, Color(col, 0.25))
			pts.append(pts[0])
			draw_polyline(pts, col, w * 1.1, true)
			draw_line(c + Vector2(0, -u * 0.8), c + Vector2(0, u * 0.9), col, w * 0.8)
			draw_line(c + Vector2(-u * 0.72, -u * 0.25), c + Vector2(u * 0.72, -u * 0.25), col, w * 0.8)
		"skill":
			var flame := PackedVector2Array()
			for i in 25:
				var t: float = float(i) / 24.0 * TAU
				var rr: float = u * (0.62 + 0.38 * pow(maxf(0.0, -sin(t)), 3.0))
				var p := Vector2(cos(t) * rr * 0.8, sin(t) * rr * 0.75 - pow(maxf(0.0, -sin(t)), 4.0) * u * 0.55)
				flame.append(c + p + Vector2(0, u * 0.2))
			draw_colored_polygon(flame, col)
			draw_circle(c + Vector2(0, u * 0.42), u * 0.28, Color(Hud.EMBER, col.a))
		"potion":
			draw_circle(c + Vector2(0, u * 0.3), u * 0.68, col)
			draw_circle(c + Vector2(0, u * 0.42), u * 0.48, Color(0.75, 0.15, 0.1, col.a))
			draw_rect(Rect2(c + Vector2(-u * 0.22, -u * 0.75), Vector2(u * 0.44, u * 0.55)), col)
			draw_rect(Rect2(c + Vector2(-u * 0.3, -u * 1.0), Vector2(u * 0.6, u * 0.28)), Color(Hud.GOLD, col.a))
			draw_circle(c + Vector2(-u * 0.22, u * 0.18), u * 0.12, Color(1, 1, 1, 0.5 * col.a))
		"jump":
			for i in 2:
				var y: float = c.y + u * (0.15 + i * 0.6) - u * 0.4
				draw_polyline(PackedVector2Array([Vector2(c.x - u * 0.75, y + u * 0.5), Vector2(c.x, y - u * 0.2),
					Vector2(c.x + u * 0.75, y + u * 0.5)]), Color(col, 1.0 - i * 0.4), w * 1.3, true)
		"lock":
			draw_arc(c, u * 0.68, 0.0, TAU, 32, col, w, true)
			draw_circle(c, u * 0.16, col)
			for i in 4:
				var ang: float = TAU * i / 4.0
				draw_line(c + Vector2.from_angle(ang) * u * 0.45, c + Vector2.from_angle(ang) * u * 1.05, col, w, true)
		"menu":
			for i in 3:
				var y: float = c.y + (i - 1) * u * 0.55
				draw_line(Vector2(c.x - u * 0.8, y), Vector2(c.x + u * 0.8, y), col, w * 1.3, true)
		"interact":
			# open hand, palm towards you
			draw_rect(Rect2(c + Vector2(-u * 0.6, -u * 0.1), Vector2(u * 1.2, u * 0.95)), col)
			draw_circle(c + Vector2(0, u * 0.85), u * 0.6, col)
			for i in 4:
				var x: float = c.x - u * 0.5 + i * u * 0.33
				var top: float = c.y - u * (0.95 if i == 1 or i == 2 else 0.75)
				draw_line(Vector2(x, c.y), Vector2(x, top), col, u * 0.26, true)
				draw_circle(Vector2(x, top), u * 0.13, col)
			draw_line(c + Vector2(-u * 0.55, u * 0.3), c + Vector2(-u * 1.0, -u * 0.15), col, u * 0.26, true)
