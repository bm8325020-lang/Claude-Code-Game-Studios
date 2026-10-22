# PROTOTYPE - NOT FOR PRODUCTION
# Animation review tool (animation agent). Renders contact sheets of the characters and saves them to OUT. Run:
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#     -s tools/anim_preview.gd
# Env: PREVIEW=actions (default: every HeroAnim action + locomotion) | raw (UAL clips) | combo | grip | looks | enemy
#      ONLY=name1,name2 limits the list; LOOK=0..4 picks the look; ANGLE=degrees around the character (0 = front,
#      -40 = front-right, the sword side); FRAMES=frames per action; OUT=folder (default tools/shots/work/).
# The tree is advanced by HeroAnim.update with a fixed 1/30 s step and root motion moves the character, so the grid
# shows foot sliding and the frames are exactly the clip times.
extends SceneTree

const LOOKS: Array[Dictionary] = [
	{"body": "Male", "outfit": "Peasant", "hair": "Hair_SimpleParted", "beard": true, "weapon": "Sword_Bronze", "shield": "Shield_Wooden"},
	{"body": "Female", "outfit": "Ranger", "hair": "Hair_Long", "weapon": "Sword_Bronze", "shield": "Shield_Wooden", "pauldrons": true},
	{"body": "Male", "outfit": "Ranger", "hood": true, "weapon": "Axe_Bronze", "pauldrons": true},
	{"body": "Male", "outfit": "Peasant", "hair": "Hair_SimpleParted", "weapon": ""},
	{"body": "Female", "outfit": "Peasant", "hair": "Hair_Buns", "weapon": "", "tint": Color(0.85, 0.9, 1.0)},
]
const CELL: Vector2i = Vector2i(300, 400)
const DT: float = 1.0 / 30.0

var out_dir: String = "res://tools/shots/work/"
var angle: float = -40.0
var cam: Camera3D
var ch: Node3D
var ha: HeroAnim
var ground: Node3D
var water: MeshInstance3D


func _initialize() -> void:
	if OS.get_environment("OUT") != "":
		out_dir = OS.get_environment("OUT")
	if OS.get_environment("ANGLE") != "":
		angle = float(OS.get_environment("ANGLE"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
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
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	ground = Node3D.new()
	root.add_child(ground)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.5, 0.4)
	g.material_override = gm
	ground.add_child(g)
	# grid lines every metre so foot sliding is visible
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.4, 0.36, 0.3)
	for i in range(-30, 31):
		for axis in 2:
			var l := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.012, 0.002, 60) if axis == 0 else Vector3(60, 0.002, 0.012)
			l.mesh = bm
			l.position = Vector3(i, 0.001, 0) if axis == 0 else Vector3(0, 0.001, i)
			l.material_override = lm
			ground.add_child(l)
	water = MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(60, 60)
	water.mesh = wp
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.45, 0.6, 0.55)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wm
	water.visible = false
	root.add_child(water)
	cam = Camera3D.new()
	cam.fov = 35
	root.add_child(cam)


func _spawn(look: Dictionary, with_anim: bool = true) -> void:
	if ch != null:
		root.remove_child(ch)
		ch.free()
	ch = CharacterKit.make(look)
	root.add_child(ch)
	ha = HeroAnim.new(ch) if with_anim else null


# Camera at `dist` from the target, `ang` degrees around it (0 = in front of a +Z facing character).
func _orbit(at: Vector3, ang: float, dist: float = 4.4, h: float = 0.55) -> void:
	var a: float = deg_to_rad(ang)
	cam.position = at + Vector3(sin(a), 0, cos(a)) * dist + Vector3(0, h, 0)
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
	sheet.fill(Color(0.2, 0.2, 0.2))
	for i in frames.size():
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	return sheet


func _save(img: Image, nm: String) -> void:
	img.save_png(ProjectSettings.globalize_path(out_dir + nm + ".png"))


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
	var only: Array[String] = _only()
	if mode == "raw":
		await _raw(only)
	elif mode == "grip":
		await _grip(li)
	elif mode == "combo":
		await _combo(li)
	elif mode == "looks":
		await _looks()
	elif mode == "enemy":
		await _enemy(only)
	else:
		await _actions(only, li)
	quit()


