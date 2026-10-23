# PROTOTYPE - NOT FOR PRODUCTION
# Glue of Sementes do Dragão v2 (see ARCHITECTURE.md). Wires the five modules together:
#   world/map.gd (GameMap)          -> the Vale de Lume, its WorldEnvironment, places, camps, npc_spots, interactables
#   actors/hero.gd, enemy.gd, boss.gd, fx.gd -> the hero, the six enemy kinds and Dom Aurélio
#   systems/progression.gd, quests.gd, items.gd -> levels, the quest chain, gear and the save file
#   ui/hud.gd, touch.gd, menu.gd, dialog.gd, npcs.gd -> the Brazilian-Portuguese interface and NPC chat
# main owns the damage router every attack calls (Fx.deal -> scene.damage), the interact button, the pause menu,
# NPC dialogue and the save on quit.
extends Node3D

const INTERACT_RANGE: float = 3.2
const TALK_RANGE: float = 3.6
const SAVE_EVERY: float = 30.0

var map: Node3D
var hero: Hero
var prog: Progression
var items: Items
var quests: Quests
var npcs: Npcs
var hud: Hud
var touch: Touch
var menu: GameMenu
var dialog: DialogBox

var _save_timer: float = 0.0
var _boss: Boss = null
var _actors: Array[Node3D] = []  # enemies, boss and townsfolk that sleep when far from the hero
var _wake_timer: float = 0.0
var _taken: Dictionary = {}  # interactable id -> true, so a pickup is collected once
var _dialog_role: String = ""

# Blox-Fruits-style loop: zone levels, hunters with repeatable contracts, chests dropped by defeated enemies
const CHEST_LIFE: float = 120.0
const WEAPON_BASE: Dictionary = {"Sword_Bronze": 12.0, "Axe_Bronze": 15.0, "Pickaxe_Bronze": 13.0}  # Items dmg the hero.gd numbers assume
var farm: Farm = Farm.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hunters: Array[Dictionary] = []   # {place, kind, pos, node}
var _chests: Array[Dictionary] = []    # {pos, level, boss, node, age}
var _plates: Dictionary = {}           # Enemy -> Label3D
var _quest_marks: Array[Dictionary] = []  # {role, label}
var _item_marks: Dictionary = {}  # interactable id -> Label3D shown while the current quest wants that item
var _farm_label: Label
var _zone: String = ""
var _hunter_offer: Dictionary = {}
const RESPAWN_S: float = 40.0
const RESPAWN_MIN_DIST: float = 30.0
var _respawns: Array[Dictionary] = []
const DROPS: Dictionary = {"elmo_vigilia": "knight"}  # quest items that drop from an enemy kind instead of lying around
var _marcos_seen: Dictionary = {}   # marco id -> pos, discovered by walking within 20 m
var _deaths: Array[Dictionary] = []  # {t, zone} for the "stuck here?" tip
var _tips_shown: Dictionary = {}
var _clock: float = 0.0  # {kind, level, pos, at}: farm needs camps that fill up again


