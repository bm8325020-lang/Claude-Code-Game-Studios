# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is a dark 3D souls-like fight (stamina, roll, lock-on, Seed spell) fun on a phone?
# Date: 2026-10-21
extends Node3D

const BONFIRE_POS := Vector3(0, 0, 14)
const BOSS_HOME := Vector3(0, 0, -26)
const ANIMS := {
	"idle": "sword_and_shield_idle", "idle2": "sword_and_shield_idle_2", "run": "sword_and_shield_run",
	"walk": "sword_and_shield_walk", "walk_back": "sword_and_shield_walk_2",
	"strafe_r": "sword_and_shield_strafe", "strafe_l": "sword_and_shield_strafe_2",
	"slash": "sword_and_shield_slash", "slash3": "sword_and_shield_slash_3", "slash5": "sword_and_shield_slash_5",
	"slash4": "sword_and_shield_slash_4", "heavy": "sword_and_shield_attack_4", "heavy2": "sword_and_shield_attack_3",
	"run_atk": "sword_and_shield_attack", "roll_atk": "sword_and_shield_attack_2", "kick": "sword_and_shield_kick",
	"roll": "stand_to_roll", "hit1": "sword_and_shield_impact", "hit2": "sword_and_shield_impact_2",
	"hit3": "sword_and_shield_impact_3", "death": "sword_and_shield_death", "death2": "sword_and_shield_death_2",
	"cast": "sword_and_shield_casting_2", "drink": "sword_and_shield_power_up",
	"block_idle": "sword_and_shield_block_idle", "block_hit": "sword_and_shield_block", "parry": "sword_and_shield_block_2",
	"backhand": "sword_and_shield_backhand", "draw": "sheath_sword_1",
	# great sword (two hands): same keys with a g_ prefix, picked by _a() when the great sword is out
	"g_idle": "gs_great_sword_idle", "g_idle2": "gs_great_sword_idle_2", "g_run": "gs_great_sword_run",
	"g_walk": "gs_great_sword_walk", "g_walk_back": "gs_great_sword_walk_2",
	"g_strafe_r": "gs_great_sword_strafe", "g_strafe_l": "gs_great_sword_strafe_2",
	"g_slash": "gs_great_sword_slash", "g_slash2": "gs_great_sword_slash_2", "g_slash3": "gs_great_sword_slash_3",
	"g_slash4": "gs_great_sword_slash_4", "g_slash5": "gs_great_sword_slash_5", "g_spin": "gs_great_sword_high_spin_attack",
	"g_slide": "gs_great_sword_slide_attack", "g_jump_atk": "gs_great_sword_jump_attack", "g_kick": "gs_great_sword_kick",
	"g_attack": "gs_great_sword_attack", "g_roll": "stand_to_roll",
	"g_hit1": "gs_great_sword_impact", "g_hit2": "gs_great_sword_impact_2", "g_hit3": "gs_great_sword_impact_3",
	"g_death": "gs_two_handed_sword_death", "g_death2": "gs_two_handed_sword_death_2",
	"g_cast": "gs_great_sword_casting", "g_drink": "gs_great_sword_power_up",
	"g_block_idle": "gs_great_sword_blocking", "g_block_hit": "gs_great_sword_blocking_2", "g_parry": "gs_great_sword_blocking_3",
	"g_draw": "gs_draw_a_great_sword_1",
}
const LOOPING := ["idle", "idle2", "run", "walk", "walk_back", "strafe_r", "strafe_l", "block_idle",
	"g_idle", "g_idle2", "g_run", "g_walk", "g_walk_back", "g_strafe_r", "g_strafe_l", "g_block_idle"]
# hit/end are seconds into the clip; speed is the playback rate; lunge is m/s before the hit
const MOVES := {
	"c1": {"anim": "slash", "speed": 1.5, "hit": 0.55, "end": 1.1, "dmg": 28, "poise": 12, "stamina": 16, "reach": 2.4, "arc": 1.2, "lunge": 1.8},
	"c2": {"anim": "slash3", "speed": 1.55, "hit": 0.6, "end": 1.2, "dmg": 30, "poise": 12, "stamina": 16, "reach": 2.4, "arc": 1.2, "lunge": 1.8},
	"c3": {"anim": "slash5", "speed": 1.5, "hit": 0.5, "end": 1.05, "dmg": 32, "poise": 14, "stamina": 17, "reach": 2.5, "arc": 1.3, "lunge": 2.0},
	"c4": {"anim": "slash4", "speed": 1.6, "hit": 0.95, "end": 1.9, "dmg": 46, "poise": 26, "stamina": 22, "reach": 2.8, "arc": 1.6, "lunge": 3.0},
	"heavy": {"anim": "heavy", "speed": 1.0, "hit": 0.55, "end": 0.95, "dmg": 58, "poise": 36, "stamina": 30, "reach": 2.6, "arc": 1.0, "lunge": 1.0},
	"run_atk": {"anim": "run_atk", "speed": 1.8, "hit": 1.0, "end": 2.0, "dmg": 48, "poise": 30, "stamina": 24, "reach": 2.8, "arc": 1.1, "lunge": 5.0},
	"roll_atk": {"anim": "roll_atk", "speed": 1.4, "hit": 0.55, "end": 1.15, "dmg": 38, "poise": 20, "stamina": 20, "reach": 2.6, "arc": 1.2, "lunge": 4.0},
	"kick": {"anim": "kick", "speed": 1.4, "hit": 0.45, "end": 1.0, "dmg": 12, "poise": 45, "stamina": 14, "reach": 2.0, "arc": 0.9, "lunge": 1.2},
	"riposte": {"anim": "heavy2", "speed": 1.3, "hit": 0.75, "end": 1.6, "dmg": 140, "poise": 0, "stamina": 10, "reach": 2.8, "arc": 1.4, "lunge": 2.5},
	"c5": {"anim": "backhand", "speed": 1.5, "hit": 0.87, "end": 1.6, "dmg": 40, "poise": 22, "stamina": 18, "reach": 2.5, "arc": 1.5, "lunge": 2.2},
	# great sword: slower, wider, more damage and poise, more stamina
	"g1": {"anim": "slash", "speed": 1.3, "hit": 0.53, "end": 1.15, "dmg": 44, "poise": 24, "stamina": 24, "reach": 3.0, "arc": 1.4, "lunge": 1.6},
	"g2": {"anim": "slash2", "speed": 1.3, "hit": 0.63, "end": 1.3, "dmg": 46, "poise": 24, "stamina": 24, "reach": 3.0, "arc": 1.4, "lunge": 1.6},
	"g3": {"anim": "slash3", "speed": 1.3, "hit": 0.87, "end": 1.5, "dmg": 50, "poise": 28, "stamina": 26, "reach": 3.0, "arc": 1.5, "lunge": 1.8},
	"g4": {"anim": "slash5", "speed": 1.35, "hit": 0.43, "end": 1.3, "dmg": 72, "poise": 45, "stamina": 30, "reach": 3.2, "arc": 1.7, "lunge": 2.6},
	"g_heavy": {"anim": "spin", "speed": 1.15, "hit": 0.7, "end": 1.6, "dmg": 85, "poise": 55, "stamina": 40, "reach": 3.3, "arc": 3.2, "lunge": 1.0},
	"g_run_atk": {"anim": "slide", "speed": 1.4, "hit": 1.23, "end": 1.9, "dmg": 60, "poise": 40, "stamina": 30, "reach": 3.0, "arc": 1.2, "lunge": 6.0},
	"g_roll_atk": {"anim": "jump_atk", "speed": 1.3, "hit": 0.9, "end": 1.7, "dmg": 78, "poise": 60, "stamina": 34, "reach": 3.0, "arc": 1.3, "lunge": 3.5},
	"g_kick": {"anim": "kick", "speed": 1.4, "hit": 0.6, "end": 1.2, "dmg": 16, "poise": 50, "stamina": 16, "reach": 2.1, "arc": 0.9, "lunge": 1.2},
	"g_riposte": {"anim": "attack", "speed": 1.2, "hit": 0.47, "end": 1.15, "dmg": 190, "poise": 0, "stamina": 12, "reach": 3.0, "arc": 1.4, "lunge": 2.5},
}
const COMBO := ["c1", "c2", "c3", "c4", "c5"]
const COMBO_G := ["g1", "g2", "g3", "g4"]
const ENEMY_SPAWNS := [
	[Vector3(-4, 0, 4), "warrior"], [Vector3(4, 0, 0), "minion"], [Vector3(-2, 0, -6), "warrior"],
	[Vector3(5, 0, -10), "minion"], [Vector3(-14, 0, -2), "minion"], [Vector3(12, 0, 6), "warrior"],
]
const SHARD_SPOTS := [Vector3(-17, 0.6, -9), Vector3(16, 0.6, 22)]