# Raw clips straight from the AnimationPlayer (no tree): what the mocap gives us.
func _raw(only: Array[String]) -> void:
	_spawn(LOOKS[0], false)
	var ap: AnimationPlayer = ch.get_meta("anim")
	for nm in ap.get_animation_list():
		if not only.is_empty() and not (String(nm) in only):
			continue
		var a: Animation = ap.get_animation(nm)
		var frames: Array[Image] = []
		_orbit(Vector3(0, 0.9, 0), angle)
		ap.play(nm)
		for i in 6:
			ap.seek(a.length * i / 5.0, true)
			frames.append(await _grab())
		_save(_sheet(frames, 6), "raw_%s" % nm)
		print("raw ", nm)


func _warm(mode: String, n: int = 20) -> void:
	for k in n:
		ha.update(DT, Vector3.ZERO, true, mode)
	await process_frame


# Steps the hero by DT, moving the body with the clip's root motion.
func _step(mode: String, v: Vector3 = Vector3.ZERO) -> void:
	ha.update(DT, v, true, mode)
	ch.position += ha.root_motion + v * DT


# Every HeroAnim action through the real AnimationTree, frames spread over its length.
func _actions(only: Array[String], li: int) -> void:
	var names: Array[String] = ["loco_idle", "loco_walk", "loco_run", "loco_sprint", "loco_mid", "lock_strafe_r",
		"lock_back", "turn_in_place", "swim", "crouch", "block", "drink_walk"]
	names.append_array(HeroAnim.ACTIONS)
	var nf: int = int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 6
	for nm in names:
		if not only.is_empty() and not (nm in only):
			continue
		_spawn(LOOKS[li])
		var frames: Array[Image] = []
		if nm.begins_with("loco") or nm.begins_with("lock") or nm in ["turn_in_place", "swim", "crouch", "block", "drink_walk"]:
			frames = await _loco(nm)
		else:
			var mode: String = "lock" if nm in HeroAnim.COMBAT else "free"
			await _warm(mode)
			var d: Dictionary = ha.act(nm)
			var length: float = d.length
			var t: float = 0.0
			for i in nf:
				var target: float = length * i / float(nf - 1)
				while t < target - 0.001:
					_step(mode)
					t += DT
				_orbit(ch.position + Vector3(0, 0.85, 0), angle)
				frames.append(await _grab())
			print("%s %s" % [nm, d])
		_save(_sheet(frames, mini(frames.size(), 8)), "%s_%d" % [nm, li])


# Locomotion: the character really moves through the world (camera follows) so sliding shows on the grid.
func _loco(nm: String) -> Array[Image]:
	var frames: Array[Image] = []
	var speed: float = {"loco_idle": 0.0, "loco_walk": 1.3, "loco_run": 5.0, "loco_sprint": 7.6, "loco_mid": 3.0,
		"lock_strafe_r": 3.6, "lock_back": 1.6, "turn_in_place": 0.0, "swim": 2.2, "crouch": 1.2, "block": 1.6,
		"drink_walk": 1.0}.get(nm, 0.0)
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
	if nm == "swim":
		ground.position.y = -3.0
		water.visible = true
	ha.look_dir = Vector3(0, 0, 1)
	var t: float = 0.0
	var side: float = 90.0 if nm != "lock_strafe_r" else 20.0
	for i in 72:
		var v: Vector3 = dir * speed * clampf(t / 0.8, 0.0, 1.0)
		if nm == "turn_in_place":
			ha.look_dir = Vector3(sin(t * 2.2), 0, cos(t * 2.2))
			mode = "lock" if t > 0.5 else "free"
		if nm == "drink_walk" and i == 30:
			ha.act("drink")
		_step(mode, v)
		t += DT
		if i >= 36 and (i - 36) % 6 == 0:
			_orbit(ch.position + Vector3(0, 0.85, 0), -side if nm != "swim" else -60.0, 4.8)
			frames.append(await _grab())
	ground.position.y = 0.0
	water.visible = false
	return frames


