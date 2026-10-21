# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does dodging through a telegraphed attack and punishing the recovery feel satisfying and fair on touch?
# Date: 2026-10-21
extends Node2D

# --- Tuning (frames at 60 Hz) -------------------------------------------------
const ARENA_CENTER := Vector2(960, 570)
const ARENA_RADII := Vector2(820, 400)
const BUFFER_FRAMES := 9

const P_SPEED := 380.0
const P_RADIUS := 44.0
const P_MAX_HP := 5
const ATK_WINDUP := 5
const ATK_ACTIVE := 6
const ATK_RECOVERY := 14
const ATK_REACH := 145.0
const ATK_ARC := deg_to_rad(110.0)
const ATK_DAMAGE := 8
const DODGE_FRAMES := 18
const DODGE_IFRAMES := 14
const DODGE_SPEED := 1050.0
const DODGE_COOLDOWN := 22
const HURT_IFRAMES := 45

const E_RADIUS := 80.0
const E_MAX_HP := 140
const E_SPEED := 175.0
const SLAM_TELEGRAPH := 40
const SLAM_ACTIVE := 6
const SLAM_RECOVERY := 50
const SLAM_RADIUS := 240.0
const LUNGE_TELEGRAPH := 38
const LUNGE_LOCK := 26
const LUNGE_ACTIVE := 16
const LUNGE_RECOVERY := 46
const LUNGE_SPEED := 1350.0

const COL_TELEGRAPH := Color(1.0, 0.18, 0.7)
const COL_PLAYER_FX := Color(1.0, 0.93, 0.65)
const COL_SILHOUETTE := Color(0.04, 0.04, 0.07)

# --- State ---------------------------------------------------------------------
var p_pos := Vector2(560, 570)
var p_face := Vector2.RIGHT
var p_hp := P_MAX_HP
var p_state := "idle"  # idle, attack, dodge, dead
var p_timer := 0
var p_dodge_dir := Vector2.RIGHT
var p_dodge_cd := 0
var p_hurt := 0
var p_hit_this_swing := false
var buffered := ""
var buffer_left := 0
var punish_bonus := 0

var e_pos := Vector2(1360, 570)
var e_hp := E_MAX_HP
var e_state := "chase"  # chase, slam_tel, slam_act, slam_rec, lunge_tel, lunge_act, lunge_rec, dead
var e_timer := 0
var e_cooldown := 40
var e_lunge_dir := Vector2.LEFT
var e_flash := 0
var last_attack_name := ""

var hitstop := 0
var slowmo := 0
var shake := 0.0
var end_timer := 0
var end_text := ""
var frame := 0
var floaters: Array = []

# Playtest metrics (the hypothesis signal)
var stats := {"time": 0.0, "punishes": 0, "perfect_dodges": 0, "deaths": 0, "wins": 0, "first_chain_time": -1.0, "chains": 0}
var chain_dodged := false

var bg_tex: GradientTexture2D
var hud: Label
var big: Label
var touch_layer: CanvasLayer
var btn_attack: TouchScreenButton
var btn_dodge: TouchScreenButton
var joystick: Control

func _ready() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.09, 0.08, 0.25), Color(0.55, 0.22, 0.32), Color(0.05, 0.2, 0.26)])
	bg_tex = GradientTexture2D.new()
	bg_tex.gradient = g
	bg_tex.fill_from = Vector2(0, 0)
	bg_tex.fill_to = Vector2(0, 1)
	bg_tex.width = 4
	bg_tex.height = 256
	_build_ui()
	get_tree().root.size_changed.connect(_layout_ui)
	_layout_ui()

