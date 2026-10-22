# PROTOTYPE - NOT FOR PRODUCTION
# Quaternius characters (Universal Base Characters rig, Unreal-mannequin bone names: pelvis, spine_01, hand_r...)
# animated by the Universal Animation Library 1 and 2 (CC0). Every clip is also stored under the KayKit name the
# enemy AI already plays (Idle_Combat, Running_A, 1H_Melee_Attack_Chop...), so one AI drives both kinds of model.
extends RefCounted

const SOURCES := ["res://assets/qchars/anims/UAL1_Standard.glb", "res://assets/qchars/anims/UAL2_Standard.glb"]
# KayKit clip name -> Universal Animation Library clip name
const ALIAS := {
	"Idle_Combat": "Sword_Idle", "Running_A": "Jog_Fwd", "Walking_D_Skeletons": "Walk", "Walking_Backwards": "Walk",
	"Running_Strafe_Left": "Jog_Fwd", "Running_Strafe_Right": "Jog_Fwd",
	"1H_Melee_Attack_Chop": "Sword_Regular_A", "1H_Melee_Attack_Slice_Horizontal": "Sword_Regular_B",
	"1H_Melee_Attack_Slice_Diagonal": "Sword_Regular_C", "1H_Melee_Attack_Stab": "Sword_Attack", "1H_Melee_Attack_Jump_Chop": "Sword_Dash_RM",
	"Dualwield_Melee_Attack_Chop": "Sword_Regular_A", "Dualwield_Melee_Attack_Slice": "Sword_Regular_B", "Dualwield_Melee_Attack_Stab": "Sword_Regular_C",
	"Block_Attack": "Shield_OneShot", "Block_Hit": "Sword_Block", "Blocking": "Idle_Shield",
	"Hit_A": "Hit_Chest", "Hit_B": "Hit_Head", "Death_A": "Death01", "Death_B": "Death01", "Death_C_Skeletons": "Death01",
	"Death_C_Skeletons_Resurrect": "LayToIdle", "Skeletons_Inactive_Floor_Pose": "Idle", "Skeletons_Awaken_Floor": "Yes",
	"Spellcasting": "Spell_Simple_Idle", "Spellcast_Raise": "Spell_Simple_Enter", "Spellcast_Shoot": "Spell_Simple_Shoot",
	"2H_Ranged_Aiming": "Idle_Shield", "2H_Ranged_Shoot": "OverhandThrow",
	"Taunt": "Idle_No", "Cheer": "Yes", "Stunned": "Idle_Shield_Break", "Dodge_Backward": "Roll", "Dodge_Left": "Roll", "Dodge_Right": "Roll",
}
const LOOPS := ["Idle", "Sword_Idle", "Jog_Fwd", "Walk", "Walk_Formal", "Sprint", "Idle_Talking", "Idle_Shield", "Spell_Simple_Idle",
	"Zombie_Walk_Fwd", "Zombie_Idle", "Idle_FoldArms", "Idle_Lantern", "Idle_Torch", "Sitting_Idle", "Sitting_Talking", "Crouch_Idle", "TreeChopping",
	"Crouch_Fwd", "Swim_Fwd", "Swim_Idle", "Jump", "Dance", "Idle_Rail_Call", "Idle_No", "Push", "Farm_Harvest", "Farm_Watering", "Fixing_Kneeling", "Walk_Carry", "Idle_Rail"]

static var libs := {}  # model path -> AnimationLibrary (pelvis heights scaled to the model)

# the model and an AnimationPlayer with every clip; shamble=true makes the walk a zombie walk.
# head ("Male"/"Female") and hair add a face: the free outfits come without one (Head_*.glb is cut from the base body)
static func instance(path: String, shamble := false, head := "", hair := "") -> Array:
	var n: Node3D = load(path).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	for part in (["res://assets/qchars/Head_%s.glb" % head] if head != "" else []) + (["res://assets/qchars/%s.gltf" % hair] if hair != "" else []):
		var src: Node = load(part).instantiate()
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			mi.get_parent().remove_child(mi)
			mi.owner = null
			sk.add_child(mi)
			mi.skeleton = NodePath("..")
		src.free()
	for old in n.find_children("*", "AnimationPlayer", true, false):
		old.queue_free()
	var ap := AnimationPlayer.new()
	sk.get_parent().add_child(ap)
	ap.root_node = NodePath("..")
	var key := path + ("|z" if shamble else "")
	if not libs.has(key):
		libs[key] = _build(sk, shamble)
	ap.add_animation_library("", libs[key])
	return [n, ap]

static func _build(sk: Skeleton3D, shamble: bool) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var pelvis := sk.find_bone("pelvis")
	var model_hip := sk.get_bone_rest(pelvis).origin.length()
	for src_path in SOURCES:
		var src: Node = load(src_path).instantiate()
		var src_sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var ratio := model_hip / maxf(0.01, src_sk.get_bone_rest(src_sk.find_bone("pelvis")).origin.length())
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		for name in ap.get_animation_list():
			var a: Animation = ap.get_animation(name).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var bone := String(a.track_get_path(t)).get_slice(":", 1)
				if sk.find_bone(bone) < 0:
					a.remove_track(t)  # bones this model lacks (the imps have no pinkies)
					continue
				a.track_set_path(t, NodePath("Skeleton3D:" + bone))
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					if bone != "pelvis" and bone != "root":
						a.remove_track(t)  # only the hips move; other bones keep this model's proportions
					elif not is_equal_approx(ratio, 1.0):
						for k in a.track_get_key_count(t):
							a.track_set_key_value(t, k, a.track_get_key_value(t, k) * ratio)
			var short := String(name).get_slice("|", String(name).get_slice_count("|") - 1)
			a.loop_mode = Animation.LOOP_LINEAR if short in LOOPS else Animation.LOOP_NONE
			lib.add_animation(short, a)
		src.free()
	for k in ALIAS:
		var target: String = ALIAS[k]
		if shamble and k in ["Walking_D_Skeletons", "Running_A", "Skeletons_Inactive_Floor_Pose", "Idle_Combat"]:
			target = {"Walking_D_Skeletons": "Zombie_Walk_Fwd", "Running_A": "Zombie_Walk_Fwd", "Skeletons_Inactive_Floor_Pose": "Zombie_Idle", "Idle_Combat": "Zombie_Idle"}[k]
		elif shamble and k.contains("Melee_Attack"):
			target = "Zombie_Scratch"
		if lib.has_animation(target):
			lib.add_animation(k, lib.get_animation(target))
	return lib