func _ready() -> void:
	Engine.max_fps = 60
	# the hero reads an action named "heavy"; the project has no key for it, so bind one (I) at runtime.
	if not InputMap.has_action("heavy"):
		InputMap.add_action("heavy")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.action_add_event("heavy", ev)

	GameMenu.load_options()
	GameMenu.apply_options()

	# systems first: the save (if any) is restored before anything reads a level or inventory.
	prog = Progression.new()
	items = Items.new()
	quests = Quests.new(prog, items)
	npcs = Npcs.new()
	add_child(npcs)

	# the world
	map = load("res://world/map.gd").new()
	add_child(map)
	map.build()
	_lighten_world()

	# the hero at the start spawn, wearing whatever the save says (peasant rags by default)
	hero = Hero.new()
	add_child(hero)
	hero.global_position = _spawn("player_start")
	hero.reset_physics_interpolation()
	hero.equip(items.look())
	_apply_stats()
	hero.refill()
	if hero.camera:
		hero.camera.far = 150.0  # pull the far plane in: fewer distant draws on a phone
	hero.hurt.connect(_on_hero_hurt)
	hero.died.connect(_on_hero_died)
	hero.interact_requested.connect(_on_interact)

	# enemies and the boss
	_spawn_camps()
	_spawn_boss()

	# townsfolk
	for n in npcs.spawn(map, self):
		if n is Node3D: _actors.append(n)
	_spawn_hunters()
	for sp: Dictionary in map.npc_spots:
		var mark := _label3d("!", Color(1.0, 0.82, 0.25), 0.0028)
		add_child(mark)
		mark.global_position = (sp.pos as Vector3) + Vector3(0, 2.4, 0)
		_quest_marks.append({"role": str(sp.role), "label": mark})

	# interface on its own CanvasLayer so it never clips into the 3D world
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	touch = Touch.new()
	layer.add_child(touch)
	menu = GameMenu.new()
	layer.add_child(menu)
	dialog = DialogBox.new()
	layer.add_child(dialog)

	hud.bind(prog, quests, map)
	menu.bind(prog, quests, items, map)
	menu.player = hero
	menu.item_used.connect(_on_item_used)
	dialog.npcs = npcs
	dialog.context_fn = func() -> String: return Npcs.context_line(prog, quests, _area())
	dialog.talked.connect(func(role: String) -> void:
		if role != "cacador":
			quests.notify("talk", role))
	dialog.choice_made.connect(_on_choice)

	# hunting contract tracker, under the quest card
	_farm_label = Label.new()
	_farm_label.add_theme_font_override("font", Hud.font(true))
	_farm_label.add_theme_font_size_override("font_size", 24)
	_farm_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
	_farm_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
	_farm_label.add_theme_constant_override("outline_size", 8)
	_farm_label.anchor_left = 1.0
	_farm_label.anchor_right = 1.0
	_farm_label.offset_left = -460.0
	_farm_label.offset_right = -22.0
	_farm_label.offset_top = 292.0  # below the quest card (HUD is laid out at a larger base size and scaled down)
	_farm_label.offset_bottom = 332.0
	_farm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_farm_label)
	farm.progress.connect(func(_h: int, _n: int) -> void: _update_farm_label())
	farm.accepted.connect(func(_c: Dictionary) -> void: _update_farm_label())
	farm.finished.connect(func(_c: Dictionary) -> void: _update_farm_label())
	_update_farm_label()
	rng.seed = Time.get_ticks_usec()

	# keep the touch HUD uncluttered: only the buttons the hero can actually use right now are shown.
	# Heavy/block/skill appear as the quest chain unlocks them (start-from-zero).
	_refresh_buttons()
	prog.unlocked.connect(func(_id: String) -> void: _refresh_buttons())

	# gear changes rebuild the hero's look; a new weapon or armour shows at once
	items.equipped.connect(func(_slot: String, _id: String) -> void:
		hero.equip(items.look())
		_apply_stats()
		_refresh_buttons())
	prog.leveled_up.connect(func(_l: int) -> void: _apply_stats())

	# the quest that is running decides what the first Marco bed, the boss bar and the castle gate do
	quests.quest_done.connect(func(id: String, _r: Dictionary) -> void:
		if id == "m14": _save())

	# start or continue
	if not quests.load_game():
		quests.start_new()
	_place_missing_quest_items()
	await get_tree().physics_frame
	_unbury_interactables()