func _build_ui() -> void:
	touch_layer = CanvasLayer.new()
	add_child(touch_layer)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 30)
	hud.position = Vector2(30, 20)
	touch_layer.add_child(hud)
	big = Label.new()
	big.add_theme_font_size_override("font_size", 64)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	touch_layer.add_child(big)
	joystick = ClassDB.instantiate("VirtualJoystick")
	joystick.set("joystick_mode", 1)  # Dynamic
	joystick.set("action_left", "move_left")
	joystick.set("action_right", "move_right")
	joystick.set("action_up", "move_up")
	joystick.set("action_down", "move_down")
	joystick.set("joystick_size", 230)
	joystick.set("tip_size", 100)
	touch_layer.add_child(joystick)
	btn_attack = _make_button("attack", 120.0)
	btn_dodge = _make_button("dodge", 95.0)

func _make_button(action: String, radius: float) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	var s := CircleShape2D.new()
	s.radius = radius
	b.shape = s
	b.shape_centered = true
	b.action = action
	b.passby_press = false
	touch_layer.add_child(b)
	return b

func _layout_ui() -> void:
	var vs := get_viewport_rect().size
	joystick.position = Vector2(0, vs.y * 0.3)
	joystick.size = Vector2(vs.x * 0.45, vs.y * 0.7)
	btn_attack.position = Vector2(vs.x - 210, vs.y - 230)
	btn_dodge.position = Vector2(vs.x - 440, vs.y - 140)
	big.position = Vector2(0, vs.y * 0.35)
	big.size = Vector2(vs.x, 200)

func _physics_process(_delta: float) -> void:
	frame += 1
	_read_buffer()
	if hitstop > 0:
		hitstop -= 1
		queue_redraw()
		return
	if slowmo > 0:
		slowmo -= 1
		if slowmo % 2 == 0:
			queue_redraw()
			return
	var dt := 1.0 / 60.0
	if end_timer > 0:
		end_timer -= 1
		if end_timer == 0:
			_reset()
		queue_redraw()
		return
	stats.time += dt
	_update_player(dt)
	_update_enemy(dt)
	_update_floaters()
	shake = max(0.0, shake - 1.2)
	_update_hud()
	queue_redraw()

func _read_buffer() -> void:
	if Input.is_action_just_pressed("attack"):
		buffered = "attack"
		buffer_left = BUFFER_FRAMES
	elif Input.is_action_just_pressed("dodge"):
		buffered = "dodge"
		buffer_left = BUFFER_FRAMES
	elif buffer_left > 0:
		buffer_left -= 1
		if buffer_left == 0:
			buffered = ""

func _consume(action: String) -> bool:
	if buffered == action:
		buffered = ""
		buffer_left = 0
		return true
	return false

func _update_player(dt: float) -> void:
	if p_state == "dead":
		return
	p_hurt = max(0, p_hurt - 1)
	p_dodge_cd = max(0, p_dodge_cd - 1)
	punish_bonus = max(0, punish_bonus - 1)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	match p_state:
		"idle":
			if input.length() > 0.1:
				p_face = input.normalized()
				p_pos += input * P_SPEED * dt
			if _consume("dodge") and p_dodge_cd == 0:
				p_state = "dodge"
				p_timer = 0
				p_dodge_dir = input.normalized() if input.length() > 0.1 else -p_face
				chain_dodged = false
			elif _consume("attack"):
				p_state = "attack"
				p_timer = 0
				p_hit_this_swing = false
				if input.length() > 0.1:
					p_face = input.normalized()
				else:
					p_face = (e_pos - p_pos).normalized()
		"attack":
			p_timer += 1
			if p_timer > ATK_WINDUP and p_timer <= ATK_WINDUP + ATK_ACTIVE and not p_hit_this_swing:
				_try_hit_enemy()
			if p_timer >= ATK_WINDUP + ATK_ACTIVE + ATK_RECOVERY:
				p_state = "idle"
			elif p_timer > ATK_WINDUP + ATK_ACTIVE + 6 and buffered == "dodge" and p_dodge_cd == 0:
				p_state = "idle"  # dodge-cancel the tail of recovery
		"dodge":
			p_timer += 1
			var k := 1.0 - float(p_timer) / DODGE_FRAMES
			p_pos += p_dodge_dir * DODGE_SPEED * (0.35 + 0.65 * k) * dt
			if p_timer >= DODGE_FRAMES:
				p_state = "idle"
				p_dodge_cd = DODGE_COOLDOWN
	p_pos = _clamp_arena(p_pos, P_RADIUS)

