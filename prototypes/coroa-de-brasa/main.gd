# PROTOTYPE - NOT FOR PRODUCTION
# Coroa de Brasa: the game's root. It owns the camera (isometric, follows the hero), the save, the village and
# the run: rooms one after another, blessings between them, a boss at the end of each floor, gold and XP that
# you keep. Damage, gold and XP all go through here so every effect (crits, burn, chain lightning, life steal,
# thorns) is in one place.
extends Node3D

const Data = preload("res://data.gd")
const Rig = preload("res://rig.gd")
const Fx = preload("res://fx.gd")
const Hero = preload("res://hero.gd")
const Enemy = preload("res://enemy.gd")
const Boss = preload("res://boss.gd")
const Room = preload("res://room.gd")
const Hub = preload("res://hub.gd")
const UI = preload("res://ui.gd")
const SAVE_PATH := "user://coroa_save.json"
const CAM_OFFSET := Vector3(7.5, 12.0, 7.5)  # the camera looks from the south-east, down at 48 degrees

var world: Node3D  # the current place (village or room) and everything flying in it
var hero: CharacterBody3D
var enemies: Array = []
var ui: CanvasLayer
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var save := {"gold": 0, "unlocked": ["knight"], "hero": "knight", "tint": 0, "upgrades": {}, "xp": {}, "levels": {}, "best": 0, "runs": 0}
var run := {}  # empty in the village
var place := {}  # the room or village dictionary
var crit_next := false
var shake_t := 0.0
var cam_pos := Vector3.ZERO
var waves := 0
var cleared := false
var boss: Node3D
var sfx_pool: Array = []
var music_player: AudioStreamPlayer
var music_now := ""
var autoplay := OS.get_environment("COROA_AUTOPLAY") != ""

var paused_game: bool:
	get:
		return ui != null and ui.panel != null

