extends SceneTree
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D: extra = " mesh aabb=" + str((n as MeshInstance3D).get_aabb()) + " skin=" + str((n as MeshInstance3D).skeleton)
	if n is Node3D: extra += " xf=" + str((n as Node3D).transform.origin) + " rot=" + str((n as Node3D).rotation_degrees) + " sc=" + str((n as Node3D).scale)
	print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children(): _dump(c, d + 1)
func _init() -> void:
	for p in ["res://assets/anims/UAL1_Standard.glb", "res://assets/anims/UAL2_Standard.glb"]:
		var s: Node = load(p).instantiate()
		var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var out := []
		for n in ap.get_animation_list():
			out.append("%s:%.2f" % [n, ap.get_animation(n).length])
		print(p, " ", out.size(), "\n", " ".join(out))
		var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
		if p.contains("UAL1"):
			var b := []
			for i in sk.get_bone_count(): b.append(sk.get_bone_name(i))
			print("bones ", b)
			print("pelvis rest ", sk.get_bone_rest(sk.find_bone("pelvis")))
			_dump(s, 0)
		s.free()
	for p in ["res://assets/chars/Male_Peasant.gltf", "res://assets/chars/parts/Male_Peasant_Body.gltf", "res://assets/chars/Head_Male.glb", "res://assets/props/Sword_Bronze.gltf", "res://assets/props/Shield_Wooden.gltf", "res://assets/props/Axe_Bronze.gltf"]:
		var s: Node = load(p).instantiate()
		print("== ", p); _dump(s, 0)
		s.free()
	quit()