# Every quest "collect" must have enough pickups in the world. Any shortfall is placed around the best anchor:
# an existing pickup of the same item, else the spot the quest had you interact with just before, else the area.
func _place_missing_quest_items() -> void:
	var have: Dictionary = {}
	for it: Dictionary in map.interactables:
		if it.has("item"):
			have[str(it.item)] = int(have.get(str(it.item), 0)) + 1
	for q: Dictionary in Quests.DATA:
		var steps: Array = q.steps
		for i in steps.size():
			var st: Dictionary = Quests.step_of(q, i)
			var item: String = str(st.target)
			if str(st.type) != "collect" or DROPS.has(item):
				continue
			var missing: int = int(st.count) - int(have.get(item, 0))
			if missing <= 0:
				continue
			var anchor: Variant = null
			for it: Dictionary in map.interactables:
				if str(it.get("item", "")) == item:
					anchor = it.pos
			if anchor == null and i > 0:
				var prev: Dictionary = Quests.step_of(q, i - 1)
				for it: Dictionary in map.interactables:
					if str(it.id) == str(prev.target):
						anchor = it.pos
			if anchor == null:
				for pl: Dictionary in map.places:
					if str(pl.id) == str(st.where):
						anchor = pl.pos
			if anchor == null:
				continue
			for k in missing:
				var a: float = TAU * (k + 1) / float(missing + 2)
				var p: Vector3 = (anchor as Vector3) + Vector3(cos(a), 0, sin(a)) * 2.6
				p.y = map.ground_y(p.x, p.z)
				(map.interactables as Array).append({"id": "%s_extra_%d" % [item, k], "kind": "pickup", "pos": p, "item": item})
			have[item] = int(st.count)


# Some quest props sit inside a building's collision box (the relha in the barn): a player can never reach them.
# Move each such spot to the nearest free ground around it.
func _unbury_interactables() -> void:
	var ss: PhysicsDirectSpaceState3D = hero.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1
	for it: Dictionary in map.interactables:
		var p: Vector3 = it.pos
		q.position = p + Vector3(0, 0.9, 0)
		if ss.intersect_point(q, 1).is_empty():
			continue
		var found: bool = false
		for ring in range(1, 13):
			var r: float = ring * 0.5
			for k in 12:
				var a: float = TAU * k / 12.0
				var c := Vector3(p.x + cos(a) * r, 0.0, p.z + sin(a) * r)
				c.y = map.ground_y(c.x, c.z)
				q.position = c + Vector3(0, 0.9, 0)
				if ss.intersect_point(q, 1).is_empty():
					it.pos = c
					found = true
					break
			if found:
				break


# ---- the damage router every attack calls (actors/fx.gd Fx.deal -> get_tree().current_scene.damage) ----
func damage(target: Node, amount: float, source: Node, kind: String) -> Dictionary:
	var amt: float = amount
	if source is Hero:
		amt *= prog.stats(items.armor()).dmg_mult
		if kind == "skill": amt *= prog.stats(items.armor()).skill_mult
		var prop: String = str(items.look().get("weapon", ""))
		if WEAPON_BASE.has(prop):
			amt *= float(items.weapon_damage()) / float(WEAPON_BASE[prop])  # better loot weapons hit harder
		if target is Enemy:
			# fighting above your level barely scratches them
			amt *= clampf(1.0 - 0.08 * float((target as Enemy).level - prog.level), 0.25, 1.0)
	elif target is Hero:
		amt *= prog.stats(items.armor()).armor_mult
		if source is Enemy:
			# gentle on the intended path, steep only well above your level (reviewed for casual players)
			var diff: int = (source as Enemy).level - prog.level
			if diff <= 1:
				amt *= 0.8 if (source as Enemy).level <= 12 else 1.0
			elif diff == 2:
				amt *= 1.5
			elif diff == 3:
				amt *= 2.0
			else:
				amt *= 3.0
	var was_alive: bool = target is Enemy and not (target as Enemy).dead
	var res: Dictionary = target.take_hit(amt, source, kind)
	if was_alive and (target as Enemy).dead:  # covers "result": "dead" and the boss falling asleep
		_on_enemy_killed(target as Enemy)
	return res


func _on_enemy_killed(e: Enemy) -> void:
	if e is Boss:
		quests.notify("kill", "boss")
	else:
		quests.notify("kill", e.kind)
	prog.gain_xp(e.xp)
	for item: String in DROPS:
		if DROPS[item] == e.kind and quests.is_target("collect", item):
			quests.notify("collect", item)
			hud.toast("Pegou: " + Items.item_name(item), "", "reward")
	if _plates.has(e):
		(_plates[e] as Node).queue_free()
		_plates.erase(e)
	_actors.erase(e)
	if not e is Boss and e.has_meta("home"):
		_respawns.append({"kind": e.kind, "level": e.level, "pos": e.get_meta("home"), "at": RESPAWN_S})
	var c: Dictionary = farm.on_kill(e.kind)
	if not c.is_empty():
		prog.gain_xp(int(c.xp))
		prog.add_gold(int(c.gold))
		hud.toast("Caça concluída!", "+%d XP   +%d ouro · fale com o caçador de novo" % [int(c.xp), int(c.gold)], "quest")
	if e is Boss or rng.randf() < Loot.DROP_CHANCE:
		_spawn_chest(e.global_position, e.level, e is Boss)