func _player_invulnerable() -> bool:
	return p_hurt > 0 or (p_state == "dodge" and p_timer <= DODGE_IFRAMES)

func _try_hit_enemy() -> void:
	if e_state == "dead":
		return
	var to_e := e_pos - p_pos
	if to_e.length() - E_RADIUS > ATK_REACH:
		return
	if abs(p_face.angle_to(to_e)) > ATK_ARC * 0.5 and to_e.length() > E_RADIUS + P_RADIUS:
		return
	p_hit_this_swing = true
	var dmg := ATK_DAMAGE
	var punish := e_state.ends_with("_rec")
	if punish_bonus > 0:
		dmg = int(dmg * 1.5)
	if punish:
		dmg += 4
		stats.punishes += 1
		_float("PUNIÇÃO", e_pos + Vector2(0, -110), COL_PLAYER_FX)
		if chain_dodged:
			stats.chains += 1
			if stats.first_chain_time < 0:
				stats.first_chain_time = stats.time
			chain_dodged = false
	e_hp -= dmg
	e_flash = 5
	hitstop = 5 if punish else 3
	shake = 10.0 if punish else 5.0
	_float(str(dmg), e_pos + Vector2(randf_range(-30, 30), -80), Color.WHITE)
	if e_hp <= 0:
		e_hp = 0
		e_state = "dead"
		stats.wins += 1
		end_text = "VITÓRIA!\nO guardião caiu."
		end_timer = 150
		hitstop = 12
		slowmo = 30

func _update_enemy(dt: float) -> void:
	if e_state == "dead":
		return
	e_flash = max(0, e_flash - 1)
	var to_p := p_pos - e_pos
	var dist := to_p.length()
	match e_state:
		"chase":
			e_cooldown = max(0, e_cooldown - 1)
			if dist > SLAM_RADIUS * 0.75:
				e_pos += to_p.normalized() * E_SPEED * dt
			if e_cooldown == 0:
				if dist < SLAM_RADIUS + 20:
					_enemy_start("slam_tel")
				elif dist < 700 and randf() < 0.03:
					_enemy_start("lunge_tel")
					e_lunge_dir = to_p.normalized()
		"slam_tel":
			e_timer += 1
			if e_timer >= SLAM_TELEGRAPH:
				_enemy_start("slam_act")
				shake = 14.0
		"slam_act":
			e_timer += 1
			if dist < SLAM_RADIUS + P_RADIUS:
				_enemy_hits_player("Pancada")
			if e_timer >= SLAM_ACTIVE:
				_enemy_start("slam_rec")
		"slam_rec":
			e_timer += 1
			if e_timer >= SLAM_RECOVERY:
				_enemy_start("chase")
				e_cooldown = 30
		"lunge_tel":
			e_timer += 1
			if e_timer <= LUNGE_LOCK:
				e_lunge_dir = to_p.normalized()
			if e_timer >= LUNGE_TELEGRAPH:
				_enemy_start("lunge_act")
		"lunge_act":
			e_timer += 1
			e_pos += e_lunge_dir * LUNGE_SPEED * dt
			if dist < E_RADIUS + P_RADIUS + 10:
				_enemy_hits_player("Investida")
			if e_timer >= LUNGE_ACTIVE:
				_enemy_start("lunge_rec")
		"lunge_rec":
			e_timer += 1
			if e_timer >= LUNGE_RECOVERY:
				_enemy_start("chase")
				e_cooldown = 35
	e_pos = _clamp_arena(e_pos, E_RADIUS)

func _enemy_start(state: String) -> void:
	e_state = state
	e_timer = 0

