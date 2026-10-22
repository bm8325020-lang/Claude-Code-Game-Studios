# PROTOTYPE - NOT FOR PRODUCTION
# Fx: cheap combat feedback for mobile (one-shot CPU particles, billboard labels, one ribbon trail) and the damage
# router every attack goes through.
#
#   Fx.deal(source, target, amount, kind) -> Dictionary   # main.damage(target, amount, source, kind) if the current
#                                                         # scene has it, else target.take_hit(amount, source, kind)
#   Fx.sparks(node, pos)  Fx.dust(node, pos)  Fx.embers(node, pos)  Fx.number(node, pos, "12", color)
#   Fx.glint(node, pos)   Fx.sfx(node, "knifeSlice", pos)  Fx.hit_stop(node, 0.06)  Fx.text(node, pos, "Zzz", color)
#   var tr := Fx.Trail.new(); add_child(tr); tr.sample(base, tip) every frame while swinging.
# `node` is any node in the tree: effects are parented to the current scene (or the root), never to the caller,
# so they outlive dying actors. Everything frees itself.
#
# Assumption about main.gd: `func damage(target, amount, source, kind) -> Dictionary` may change `amount`
# (attributes, armour) and react (XP, quests, HUD), and must end by returning target.take_hit(amount, source, kind).
# kind: "light" | "heavy" | "riposte" | "projectile" | "fire".
# Hit-stop drops Engine.time_scale for a few real milliseconds and restores `base_time_scale` (set it if the game
# ever slows time on purpose).
class_name Fx
extends RefCounted

const SFX_DIR: String = "res://assets/sfx/%s.ogg"

static var base_time_scale: float = 1.0
static var _streams: Dictionary = {}
static var _mats: Dictionary = {}
static var _quad: QuadMesh = null
static var _glow_tex: GradientTexture2D = null
static var _stop_id: int = 0


static func deal(source: Node, target: Node, amount: float, kind: String) -> Dictionary:
	if target == null or not is_instance_valid(target) or source == null or not source.is_inside_tree():
		return {}
	var scene: Node = source.get_tree().current_scene
	if scene != null and scene.has_method("damage"):
		var r: Variant = scene.call("damage", target, amount, source, kind)
		return r if r is Dictionary else {}
	if target.has_method("take_hit"):
		return target.call("take_hit", amount, source, kind)
	return {}


static func _host(n: Node) -> Node:
	var t: SceneTree = n.get_tree()
	return t.current_scene if t.current_scene != null else t.root


static func _mat(key: String, additive: bool) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = glow_texture()
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_receive_shadows = true
		_mats[key] = m
	return _mats[key]


# Soft round dot (white centre, transparent edge) shared by sparks, dust and glints.
static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.75))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 32
		_glow_tex.height = 32
	return _glow_tex


static func burst(n: Node, pos: Vector3, color: Color, count: int, speed: float, life: float, size: float,
		gravity: float, additive: bool, spread: float = 180.0) -> void:
	if n == null or not n.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = life
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _mat("add" if additive else "alpha", additive)
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_host(n).add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


static func sparks(n: Node, pos: Vector3, color: Color = Color(1.0, 0.75, 0.35), count: int = 14) -> void:
	burst(n, pos, color, count, 6.0, 0.32, 0.07, 12.0, true)
	burst(n, pos, Color(1, 0.95, 0.8, 0.9), 1, 0.0, 0.09, 0.55, 0.0, true)  # the flash


static func dust(n: Node, pos: Vector3, count: int = 8, size: float = 0.45) -> void:
	burst(n, pos + Vector3(0, 0.1, 0), Color(0.62, 0.52, 0.4, 0.55), count, 1.6, 0.75, size, -0.4, false, 80.0)


static func embers(n: Node, pos: Vector3, count: int = 36) -> void:
	burst(n, pos, Color(1.0, 0.55, 0.15), count, 4.5, 0.9, 0.09, -1.5, true)
	burst(n, pos, Color(1.0, 0.8, 0.4, 0.8), 2, 0.4, 0.25, 1.1, 0.0, true)


