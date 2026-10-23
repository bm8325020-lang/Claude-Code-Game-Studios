# PROTOTYPE - NOT FOR PRODUCTION
# CPU probe: runs the playtest bot and reports the CPU cost of a frame, split into stages with marker nodes at the
# ends of the process priority order (scripts + animation in _process, scripts in _physics_process, the physics
# engine step), with the hero, the enemies and the HUD bracketed on their own. Every 15th frame it also times the
# main.gd/HUD hot paths by calling them once more (those frames are left out of the stage numbers).
#   godot --headless --path . --fixed-fps 30 -s tools/cpu_probe.gd -- [minutes=1] [seed=5]
# Numbers are desktop ms; a mid-range phone is several times slower, so compare before/after on the same machine.
extends "res://tools/player_bot.gd"


class Mark extends Node:
	var on_tick: Callable
	func _init(prio: int, cb: Callable) -> void:
		process_priority = prio
		process_physics_priority = prio
		process_mode = Node.PROCESS_MODE_ALWAYS
		on_tick = cb
	func _process(_dt: float) -> void: on_tick.call(false)
	func _physics_process(_dt: float) -> void: on_tick.call(true)


const SAMPLE_EVERY: int = 15
const HERO_P: int = -50000
const ENEMY_P: int = -40000
const HUD_P: int = 50000
var _frame: int = 0
var _boot_ms: int = -1
var _skip: bool = true  # warm-up and sampled frames are left out
var _stats: Dictionary = {}  # name -> [sum_us, worst_us, count]
var _m: Dictionary = {}  # mark name -> ticks_usec this frame
var _bot_us: int = 0
var _totals: Array[float] = []  # per-frame totals, for the 99th percentile (worst is one-off noise on a shared box)


func _add(key: String, us: float) -> void:
	var s: Array = _stats.get(key, [0.0, 0.0, 0])
	s[0] += us
	s[1] = maxf(s[1], us)
	s[2] += 1
	_stats[key] = s


func _time(key: String, f: Callable) -> void:
	var t0: int = Time.get_ticks_usec()
	f.call()
	_add(key, Time.get_ticks_usec() - t0)


func _mark(name: String, prio: int) -> void:
	root.add_child(Mark.new(prio, func(phys: bool) -> void: _m[("ph_" if phys else "pr_") + name] = Time.get_ticks_usec()))


func _frame_done() -> void:
	# called at the start of a physics tick: the previous frame is complete
	if not _skip and _m.size() >= 12:
		_totals.append(_m.ph_start2 - _m.ph_start - _bot_us - int(_m.get("bot_input", 0)))
		_add("FRAME total (cpu, minus bot)", _m.ph_start2 - _m.ph_start - _bot_us - int(_m.get("bot_input", 0)))
		_add("  physics: scripts (all _physics_process)", _m.ph_end - _m.ph_start - int(_m.get("bot_input", 0)))
		_add("    hero._physics_process (minus bot input)", _m.ph_hero1 - _m.ph_hero0 - int(_m.get("bot_input", 0)))
		_add("    enemies _physics_process", _m.ph_en1 - _m.ph_en0)
		_add("  physics: engine step + misc", _m.pr_start - _m.ph_end - _bot_us)
		_add("  process: scripts + anim (all _process)", _m.pr_end - _m.pr_start)
		_add("    hero _process/anim", _m.pr_hero1 - _m.pr_hero0)
		_add("    enemies _process/anim", _m.pr_en1 - _m.pr_en0)
		_add("    hud._process", _m.pr_hud1 - _m.pr_hud0)
		_add("  after process (interp, render, idle)", _m.ph_start2 - _m.pr_end)
	_skip = false


func _tick(dt: float) -> void:
	if _boot_ms < 0:
		_boot_ms = Time.get_ticks_msec()  # engine start -> main.tscn loaded and its first frame done
		root.add_child(Mark.new(-100001, func(phys: bool) -> void:
			if phys:
				_m["ph_start2"] = Time.get_ticks_usec()
				_frame_done()
				_m.clear()
				_m["ph_start"] = Time.get_ticks_usec()))
		_mark("start", -100000)
		_mark("end", 100000)
		_mark("hero0", HERO_P - 1)
		_mark("hero1", HERO_P + 1)
		_mark("en0", ENEMY_P - 1)
		_mark("en1", ENEMY_P + 1)
		_mark("hud0", HUD_P - 1)
		_mark("hud1", HUD_P + 1)
		hero.set_bot(func(h: Hero) -> Dictionary:  # the bot's input runs inside hero._physics_process: time it apart
			var b0: int = Time.get_ticks_usec()
			var r: Dictionary = _bot(h)
			_m["bot_input"] = int(_m.get("bot_input", 0)) + Time.get_ticks_usec() - b0
			return r)
	if _frame < 60 or paused:
		_skip = true
	_frame += 1
	if _frame % 30 == 1:  # respawned enemies join the bracket
		_bracket(hero, HERO_P)
		_bracket(g.hud, HUD_P)
		for e: Node in g.get_tree().get_nodes_in_group("enemies"):
			_bracket(e, ENEMY_P)
	var t0: int = Time.get_ticks_usec()
	super._tick(dt)
	_bot_us = Time.get_ticks_usec() - t0
	_add("bot._tick (probe overhead, excluded)", _bot_us)
	if _frame % SAMPLE_EVERY == 0 and not g.dialog.is_open and not paused:
		_skip = true
		var q: Dictionary = g.quests.current()
		_time("main._process (whole, sampled)", func() -> void: g._process(0.0))
		_time("main._update_interact_prompt", g._update_interact_prompt)
		_time("main._nearest_interactable", g._nearest_interactable)
		_time("main._quest_interactable", g._quest_interactable)
		_time("main._area", g._area)
		_time("main._place_id", func() -> void: g._place_id(hero.global_position))
		_time("main._refresh_marks", g._refresh_marks)
		_time("main._sleep_far_actors", g._sleep_far_actors)
		_time("main._check_achievements", g._check_achievements)
		_time("main._elites_tick", g._elites_tick)
		_time("hud._poll_systems", g.hud._poll_systems)
		_time("Hud.quest_pos", func() -> void: Hud.quest_pos(q, g.map))
		var goal: Variant = Hud.quest_pos(q, g.map)
		if goal is Vector3:
			_time("main._route", func() -> void: g._route(goal))


# a node and its whole subtree (skeleton, AnimationTree) run at prio, between the two marks around it
func _bracket(n: Node, prio: int) -> void:
	for c: Node in [n] + n.find_children("*", "", true, false):
		c.process_priority = prio
		c.process_physics_priority = prio


func _report() -> void:
	print("CPU_PROBE boot_ms=%d frames=%d enemies=%d interactables=%d" % [_boot_ms, _frame,
		g.get_tree().get_nodes_in_group("enemies").size(), (g.map.interactables as Array).size()])
	_totals.sort()
	if not _totals.is_empty():
		print("CPU_PROBE FRAME total p50 %.3f ms  p99 %.3f ms" % [_totals[_totals.size() / 2] / 1000.0, _totals[int(_totals.size() * 0.99)] / 1000.0])
	for k: String in _stats:
		var s: Array = _stats[k]
		print("CPU_PROBE %-44s avg %7.3f ms  worst %7.3f ms  n=%d" % [k, s[0] / s[2] / 1000.0, s[1] / 1000.0, s[2]])
	super._report()
