# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is a dark 3D souls-like fight (stamina, roll, lock-on, Seed spell) fun on a phone?
# Date: 2026-10-21
extends Node3D

const HeroLook = preload("res://hero_look.gd")
const HeroAnims = preload("res://hero_anims.gd")

const Level = preload("res://level.gd")
const Rpg = preload("res://rpg.gd")
const Menu = preload("res://menu.gd")
const World = preload("res://world.gd")
const QRig = preload("res://qrig.gd")
const Npcs = preload("res://npcs.gd")
const Dialog = preload("res://dialog.gd")
const BOSS_HOME := Vector3(0, 0, -26)
const ANIMS := {
	"idle": "sword_and_shield_idle", "idle2": "sword_and_shield_idle_2", "run": "sword_and_shield_run",
	"walk": "sword_and_shield_walk", "walk_back": "sword_and_shield_walk_2",
	"strafe_r": "sword_and_shield_strafe", "strafe_l": "sword_and_shield_strafe_2",
	"roll": "stand_to_roll", "hit1": "sword_and_shield_impact", "hit2": "sword_and_shield_impact_2",
	"hit3": "sword_and_shield_impact_3", "death": "sword_and_shield_death", "death2": "sword_and_shield_death_2",
	"block_idle": "sword_and_shield_block_idle", "block_hit": "sword_and_shield_block", "jump": "sword_and_shield_jump",
	"draw": "sheath_sword_1",
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
# x_* clips are hand-made in hero_anims.gd (same hit times there); g* moves still use Mixamo clips
const MOVES := {
	"c1": {"anim": "x_slash1", "speed": 1.0, "hit": 0.4, "end": 0.8, "dmg": 28, "poise": 12, "stamina": 16, "reach": 2.4, "arc": 1.2, "lunge": 1.8},
	"c2": {"anim": "x_slash2", "speed": 1.0, "hit": 0.36, "end": 0.75, "dmg": 30, "poise": 12, "stamina": 16, "reach": 2.4, "arc": 1.2, "lunge": 1.8},
	"c3": {"anim": "x_slash3", "speed": 1.0, "hit": 0.42, "end": 0.85, "dmg": 32, "poise": 14, "stamina": 17, "reach": 2.5, "arc": 1.3, "lunge": 2.0},
	"c4": {"anim": "x_thrust", "speed": 1.0, "hit": 0.48, "end": 1.0, "dmg": 46, "poise": 26, "stamina": 22, "reach": 2.8, "arc": 1.6, "lunge": 3.5},
	"heavy": {"anim": "x_heavy", "speed": 1.0, "hit": 0.7, "end": 1.25, "dmg": 58, "poise": 36, "stamina": 30, "reach": 2.6, "arc": 1.0, "lunge": 1.0},
	"run_atk": {"anim": "x_run_atk", "speed": 1.0, "hit": 0.44, "end": 1.0, "dmg": 48, "poise": 30, "stamina": 24, "reach": 2.8, "arc": 1.1, "lunge": 5.0},
	"roll_atk": {"anim": "x_roll_atk", "speed": 1.0, "hit": 0.28, "end": 0.7, "dmg": 38, "poise": 20, "stamina": 20, "reach": 2.6, "arc": 1.2, "lunge": 4.0},
	"kick": {"anim": "x_bash", "speed": 1.0, "hit": 0.36, "end": 0.65, "dmg": 12, "poise": 45, "stamina": 14, "reach": 2.0, "arc": 0.9, "lunge": 1.2},
	"riposte": {"anim": "x_riposte", "speed": 1.0, "hit": 0.72, "end": 1.4, "dmg": 140, "poise": 0, "stamina": 10, "reach": 2.8, "arc": 1.4, "lunge": 2.5},
	"c6": {"anim": "x_roll_atk", "speed": 1.0, "hit": 0.28, "end": 0.7, "dmg": 34, "poise": 18, "stamina": 18, "reach": 2.6, "arc": 1.2, "lunge": 2.5},
	"c5": {"anim": "x_spin", "speed": 1.0, "hit": 0.46, "end": 1.0, "dmg": 40, "poise": 22, "stamina": 18, "reach": 2.6, "arc": 3.2, "lunge": 2.2},
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
# after the last hit, every swing that LANDED lets the next press keep going with a different move
const CHAIN := ["c1", "c2", "c3", "c4", "c5", "c6"]
const CHAIN_G := ["g1", "g2", "g3", "g4"]
const COMBO_G := ["g1", "g2", "g3", "g4"]
# Seeds of power: FOGO casts the current one, TROCAR cycles
const SEEDS := {
	"fogo": {"name": "FOGO", "cost": 30.0, "col": Color(1, 0.55, 0.2)},
	"gelo": {"name": "GELO", "cost": 25.0, "col": Color(0.55, 0.85, 1.0)},
	"raio": {"name": "RAIO", "cost": 35.0, "col": Color(1.0, 0.95, 0.5)},
}
# loot: [name, colour, stat factor]; names per slot follow the same rarity order
const RARITY := [["Comum", Color(0.75, 0.75, 0.75), 1.0], ["Raro", Color(0.35, 0.6, 1.0), 1.6],
	["Épico", Color(0.75, 0.35, 1.0), 2.4], ["Lendário", Color(1.0, 0.6, 0.1), 3.6]]
const ITEMS := {
	"sword": {"names": ["Espada Enferrujada", "Lâmina do Juramento", "Fio da Cinza", "Presa do Dragão"], "base": 6.0, "fmt": "+%d%% dano (espada)"},
	"great": {"names": ["Espadão Rachado", "Montante do Guardião", "Cutelo das Brasas", "Ira do Wyrm"], "base": 6.0, "fmt": "+%d%% dano (espadão)"},
	"ring": {"names": ["Anel de Osso", "Anel do Cavaleiro", "Anel da Seiva", "Anel do Primeiro Fogo"], "base": 12.0, "fmt": "+%d vida máxima"},
	"amulet": {"names": ["Amuleto Gasto", "Amuleto Rúnico", "Coração de Brasa", "Olho do Dragão"], "base": 10.0, "fmt": "+%d%% dano das Sementes"},
}

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
var max_flasks := 3
var cls := "cavaleiro"  # starting class (rpg.gd)
var attrs := Rpg.class_attrs("cavaleiro")
var talents := {}  # learnt talent ids
var stats := {}  # derived from attrs and talents by _recalc()
var upgrades := {"sword": 0, "great": 0}  # weapon reinforcement +0..+5
var titanite := 0  # second currency: reinforcement material
var kills := 0
var sentinels_dead := false
var boss_kills := 0
var bonus_hp := 0.0  # permanent max-HP rewards
var max_essence := 100.0
var shards_found := 0
var poison_t := 0.0
var buff_t := 0.0  # Esquiva Perfeita
var menu: Control
var world: Node3D  # world.gd: the streamed 10 km world around the valley
var npcs: Node  # npcs.gd: people you can talk to
var dialog: Control
var smith_open := false  # talking to the smith: reinforce without a bonfire
var free_points := 0  # attribute points returned by a respec
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
var interacts: Array = []  # {pos, r, label, do}
var elevator: AnimatableBody3D
var elevator_open := false
var elevator_t := 0.0
var elevator_moving := false
var bells := 0
var climbing := false
var bonfires: Array = []  # [pos, name]
var bonfire_pos := Vector3.ZERO  # last bonfire rested at
var lit := {}  # bonfire names already lit
var breakables: Array = []
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
var landed := false  # did the current swing hit something
var chain := 0  # moves chained past the scripted combo
var combo_step := 0
var hit_done := false
var roll_dir := Vector3.ZERO
var lock_target = null
var seed_cd := 0.0
var dropped_embers := 0
var dropped_marker: Node3D
var invuln_t := 0.0

var enemies: Array = []
var boss = null  # the boss nearest the player; every boss function works on this one
var bosses: Array = []
var meteors: Array = []
var fireballs: Array = []
var bolts: Array = []  # casters' ghost-fire bolts
var floaters: Array = []
var stone_mat: StandardMaterial3D
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
var seeds := ["fogo"]
var seed_i := 0
var seed_marks: Array = []  # [node, spot]
var region := ""
var gear := {}  # slot -> item {slot, rarity, name, val}
var loot: Array = []  # [node, item]
var sfx_players: Array = []
var sfx_cache := {}
var music_amb: AudioStreamPlayer
var music_boss: AudioStreamPlayer
var step_t := 0.0

func _ready() -> void:
	randomize()
	stone_mat = _pbr("castle_wall_slates", 1.0)
	_build_world()
	world = World.new()
	add_child(world)
	world.setup(self)
	_build_player()
	_update_camera(0.0)
	_recalc()
	hp = max_hp
	stamina = max_stamina
	essence = max_essence
	for sp in Level.SPAWNS:
		_spawn_enemy(sp[0], sp[1])
	for i in Level.SHARDS.size():
		shards.append(_glow_marker(Level.SHARDS[i], Color(0.4, 1.0, 0.5)))
		shards[-1].set_meta("spot", i)
	_spawn_breakables()
	_build_elevator()
	npcs = Npcs.new()
	add_child(npcs)
	_build_ui()
	npcs.setup(self)
	_build_audio()
	for l in find_children("*", "OmniLight3D", true, false):
		l.distance_fade_enabled = true
		l.distance_fade_begin = 35.0
		l.distance_fade_length = 10.0
	if not autoplay:  # the playtest robot always starts fresh and never overwrites a save
		_build_title()

# ------------------------------------------------------------------ save
const SAVE_PATH := "user://sementes_save.json"

func _save() -> void:
	if autoplay:
		return
	var d := {
		"level": level, "max_flasks": max_flasks, "cls": cls, "attrs": attrs, "talents": talents.keys(), "upgrades": upgrades,
		"titanite": titanite, "kills": kills, "sentinels_dead": sentinels_dead, "boss_kills": boss_kills, "bonus_hp": bonus_hp,
		"shards_found": shards_found, "free_points": free_points, "found": world.found.keys(),
		"embers": embers, "dropped_embers": dropped_embers, "seeds": seeds, "seed_i": seed_i, "dragon_seed": dragon_seed,
		"gear": gear, "lit": lit.keys(), "elevator_open": elevator_open, "bells": bells,
		"bonfire": [bonfire_pos.x, bonfire_pos.y, bonfire_pos.z],
		"dropped_at": [dropped_marker.position.x, dropped_marker.position.y, dropped_marker.position.z] if dropped_marker != null else [],
		"bosses_dead": bosses.filter(func(b): return b.dead).map(func(b): return b.kind),
		"shards_left": shards.map(func(n): return n.get_meta("spot")),
		"seeds_left": seed_marks.map(func(m): return m[1][2]),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary:
		return  # unreadable save: start a new game rather than crash
	level = int(d.level)
	max_flasks = int(d.max_flasks)
	cls = d.get("cls", "cavaleiro")
	attrs = Rpg.class_attrs(cls)
	if d.has("attrs"):
		for a in Rpg.ATTRS:
			attrs[a] = int(d.attrs[a])
	else:  # saves from before attributes: spread the levels already bought
		for i in level - 1:
			attrs[Rpg.ATTRS[i % Rpg.ATTRS.size()]] += 1
	talents = {}
	for t in d.get("talents", []):
		talents[t] = true
	for w in d.get("upgrades", {}):
		upgrades[w] = int(d.upgrades[w])
	titanite = int(d.get("titanite", 0))
	kills = int(d.get("kills", 0))
	sentinels_dead = d.get("sentinels_dead", false)
	boss_kills = int(d.get("boss_kills", 0))
	bonus_hp = float(d.get("bonus_hp", 0.0))
	shards_found = int(d.get("shards_found", 0))
	free_points = int(d.get("free_points", 0))
	for n in d.get("found", []):
		world.found[n] = true
	embers = int(d.embers)
	seeds = d.seeds
	seed_i = clampi(int(d.seed_i), 0, seeds.size() - 1)
	dragon_seed = d.dragon_seed
	weapon = "sword"
	gear = {}
	for slot in d.gear:
		var it: Dictionary = d.gear[slot]
		it.rarity = int(it.rarity)
		gear[slot] = it
	for n in d.lit:
		lit[n] = true
	elevator_open = d.get("elevator_open", false)
	bells = int(d.get("bells", 0))
	bonfire_pos = Vector3(d.bonfire[0], d.bonfire[1], d.bonfire[2])
	if d.dropped_at.size() == 3 and int(d.dropped_embers) > 0:
		dropped_embers = int(d.dropped_embers)
		dropped_marker = _glow_marker(Vector3(d.dropped_at[0], d.dropped_at[1], d.dropped_at[2]), Color(1, 0.5, 0.1))
	for b in bosses:
		if b.kind in d.bosses_dead:
			b.dead = true
			b.root.visible = false
	for n in shards.duplicate():
		if not int(n.get_meta("spot")) in d.shards_left.map(func(x): return int(x)):
			shards.erase(n)
			n.queue_free()
	for m in seed_marks.duplicate():
		if not m[1][2] in d.seeds_left:
			seed_marks.erase(m)
			m[0].queue_free()
	_recalc()
	hp = max_hp
	stamina = max_stamina
	essence = max_essence
	flasks = max_flasks
	player.position = bonfire_pos + Vector3(0, 0.5, -2.5)
	_show_banner("BEM-VINDO DE VOLTA", "Nível %d  ·  %d brasas" % [level, embers], Color(0.95, 0.85, 0.65), 3.0)

# title card: the world is built and paused behind it
func _build_title() -> void:
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)
	ui.visible = false
	var title := Label.new()
	title.text = "SEMENTES DO DRAGÃO"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Sombra e Chama"
	sub.add_theme_font_size_override("font_size", 40)
	sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var has_save := FileAccess.file_exists(SAVE_PATH)
	for b in ([["CONTINUAR", true]] if has_save else []) + [["NOVO JOGO", false]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(520, 110)
		btn.add_theme_font_size_override("font_size", 46)
		btn.pressed.connect(func():
			if b[1]:
				_load()
				layer.queue_free()
				ui.visible = true
				get_tree().paused = false
			else:
				_class_choice(layer, box))
		box.add_child(btn)

# new game: pick a starting class, then the world unpauses
func _class_choice(layer: CanvasLayer, box: VBoxContainer) -> void:
	for c in box.get_children():
		if c is Button:
			c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	for k in Rpg.CLASSES:
		var c: Dictionary = Rpg.CLASSES[k]
		var btn := Button.new()
		var a: Dictionary = c.attrs
		btn.text = "%s\n\n%s\n\nVig %d  Fôl %d  For %d\nDes %d  Int %d" % [c.name.to_upper(), c.desc, a.vig, a.fol, a["for"], a.des, a.int]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(440, 380)
		btn.add_theme_font_size_override("font_size", 32)
		btn.pressed.connect(func():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			cls = k
			attrs = Rpg.class_attrs(k)
			max_flasks = c.flasks
			flasks = max_flasks
			_recalc()
			hp = max_hp
			stamina = max_stamina
			essence = max_essence
			_show_banner("SANTUÁRIO DA CHAMA", "%s · siga a escadaria até o Burgo" % c.name, Color(0.95, 0.85, 0.65), 3.5)
			layer.queue_free()
			ui.visible = true
			get_tree().paused = false)
		row.add_child(btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()

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
	# night sky with an ember-lit horizon (the volcano), instead of a black void
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.025, 0.05)
	sky_mat.sky_horizon_color = Color(0.2, 0.11, 0.1)
	sky_mat.ground_horizon_color = Color(0.12, 0.07, 0.07)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.015)
	sky_mat.sun_angle_max = 3.0
	sky_mat.sun_curve = 0.3
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.32, 0.42)
	e.ambient_light_energy = 0.8
	e.fog_enabled = true
	e.fog_light_color = Color(0.07, 0.055, 0.07)
	e.fog_density = 0.007
	e.fog_sky_affect = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, 150, 0)
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 25
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # one shadow pass instead of four
	add_child(moon)
	Level.build(self)