func _ready() -> void:
	randomize()
	_load()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false  # on the compatibility renderer the bloom washed the whole picture out
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.make_current()
	ui = UI.new()
	add_child(ui)
	ui.setup(self)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -10.0
	add_child(music_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	go_hub()
	if not save.has("seen_intro"):
		save.seen_intro = true
		ui.message("COROA DE BRASA", "A Coroa de Brasa foi roubada pelos mortos.\nDesça a masmorra, vença os chefes e traga o fogo de volta.\n\nArraste do lado esquerdo para andar. ATACAR mira sozinho no inimigo mais perto. ESQUIVA te deixa invencível por um instante.\nOuro e experiência ficam com você mesmo se cair.", "COMEÇAR", func(): pass)

# ------------------------------------------------------------------ places
func _clear_world() -> void:
	if world != null:
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	enemies = []
	boss = null

func _spawn_hero(at: Vector3) -> void:
	var hp_frac := 1.0
	if hero != null:
		hp_frac = hero.hp / hero.max_hp if not hero.dead else 1.0
		hero.queue_free()
	hero = Hero.new()
	add_child(hero)
	hero.setup(self, save.hero, Data.TINTS[save.tint])
	hero.max_hp = max_hp()
	hero.hp = hero.max_hp * (hp_frac if in_run() else 1.0)
	hero.global_position = at + Vector3(0, 0.2, 0)
	cam_pos = hero.global_position

func go_hub() -> void:
	run = {}
	_clear_world()
	place = Hub.build(world)
	env.background_color = Color(0.35, 0.6, 0.9)
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.45
	sun.light_color = Color(1, 0.93, 0.8)
	sun.light_energy = 0.95
	_spawn_hero(place.spawn)
	music("town")
	ui.banner("VILA DA BRASA", "Altar dos Heróis · Forja · Portal da Masmorra", Color(1, 0.85, 0.5))

func in_run() -> bool:
	return not run.is_empty()

var starting := false

func start_run() -> void:
	if starting:
		return  # the portal fade is already running
	starting = true
	var potions := 2 + int(save.upgrades.get("pocao", 0))
	run = {"floor": 0, "room": 0, "potions": potions, "bless": {}, "gold": 0, "xp_run": 0, "rng": RandomNumberGenerator.new()}
	run.rng.randomize()
	save.runs += 1
	ui.transition(func():
		starting = false
		_next_room())

func _next_room() -> void:
	if run.is_empty():
		return  # the run ended during the fade
	var fl: Dictionary = Data.FLOORS[run.floor]
	run.room += 1
	var is_boss: bool = run.room > fl.rooms
	if autoplay:
		print("ROOM floor %d room %d hp %d reward %s" % [run.floor + 1, run.room, int(hero.hp), run.get("reward", "")])
	_clear_world()
	place = Room.build(world, fl.biome, run.rng, is_boss)
	var bg: Color = {"crypt": Color(0.04, 0.03, 0.07), "forest": Color(0.03, 0.07, 0.05), "fort": Color(0.08, 0.03, 0.03)}[fl.biome]
	env.background_color = bg
	env.ambient_light_color = {"crypt": Color(0.6, 0.6, 0.85), "forest": Color(0.6, 0.85, 0.6), "fort": Color(0.9, 0.65, 0.6)}[fl.biome]
	env.ambient_light_energy = 0.4
	sun.light_energy = 0.75
	sun.light_color = Color(1, 0.85, 0.75)
	_spawn_hero(place.entry)
	cleared = false
	if is_boss:
		var b := Boss.new()
		world.add_child(b)
		b.global_position = Vector3(0, 0.1, -4)
		b.setup_boss(self, Data.BOSSES[run.floor], run.floor)
		enemies.append(b)
		boss = b
		waves = 0
		ui.banner(Data.BOSSES[run.floor].name.to_upper(), fl.name, Color(1, 0.4, 0.3), 3.0)
		music("boss")
		sfx("impactBell_heavy_000")
	else:
		waves = 2 if run.room > 1 else 1
		_wave()
		music("forest" if fl.biome == "forest" else "dungeon")
		ui.banner(fl.name.to_upper() if run.room == 1 else "SALA %d" % run.room, "Derrote todos os inimigos" if run.room == 1 else "", Color(0.9, 0.85, 1), 2.0)

func _wave() -> void:
	waves -= 1
	var fl: Dictionary = Data.FLOORS[run.floor]
	var depth: int = run.floor * 6 + run.room
	var n: int = 3 + depth / 2 + run.rng.randi_range(0, 2)
	var spots: Array = place.spawns.duplicate()
	spots.shuffle()
	for i in mini(n, spots.size()):
		var elite: bool = depth >= 3 and run.rng.randf() < 0.03 + depth * 0.012  # no elites in the first rooms
		spawn_enemy(fl.pool[run.rng.randi() % fl.pool.size()], spots[i], elite)

func spawn_enemy(kind: String, pos: Vector3, elite := false) -> void:
	var e := Enemy.new()
	world.add_child(e)
	e.global_position = clamp_to_room(pos) + Vector3(0, 0.1, 0)
	e.setup(self, kind, run.get("floor", 0) * 2 + run.get("room", 0) / 2, elite)
	enemies.append(e)

func clamp_to_room(p: Vector3) -> Vector3:
	var b: Rect2 = place.bounds
	return Vector3(clampf(p.x, b.position.x, b.end.x), p.y, clampf(p.z, b.position.y, b.end.y))

func floor_y() -> float:
	return 0.0

func room_title() -> String:
	var fl: Dictionary = Data.FLOORS[run.floor]
	if run.room > fl.rooms:
		return "%s  ·  CHEFE" % fl.name
	return "%s  ·  sala %d/%d" % [fl.name, run.room, fl.rooms]

func boss_node():
	return boss if boss != null and is_instance_valid(boss) and not boss.dead else null

# ------------------------------------------------------------------ the loop
func _physics_process(dt: float) -> void:
	if hero == null:
		return
	if ui.pressed("pause") and not paused_game:
		ui.pause_panel()
	if paused_game:
		return
	if autoplay:
		_autoplay()
	if ui.pressed("interact"):
		_interact()
	if in_run() and place.has("exits"):  # (not during the fade into the first room)
		_update_room()
	_update_pickups(dt)

func _process(dt: float) -> void:
	if hero == null:
		return
	cam_pos = cam_pos.lerp(hero.global_position, clampf(dt * 6.0, 0.0, 1.0))
	shake_t = maxf(0.0, shake_t - dt)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_t * 0.4
	cam.global_position = cam_pos + CAM_OFFSET + sh
	cam.look_at(cam_pos + Vector3(0, 1.0, 0) + sh)

# the world direction for a joystick vector (x right, y down on screen)
func cam_dir(v: Vector2) -> Vector3:
	var right := Vector3(1, 0, -1).normalized()
	var up := Vector3(-1, 0, -1).normalized()
	return right * v.x - up * v.y

func _update_room() -> void:
	if hero.dead:
		if not run.has("dying"):
			run.dying = true
			sfx("lose")
			get_tree().create_timer(1.8).timeout.connect(func(): end_run(false))
		return
	var alive := enemies.filter(func(e): return not e.dead)
	if not cleared and alive.size() <= 1 and waves > 0 and boss == null:
		_wave()
	elif not cleared and alive.is_empty() and waves <= 0:
		_room_clear()
	var door := -1
	for i in place.exits.size():
		if cleared and hero.global_position.distance_to(place.exits[i].pos) < 2.2:
			door = i
	if door >= 0 and not run.has("leaving"):
		run.leaving = true
		run.reward = place.exits[door].get("reward", "bless")
		sfx("doorOpen_1")
		ui.transition(func():
			run.erase("leaving")
			_next_room())

func _room_clear() -> void:
	cleared = true
	var fl: Dictionary = Data.FLOORS[run.floor]
	if boss != null:
		# a floor done: heal, then the next floor or the end
		sfx("win")
		run.gold += int(80 * gold_mult())
		if run.floor + 1 >= Data.FLOORS.size():
			get_tree().create_timer(2.0).timeout.connect(func(): end_run(true))
			return
		ui.banner("ANDAR VENCIDO!", "A escada para %s se abre" % Data.FLOORS[run.floor + 1].name, Color(1, 0.85, 0.3), 3.0)
		run.floor += 1
		run.room = 0
		hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.5)
	else:
		ui.banner("SALA LIMPA", "Escolha uma porta: cada uma leva a uma recompensa", Color(0.6, 1, 0.6), 2.0)
	_open_gates()
	_give_reward(run.get("reward", "bless"))

