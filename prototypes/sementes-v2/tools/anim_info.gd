# Animation agent: prints measured speeds and action timing.
extends SceneTree
func _initialize() -> void:
	var ch: Node3D = CharacterKit.make({"body": "Male", "outfit": "Peasant", "weapon": "Sword_Bronze"})
	print("SPEED ", AnimLib.SPEED, "\nCYCLE ", AnimLib.CYCLE)
	for k in AnimLib.INFO:
		print(k, " ", AnimLib.INFO[k])
	ch.free()
	quit()
