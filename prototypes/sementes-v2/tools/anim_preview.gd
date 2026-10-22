# PROTOTYPE - NOT FOR PRODUCTION
# Animation review tool (animation agent). Renders contact sheets (6 frames per action) of the hero and saves them to
# OUT. Run:
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#     -s tools/anim_preview.gd
# Env: PREVIEW=raw (every raw UAL clip) | actions (default: every HeroAnim action + locomotion speeds) | combo |
#      grip (weapon close-ups from several angles); ONLY=name1,name2 limits the list; LOOK=0..3 picks the look.
extends SceneTree

const OUT: String = "/tmp/claude-0/-home-user/09449103-5068-5eff-93a6-3d4914815589/scratchpad/v2shots/anim/"
const LOOKS: Array[Dictionary] = [
	{"body": "Male", "outfit": "Peasant", "hair": "Hair_SimpleParted", "beard": true, "weapon": "Sword_Bronze", "shield": "Shield_Wooden"},
	{"body": "Female", "outfit": "Ranger", "hair": "Hair_Long", "weapon": "Sword_Bronze", "shield": "Shield_Wooden", "pauldrons": true},
	{"body": "Male", "outfit": "Ranger", "hood": true, "weapon": "Axe_Bronze", "pauldrons": true},
	{"body": "Female", "outfit": "Peasant", "hair": "Hair_Buns", "weapon": "", "tint": Color(0.85, 0.9, 1.0)},
]
const CELL: Vector2i = Vector2i(300, 400)

var cam: Camera3D
var ch: Node3D
var ha: HeroAnim
var ground: MeshInstance3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_stage()
	_run.call_deferred()


func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.74, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.78)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.5, 0.4)
	ground.material_override = gm
	root.add_child(ground)
	# grid lines every metre so foot sliding is visible
	for i in range(-10, 11):
		for axis in 2:
			var l := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.012, 0.002, 20) if axis == 0 else Vector3(20, 0.002, 0.012)
			l.mesh = bm
			l.position = Vector3(i, 0.001, 0) if axis == 0 else Vector3(0, 0.001, i)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(0.4, 0.36, 0.3)
			l.material_override = lm
			root.add_child(l)
	cam = Camera3D.new()
	cam.fov = 35
	root.add_child(cam)


func _spawn(look: Dictionary) -> void:
	if ch != null:
		ch.queue_free()
	ch = CharacterKit.make(look)
	root.add_child(ch)
	ha = HeroAnim.new(ch)


func _aim(from: Vector3, at: Vector3) -> void:
	cam.position = from
	cam.look_at(at)


func _grab() -> Image:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var img: Image = root.get_viewport().get_texture().get_image()
	var vs: Vector2i = img.get_size()
	var w: int = int(vs.y * 0.75)
	var r: Image = img.get_region(Rect2i((vs.x - w) / 2, 0, w, vs.y))
	r.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return r


func _sheet(frames: Array[Image], cols: int) -> Image:
	var rows: int = int(ceil(frames.size() / float(cols)))
	var sheet: Image = Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	return sheet


func _only() -> Array[String]:
	var o: Array[String] = []
	var s: String = OS.get_environment("ONLY")
	if s != "":
		for p in s.split(","):
			o.append(p)
	return o


func _run() -> void:
	var mode: String = OS.get_environment("PREVIEW")
	if mode == "":
		mode = "actions"
	var li: int = int(OS.get_environment("LOOK")) if OS.get_environment("LOOK") != "" else 0
	_spawn(LOOKS[li])
	var only: Array[String] = _only()
	if mode == "raw":
		await _raw(only)
	elif mode == "grip":
		await _grip()
	elif mode == "combo":
		await _combo()
	elif mode == "looks":
		await _looks()
	else:
		await _actions(only, li)
	quit()


# Raw clips straight from the AnimationPlayer (no tree): what the mocap gives us.
func _raw(only: Array[String]) -> void:
	ha.set_active(false)
	var ap: AnimationPlayer = ch.get_meta("anim")
	for nm in ap.get_animation_list():
		if not only.is_empty() and not (String(nm) in only):
			continue
		var a: Animation = ap.get_animation(nm)
		var frames: Array[Image] = []
		_aim(Vector3(3.2, 1.5, 3.2), Vector3(0, 0.9, 0))
		for i in 6:
			ap.play(nm, 0.0)
			ap.seek(a.length * i / 5.0, true)
			frames.append(await _grab())
		_sheet(frames, 6).save_png(OUT + "raw_%s.png" % nm)
		print("raw ", nm)