# the reward of the room you chose (shown over its door), given when it is clear
const REWARDS := {"bless": ["BÊNÇÃO", Color(1, 0.8, 0.3)], "gold": ["OURO", Color(1, 0.9, 0.2)], "heal": ["CURA", Color(0.4, 1, 0.5)],
	"potion": ["POÇÃO", Color(1, 0.45, 0.65)]}

func _give_reward(kind: String) -> void:
	match kind:
		"bless":
			var pool := Data.BLESSINGS.duplicate()
			pool.shuffle()
			get_tree().create_timer(0.9).timeout.connect(func():
				if in_run() and not hero.dead:
					ui.blessings(pool.slice(0, 3), _take_blessing))
		"gold":
			var c := Rig.prop("dungeon", "chest_gold")
			world.add_child(c)
			c.global_position = hero.global_position + Vector3(0, 0, -2.5)
			var n: int = 40 + run.floor * 30
			for k in 6:
				_coin(c.global_position, n / 6)
			ui.banner("TESOURO", "+%d ouro" % int(n * gold_mult()), Color(1, 0.9, 0.3), 1.5)
		"heal":
			hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.4)
			Fx.burst(world, hero.global_position + Vector3(0, 1, 0), Color(0.4, 1, 0.5), 30, 5.0)
			ui.banner("FONTE DE VIDA", "+40% de vida", Color(0.4, 1, 0.5), 1.5)
		"potion":
			run.potions += 1
			ui.banner("POÇÃO", "+1 poção de cura", Color(1, 0.45, 0.65), 1.5)

func _open_gates() -> void:
	var kinds := ["bless", "bless", "gold", "heal", "potion"]
	kinds.shuffle()
	var used := []
	for ex in place.exits:
		var g: Node3D = ex.gate
		g.queue_free()
		var door := Rig.prop("dungeon", "wall_doorway")
		door.position = ex.at
		place.node.add_child(door)
		var kind: String = kinds.filter(func(k): return k not in used)[0]
		used.append(kind)
		ex.reward = kind
		var col: Color = REWARDS[kind][1]
		var glow := Fx.orb(1.0, col)
		glow.position = ex.at + Vector3(0, 1.5, 0.6)
		glow.scale = Vector3(1.2, 1.6, 0.2)
		place.node.add_child(glow)
		var l := Label3D.new()
		l.text = REWARDS[kind][0] if boss == null else "PRÓXIMO ANDAR"
		l.font_size = 120
		l.outline_size = 24
		l.modulate = col
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = ex.at + Vector3(0, 4.8, 0.6)
		l.pixel_size = 0.008
		place.node.add_child(l)