func _process(dt: float) -> void:
	if not is_instance_valid(hero):
		return
	var s: Dictionary = prog.stats(items.armor())
	hud.set_life(hero.hp, s.max_hp)
	hud.set_stamina(hero.stamina, s.max_stamina)
	hud.set_player(hero.global_position, hero.cam_yaw)
	var zone: String = _place_id(hero.global_position)
	var area: String = _area()
	hud.show_area(Zones.label(zone, area) if area != "" else "")
	if zone != _zone:
		_zone = zone
		if Zones.LEVELS.has(zone) and int(Zones.range_of(zone)[0]) >= prog.level + 2:
			hud.toast("Recomendado: Nv %d" % int(Zones.range_of(zone)[0]), "Você é Nv %d. Os inimigos daqui batem forte." % prog.level, "info")
	_age_chests(dt)
	_tick_respawns(dt)
	_clock += dt
	for it: Dictionary in map.interactables:
		if str(it.get("kind", "")) == "rest" and not _marcos_seen.has(str(it.id)) and hero.global_position.distance_to(it.pos) < 20.0:
			_marcos_seen[str(it.id)] = it.pos
	_update_interact_prompt()
	_update_boss_bar()

	# pause menu
	if Input.is_action_just_pressed("menu") and not dialog.visible:
		menu.toggle()
	hero.input_enabled = not menu.is_open and not dialog.visible

	_wake_timer += dt
	if _wake_timer >= 0.25:
		_wake_timer = 0.0
		_sleep_far_actors()
		_refresh_marks()
		if _zone != "":
			quests.notify("reach", _zone)  # harmless when repeated; also counts if you are already there

	_save_timer += dt
	if _save_timer >= SAVE_EVERY:
		_save_timer = 0.0
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_save()


# ---- helpers ----
func _spawn(key: String) -> Vector3:
	var sp: Dictionary = map.spawns
	return sp.get(key, Vector3.ZERO)


func _apply_stats() -> void:
	var s: Dictionary = prog.stats(items.armor())
	hero.max_hp = s.max_hp
	hero.max_stamina = s.max_stamina
	hero.power = s.dmg_mult
	hero.potions = items.count("frasco") if items.has("frasco") else hero.potions


func _spawn_camps() -> void:
	for c: Dictionary in map.camps:
		var kinds: Array = c.get("kinds", [])
		if kinds.is_empty() or "boss" in kinds:
			continue  # the boss is placed on its own spawn, not as a camp body
		var n: int = mini(int(c.get("count", kinds.size())), 3)  # cap bodies per camp: lighter on a phone
		var place: String = str(c.get("place", ""))
		var base: Vector3 = c.get("pos", Vector3.ZERO)
		for i in n:
			var k: String = kinds[i % kinds.size()]
			var off := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			var lvl: int = Zones.level_for(place, i) if Zones.LEVELS.has(place) else int(c.get("level", 1))
			_spawn_enemy(k, lvl, base + off)


func _spawn_enemy(k: String, lvl: int, pos: Vector3) -> Enemy:
	var e: Enemy = Enemy.spawn(self, k, lvl, pos)
	_actors.append(e)
	_add_plate(e)
	e.set_meta("home", pos)
	return e


func _tick_respawns(dt: float) -> void:
	for r: Dictionary in _respawns.duplicate():
		r.at = float(r.at) - dt
		if float(r.at) <= 0.0 and hero.global_position.distance_to(r.pos) > RESPAWN_MIN_DIST:
			_respawns.erase(r)
			_spawn_enemy(str(r.kind), int(r.level), r.pos)