# player
var player: CharacterBody3D
var model: Node3D
var anim: AnimationPlayer
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var cam_yaw := PI
var cam_pitch := -0.35
var hp := 150.0
var max_hp := 150.0
var max_stamina := 100.0
var essence := 100.0
var level := 1
var dmg_mult := 1.0
var max_flasks := 3
var move := ""
var attack_hold := 0.0
var sprinting := false
var sprint_t := 0.0
var since_roll := 99.0
var block_t := 0.0
var hit_len := 0.55
var idle_t := 0.0
var auto_block := 0.0
var shards: Array = []
var weapon := "sword"  # sword (sword + shield) or great (great sword, two hands)
var sword_props: Array = []
var great_prop: Node3D
var gate: StaticBody3D
var gate_bars: Node3D
var stamina := 100.0
var stamina_delay := 0.0
var flasks := 3
var embers := 0
var state := "free"  # free, attack, roll, hit, drink, cast, dead
var state_t := 0.0
var combo_queued := false
var combo_step := 0
var hit_done := false
var roll_dir := Vector3.ZERO
var lock_target = null
var seed_cd := 0.0
var dropped_embers := 0
var dropped_marker: Node3D
var invuln_t := 0.0

var enemies: Array = []
var boss = null
var fireballs: Array = []
var floaters: Array = []
var stone_mat: StandardMaterial3D
var steel_mat: StandardMaterial3D
var ui: CanvasLayer
var ui_draw: Control
var joystick: Control
var buttons := {}
var banner := ""
var banner_sub := ""
var banner_t := 0.0
var banner_col := Color.WHITE
var cam_touch := -1
var shake := 0.0
var autoplay := OS.get_environment("SEMENTES_AUTOPLAY") == "1"  # playtest robot for screenshots only
var dragon_seed := false
var sfx_players: Array = []
var sfx_cache := {}
var music_amb: AudioStreamPlayer
var music_boss: AudioStreamPlayer
var step_t := 0.0

func _ready() -> void:
	randomize()
	stone_mat = _pbr("castle_wall_slates", 1.0)
	steel_mat = StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.32, 0.33, 0.37)
	steel_mat.metallic = 0.9
	steel_mat.roughness = 0.32
	_build_world()
	_build_player()
	for sp in ENEMY_SPAWNS:
		_spawn_enemy(sp[0], sp[1])
	for p in SHARD_SPOTS:
		shards.append(_glow_marker(p, Color(0.4, 1.0, 0.5)))
	_spawn_boss()
	_build_gate()
	_build_ui()
	_build_audio()
	_show_banner("RUÍNAS DO GUARDIÃO", "Atrás do portão espera o Dragão", Color(0.95, 0.85, 0.65), 4.0)

# ------------------------------------------------------------------ world
func _pbr(name: String, uv: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_diff_1k.jpg" % name)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/%s_nor_gl_1k.jpg" % name)
	m.roughness_texture = load("res://assets/tex/%s_rough_1k.jpg" % name)
	m.uv1_scale = Vector3(uv, uv, uv)
	return m

func _prop(name: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	var s: Node3D = load("res://assets/props/%s.glb" % name).instantiate()
	s.position = pos
	s.rotation.y = rot_y
	s.scale = Vector3.ONE * scale
	add_child(s)
	for m in s.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mt = m.mesh.surface_get_material(i)
			if mt and mt.resource_name == "stone":
				m.set_surface_override_material(i, stone_mat)
	return s

func _box_collider(pos: Vector3, size: Vector3, mesh_mat: Material = null) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	if mesh_mat:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mesh_mat
		body.add_child(mi)
	add_child(body)

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	we.environment = e
	add_child(we)
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.32, 0.42)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.09, 0.12)
	e.fog_density = 0.03
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, 150, 0)
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40
	add_child(moon)
	var floor_mat := _pbr("cobblestone_floor_08", 18.0)
	_box_collider(Vector3(0, -0.5, -6), Vector3(44, 1, 76), floor_mat)
	var wall := _pbr("castle_wall_slates", 4.0)
	_box_collider(Vector3(-22, 4, -6), Vector3(1, 8, 76), wall)
	_box_collider(Vector3(22, 4, -6), Vector3(1, 8, 76), wall)
	_box_collider(Vector3(0, 4, 32), Vector3(44, 8, 1), wall)
	_box_collider(Vector3(0, 4, -44), Vector3(44, 8, 1), wall)
	# divider wall with the archway to the boss arena
	_box_collider(Vector3(-12.6, 3, -14), Vector3(18.8, 6, 1.2), wall)
	_box_collider(Vector3(12.6, 3, -14), Vector3(18.8, 6, 1.2), wall)
	var arch := _prop("archway_gate", Vector3(0, 0, -14))
	arch.get_children()  # keep the gate visual; the bars are decorative and open
	_prop("bonfire", BONFIRE_POS)
	var fire := OmniLight3D.new()
	fire.position = BONFIRE_POS + Vector3(0, 0.9, 0)
	fire.light_color = Color(1, 0.5, 0.15)
	fire.light_energy = 3.0
	fire.omni_range = 9
	add_child(fire)
	for i in 4:
		var side := -1 if i % 2 == 0 else 1
		_prop("column_broken", Vector3(side * 9, 0, 8 - i * 6), randf() * TAU)
	_prop("graves", Vector3(-12, 0, 10), 0.3)
	_prop("graves", Vector3(13, 0, -4), -0.5)
	_prop("wall_ruin", Vector3(10, 0, 10), 0.4)
	_prop("wall_ruin", Vector3(-11, 0, -6), -0.2)
	_prop("seed_shrine", Vector3(0, 0, -38))
	for x in [-1.7, 1.7]:
		var t := _prop("torch_sconce", Vector3(x * 1.6, 2.6, -13.3), PI)
		var l := OmniLight3D.new()
		l.position = t.position + Vector3(0, 0.6, 0.4)
		l.light_color = Color(1, 0.55, 0.2)
		l.light_energy = 2.2
		l.omni_range = 8
		add_child(l)
	for z in [-22.0, -32.0]:
		for x in [-14.0, 14.0]:
			_prop("column_broken", Vector3(x, 0, z), randf() * TAU, 1.3)
			var l2 := OmniLight3D.new()
			l2.position = Vector3(x * 0.85, 2.0, z)
			l2.light_color = Color(1, 0.35, 0.1)
			l2.light_energy = 1.6
			l2.omni_range = 9
			add_child(l2)