func _take_blessing(b: Dictionary) -> void:
	run.bless[b.id] = run.bless.get(b.id, 0) + 1
	match b.id:
		"hp":
			hero.max_hp = max_hp()
			hero.hp = minf(hero.max_hp, hero.hp + 30)
		"potion":
			run.potions += 1
	hero.max_hp = max_hp()
	Fx.burst(world, hero.global_position + Vector3(0, 1, 0), b.col, 24, 5.0)
	number(hero.global_position + Vector3(0, 2.4, 0), b.name, b.col)

func end_run(win: bool) -> void:
	if not in_run():
		return
	var gold: int = run.gold
	var xp: int = run.xp_run
	var floor_reached: int = run.floor + 1
	if autoplay:
		print("RUN %s %s floor %d room %d gold %d xp %d" % [save.hero, "WIN" if win else "DIED", run.floor + 1, run.room, run.gold, run.xp_run])
	save.gold += gold
	save.best = maxi(save.best, floor_reached)
	var before := hero_level(save.hero)
	_add_xp(save.hero, xp)
	var after := hero_level(save.hero)
	run = {}
	_save()
	var title := "VITÓRIA! A COROA É SUA" if win else "VOCÊ CAIU"
	var body := "Ouro ganho: %d (total %d)\nExperiência: %d%s" % [gold, save.gold, xp, "\n%s subiu para o nível %d!" % [Data.HEROES[save.hero].name, after] if after > before else ""]
	ui.transition(func():
		go_hub()
		ui.message(title, body, "VOLTAR À VILA", func(): pass))

# ------------------------------------------------------------------ the village
func interact_label() -> String:
	if in_run() or hero == null:
		return ""
	for s in place.get("stations", []):
		if hero.global_position.distance_to(s.pos) < 3.5:
			return s.label
	return ""

func _interact() -> void:
	if in_run():
		return
	for s in place.get("stations", []):
		if hero.global_position.distance_to(s.pos) < 3.5:
			match s.action:
				"portal":
					start_run()
				"heroes":
					ui.heroes_panel()
				"forge":
					ui.forge_panel()
			return

func choose_hero(id: String) -> bool:
	if not save.unlocked.has(id):
		var cost: int = Data.HEROES[id].unlock
		if save.gold < cost:
			ui.banner("OURO INSUFICIENTE", "Precisa de %d" % cost, Color(1, 0.4, 0.4), 1.5)
			return true
		save.gold -= cost
		save.unlocked.append(id)
		sfx("handleCoins")
	save.hero = id
	_save()
	_spawn_hero(hero.global_position)
	return true

func choose_tint(i: int) -> void:
	save.tint = i
	_save()
	_spawn_hero(hero.global_position)

func buy_upgrade(id: String, cost: int) -> void:
	if save.gold < cost:
		return
	save.gold -= cost
	save.upgrades[id] = int(save.upgrades.get(id, 0)) + 1
	sfx("metalPot1")
	_save()
	hero.max_hp = max_hp()
	hero.hp = hero.max_hp

# ------------------------------------------------------------------ numbers
func _b(id: String) -> int:
	return int(run.get("bless", {}).get(id, 0))

func _u(id: String) -> int:
	return int(save.upgrades.get(id, 0))

func hero_level(id: String) -> int:
	return int(save.levels.get(id, 1))

func max_hp() -> float:
	return Data.HEROES[save.hero].hp * (1.0 + 0.06 * (hero_level(save.hero) - 1)) + 12.0 * _u("vida") + 30.0 * _b("hp")

func dmg_mult() -> float:
	return (1.0 + 0.2 * _b("dmg")) * (1.0 + 0.06 * _u("forca")) * (1.0 + 0.06 * (hero_level(save.hero) - 1))

func gold_mult() -> float:
	return 1.0 + 0.4 * _b("gold") + 0.1 * _u("ganancia")

