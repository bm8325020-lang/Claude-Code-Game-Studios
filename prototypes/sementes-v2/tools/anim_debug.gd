# Animation agent: prints pelvis height / hand pos per frame through the real AnimationTree (ACT=name).
extends SceneTree
var ch: Node3D
var ha: HeroAnim
var n: int = 0
func _initialize() -> void:
	ch = CharacterKit.make({"body": "Male", "outfit": "Peasant", "weapon": "Sword_Bronze"})
	root.add_child(ch)
	ha = HeroAnim.new(ch)
func _process(dt: float) -> bool:
	n += 1
	if n == 20:
		print(ha.act(OS.get_environment("ACT")))
	ha.update(1.0 / 30.0, Vector3.ZERO, true, "free")
	(ch.get_meta("tree") as AnimationTree).advance(0.0)
	if n >= 18:
		var sk: Skeleton3D = ch.get_meta("skeleton")
		var tree: AnimationTree = ch.get_meta("tree")
		print(n, " pelvis ", sk.get_bone_global_pose(sk.find_bone("pelvis")).origin, " root ", sk.get_bone_global_pose(sk.find_bone("root")).origin, " act ", tree.get("parameters/act/current_state"))
	return n > 30