# places a model from assets/<path>.glb scaled to height h; tint darkens its own material, mat replaces it
func _place(path: String, pos: Vector3, h: float, tint: Color, mat: Material = null, rot_y := -1.0) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var n: Node3D = load("res://assets/%s.glb" % path).instantiate()
	holder.add_child(n)
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if str(m.name).ends_with("_collider") or m.name == &"Logo":  # collision hulls and a brand decal
			m.visible = false
			continue
		var xf := Transform3D()  # mesh -> model root; global_transform is not up to date during _ready
		var p: Node = m
		while p != n:
			xf = p.transform * xf
			p = p.get_parent()
		var a: AABB = xf * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
		for i in m.mesh.get_surface_count():
			if mat != null:
				m.set_surface_override_material(i, mat)
			elif m.mesh.surface_get_material(i) is StandardMaterial3D:
				var d: StandardMaterial3D = m.mesh.surface_get_material(i).duplicate()
				d.albedo_color *= tint
				m.set_surface_override_material(i, d)
	var k := h / box.size.y if box.size.y > 0.01 else 1.0
	n.scale = Vector3.ONE * k
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	holder.position = pos
	holder.rotation.y = randf() * TAU if rot_y < 0 else rot_y
	return holder

func _static_box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.position = pos + Vector3(0, size.y / 2, 0)
	body.add_child(cs)
	add_child(body)

# pots, jars and barrels: break with an attack or a roll, drop a few embers, back at the bonfire
func _spawn_breakables() -> void:
	for b in breakables:
		if is_instance_valid(b.node):
			b.node.queue_free()
	breakables.clear()
	for sp in Level.BREAKABLES:
		var n := _place("pm/" + sp[1], sp[0], sp[2], Color(0.5, 0.45, 0.42), null)
		breakables.append({"node": n, "pos": sp[0], "wood": sp[1].contains("Barrel")})

func _break(b: Dictionary) -> void:
	breakables.erase(b)
	var n: Node3D = b.node
	var bits := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.12) if b.wood else Color(0.35, 0.3, 0.27)
	bm.material = mat
	bits.mesh = bm
	bits.one_shot = true
	bits.emitting = true
	bits.amount = 18
	bits.lifetime = 0.9
	bits.explosiveness = 1.0
	bits.direction = Vector3.UP
	bits.spread = 70
	bits.initial_velocity_min = 2.0
	bits.initial_velocity_max = 4.5
	bits.gravity = Vector3(0, -12, 0)
	bits.position = b.pos + Vector3(0, 0.4, 0)
	add_child(bits)
	get_tree().create_timer(1.2).timeout.connect(bits.queue_free)
	n.queue_free()
	_sfx(["impactWood_medium_001", "impactWood_medium_002"] if b.wood else ["impactGlass_heavy_000", "impactGlass_heavy_001", "impactGlass_heavy_002"], -2)
	var r := randi_range(3, 12)
	embers += r
	_float("+%d brasas" % r, b.pos + Vector3(0, 1.4, 0), Color(1, 0.7, 0.3))
	if flasks < max_flasks and randf() < 0.12:
		flasks += 1
		_float("+1 frasco", b.pos + Vector3(0, 1.9, 0), Color(0.6, 1, 0.6))

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
	HeroAnims.add_to(lib, ap.get_node(ap.root_node).get_node("Skeleton3D"))
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
	player.position = bonfire_pos + Vector3(0, 0.5, -2.5)
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
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	_load_anims(anim)
	HeroLook.dress(model)
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
	var fill := OmniLight3D.new()  # from the camera's side, so the dark knight never reads as a black silhouette
	fill.position = Vector3(0, 0.6, 1.8)
	fill.light_color = Color(1.0, 0.85, 0.7)
	fill.light_energy = 0.8
	fill.omni_range = 5.0
	cam_pivot.add_child(fill)
	spring = SpringArm3D.new()
	spring.spring_length = 4.2
	spring.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.3  # a ray slips past wall edges and lets the camera see inside them
	spring.shape = probe
	spring.collision_mask = 1 | 2  # layer 2: camera-only colliders (rock masses under the platforms)
	spring.add_excluded_object(player.get_rid())
	spring.process_mode = Node.PROCESS_MODE_ALWAYS  # the title card pauses the world: still frame the shrine behind it
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 65
	camera.far = 320
	spring.add_child(camera)

func _dark_cloth() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.05, 0.04)
	m.roughness = 0.9
	return m

# our own models on the KayKit rig (tools/make_foes.py), so the KayKit clips still play; data in Rpg.FOES
var foe_mat: StandardMaterial3D