# ------------------------------------------------------------------ characters
func _load_anims(ap: AnimationPlayer) -> void:
	var lib := AnimationLibrary.new()
	for key in ANIMS:
		var src: AnimationPlayer = load("res://assets/mixamo/%s.fbx" % ANIMS[key]).instantiate().find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = src.get_animation("mixamo_com").duplicate()
		# strip root motion on the hips so the body moves the character, not the clip
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and str(a.track_get_path(t)).ends_with("mixamorig_Hips"):
				var k0: Vector3 = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(k0.x, v.y, k0.z))
		a.loop_mode = Animation.LOOP_LINEAR if key in LOOPING else Animation.LOOP_NONE
		lib.add_animation(key, a)
	ap.add_animation_library("p", lib)

func _attach(skel: Skeleton3D, bone: String, prop_name: String, xf: Transform3D) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var p: Node3D = load("res://assets/props/%s.glb" % prop_name).instantiate()
	p.transform = xf
	ba.add_child(p)
	return ba

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = BONFIRE_POS + Vector3(0, 0, -2.5)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	player.add_child(cs)
	add_child(player)
	model = load("res://assets/mixamo/x_bot.fbx").instantiate()
	player.add_child(model)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, steel_mat if i == 0 else _dark_cloth())
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	_load_anims(anim)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	# hand bones are scaled by 100 in Mixamo rigs exported to cm; the props are in metres
	var s := 1.0 / skel.get_bone_global_rest(skel.find_bone("mixamorig_RightHand")).basis.get_scale().x
	sword_props.append(_attach(skel, "mixamorig_RightHand", "longsword", Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3.ONE * s), Vector3(0, 0.07, 0.02) * s)))
	great_prop = _attach(skel, "mixamorig_RightHand", "longsword", Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3(1.4, 1.4, 1.8) * s), Vector3(0, 0.07, 0.02) * s))
	great_prop.visible = false
	sword_props.append(_attach(skel, "mixamorig_LeftForeArm", "shield", Transform3D(Basis(Vector3.UP, PI / 2).rotated(Vector3.FORWARD, PI / 2).scaled(Vector3.ONE * s), Vector3(0.0, 0.18, 0.06) * s)))
	anim.play("p/idle")
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 4.2
	spring.margin = 0.2
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 65
	camera.far = 120
	spring.add_child(camera)

func _dark_cloth() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.05, 0.04)
	m.roughness = 0.9
	return m

func _skeleton_model(kind: String) -> Node3D:
	var k: Node3D = load("res://assets/skeletons/Skeleton_%s.glb" % ("Warrior" if kind == "warrior" else "Minion")).instantiate()
	k.scale = Vector3.ONE * (1.0 if kind == "warrior" else 0.92)
	for m in k.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mt = m.mesh.surface_get_material(i)
			if mt is StandardMaterial3D:
				var d: StandardMaterial3D = mt.duplicate()
				d.albedo_color = Color(0.72, 0.68, 0.62)  # aged bone, less toy-like
				d.roughness = 0.85
				m.set_surface_override_material(i, d)
	var skel: Skeleton3D = k.find_children("*", "Skeleton3D", true, false)[0]
	var ba := BoneAttachment3D.new()
	ba.bone_name = "handslot.r"
	skel.add_child(ba)
	ba.add_child(load("res://assets/skeletons/Skeleton_Blade.gltf").instantiate())
	return k

func _spawn_enemy(pos: Vector3, kind := "warrior") -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = randf() * TAU
	add_child(root)
	var k := _skeleton_model(kind)
	root.add_child(k)
	var eye := OmniLight3D.new()
	eye.position = Vector3(0, 1.7, 0.25)
	eye.light_color = Color(1, 0.1, 0.05)
	eye.light_energy = 0.0
	eye.omni_range = 1.8
	root.add_child(eye)
	var ap: AnimationPlayer = k.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("Skeletons_Inactive_Floor_Pose")
	var hpv := 90.0 if kind == "warrior" else 55.0
	var poise := 40.0 if kind == "warrior" else 22.0
	enemies.append({"root": root, "ap": ap, "eye": eye, "kind": kind, "hp": hpv, "max": hpv, "poise": poise, "max_poise": poise,
		"home": pos, "state": "dormant", "t": 0.0, "hit": false, "dead": false, "atk": "", "wind_pos": 0.0, "leap": false})

func _spawn_boss() -> void:
	var root := Node3D.new()
	root.position = BOSS_HOME
	add_child(root)
	var d: Node3D = load("res://assets/dragon/dragon.dae").instantiate()
	d.scale = Vector3(6.5, 6.5, 6.5)
	d.position.y = 2.4
	d.rotation.y = PI
	root.add_child(d)
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = load("res://assets/dragon/dragon.png")
	dm.roughness = 0.55
	for m in d.find_children("*", "MeshInstance3D", true, false):
		m.material_override = dm
	var ap: AnimationPlayer = d.find_children("*", "AnimationPlayer", true, false)[0] if not d.find_children("*", "AnimationPlayer", true, false).is_empty() else AnimationPlayer.new()
	if ap.get_parent() == null:
		d.add_child(ap)
	var lib := AnimationLibrary.new()
	for key in ["idle", "walk", "attack", "die"]:
		var src: Node = load("res://assets/dragon/dragon_%s.dae" % key).instantiate()
		var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = sap.get_animation(sap.get_animation_list()[0]).duplicate()
		a.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "walk"] else Animation.LOOP_NONE
		lib.add_animation(key, a)
	ap.add_animation_library("d", lib)
	ap.play("d/idle")
	var mouth := OmniLight3D.new()
	mouth.position = Vector3(0, 3.5, 3.5)
	mouth.light_color = Color(1, 0.4, 0.05)
	mouth.light_energy = 0.0
	mouth.omni_range = 10
	root.add_child(mouth)
	boss = {"root": root, "ap": ap, "mouth": mouth, "hp": 1100.0, "max": 1100.0, "state": "idle", "t": 0.0, "hit": false, "dead": false, "awake": false, "next": "bite", "phase": 1}

# ------------------------------------------------------------------ loop
func _physics_process(dt: float) -> void:
	_update_player(dt)
	for e in enemies:
		_update_enemy(e, dt)
	_update_boss(dt)
	_update_fireballs(dt)
	_update_pickups()
	_update_camera(dt)
	banner_t = max(0.0, banner_t - dt)
	shake = max(0.0, shake - dt * 3.0)
	for f in floaters:
		f.t -= dt
		f.pos.y += dt * 0.8
	floaters = floaters.filter(func(f): return f.t > 0)
	ui_draw.queue_redraw()

func _cam_basis_dirs() -> Array:
	var fwd := -Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var right := Vector3(-fwd.z, 0, fwd.x)
	return [fwd, right]

func _input_vec() -> Vector2:
	return _autoplay_vec() if autoplay else Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _input_dir() -> Vector3:
	var v := _input_vec()
	var d := _cam_basis_dirs()
	return (d[0] * -v.y + d[1] * v.x)

func _fwd() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))