func _spawn_boss() -> void:
	var sp: Dictionary = map.spawns
	if sp.has("boss"):
		_boss = Boss.spawn_boss(self, sp["boss"])
		_boss.level = Zones.BOSS_LEVEL
		_actors.append(_boss)
		_add_plate(_boss)


func _area() -> String:
	return map.area_name(hero.global_position)


# the contextual "Falar/Agir" button: show it when a person or an interactable is in reach
func _update_interact_prompt() -> void:
	var it: Dictionary = _nearest_interactable()
	var npc: Dictionary = _nearest_npc()
	if not it.is_empty() and quests.is_target("interact", str(it.get("id", ""))) and not (not npc.is_empty() and quests.is_target("talk", str(npc.role))):
		touch.show_interact(_prompt_for(it))
	elif not npc.is_empty() or not _nearest_hunter().is_empty():
		touch.show_interact("Falar")
	elif not _nearest_chest().is_empty():
		touch.show_interact("Abrir")
	elif not it.is_empty():
		touch.show_interact(_prompt_for(it))
	else:
		touch.hide_interact()


func _prompt_for(it: Dictionary) -> String:
	match it.get("kind", ""):
		"rest": return "Descansar"
		"pickup": return "Pegar"
		"chest": return "Abrir"
		_: return "Agir"


func _on_interact() -> void:
	if dialog.visible:
		return
	var npc: Dictionary = _nearest_npc()
	var near_it: Dictionary = _nearest_interactable()
	# what the quest asks for wins over whoever happens to stand closest (Joana stands at her own forge)
	if not near_it.is_empty() and quests.is_target("interact", str(near_it.get("id", ""))) and not (not npc.is_empty() and quests.is_target("talk", str(npc.role))):
		npc = {}
	if not npc.is_empty():
		_open_dialog(npc.role)
		return
	var h: Dictionary = _nearest_hunter()
	if not h.is_empty():
		_open_hunter(h)
		return
	var ch: Dictionary = _nearest_chest()
	if not ch.is_empty():
		_open_chest(ch)
		return
	var it: Dictionary = _nearest_interactable()
	if it.is_empty():
		return
	var kind: String = it.get("kind", "")
	var id: String = it.get("id", "")
	match kind:
		"pickup", "chest":
			var item: String = it.get("item", "")
			if item != "":
				quests.notify("collect", item)
			_taken[id] = true
			hero.perform("open_chest" if kind == "chest" else "pickup")
		"rest":
			hero.perform("sit")
			hero.refill()
			quests.notify("interact", id)
		_:
			hero.perform("interact")
			quests.notify("interact", id)


func _open_dialog(role: String) -> void:
	_dialog_role = role
	# tapping FALAR is talking: a player should not have to type to the NPC to move the story on
	var lines: Array = []
	var before: Dictionary = quests.current()
	if quests.is_target("talk", role):
		var qid: String = str(before.get("id", ""))
		quests.notify("talk", role)
		var d: Dictionary = Quests.quest(qid)
		var after: Dictionary = quests.current()
		if quests.is_done(qid) and str(d.get("done", "")) != "":
			lines.append(str(d.done))
		var nd: Dictionary = Quests.quest(str(after.get("id", "")))
		if str(after.get("id", "")) != qid and str(nd.get("offer", "")) != "":
			lines.append(str(nd.offer))
		if not after.is_empty():
			lines.append("Próximo: " + str(after.get("text", "")))
	dialog.open(role, lines, [])
	hero.perform("talk")


func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var bd: float = INTERACT_RANGE * INTERACT_RANGE
	for it: Dictionary in map.interactables:
		if _taken.has(it.get("id", "")):
			continue
		var ip: Vector3 = it.get("pos", Vector3.ZERO)
		if absf(ip.y - hero.global_position.y) > 3.0:
			continue
		var d: float = Vector2(hero.global_position.x, hero.global_position.z).distance_squared_to(Vector2(ip.x, ip.z))
		if d < bd:
			bd = d
			best = it
	return best


