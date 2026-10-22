# Animation agent: prints pelvis/root path and hand_r speed for clips (ONLY=a,b).
extends SceneTree
func _initialize() -> void:
	var ch: Node3D = CharacterKit.make({"body": "Male", "outfit": "Peasant"})
	var sk: Skeleton3D = ch.get_meta("skeleton")
	var ap: AnimationPlayer = ch.get_meta("anim")
	var lib: AnimationLibrary = ap.get_animation_library("")
	var hand: int = sk.find_bone("hand_r")
	var pel: int = sk.find_bone("pelvis")
	var fl: int = sk.find_bone("ball_l")
	var fr: int = sk.find_bone("ball_r")
	for nm in OS.get_environment("ONLY").split(","):
		var a: Animation = lib.get_animation(nm)
		print("== ", nm, " len=", a.length, " rm=", AnimLib.ROOT_MOTION.has(nm))
		var prev := Vector3.ZERO
		var t: float = 0.0
		var line := ""
		while t <= a.length + 0.001:
			var h: Transform3D = AnimLib.bone_global(sk, a, hand, t)
			var tip: Vector3 = h * Vector3(0, 0, 0)
			var p: Vector3 = AnimLib.bone_global(sk, a, pel, t).origin
			var l: Vector3 = AnimLib.bone_global(sk, a, fl, t).origin
			var r: Vector3 = AnimLib.bone_global(sk, a, fr, t).origin
			var sp: float = (tip - prev).length() * 30.0 if t > 0 else 0.0
			prev = tip
			print("%.2f pel(%.2f %.2f %.2f) hand(%.2f %.2f %.2f) v=%.1f footL(%.2f %.2f %.2f) footR(%.2f %.2f %.2f)" % [t, p.x, p.y, p.z, tip.x, tip.y, tip.z, sp, l.x, l.y, l.z, r.x, r.y, r.z])
			t += 1.0 / 30.0 * float(OS.get_environment("STEP") if OS.get_environment("STEP") != "" else "1")
	quit()