func stat(k: String) -> float:
	match k:
		"aspd": return 0.15 * _b("aspd")
		"crit": return 0.05 + 0.12 * _b("crit") + 0.04 * _u("sorte")
		"cdr": return minf(0.6, 0.2 * _b("cdr"))
		"speed": return 0.12 * _b("speed")
	return 0.0

func gold_now() -> int:
	return save.gold + int(run.get("gold", 0))

func _add_xp(id: String, xp: int) -> void:
	var lv := hero_level(id)
	var have: int = int(save.xp.get(id, 0)) + xp
	while have >= Data.xp_need(lv):
		have -= Data.xp_need(lv)
		lv += 1
	save.xp[id] = have
	save.levels[id] = lv

# ------------------------------------------------------------------ combat
func damage_enemy(e: Node3D, dmg: float, from: Vector3) -> void:
	if e.dead:
		return
	var crit: bool = crit_next or randf() < stat("crit")
	crit_next = false
	if crit:
		dmg *= 2.0
	e.hurt(dmg, from)
	number(e.global_position + Vector3(0, 2.0 * e.scale_k, 0), str(int(dmg)), Color(1, 0.9, 0.3) if crit else Color.WHITE, crit)
	Fx.burst(world, e.global_position + Vector3(0, 1.0 * e.scale_k, 0), Color(1, 0.85, 0.6), 5, 3.0, 0.08)
	sfx(["impactPunch_medium_000", "impactPunch_medium_001"].pick_random())
	if _b("leech") > 0:
		hero.hp = minf(hero.max_hp, hero.hp + 2.0 * _b("leech"))
	if _b("burn") > 0:
		e.burn_t = 3.0 * _b("burn")
	if _b("chain") > 0 and randf() < 0.25 * _b("chain"):
		var jumps := 0
		for o in enemies:
			if o != e and not o.dead and o.global_position.distance_to(e.global_position) < 7.0 and jumps < 2:
				jumps += 1
				_lightning(e.global_position, o.global_position)
				o.hurt(dmg * 0.5, e.global_position)
				if o.hp <= 0.0:
					kill_enemy(o)
	if crit:
		_hitstop(0.06)
	if e.hp <= 0.0:
		kill_enemy(e)

func _lightning(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 7:
		var p := a.lerp(b, k / 6.0) + Vector3(randf_range(-0.3, 0.3), 1.2 + randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		im.surface_add_vertex(p)
	im.surface_end()
	mi.mesh = im
	mi.material_override = Fx.glow(Color(0.6, 0.9, 1))
	world.add_child(mi)
	get_tree().create_timer(0.15).timeout.connect(mi.queue_free)

func _hitstop(secs: float) -> void:
	Engine.time_scale = 0.1
	get_tree().create_timer(secs, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func kill_enemy(e: Node3D) -> void:
	if e.dead:
		return
	e.die()
	enemies.erase(e)  # the body stays a moment to fall apart, but nothing targets it any more
	var g := int(e.gold * gold_mult())
	if in_run():
		run.xp_run += e.xp
	for k in mini(g, 6):
		_coin(e.global_position, int(ceil(float(g) / mini(g, 6))) if k == 0 else 0)
	if e == boss:
		shake(1.0)
		Fx.burst(world, e.global_position + Vector3(0, 2, 0), Color(1, 0.6, 0.2), 60, 9.0, 0.2)

var coins: Array = []

func _coin(at: Vector3, value: int) -> void:
	var c := Rig.prop("dungeon", "coin")
	c.scale = Vector3.ONE * 1.5
	world.add_child(c)
	c.global_position = at + Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1))
	coins.append({"node": c, "t": 0.0, "value": value})

func _update_pickups(dt: float) -> void:
	for c in coins.duplicate():
		if not is_instance_valid(c.node):
			coins.erase(c)
			continue
		c.t += dt
		c.node.rotation.y += dt * 6.0
		if c.t > 0.5:  # then they fly to you
			var to: Vector3 = hero.global_position + Vector3(0, 1, 0) - c.node.global_position
			c.node.global_position += to.normalized() * minf(to.length(), dt * 18.0)
			if to.length() < 0.5:
				if in_run():
					run.gold += c.value
				coins.erase(c)
				c.node.queue_free()
				sfx("handleCoins")

func hurt_hero(dmg: float, from: Vector3) -> void:
	if hero.dead or hero.invuln > 0.0:
		return
	var before: float = hero.hp
	hero.hurt(dmg, from)
	if hero.hp < before:
		number(hero.global_position + Vector3(0, 2.2, 0), str(int(before - hero.hp)), Color(1, 0.3, 0.3))
		shake(0.3)
		sfx("impactSoft_heavy_000")

func thorns(e: Node3D) -> void:
	if _b("thorns") > 0 and not e.dead:
		damage_enemy(e, 15.0 * _b("thorns"), hero.global_position)

func drink() -> void:
	if not in_run() or run.potions <= 0 or hero.hp >= hero.max_hp:
		return
	run.potions -= 1
	hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.4)
	hero.ap.play("Use_Item", 0.1, 1.6)
	Fx.burst(world, hero.global_position + Vector3(0, 1, 0), Color(1, 0.4, 0.6), 20, 3.0)
	sfx("metalPot1")

