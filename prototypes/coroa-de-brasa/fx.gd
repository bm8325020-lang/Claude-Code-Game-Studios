# PROTOTYPE - NOT FOR PRODUCTION
# Small visual effects made in code: floating damage numbers, red warning rings on the floor before an enemy
# strikes, bursts of sparks, glowing orbs. All unshaded and additive so they read well on a phone screen.
extends RefCounted

static var mats := {}

static func glow(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = col
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		mats[key] = m
	return mats[key]

# a number that rises and fades
static func number(parent: Node, pos: Vector3, text: String, col: Color, big := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 96 if big else 64
	l.outline_size = 18
	l.modulate = col
	l.pixel_size = 0.006
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position", pos + Vector3(randf_range(-0.4, 0.4), 1.4, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)

# a flat ring on the floor that fills while the danger winds up; returns it so the caller can free it early
static func ring(parent: Node, pos: Vector3, radius: float, secs: float, col := Color(1, 0.15, 0.1, 0.55)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 0.9
	tm.outer_radius = radius
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = glow(col)
	mi.position = pos + Vector3(0, 0.08, 0)
	mi.scale = Vector3(1, 0.05, 1)
	parent.add_child(mi)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 32
	disc.mesh = cm
	disc.material_override = glow(Color(col.r, col.g, col.b, 0.25))
	disc.scale = Vector3(0.05, 1, 0.05)
	mi.add_child(disc)
	disc.position.y = 0.0
	var tw := disc.create_tween()
	tw.tween_property(disc, "scale", Vector3(1, 1, 1), secs)
	tw.tween_callback(mi.queue_free)
	return mi

# a burst of glowing bits flying out from pos
static func burst(parent: Node, pos: Vector3, col: Color, n := 10, power := 4.0, size := 0.12) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = power * 0.5
	p.initial_velocity_max = power
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = glow(col)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# a glowing ball (projectiles, pickups)
static func orb(radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = glow(col)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.2
	l.omni_range = radius * 10
	mi.add_child(l)
	return mi

# an expanding flat shockwave
static func wave(parent: Node, pos: Vector3, radius: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = glow(col)
	mi.position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3(0.2, 0.2, 0.2)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel()
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius), 0.3)
	tw.tween_property(mi, "transparency", 1.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)