func _update_player(dt: float) -> void:
	invuln_t = max(0.0, invuln_t - dt)
	seed_cd = max(0.0, seed_cd - dt)
	since_roll += dt
	stamina_delay -= dt
	if stamina_delay <= 0 and state in ["free"] and not sprinting:
		stamina = min(max_stamina, stamina + 40.0 * dt)
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * dt
	else:
		player.velocity.y = 0.0
	var v := _input_vec()
	var dir := _input_dir()
	state_t += dt
	# heavy attack: hold ATTACK
	if _held("attack") and state == "free":
		attack_hold += dt
		if attack_hold > 0.32 and stamina > 5:
			attack_hold = -99.0
			_start_move(_mv("heavy"))
	elif not _held("attack"):
		attack_hold = 0.0
	match state:
		"free":
			sprint_t = sprint_t + dt if v.length() > 0.95 and lock_target == null else 0.0
			sprinting = sprint_t > 0.6 and stamina > 1
			var speed := 4.6
			if sprinting:
				speed = 7.2
				stamina -= 14.0 * dt
				stamina_delay = 0.4
			elif lock_target != null:
				speed = 3.2
			var hv := dir * speed
			player.velocity.x = hv.x
			player.velocity.z = hv.z
			if lock_target != null:
				_face(lock_target.root.position - player.position)
				_play_locomotion(dir)
			else:
				if dir.length() > 0.1:
					_face(dir)
				if dir.length() > 0.1:
					anim.speed_scale = 1.35 if sprinting else 1.0
					_play(_a("run"), 0.15)
				else:
					anim.speed_scale = 1.0
					idle_t += dt
					_play(_a("idle2" if idle_t > 6.0 else "idle"), 0.3)
			if dir.length() > 0.1:
				idle_t = 0.0
				step_t -= dt * (1.5 if sprinting else 1.0)
				if step_t <= 0:
					step_t = 0.36
					_sfx(["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003", "footstep_concrete_004"], -10)
			if _pressed("attack") and stamina > 5:
				attack_hold = 0.0
				if _held("block"):
					_start_move(_mv("kick"))
				else:
					_start_attack()
			elif _pressed("roll") and stamina > 5:
				_start_roll(dir)
			elif _pressed("seed") and seed_cd <= 0 and essence >= 30:
				_start_cast()
			elif _pressed("flask") and flasks > 0:
				_set_state("drink")
				anim.speed_scale = 1.0
				_play(_a("drink"), 0.1)
				_sfx("metalPot1", -6)
			elif _held("block") and stamina > 0:
				_set_state("block")
				block_t = 0.0
				_play(_a("block_idle"), 0.1)
			elif _pressed("level") and player.position.distance_to(BONFIRE_POS) < 3.0:
				_level_up()
			elif _pressed("weapon"):
				_set_state("swap")
				anim.play("p/g_draw" if weapon == "sword" else "p/draw", 0.1, 1.4)
				_sfx("drawKnife1", -2)
		"attack":
			var mv: Dictionary = MOVES[move]
			var hit_at: float = mv.hit / mv.speed
			var lunge: float = mv.get("lunge", 1.5)
			var k := 1.0 if state_t < hit_at else 0.25
			player.velocity.x = _fwd().x * lunge * k
			player.velocity.z = _fwd().z * lunge * k
			if lock_target != null and state_t < hit_at * 0.7:
				_face(lock_target.root.position - player.position)
			elif state_t < hit_at * 0.5 and dir.length() > 0.1:
				_face(dir)
			if _pressed("attack"):
				combo_queued = true
			if not hit_done and state_t > hit_at:
				hit_done = true
				_player_hit_check(move)
			var end_at: float = mv.end / mv.speed
			var combo: Array = COMBO_G if weapon == "great" else COMBO
			if state_t > hit_at + 0.12 and combo_queued and stamina > 5 and move in combo and move != combo[-1]:
				_start_move(combo[combo.find(move) + 1])
			elif state_t > hit_at + 0.15 and _pressed("roll") and stamina > 5:
				_start_roll(dir)
			elif state_t > end_at:
				_set_state("free")
		"roll":
			var k2: float = 1.0 - clampf(state_t / 0.75, 0.0, 1.0)
			player.velocity.x = roll_dir.x * 7.5 * (0.3 + k2)
			player.velocity.z = roll_dir.z * 7.5 * (0.3 + k2)
			if state_t > 0.85:
				since_roll = 0.0
				_set_state("free")
		"block":
			block_t += dt
			player.velocity.x = dir.x * 1.6
			player.velocity.z = dir.z * 1.6
			if lock_target != null:
				_face(lock_target.root.position - player.position)
			elif dir.length() > 0.1:
				_face(dir)
			if _pressed("attack") and stamina > 5:
				_start_move(_mv("kick"))
			elif not _held("block"):
				_set_state("free")
		"swap":
			player.velocity.x = 0
			player.velocity.z = 0
			# the hand reaches the back halfway through the draw clip: swap the props there
			if state_t > 0.45 and state_t - dt <= 0.45:
				weapon = "great" if weapon == "sword" else "sword"
				great_prop.visible = weapon == "great"
				for p in sword_props:
					p.visible = weapon == "sword"
			if state_t > 1.0:
				_set_state("free")
				_show_banner("ESPADÃO" if weapon == "great" else "ESPADA E ESCUDO",
					"Duas mãos: mais dano e alcance, mais lento" if weapon == "great" else "Rápida, escudo forte para aparar", Color(0.85, 0.85, 0.9), 1.6)
		"hit":
			player.velocity.x = 0
			player.velocity.z = 0
			if state_t > hit_len:
				_set_state("free")
		"drink":
			player.velocity.x = 0
			player.velocity.z = 0
			if state_t > 0.9 and state_t - dt <= 0.9 and flasks > 0:
				flasks -= 1
				hp = min(max_hp, hp + 70)
				_float("+70", player.position + Vector3(0, 2, 0), Color(0.6, 1, 0.6))
			if state_t > 1.4:
				_set_state("free")
		"cast":
			player.velocity.x = 0
			player.velocity.z = 0
			if state_t > 0.45 and state_t - dt <= 0.45:
				_throw_fireball()
			if state_t > 0.9:
				_set_state("free")
		"dead":
			player.velocity = Vector3.ZERO
			if state_t > 4.0:
				_respawn()
	player.move_and_slide()
	if _pressed("lock"):
		_toggle_lock()
	if lock_target != null and (lock_target.dead or lock_target.root.position.distance_to(player.position) > 20):
		lock_target = null
	# bonfire rest
	if state == "free" and player.position.distance_to(BONFIRE_POS) < 2.2 and (hp < max_hp or flasks < max_flasks or essence < 100):
		hp = max_hp
		flasks = max_flasks
		essence = 100.0
		_respawn_enemies()
		_show_banner("FOGUEIRA ACESA", "Vida, frascos e essência restaurados. Os mortos se levantam de novo.", Color(1, 0.7, 0.3), 2.5)
	# reclaim dropped embers
	if dropped_marker != null and player.position.distance_to(dropped_marker.position) < 1.5:
		embers += dropped_embers
		_float("+%d brasas recuperadas" % dropped_embers, player.position + Vector3(0, 2.2, 0), Color(1, 0.7, 0.3))
		dropped_embers = 0
		dropped_marker.queue_free()
		dropped_marker = null

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "free":
		anim.speed_scale = 1.0

func _play_locomotion(dir: Vector3) -> void:
	if dir.length() < 0.1:
		_play(_a("idle"), 0.2)
		return
	var local := dir.rotated(Vector3.UP, -model.rotation.y)
	if abs(local.x) > abs(local.z):
		_play(_a("strafe_l" if local.x > 0 else "strafe_r"), 0.2)
	else:
		_play(_a("walk" if local.z > 0 else "walk_back"), 0.2)

func _pressed(action: String) -> bool:
	if autoplay:
		return _autoplay_press(action)
	return Input.is_action_just_pressed(action)

func _held(action: String) -> bool:
	if autoplay:
		return action == "block" and auto_block > 0
	return Input.is_action_pressed(action)

func _face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.3)

func _play(name: String, blend: float) -> void:
	if anim.current_animation != name:
		anim.play(name, blend)

# animation name for the weapon in hand
func _a(n: String) -> String:
	return "p/g_" + n if weapon == "great" and ANIMS.has("g_" + n) else "p/" + n

# move name for the weapon in hand
func _mv(n: String) -> String:
	return "g_" + n if weapon == "great" else n

