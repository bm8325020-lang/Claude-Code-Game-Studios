# Animation agent: tree debugging.
extends SceneTree
var ch: Node3D
var ha: HeroAnim
var n: int = 0
func _initialize() -> void:
	ch = CharacterKit.make({"body": "Male", "outfit": "Peasant", "weapon": "Sword_Bronze"})
	root.add_child(ch)
	ha = HeroAnim.new(ch)
func _process(dt: float) -> bool:
	ha.update(1.0 / 30.0, Vector3(0, 0, 1.5), true, "free")
	n += 1
	if n % 10 == 0:
		var sk: Skeleton3D = ch.get_meta("skeleton")
		var b: int = sk.find_bone("upperarm_l")
		print(n, " arm ", sk.get_bone_pose_rotation(b), " rest ", sk.get_bone_rest(b).basis.get_rotation_quaternion())
		var tree: AnimationTree = ch.get_meta("tree")
		for p in ["relaxed/blend_position", "loco_ts/scale", "mode/current_state", "act/current_state", "stance/blend_amount"]:
			print("  ", p, " = ", tree.get("parameters/" + p))
	return n > 30
