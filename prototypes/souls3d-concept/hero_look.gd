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
	# each piece is named "<bone>__<piece>" and modelled in that bone's space. All pieces become one mesh skinned
	# rigidly to the skeleton, one surface per material: ~50 bone attachments cost ~50 draw calls on phones.
	var armor: Node3D = load("res://assets/props/hero_armor.glb").instantiate()
	var tools := {}  # material name -> SurfaceTool
	for mi in armor.find_children("*", "MeshInstance3D", true, false):
		var bone := skel.find_bone(str(mi.name).split("__")[0])
		var rest := skel.get_bone_global_rest(bone)
		var nb := rest.basis.inverse().transposed()
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var key: String = src.resource_name if src != null and mats.has(src.resource_name) else "plate"
			if not tools.has(key):
				tools[key] = SurfaceTool.new()
				tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			var st: SurfaceTool = tools[key]
			var arr: Array = mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var order: Array = range(verts.size()) if idx == null else Array(idx)
			for v in order:
				st.set_normal((nb * norms[v]).normalized())
				st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				st.add_vertex(rest * verts[v])
	var mesh := ArrayMesh.new()
	for key in tools:
		tools[key].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	var skinned := MeshInstance3D.new()
	skinned.name = "HeroArmor"
	skinned.mesh = mesh
	skel.add_child(skinned)
	skinned.skeleton = skinned.get_path_to(skel)
	skinned.skin = skel.create_skin_from_rest_transforms()
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
