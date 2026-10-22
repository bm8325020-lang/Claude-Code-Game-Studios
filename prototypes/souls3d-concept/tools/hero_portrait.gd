# PROTOTYPE - NOT FOR PRODUCTION
# Renders hero portraits for review.
# usage: OUT=<dir> ANIM=<mixamo clip> AT=<seconds> godot --path . --rendering-driver opengl3 --resolution 900x1200 -s tools/hero_portrait.gd
extends SceneTree

const HeroLook = preload("res://hero_look.gd")
const SHOTS := [  # camera position, look-at target
	[Vector3(1.3, 1.25, 2.6), Vector3(0, 1.0, 0)],
	[Vector3(-1.4, 1.3, -2.5), Vector3(0, 1.05, 0)],
	[Vector3(0.45, 1.62, 0.95), Vector3(0, 1.5, 0)],
]
var frame := 0
var cam: Camera3D

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.07)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()  # cold moonlight from the front-left
	key.rotation = Vector3(-0.6, -0.5, 0)
	key.light_color = Color(0.7, 0.78, 1.0)
	key.light_energy = 0.9
	key.shadow_enabled = true
	root.add_child(key)
	var fire := OmniLight3D.new()  # bonfire behind the hero: warm rim light
	fire.position = Vector3(-0.8, 0.6, -1.6)
	fire.light_color = Color(1.0, 0.5, 0.18)
	fire.light_energy = 4.0
	fire.omni_range = 5.0
	fire.shadow_enabled = true
	root.add_child(fire)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/tex/cobblestone_floor_08_diff_1k.jpg")
	gm.normal_enabled = true
	gm.normal_texture = load("res://assets/tex/cobblestone_floor_08_nor_gl_1k.jpg")
	gm.uv1_scale = Vector3(5, 5, 5)
	ground.material_override = gm
	root.add_child(ground)
	var model: Node3D = load("res://assets/mixamo/x_bot.scn").instantiate()
	root.add_child(model)
	HeroLook.dress(model)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(skel, "mixamorig_RightHand", "longsword", Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.07, 0.02)))
	_attach(skel, "mixamorig_LeftForeArm", "shield", Transform3D(Basis(Vector3.UP, PI / 2).rotated(Vector3.FORWARD, PI / 2), Vector3(0.0, 0.18, 0.06)))
	var src: AnimationPlayer = load("res://assets/mixamo/%s.scn" % OS.get_environment("ANIM")).instantiate().find_children("*", "AnimationPlayer", true, false)[0]
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := AnimationLibrary.new()
	lib.add_animation("a", src.get_animation("mixamo_com"))
	ap.add_animation_library("x", lib)
	ap.play("x/a")
	ap.seek(float(OS.get_environment("AT")), true)
	ap.pause()
	cam = Camera3D.new()
	cam.fov = 40
	root.add_child(cam)

func _attach(skel: Skeleton3D, bone: String, prop: String, xf: Transform3D) -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var p: Node3D = load("res://assets/props/%s.glb" % prop).instantiate()
	p.transform = xf
	ba.add_child(p)

func _process(_d: float) -> bool:
	frame += 1
	var i := (frame - 5) / 4
	if frame >= 5 and (frame - 5) % 4 == 0 and i < SHOTS.size():
		cam.position = SHOTS[i][0]
		cam.look_at(SHOTS[i][1])
	if frame >= 8 and (frame - 8) % 4 == 0 and i < SHOTS.size():
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT") + "/shot%d.png" % i)
	return frame > 5 + SHOTS.size() * 4 + 4