# Every HeroAnim action through the real AnimationTree, 6 frames spread over its length.
func _actions(only: Array[String], li: int) -> void:
	var names: Array[String] = ["loco_idle", "loco_walk", "loco_jog", "loco_sprint", "lock_strafe_r", "lock_back",
		"turn_in_place", "swim", "crouch", "block"]
	names.append_array(HeroAnim.ACTIONS)
	for nm in names:
		if not only.is_empty() and not (nm in only):
			continue
		_spawn(LOOKS[li])
		ch.position = Vector3.ZERO
		var frames: Array[Image] = []
		_aim(Vector3(2.8, 1.45, 3.4), Vector3(0, 0.85, 0))
		if nm.begins_with("loco") or nm.begins_with("lock") or nm in ["turn_in_place", "swim", "crouch", "block"]:
			frames = await _loco(nm)
		else:
			var d: Dictionary = {}
			for k in 20:
				ha.update(1.0 / 30.0, Vector3.ZERO, true, "free")
				await process_frame
			d = ha.act(nm)
			var length: float = d.length
			var t: float = 0.0
			var step: float = length / 5.0
			for i in 6:
				var target: float = step * i
				while t < target - 0.0001:
					var dt: float = minf(1.0 / 30.0, target - t)
					ha.update(dt, Vector3.ZERO, true, "free")
					ch.get_meta("tree").advance(0.0)
					t += dt
				frames.append(await _grab())
			print("%s %s" % [nm, d])
		_sheet(frames, 6).save_png(OUT + "%s_%d.png" % [nm, li])


# Locomotion: the character really moves through the world (camera follows from the side) so sliding shows.
func _loco(nm: String) -> Array[Image]:
	var frames: Array[Image] = []
	var speed: float = {"loco_idle": 0.0, "loco_walk": 1.4, "loco_jog": 3.6, "loco_sprint": 6.5, "lock_strafe_r": 2.5,
		"lock_back": 1.6, "turn_in_place": 0.0, "swim": 1.8, "crouch": 1.2, "block": 1.4}.get(nm, 0.0)
	var dir := Vector3(0, 0, 1)
	var mode: String = "free"
	if nm == "lock_strafe_r":
		dir = Vector3(-1, 0, 0)
		mode = "lock"
	elif nm == "lock_back":
		dir = Vector3(0, 0, -1)
		mode = "lock"
	elif nm in ["swim", "crouch", "block"]:
		mode = nm
	ha.look_dir = Vector3(0, 0, 1)
	var t: float = 0.0
	for i in 72:
		var v: Vector3 = dir * speed * clampf(t / 0.8, 0.0, 1.0)
		if nm == "turn_in_place":
			ha.look_dir = Vector3(sin(t * 2.2), 0, cos(t * 2.2))
			mode = "lock" if t > 0.5 else "free"
		ha.update(1.0 / 30.0, v, true, mode)
		ch.position += v / 30.0
		t += 1.0 / 30.0
		if i >= 36 and (i - 36) % 6 == 0:
			_aim(ch.position + Vector3(3.6, 1.3, 0.6), ch.position + Vector3(0, 0.85, 0))
			frames.append(await _grab())
		else:
			await process_frame
	return frames


# The full light combo as a frame sequence (10 fps) from a 3/4 front view.
func _combo() -> void:
	_aim(Vector3(2.4, 1.5, 3.2), Vector3(0, 0.9, 0))
	for k in 15:
		ha.update(1.0 / 30.0, Vector3.ZERO, true, "free")
		await process_frame
	var seq: Array[Image] = []
	var t: float = 0.0
	for a in ["light1", "light2", "light3", "light4"]:
		var d: Dictionary = ha.act(a)
		var cancel: float = d.cancel
		var local: float = 0.0
		while local < cancel:
			ha.update(1.0 / 30.0, Vector3.ZERO, true, "free")
			local += 1.0 / 30.0
			t += 1.0 / 30.0
			if int(round(t * 30.0)) % 3 == 0:
				seq.append(await _grab())
			else:
				await process_frame
		print(a, " ", d)
	for k in 30:
		ha.update(1.0 / 30.0, Vector3.ZERO, true, "free")
		if k % 3 == 0:
			seq.append(await _grab())
		else:
			await process_frame
	for i in range(0, seq.size(), 12):
		_sheet(seq.slice(i, mini(i + 12, seq.size())), 6).save_png(OUT + "combo_%02d.png" % (i / 12))
	print("combo frames ", seq.size())


# Weapon in hand from four angles, idle and mid-swing.
func _grip() -> void:
	var frames: Array[Image] = []
	for pose in ["idle", "light1"]:
		for k in 15:
			ha.update(1.0 / 30.0, Vector3.ZERO, true, "lock")
			await process_frame
		if pose == "light1":
			ha.act("light1")
			for k in 7:
				ha.update(1.0 / 30.0, Vector3.ZERO, true, "lock")
				await process_frame
		var hand: Vector3 = (ch.get_meta("skeleton") as Skeleton3D).get_bone_global_pose(
			(ch.get_meta("skeleton") as Skeleton3D).find_bone("hand_r")).origin
		for ang in [0.0, 90.0, 180.0, 270.0]:
			var a: float = deg_to_rad(ang)
			_aim(hand + Vector3(sin(a), 0.25, cos(a)) * 1.3, hand)
			frames.append(await _grab())
	_sheet(frames, 4).save_png(OUT + "grip_%s.png" % (ch.get_meta("look") as Dictionary).get("weapon", ""))


func _looks() -> void:
	var frames: Array[Image] = []
	for i in LOOKS.size():
		_spawn(LOOKS[i])
		for k in 10:
			ha.update(1.0 / 30.0, Vector3.ZERO, true, "free")
			await process_frame
		_aim(Vector3(1.6, 1.4, 3.0), Vector3(0, 0.95, 0))
		frames.append(await _grab())
	_sheet(frames, 4).save_png(OUT + "looks.png")
