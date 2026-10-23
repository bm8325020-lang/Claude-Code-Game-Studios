# PROTOTYPE - NOT FOR PRODUCTION
# Boot probe: ms from engine start until the hero can move (main.tscn loaded, world built, loading screen gone).
#   godot --headless --path . -s res://tools/boot_probe.gd
# Desktop numbers; a phone is several times slower. Compare before/after on the same machine.
extends SceneTree


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sementes2_save.json"))  # a fresh download
	var t0: int = Time.get_ticks_msec()
	var g: Node3D = load("res://main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	var t1: int = Time.get_ticks_msec()
	var frames: int = 0
	while g.get("booted") == false:
		await process_frame
		frames += 1
	if g.get("booted") == null:  # an older main.gd without the flag: its _ready ends one physics frame in
		await physics_frame
		await process_frame
	var t2: int = Time.get_ticks_msec()
	print("BOOT engine->main=%d first_frame_blocked=%d playable=%d frames=%d enemies=%d steps=%s map=%s" % [
		t0, t1 - t0, t2, frames, get_nodes_in_group("enemies").size(), str(g.get_meta("boot_ms", {})), str(g.map.stats)])
	quit()