func _skeleton_model(kind: String) -> Node3D:
	if Rpg.FOES[kind].ai == "wolf":
		return _wolf_model()
	var f: Dictionary = Rpg.FOES[kind]
	if f.get("rig", "") == "q":
		return _q_model(f)
	var k: Node3D = load("res://assets/foes/%s.glb" % f.model).instantiate()
	k.scale = Vector3.ONE * f.scale
	var skel: Skeleton3D = k.find_children("*", "Skeleton3D", true, false)[0]
	for g in f.gear:
		var ba := BoneAttachment3D.new()
		ba.bone_name = g[0]
		skel.add_child(ba)
		ba.add_child(load("res://assets/foes/w_%s.glb" % g[1]).instantiate())
	if foe_mat == null:
		foe_mat = StandardMaterial3D.new()
		foe_mat.vertex_color_use_as_albedo = true  # colours are baked per face, so a foe is one draw call
		foe_mat.roughness = 0.8
	for m in k.find_children("*", "MeshInstance3D", true, false):
		m.material_override = foe_mat
	return k

# a Quaternius character (qrig.gd) with its weapons in the right hand bone
var Q_HAND := Transform3D(Basis.from_euler(Vector3(PI / 2.0, 0, 0)), Vector3(0.0, 0.08, 0.0))  # weapon in the mannequin hand_r frame
func _q_model(f: Dictionary) -> Node3D:
	var r: Array = QRig.instance("res://assets/qchars/" + f.model, f.get("shamble", false), f.get("head", ""), f.get("hair", ""))
	var k: Node3D = r[0]
	k.scale = Vector3.ONE * f.scale
	var skel: Skeleton3D = k.find_children("*", "Skeleton3D", true, false)[0]
	for g in f.gear:
		var ba := BoneAttachment3D.new()
		ba.bone_name = g[0]
		skel.add_child(ba)
		var w: Node3D = load("res://assets/foes/w_%s.glb" % g[1]).instantiate()
		w.transform = Q_HAND
		ba.add_child(w)
		if foe_mat == null:
			foe_mat = StandardMaterial3D.new()
			foe_mat.vertex_color_use_as_albedo = true
			foe_mat.roughness = 0.8
		for m in w.find_children("*", "MeshInstance3D", true, false):
			m.material_override = foe_mat
	return k

# Quaternius wolf (CC0), recoloured ash-grey, scaled to 0.85 m at the shoulder
func _wolf_model() -> Node3D:
	var holder := Node3D.new()
	var w: Node3D = load("res://assets/beasts/wolf.fbx").instantiate()
	holder.add_child(w)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.16, 0.15, 0.15)
	fur.roughness = 0.95
	var box := AABB()
	for m in w.find_children("*", "MeshInstance3D", true, false):
		m.material_override = fur
		var xf := Transform3D()
		var p: Node = m
		while p != w:
			xf = p.transform * xf
			p = p.get_parent()
		box = xf * m.get_aabb()
	# shortcut: the skinned mesh's bind AABB is ~3.4x smaller than the posed wolf; measured by eye, not computed
	w.scale = Vector3.ONE * 0.85 / box.size.y * 3.4
	return holder

func _spawn_enemy(pos: Vector3, kind := "warrior") -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = randf() * TAU
	add_child(root)
	var k := _skeleton_model(kind)
	root.add_child(k)
	var eye := OmniLight3D.new()
	eye.position = Vector3(0, 1.7, 0.25)
	eye.light_color = Color(0.3, 0.8, 1.0) if Rpg.FOES[kind].ai == "caster" else Color(1, 0.1, 0.05)
	if Rpg.FOES[kind].ai == "wolf":
		eye.position = Vector3(0, 0.75, 0.6)
	eye.light_energy = 0.0
	eye.visible = false  # lights are expensive on phones: on only for a nearby attack tell (see _cull)
	eye.omni_range = 1.8
	root.add_child(eye)
	var ap: AnimationPlayer = k.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("WolfArmature|Idle" if Rpg.FOES[kind].ai == "wolf" else "Skeletons_Inactive_Floor_Pose")
	var hpv: float = Rpg.FOES[kind].hp
	var poise: float = Rpg.FOES[kind].poise
	enemies.append({"root": root, "ap": ap, "eye": eye, "kind": kind, "ai": Rpg.FOES[kind].ai, "hp": hpv, "max": hpv, "poise": poise, "max_poise": poise,
		"home": pos, "state": "dormant", "t": 0.0, "hit": false, "dead": false, "atk": "", "wind_pos": 0.0, "leap": false,
		"model": k, "combo": false, "side": 1.0, "dodge": Vector3.ZERO, "revive_t": -1.0, "revived": false, "cast_cd": 2.0})

# dragon model with the "d" library (idle, walk, attack, die); returns [model, AnimationPlayer]
func _dragon_model(size: float, tex: String) -> Array:
	var d: Node3D = load("res://assets/dragon/dragon.dae").instantiate()
	d.scale = Vector3.ONE * size
	d.position.y = size * 0.37
	d.rotation.y = PI
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = load("res://assets/dragon/%s.png" % tex)
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
	return [d, ap]

func _spawn_boss(home: Vector3, size: float, tint: Color, hpmax: float, title: String, kind: String) -> void:
	var root := Node3D.new()
	root.position = home
	add_child(root)
	var dr := _dragon_model(size, "dragon")
	root.add_child(dr[0])
	for m in dr[0].find_children("*", "MeshInstance3D", true, false):
		m.material_override.albedo_color = tint
	var ap: AnimationPlayer = dr[1]
	var mouth := OmniLight3D.new()
	mouth.position = Vector3(0, 3.5, 3.5) * size / 6.5
	mouth.light_color = Color(1, 0.4, 0.05)
	mouth.light_energy = 0.0
	mouth.omni_range = 10
	root.add_child(mouth)
	bosses.append({"root": root, "ap": ap, "mouth": mouth, "hp": hpmax, "max": hpmax, "state": "idle", "t": 0.0, "hit": false, "dead": false,
		"awake": false, "next": "bite", "phase": 1, "home": home, "k": size / 6.5, "name": title, "kind": kind})

# ------------------------------------------------------------------ loop
# phones: far enemies are hidden and not animated, eye lights only for a nearby attack tell, far lights fade out
func _cull() -> void:
	for e in enemies:
		var d: float = e.root.position.distance_to(player.position)
		e.root.visible = d < 70.0
		e.ap.active = d < 55.0 or e.state != "dormant"
		e.eye.visible = d < 25.0 and e.eye.light_energy > 1.0

func _physics_process(dt: float) -> void:
	world.update(player.position)
	npcs.update(dt)
	_cull()
	_update_player(dt)
	for e in enemies:
		_update_enemy(e, dt)
	var near := 1e9
	for b in bosses:
		boss = b
		_update_boss(dt)
	for b in bosses:  # aim everything else at the nearest living boss
		var d: float = b.root.position.distance_to(player.position)
		if not b.dead and d < near:
			near = d
			boss = b
	_update_meteors(dt)
	_update_elevator(dt)
	_update_fireballs(dt)
	_update_bolts(dt)
	_update_pickups()
	_update_camera(dt)
	if Input.is_action_just_pressed("menu") and not menu.visible and state != "dead":
		menu.open()
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
	buff_t = maxf(0.0, buff_t - dt)
	if poison_t > 0.0 and state != "dead":
		poison_t -= dt
		hp = maxf(1.0, hp - 3.0 * dt)  # poison wears you down but never kills on its own
	if talents.has("essencia"):
		essence = minf(max_essence, essence + 2.0 * dt)
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
			elif _pressed("seed") and seed_cd <= 0 and essence >= _seed_cost():
				_start_cast()
			elif _pressed("seed_next") and seeds.size() > 1:
				seed_i = (seed_i + 1) % seeds.size()
				_float("Semente: " + SEEDS[seeds[seed_i]].name, player.position + Vector3(0, 2.2, 0), SEEDS[seeds[seed_i]].col)
			elif _pressed("travel") and _near_bonfire(3.0) != null and lit.size() > 1:
				_fast_travel()
			elif _pressed("flask") and flasks > 0:
				_set_state("drink")
				anim.speed_scale = 1.0
				_play(_a("drink"), 0.1)
				_sfx("metalPot1", -6)
			elif _pressed("jump") and player.is_on_floor() and stamina > 5:
				player.velocity.y = 7.6
				_spend(8.0)
				anim.play(_a("jump"), 0.1, 1.4)
				_sfx(["cloth1", "cloth3"], -6)
			elif _pressed("interact") and _current_interact() != null:
				_current_interact().do.call()
			elif _held("block") and stamina > 0:
				_set_state("block")
				block_t = 0.0
				_play(_a("block_idle"), 0.1)
			elif _pressed("level") and _near_bonfire(3.0) != null:
				menu.open("status")
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
			var pool: Array = CHAIN_G if weapon == "great" else CHAIN
			if state_t > hit_at + 0.12 and combo_queued and stamina > 5 and move in combo and move != combo[-1]:
				_start_move(combo[combo.find(move) + 1])
			elif state_t > hit_at + 0.12 and combo_queued and stamina > 5 and landed and move in pool:
				# endless chain while you keep connecting: a different swing each time, half stamina
				var next: String = pool.filter(func(m): return m != move).pick_random()
				chain += 1
				_start_move(next)
				stamina += MOVES[next].stamina * 0.5
				if chain % 4 == 0:
					_float("%d GOLPES!" % (chain + combo.size()), player.position + Vector3(0, 2.6, 0), Color(1, 0.8, 0.3))
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
		"climb":
			player.velocity = Vector3.ZERO
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
				var heal: float = 70.0 * stats.flask_mult
				hp = min(max_hp, hp + heal)
				poison_t = 0.0  # the Sap also cures poison
				_float("+%d" % int(heal), player.position + Vector3(0, 2, 0), Color(0.6, 1, 0.6))
			if state_t > 1.4:
				_set_state("free")
		"cast":
			player.velocity.x = 0
			player.velocity.z = 0
			if state_t > 0.45 and state_t - dt <= 0.45:
				match seeds[seed_i]:
					"fogo": _throw_fireball()
					"gelo": _throw_fireball(true)
					"raio": _lightning()
			if state_t > 0.9:
				_set_state("free")
		"dead":
			player.velocity = Vector3.ZERO
			if state_t > 4.0:
				_respawn()
	if state == "free" and not player.is_on_floor() and dir.length() > 0.1 and player.velocity.y < 2.0:
		_try_mantle()
	if state == "climb":
		player.velocity = Vector3.ZERO
	player.move_and_slide()
	if player.position.y < Level.FALL_DEATH_Y and state != "dead":
		_hurt_player(9999.0, "Caiu no abismo")
	if state == "roll" or sprinting:
		for b in breakables.duplicate():
			if Vector2(b.pos.x - player.position.x, b.pos.z - player.position.z).length() < 0.9:
				_break(b)
	if _pressed("lock"):
		_toggle_lock()
	if lock_target != null and (lock_target.dead or lock_target.root.position.distance_to(player.position) > 20):
		lock_target = null
	# bonfire rest
	var bf = _near_bonfire(2.2)
	if state == "free" and bf != null and (hp < max_hp or flasks < max_flasks or essence < max_essence or not lit.has(bf[1]) or bonfire_pos != bf[0]):
		bonfire_pos = bf[0]
		lit[bf[1]] = true
		hp = max_hp
		flasks = max_flasks
		essence = max_essence
		_respawn_enemies()
		_save.call_deferred()
		_show_banner("FOGUEIRA: " + bf[1].to_upper(), "Vida, frascos e essência restaurados. Os mortos se levantam de novo.", Color(1, 0.7, 0.3), 2.5)
	# reclaim dropped embers
	if dropped_marker != null and player.position.distance_to(dropped_marker.position) < 1.5:
		embers += dropped_embers
		_float("+%d brasas recuperadas" % dropped_embers, player.position + Vector3(0, 2.2, 0), Color(1, 0.7, 0.3))
		dropped_embers = 0
		dropped_marker.queue_free()
		dropped_marker = null
		_save()