func _nearest_npc() -> Dictionary:
	var best: Dictionary = {}
	var bd: float = TALK_RANGE * TALK_RANGE
	for sp: Dictionary in map.npc_spots:
		var d: float = hero.global_position.distance_squared_to(sp.get("pos", Vector3.ZERO))
		if d < bd:
			bd = d
			best = sp
	return best


func _update_boss_bar() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if _boss.dead:
		hud.boss_hide()
	elif _boss.get("state") != "patrol" and _boss.hp < _boss.max_hp:
		hud.boss_show(_boss.display_name, _boss.hp, _boss.max_hp)


func _on_hero_hurt(_amount: float, _source: Node, _result: String) -> void:
	pass  # the HUD polls hp in _process; hook kept for sfx/feedback later


func _on_hero_died() -> void:
	# nothing is lost; you wake at the nearest Marco de Lume you have found (else the village)
	var where: Vector3 = hero.global_position
	var unused_flasks: bool = hero.potions > 0
	_deaths.append({"t": _clock, "zone": _zone})
	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(hero):
		return
	var at: Vector3 = _spawn("player_start")
	var woke_marco: bool = false
	var bd: float = 1e12
	for id: String in _marcos_seen:
		var d: float = (_marcos_seen[id] as Vector3).distance_to(where)
		if d < bd:
			bd = d
			at = (_marcos_seen[id] as Vector3) + Vector3(1.5, 0, 0)
			woke_marco = true
	hero.revive(at)
	hero.reset_physics_interpolation()  # teleport: don't smear from the death spot
	if woke_marco:
		hud.toast("Você acordou no Marco de Lume", "", "info")
	_death_tip(unused_flasks)


# three deaths in one area within five minutes: one friendly, non-blocking tip per area
func _death_tip(unused_flasks: bool) -> void:
	var recent: int = 0
	for d: Dictionary in _deaths:
		if str(d.zone) == _zone and _clock - float(d.t) < 300.0:
			recent += 1
	if recent < 3 or _tips_shown.has(_zone):
		return
	_tips_shown[_zone] = true
	if unused_flasks:
		hud.toast("Dica", "Use o frasco quando a vida estiver baixa.", "info")
	else:
		hud.toast("Dica", "Suba de nível na área anterior — o Caçador paga por caça.", "info")


func _on_item_used(_id: String, heal: int) -> void:
	hero.hp = minf(hero.max_hp, hero.hp + heal)


func _save() -> void:
	quests.save_game()


# Cheaper environment for phones: shorter shadows, no screen-space heavy effects, tighter fog.
func _lighten_world() -> void:
	for n in _all_nodes(map):
		if n is DirectionalLight3D:
			var dl := n as DirectionalLight3D
			dl.directional_shadow_max_distance = 25.0 if OS.has_feature("mobile") else 55.0
			dl.shadow_blur = 1.0
		elif n is WorldEnvironment:
			var env: Environment = (n as WorldEnvironment).environment
			if env:
				env.ssao_enabled = false
				env.ssil_enabled = false
				env.sdfgi_enabled = false
				env.glow_enabled = false


func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out.append_array(_all_nodes(c))
	return out


# Show only the buttons the hero can use now; reveal heavy/block/skill as progression grants them.
func _refresh_buttons() -> void:
	if touch == null:
		return
	var has_weapon: bool = String(items.look().get("weapon", "")) != ""
	touch.set_button("heavy", has_weapon)
	touch.set_button("lock", has_weapon)
	touch.set_button("block", prog.has_unlock("bloqueio"))
	touch.set_button("skill", prog.has_unlock("sopro_brasa") or prog.has_unlock("calor_lar"))


# Far enemies/NPCs stop thinking, moving and animating (the phone's CPU was spent on 50 skeletons nobody saw).
# An enemy that is chasing or fighting stays awake so it can follow the hero out of range.
const WAKE_RANGE: float = 45.0

