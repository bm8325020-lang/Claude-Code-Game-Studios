# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is exploring an island and farming monsters with Seed skills fun on a phone?
# Date: 2026-10-21
extends Node2D

const T := 16  # tile size in world pixels
const MAP_W := 64
const MAP_H := 40
const ZOOM := 4.0
const SAFE_POINT := Vector2(6.5 * T, 20.5 * T)

# Atlas indices (Kenney packed sheets, 12 columns)
const TOWN_GRASS := [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2]
const TOWN_DIRT := 25
const TOWN_TREES := [4, 16, 28, 3, 15, 27, 5]
const TOWN_MUSHROOM := 29
const TOWN_SIGN := 83
const TOWN_COIN := 93
const TOWN_STONE_FLOOR := 109
const DUN_SAND := [48, 49, 48, 50, 51]
const DUN_KNIGHT := 97
const DUN_CHEST := 89
const DUN_POTION := 115

const MONSTERS := {
	"slime": {"name": "Slime", "sprite": 108, "hp": 30, "dmg": 6, "speed": 28, "xp": 6, "gold": 3, "lvl": 1},
	"bat": {"name": "Morcego", "sprite": 120, "hp": 45, "dmg": 9, "speed": 46, "xp": 11, "gold": 5, "lvl": 3},
	"spider": {"name": "Aranha", "sprite": 122, "hp": 80, "dmg": 14, "speed": 40, "xp": 20, "gold": 8, "lvl": 5},
	"ghost": {"name": "Fantasma", "sprite": 121, "hp": 120, "dmg": 18, "speed": 30, "xp": 34, "gold": 12, "lvl": 8, "ranged": true},
	"boss": {"name": "Rei Caranguejo", "sprite": 110, "hp": 1400, "dmg": 26, "speed": 24, "xp": 400, "gold": 150, "lvl": 12, "boss": true},
	"golden": {"name": "Slime Dourado", "sprite": 108, "hp": 60, "dmg": 4, "speed": 34, "xp": 40, "gold": 40, "lvl": 2, "golden": true},
}
const ZONES := [
	{"name": "Praia", "x0": 0, "x1": 14, "spawns": ["slime"], "count": 9},
	{"name": "Campina", "x0": 14, "x1": 32, "spawns": ["slime", "bat", "bat"], "count": 12},
	{"name": "Floresta", "x0": 32, "x1": 48, "spawns": ["spider", "bat"], "count": 12},
	{"name": "Ruínas", "x0": 48, "x1": 64, "spawns": ["ghost"], "count": 9},
]
const SEEDS := {
	"fire": {"name": "Semente de Fogo", "color": Color(1.0, 0.45, 0.1), "skills": ["Bola de Fogo", "Anel de Chamas", "Meteoro"], "cd": [1.1, 5.0, 9.0]},
	"ice": {"name": "Semente de Gelo", "color": Color(0.35, 0.9, 1.0), "skills": ["Estilhaços", "Nova Congelante", "Nevasca"], "cd": [0.9, 6.0, 10.0]},
}

var town_tex: Texture2D
var dun_tex: Texture2D
var ground: TileMapLayer
var decor: TileMapLayer
var cam: Camera2D
var fx: Node2D
var ui: CanvasLayer
var ui_draw: Control
var joystick: Control
var buttons := {}

# Player
var player: Sprite2D
var p_level := 1
var p_xp := 0.0
var p_hp := 100.0
var p_face := Vector2.RIGHT
var p_attack_cd := 0.0
var p_dodge_t := 0.0
var p_dodge_cd := 0.0
var p_dodge_dir := Vector2.RIGHT
var p_hurt_t := 0.0
var p_dead_t := 0.0
var gold_carried := 0
var gold_banked := 0
var potions := 0
var seed := ""
var seed_level := 1
var seed_xp := 0.0
var skill_cd := [0.0, 0.0, 0.0]
var seeds_owned: Array = []

var monsters: Array = []
var pickups: Array = []
var projectiles: Array = []
var effects: Array = []
var floaters: Array = []
var chests: Array = []
var banner := ""
var banner_t := 0.0
var banner_col := Color.WHITE
var flash_t := 0.0
var flash_col := Color.WHITE
var shake := 0.0
var slowmo_t := 0.0
var golden_spawned := false
var boss_respawn_t := -1.0
var kills := 0
var play_time := 0.0
var zone_name := ""
var autoplay := OS.get_environment("SEMENTES_AUTOPLAY") == "1"  # playtest robot for screenshots only

