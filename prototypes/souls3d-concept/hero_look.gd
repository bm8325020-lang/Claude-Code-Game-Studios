# PROTOTYPE - NOT FOR PRODUCTION
# Dresses the Mixamo X Bot as the hero: dark gambeson body + hero_armor.glb pieces on the bones,
# with tiling Poly Haven textures (object-space triplanar, the pieces have no UVs).
extends RefCounted

static func dress(model: Node3D) -> void:
	var gambeson := StandardMaterial3D.new()
	gambeson.albedo_color = Color(0.09, 0.07, 0.07)
	gambeson.roughness = 0.95
	for m in model.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, gambeson)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var mats := {
		"plate": _mat("armor_steel", Color(1, 1, 1), 0.8),
		"plate_dark": _mat("armor_steel", Color(0.5, 0.5, 0.52), 0.75),
		"trim": _mat("armor_steel", Color(1.0, 0.72, 0.36), 0.5),
		"leather": _mat("armor_leather", Color(1, 1, 1), 0.0),
		"cloth": _mat("armor_cloth", Color(1, 1, 1), 0.0),
	}
	mats.cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	# each piece is named "<bone>__<piece>" and modelled in that bone's space
	var armor: Node3D = load("res://assets/props/hero_armor.glb").instantiate()
	for mi in armor.find_children("*", "MeshInstance3D", true, false):
		var ba := BoneAttachment3D.new()
		ba.bone_name = str(mi.name).split("__")[0]
		skel.add_child(ba)
		mi.get_parent().remove_child(mi)
		mi.owner = null
		mi.transform = Transform3D.IDENTITY
		ba.add_child(mi)
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src != null and mats.has(src.resource_name):
				mi.set_surface_override_material(i, mats[src.resource_name])
	armor.free()

static func _mat(tex: String, tint: Color, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_diff.jpg" % tex)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/%s_nor_gl.jpg" % tex)
	m.metallic = metal
	if ResourceLoader.exists("res://assets/tex/%s_rough.jpg" % tex):
		m.roughness_texture = load("res://assets/tex/%s_rough.jpg" % tex)
		m.roughness = 1.0
	else:
		m.roughness = 0.8
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	return m