func _spend(amount: float) -> void:
	stamina = max(-10.0, stamina - amount)
	stamina_delay = 0.6

func _start_attack() -> void:
	var t = _broken_target_in_front()
	if t != null:
		_start_move(_mv("riposte"))
	elif since_roll < 0.35:
		_start_move(_mv("roll_atk"))
	elif sprinting:
		_start_move(_mv("run_atk"))
	else:
		_start_move((COMBO_G if weapon == "great" else COMBO)[0])

func _start_move(name: String) -> void:
	var mv: Dictionary = MOVES[name]
	move = name
	_set_state("attack")
	hit_done = false
	combo_queued = false
	sprinting = false
	_spend(mv.stamina)
	anim.play(_a(mv.anim), 0.08, mv.speed)
	_sfx(["knifeSlice", "knifeSlice2", "drawKnife1"] if not name.ends_with("kick") else ["cloth1"], -3)

func _start_roll(dir: Vector3) -> void:
	_set_state("roll")
	_spend(18.0)
	roll_dir = dir.normalized() if dir.length() > 0.1 else _fwd()
	model.rotation.y = atan2(roll_dir.x, roll_dir.z)
	invuln_t = 0.45
	anim.play(_a("roll"), 0.05, 1.7)
	_sfx(["cloth1", "cloth3"], -2)

func _start_cast() -> void:
	_set_state("cast")
	seed_cd = 1.2
	essence -= 30.0
	anim.play(_a("cast"), 0.1, 1.2)

func _level_up() -> void:
	var cost := 150 * level
	if embers < cost:
		_show_banner("BRASAS INSUFICIENTES", "Precisa de %d brasas para o nível %d" % [cost, level + 1], Color(0.8, 0.6, 0.4), 2.0)
		return
	embers -= cost
	level += 1
	max_hp += 15.0
	max_stamina += 8.0
	dmg_mult += 0.06
	hp = max_hp
	stamina = max_stamina
	_sfx("jingle_win", -6)
	_show_banner("NÍVEL %d" % level, "+15 vida  ·  +8 estamina  ·  +6%% dano", Color(1, 0.8, 0.4), 2.5)

func _broken_target_in_front():
	for e in enemies:
		if not e.dead and e.state == "broken":
			var to: Vector3 = e.root.position - player.position
			if to.length() < 2.6:
				return e
	return null

func _player_hit_check(name: String) -> void:
	var mv: Dictionary = MOVES[name]
	var fwd := _fwd()
	for e in enemies:
		if e.dead:
			continue
		var to: Vector3 = e.root.position - player.position
		if to.length() < mv.reach and fwd.angle_to(to.normalized()) < mv.arc:
			_damage_enemy(e, mv)
	if boss != null and not boss.dead:
		var tb: Vector3 = boss.root.position - player.position
		if tb.length() < mv.reach + 2.6 and fwd.angle_to(tb.normalized()) < 1.0:
			_damage_boss(mv.dmg * dmg_mult)

func _damage_enemy(e: Dictionary, mv: Dictionary) -> void:
	if e.state in ["dormant", "awaken"]:
		return
	var dmg: float = mv.dmg * dmg_mult
	if e.state == "broken" and move == "riposte":
		dmg = 140.0 * dmg_mult
		_float("CRÍTICO!", e.root.position + Vector3(0, 2.6, 0), Color(1, 0.3, 0.2))
		shake = 0.6
	elif e.state == "block":
		if move == "kick":
			_break_guard(e)
			return
		dmg *= 0.2
		e.ap.play("Block_Hit", 0.05)
		_sfx("impactPlate_heavy_002", -2)
		_float("bloqueou", e.root.position + Vector3(0, 2.3, 0), Color(0.7, 0.7, 0.8))
	e.hp -= dmg
	shake = max(shake, 0.25)
	_sfx(["impactWood_heavy_000", "impactPlate_heavy_000"], -2)
	_float(str(int(dmg)), e.root.position + Vector3(0, 2.1, 0), Color.WHITE)
	if e.hp <= 0:
		_kill_enemy(e)
		return
	if e.state == "block":
		return
	e.poise -= mv.poise
	if e.poise <= 0:
		_break_guard(e)
	elif e.state != "broken":
		e.state = "stagger"
		e.t = 0.0
		e.ap.play(["Hit_A", "Hit_B"].pick_random(), 0.05, 1.4)

func _break_guard(e: Dictionary) -> void:
	e.state = "broken"
	e.t = 0.0
	e.poise = e.max_poise
	e.ap.play("Hit_B", 0.05, 0.5)
	_sfx("impactPlate_heavy_001", 0)
	_float("ATORDOADO", e.root.position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3))

func _kill_enemy(e: Dictionary) -> void:
	e.dead = true
	e.ap.play(["Death_A", "Death_B"].pick_random())
	e.eye.light_energy = 0.0
	var reward: int = 60 if e.kind == "warrior" else 35
	embers += reward
	_float("+%d brasas" % reward, e.root.position + Vector3(0, 2.6, 0), Color(1, 0.7, 0.3))
	if lock_target == e:
		lock_target = null

func _damage_boss(dmg: float) -> void:
	boss.hp -= dmg
	_wake_boss()
	shake = 0.3
	_sfx(["impactPlate_heavy_001", "impactPlate_heavy_002"], -1)
	_float(str(int(dmg)), boss.root.position + Vector3(0, 5, 0), Color(1, 0.9, 0.6))
	if boss.phase == 1 and boss.hp < boss.max * 0.5:
		boss.phase = 2
		boss.state = "chase"
		boss.t = 0.0
		_sfx("dragon_roar", 4)
		shake = 0.8
		_show_banner("O DRAGÃO SE ENFURECE", "Ataques mais rápidos", Color(1, 0.25, 0.1), 2.5)
	if boss.hp <= 0 and not boss.dead:
		boss.dead = true
		boss.ap.play("d/die")
		embers += 2000
		dragon_seed = true
		_sfx("dragon_roar", 2)
		_sfx("jingle_win", -2)
		_fade(music_boss, -80.0, 4.0)
		_fade(music_amb, -8.0, 4.0)
		_set_gate(false)
		_show_banner("DRAGÃO DERROTADO", "Você obteve a SEMENTE DO DRAGÃO  ·  +2000 brasas", Color(1, 0.6, 0.15), 6.0)

func _hurt_player(dmg: float, src: String, attacker: Dictionary = {}) -> void:
	if invuln_t > 0 or state == "dead":
		return
	if state == "block":
		if block_t < 0.22 and not attacker.is_empty():
			_float("APARADO!", player.position + Vector3(0, 2.2, 0), Color(0.6, 0.9, 1))
			_sfx("impactPlate_heavy_002", 2)
			anim.play(_a("parry"), 0.05, 1.4)
			_break_guard(attacker)
			return
		stamina -= dmg * (1.4 if weapon == "great" else 0.9)
		stamina_delay = 0.6
		anim.play(_a("block_hit"), 0.05, 1.3)
		_sfx("impactPlate_heavy_000", 0)
		if stamina > 0:
			hp -= dmg * 0.1
			return
		_float("GUARDA QUEBRADA", player.position + Vector3(0, 2.2, 0), Color(1, 0.5, 0.3))
		dmg *= 0.5
	hp -= dmg
	shake = 0.5
	_sfx(["impactPunch_heavy_000", "impactPunch_heavy_001"], 0)
	_float("-%d" % int(dmg), player.position + Vector3(0, 2, 0), Color(1, 0.3, 0.3))
	if hp <= 0:
		hp = 0
		_set_state("dead")
		anim.play(_a(["death", "death2"].pick_random()), 0.1)
		_sfx("jingle_death", -2)
		if dropped_marker != null:
			dropped_marker.queue_free()
		dropped_embers = embers
		embers = 0
		if dropped_embers > 0:
			dropped_marker = _glow_marker(player.position, Color(1, 0.5, 0.1))
		_show_banner("VOCÊ MORREU", "%s · suas brasas ficaram onde você caiu" % src, Color(0.75, 0.05, 0.05), 4.0)
	elif state in ["free", "drink", "cast", "block"]:
		_set_state("hit")
		var h: String = ["hit1", "hit2", "hit3"].pick_random()
		hit_len = 0.55
		anim.play(_a(h), 0.05, 1.3)

