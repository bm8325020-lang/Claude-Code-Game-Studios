# Animation agent: per-frame pelvis, lowest bone (ground contact) and hands for clips (ONLY=a,b  STEP=frames).
extends SceneTree
func _initialize() -> void:
	var ch: Node3D = CharacterKit.make({"body": OS.get_environment("BODY") if OS.get_environment("BODY") != "" else "Male"})
	var sk: Skeleton3D = ch.get_meta("skeleton")
	var lib: AnimationLibrary = (ch.get_meta("anim") as AnimationPlayer).get_animation_library("")
	var hr: int = sk.find_bone("hand_r")
	var hl: int = sk.find_bone("hand_l")
	var pel: int = sk.find_bone("pelvis")
	var step: int = int(OS.get_environment("STEP")) if OS.get_environment("STEP") != "" else 2
	for nm in OS.get_environment("ONLY").split(","):
		var a: Animation = lib.get_animation(nm)
		print("== ", nm, " len=", a.length)
		var t: float = 0.0
		while t <= a.length + 0.001:
			var low: float = 99.0
			var lowb: String = ""
			for b in sk.get_bone_count():
				var y: float = AnimLib.bone_global(sk, a, b, t).origin.y
				if y < low:
					low = y
					lowb = sk.get_bone_name(b)
			var p: Vector3 = AnimLib.bone_global(sk, a, pel, t).origin
			var r: Vector3 = AnimLib.bone_global(sk, a, hr, t).origin
			var l: Vector3 = AnimLib.bone_global(sk, a, hl, t).origin
			print("%.2f pel(%.2f %.2f %.2f) low %.2f %s  handR(%.2f %.2f %.2f) handL(%.2f %.2f %.2f)" % [t, p.x, p.y, p.z, low, lowb, r.x, r.y, r.z, l.x, l.y, l.z])
			t += step / 30.0
	ch.free()
	quit()
