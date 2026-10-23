# PROTOTYPE - NOT FOR PRODUCTION
# Playtest bot: plays like a new player who only knows what the screen shows. It follows the quest tracker's
# target (the HUD arrow), presses FALAR/ABRIR/PEGAR when the button appears, fights what attacks it, drinks when
# low, accepts hunter contracts, and wanders when it has nothing to do. It never reads map internals for routing.
#   godot --headless --path . --fixed-fps 30 -s tools/player_bot.gd -- [minutes] [seed]
# Writes tools/playtest_report.json and prints a summary.
extends SceneTree

var g: Node3D
var hero: Hero
var t: float = 0.0
var minutes: float = 20.0
var log: Array = []
var deaths: int = 0
var stuck_events: int = 0
var stuck_spots: Array = []
var areas: Dictionary = {}       # area name -> first time seen (s)
var quest_times: Dictionary = {}  # quest id -> completed at (s)
var dialog_opened: int = 0
var talk_targets_ignored: int = 0
var _wander: Vector3 = Vector3.ZERO
var _wander_t: float = 0.0
var _dbg_target: Variant = null  # last aim, logged with each sample so a stall shows what the bot was walking to
var _last_pos: Vector3 = Vector3.ZERO
var _still: float = 0.0
var _atk_cd: float = 0.0
var _int_cd: float = 0.0
var _dlg_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sample_t: float = 0.0
var _quest_stall: float = 0.0
var _last_quest_key: String = ""
var _max_quest_stall: float = 0.0
var _stall_quest: String = ""
var _hurts: Array = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: minutes = float(args[0])
	_rng.seed = int(args[1]) if args.size() > 1 else 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sementes2_save.json"))  # a fresh download
	seed(int(args[1]) if args.size() > 1 else 1)  # same enemy spawn offsets per seed, so runs compare
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await process_frame
	hero = g.hero
	hero.set_bot(_bot)
	hero.hurt.connect(func(amount: float, source: Node, _r: String) -> void:
		var who: String = "?" if source == null else (str(source.get("kind")) + " Nv" + str(source.get("level")) if source is Enemy else source.get_class())
		_hurts.append("%s:%d" % [who, int(amount)])
		if _hurts.size() > 4: _hurts.pop_front())
	hero.died.connect(func() -> void:
		deaths += 1
		log.append({"t": snappedf(t, 0.1), "event": "death", "area": g._area(), "level": g.prog.level, "hp_max": int(hero.max_hp),
			"last_hits": _hurts.duplicate(), "pos": [snappedf(hero.global_position.x, 1), snappedf(hero.global_position.y, 1), snappedf(hero.global_position.z, 1)], "swim": hero.swimming}))
	g.quests.quest_done.connect(func(id: String, _r: Dictionary) -> void:
		quest_times[id] = snappedf(t, 0.1)
		log.append({"t": snappedf(t, 0.1), "event": "quest_done", "id": id, "level": g.prog.level}))
	_last_pos = hero.global_position
	while t < minutes * 60.0:
		await process_frame
		var dt: float = 1.0 / 30.0
		t += dt
		_tick(dt)
	_report()
	quit()