func _glow_marker(pos: Vector3, col: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.0
	l.omni_range = 3
	l.position.y = 0.4
	n.add_child(l)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	orb.mesh = sm
	var om := StandardMaterial3D.new()
	om.emission_enabled = true
	om.emission = col
	om.emission_energy_multiplier = 5
	orb.material_override = om
	orb.position.y = 0.4
	n.add_child(orb)
	add_child(n)
	return n

func _update_pickups() -> void:
	for s in shards.duplicate():
		s.rotation.y += 0.03
		if s.position.distance_to(player.position) < 1.4:
			max_flasks += 1
			flasks += 1
			shards.erase(s)
			s.queue_free()
			_sfx("jingle_win", -8)
			_show_banner("FRAGMENTO DE SEIVA", "Frascos máximos: %d" % max_flasks, Color(0.5, 1, 0.6), 2.5)

func _respawn() -> void:
	player.position = BONFIRE_POS + Vector3(0, 0, -2.5)
	hp = max_hp
	stamina = max_stamina
	flasks = max_flasks
	essence = 100.0
	_set_state("free")
	lock_target = null
	_respawn_enemies()
	if boss != null and not boss.dead:
		boss.hp = boss.max
		boss.awake = false
		boss.phase = 1
		boss.root.position = BOSS_HOME
		boss.state = "idle"
		_set_gate(false)
		_fade(music_boss, -80.0, 2.0)
		_fade(music_amb, -8.0, 2.0)

func _respawn_enemies() -> void:
	for e in enemies:
		e.root.queue_free()
	enemies.clear()
	for sp in ENEMY_SPAWNS:
		_spawn_enemy(sp[0], sp[1])

func _toggle_lock() -> void:
	if lock_target != null:
		lock_target = null
		return
	var best = null
	var bd := 18.0
	var cands: Array = enemies.filter(func(e): return not e.dead and e.state != "dormant")
	if boss != null and not boss.dead and boss.awake:
		cands.append(boss)
	for c in cands:
		var d: float = c.root.position.distance_to(player.position)
		if d < bd:
			bd = d
			best = c
	lock_target = best

# ------------------------------------------------------------------ boss gate
func _build_gate() -> void:
	gate = StaticBody3D.new()
	gate.position = Vector3(0, 0, -14)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.2, 4, 0.4)
	cs.shape = sh
	cs.position.y = 2
	cs.disabled = true
	gate.add_child(cs)
	gate_bars = Node3D.new()
	gate_bars.position.y = 4.2
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.1, 0.11)
	iron.metallic = 0.9
	iron.roughness = 0.5
	for i in 9:
		var bar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 3.8
		bar.mesh = cm
		bar.material_override = iron
		bar.position = Vector3(-1.2 + i * 0.3, 1.9, 0.15)
		gate_bars.add_child(bar)
	gate.add_child(gate_bars)
	add_child(gate)

func _set_gate(closed: bool) -> void:
	(gate.get_child(0) as CollisionShape3D).disabled = not closed
	create_tween().tween_property(gate_bars, "position:y", 0.0 if closed else 4.2, 0.5 if closed else 2.0)
	if closed:
		_sfx("impactMetal_heavy_000" if sfx_cache.has("impactMetal_heavy_000") else "impactPlate_heavy_001", 2)

func _wake_boss() -> void:
	if boss.awake:
		return
	boss.awake = true
	_set_gate(true)
	_show_banner("DRAGÃO GUARDIÃO", "", Color(1, 0.45, 0.15), 3.0)
	_sfx("dragon_roar", 3)
	_fade(music_amb, -80.0, 2.0)
	_fade(music_boss, -4.0, 2.0)

# ------------------------------------------------------------------ enemies
func _update_enemy(e: Dictionary, dt: float) -> void:
	if e.dead:
		return
	e.t += dt
	var to: Vector3 = player.position - e.root.position
	to.y = 0
	var dist := to.length()
	var ap: AnimationPlayer = e.ap
	var speed: float = 3.0 if e.kind == "warrior" else 3.9
	match e.state:
		"dormant":
			if dist < 9 and state != "dead":
				e.state = "awaken"
				e.t = 0.0
				e.eye.light_energy = 0.5
				ap.play("Skeletons_Awaken_Floor", 0.1, 1.3)
				_sfx("impactWood_heavy_000", -6)
		"awaken":
			if e.t > 1.9:
				e.state = "chase"
		"idle":
			if dist < 11 and state != "dead":
				e.state = "chase"
		"chase":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.15)
			# warriors raise the shield when the player swings at them
			if e.kind == "warrior" and state == "attack" and state_t < 0.1 and dist < 3.2 and randf() < 0.35:
				e.state = "block"
				e.t = 0.0
				ap.play("Blocking", 0.1)
				return
			if dist > 4.0 and dist < 6.5 and e.t > 1.5 and randf() < 0.02:
				_enemy_attack(e, "1H_Melee_Attack_Jump_Chop")
				e.leap = true
			elif dist > 1.9:
				e.root.position += to.normalized() * speed * dt
				if ap.current_animation != "Running_A":
					ap.play("Running_A", 0.2)
			else:
				_enemy_attack(e, ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Stab"].pick_random())
			if dist > 16 or state == "dead":
				e.state = "idle"
				ap.play("Idle_Combat", 0.2)
		"windup":
			e.eye.light_energy = 0.5 + 6.0 * e.t
			if e.t > (0.45 if e.kind == "warrior" else 0.3):
				e.state = "strike"
				e.t = 0.0
				e.hit = false
				ap.speed_scale = 1.0
				ap.play(e.atk, 0.0, 1.4)
				ap.seek(e.wind_pos, true)
				_sfx(["knifeSlice", "knifeSlice2"], -4)
		"strike":
			e.eye.light_energy = 0.5
			var length: float = ap.current_animation_length
			if e.leap and ap.current_animation_position < length * 0.5:
				e.root.position += to.normalized() * 5.5 * dt
			if not e.hit and ap.current_animation_position > length * 0.5:
				e.hit = true
				var fwd := Vector3(sin(e.root.rotation.y), 0, cos(e.root.rotation.y))
				if dist < 2.6 and fwd.angle_to(to.normalized()) < 1.0:
					_hurt_player(30.0 if e.kind == "warrior" else 20.0, "Esqueleto Guerreiro" if e.kind == "warrior" else "Esqueleto Lacaio", e)
			if ap.current_animation_position > length * 0.92 or e.t > 2.5:
				e.state = "chase"
				e.t = 0.0
				e.leap = false
		"block":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.2)
			if e.t > 1.1:
				e.state = "chase"
				e.t = 0.0
		"stagger":
			e.eye.light_energy = 0.5
			e.root.position -= to.normalized() * 1.5 * dt
			if e.t > 0.45:
				e.state = "chase"
				e.t = 0.0
		"broken":
			e.eye.light_energy = 0.1
			if e.t > 2.5:
				e.state = "chase"
				e.t = 0.0