func _fast_travel() -> void:
	var here = _near_bonfire(3.0)
	var names := []
	for b in bonfires:
		if lit.has(b[1]):
			names.append(b)
	var i: int = names.find(here)
	var to = names[(i + 1) % names.size()]
	bonfire_pos = to[0]
	player.position = to[0] + Vector3(0, 0.5, -2.5)
	_respawn_enemies()
	_sfx("fireball", -8)
	_show_banner(to[1].to_upper(), "Viagem pelas chamas", Color(1, 0.7, 0.3), 2.5)

# ground under a point (level geometry), or the fallback when there is none
func _ground_y(p: Vector3, fallback: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.5, 0), p - Vector3(0, 6.0, 0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else fallback

# grab a ledge in front while airborne: chest ray hits a wall, a ray from above finds its top within reach
func _try_mantle() -> void:
	var space := player.get_world_3d().direct_space_state
	var fwd := _fwd()
	var chest := PhysicsRayQueryParameters3D.create(player.position + Vector3(0, 1.1, 0), player.position + Vector3(0, 1.1, 0) + fwd * 0.9)
	chest.exclude = [player.get_rid()]
	if space.intersect_ray(chest).is_empty():
		return
	var above := player.position + fwd * 0.75 + Vector3(0, 2.6, 0)
	var down := PhysicsRayQueryParameters3D.create(above, above - Vector3(0, 2.4, 0))
	down.exclude = [player.get_rid()]
	var top := space.intersect_ray(down)
	if top.is_empty() or top.normal.y < 0.7:
		return
	var rise: float = top.position.y - player.position.y
	if rise < 0.5 or rise > 2.4:
		return
	_climb(top.position + fwd * 0.4 + Vector3(0, 0.05, 0), 0.55)

# move the hero to a spot over time (ledge grab, ladder); no control meanwhile
func _climb(to: Vector3, secs := 2.2) -> void:
	_set_state("climb")
	anim.play(_a("jump"), 0.1, 0.8)
	_sfx("cloth3", -4)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(player, "position", Vector3(player.position.x, to.y, player.position.z), secs * 0.7)
	tw.tween_property(player, "position", to, secs * 0.3)
	tw.tween_callback(func(): _set_state("free"))

func _ring_bell(n: int) -> void:
	_sfx("jingle_win", 0)
	_sfx("impactPlate_heavy_002", 4)
	shake = 0.5
	if bells >= n:
		_show_banner("O SINO JÁ TOCOU", "", Color(0.8, 0.75, 0.6), 2.0)
		return
	bells = n
	_show_banner("%dº SINO DO DESPERTAR" % n, "Algo se move nas profundezas", Color(1, 0.85, 0.5), 4.0)
	_save()

func _current_interact():
	for it in interacts:
		var d: Vector3 = it.pos - player.position
		if Vector2(d.x, d.z).length() < it.r and absf(d.y) < 2.2:
			return it
	return null

# the church elevator: starts at the top; riding it down the first time opens the shortcut
func _build_elevator() -> void:
	elevator = AnimatableBody3D.new()
	elevator.position = Vector3(Level.ELEVATOR.x, Level.CHURCH_Y - 0.2, Level.ELEVATOR.z)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.6, 0.4, 3.6)
	cs.shape = sh
	elevator.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	mi.mesh = bm
	mi.material_override = Level.mats.wood
	elevator.add_child(mi)
	add_child(elevator)
	var bottom := Vector3(Level.ELEVATOR.x + 2.6, 0, Level.ELEVATOR.z)
	var top := Vector3(Level.ELEVATOR.x - 1.8, Level.CHURCH_Y, Level.ELEVATOR.z)
	interacts.append({"pos": bottom, "r": 2.0, "label": "CHAMAR", "do": func(): _call_elevator(0.0)})
	interacts.append({"pos": top, "r": 2.0, "label": "CHAMAR", "do": func(): _call_elevator(Level.CHURCH_Y)})

func _call_elevator(to_y: float) -> void:
	if not elevator_open:
		_show_banner("NÃO RESPONDE", "Algo o trava lá em cima", Color(0.8, 0.7, 0.6), 2.5)
		return
	_move_elevator(to_y)

func _move_elevator(to_y: float) -> void:
	if elevator_moving or absf(elevator.position.y + 0.2 - to_y) < 0.5:
		return
	elevator_moving = true
	_sfx("impactWood_heavy_000", -2)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(elevator, "position:y", to_y - 0.2, 7.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): elevator_moving = false)

func _update_elevator(dt: float) -> void:
	var p := elevator.position
	var on := absf(player.position.x - p.x) < 1.8 and absf(player.position.z - p.z) < 1.8 and absf(player.position.y - (p.y + 0.2)) < 0.6
	elevator_t = elevator_t + dt if on and not elevator_moving else 0.0
	if elevator_t > 0.6:
		elevator_t = 0.0
		var at_top := p.y > Level.CHURCH_Y * 0.5
		if at_top and not elevator_open:
			elevator_open = true
			_show_banner("ATALHO ABERTO", "O elevador liga a Igreja ao Santuário", Color(0.6, 1, 0.6), 3.5)
			_save()
		if elevator_open:
			_move_elevator(0.0 if at_top else Level.CHURCH_Y)

func _near_bonfire(r: float):
	for b in bonfires:
		if player.position.distance_to(b[0]) < r:
			return b
	return null

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
	if name == COMBO[0] or name == COMBO_G[0] or not (name in CHAIN or name in CHAIN_G):
		chain = 0
	landed = false
	move = name
	_set_state("attack")
	hit_done = false
	combo_queued = false
	sprinting = false
	_spend(mv.stamina * stats.stamina_cost)
	anim.play(_a(mv.anim), 0.08, mv.speed)
	_sfx(["knifeSlice", "knifeSlice2", "drawKnife1"] if not name.ends_with("kick") else ["cloth1"], -3)

func _start_roll(dir: Vector3) -> void:
	_set_state("roll")
	_spend(18.0 * stats.roll_cost)
	roll_dir = dir.normalized() if dir.length() > 0.1 else _fwd()
	model.rotation.y = atan2(roll_dir.x, roll_dir.z)
	invuln_t = 0.45
	anim.play(_a("roll"), 0.05, 1.7)
	_sfx(["cloth1", "cloth3"], -2)

func _start_cast() -> void:
	_set_state("cast")
	seed_cd = 1.2
	essence -= _seed_cost()
	anim.play(_a("cast"), 0.1, 1.2)

# every stat from attributes, talents, gear and permanent rewards
func _recalc() -> void:
	stats = Rpg.derive(attrs, talents)
	max_hp = stats.max_hp + bonus_hp + (gear.ring.val if gear.has("ring") else 0.0)
	max_stamina = stats.max_stamina
	max_essence = stats.max_essence
	hp = minf(hp, max_hp)
	essence = minf(essence, max_essence)

func _melee_mult() -> float:
	var m: float = stats[weapon + "_mult"] * Rpg.upgrade_mult(upgrades[weapon])
	if gear.has(weapon):
		m *= 1.0 + gear[weapon].val / 100.0
	if talents.has("furia"):
		m *= 1.0 + 0.1 * mini(chain / 4, 4)
	if buff_t > 0.0:
		m *= 1.3
	return m

func _seed_mult() -> float:
	return stats.seed_mult * ((1.0 + gear.amulet.val / 100.0) if gear.has("amulet") else 1.0)

func _seed_cost() -> float:
	return SEEDS[seeds[seed_i]].cost * stats.seed_cost

# level up at a bonfire: one point into an attribute (called from the menu)
func _buy_attr(a: String) -> bool:
	var cost := Rpg.level_cost(level)
	if embers < cost or _near_bonfire(3.0) == null:
		return false
	embers -= cost
	level += 1
	attrs[a] += 1
	_recalc()
	hp = max_hp
	stamina = max_stamina
	_sfx("jingle_win", -6)
	_save()
	return true

func _talent_points_left() -> int:
	return Rpg.talent_points(level, bells, boss_kills) - talents.size()

func _learn(id: String) -> bool:
	if _talent_points_left() <= 0 or not Rpg.can_learn(id, talents):
		return false
	talents[id] = true
	_recalc()
	_sfx("jingle_win", -8)
	_save()
	return true

# reset attributes and talents at a bonfire; the first one is free, then it costs embers
func _respec_cost() -> int:
	return 0 if not has_meta("respecced") else 100 * level

func _respec() -> bool:
	var cost := _respec_cost()
	if embers < cost or _near_bonfire(3.0) == null:
		return false
	embers -= cost
	set_meta("respecced", true)
	var base := Rpg.class_attrs(cls)
	for a in Rpg.ATTRS:
		free_points += attrs[a] - base[a]
	attrs = base
	talents = {}
	_recalc()
	_save()
	return true