func _ready() -> void:
	randomize()
	town_tex = load("res://assets/town.png")
	dun_tex = load("res://assets/dungeon.png")
	_build_map()
	fx = Node2D.new()
	fx.z_index = 5
	fx.draw.connect(_draw_fx)
	add_child(fx)
	player = _sprite(dun_tex, DUN_KNIGHT)
	player.position = SAFE_POINT + Vector2(24, 0)
	player.z_index = 3
	add_child(player)
	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * T
	cam.limit_bottom = MAP_H * T
	player.add_child(cam)
	for z in ZONES:
		for i in z.count:
			_spawn_monster(z.spawns.pick_random(), _random_point_in_zone(z))
	_spawn_monster("boss", Vector2(58 * T, 20 * T))
	for c in [Vector2(10, 8), Vector2(22, 31), Vector2(28, 6), Vector2(40, 33), Vector2(44, 9), Vector2(55, 34)]:
		var s := _sprite(dun_tex, DUN_CHEST)
		s.position = c * T
		s.z_index = 1
		add_child(s)
		chests.append({"node": s, "open": false})
	_build_ui()
	_show_banner("Ilha das Sementes", Color(1, 0.9, 0.6), 3.0)
	if OS.get_environment("SEMENTES_DEBUG_SEED") != "":
		seed = OS.get_environment("SEMENTES_DEBUG_SEED")

# ---------------------------------------------------------------- World
func _build_map() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	for tex in [town_tex, dun_tex]:
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(T, T)
		for y in 11:
			for x in 12:
				src.create_tile(Vector2i(x, y))
		ts.add_source(src)
	ground = TileMapLayer.new()
	ground.tile_set = ts
	add_child(ground)
	decor = TileMapLayer.new()
	decor.tile_set = ts
	decor.z_index = 2
	add_child(decor)
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			if x < 13:
				_put(ground, cell, 1, DUN_SAND.pick_random())
			elif x >= 49:
				_put(ground, cell, 0, TOWN_STONE_FLOOR if randf() < 0.85 else 43)
			else:
				_put(ground, cell, 0, TOWN_GRASS.pick_random())
			if y == 20 and x >= 8 and x < 58:
				_put(ground, cell, 0, TOWN_DIRT)
			# decoration
			var near_path: bool = abs(y - 20) < 2
			if x >= 13 and x < 49 and not near_path and (y < 2 or y > MAP_H - 3 or randf() < (0.22 if x >= 32 else 0.04)):
				_put(decor, cell, 0, TOWN_TREES.pick_random())
			elif x >= 13 and x < 49 and not near_path and randf() < 0.01:
				_put(decor, cell, 0, TOWN_MUSHROOM)
	_put(decor, Vector2i(6, 19), 0, TOWN_SIGN)

func _put(layer: TileMapLayer, cell: Vector2i, source: int, idx: int) -> void:
	layer.set_cell(cell, source, Vector2i(idx % 12, idx / 12))

func _sprite(tex: Texture2D, idx: int) -> Sprite2D:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2((idx % 12) * T, (idx / 12) * T, T, T)
	var s := Sprite2D.new()
	s.texture = a
	return s

func _random_point_in_zone(z: Dictionary) -> Vector2:
	return Vector2(randf_range(z.x0 + 1, z.x1 - 1) * T, randf_range(3, MAP_H - 3) * T)

func _zone_at(pos: Vector2) -> Dictionary:
	for z in ZONES:
		if pos.x < z.x1 * T:
			return z
	return ZONES[-1]

# ---------------------------------------------------------------- Monsters
func _spawn_monster(kind: String, pos: Vector2) -> void:
	var d: Dictionary = MONSTERS[kind]
	var s := _sprite(dun_tex, d.sprite)
	s.position = pos
	s.z_index = 2
	if d.get("boss", false):
		s.scale = Vector2(2.5, 2.5)
	if d.get("golden", false):
		s.modulate = Color(2.2, 1.8, 0.3)
		s.scale = Vector2(1.3, 1.3)
	add_child(s)
	monsters.append({"kind": kind, "node": s, "hp": float(d.hp), "max": float(d.hp), "home": pos, "wander": pos,
		"atk_cd": 0.0, "shoot_cd": 2.0, "slow_t": 0.0, "freeze_t": 0.0, "hit_t": 0.0, "kb": Vector2.ZERO,
		"boss_t": 3.0, "summon_t": 7.0, "charge": 0.0, "charge_dir": Vector2.ZERO, "tele": 0.0})