func _enemy_attack(e: Dictionary, atk: String) -> void:
	e.state = "windup"
	e.t = 0.0
	e.atk = atk
	e.ap.play(atk, 0.1, 0.35)
	e.wind_pos = 0.0
	e.wind_pos = (0.45 if e.kind == "warrior" else 0.3) * 0.35

func _update_boss(dt: float) -> void:
	if boss == null or boss.dead:
		return
	boss.t += dt
	var root: Node3D = boss.root
	var to: Vector3 = player.position - root.position
	to.y = 0
	var dist := to.length()
	var ap: AnimationPlayer = boss.ap
	var fury: float = 1.0 if boss.phase == 1 else 1.45
	if not boss.awake:
		if player.position.z < -15.5 and state != "dead":
			_wake_boss()
		return
	match boss.state:
		"idle", "chase":
			root.rotation.y = lerp_angle(root.rotation.y, atan2(to.x, to.z), 0.06 * fury)
			if dist > 5.5:
				root.position += to.normalized() * 2.6 * fury * dt
				if ap.current_animation != "d/walk":
					ap.play("d/walk", 0.3, fury)
			elif boss.t > 1.2 / fury:
				boss.state = "windup"
				boss.t = 0.0
				boss.next = "breath" if randf() < (0.4 if boss.phase == 1 else 0.55) else "bite"
			if dist > 9 and boss.t > 3.0 / fury and randf() < 0.01 * fury:
				boss.state = "windup"
				boss.t = 0.0
				boss.next = "breath"
		"windup":
			ap.play("d/attack", 0.2, 0.6 * fury)
			boss.mouth.light_energy = boss.t * 8.0
			var wind := (0.9 if boss.next == "bite" else 1.2) / fury
			if boss.t > wind:
				boss.state = boss.next
				boss.t = 0.0
				boss.hit = false
				_sfx("fire_breath" if boss.next == "breath" else "dragon_roar", 0 if boss.next == "breath" else -6)
		"bite":
			boss.mouth.light_energy = 0.5
			if not boss.hit and boss.t > 0.15:
				boss.hit = true
				var fwd := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y))
				if dist < 6.0 and fwd.angle_to(to.normalized()) < 0.8:
					_hurt_player(45.0 * fury, "Mordida do Dragão")
			if boss.t > 1.0 / fury:
				boss.state = "chase"
				boss.t = 0.0
		"breath":
			boss.mouth.light_energy = 9.0
			var fwd2 := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y))
			if int(boss.t * 10) % 3 == 0 and dist < 10.0 and fwd2.angle_to(to.normalized()) < 0.5:
				_hurt_player(14.0 * fury, "Sopro de Fogo")
			if boss.t > 1.6:
				boss.mouth.light_energy = 0.0
				boss.state = "chase"
				boss.t = 0.0

# ------------------------------------------------------------------ Seed of Fire
func _throw_fireball() -> void:
	var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(1, 0.45, 0.1)
	m.emission_energy_multiplier = 6
	m.albedo_color = Color(1, 0.6, 0.2)
	ball.material_override = m
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.5, 0.15)
	l.light_energy = 2.5
	l.omni_range = 5
	ball.add_child(l)
	ball.position = player.position + Vector3(0, 1.3, 0) + fwd * 0.8
	add_child(ball)
	fireballs.append({"node": ball, "vel": fwd * 14.0, "t": 1.5})
	_sfx("fireball", 0)

func _update_fireballs(dt: float) -> void:
	for f in fireballs.duplicate():
		f.t -= dt
		var n: Node3D = f.node
		n.position += f.vel * dt
		var hit := false
		for e in enemies:
			if not e.dead and n.position.distance_to(e.root.position + Vector3(0, 1, 0)) < 1.2:
				_damage_enemy(e, {"dmg": 55.0, "poise": 20.0})
				hit = true
		if boss != null and not boss.dead and n.position.distance_to(boss.root.position + Vector3(0, 2.5, 0)) < 3.0:
			_damage_boss(70.0)
			hit = true
		if hit or f.t <= 0:
			n.queue_free()
			fireballs.erase(f)

# ------------------------------------------------------------------ camera
func _update_camera(dt: float) -> void:
	if lock_target != null:
		var to: Vector3 = lock_target.root.position - player.position
		cam_yaw = lerp_angle(cam_yaw, atan2(-to.x, -to.z), 0.08)
	cam_pivot.position = player.position + Vector3(0, 1.6, 0)
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	camera.h_offset = randf_range(-shake, shake) * 0.15
	camera.v_offset = randf_range(-shake, shake) * 0.15

func _input(event: InputEvent) -> void:
	var vs := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > vs.x * 0.45 and not _on_button(event.position, vs):
			cam_touch = event.index
		elif not event.pressed and event.index == cam_touch:
			cam_touch = -1
	elif event is InputEventScreenDrag and event.index == cam_touch:
		cam_yaw -= event.relative.x * 0.006
		cam_pitch = clamp(cam_pitch - event.relative.y * 0.004, -0.9, 0.2)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_yaw -= event.relative.x * 0.006
		cam_pitch = clamp(cam_pitch - event.relative.y * 0.004, -0.9, 0.2)

func _on_button(pos: Vector2, vs: Vector2) -> bool:
	for a in buttons:
		if pos.distance_to(_button_pos(a, vs)) < _button_r(a) + 10:
			return true
	return false

# ------------------------------------------------------------------ autoplay (screenshots only)
var auto_t := 0.0
func _autoplay_vec() -> Vector2:
	var target = null
	var bd := 100.0
	for e in enemies:
		if not e.dead and e.root.position.distance_to(player.position) < bd:
			bd = e.root.position.distance_to(player.position)
			target = e
	if target == null and boss != null and not boss.dead:
		target = boss
	if target == null:
		return Vector2.ZERO
	var to: Vector3 = target.root.position - player.position
	if to.length() < (4.0 if target == boss else 1.8):
		return Vector2.ZERO
	var d := _cam_basis_dirs()
	var n := to.normalized()
	return Vector2(n.dot(d[1]), -n.dot(d[0]))

func _autoplay_press(action: String) -> bool:
	auto_block = max(0.0, auto_block - 1.0 / 60.0)
	match action:
		"attack": return randf() < 0.09
		"roll": return randf() < 0.012
		"seed": return randf() < 0.01
		"flask": return hp < 60 and randf() < 0.05
		"lock": return lock_target == null and randf() < 0.01
		"weapon": return randf() < 0.004
		"block":
			if randf() < 0.01:
				auto_block = 1.0
			return false
	return false

# ------------------------------------------------------------------ audio
func _build_audio() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	music_amb = _music("dungeon_ambience.ogg", -8.0)
	music_boss = _music("boss_battle_metal.mp3", -80.0)
	music_amb.play()

func _music(file: String, db: float) -> AudioStreamPlayer:
	var st = load("res://assets/music/" + file)
	st.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	add_child(p)
	return p

func _fade(p: AudioStreamPlayer, db: float, sec: float) -> void:
	if db > -60 and not p.playing:
		p.play()
	create_tween().tween_property(p, "volume_db", db, sec)

func _sfx(name, db := 0.0) -> void:
	var n: String = name.pick_random() if name is Array else name
	if not sfx_cache.has(n):
		sfx_cache[n] = load("res://assets/sfx/%s.ogg" % n)
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_cache[n]
			p.volume_db = db
			p.pitch_scale = randf_range(0.93, 1.07)
			p.play()
			return

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	ui_draw = Control.new()
	ui_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_draw.draw.connect(_draw_ui)
	ui.add_child(ui_draw)
	joystick = ClassDB.instantiate("VirtualJoystick")
	joystick.set("joystick_mode", 1)
	joystick.set("action_left", "move_left")
	joystick.set("action_right", "move_right")
	joystick.set("action_up", "move_up")
	joystick.set("action_down", "move_down")
	joystick.set("joystick_size", 230)
	joystick.set("tip_size", 100)
	ui.add_child(joystick)
	for a in ["attack", "roll", "lock", "seed", "flask", "block", "level", "weapon"]:
		var b := TouchScreenButton.new()
		var s := CircleShape2D.new()
		s.radius = _button_r(a)
		b.shape = s
		b.shape_centered = true
		b.action = a
		ui.add_child(b)
		buttons[a] = b
	get_tree().root.size_changed.connect(_layout_ui)
	_layout_ui()