func _place_point(a: String) -> bool:
	if free_points <= 0:
		return false
	free_points -= 1
	attrs[a] += 1
	_recalc()
	_save()
	return true

func _reinforce() -> bool:
	var lv: int = upgrades[weapon]
	if lv >= Rpg.MAX_UPGRADE or (_near_bonfire(3.0) == null and not smith_open):
		return false
	var c: Array = Rpg.upgrade_cost(lv)
	if titanite < c[0] or embers < c[1]:
		return false
	titanite -= c[0]
	embers -= c[1]
	upgrades[weapon] = lv + 1
	_sfx("impactPlate_heavy_002", -2)
	_save()
	return true

func _quest_state() -> Dictionary:
	return {"lit": lit, "sentinels_dead": sentinels_dead, "bells": bells, "elevator_open": elevator_open,
		"shards_found": shards_found, "best_upgrade": maxi(upgrades.sword, upgrades.great), "talents": talents.size(), "kills": kills}

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
	for b in breakables.duplicate():
		var tb: Vector3 = b.pos - player.position
		tb.y = 0
		if tb.length() < mv.reach + 0.3 and fwd.angle_to(tb.normalized()) < mv.arc:
			_break(b)
	for e in enemies:
		if e.dead:
			continue
		var to: Vector3 = e.root.position - player.position
		if to.length() < mv.reach and fwd.angle_to(to.normalized()) < mv.arc:
			_damage_enemy(e, mv)
			landed = true
	if boss != null and not boss.dead:
		var tb: Vector3 = boss.root.position - player.position
		if tb.length() < mv.reach + 2.6 and fwd.angle_to(tb.normalized()) < 1.0:
			landed = true
			_damage_boss(mv.dmg * _melee_mult())

func _damage_enemy(e: Dictionary, mv: Dictionary) -> void:
	if e.state in ["dormant", "awaken"]:
		return
	var el: String = mv.get("el", "fis")
	var dmg: float = mv.dmg * (_melee_mult() if el == "fis" else _seed_mult())
	if e.state == "broken" and move == "riposte":
		dmg = 140.0 * _melee_mult() * stats.crit_mult
		_float("CRÍTICO!", e.root.position + Vector3(0, 2.6, 0), Color(1, 0.3, 0.2))
		shake = 0.6
	elif e.state == "block":
		if move == "kick":
			_break_guard(e)
			return
		dmg *= 0.2
		_eplay(e, "Block_Hit", 0.05)
		_sfx("impactPlate_heavy_002", -2)
		_float("bloqueou", e.root.position + Vector3(0, 2.3, 0), Color(0.7, 0.7, 0.8))
	var weak := Rpg.weakness(e.kind, el)
	dmg *= weak
	e.hp -= dmg
	shake = max(shake, 0.25)
	_sfx(["impactWood_heavy_000", "impactPlate_heavy_000"], -2)
	_float(str(int(dmg)) + (" FRACO!" if weak > 1.1 else (" resiste" if weak < 0.9 else "")), e.root.position + Vector3(0, 2.1, 0),
		Color(1, 0.6, 0.2) if weak > 1.1 else (Color(0.6, 0.6, 0.65) if weak < 0.9 else Color.WHITE))
	if el == "fogo" and e.hp > 0:
		if e.get("burn", 0.0) <= 0.0:
			_float("QUEIMANDO", e.root.position + Vector3(0, 2.6, 0), Color(1, 0.45, 0.1))
		e.burn = 4.0
	if el == "fis" and talents.has("sangue") and e.hp > 0:
		e.bleed = e.get("bleed", 0.0) + 25.0
		if e.bleed >= 100.0:
			e.bleed = 0.0
			e.hp -= e.max * 0.12 + 20.0
			_float("SANGRAMENTO", e.root.position + Vector3(0, 2.6, 0), Color(0.9, 0.05, 0.05))
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
		_eplay(e, ["Hit_A", "Hit_B"].pick_random(), 0.05, 1.4)

func _eplay(e: Dictionary, anim_name: String, blend := -1.0, speed := 1.0) -> void:
	if e.ap.has_animation(anim_name):  # the wolf has no hit or death clips
		e.ap.play(anim_name, blend, speed)

func _break_guard(e: Dictionary) -> void:
	e.state = "broken"
	e.t = 0.0
	e.poise = e.max_poise
	_eplay(e, "Hit_B", 0.05, 0.5)
	_sfx("impactPlate_heavy_001", 0)
	_float("ATORDOADO", e.root.position + Vector3(0, 2.4, 0), Color(1, 0.85, 0.3))

func _kill_enemy(e: Dictionary) -> void:
	e.dead = true
	e.eye.light_energy = 0.0
	if e.ai == "wolf":
		e.revive_t = -1.0
		e.ap.stop()
		create_tween().tween_property(e.root, "rotation:z", PI / 2, 0.4)  # keels over
	elif not e.revived and e.kind in ["warrior", "minion", "rogue"] and randf() < 0.5:  # only the undead of the first valley
		e.revive_t = 4.0
		e.ap.play("Death_C_Skeletons")
	else:
		e.revive_t = -1.0
		e.ap.play(["Death_A", "Death_B"].pick_random())
	if randf() < (0.25 if e.ai == "wolf" else 0.35):
		_drop_item(e.root.position, _roll_rarity())
	var reward: int = Rpg.FOES[e.kind].reward / (2 if e.revived else 1)
	embers += reward
	_float("+%d brasas" % reward, e.root.position + Vector3(0, 2.6, 0), Color(1, 0.7, 0.3))
	kills += 1
	var ti := 2 if e.kind in ["sentinel", "blackknight", "executioner"] else (1 if randf() < 0.12 else 0)
	if ti > 0 and not e.revived:
		titanite += ti
		_float("+%d titanita" % ti, e.root.position + Vector3(0, 3.0, 0), Color(0.7, 0.85, 1.0))
	if talents.has("vampiro"):
		hp = minf(max_hp, hp + max_hp * 0.08)
	if e.kind == "sentinel" and not sentinels_dead and enemies.filter(func(o): return o.kind == "sentinel" and not o.dead).is_empty():
		sentinels_dead = true
		_show_banner("SENTINELAS DERROTADAS", "O caminho para o sino está livre  ·  +1 talento", Color(1, 0.8, 0.4), 4.0)
		boss_kills += 1
		_save()
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
		if boss.kind == "wyrm":
			embers += 5000
			_drop_item(boss.root.position + Vector3(0, 0, 4), 3)
			bonus_hp += 50.0
			boss_kills += 1
			_recalc()
			hp = max_hp
			_sfx("dragon_roar", 2)
			_sfx("jingle_win", -2)
			_fade(music_boss, -80.0, 4.0)
			_fade(music_amb, -8.0, 4.0)
			_save.call_deferred()
			_show_banner("WYRM ANCIÃO DERROTADO", "A ilha é sua  ·  +5000 brasas  ·  +50 vida máxima", Color(1, 0.6, 0.15), 7.0)
			return
		embers += 2000
		boss_kills += 1
		_drop_item(boss.root.position + Vector3(0, 0, 3), 3)
		dragon_seed = true
		_sfx("dragon_roar", 2)
		_sfx("jingle_win", -2)
		_fade(music_boss, -80.0, 4.0)
		_fade(music_amb, -8.0, 4.0)
		_set_gate(false)
		_save.call_deferred()
		_show_banner("DRAGÃO DERROTADO", "Você obteve a SEMENTE DO DRAGÃO  ·  +2000 brasas", Color(1, 0.6, 0.15), 6.0)

func _hurt_player(dmg: float, src: String, attacker: Dictionary = {}) -> void:
	if invuln_t > 0 and state == "roll" and talents.has("esquiva") and buff_t <= 0.0:
		buff_t = 3.0
		stamina = minf(max_stamina, stamina + 25.0)
		_float("ESQUIVA PERFEITA", player.position + Vector3(0, 2.2, 0), Color(0.7, 0.9, 1))
	if invuln_t > 0 or state == "dead":
		return
	dmg *= stats.taken_mult
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
	if not attacker.is_empty() and randf() < Rpg.FOES.get(attacker.get("kind", ""), {}).get("poison", 0.0) and hp > 0:
		if poison_t <= 0.0:
			_float("ENVENENADO", player.position + Vector3(0, 2.4, 0), Color(0.5, 0.9, 0.2))
		poison_t = 8.0
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
		_save()
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

func _roll_rarity() -> int:
	var r := randf()
	return 3 if r < 0.01 else (2 if r < 0.08 else (1 if r < 0.3 else 0))

func _drop_item(pos: Vector3, rarity: int) -> void:
	var slot: String = ITEMS.keys().pick_random()
	var f: float = RARITY[rarity][2] * randf_range(0.85, 1.15)
	var item := {"slot": slot, "rarity": rarity, "name": ITEMS[slot].names[rarity], "val": roundf(ITEMS[slot].base * f)}
	var col: Color = RARITY[rarity][1]
	var n := _glow_marker(pos + Vector3(0, 0.2, 0), col)
	if rarity >= 1:  # a beam of light so rare drops are seen from afar
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.12
		cm.height = 4.0 + rarity * 3.0
		beam.mesh = cm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.albedo_color = Color(col, 0.6)
		beam.material_override = bm
		beam.position.y = cm.height / 2.0
		n.add_child(beam)
	loot.append([n, item])

func _take_item(item: Dictionary) -> void:
	var col: Color = RARITY[item.rarity][1]
	var line: String = ITEMS[item.slot].fmt % int(item.val)
	var old = gear.get(item.slot)
	if old == null or item.val > old.val:
		gear[item.slot] = item
		_recalc()
		_show_banner(item.name.to_upper(), "%s  ·  %s  ·  equipado" % [RARITY[item.rarity][0], line], col, 3.0 if item.rarity < 3 else 5.0)
	else:
		embers += 20 * (item.rarity + 1)
		_float("%s (%s) → +%d brasas" % [item.name, RARITY[item.rarity][0], 20 * (item.rarity + 1)], player.position + Vector3(0, 2.4, 0), col)
	_sfx("jingle_win" if item.rarity >= 2 else "metalPot1", -6 if item.rarity >= 2 else -4)
	if item.rarity == 3:
		_sfx("dragon_roar", -12)
		shake = 0.4
	_save()