func _tick(dt: float) -> void:
	# dialogs pause the game: read for a moment, take a quest choice if there is one, then close
	if g.dialog.is_open:
		_dlg_t += dt
		if _dlg_t > 2.0:
			var ch: Array = g.dialog._choices
			if not ch.is_empty() and ch[0] is Dictionary and g.dialog.role == "cacador":
				g.dialog.choice_made.emit(g.dialog.role, str(ch[0].id))
			if g.dialog.is_open:
				g.dialog.close()
			_dlg_t = 0.0
		return
	if g.menu.is_open:
		g.menu.close()
	# a full-screen panel (the ending) pauses the game: tap its button like a player would
	if paused:
		for b: Node in g.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and (b as Button).text == "Continuar explorando":
				(b as Button).pressed.emit()
		return
	_atk_cd -= dt
	_int_cd -= dt
	var area: String = g._area()
	if area != "" and not areas.has(area):
		areas[area] = snappedf(t, 0.1)
	# stuck: barely moved for 6 s while trying to go somewhere
	var moved: float = hero.global_position.distance_to(_last_pos)
	var wants_to_move: bool = Hud.quest_pos(g.quests.current(), g.map) is Vector3 and hero.global_position.distance_to(Hud.quest_pos(g.quests.current(), g.map)) > 3.0
	_still = _still + dt if (moved < 0.03 and wants_to_move) else 0.0
	_last_pos = hero.global_position
	if _still > 6.0:
		stuck_events += 1
		stuck_spots.append([snappedf(hero.global_position.x, 1), snappedf(hero.global_position.z, 1), area])
		# walk around it like a person would: sidestep left or right of where we were heading, then try again
		var tgt: Variant = Hud.quest_pos(g.quests.current(), g.map)
		var fwd: Vector3 = ((tgt as Vector3) - hero.global_position) if tgt is Vector3 else Vector3.FORWARD
		fwd.y = 0.0
		var side: Vector3 = fwd.normalized().cross(Vector3.UP) * (1.0 if stuck_events % 2 == 0 else -1.0)
		_wander = (side * 0.9 - fwd.normalized() * 0.3).normalized()
		_wander_t = 3.0
		_still = 0.0
	# how long the same quest step stays unfinished
	var q: Dictionary = g.quests.current()
	var qk: String = "%s:%s" % [q.get("id", ""), q.get("step", "")]
	if qk == _last_quest_key:
		_quest_stall += dt
		if _quest_stall > _max_quest_stall:
			_max_quest_stall = _quest_stall
			_stall_quest = "%s — %s" % [q.get("title", ""), q.get("text", "")]
	else:
		_last_quest_key = qk
		_quest_stall = 0.0
	_sample_t += dt
	if _sample_t >= 30.0:
		_sample_t = 0.0
		log.append({"t": snappedf(t, 0.1), "area": area, "level": g.prog.level, "hp": int(hero.hp), "gold": g.prog.gold,
			"quest": str(q.get("text", "")), "pos": [snappedf(hero.global_position.x, 1), snappedf(hero.global_position.z, 1)],
			"y": snappedf(hero.global_position.y, 0.1), "aim": str(_dbg_target), "vel": snappedf(hero.velocity.length(), 0.1)})


func _enemy_threat() -> Enemy:
	var best: Enemy = null
	var bd: float = 7.0
	for n in get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e.dead or not e.visible:
			continue
		var d: float = e.global_position.distance_to(hero.global_position)
		if d < bd and (e.state in ["combat", "attack", "alert"] or d < 3.0):
			bd = d
			best = e
	return best