# Floating damage number (or any short text) that rises and fades.
static func number(n: Node, pos: Vector3, txt: String, color: Color = Color.WHITE, big: bool = false) -> void:
	text(n, pos + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25)), txt, color, 88 if big else 60, 0.8)


static func text(n: Node, pos: Vector3, txt: String, color: Color, size: int = 60, rise: float = 0.8, life: float = 0.85) -> void:
	if n == null or not n.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = txt
	l.font_size = size
	l.outline_size = 14
	l.outline_modulate = Color(0.08, 0.05, 0.03, 0.85)
	l.modulate = color
	l.pixel_size = 0.0035
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	_host(n).add_child(l)
	l.global_position = pos
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + rise, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE * 1.0, 0.12).from(Vector3.ONE * 1.5)
	tw.tween_property(l, "modulate:a", 0.0, life * 0.45).set_delay(life * 0.55)
	tw.chain().tween_callback(l.queue_free)


# A bright star on a weapon just before it swings: the telegraph players learn to read.
static func glint(n: Node, pos: Vector3, color: Color = Color(1.0, 0.85, 0.5), size: float = 0.9) -> void:
	if n == null or not n.is_inside_tree():
		return
	var s := Sprite3D.new()
	s.texture = glow_texture()
	s.modulate = color
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.pixel_size = size / 32.0
	s.render_priority = 9
	_host(n).add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.05
	var tw: Tween = s.create_tween()
	tw.tween_property(s, "scale", Vector3(1.6, 0.35, 1.0), 0.12)
	tw.tween_property(s, "scale", Vector3(0.4, 1.4, 1.0), 0.12)
	tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.12)
	tw.tween_callback(s.queue_free)


static func sfx(n: Node, names: Variant, pos: Vector3, db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if n == null or not n.is_inside_tree():
		return
	var nm: String = (names as Array).pick_random() if names is Array else String(names)
	if not _streams.has(nm):
		var path: String = SFX_DIR % nm
		_streams[nm] = load(path) if ResourceLoader.exists(path) else null
	if _streams[nm] == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[nm]
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.unit_size = 6.0
	p.max_distance = 40.0
	_host(n).add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# Freezes the action for `dur` real seconds (ignores time scale), then restores base_time_scale.
static func hit_stop(n: Node, dur: float, scale: float = 0.05) -> void:
	if n == null or not n.is_inside_tree():
		return
	_stop_id += 1
	var id: int = _stop_id
	Engine.time_scale = base_time_scale * scale
	n.get_tree().create_timer(dur, true, false, true).timeout.connect(func() -> void:
		if id == _stop_id:
			Engine.time_scale = base_time_scale)


# Ribbon behind a swinging weapon: call sample(base, tip) each frame while it should draw; it fades by itself.
class Trail extends MeshInstance3D:
	const LIFE: float = 0.13
	var color: Color = Color(1.0, 0.92, 0.75, 0.8)
	var _pts: Array = []   # [base: Vector3, tip: Vector3, age: float]
	var _im: ImmediateMesh

	func _init() -> void:
		top_level = true
		_im = ImmediateMesh.new()
		mesh = _im
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		material_override = m

	func sample(base: Vector3, tip: Vector3) -> void:
		_pts.push_front([base, tip, 0.0])
		if _pts.size() > 12:
			_pts.pop_back()

	func _process(dt: float) -> void:
		global_transform = Transform3D.IDENTITY
		for p in _pts:
			p[2] = float(p[2]) + dt
		while not _pts.is_empty() and float(_pts[-1][2]) > LIFE:
			_pts.pop_back()
		_im.clear_surfaces()
		if _pts.size() < 2:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for p in _pts:
			var a: float = clampf(1.0 - float(p[2]) / LIFE, 0.0, 1.0)
			_im.surface_set_color(Color(color.r, color.g, color.b, 0.0))
			_im.surface_add_vertex(p[0])
			_im.surface_set_color(Color(color.r, color.g, color.b, color.a * a))
			_im.surface_add_vertex(p[1])
		_im.surface_end()