func _enemy_hits_player(attack_name: String) -> void:
	if p_state == "dead":
		return
	if _player_invulnerable():
		if p_state == "dodge" and not chain_dodged:
			chain_dodged = true
			stats.perfect_dodges += 1
			punish_bonus = 40
			slowmo = 14
			_float("ESQUIVA!", p_pos + Vector2(0, -80), COL_PLAYER_FX)
		return
	p_hp -= 1
	p_hurt = HURT_IFRAMES
	last_attack_name = attack_name
	hitstop = 6
	shake = 16.0
	p_pos += (p_pos - e_pos).normalized() * 60.0
	if p_hp <= 0:
		p_state = "dead"
		stats.deaths += 1
		end_text = "VOCÊ MORREU\nGolpe fatal: %s\n%s" % [attack_name, _tip(attack_name)]
		end_timer = 180

func _tip(attack_name: String) -> String:
	if attack_name == "Pancada":
		return "Dica: quando o círculo rosa crescer, esquive PARA FORA dele."
	return "Dica: a linha rosa trava antes do bote — esquive para o LADO."

func _reset() -> void:
	p_pos = Vector2(560, 570)
	p_hp = P_MAX_HP
	p_state = "idle"
	p_hurt = 0
	e_pos = Vector2(1360, 570)
	e_hp = E_MAX_HP
	e_state = "chase"
	e_cooldown = 60
	end_text = ""
	floaters.clear()

func _clamp_arena(pos: Vector2, r: float) -> Vector2:
	var d := (pos - ARENA_CENTER) / (ARENA_RADII - Vector2(r, r))
	if d.length() > 1.0:
		d = d.normalized()
		return ARENA_CENTER + d * (ARENA_RADII - Vector2(r, r))
	return pos

func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 50, "col": col})

func _update_floaters() -> void:
	for f in floaters:
		f.t -= 1
		f.pos.y -= 1.2
	floaters = floaters.filter(func(f): return f.t > 0)

func _update_hud() -> void:
	var first := "—" if stats.first_chain_time < 0 else "%.0fs" % stats.first_chain_time
	hud.text = "Vida: %s   Guardião: %d/%d\nTempo %.0fs · Esquivas perfeitas %d · Punições %d · Esquiva→punição %d (1ª em %s) · Mortes %d · Vitórias %d" % [
		"♥".repeat(p_hp), e_hp, E_MAX_HP, stats.time, stats.perfect_dodges, stats.punishes, stats.chains, first, stats.deaths, stats.wins]
	big.text = end_text

