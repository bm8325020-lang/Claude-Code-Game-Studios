# PROTOTYPE - NOT FOR PRODUCTION
# CharacterKit: builds a rigged Quaternius character from the modular parts in assets/chars/parts (outfit pieces
# share one skeleton), adds a head, hair and colours, and puts props from assets/props in the hands.
#
#   var ch := CharacterKit.make({"body": "Female", "outfit": "Ranger", "hair": "Hair_Long", "weapon": "Sword_Bronze"})
#
# look keys (all optional):
#   body "Male"|"Female"; outfit "Peasant"|"Ranger" (default for every piece);
#   arms/torso/legs/feet: override the outfit of one piece ("Peasant"/"Ranger");
#   hood: bool (Ranger hood, hides hair), pauldrons: bool (Ranger only);
#   hair: "Hair_SimpleParted"|"Hair_Long"|"Hair_Buns"|"Hair_Buzzed"|"Hair_BuzzedFemale"|"" ; beard: bool;
#   tint: Color multiplies the outfit texture (cloth dye), hair_color: Color;
#   weapon: prop name ("Sword_Bronze", "Axe_Bronze", "Pickaxe_Bronze", "Torch_Metal"...) or "";
#   shield: "Shield_Wooden" or "".
# Result: Node3D "Character" facing +Z, feet at y=0, with
#   Model/Armature/Skeleton3D (meshes, hand attachments "WeaponR"/"WeaponL"),
#   Anim: AnimationPlayer with AnimLib's library ("" library: raw UAL clip names and authored action names).
# Metadata: "skeleton" (Skeleton3D), "anim" (AnimationPlayer), "look" (Dictionary).
# HeroAnim adds the AnimationTree; enemies can call Anim.play("Walk") directly.
class_name CharacterKit
extends RefCounted

const PARTS: String = "res://assets/chars/parts/"
const CHARS: String = "res://assets/chars/"

# Hand-measured grips (in hand bone space), tuned with tools/anim_preview.gd from several angles.
# Each: [origin offset, euler degrees]. The prop's own origin is at its grip/guard, blade or haft along +Y.
const GRIP: Dictionary = {
	"Sword_Bronze": [Vector3(0.0, 0.0, 0.0), Vector3(0, 0, 0)],
	"Axe_Bronze": [Vector3(0.0, 0.26, 0.0), Vector3(0, 0, 0)],
	"Pickaxe_Bronze": [Vector3(0.0, 0.2, 0.0), Vector3(0, 0, 0)],
	"Shield_Wooden": [Vector3(0.0, 0.0, 0.0), Vector3(0, 0, 0)],
}

static var _mats: Dictionary = {}


static func make(look: Dictionary) -> Node3D:
	var body: String = look.get("body", "Male")
	var outfit: String = look.get("outfit", "Peasant")
	var root := Node3D.new()
	root.name = "Character"
	var pieces: Array[String] = []
	pieces.append("%s_%s_Body" % [body, look.get("torso", outfit)])
	pieces.append("%s_%s_Arms" % [body, look.get("arms", outfit)])
	pieces.append("%s_%s_Legs" % [body, look.get("legs", outfit)])
	var feet: String = look.get("feet", outfit)
	pieces.append("%s_%s_Feet%s" % [body, feet, "_Boots" if feet == "Ranger" and body == "Male" else ""])
	var hood: bool = look.get("hood", false)
	if hood:
		pieces.append("%s_Ranger_Head_Hood" % body)
	if look.get("pauldrons", false):
		pieces.append("%s_Ranger_Acc_Pauldron%s" % [body, "s" if body == "Female" else ""])
	var model: Node3D = load(PARTS + pieces[0] + ".gltf").instantiate()
	model.name = "Model"
	root.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var extra: Array[String] = []
	for i in range(1, pieces.size()):
		extra.append(PARTS + pieces[i] + ".gltf")
	extra.append(CHARS + "Head_%s.glb" % body)
	var hair: String = look.get("hair", "Hair_SimpleParted" if body == "Male" else "Hair_Long")
	if hair != "" and not hood:
		extra.append(CHARS + hair + ".gltf")
	if look.get("beard", false):
		extra.append(CHARS + "Hair_Beard.gltf")
	for path in extra:
		_graft(sk, path)
	var tint: Color = look.get("tint", Color.WHITE)
	var hair_color: Color = look.get("hair_color", Color(0.32, 0.2, 0.12))
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		_paint(mi as MeshInstance3D, tint, hair_color, body)
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.root_node = ap.get_path_to(sk.get_parent())
	ap.add_animation_library("", AnimLib.library(sk))
	ap.playback_default_blend_time = 0.2
	root.set_meta("skeleton", sk)
	root.set_meta("anim", ap)
	root.set_meta("look", look.duplicate())
	set_weapon(root, look.get("weapon", ""))
	set_shield(root, look.get("shield", ""))
	return root