# The full light combo chained at the cancel points (as the hero does), 10 frames per second.
func _combo(li: int) -> void:
	_spawn(LOOKS[li])
	await _warm("lock")
	var seq: Array[Image] = []
	var n: int = 0
	var chain: Array[String] = ["light1", "light2", "light3", "light4"]
	if OS.get_environment("CHAIN") != "":
		chain.assign(OS.get_environment("CHAIN").split(","))
	for a in chain:
		var d: Dictionary = ha.act(a)
		var local: float = 0.0
		var until: float = d.cancel if a != chain[chain.size() - 1] else d.length
		while local < until:
			_step("lock")
			local += DT
			n += 1
			if n % 3 == 0:
				_orbit(ch.position + Vector3(0, 0.85, 0), angle)
				seq.append(await _grab())
		print(a, " ", d)
	for k in 12:
		_step("lock")
		n += 1
		if n % 3 == 0:
			seq.append(await _grab())
	for i in range(0, seq.size(), 16):
		_save(_sheet(seq.slice(i, mini(i + 16, seq.size())), 8), "combo_%d_%02d" % [li, i / 16])
	print("combo frames ", seq.size())


# Weapon in hand from four angles: combat idle, mid-swing, block, and stowed on the back.
func _grip(li: int) -> void:
	_spawn(LOOKS[li])
	var frames: Array[Image] = []
	for pose in ["ready", "light1", "block", "stowed"]:
		_spawn(LOOKS[li])
		var mode: String = "block" if pose == "block" else "lock"
		ha.auto_stow = true
		if pose == "stowed":
			mode = "free"
			ha._calm = 99.0
		else:
			ha.act("hit_light")  # wakes the combat stance
		await _warm(mode, 40)
		if pose == "light1":
			ha.act("light1")
			for k in 6:
				_step(mode)
		var skel: Skeleton3D = ch.get_meta("skeleton")
		var hand: Vector3 = skel.get_bone_global_pose(skel.find_bone("hand_r" if pose != "stowed" else "spine_03")).origin
		for ang in [-40.0, 50.0, 140.0, 230.0]:
			_orbit(hand, ang, 1.6, 0.25)
			frames.append(await _grab())
	_save(_sheet(frames, 4), "grip_%d" % li)


func _looks() -> void:
	var frames: Array[Image] = []
	var all: Array[Dictionary] = LOOKS.duplicate()
	all.append({"body": "Imp"})
	all.append({"body": "Puglin"})
	for lk in all:
		_spawn(lk)
		await _warm("free")
		_orbit(Vector3(0, 0.85, 0), angle)
		frames.append(await _grab())
	_save(_sheet(frames, all.size()), "looks")


# Monsters: idle, walk (moving), attack, hit, death straight from Anim (as a simple AI would play them),
# then the HeroAnim attack through the tree.
func _enemy(only: Array[String]) -> void:
	for body in ["Imp", "Puglin"]:
		if not only.is_empty() and not (body in only):
			continue
		var rows: Array[Image] = []
		for clip in ["idle", "walk", "run", "attack", "attack2", "hit", "death"]:
			_spawn({"body": body}, false)
			var ap: AnimationPlayer = ch.get_meta("anim")
			var a: Animation = ap.get_animation(clip)
			ap.play(clip)
			var speed: float = 0.0
			if clip == "walk" or clip == "run":
				var lib: AnimationLibrary = ap.get_animation_library("")
				var src: String = "Loco_Walk" if clip == "walk" else "Loco_Jog"
				speed = AnimLib.speed(lib, src)
			for i in 6:
				var t: float = a.length * i / 5.0
				ap.seek(t, true)
				ch.position = Vector3(0, 0, speed * t)
				_orbit(ch.position + Vector3(0, 0.6, 0), angle if speed == 0.0 else -90.0, 3.6, 0.4)
				rows.append(await _grab())
			print(body, " ", clip, " ", a.length)
		_save(_sheet(rows, 6), "enemy_%s" % body)