func _sleep_far_actors() -> void:
	var hp: Vector3 = hero.global_position
	for a in _actors:
		if not is_instance_valid(a):
			continue
		var near: bool = a.global_position.distance_to(hp) < WAKE_RANGE
		var busy: bool = a is Enemy and not (a as Enemy).dead and String(a.get("state")) not in ["patrol", "idle", "return", "sleep", "guard"]
		var awake: bool = near or busy
		a.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
		a.visible = awake



# ---- zones, hunters, chests, nameplates ----
func _place_id(pos: Vector3) -> String:
	var best: String = ""
	var bd: float = 1e12
	for p: Dictionary in map.places:
		var d: float = Vector2(pos.x, pos.z).distance_to(Vector2((p.pos as Vector3).x, (p.pos as Vector3).z))
		if d < float(p.get("radius", 40.0)) and d < bd:
			bd = d
			best = str(p.id)
	return best


func _label3d(text: String, col: Color, px: float = 0.0011) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.outline_modulate = Color(0.1, 0.05, 0.02)
	l.outline_size = 10
	l.font_size = 34
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.fixed_size = true  # same size on screen near or far, so a close enemy's name never covers the fight
	l.visibility_range_end = 28.0
	return l


func _add_plate(e: Enemy) -> void:
	var l := _label3d("", Color.WHITE)
	e.add_child(l)
	l.position = Vector3(0, e.target_height + 0.55, 0)
	_plates[e] = l
	_paint_plate(e)


func _paint_plate(e: Enemy) -> void:
	var l: Label3D = _plates.get(e)
	if l == null:
		return
	var wanted: bool = quests.is_target("kill", "boss" if e is Boss else e.kind) or (farm.has_active() and str(farm.active.kind) == e.kind)
	l.text = ("⚔ " if wanted else "") + "%s · Nv %d" % [e.display_name, e.level]
	match Zones.danger(e.level, prog.level):
		2: l.modulate = Color(1.0, 0.25, 0.2)
		1: l.modulate = Color(1.0, 0.7, 0.25)
		_: l.modulate = Color(0.95, 0.95, 0.9)


func _spawn_hunters() -> void:
	var seen: Dictionary = {}
	var village: Vector3 = _spawn("village_square")
	for c: Dictionary in map.camps:
		var place: String = str(c.get("place", ""))
		var kinds: Array = c.get("kinds", [])
		if seen.has(place) or kinds.is_empty() or "boss" in kinds or not Zones.LEVELS.has(place):
			continue
		seen[place] = true
		var camp: Vector3 = c.pos
		var toward: Vector3 = (village - camp)
		toward.y = 0.0
		var p: Vector3 = camp + toward.normalized() * 16.0  # on the village side of the camp, out of the fight
		p.y = map.ground_y(p.x, p.z)
		var ch: Node3D = CharacterKit.make({"body": "Male", "outfit": "Ranger", "hood": true, "weapon": "Axe_Bronze"})
		add_child(ch)
		ch.global_position = p
		ch.look_at(p - toward.normalized(), Vector3.UP)  # models face +Z: this turns them toward the village side
		var ap: AnimationPlayer = ch.get_meta("anim") as AnimationPlayer
		if ap and ap.has_animation("idle"):
			ap.play("idle")
		var mark := _label3d("!", Color(0.45, 0.85, 1.0), 0.0028)
		ch.add_child(mark)
		mark.position = Vector3(0, 2.4, 0)
		var tag := _label3d("Caçador · Nv %d–%d" % [int(Zones.range_of(place)[0]), int(Zones.range_of(place)[1])], Color(0.75, 0.9, 1.0))
		ch.add_child(tag)
		tag.position = Vector3(0, 2.05, 0)
		_hunters.append({"place": place, "kind": str(kinds[0]), "pos": p, "node": ch})
		_actors.append(ch)


func _nearest_hunter() -> Dictionary:
	for h: Dictionary in _hunters:
		if hero.global_position.distance_to(h.pos) < TALK_RANGE:
			return h
	return {}


