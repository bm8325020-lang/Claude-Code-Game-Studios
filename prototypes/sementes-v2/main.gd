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
var _taken: Dictionary = {}  # interactable id -> true, so a pickup is collected once
var _dialog_role: String = ""


func _ready() -> void:
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

	# the hero at the start spawn, wearing whatever the save says (peasant rags by default)
	hero = Hero.new()
	add_child(hero)
	hero.global_position = _spawn("player_start")
	hero.equip(items.look())
	_apply_stats()
	hero.refill()
	hero.hurt.connect(_on_hero_hurt)
	hero.died.connect(_on_hero_died)
	hero.interact_requested.connect(_on_interact)

	# enemies and the boss
	_spawn_camps()
	_spawn_boss()

	# townsfolk
	npcs.spawn(map, self)

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
	dialog.talked.connect(func(role: String) -> void: quests.notify("talk", role))

	# gear changes rebuild the hero's look; a new weapon or armour shows at once
	items.equipped.connect(func(_slot: String, _id: String) -> void:
		hero.equip(items.look())
		_apply_stats())
	prog.leveled_up.connect(func(_l: int) -> void: _apply_stats())

	# the quest that is running decides what the first Marco bed, the boss bar and the castle gate do
	quests.quest_done.connect(func(id: String, _r: Dictionary) -> void:
		if id == "m14": _save())

	# start or continue
	if not quests.load_game():
		quests.start_new()


# ---- the damage router every attack calls (actors/fx.gd Fx.deal -> get_tree().current_scene.damage) ----
func damage(target: Node, amount: float, source: Node, kind: String) -> Dictionary:
	var amt: float = amount
	if source is Hero:
		amt *= prog.stats(items.armor()).dmg_mult
		if kind == "skill": amt *= prog.stats(items.armor()).skill_mult
	elif target is Hero:
		amt *= prog.stats(items.armor()).armor_mult
	var res: Dictionary = target.take_hit(amt, source, kind)
	if res.get("dead", false):
		if target is Boss:
			quests.notify("kill", "boss")
		elif target is Enemy:
			quests.notify("kill", (target as Enemy).kind)
	return res


func _process(dt: float) -> void:
	if not is_instance_valid(hero):
		return
	var s: Dictionary = prog.stats(items.armor())
	hud.set_life(hero.hp, s.max_hp)
	hud.set_stamina(hero.stamina, s.max_stamina)
	hud.set_player(hero.global_position, hero.cam_yaw)
	hud.show_area(_area())
	_update_interact_prompt()
	_update_boss_bar()

	# pause menu
	if Input.is_action_just_pressed("menu") and not dialog.visible:
		menu.toggle()
	hero.input_enabled = not menu.is_open and not dialog.visible

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
		var n: int = int(c.get("count", kinds.size()))
		var lvl: int = int(c.get("level", 1))
		var base: Vector3 = c.get("pos", Vector3.ZERO)
		for i in n:
			var k: String = kinds[i % kinds.size()]
			var off := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			Enemy.spawn(self, k, lvl, base + off)


func _spawn_boss() -> void:
	var sp: Dictionary = map.spawns
	if sp.has("boss"):
		_boss = Boss.spawn_boss(self, sp["boss"])


func _area() -> String:
	return map.area_name(hero.global_position)


# the contextual "Falar/Agir" button: show it when a person or an interactable is in reach
func _update_interact_prompt() -> void:
	var it: Dictionary = _nearest_interactable()
	var npc: Dictionary = _nearest_npc()
	if not npc.is_empty():
		touch.show_interact("Falar")
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
	if not npc.is_empty():
		_open_dialog(npc.role)
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
	var q: Dictionary = quests.current()
	var lines: Array = []
	if q.get("pos_kind", "") == "npc" and q.get("pos_key", "") == role:
		lines = [q.get("text", "")]
	dialog.open(role, lines, [])
	hero.perform("talk")


func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var bd: float = INTERACT_RANGE * INTERACT_RANGE
	for it: Dictionary in map.interactables:
		if _taken.has(it.get("id", "")):
			continue
		var d: float = hero.global_position.distance_squared_to(it.get("pos", Vector3.ZERO))
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
	# respawn at the last Marco de Lume (or the inn bed), losing nothing but position
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(hero):
		hero.revive(_spawn("player_start"))


func _on_item_used(_id: String, heal: int) -> void:
	hero.hp = minf(hero.max_hp, hero.hp + heal)


func _save() -> void:
	quests.save_game()
