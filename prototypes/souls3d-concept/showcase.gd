# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is a dark 3D souls-like fight (stamina, roll, lock-on, Seed spell) fun on a phone?
# Date: 2026-10-21
extends Node3D
var stone: StandardMaterial3D
func _ready():
	var we := WorldEnvironment.new(); var e := Environment.new(); we.environment = e; add_child(we)
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.04, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.3, 0.32, 0.4); e.ambient_light_energy = 0.7
	e.fog_enabled = true; e.fog_light_color = Color(0.1, 0.11, 0.15); e.fog_density = 0.035
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var moon := DirectionalLight3D.new(); moon.rotation_degrees = Vector3(-40, 140, 0); moon.light_color = Color(0.6, 0.65, 0.9); moon.light_energy = 0.7; moon.shadow_enabled = true; add_child(moon)
	stone = _pbr("castle_wall_slates", 1.0)
	var floor := MeshInstance3D.new(); floor.mesh = PlaneMesh.new(); floor.mesh.size = Vector2(40, 40); floor.material_override = _pbr("cobblestone_floor_08", 10.0); add_child(floor)
	var layout := {"archway_gate": Vector3(0, 0, -7), "column_broken": Vector3(-5, 0, -4), "wall_ruin": Vector3(5, 0, -5), "bonfire": Vector3(0, 0, 0), "graves": Vector3(-4.5, 0, 1.5), "seed_shrine": Vector3(4, 0, 0.5), "torch_sconce": Vector3(-1.4, 2.4, -6.6), "longsword": Vector3(1.8, 0.4, 2.6), "shield": Vector3(2.6, 0.45, 2.6)}
	for n in layout:
		var s = load("res://assets/props/%s.glb" % n).instantiate()
		s.position = layout[n]
		if n == "longsword": s.rotation_degrees = Vector3(0, 30, 70)
		if n == "shield": s.rotation_degrees = Vector3(-15, -20, 0)
		add_child(s)
		for m in s.find_children("*", "MeshInstance3D", true, false):
			for i in m.mesh.get_surface_count():
				var mat = m.mesh.surface_get_material(i)
				if mat and mat.resource_name == "stone": m.set_surface_override_material(i, stone)
	var fire := OmniLight3D.new(); fire.position = Vector3(0, 0.8, 0); fire.light_color = Color(1, 0.5, 0.15); fire.light_energy = 3.5; fire.omni_range = 9; add_child(fire)
	var glow := OmniLight3D.new(); glow.position = Vector3(4, 2.2, 0.5); glow.light_color = Color(1, 0.55, 0.15); glow.light_energy = 1.5; glow.omni_range = 4; add_child(glow)
	var cam := Camera3D.new(); cam.position = Vector3(0, 3.4, 8.5); cam.fov = 62; add_child(cam); cam.look_at(Vector3(0, 1.2, -2))
func _pbr(name: String, uv: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_diff_1k.jpg" % name); m.normal_enabled = true; m.normal_texture = load("res://assets/tex/%s_nor_gl_1k.jpg" % name)
	m.roughness_texture = load("res://assets/tex/%s_rough_1k.jpg" % name); m.uv1_scale = Vector3(uv, uv, uv)
	return m
