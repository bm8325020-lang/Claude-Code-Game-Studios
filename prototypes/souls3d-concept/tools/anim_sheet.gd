# PROTOTYPE - NOT FOR PRODUCTION
# Contact sheet of one hero animation: the game's hero frozen at each key pose (hand-made clips)
# or at N even moments (others), side and front views.
# usage: OUT=<dir> ANIM=<name in library p> N=<frames> godot --path . --rendering-driver opengl3 --resolution 480x540 -s tools/anim_sheet.gd
extends SceneTree

var main
var frame := 0
var cam: Camera3D
var n := 6
var times := []

func _init() -> void:
	main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	n = int(OS.get_environment("N")) if OS.get_environment("N") != "" else 6
	var def = load("res://hero_anims.gd").MOVES.get(OS.get_environment("ANIM"))
	if def != null:
		for k in def.keys:
			times.append(k.t)
		n = times.size()
	cam = Camera3D.new()
	cam.fov = 40
	get_root().add_child(cam)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		main.set_physics_process(false)
		for e in main.enemies:
			e.root.visible = false
		if main.boss != null:
			main.boss.root.visible = false
		var skel: Skeleton3D = main.model.find_children("*", "Skeleton3D", true, false)[0]
		var hand: Vector3 = skel.get_bone_global_pose(skel.find_bone("hand_r")).origin
		var sh: Vector3 = skel.get_bone_global_pose(skel.find_bone("upperarm_r")).origin
		print("idle: right shoulder ", sh, " right hand ", hand, " model rot ", main.model.rotation.y)
	if frame < 5:
		return false
	var i := (frame - 5) / 3
	var a: Animation = main.anim.get_animation("p/" + OS.get_environment("ANIM"))
	if i >= n * 2:
		return true
	var t := a.length * float(i % n) / float(n - 1)
	if times.size() > 0:
		t = times[i % n]
	main.anim.play("p/" + OS.get_environment("ANIM"))
	main.anim.seek(t, true)
	main.anim.pause()
	var p: Vector3 = main.player.position + Vector3(0, 1.0, 0)
	var fwd := Vector3(sin(main.model.rotation.y), 0, cos(main.model.rotation.y))
	var side := fwd.cross(Vector3.UP)
	cam.position = p + (side * -3.4 if i < n else fwd * 3.0 + side * -1.2) + Vector3(0, 0.3, 0)
	cam.look_at(p)
	if (frame - 5) % 3 == 2:
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%02d.png" % i)
	return false