func _update_pickups() -> void:
	for l in loot.duplicate():
		l[0].rotation.y += 0.04
		if l[0].position.distance_to(player.position) < 1.6:
			_take_item(l[1])
			l[0].queue_free()
			loot.erase(l)
	for sm in seed_marks.duplicate():
		if sm[0].position.distance_to(player.position) < 1.6:
			seeds.append(sm[1][2])
			seed_i = seeds.size() - 1
			sm[0].queue_free()
			seed_marks.erase(sm)
			_sfx("jingle_win", -4)
			_show_banner(sm[1][3], sm[1][4], SEEDS[sm[1][2]].col, 4.0)
			_save()
	var r := ""
	var ar := Level.area_of(player.position)
	if ar.is_empty():
		ar = world.area_of(player.position)
	if not ar.is_empty():
		r = ar[0]
		if r != region and banner_t <= 0.5:
			_show_banner(ar[0], ar[1], Color(0.95, 0.85, 0.65), 3.5)
	if banner_t <= 0.5 or r != "":
		region = r
	for s in shards.duplicate():
		s.rotation.y += 0.03
		if s.position.distance_to(player.position) < 1.4:
			max_flasks += 1
			flasks += 1
			shards_found += 1
			shards.erase(s)
			s.queue_free()
			_sfx("jingle_win", -8)
			_show_banner("FRAGMENTO DE SEIVA", "Frascos máximos: %d" % max_flasks, Color(0.5, 1, 0.6), 2.5)
			_save()

func _respawn() -> void:
	player.position = bonfire_pos + Vector3(0, 0.5, -2.5)
	hp = max_hp
	stamina = max_stamina
	flasks = max_flasks
	essence = max_essence
	poison_t = 0.0
	_set_state("free")
	lock_target = null
	_respawn_enemies()
	for b in bosses:
		if not b.dead:
			b.hp = b.max
			b.awake = false
			b.phase = 1
			b.root.position = b.home
			b.state = "idle"
	_set_gate(false)
	_fade(music_boss, -80.0, 2.0)
	_fade(music_amb, -8.0, 2.0)

func _respawn_enemies() -> void:
	_spawn_breakables()
	for e in enemies:
		e.root.queue_free()
	enemies.clear()
	for sp in Level.SPAWNS:
		_spawn_enemy(sp[0], sp[1])
	world.respawn()

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
	if gate == null:
		return
	(gate.get_child(0) as CollisionShape3D).disabled = not closed
	create_tween().tween_property(gate_bars, "position:y", 0.0 if closed else 4.2, 0.5 if closed else 2.0)
	if closed:
		_sfx("impactMetal_heavy_000" if sfx_cache.has("impactMetal_heavy_000") else "impactPlate_heavy_001", 2)

func _wake_boss() -> void:
	if boss.awake:
		return
	boss.awake = true
	if boss.kind == "guardian":
		_set_gate(true)
	_show_banner(boss.name.to_upper(), "", Color(1, 0.45, 0.15), 3.0)
	_sfx("dragon_roar", 3)
	_fade(music_amb, -80.0, 2.0)
	_fade(music_boss, -4.0, 2.0)

# ------------------------------------------------------------------ enemies
func _update_enemy(e: Dictionary, dt: float) -> void:
	if e.state == "dormant" and e.root.position.distance_squared_to(player.position) > 3600.0:
		return  # far sleepers cost nothing
	if e.get("slow", 0.0) > 0.0:  # Ice Seed
		e.slow -= dt
		dt *= 0.4
		e.ap.speed_scale = 0.4 if e.slow > 0.0 else 1.0
	if e.get("burn", 0.0) > 0.0 and not e.dead:  # Fire Seed burn
		e.burn -= dt
		e.hp -= 6.0 * _seed_mult() * dt
		if e.hp <= 0.0:
			_kill_enemy(e)
	e.root.position.y = _ground_y(e.root.position, e.root.position.y)
	if e.dead:
		# some skeletons pull themselves back together once, unless their bones are burnt (Fire Seed)
		if e.revive_t > 0:
			e.revive_t -= dt
			e.eye.light_energy = 0.3 + 0.3 * sin(e.revive_t * 12.0)
			if e.revive_t <= 0:
				e.dead = false
				e.revived = true
				e.hp = e.max * 0.5
				e.state = "awaken"
				e.t = -0.8
				e.ap.play("Death_C_Skeletons_Resurrect")
				_sfx("impactWood_heavy_000", -2)
				_float("RESSURGIU", e.root.position + Vector3(0, 2.4, 0), Color(0.8, 0.4, 0.3))
		return
	e.t += dt
	e.cast_cd -= dt
	if e.ai == "wolf":
		_update_wolf(e, dt)
		return
	var to: Vector3 = player.position - e.root.position
	to.y = 0
	var dist := to.length()
	var ap: AnimationPlayer = e.ap
	var speed: float = Rpg.FOES[e.kind].speed
	match e.state:
		"dormant":
			if (dist < 9 or e.get("alerted", false)) and state != "dead":
				_alert(e)
				e.state = "awaken"
				e.t = 0.0
				e.eye.light_energy = 0.5
				ap.play("Skeletons_Awaken_Floor", 0.1, 1.3)
				_sfx("impactWood_heavy_000", -6)
		"awaken":
			if e.t > 1.9:
				e.state = "chase"
		"idle":
			if (dist < 11 or e.get("alerted", false)) and state != "dead":
				_alert(e)
				e.state = "chase"
		"chase" when e.ai in ["caster", "archer"]:
			# keeps its distance and throws ghost fire
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.15)
			if dist < 5.0:
				e.root.position -= to.normalized() * 2.2 * dt
				if ap.current_animation != "Walking_Backwards":
					ap.play("Walking_Backwards", 0.2)
			elif dist > 11.0:
				e.root.position += to.normalized() * 2.4 * dt
				if ap.current_animation != "Walking_D_Skeletons":
					ap.play("Walking_D_Skeletons", 0.2)
			elif e.cast_cd <= 0:
				e.state = "cast"
				e.t = 0.0
				e.hit = false
				ap.play("2H_Ranged_Aiming" if e.ai == "archer" else "Spellcast_Raise", 0.15, 1.4)
				e.eye.light_energy = 2.0
			elif ap.current_animation != ("2H_Ranged_Aiming" if e.ai == "archer" else "Spellcasting"):
				ap.play("2H_Ranged_Aiming" if e.ai == "archer" else "Spellcasting", 0.2)
			if dist > 18 or state == "dead":
				e.state = "idle"
				ap.play("Idle_Combat", 0.2)
		"cast":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.2)
			if not e.hit and e.t > 1.1:
				e.hit = true
				ap.play("2H_Ranged_Shoot" if e.ai == "archer" else "Spellcast_Shoot", 0.05, 1.2)
				_cast_bolt(e)
			if e.t > 1.8:
				e.state = "chase"
				e.cast_cd = randf_range(2.5, 4.0)
				e.eye.light_energy = 0.5
		"dodge":
			e.root.position += e.dodge * dt
			if e.t > 0.45:
				e.state = "chase"
				e.t = 0.0
		"circle":
			# souls enemies sidestep around you, waiting for an opening
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.2)
			e.root.position += to.normalized().cross(Vector3.UP) * e.side * 2.0 * dt
			if e.t > 1.6 or dist > 6.0:
				e.state = "chase"
				e.t = 0.0
		"chase":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.15)
			e.root.position += _separation(e) * dt  # a pack spreads out instead of stacking on one spot
			# hurt and alone at the front: back off and wait for the others
			if e.hp < e.max * 0.3 and dist < 3.0 and randf() < 0.01:
				e.state = "dodge"
				e.t = 0.0
				e.dodge = -to.normalized() * 6.0
				ap.play("Dodge_Backward", 0.05)
				return
			# minions are quick: they hop out of the way of a swing
			if e.ai in ["minion", "rogue"] and state == "attack" and state_t < 0.1 and dist < 3.2 and randf() < 0.3:
				e.state = "dodge"
				e.t = 0.0
				var side := randi() % 3
				e.dodge = (-to.normalized() if side == 0 else to.normalized().cross(Vector3.UP) * (1 if side == 1 else -1)) * 6.0
				ap.play(["Dodge_Backward", "Dodge_Left", "Dodge_Right"][side], 0.05)
				return
			if dist > 2.5 and dist < 5.0 and e.t > 1.0 and randf() < 0.012:
				e.state = "circle"
				e.t = 0.0
				e.side = [-1.0, 1.0].pick_random()
				ap.play("Running_Strafe_Left" if e.side > 0 else "Running_Strafe_Right", 0.2)
				return
			# warriors raise the shield when the player swings at them
			if e.ai in ["warrior", "sentinel"] and state == "attack" and state_t < 0.1 and dist < 3.2 and randf() < 0.35:
				e.state = "block"
				e.t = 0.0
				ap.play("Blocking", 0.1)
				return
			if dist > 4.0 and dist < 6.5 and e.t > 1.5 and randf() < 0.02:
				_enemy_attack(e, "1H_Melee_Attack_Jump_Chop")
				e.leap = true
			elif dist > 8.0:
				e.root.position += to.normalized() * speed * 0.5 * dt
				if ap.current_animation != "Walking_D_Skeletons":
					ap.play("Walking_D_Skeletons", 0.2)
			elif dist > 1.9:
				e.root.position += to.normalized() * speed * dt
				if ap.current_animation != "Running_A":
					ap.play("Running_A", 0.2)
			elif _attackers_near() >= 2:
				# only two strike at once (souls-style attack tokens); the rest circle and wait their turn
				e.state = "circle"
				e.t = 0.0
				e.side = [-1.0, 1.0].pick_random()
				ap.play("Running_Strafe_Left" if e.side > 0 else "Running_Strafe_Right", 0.2)
			else:
				_enemy_attack(e, (["Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab"] if e.kind == "rogue" else
					["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Stab"]).pick_random())
			if dist > 16 or state == "dead":
				e.state = "idle"
				ap.play(["Taunt", "Cheer"].pick_random() if state == "dead" else "Idle_Combat", 0.2)
		"windup":
			e.eye.light_energy = 0.5 + 6.0 * e.t
			if e.t > (0.45 if e.ai in ["warrior", "sentinel"] else 0.3):
				e.state = "strike"
				e.t = 0.0
				e.hit = false
				ap.speed_scale = 1.0
				ap.play(e.atk, 0.0, 1.4)
				ap.seek(e.wind_pos)
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
					_hurt_player(Rpg.FOES[e.kind].dmg, Rpg.FOES[e.kind].name, e)
			if ap.current_animation_position > length * 0.92 or e.t > 2.5:
				e.leap = false
				# one follow-up swing now and then
				if not e.combo and dist < 2.6 and randf() < 0.35 and state != "dead":
					e.combo = true
					_enemy_attack(e, ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop", "Dualwield_Melee_Attack_Slice"].pick_random())
				else:
					e.combo = false
					e.state = "chase"
					e.t = 0.0
		"block":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.2)
			if e.t > 1.1:
				if dist < 2.4 and randf() < 0.6:
					_enemy_attack(e, "Block_Attack")  # shield bash out of the guard
				else:
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