func _update_monsters(dt: float) -> void:
	var ppos := player.position
	for m in monsters:
		var d: Dictionary = MONSTERS[m.kind]
		var n: Sprite2D = m.node
		m.hit_t = max(0.0, m.hit_t - dt)
		m.slow_t = max(0.0, m.slow_t - dt)
		m.freeze_t = max(0.0, m.freeze_t - dt)
		n.modulate = Color(2.2, 1.8, 0.3) if d.get("golden", false) else Color.WHITE
		if m.hit_t > 0:
			n.modulate = Color(3, 3, 3)
		elif m.freeze_t > 0:
			n.modulate = Color(0.5, 1.2, 2.0)
		n.position += m.kb * dt
		m.kb = m.kb.move_toward(Vector2.ZERO, 600 * dt)
		if m.freeze_t > 0:
			continue
		var spd: float = d.speed * (0.45 if m.slow_t > 0 else 1.0)
		var to_p := ppos - n.position
		var dist := to_p.length()
		var aggro := 120.0 if d.get("boss", false) else 70.0
		if d.get("golden", false):
			# the golden slime runs away
			if dist < 60 and m.hit_t <= 0 and m.max - m.hp < 1:
				n.position -= to_p.normalized() * spd * dt
				n.position = n.position.clamp(Vector2(16, 16), Vector2(MAP_W * T - 16, MAP_H * T - 16))
			continue
		if d.get("boss", false):
			_update_boss(m, dt, to_p, dist)
			continue
		if dist < aggro and p_dead_t <= 0:
			if d.get("ranged", false) and dist < 80:
				m.shoot_cd -= dt
				if m.shoot_cd <= 0:
					m.shoot_cd = 2.2
					projectiles.append({"pos": n.position, "vel": to_p.normalized() * 70.0, "enemy": true, "dmg": d.dmg, "t": 3.0, "kind": "orb"})
				if dist > 40:
					n.position += to_p.normalized() * spd * dt
			else:
				n.position += to_p.normalized() * spd * dt
		else:
			if n.position.distance_to(m.wander) < 3 or randf() < 0.005:
				m.wander = m.home + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			n.position += (m.wander - n.position).normalized() * spd * 0.4 * dt
		m.atk_cd = max(0.0, m.atk_cd - dt)
		if dist < 11 and m.atk_cd <= 0:
			m.atk_cd = 0.9
			_hurt_player(d.dmg * (1.0 + 0.1 * (d.lvl - 1)), d.name)
		n.flip_h = to_p.x < 0