func _open_hunter(h: Dictionary) -> void:
	hero.perform("talk")
	if farm.has_active():
		var a: Dictionary = farm.active
		dialog.open("cacador", ["Ainda tá na caça: %s. Faltam %d." % [Farm.text(a), int(a.need) - int(a.have)]], [])
		return
	_hunter_offer = Farm.offer(h.place, h.kind)
	dialog.open("cacador", ["Tem serviço: %s." % Farm.text(_hunter_offer),
		"Pago %d de experiência e %d de ouro. Topa?" % [int(_hunter_offer.xp), int(_hunter_offer.gold)]],
		[{"id": "aceitar", "text": "Aceitar a caça"}])


func _on_choice(role: String, id: String) -> void:
	if role == "cacador" and id == "aceitar" and not _hunter_offer.is_empty():
		farm.accept(_hunter_offer)
		_hunter_offer = {}
		dialog.close()
		hud.toast("Caça aceita", Farm.text(farm.active), "quest")


func _update_farm_label() -> void:
	if _farm_label == null:
		return
	if farm.has_active():
		var a: Dictionary = farm.active
		_farm_label.text = "Caça: %s  %d/%d" % [str(Farm.KIND_NAME.get(a.kind, a.kind)), int(a.have), int(a.need)]
	else:
		_farm_label.text = ""


func _spawn_chest(pos: Vector3, level: int, boss: bool) -> void:
	var scene: PackedScene = load("res://assets/props/Chest_Wood.gltf")
	var node: Node3D = scene.instantiate()
	add_child(node)
	node.global_position = Vector3(pos.x, map.ground_y(pos.x, pos.z), pos.z)
	node.rotation.y = rng.randf() * TAU
	var tag := _label3d("Baú" if not boss else "Baú do Conde", Color(1.0, 0.85, 0.4))
	node.add_child(tag)
	tag.position = Vector3(0, 1.1, 0)
	_chests.append({"pos": node.global_position, "level": level, "boss": boss, "node": node, "age": 0.0})


func _nearest_chest() -> Dictionary:
	for c: Dictionary in _chests:
		if hero.global_position.distance_to(c.pos) < INTERACT_RANGE:
			return c
	return {}


func _open_chest(c: Dictionary) -> void:
	hero.perform("open_chest")
	var r: Dictionary = Loot.roll(int(c.level), rng, bool(c.boss))
	prog.add_gold(int(r.gold))
	if str(r.item) != "":
		items.add(str(r.item))
		hud.toast("%s: %s" % [str(Loot.NAME[r.rarity]), Items.item_name(str(r.item))], "+%d ouro · veja no Inventário" % int(r.gold), "reward")
	else:
		hud.toast("Baú", "+%d ouro" % int(r.gold), "reward")
	(c.node as Node).queue_free()
	_chests.erase(c)


func _age_chests(dt: float) -> void:
	for c: Dictionary in _chests.duplicate():
		c.age = float(c.age) + dt
		if float(c.age) > CHEST_LIFE:
			(c.node as Node).queue_free()
			_chests.erase(c)


# "!" over townsfolk who have story work for you; nameplate colours follow the hero's level
func _refresh_marks() -> void:
	for m: Dictionary in _quest_marks:
		(m.label as Label3D).visible = quests.is_target("talk", str(m.role))
	# a glowing star over every pickup or quest spot the current quest needs: small props are easy to miss
	for it: Dictionary in map.interactables:
		var id: String = str(it.get("id", ""))
		var kind: String = str(it.get("kind", ""))
		var want: bool = not _taken.has(id) and (
			(kind in ["pickup", "chest"] and quests.is_target("collect", str(it.get("item", ""))))
			or quests.is_target("interact", id))
		if want and not _item_marks.has(id):
			var l := _label3d("✦", Color(1.0, 0.85, 0.3), 0.0022)
			l.visibility_range_end = 45.0
			add_child(l)
			l.global_position = (it.pos as Vector3) + Vector3(0, 1.4, 0)
			_item_marks[id] = l
		elif not want and _item_marks.has(id):
			(_item_marks[id] as Node).queue_free()
			_item_marks.erase(id)
	for e: Enemy in _plates:
		if is_instance_valid(e) and e.visible:
			_paint_plate(e)