# an enemy that notices you wakes the others around it
func _alert(e: Dictionary) -> void:
	for o in enemies:
		if o != e and not o.dead and o.state in ["dormant", "idle"] and o.root.position.distance_squared_to(e.root.position) < 144.0:
			o.alerted = true

func _attackers_near() -> int:
	var n := 0
	for o in enemies:
		if not o.dead and o.state in ["windup", "strike"] and o.root.position.distance_squared_to(player.position) < 25.0:
			n += 1
	return n

func _separation(e: Dictionary) -> Vector3:
	var push := Vector3.ZERO
	for o in enemies:
		if o == e or o.dead:
			continue
		var d: Vector3 = e.root.position - o.root.position
		d.y = 0.0
		var l := d.length()
		if l < 1.3 and l > 0.01:
			push += d / l * (1.3 - l) * 3.0
	return push

# wolves have only idle/walk clips: the pounce is done by moving and tilting the model
func _update_wolf(e: Dictionary, dt: float) -> void:
	var to: Vector3 = player.position - e.root.position
	to.y = 0
	var dist := to.length()
	var m: Node3D = e.model
	var walk := "WolfArmature|Walking"
	match e.state:
		"dormant", "idle":
			if dist < 14 and state != "dead":
				e.state = "chase"
				e.t = 0.0
				e.eye.light_energy = 0.6
				_sfx("dragon_roar", -18)
		"chase":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.2)
			if dist > 3.2:
				e.root.position += to.normalized() * 6.5 * dt
				e.ap.play(walk, 0.2, 2.4)
			elif dist < 6 and e.t > 0.4 and randf() < 0.02:
				e.state = "circle"
				e.t = 0.0
				e.side = [-1.0, 1.0].pick_random()
			elif e.t > 0.6:
				e.state = "windup"
				e.t = 0.0
				e.eye.light_energy = 3.0
				e.ap.play("WolfArmature|Idle", 0.1)
			if dist > 22 or state == "dead":
				e.state = "idle"
				e.ap.play("WolfArmature|Idle", 0.2)
		"circle":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.2)
			e.root.position += to.normalized().cross(Vector3.UP) * e.side * 4.0 * dt
			e.ap.play(walk, 0.2, 1.6)
			if e.t > 1.0:
				e.state = "chase"
				e.t = 0.0
		"windup":
			e.root.rotation.y = lerp_angle(e.root.rotation.y, atan2(to.x, to.z), 0.25)
			m.rotation.x = -0.25 * minf(e.t / 0.3, 1.0)  # haunches down
			if e.t > 0.45:
				e.state = "leap"
				e.t = 0.0
				e.hit = false
				e.dodge = to.normalized()
				_sfx("cloth3", -4)
		"leap":
			var k: float = e.t / 0.45
			e.root.position += e.dodge * 9.0 * dt
			m.position.y = sin(PI * minf(k, 1.0)) * 0.7
			m.rotation.x = lerpf(-0.3, 0.35, minf(k, 1.0))
			if not e.hit and k > 0.55 and dist < 1.7:
				e.hit = true
				_hurt_player(Rpg.FOES[e.kind].dmg, Rpg.FOES[e.kind].name, e)
			if k >= 1.0:
				e.state = "recover"
				e.t = 0.0
				m.position.y = 0.0
				m.rotation.x = 0.0
				e.eye.light_energy = 0.6
		"recover":
			if e.t > 0.6:
				e.state = "chase"
				e.t = 0.0
		"stagger":
			m.position.y = 0.0
			m.rotation.x = 0.0
			e.root.position -= to.normalized() * 2.5 * dt
			if e.t > 0.35:
				e.state = "chase"
				e.t = 0.0
		"broken":
			m.rotation.x = 0.0
			e.ap.play("WolfArmature|Idle", 0.2, 0.3)
			if e.t > 2.5:
				e.state = "chase"
				e.t = 0.0

func _enemy_attack(e: Dictionary, atk: String) -> void:
	e.state = "windup"
	e.t = 0.0
	e.atk = atk
	e.ap.play(atk, 0.1, 0.35)
	e.wind_pos = 0.0
	e.wind_pos = (0.45 if e.ai in ["warrior", "sentinel"] else 0.3) * 0.35

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
		var zone: bool = (player.position.z < -15.5 and player.position.z > -44.0 and absf(player.position.x) < 22.0) if boss.kind == "guardian" \
			else player.position.distance_to(boss.home) < 26.0
		if zone and state != "dead":
			_wake_boss()
		return
	var k: float = boss.k
	match boss.state:
		"idle", "chase":
			root.rotation.y = lerp_angle(root.rotation.y, atan2(to.x, to.z), 0.06 * fury)
			if dist > 5.5 * k:
				root.position += to.normalized() * 2.6 * fury * dt
				if ap.current_animation != "d/walk":
					ap.play("d/walk", 0.3, fury)
			elif boss.t > 1.2 / fury:
				boss.state = "windup"
				boss.t = 0.0
				boss.next = "breath" if randf() < (0.4 if boss.phase == 1 else 0.55) else "bite"
			if dist > 9 * k and boss.t > 3.0 / fury and randf() < 0.01 * fury:
				boss.state = "windup"
				boss.t = 0.0
				boss.next = "rain" if boss.kind == "wyrm" and randf() < 0.6 else "breath"
		"windup":
			ap.play("d/attack", 0.2, 0.6 * fury)
			boss.mouth.light_energy = boss.t * 8.0
			var wind := (0.9 if boss.next == "bite" else 1.2) / fury
			if boss.t > wind:
				boss.state = boss.next
				boss.t = 0.0
				boss.hit = false
				_sfx("fire_breath" if boss.next == "breath" else "dragon_roar", 0 if boss.next == "breath" else -6)
				if boss.next == "rain":  # the Ancient Wyrm calls fire down around you
					for i in 6:
						var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
						_meteor(player.position + off)
		"bite":
			boss.mouth.light_energy = 0.5
			if not boss.hit and boss.t > 0.15:
				boss.hit = true
				var fwd := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y))
				if dist < 6.0 * k and fwd.angle_to(to.normalized()) < 0.8:
					_hurt_player(45.0 * fury, "Mordida do Dragão")
			if boss.t > 1.0 / fury:
				boss.state = "chase"
				boss.t = 0.0
		"breath":
			boss.mouth.light_energy = 9.0
			var fwd2 := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y))
			if int(boss.t * 10) % 3 == 0 and dist < 10.0 * k and fwd2.angle_to(to.normalized()) < 0.5:
				_hurt_player(14.0 * fury, "Sopro de Fogo")
			if boss.t > 1.6:
				boss.mouth.light_energy = 0.0
				boss.state = "chase"
				boss.t = 0.0
		"rain":
			boss.mouth.light_energy = 3.0
			if boss.t > 1.4:
				boss.mouth.light_energy = 0.0
				boss.state = "chase"
				boss.t = 0.0

func _meteor(at: Vector3) -> void:
	var ring := MeshInstance3D.new()  # warning circle on the ground
	var tm := TorusMesh.new()
	tm.inner_radius = 1.7
	tm.outer_radius = 2.0
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 0.3, 0.05)
	ring.material_override = rm
	ring.position = at + Vector3(0, 0.15, 0)
	add_child(ring)
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	rock.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.emission_enabled = true
	mm.emission = Color(1, 0.4, 0.05)
	mm.emission_energy_multiplier = 5
	rock.material_override = mm
	rock.position = at + Vector3(0, 16, 0)
	add_child(rock)
	meteors.append({"at": at, "t": 1.3, "ring": ring, "rock": rock})

func _update_meteors(dt: float) -> void:
	for m in meteors.duplicate():
		m.t -= dt
		m.rock.position.y = m.at.y + 16.0 * maxf(m.t, 0.0) / 1.3
		if m.t <= 0:
			if Vector2(player.position.x - m.at.x, player.position.z - m.at.z).length() < 2.0:
				_hurt_player(35.0, "Chuva de Fogo")
			_sfx("fireball", -4)
			shake = maxf(shake, 0.3)
			m.ring.queue_free()
			m.rock.queue_free()
			meteors.erase(m)

# ------------------------------------------------------------------ Seed of Fire
func _throw_fireball(ice := false) -> void:
	var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(0.5, 0.85, 1.0) if ice else Color(1, 0.45, 0.1)
	m.emission_energy_multiplier = 6
	m.albedo_color = Color(0.7, 0.9, 1.0) if ice else Color(1, 0.6, 0.2)
	ball.material_override = m
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.8, 1.0) if ice else Color(1, 0.5, 0.15)
	l.light_energy = 2.5
	l.omni_range = 5
	ball.add_child(l)
	ball.position = player.position + Vector3(0, 1.3, 0) + fwd * 0.8
	add_child(ball)
	fireballs.append({"node": ball, "vel": fwd * (17.0 if ice else 14.0), "t": 1.5, "ice": ice})
	_sfx("fireball", 0)

# Lightning Seed: instant strike on the locked/nearest enemy ahead, then jumps to two more
func _lightning() -> void:
	var fwd := _fwd()
	var target = lock_target
	if target == null or target == boss:
		var best := 15.0
		for e in enemies:
			var to: Vector3 = e.root.position - player.position
			if not e.dead and to.length() < best and fwd.angle_to(to.normalized()) < 0.9:
				best = to.length()
				target = e
	_sfx("impactPlate_heavy_002", 2)
	if target == null:
		_bolt_line(player.position + Vector3(0, 1.4, 0), player.position + Vector3(0, 1.4, 0) + fwd * 12.0)
		return
	var from := player.position + Vector3(0, 1.4, 0)
	var hit := [target]
	var dmg := 45.0
	while true:
		var tp: Vector3 = target.root.position + Vector3(0, 1.1, 0)
		_bolt_line(from, tp)
		_damage_enemy(target, {"dmg": dmg, "poise": 25.0, "el": "raio"})
		from = tp
		dmg *= 0.6
		var next = null
		for e in enemies:
			if not e.dead and not e in hit and e.root.position.distance_to(target.root.position) < 6.0:
				next = e
				break
		if next == null or hit.size() >= 3:
			break
		hit.append(next)
		target = next