# --- Drawing ("Shadow and Flame": silhouettes, only what matters glows) -------
func _draw() -> void:
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	var vs := get_viewport_rect().size
	draw_texture_rect(bg_tex, Rect2(Vector2.ZERO, vs), false)
	draw_set_transform(off)
	_draw_ellipse(ARENA_CENTER, ARENA_RADII, Color(0.03, 0.12, 0.15))
	_draw_ellipse(ARENA_CENTER, ARENA_RADII * 0.98, Color(0.02, 0.08, 0.1))
	# Enemy telegraphs (reserved hue)
	match e_state:
		"slam_tel":
			var k := float(e_timer) / SLAM_TELEGRAPH
			draw_circle(e_pos, SLAM_RADIUS, Color(COL_TELEGRAPH, 0.12))
			draw_circle(e_pos, SLAM_RADIUS * k, Color(COL_TELEGRAPH, 0.35))
			draw_arc(e_pos, SLAM_RADIUS, 0, TAU, 64, COL_TELEGRAPH, 4.0)
		"slam_act":
			draw_circle(e_pos, SLAM_RADIUS, Color(1, 1, 1, 0.55))
		"lunge_tel":
			var locked := e_timer > LUNGE_LOCK
			var w := 140.0
			var a := e_pos
			var b := e_pos + e_lunge_dir * LUNGE_SPEED * LUNGE_ACTIVE / 60.0
			draw_line(a, b, Color(COL_TELEGRAPH, 0.5 if locked else 0.22), w)
			if locked:
				draw_line(a, b, COL_TELEGRAPH, 6.0)
	# Enemy body
	var e_col := COL_SILHOUETTE
	if e_flash > 0:
		e_col = Color.WHITE
	if e_state != "dead":
		_draw_spiky(e_pos, E_RADIUS, e_col)
		if e_state.ends_with("_rec"):
			var pulse := 0.5 + 0.5 * sin(frame * 0.4)
			draw_arc(e_pos, E_RADIUS + 10, 0, TAU, 48, Color(1, 1, 1, 0.35 + 0.4 * pulse), 4.0)
		draw_circle(e_pos + Vector2(14, -18), 7, COL_TELEGRAPH if e_state.ends_with("_tel") else Color(0.9, 0.85, 0.7))
		var w2 := 160.0
		draw_rect(Rect2(e_pos + Vector2(-w2 / 2, -E_RADIUS - 34), Vector2(w2, 10)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(e_pos + Vector2(-w2 / 2, -E_RADIUS - 34), Vector2(w2 * e_hp / E_MAX_HP, 10)), Color(0.95, 0.9, 0.8))
	# Player attack arc
	if p_state == "attack" and p_timer > ATK_WINDUP and p_timer <= ATK_WINDUP + ATK_ACTIVE:
		var ang := p_face.angle()
		var col := COL_PLAYER_FX if punish_bonus == 0 else Color(1, 1, 1)
		draw_arc(p_pos, ATK_REACH * 0.8, ang - ATK_ARC / 2, ang + ATK_ARC / 2, 24, col, 26.0)
	# Player body
	if p_state != "dead":
		var visible := not (p_hurt > 0 and (frame / 4) % 2 == 0)
		if p_state == "dodge" and p_timer <= DODGE_IFRAMES:
			draw_circle(p_pos - p_dodge_dir * 40, P_RADIUS * 0.8, Color(COL_PLAYER_FX, 0.25))
		if visible:
			draw_circle(p_pos, P_RADIUS + 5, Color(COL_PLAYER_FX, 0.85))
			draw_circle(p_pos, P_RADIUS, COL_SILHOUETTE)
			draw_circle(p_pos + p_face * 18, 6, COL_PLAYER_FX)
	for f in floaters:
		draw_string(ThemeDB.fallback_font, f.pos - Vector2(60, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color(f.col, f.t / 50.0))
	draw_set_transform(Vector2.ZERO)
	_draw_touch_controls(vs)

func _draw_touch_controls(vs: Vector2) -> void:
	var a := Vector2(vs.x - 210, vs.y - 230)
	var d := Vector2(vs.x - 440, vs.y - 140)
	var a_on := Input.is_action_pressed("attack")
	var d_on := Input.is_action_pressed("dodge")
	draw_circle(a, 120, Color(1, 1, 1, 0.22 if a_on else 0.1))
	draw_arc(a, 120, 0, TAU, 48, Color(1, 1, 1, 0.5), 3)
	draw_string(ThemeDB.fallback_font, a - Vector2(80, -12), "ATACAR", HORIZONTAL_ALIGNMENT_CENTER, 160, 34, Color(1, 1, 1, 0.8))
	draw_circle(d, 95, Color(1, 1, 1, 0.22 if d_on else 0.1))
	draw_arc(d, 95, 0, TAU, 48, Color(1, 1, 1, 0.5), 3)
	draw_string(ThemeDB.fallback_font, d - Vector2(80, -12), "ESQUIVA", HORIZONTAL_ALIGNMENT_CENTER, 160, 30, Color(1, 1, 1, 0.8))
	if p_dodge_cd > 0:
		draw_arc(d, 100, -PI / 2, -PI / 2 + TAU * float(p_dodge_cd) / DODGE_COOLDOWN, 32, COL_PLAYER_FX, 6)

func _draw_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 64:
		var t := TAU * i / 64.0
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	draw_colored_polygon(pts, col)

func _draw_spiky(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var t := TAU * i / 14.0
		var rr := r * (1.15 if i % 2 == 0 else 0.85)
		pts.append(c + Vector2(cos(t), sin(t)) * rr)
	draw_colored_polygon(pts, col)