func _button_r(a: String) -> float:
	match a:
		"attack": return 115.0
		"lock", "level", "weapon": return 62.0
	return 78.0

func _button_pos(a: String, vs: Vector2) -> Vector2:
	match a:
		"attack": return Vector2(vs.x - 200, vs.y - 200)
		"roll": return Vector2(vs.x - 420, vs.y - 110)
		"block": return Vector2(vs.x - 420, vs.y - 300)
		"seed": return Vector2(vs.x - 320, vs.y - 460)
		"flask": return Vector2(vs.x - 140, vs.y - 430)
		"lock": return Vector2(vs.x - 110, vs.y - 600)
		"weapon": return Vector2(vs.x - 260, vs.y - 640)
		"level": return Vector2(vs.x * 0.5, vs.y - 120)
	return Vector2.ZERO

func _layout_ui() -> void:
	var vs := get_viewport().get_visible_rect().size
	joystick.position = Vector2(0, vs.y * 0.3)
	joystick.size = Vector2(vs.x * 0.4, vs.y * 0.7)
	for a in buttons:
		buttons[a].position = _button_pos(a, vs)

func _float(text: String, pos: Vector3, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 1.0, "col": col})

func _show_banner(text: String, sub: String, col: Color, t: float) -> void:
	banner = text
	banner_sub = sub
	banner_col = col
	banner_t = t

func _draw_ui() -> void:
	var vs := get_viewport().get_visible_rect().size
	var font := ThemeDB.fallback_font
	for f in floaters:
		if camera.is_position_behind(f.pos):
			continue
		var sp := camera.unproject_position(f.pos)
		ui_draw.draw_string_outline(font, sp - Vector2(150, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 34, 8, Color(0, 0, 0, f.t))
		ui_draw.draw_string(font, sp - Vector2(150, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 34, Color(f.col, f.t))
	if lock_target != null and not camera.is_position_behind(lock_target.root.position):
		var lp := camera.unproject_position(lock_target.root.position + Vector3(0, 1.3 if lock_target != boss else 3.5, 0))
		ui_draw.draw_circle(lp, 9, Color(1, 1, 1, 0.9))
		ui_draw.draw_arc(lp, 18, 0, TAU, 24, Color(1, 1, 1, 0.6), 2)
	# HP and stamina, souls style
	ui_draw.draw_rect(Rect2(40, 34, max_hp * 3.2, 22), Color(0.1, 0, 0, 0.7))
	ui_draw.draw_rect(Rect2(40, 34, hp * 3.2, 22), Color(0.65, 0.08, 0.08))
	ui_draw.draw_rect(Rect2(40, 64, max_stamina * 3.2, 14), Color(0, 0.08, 0, 0.7))
	ui_draw.draw_rect(Rect2(40, 64, max(0.0, stamina) * 3.2, 14), Color(0.25, 0.6, 0.25))
	ui_draw.draw_rect(Rect2(40, 84, 100 * 2.4, 10), Color(0, 0, 0.1, 0.7))
	ui_draw.draw_rect(Rect2(40, 84, essence * 2.4, 10), Color(0.25, 0.45, 0.95))
	_text("Nível %d   Frascos %d/%d" % [level, flasks, max_flasks], Vector2(40, 132), 28, Color(0.9, 0.8, 0.6))
	if player.position.distance_to(BONFIRE_POS) < 3.0:
		_text("Próximo nível: %d brasas" % (150 * level), Vector2(vs.x * 0.5 - 170, vs.y - 200), 28, Color(1, 0.8, 0.5))
	for e in enemies:
		if e.dead or e.hp >= e.max or camera.is_position_behind(e.root.position):
			continue
		var ep := camera.unproject_position(e.root.position + Vector3(0, 2.3, 0))
		ui_draw.draw_rect(Rect2(ep - Vector2(50, 0), Vector2(100, 8)), Color(0, 0, 0, 0.6))
		ui_draw.draw_rect(Rect2(ep - Vector2(50, 0), Vector2(100 * e.hp / e.max, 8)), Color(0.75, 0.1, 0.1))
		ui_draw.draw_rect(Rect2(ep - Vector2(50, -10), Vector2(100 * e.poise / e.max_poise, 4)), Color(1, 0.8, 0.3) if e.state != "broken" else Color(1, 0.2, 0.2))
	_text("%d" % embers, Vector2(vs.x - 220, 60), 40, Color(1, 0.75, 0.4))
	_text("brasas", Vector2(vs.x - 220, 92), 22, Color(0.8, 0.6, 0.4))
	if dragon_seed:
		_text("Semente do Dragão", Vector2(vs.x - 330, 130), 26, Color(1, 0.55, 0.15))
	if boss != null and boss.awake and not boss.dead:
		var w := vs.x * 0.55
		var x0 := (vs.x - w) / 2
		_text("Dragão Guardião", Vector2(x0, vs.y - 92), 30, Color(0.95, 0.9, 0.8))
		ui_draw.draw_rect(Rect2(x0, vs.y - 80, w, 16), Color(0.1, 0, 0, 0.7))
		ui_draw.draw_rect(Rect2(x0, vs.y - 80, w * boss.hp / boss.max, 16), Color(0.6, 0.1, 0.05))
	for a in buttons:
		var pos := _button_pos(a, vs)
		var r := _button_r(a)
		if a == "level" and player.position.distance_to(BONFIRE_POS) > 3.0:
			continue
		var label: String = {"attack": "ATACAR", "roll": "ROLAR", "lock": "MIRA", "seed": "FOGO", "flask": "FRASCO", "block": "DEFESA", "level": "NÍVEL", "weapon": "ARMA"}[a]
		var col := Color(1, 0.55, 0.2) if a == "seed" else Color(1, 1, 1)
		ui_draw.draw_circle(pos, r, Color(col, 0.28 if Input.is_action_pressed(a) else 0.12))
		ui_draw.draw_arc(pos, r, 0, TAU, 48, Color(col, 0.6), 3)
		if a == "seed" and essence < 30:
			ui_draw.draw_circle(pos, r, Color(0, 0, 0, 0.5))
		ui_draw.draw_string_outline(font, pos - Vector2(r, -10), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 28, 6, Color(0, 0, 0, 0.8))
		ui_draw.draw_string(font, pos - Vector2(r, -10), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 28, Color(1, 1, 1, 0.9))
	if banner_t > 0:
		var a: float = minf(1.0, banner_t)
		ui_draw.draw_rect(Rect2(0, vs.y * 0.38, vs.x, 150), Color(0, 0, 0, 0.45 * a))
		ui_draw.draw_string_outline(font, Vector2(0, vs.y * 0.38 + 80), banner, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 72, 10, Color(0, 0, 0, a))
		ui_draw.draw_string(font, Vector2(0, vs.y * 0.38 + 80), banner, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 72, Color(banner_col, a))
		ui_draw.draw_string(font, Vector2(0, vs.y * 0.38 + 128), banner_sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, Color(0.9, 0.9, 0.9, a))

func _text(s: String, pos: Vector2, size: int, col: Color) -> void:
	ui_draw.draw_string_outline(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8))
	ui_draw.draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
