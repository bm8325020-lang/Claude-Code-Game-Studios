# PROTOTYPE - NOT FOR PRODUCTION
# Animation agent: numeric checks of every authored action (no rendering). Per action prints the lowest foot
# height range (floating / sinking), pelvis height range and the first/last frame pose distance to idle (pops).
#   godot --headless --path . -s tools/anim_check.gd       (BODY=Male|Female|Imp|Puglin)
extends SceneTree


func _initialize() -> void:
	var body: String = OS.get_environment("BODY") if OS.get_environment("BODY") != "" else "Male"
	var ch: Node3D = CharacterKit.make({"body": body})
	var sk: Skeleton3D = ch.get_meta("skeleton")
	var ap: AnimationPlayer = ch.get_meta("anim")
	var lib: AnimationLibrary = ap.get_animation_library("")
	var feet: Array[int] = [sk.find_bone("foot_l"), sk.find_bone("ball_l"), sk.find_bone("foot_r"), sk.find_bone("ball_r")]
	var pel: int = sk.find_bone("pelvis")
	var names: Array = (lib.get_meta("info") as Dictionary).keys()
	for nm in names:
		var a: Animation = lib.get_animation(nm)
		var lo: float = 99.0
		var hi: float = -99.0
		var plo: float = 99.0
		var phi: float = -99.0
		var t: float = 0.0
		while t <= a.length + 0.001:
			var low: float = 99.0
			for f in feet:
				low = minf(low, AnimLib.bone_global(sk, a, f, t).origin.y)
			lo = minf(lo, low)
			hi = maxf(hi, low)
			var py: float = AnimLib.bone_global(sk, a, pel, t).origin.y
			plo = minf(plo, py)
			phi = maxf(phi, py)
			t += 1.0 / 30.0
		var info: Dictionary = (lib.get_meta("info") as Dictionary)[nm]
		print("%-16s len %.2f  foot %.2f..%.2f  pelvis %.2f..%.2f  hit %s cancel %.2f move %s" % [nm, a.length, lo, hi, plo, phi, str(info.hit), info.cancel, str(info.move)])
	ch.free()
	quit()