# ------------------------------------------------------------------ feedback
func number(pos: Vector3, text: String, col: Color, big := false) -> void:
	Fx.number(world, pos, text, col, big)

func banner(t: String, sub: String, col: Color) -> void:
	ui.banner(t, sub, col)

func shake(a: float) -> void:
	shake_t = maxf(shake_t, a)

# one looping track at a time (assets/music, CC0)
func music(name: String) -> void:
	if name == music_now:
		return
	music_now = name
	var st = load("res://assets/music/%s.ogg" % name)
	st.loop = true
	music_player.stream = st
	music_player.play()

func sfx(name: String) -> void:
	var path := "res://assets/sfx/%s.ogg" % {"swing": ["knifeSlice", "knifeSlice2"].pick_random(), "dodge": "cloth1", "skill": "drawKnife1"}.get(name, name)
	if not ResourceLoader.exists(path):
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = load(path)
			p.volume_db = -6.0
			p.pitch_scale = randf_range(0.92, 1.08)
			p.play()
			return

# ------------------------------------------------------------------ save
func _save() -> void:
	if autoplay:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH) or autoplay:
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary:
		return  # unreadable: start fresh rather than crash
	for k in d:
		save[k] = d[k]
	save.gold = int(save.gold)
	save.tint = int(save.tint)
	if not Data.HEROES.has(save.hero):
		save.hero = "knight"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()

# ------------------------------------------------------------------ test robot (COROA_AUTOPLAY=1)
func _autoplay() -> void:
	if OS.get_environment("COROA_HERO") != "" and save.hero != OS.get_environment("COROA_HERO"):
		save.hero = OS.get_environment("COROA_HERO")
		save.unlocked.append(save.hero)
		_spawn_hero(hero.global_position)
	if in_run() and hero.hp < hero.max_hp * 0.4:
		ui.fresh["potion"] = true
	if not in_run():
		if ui.fade.color.a == 0.0:
			start_run()
		return
	var tg: Node3D = hero.target(30.0)
	var v := Vector2.ZERO
	var right := Vector3(1, 0, -1).normalized()
	var up := Vector3(-1, 0, -1).normalized()
	for e in enemies:  # dodge away from a strike that is coming (the red ring), like a player would
		if not e.dead and e.state == "windup" and e.t > 0.25 and e.global_position.distance_to(hero.global_position) < e.def.range * e.scale_k + 1.5:
			var away: Vector3 = hero.global_position - e.global_position
			ui.stick_vec = Vector2(away.dot(right), -away.dot(up)).normalized()
			ui.fresh["dodge"] = true
			return
	if tg != null:
		var d: Vector3 = tg.global_position - hero.global_position
		var reach: float = Data.HEROES[save.hero].attack[0].range
		if d.length() > minf(reach, 10.0) * 0.8:
			v = Vector2(d.dot(right), -d.dot(up)).normalized()
		else:
			ui.fresh["attack"] = true
		if randf() < 0.02:
			ui.fresh["skill%d" % randi_range(0, 2)] = true
	elif cleared and place.has("exits"):
		var d2: Vector3 = place.exits[0].pos - hero.global_position
		v = Vector2(d2.dot(right), -d2.dot(up)).normalized()
	ui.stick_vec = v
	if ui.panel != null:
		pass