func _bot(h: Hero) -> Dictionary:
	var out: Dictionary = {"move": Vector2.ZERO, "pressed": [], "held": []}
	var pressed: Array = []
	# drink when low, like anyone would
	if h.hp < h.max_hp * 0.35 and h.potions > 0 and _int_cd <= 0.0:
		pressed.append("potion")
		_int_cd = 2.0
	var e: Enemy = _enemy_threat()
	if e != null:
		var to: Vector3 = e.global_position - h.global_position
		to.y = 0.0
		if h.lock_target == null:
			pressed.append("lock")
		if to.length() > 2.0:
			out.move = h.stick_for(to.normalized())
		elif e.state == "attack" and _rng.randf() < 0.05:
			pressed.append("dodge")
			out.move = h.stick_for(to.normalized().cross(Vector3.UP))
		elif h.skill_tier > 0 and h.skill_cd <= 0.0:
			pressed.append("skill")  # a player uses the shiny new button
		elif _atk_cd <= 0.0:
			_atk_cd = 0.4
			pressed.append("attack")
		out.pressed = pressed
		return out
	# the FALAR / ABRIR / PEGAR button is on screen: press it
	if _interact_shown():
		if _int_cd <= 0.0:
			pressed.append("interact")
			dialog_opened += 1
			_int_cd = 3.0
	# follow the quest arrow (the HUD's own target), else wander
	# follow the arrow on screen (it goes along roads); fall back to the raw goal if the HUD has none
	var target: Variant = g.hud.quest_target if g.hud.quest_target is Vector3 else Hud.quest_pos(g.quests.current(), g.map)
	# the quest card says "Recomendado: Nv X · treine com o Caçador": do what it says
	var farming: bool = str(g._quest_note(g.quests.current())) != ""
	if farming:
		if not g.farm.has_active():
			var best_h: Dictionary = {}
			var bh: float = 1e12
			for hh: Dictionary in g._hunters:
				if int(Zones.range_of(hh.place)[1]) <= g.prog.level + 1 and hh.pos.distance_to(h.global_position) < bh:
					bh = hh.pos.distance_to(h.global_position)
					best_h = hh
			if not best_h.is_empty():
				target = best_h.pos
		else:
			var fk: String = str(g.farm.active.kind)
			var fd: float = 1e12
			for n in get_nodes_in_group("enemies"):
				var fe := n as Enemy
				if fe and not fe.dead and fe.kind == fk and fe.global_position.distance_to(h.global_position) < fd:
					fd = fe.global_position.distance_to(h.global_position)
					target = fe.global_position
	# enemies marked ⚔ on their nameplate (visible within ~28 m) are what the quest wants: go fight them
	var best_e: float = 28.0
	for n in get_nodes_in_group("enemies"):
		var en := n as Enemy
		if en == null or en.dead or not en.visible or not g._plates.has(en):
			continue
		var d: float = en.global_position.distance_to(h.global_position)
		var want_k: String = str(g.quests.current().get("target", ""))
		var story_kill: bool = str(g.quests.current().get("type", "")) == "kill" and ((want_k == "boss" and en is Boss) or (want_k != "boss" and en.kind == want_k))
		if d < best_e and story_kill and Zones.danger(en.level, g.prog.level) < 2:
			best_e = d
			target = en.global_position
	# a quest star visible on screen nearby beats the far arrow (players walk to what glows)
	var best_d: float = 45.0
	for id in g._item_marks:
		var l: Label3D = g._item_marks[id]
		var d: float = l.global_position.distance_to(h.global_position)
		if d < best_d:
			best_d = d
			target = l.global_position
	_dbg_target = target
	var dir: Vector3 = Vector3.ZERO
	if target is Vector3 and _wander_t <= 0.0:
		dir = (target as Vector3) - h.global_position
		dir.y = 0.0
		if dir.length() < 1.5:
			dir = Vector3.ZERO
	else:
		_wander_t -= 1.0 / 30.0
		if _wander == Vector3.ZERO or _rng.randf() < 0.004:
			_wander = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		dir = _wander
	if dir != Vector3.ZERO:
		out.move = h.stick_for(dir.normalized())
	out.pressed = pressed
	return out


func _interact_shown() -> bool:
	# what the player sees: the contextual button has a label
	return Touch._interact_label != ""


func _nearby() -> Array:
	var out: Array = []
	for n in get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and e.global_position.distance_to(hero.global_position) < 60.0:
			out.append({"kind": e.kind, "lvl": e.level, "state": e.state, "dead": e.dead, "vis": e.visible, "pm": e.process_mode,
				"d": snappedf(e.global_position.distance_to(hero.global_position), 0.1), "plate": str((g._plates[e] as Label3D).text) if g._plates.has(e) else ""})
	return out


func _report() -> void:
	var rep: Dictionary = {"minutes": minutes, "final_level": g.prog.level, "gold": g.prog.gold, "deaths": deaths,
		"stuck_events": stuck_events, "stuck_spots": stuck_spots.slice(0, 15), "areas_seen": areas,
		"quests_done": quest_times, "current_quest": g.quests.current().get("text", ""),
		"longest_quest_stall_s": snappedf(_max_quest_stall, 1), "stalled_on": _stall_quest,
		"interact_presses": dialog_opened, "farm_active": g.farm.active, "inventory": g.items.list().map(func(x): return x.name),
		"timeline": log, "nearby_enemies": _nearby()}
	var f := FileAccess.open("res://tools/playtest_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rep, "  "))
	f.close()
	print("PLAYTEST level=%d deaths=%d stuck=%d areas=%d quests=%s stall=%ds on [%s] interact=%d" % [g.prog.level, deaths,
		stuck_events, areas.size(), quest_times.keys(), int(_max_quest_stall), _stall_quest, dialog_opened])
