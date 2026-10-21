extends Node3D
func _ready():
	var we := WorldEnvironment.new(); var e := Environment.new(); we.environment = e; add_child(we)
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.25, 0.27, 0.35); e.ambient_light_energy = 0.6
	e.fog_enabled = true; e.fog_light_color = Color(0.12, 0.13, 0.17); e.fog_density = 0.05
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var moon := DirectionalLight3D.new(); moon.rotation_degrees = Vector3(-35, 150, 0); moon.light_color = Color(0.55, 0.6, 0.85); moon.light_energy = 0.5; moon.shadow_enabled = true; add_child(moon)
	var floor := MeshInstance3D.new(); floor.mesh = PlaneMesh.new(); floor.mesh.size = Vector2(40, 40); floor.material_override = _pbr("cobblestone_floor_08", 10.0); add_child(floor)
	for i in 6:
		var p := MeshInstance3D.new(); p.mesh = CylinderMesh.new(); p.mesh.top_radius = 0.6; p.mesh.bottom_radius = 0.7; p.mesh.height = 7
		p.position = Vector3(-6 + (i % 2) * 12, 3.5, -2 - (i / 2) * 7); p.material_override = _pbr("castle_wall_slates", 2.0); add_child(p)
		var t := OmniLight3D.new(); t.position = p.position + Vector3(0.9 * (1 if i % 2 == 0 else -1), 0.5, 0); t.light_color = Color(1, 0.55, 0.2); t.light_energy = 2.5; t.omni_range = 7; add_child(t)
		var flame := MeshInstance3D.new(); flame.mesh = SphereMesh.new(); flame.mesh.radius = 0.12; flame.mesh.height = 0.3; var fm := StandardMaterial3D.new(); fm.emission_enabled = true; fm.emission = Color(1, 0.6, 0.2); fm.emission_energy_multiplier = 4; fm.albedo_color = Color(1, 0.6, 0.2); flame.material_override = fm; flame.position = t.position; add_child(flame)
	var wall := MeshInstance3D.new(); wall.mesh = BoxMesh.new(); wall.mesh.size = Vector3(30, 8, 1); wall.position = Vector3(0, 4, -24); wall.material_override = _pbr("castle_wall_slates", 6.0); add_child(wall)
	var k = _knight(); k.position = Vector3(0, 0, 4); k.rotation_degrees.y = 20; add_child(k)
	var d = load("res://assets/dragon/dragon.dae").instantiate(); d.scale = Vector3(7, 7, 7); d.position = Vector3(0, 2.5, -12); add_child(d)
	var dm := StandardMaterial3D.new(); dm.albedo_texture = load("res://assets/dragon/dragon_black.png"); dm.roughness = 0.6
	for m in d.find_children("*", "MeshInstance3D", true, false): m.material_override = dm
	var eye := OmniLight3D.new(); eye.light_color = Color(1, 0.3, 0.1); eye.light_energy = 3; eye.position = Vector3(0, 4, -8); eye.omni_range = 6; add_child(eye)
	var key := OmniLight3D.new(); key.position = Vector3(1.5, 2.5, 6.5); key.light_color = Color(1, 0.7, 0.45); key.light_energy = 2.0; key.omni_range = 6; add_child(key)
	var cam := Camera3D.new(); cam.position = Vector3(-1.4, 2.2, 7.2); cam.fov = 60; add_child(cam); cam.look_at(Vector3(0, 1.3, 2))
func _pbr(name: String, uv: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_diff_1k.jpg" % name); m.normal_enabled = true; m.normal_texture = load("res://assets/tex/%s_nor_gl_1k.jpg" % name)
	m.roughness_texture = load("res://assets/tex/%s_rough_1k.jpg" % name); m.uv1_scale = Vector3(uv, uv, uv)
	return m
func _knight() -> Node3D:
	var k = load("res://assets/knight/KnightCharacter.fbx").instantiate()
	k.scale = Vector3(0.55, 0.55, 0.55)
	k.get_node("AnimationPlayer").play("HumanArmature|Idle_swordRight")
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color(0.22, 0.22, 0.25); steel.metallic = 0.85; steel.roughness = 0.35
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = Color(0.18, 0.06, 0.05); cloth.roughness = 0.9
	var body: MeshInstance3D = k.find_child("Knight", true, false)
	for s in body.mesh.get_surface_count():
		body.set_surface_override_material(s, steel if s % 2 == 0 else cloth)
	var skel: Skeleton3D = k.find_child("Skeleton3D", true, false)
	for pair in [["Helmet1", "Head"], ["ShoulderPads", "Torso"], ["Sword", "Palm.R"]]:
		var acc = load("res://assets/knight/%s.fbx" % pair[0]).instantiate()
		var ba := BoneAttachment3D.new(); ba.bone_name = pair[1]; skel.add_child(ba)
		var bi := skel.find_bone(pair[1])
		ba.add_child(acc)
		acc.transform = skel.get_bone_global_rest(bi).affine_inverse() * (skel.get_parent() as Node3D).transform.affine_inverse()
		for m in acc.find_children("*", "MeshInstance3D", true, false): m.material_override = steel
	return k