func _bolt_line(a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.97, 0.7)
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, m)
	for i in 9:  # jagged
		var p := a.lerp(b, i / 8.0)
		if i > 0 and i < 8:
			p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		im.surface_add_vertex(p)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var l := OmniLight3D.new()
	l.position = b
	l.light_color = Color(1, 0.95, 0.6)
	l.light_energy = 4.0
	l.omni_range = 7
	mi.add_child(l)
	add_child(mi)
	get_tree().create_timer(0.18).timeout.connect(mi.queue_free)

func _update_fireballs(dt: float) -> void:
	for f in fireballs.duplicate():
		f.t -= dt
		var n: Node3D = f.node
		n.position += f.vel * dt
		var hit := false
		for e in enemies:
			if n.position.distance_to(e.root.position + Vector3(0, 1, 0)) < 1.2:
				if not e.dead:
					_damage_enemy(e, {"dmg": 30.0, "poise": 60.0, "el": "gelo"} if f.ice else {"dmg": 110.0 if f.get("big") else 55.0, "poise": 20.0, "el": "fogo"})
					if f.ice:
						e.slow = 3.0
						_float("CONGELADO", e.root.position + Vector3(0, 2.4, 0), Color(0.6, 0.9, 1))
					hit = true
				elif e.revive_t > 0 and not f.ice:
					e.revive_t = -1.0
					e.eye.light_energy = 0.0
					_float("CINZAS", e.root.position + Vector3(0, 1.8, 0), Color(1, 0.55, 0.2))
					hit = true
		if boss != null and not boss.dead and n.position.distance_to(boss.root.position + Vector3(0, 2.5, 0)) < 3.0:
			_damage_boss(70.0 * _seed_mult())
			hit = true
		if hit or f.t <= 0:
			n.queue_free()
			fireballs.erase(f)

func _cast_bolt(e: Dictionary) -> void:
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(0.3, 0.85, 1.0)
	m.emission_energy_multiplier = 5
	m.albedo_color = Color(0.5, 0.9, 1.0)
	ball.material_override = m
	var l := OmniLight3D.new()
	l.light_color = Color(0.3, 0.8, 1.0)
	l.light_energy = 2.0
	l.omni_range = 4
	ball.add_child(l)
	ball.position = e.root.position + Vector3(0, 1.4, 0)
	add_child(ball)
	var arrow: bool = e.ai == "archer"
	if arrow:  # a crossbow bolt: fast, straight, dark
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.04, 0.6)
		ball.mesh = bm
		m.emission = Color(0.6, 0.15, 0.05)
		m.emission_energy_multiplier = 1.0
		m.albedo_color = Color(0.2, 0.15, 0.1)
		l.light_energy = 0.0
		ball.look_at_from_position(ball.position, player.position + Vector3(0, 1.0, 0))
	var spd := 24.0 if arrow else 9.0
	bolts.append({"node": ball, "vel": (player.position + Vector3(0, 1.0, 0) - ball.position).normalized() * spd, "t": 2.5,
		"homing": not arrow, "dmg": 18.0 if arrow else 22.0, "src": Rpg.FOES[e.kind].name})
	_sfx("knifeSlice" if arrow else "fireball", -6)

func _update_bolts(dt: float) -> void:
	for b in bolts.duplicate():
		b.t -= dt
		var n: Node3D = b.node
		if b.homing:
			var want: Vector3 = (player.position + Vector3(0, 1.0, 0) - n.position).normalized() * 9.0
			b.vel = b.vel.lerp(want, 0.8 * dt)  # slight homing: roll through it, do not outrun it
		n.position += b.vel * dt
		var hit: bool = n.position.distance_to(player.position + Vector3(0, 1.0, 0)) < 0.8
		if hit:
			_hurt_player(b.dmg, b.src)
		if hit or b.t <= 0:
			n.queue_free()
			bolts.erase(b)

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
		cam_yaw -= event.relative.x * 0.006 * menu.options.sens
		cam_pitch = clamp(cam_pitch - event.relative.y * 0.004 * menu.options.sens, -0.9, 0.2)
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
	for a in ["attack", "roll", "lock", "seed", "flask", "block", "level", "weapon", "seed_next", "travel", "jump", "interact", "menu"]:
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
	var ml := CanvasLayer.new()
	ml.layer = 15
	add_child(ml)
	menu = Menu.new()
	ml.add_child(menu)
	menu.setup(self)
	menu.apply_options()
	dialog = Dialog.new()
	ml.add_child(dialog)
	dialog.setup(self)

func _button_r(a: String) -> float:
	match a:
		"attack": return 115.0
		"lock", "level", "weapon", "seed_next", "travel", "menu": return 62.0
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
		"seed_next": return Vector2(vs.x - 470, vs.y - 500)
		"travel": return Vector2(vs.x * 0.5 + 160, vs.y - 120)
		"jump": return Vector2(vs.x - 600, vs.y - 150)
		"interact": return Vector2(vs.x - 610, vs.y - 330)
		"level": return Vector2(vs.x * 0.5, vs.y - 120)
		"menu": return Vector2(vs.x - 110, 260)
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
	ui_draw.draw_rect(Rect2(40, 34, max_hp * 2.6, 28), Color(0.1, 0, 0, 0.7))
	ui_draw.draw_rect(Rect2(40, 34, hp * 2.6, 28), Color(0.5, 0.75, 0.15) if poison_t > 0.0 else Color(0.65, 0.08, 0.08))
	ui_draw.draw_rect(Rect2(40, 70, max_stamina * 3.2, 18), Color(0, 0.08, 0, 0.7))
	ui_draw.draw_rect(Rect2(40, 70, max(0.0, stamina) * 3.2, 18), Color(0.25, 0.6, 0.25))
	ui_draw.draw_rect(Rect2(40, 96, max_essence * 2.4, 14), Color(0, 0, 0.1, 0.7))
	ui_draw.draw_rect(Rect2(40, 96, essence * 2.4, 14), Color(0.25, 0.45, 0.95))
	_text("Nível %d   Frascos %d/%d" % [level, flasks, max_flasks], Vector2(40, 150), 34, Color(0.9, 0.8, 0.6))
	var status := []
	if poison_t > 0.0:
		status.append("ENVENENADO")
	if buff_t > 0.0:
		status.append("ESQUIVA +30% dano")
	if not status.is_empty():
		_text("  ".join(status), Vector2(40, 192), 30, Color(0.6, 1, 0.4))
	if menu.options.show_fps:
		_text("%d FPS" % Engine.get_frames_per_second(), Vector2(vs.x * 0.5 - 40, 30), 22, Color(0.6, 0.6, 0.6))
	_text("Objetivo: " + Rpg.current_objective(_quest_state()), Vector2(vs.x * 0.5 - 330, 66), 28, Color(0.95, 0.85, 0.6))
	if _near_bonfire(3.0) != null:
		_text("NÍVEL: subir atributos, reforçar arma, talentos", Vector2(vs.x * 0.5 - 330, vs.y - 200), 30, Color(1, 0.8, 0.5))
	for e in enemies:
		if e.dead or e.hp >= e.max or camera.is_position_behind(e.root.position):
			continue
		var ep := camera.unproject_position(e.root.position + Vector3(0, 2.3, 0))
		ui_draw.draw_rect(Rect2(ep - Vector2(50, 0), Vector2(100, 8)), Color(0, 0, 0, 0.6))
		ui_draw.draw_rect(Rect2(ep - Vector2(50, 0), Vector2(100 * e.hp / e.max, 8)), Color(0.75, 0.1, 0.1))
		ui_draw.draw_rect(Rect2(ep - Vector2(50, -10), Vector2(100 * e.poise / e.max_poise, 4)), Color(1, 0.8, 0.3) if e.state != "broken" else Color(1, 0.2, 0.2))
	_text("%d" % embers, Vector2(vs.x - 260, 60), 44, Color(1, 0.75, 0.4))
	_text("brasas", Vector2(vs.x - 260, 94), 26, Color(0.8, 0.6, 0.4))
	_text("%d titanita" % titanite, Vector2(vs.x - 260, 134), 28, Color(0.7, 0.85, 1.0))
	if dragon_seed:
		_text("Semente do Dragão", Vector2(vs.x - 330, 130), 26, Color(1, 0.55, 0.15))
	if boss != null and boss.awake and not boss.dead:
		var w := vs.x * 0.55
		var x0 := (vs.x - w) / 2
		_text(boss.name, Vector2(x0, vs.y - 92), 30, Color(0.95, 0.9, 0.8))
		ui_draw.draw_rect(Rect2(x0, vs.y - 80, w, 16), Color(0.1, 0, 0, 0.7))
		ui_draw.draw_rect(Rect2(x0, vs.y - 80, w * boss.hp / boss.max, 16), Color(0.6, 0.1, 0.05))
	for a in buttons:
		var pos := _button_pos(a, vs)
		var r := _button_r(a)
		if a == "level" and _near_bonfire(3.0) == null:
			continue
		if a == "seed_next" and seeds.size() < 2:
			continue
		if a == "interact" and _current_interact() == null:
			continue
		if a == "travel" and (_near_bonfire(3.0) == null or lit.size() < 2):
			continue
		var label: String = {"attack": "ATACAR", "roll": "ROLAR", "lock": "MIRA", "seed": SEEDS[seeds[seed_i]].name, "flask": "FRASCO", "block": "DEFESA",
			"level": "NÍVEL", "weapon": "ARMA", "seed_next": "TROCAR", "travel": "VIAJAR", "jump": "PULAR", "menu": "MENU",
			"interact": _current_interact().label if a == "interact" else ""}[a]
		var col: Color = SEEDS[seeds[seed_i]].col if a == "seed" else Color(1, 1, 1)
		ui_draw.draw_circle(pos, r, Color(col, 0.28 if Input.is_action_pressed(a) else 0.12))
		ui_draw.draw_arc(pos, r, 0, TAU, 48, Color(col, 0.6), 3)
		if a == "seed" and essence < _seed_cost():
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
