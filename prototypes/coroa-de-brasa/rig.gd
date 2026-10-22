# PROTOTYPE - NOT FOR PRODUCTION
# KayKit characters (Adventurers and Skeletons share the Rig_Medium skeleton): the model, its weapons on the hand
# slots, an optional colour tint, and one AnimationPlayer holding every Rig_Medium clip (the KayKit Character
# Animations pack), loaded once and shared.
extends RefCounted

const ANIM_FILES := ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "CombatRanged", "Simulation", "Special", "Tools"]
const LOOPS := ["Idle_A", "Idle_B", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C", "Walking_Backwards",
	"Running_Strafe_Left", "Running_Strafe_Right", "Melee_Blocking", "Melee_2H_Idle", "Melee_Unarmed_Idle", "Ranged_Bow_Idle",
	"Ranged_Bow_Aiming_Idle", "Ranged_Magic_Spellcasting", "Melee_2H_Attack_Spinning", "Skeletons_Idle", "Skeletons_Walking",
	"Sit_Chair_Idle", "Sit_Floor_Idle", "Lie_Idle", "Hammering", "Working_A", "Working_B", "Working_C", "Chopping", "Sawing",
	"Fishing_Idle", "Crouching", "Sneaking", "Jump_Idle", "Waving", "Cheering", "Push_Ups"]

static var lib: AnimationLibrary

static func library() -> AnimationLibrary:
	if lib == null:
		lib = AnimationLibrary.new()
		for f in ANIM_FILES:
			var n: Node = load("res://assets/anims/Rig_Medium_%s.glb" % f).instantiate()
			var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
			for a in ap.get_animation_list():
				if a == "T-Pose" or lib.has_animation(a):
					continue
				var anim: Animation = ap.get_animation(a).duplicate()
				anim.loop_mode = Animation.LOOP_LINEAR if a in LOOPS else Animation.LOOP_NONE
				lib.add_animation(a, anim)
			n.free()
	return lib

# [root node, AnimationPlayer]; dir is "heroes" or "skeletons"; right/left are weapon model names ("" for none)
static func make(dir: String, model: String, right := "", left := "", tint := Color.WHITE) -> Array:
	var root: Node3D = load("res://assets/%s/%s.glb" % [dir, model]).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	for w in [[right, "handslot.r"], [left, "handslot.l"]]:
		if w[0] == "":
			continue
		var ba := BoneAttachment3D.new()
		ba.bone_name = w[1]
		sk.add_child(ba)
		var wdir := "skeletons" if w[0].begins_with("Skeleton_") else "weapons"
		ba.add_child(load("res://assets/%s/%s.gltf" % [wdir, w[0]]).instantiate())
	if tint != Color.WHITE:
		for mi in sk.find_children("*", "MeshInstance3D", false, false):
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i) as StandardMaterial3D
				if m != null:
					var d: StandardMaterial3D = m.duplicate()
					d.albedo_color = tint
					mi.set_surface_override_material(i, d)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var ap := AnimationPlayer.new()
	root.add_child(ap)
	ap.root_node = NodePath("..")
	# the clips' tracks are "Rig_Medium/Skeleton3D:bone": the characters have the same node names
	ap.add_animation_library("", library())
	return [root, ap]

# a static prop from a kit folder
static func prop(dir: String, name: String) -> Node3D:
	return load("res://assets/%s/%s.gltf" % [dir, name]).instantiate()

# merges every static mesh under node (kit props share a texture per kit) into one mesh per material: a room of
# a hundred pieces becomes a few draw calls. Characters (anything with a Skeleton3D) and lights are left alone.
static func merge_static(node: Node3D) -> void:
	var tools := {}
	var drop := []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var skip := false
		var p: Node = mi
		while p != node:
			if p is Skeleton3D or p is CPUParticles3D or (p is Node3D and p.has_meta("keep")):
				skip = true
				break
			p = p.get_parent()
		if skip or mi.mesh == null:
			continue
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else _local_xf(mi, node)
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			var key = mat.albedo_texture if mat is StandardMaterial3D and mat.albedo_texture != null else mat  # every file of a kit has its own copy of the one material
			if not tools.has(key):
				tools[key] = [SurfaceTool.new(), mat]
				tools[key][0].begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key][0].append_from(mi.mesh, i, xf)
		drop.append(mi)
	for mi in drop:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in tools:
		var out := MeshInstance3D.new()
		var m := ArrayMesh.new()
		tools[key][0].commit(m)
		m.surface_set_material(0, tools[key][1])
		out.mesh = m
		node.add_child(out)

static func _local_xf(mi: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D()
	var p: Node = mi
	while p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