func _update_boss(m: Dictionary, dt: float, to_p: Vector2, dist: float) -> void:
	var d: Dictionary = MONSTERS["boss"]
	var n: Sprite2D = m.node
	if m.charge > 0:
		m.charge -= dt
		n.position += m.charge_dir * 170 * dt
		if dist < 22:
			_hurt_player(d.dmg * 1.5, "Investida do Rei")
		return
	if m.tele > 0:
		m.tele -= dt
		if m.tele <= 0:
			m.charge = 0.55
		return
	if dist < 140 and p_dead_t <= 0:
		n.position += to_p.normalized() * d.speed * dt
		m.boss_t -= dt
		m.summon_t -= dt
		if m.boss_t <= 0:
			m.boss_t = 3.5
			m.tele = 0.6
			m.charge_dir = to_p.normalized()
		if m.summon_t <= 0:
			m.summon_t = 8.0
			for i in 3:
				_spawn_monster("ghost" if randf() < 0.3 else "spider", n.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
			_float("CHAMOU AJUDA!", n.position + Vector2(0, -30), Color(1, 0.4, 0.4))
	m.atk_cd = max(0.0, m.atk_cd - dt)
	if dist < 20 and m.atk_cd <= 0:
		m.atk_cd = 1.0
		_hurt_player(d.dmg, "Garra do Rei")

func _damage_monster(m: Dictionary, amount: float, from: Vector2, knock := 120.0, element := "") -> void:
	if m.hp <= 0:
		return
	var crit := randf() < 0.12
	if crit:
		amount *= 1.8
	m.hp -= amount
	m.hit_t = 0.08
	var n: Sprite2D = m.node
	if not MONSTERS[m.kind].get("boss", false):
		m.kb = (n.position - from).normalized() * knock
	var col := Color(1, 1, 0.4) if crit else Color.WHITE
	if element != "":
		col = SEEDS[element].color.lightened(0.3)
		seed_xp += amount * 0.15
	_float(("%d!" if crit else "%d") % int(amount), n.position + Vector2(randf_range(-6, 6), -12), col, 1.4 if crit else 1.0)
	if m.hp <= 0:
		_kill_monster(m)

func _kill_monster(m: Dictionary) -> void:
	var d: Dictionary = MONSTERS[m.kind]
	var n: Sprite2D = m.node
	kills += 1
	_gain_xp(d.xp)
	var coins: int = int(d.gold * randf_range(0.8, 1.3))
	for i in clampi(coins / 3 + 1, 1, 25):
		_drop("coin", n.position, maxi(1, coins / (coins / 3 + 1)))
	if randf() < 0.12 or d.get("boss", false):
		_drop("potion", n.position, 1)
	if d.get("golden", false):
		_drop("seed_fire", n.position, 1)
	if d.get("boss", false):
		_drop("seed_ice", n.position, 1)
		boss_respawn_t = 60.0
		shake = 6.0
		slowmo_t = 0.6
		_show_banner("REI CARANGUEJO DERROTADO!", Color(1, 0.85, 0.3), 3.0)
	effects.append({"kind": "poof", "pos": n.position, "t": 0.3, "max": 0.3, "r": 10.0 * n.scale.x, "col": Color(1, 1, 1)})
	n.queue_free()
	monsters.erase(m)
	if not d.get("boss", false) and not d.get("golden", false):
		var z := _zone_at(m.home)
		get_tree().create_timer(6.0).timeout.connect(func(): _spawn_monster(z.spawns.pick_random(), _random_point_in_zone(z)))

func _nearest_monster(pos: Vector2, max_dist: float) -> Variant:
	var best = null
	var bd := max_dist
	for m in monsters:
		var dd: float = pos.distance_to(m.node.position)
		if dd < bd:
			bd = dd
			best = m
	return best

# ---------------------------------------------------------------- Player
func _autoplay_input() -> Vector2:
	var target = _nearest_monster(player.position, 400.0)
	if target == null:
		return Vector2.RIGHT
	var to_t: Vector2 = target.node.position - player.position
	return to_t.normalized() if to_t.length() > 16 else Vector2.ZERO

func _update_player(dt: float) -> void:
	if p_dead_t > 0:
		p_dead_t -= dt
		if p_dead_t <= 0:
			player.visible = true
			player.position = SAFE_POINT + Vector2(24, 0)
			p_hp = _max_hp()
		return
	p_hurt_t = max(0.0, p_hurt_t - dt)
	p_attack_cd = max(0.0, p_attack_cd - dt)
	p_dodge_cd = max(0.0, p_dodge_cd - dt)
	for i in 3:
		skill_cd[i] = max(0.0, skill_cd[i] - dt)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if autoplay:
		input = _autoplay_input()
	if p_dodge_t > 0:
		p_dodge_t -= dt
		player.position += p_dodge_dir * 230 * dt
	else:
		if input.length() > 0.1:
			p_face = input.normalized()
			player.position += input * 78 * dt
			player.flip_h = input.x < 0
		if Input.is_action_just_pressed("dodge") and p_dodge_cd <= 0:
			p_dodge_t = 0.22
			p_dodge_cd = 0.7
			p_dodge_dir = p_face
		if (Input.is_action_pressed("attack") or autoplay) and p_attack_cd <= 0:
			_basic_attack()
		for i in 3:
			if Input.is_action_just_pressed("skill_%d" % (i + 1)) or (autoplay and randf() < 0.02):
				_cast_skill(i)
	player.position = player.position.clamp(Vector2(8, 8), Vector2(MAP_W * T - 8, MAP_H * T - 8))
	player.modulate = Color(1, 1, 1, 0.5) if p_dodge_t > 0 else (Color(3, 1, 1) if p_hurt_t > 0.3 else Color.WHITE)
	# safe point banks gold
	if player.position.distance_to(SAFE_POINT) < 26 and gold_carried > 0:
		gold_banked += gold_carried
		_float("+%d guardado" % gold_carried, player.position + Vector2(0, -16), Color(0.6, 1, 0.6))
		gold_carried = 0
	# chests
	for c in chests:
		if not c.open and player.position.distance_to(c.node.position) < 14:
			c.open = true
			c.node.modulate = Color(0.5, 0.5, 0.5)
			for i in 12:
				_drop("coin", c.node.position, 4 + p_level)
			_drop("potion", c.node.position, 1)
			_float("BAÚ!", c.node.position + Vector2(0, -14), Color(1, 0.85, 0.3), 1.4)
	var z := _zone_at(player.position)
	if z.name != zone_name:
		zone_name = z.name
		_show_banner(zone_name, Color(0.9, 0.95, 1), 1.6)
	if seed_xp >= 40.0 * seed_level:
		seed_xp -= 40.0 * seed_level
		seed_level += 1
		_show_banner("%s nível %d!" % [SEEDS[seed].name, seed_level], SEEDS[seed].color, 2.0)

func _max_hp() -> float:
	return 100.0 + 22.0 * (p_level - 1)

func _atk() -> float:
	return 12.0 + 4.0 * (p_level - 1)

func _seed_mult() -> float:
	return 1.0 + 0.15 * (seed_level - 1)

func _basic_attack() -> void:
	p_attack_cd = 0.3
	var target = _nearest_monster(player.position, 30.0)
	var dir := p_face
	if target != null:
		dir = (target.node.position - player.position).normalized()
		p_face = dir
		player.flip_h = dir.x < 0
	effects.append({"kind": "slash", "pos": player.position + dir * 10, "dir": dir, "t": 0.12, "max": 0.12, "col": Color(1, 1, 0.85)})
	for m in monsters.duplicate():
		var to_m: Vector2 = m.node.position - player.position
		if to_m.length() < 26 + (12 if MONSTERS[m.kind].get("boss", false) else 0) and (to_m.length() < 8 or abs(dir.angle_to(to_m)) < 1.1):
			_damage_monster(m, _atk() * randf_range(0.9, 1.1), player.position)

func _cast_skill(i: int) -> void:
	if seed == "" or skill_cd[i] > 0:
		return
	skill_cd[i] = SEEDS[seed].cd[i]
	var target = _nearest_monster(player.position, 140.0)
	var aim: Vector2 = p_face if target == null else (target.node.position - player.position).normalized()
	var tpos: Vector2 = player.position + p_face * 50 if target == null else target.node.position
	var col: Color = SEEDS[seed].color
	var mult := _seed_mult() * _atk()
	match [seed, i]:
		["fire", 0]:
			projectiles.append({"pos": player.position, "vel": aim * 190.0, "enemy": false, "dmg": 2.2 * mult, "t": 1.2, "kind": "fireball", "radius": 22.0})
		["fire", 1]:
			_area(player.position, 42.0, 3.0 * mult, "fire", 260.0)
			effects.append({"kind": "ring", "pos": player.position, "t": 0.35, "max": 0.35, "r": 42.0, "col": col})
			shake = 3.0
		["fire", 2]:
			effects.append({"kind": "meteor", "pos": tpos, "t": 0.6, "max": 0.6, "r": 46.0, "col": col, "dmg": 6.0 * mult})
		["ice", 0]:
			for a in [-0.25, 0.0, 0.25]:
				projectiles.append({"pos": player.position, "vel": aim.rotated(a) * 210.0, "enemy": false, "dmg": 1.6 * mult, "t": 0.9, "kind": "shard", "radius": 0.0})
		["ice", 1]:
			_area(player.position, 46.0, 2.0 * mult, "ice", 80.0, 2.0)
			effects.append({"kind": "ring", "pos": player.position, "t": 0.4, "max": 0.4, "r": 46.0, "col": col})
		["ice", 2]:
			effects.append({"kind": "blizzard", "pos": tpos, "t": 3.0, "max": 3.0, "r": 52.0, "col": col, "dmg": 0.9 * mult, "tick": 0.0})

func _area(center: Vector2, r: float, dmg: float, element: String, knock: float, freeze := 0.0) -> void:
	for m in monsters.duplicate():
		if m.node.position.distance_to(center) < r:
			if freeze > 0:
				m.freeze_t = freeze
			if element == "ice":
				m.slow_t = 2.5
			_damage_monster(m, dmg * randf_range(0.9, 1.1), center, knock, element)

func _hurt_player(amount: float, src: String) -> void:
	if p_dodge_t > 0 or p_hurt_t > 0 or p_dead_t > 0:
		return
	p_hp -= amount
	p_hurt_t = 0.5
	shake = 4.0
	_float("-%d" % int(amount), player.position + Vector2(0, -14), Color(1, 0.3, 0.3))
	if p_hp <= 0:
		_die(src)
	elif p_hp < _max_hp() * 0.3 and potions > 0:
		potions -= 1
		p_hp = min(_max_hp(), p_hp + _max_hp() * 0.5)
		_float("POÇÃO!", player.position + Vector2(0, -22), Color(1, 0.4, 0.5))

func _die(src: String) -> void:
	p_dead_t = 2.5
	player.visible = false
	var lost := gold_carried
	gold_carried = 0
	potions = 0
	flash_t = 0.6
	flash_col = Color(0.6, 0, 0)
	_show_banner("VOCÊ MORREU — %s\nPerdeu %d de ouro e as poções. Guarde ouro na placa da praia!" % [src, lost], Color(1, 0.5, 0.5), 3.5)

func _gain_xp(amount: float) -> void:
	p_xp += amount
	while p_xp >= _xp_needed():
		p_xp -= _xp_needed()
		p_level += 1
		p_hp = _max_hp()
		flash_t = 0.3
		flash_col = Color(1, 0.95, 0.6)
		_show_banner("NÍVEL %d!" % p_level, Color(1, 0.95, 0.5), 1.6)
		effects.append({"kind": "ring", "pos": player.position, "t": 0.5, "max": 0.5, "r": 30.0, "col": Color(1, 0.95, 0.6)})
	if p_level >= 2 and not golden_spawned:
		golden_spawned = true
		_spawn_monster("golden", Vector2(9 * T, 12 * T))
		_show_banner("Um SLIME DOURADO apareceu na praia!", Color(1, 0.85, 0.2), 3.0)

func _xp_needed() -> float:
	return 20.0 * pow(p_level, 1.5)

# ---------------------------------------------------------------- Drops
func _drop(kind: String, pos: Vector2, value: int) -> void:
	var node: Sprite2D
	match kind:
		"coin":
			node = _sprite(town_tex, TOWN_COIN)
			node.scale = Vector2(0.6, 0.6)
		"potion":
			node = _sprite(dun_tex, DUN_POTION)
			node.scale = Vector2(0.8, 0.8)
		_:
			node = Sprite2D.new()
	node.position = pos
	node.z_index = 2
	add_child(node)
	var vel := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(30, 70)
	pickups.append({"kind": kind, "node": node, "value": value, "vel": vel, "t": 0.0})

func _update_pickups(dt: float) -> void:
	for p in pickups.duplicate():
		var n: Sprite2D = p.node
		p.t += dt
		n.position += p.vel * dt
		p.vel = p.vel.move_toward(Vector2.ZERO, 150 * dt)
		var to_p := player.position - n.position
		var magnet := 34.0 if p.kind == "coin" else 18.0
		if p.t > 0.4 and to_p.length() < magnet and p_dead_t <= 0:
			n.position += to_p.normalized() * 160 * dt
		if p.t > 0.3 and to_p.length() < 7 and p_dead_t <= 0:
			_collect(p)
		elif p.kind.begins_with("seed"):
			queue_redraw()

func _collect(p: Dictionary) -> void:
	p.node.queue_free()
	pickups.erase(p)
	match p.kind:
		"coin":
			gold_carried += p.value
		"potion":
			potions += 1
			_float("+Poção", player.position + Vector2(0, -14), Color(1, 0.5, 0.6))
		"seed_fire", "seed_ice":
			var s: String = "fire" if p.kind == "seed_fire" else "ice"
			if not seeds_owned.has(s):
				seeds_owned.append(s)
			seed = s
			seed_level = 1
			seed_xp = 0.0
			skill_cd = [0.0, 0.0, 0.0]
			slowmo_t = 1.0
			flash_t = 0.8
			flash_col = SEEDS[s].color
			shake = 5.0
			_show_banner("%s!\nNovos poderes: %s" % [SEEDS[s].name.to_upper(), ", ".join(SEEDS[s].skills)], SEEDS[s].color, 4.0)

# ---------------------------------------------------------------- Projectiles & effects
func _update_projectiles(dt: float) -> void:
	for pr in projectiles.duplicate():
		pr.t -= dt
		pr.pos += pr.vel * dt
		var done: bool = pr.t <= 0
		if pr.enemy:
			if pr.pos.distance_to(player.position) < 8:
				_hurt_player(pr.dmg, "Bola Fantasma")
				done = true
		else:
			for m in monsters.duplicate():
				if pr.pos.distance_to(m.node.position) < 10 * m.node.scale.x:
					if pr.kind == "fireball":
						_area(pr.pos, pr.radius, pr.dmg, "fire", 160.0)
						effects.append({"kind": "ring", "pos": pr.pos, "t": 0.3, "max": 0.3, "r": pr.radius, "col": SEEDS.fire.color})
						shake = 2.0
					else:
						m.slow_t = 2.0
						_damage_monster(m, pr.dmg, pr.pos, 60.0, "ice")
					done = true
					break
		if done:
			projectiles.erase(pr)

func _update_effects(dt: float) -> void:
	for e in effects.duplicate():
		e.t -= dt
		if e.kind == "meteor" and e.t <= 0:
			_area(e.pos, e.r, e.dmg, "fire", 300.0)
			effects.append({"kind": "ring", "pos": e.pos, "t": 0.45, "max": 0.45, "r": e.r, "col": e.col})
			shake = 7.0
		if e.kind == "blizzard":
			e.tick -= dt
			if e.tick <= 0:
				e.tick = 0.3
				_area(e.pos, e.r, e.dmg, "ice", 0.0)
		if e.t <= 0:
			effects.erase(e)
	for f in floaters:
		f.t -= dt
		f.pos.y -= 18 * dt
	floaters = floaters.filter(func(f): return f.t > 0)

func _float(text: String, pos: Vector2, col: Color, size := 1.0) -> void:
	floaters.append({"text": text, "pos": pos, "t": 0.9, "col": col, "size": size})

func _show_banner(text: String, col: Color, t: float) -> void:
	banner = text
	banner_col = col
	banner_t = t

# ---------------------------------------------------------------- Loop
func _physics_process(delta: float) -> void:
	var dt := delta
	if slowmo_t > 0:
		slowmo_t -= delta
		dt *= 0.3
	play_time += delta
	_update_player(dt)
	_update_monsters(dt)
	_update_projectiles(dt)
	_update_effects(dt)
	_update_pickups(dt)
	if boss_respawn_t > 0:
		boss_respawn_t -= dt
		if boss_respawn_t <= 0:
			_spawn_monster("boss", Vector2(58 * T, 20 * T))
	banner_t = max(0.0, banner_t - delta)
	flash_t = max(0.0, flash_t - delta)
	shake = max(0.0, shake - 20 * delta)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	fx.queue_redraw()
	ui_draw.queue_redraw()

func _draw_fx() -> void:
	# safe point glow
	fx.draw_circle(SAFE_POINT, 26, Color(0.4, 1, 0.5, 0.12))
	fx.draw_arc(SAFE_POINT, 26, 0, TAU, 32, Color(0.5, 1, 0.6, 0.5), 1.0)
	for p in pickups:
		if p.kind.begins_with("seed"):
			var col: Color = SEEDS["fire" if p.kind == "seed_fire" else "ice"].color
			var pos: Vector2 = p.node.position
			var pulse := 0.5 + 0.5 * sin(play_time * 6.0)
			fx.draw_circle(pos, 12 + 3 * pulse, Color(col, 0.25))
			fx.draw_circle(pos, 5, col)
			fx.draw_circle(pos + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.9))
			fx.draw_line(pos + Vector2(0, -5), pos + Vector2(3, -9), Color(0.3, 0.9, 0.3), 1.5)
	for e in effects:
		var k: float = 1.0 - e.t / e.max
		match e.kind:
			"slash":
				fx.draw_arc(e.pos, 10, e.dir.angle() - 1.0, e.dir.angle() + 1.0, 12, Color(e.col, 1.0 - k), 3.0)
			"ring":
				fx.draw_circle(e.pos, e.r * (0.4 + 0.6 * k), Color(e.col, 0.35 * (1.0 - k)))
				fx.draw_arc(e.pos, e.r * (0.4 + 0.6 * k), 0, TAU, 40, Color(e.col, 1.0 - k), 2.0)
			"poof":
				fx.draw_circle(e.pos, e.r * (0.5 + k), Color(1, 1, 1, 0.5 * (1.0 - k)))
			"meteor":
				fx.draw_arc(e.pos, e.r, 0, TAU, 40, Color(e.col, 0.7), 1.5)
				fx.draw_circle(e.pos, e.r * k, Color(e.col, 0.25))
				var fall: Vector2 = e.pos + Vector2(-60, -120) * (1.0 - k)
				fx.draw_circle(fall, 7, e.col)
				fx.draw_circle(fall, 4, Color(1, 1, 0.7))
			"blizzard":
				fx.draw_circle(e.pos, e.r, Color(e.col, 0.18))
				for i in 10:
					var a := play_time * 2.0 + i * 0.63
					var rr: float = fmod(i * 7.3 + play_time * 30.0, e.r)
					fx.draw_circle(e.pos + Vector2(cos(a), sin(a)) * rr, 1.5, Color(1, 1, 1, 0.8))
	for pr in projectiles:
		match pr.kind:
			"fireball":
				fx.draw_circle(pr.pos, 6, Color(SEEDS.fire.color, 0.4))
				fx.draw_circle(pr.pos, 3.5, Color(1, 0.85, 0.4))
			"shard":
				fx.draw_line(pr.pos - pr.vel.normalized() * 5, pr.pos + pr.vel.normalized() * 3, SEEDS.ice.color, 2.0)
			"orb":
				fx.draw_circle(pr.pos, 4, Color(0.8, 0.5, 1, 0.8))
	for m in monsters:
		var d: Dictionary = MONSTERS[m.kind]
		var n: Sprite2D = m.node
		if d.get("boss", false) and m.tele > 0:
			fx.draw_line(n.position, n.position + m.charge_dir * 95, Color(1, 0.2, 0.3, 0.5), 18.0)
		if m.hp < m.max:
			var w := 14.0 * n.scale.x
			var top := n.position + Vector2(-w / 2, -9 * n.scale.y - 4)
			fx.draw_rect(Rect2(top, Vector2(w, 2)), Color(0, 0, 0, 0.6))
			fx.draw_rect(Rect2(top, Vector2(w * m.hp / m.max, 2)), Color(1, 0.3, 0.3))