# Moves the meshes of another part file onto this skeleton (same rig, bones bound by name).
static func _graft(sk: Skeleton3D, path: String) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		push_warning("CharacterKit: missing " + path)
		return
	var src: Node = ps.instantiate()
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)
		mi.owner = null
		sk.add_child(mi)
		(mi as MeshInstance3D).skeleton = NodePath("..")
	src.free()


static func _paint(mi: MeshInstance3D, tint: Color, hair_color: Color, body: String) -> void:
	var nm: String = mi.name
	for s in mi.mesh.get_surface_count():
		var m: Material = mi.get_active_material(s)
		var key: String = ""
		if nm.begins_with("Hair") or nm.contains("Beard") or nm == "Eyebrows":
			key = "hair|%s|%s" % [hair_color.to_html(), body]
		elif m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
			var tex: String = (m as BaseMaterial3D).albedo_texture.resource_path
			if not tint.is_equal_approx(Color.WHITE) and (tex.contains("Peasant") or tex.contains("Ranger")):
				key = "cloth|%s|%s" % [tint.to_html(), m.resource_name]
		if key == "":
			continue
		if not _mats.has(key):
			var nmat: StandardMaterial3D
			if key.begins_with("hair"):
				nmat = StandardMaterial3D.new()
				var htex: String = CHARS + "Head_%s_T_Hair_%d_BaseColor.png" % [body, 2 if body == "Female" else 1]
				if ResourceLoader.exists(htex):
					nmat.albedo_texture = load(htex)
				nmat.albedo_color = hair_color
				nmat.roughness = 0.75
				nmat.cull_mode = BaseMaterial3D.CULL_DISABLED
				if nm == "Eyebrows" and m is BaseMaterial3D:
					nmat = (m as BaseMaterial3D).duplicate()
					nmat.albedo_color = hair_color * 0.8
			else:
				nmat = (m as StandardMaterial3D).duplicate()
				nmat.albedo_color = tint
			_mats[key] = nmat
		mi.set_surface_override_material(s, _mats[key])


# Puts prop `prop` in the right hand ("" removes it).
static func set_weapon(ch: Node3D, prop: String) -> void:
	_hold(ch, "WeaponR", "hand_r", prop)


# Puts a shield (or any prop) on the left forearm ("" removes it).
static func set_shield(ch: Node3D, prop: String) -> void:
	_hold(ch, "WeaponL", "hand_l", prop)


static func _hold(ch: Node3D, slot: String, bone: String, prop: String) -> void:
	var sk: Skeleton3D = ch.get_meta("skeleton")
	var old: Node = sk.get_node_or_null(slot)
	if old != null:
		sk.remove_child(old)
		old.queue_free()
	var look: Dictionary = ch.get_meta("look", {})
	look["weapon" if slot == "WeaponR" else "shield"] = prop
	if prop == "":
		return
	var att := BoneAttachment3D.new()
	att.name = slot
	att.bone_name = bone
	sk.add_child(att)
	var p: Node3D = load("res://assets/props/%s.gltf" % prop).instantiate()
	p.name = "Prop"
	att.add_child(p)
	p.transform = grip_transform(sk, prop, bone)
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


# Where the prop sits in the hand bone's space. Built from the hand's own finger bones so it fits any body size.
static func grip_transform(sk: Skeleton3D, prop: String, bone: String) -> Transform3D:
	var side: String = bone.right(2)
	var hand: int = sk.find_bone(bone)
	var index: Vector3 = sk.get_bone_rest(sk.find_bone("index_01" + side)).origin
	var pinky: Vector3 = sk.get_bone_rest(sk.find_bone("pinky_01" + side)).origin
	var middle: Vector3 = sk.get_bone_rest(sk.find_bone("middle_01" + side)).origin
	if hand < 0:
		return Transform3D.IDENTITY
	var g: Array = GRIP.get(prop, [Vector3.ZERO, Vector3.ZERO])
	var up: Vector3 = (index - pinky).normalized()           # out of the fist on the thumb side
	var fwd: Vector3 = (middle - up * middle.dot(up)).normalized()  # knuckles direction
	var basis := Basis(fwd, up, fwd.cross(up))
	var center: Vector3 = (index + pinky) * 0.5 * 0.55       # middle of the closed fist
	var xf := Transform3D(basis, center)
	if prop.begins_with("Shield"):
		# strapped to the forearm, face out of the back of the hand, top toward the elbow
		var rest: Transform3D = sk.get_bone_rest(hand)
		var elbow: Vector3 = -(rest.basis.inverse() * rest.origin)
		var y: Vector3 = elbow.normalized()
		var z: Vector3 = fwd.cross(up) * (-1.0 if side == "_l" else 1.0)
		z = (z - y * z.dot(y)).normalized()
		xf = Transform3D(Basis(y.cross(z), y, z), elbow * 0.42 + z * 0.06)
	return xf * Transform3D(Basis.from_euler((g[1] as Vector3) * (PI / 180.0)), g[0])