# ---------------------------------------------------------------- UI
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
	for a in ["attack", "dodge", "skill_1", "skill_2", "skill_3"]:
		var b := TouchScreenButton.new()
		var s := CircleShape2D.new()
		s.radius = 115.0 if a == "attack" else 80.0
		b.shape = s
		b.shape_centered = true
		b.action = a
		ui.add_child(b)
		buttons[a] = b
	get_tree().root.size_changed.connect(_layout_ui)
	_layout_ui()

func _button_pos(a: String, vs: Vector2) -> Vector2:
	match a:
		"attack": return Vector2(vs.x - 200, vs.y - 200)
		"dodge": return Vector2(vs.x - 430, vs.y - 110)
		"skill_1": return Vector2(vs.x - 420, vs.y - 300)
		"skill_2": return Vector2(vs.x - 330, vs.y - 470)
		"skill_3": return Vector2(vs.x - 150, vs.y - 470)
	return Vector2.ZERO

func _layout_ui() -> void:
	var vs := get_viewport_rect().size
	joystick.position = Vector2(0, vs.y * 0.3)
	joystick.size = Vector2(vs.x * 0.45, vs.y * 0.7)
	for a in buttons:
		buttons[a].position = _button_pos(a, vs)

func _draw_ui() -> void:
	var vs := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var ct := get_viewport().get_canvas_transform()
	for f in floaters:
		var sp: Vector2 = ct * f.pos
		var size := int(36 * f.size)
		ui_draw.draw_string_outline(font, sp - Vector2(100, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 200, size, 8, Color(0, 0, 0, f.t))
		ui_draw.draw_string(font, sp - Vector2(100, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 200, size, Color(f.col, min(1.0, f.t * 2)))
	if flash_t > 0:
		ui_draw.draw_rect(Rect2(Vector2.ZERO, vs), Color(flash_col, flash_t * 0.5))
	# top-left: level, HP, XP
	var x := 30.0
	ui_draw.draw_rect(Rect2(x - 10, 16, 560, 128), Color(0, 0, 0, 0.45))
	_text("Nv %d" % p_level, Vector2(x, 62), 40, Color(1, 0.95, 0.6))
	ui_draw.draw_rect(Rect2(x + 120, 30, 400, 30), Color(0.2, 0, 0))
	ui_draw.draw_rect(Rect2(x + 120, 30, 400 * max(0.0, p_hp) / _max_hp(), 30), Color(0.9, 0.2, 0.25))
	_text("%d/%d" % [max(0, int(p_hp)), int(_max_hp())], Vector2(x + 130, 56), 24, Color.WHITE)
	ui_draw.draw_rect(Rect2(x + 120, 70, 400, 14), Color(0.1, 0.1, 0.2))
	ui_draw.draw_rect(Rect2(x + 120, 70, 400 * p_xp / _xp_needed(), 14), Color(0.4, 0.8, 1))
	_text("Poções %d · Abates %d · %s" % [potions, kills, zone_name], Vector2(x, 128), 26, Color(0.9, 0.9, 0.9))
	# top-right: gold and seed
	var rx := vs.x - 520
	ui_draw.draw_rect(Rect2(rx - 10, 16, 510, 128), Color(0, 0, 0, 0.45))
	_text("Ouro: %d   (guardado %d)" % [gold_carried, gold_banked], Vector2(rx, 60), 30, Color(1, 0.85, 0.3))
	if seed != "":
		_text("%s · nível %d" % [SEEDS[seed].name, seed_level], Vector2(rx, 110), 30, SEEDS[seed].color)
	else:
		_text("Sem Semente — ache uma!", Vector2(rx, 110), 30, Color(0.7, 0.7, 0.7))
	# buttons
	for a in buttons:
		var pos := _button_pos(a, vs)
		var r := 115.0 if a == "attack" else 80.0
		var col := Color(1, 1, 1)
		var label := "ATACAR" if a == "attack" else ("ESQUIVA" if a == "dodge" else "")
		var cd_frac := 0.0
		if a.begins_with("skill"):
			var i := int(a.right(1)) - 1
			if seed == "":
				label = "?"
				col = Color(0.5, 0.5, 0.5)
			else:
				col = SEEDS[seed].color
				label = SEEDS[seed].skills[i]
				cd_frac = skill_cd[i] / SEEDS[seed].cd[i]
		elif a == "dodge":
			cd_frac = p_dodge_cd / 0.7
		var pressed := Input.is_action_pressed(a)
		ui_draw.draw_circle(pos, r, Color(col, 0.35 if pressed else 0.18))
		ui_draw.draw_arc(pos, r, 0, TAU, 48, Color(col, 0.8), 4)
		if cd_frac > 0:
			ui_draw.draw_circle(pos, r * cd_frac, Color(0, 0, 0, 0.45))
		ui_draw.draw_string_outline(font, pos - Vector2(r, -10), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 26 if a.begins_with("skill") else 32, 6, Color(0, 0, 0, 0.8))
		ui_draw.draw_string(font, pos - Vector2(r, -10), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 26 if a.begins_with("skill") else 32, Color(1, 1, 1))
	for m in monsters:
		if m.kind == "golden" or m.kind == "boss":
			var sp: Vector2 = ct * m.node.position
			if not Rect2(Vector2.ZERO, vs).grow(-40).has_point(sp):
				var c := vs / 2
				var dir := (sp - c).normalized()
				var edge: Vector2 = c + dir * minf(vs.x / 2.0 - 90.0, vs.y / 2.0 - 90.0)
				edge = edge.clamp(Vector2(90, 170), vs - Vector2(90, 90))
				var acol := Color(1, 0.85, 0.2) if m.kind == "golden" else Color(1, 0.3, 0.3)
				ui_draw.draw_colored_polygon(PackedVector2Array([edge + dir * 34, edge + dir.rotated(2.5) * 22, edge + dir.rotated(-2.5) * 22]), acol)
				_text("Slime Dourado" if m.kind == "golden" else "Chefe", edge - Vector2(70, 34), 24, acol)
	if banner_t > 0:
		var lines := banner.split("\n")
		for li in lines.size():
			var y := vs.y * 0.3 + li * 64
			var sz := 60 if li == 0 else 36
			ui_draw.draw_string_outline(font, Vector2(0, y), lines[li], HORIZONTAL_ALIGNMENT_CENTER, vs.x, sz, 12, Color(0, 0, 0, min(1.0, banner_t)))
			ui_draw.draw_string(font, Vector2(0, y), lines[li], HORIZONTAL_ALIGNMENT_CENTER, vs.x, sz, Color(banner_col, min(1.0, banner_t)))

func _text(s: String, pos: Vector2, size: int, col: Color) -> void:
	ui_draw.draw_string_outline(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8))
	ui_draw.draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
