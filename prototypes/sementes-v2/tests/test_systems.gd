# PROTOTYPE - NOT FOR PRODUCTION
# Headless check of systems/progression.gd, quests.gd, items.gd: plays the whole quest chain through notify(),
# checks rewards, levels, look keys and a save/load round trip. Prints PASS/FAIL and quits with 0/1.
# Run: godot --headless --path . -s tests/test_systems.gd
extends SceneTree

const PLACES: Array[String] = ["village", "farm", "river", "forest", "bandit_camp", "watchtower", "mine", "castle", "lake",
	"mina_fundo", "passo_escama", "cauda", "cauda_ponta"]
const ROLES: Array[String] = ["blacksmith", "merchant", "elder", "farmer", "fisher", "guard_captain", "innkeeper", "miner",
	"priest"]
const KINDS: Array[String] = ["wolf_imp", "bandit", "bandit_archer", "puglin", "possessed", "knight", "boss"]
const INTERACTABLES: Array[String] = ["marco_vila", "marco_quinta", "marco_bosque", "marco_atalaia", "marco_fundo",
	"forja_joana", "poste_treino", "pombal", "moinho_comporta", "ponte_rio", "carvalha_mae", "tenda_tobias",
	"farol_atalaia", "barco_celeste", "insone_tome", "mina_portao", "castelo_portao", "relicario", "marco_cauda", "sino_mae"]
const TEST_SAVE: String = "user://sementes2_test_save.json"

var fails: int = 0
var checks: int = 0


func _init() -> void:
	_check_data()
	_check_basics()
	_play_chain()
	_check_gates()
	print("%s: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0 if fails == 0 else 1)


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", what)


func _check_data() -> void:
	var ids: Dictionary = {}
	var main_min: int = 0
	var all_min: int = 0
	var mains: int = 0
	var sides: int = 0
	for q: Dictionary in Quests.DATA:
		var id: String = str(q.id)
		ok(not ids.has(id), "unique id " + id)
		ids[id] = true
		if str(q.kind) == "main":
			mains += 1
			main_min += int(q.minutes)
		else:
			sides += 1
		all_min += int(q.minutes)
		var g: String = str(q.giver)
		ok(g in ROLES or g in INTERACTABLES, "%s giver %s" % [id, g])
		for req: Variant in q.requires:
			ok(ids.has(str(req)), "%s requires earlier quest %s" % [id, req])
		for i: int in (q.steps as Array).size():
			var s: Dictionary = Quests.step_of(q, i)
			var t: String = s.target
			var valid: bool = false
			match str(s.type):
				"talk": valid = t in ROLES
				"reach": valid = t in PLACES
				"kill": valid = t in KINDS
				"collect": valid = Items.DEFS.has(t)
				"interact": valid = t in INTERACTABLES
			ok(valid, "%s step %d %s %s" % [id, i, s.type, t])
			ok(str(s.where) in PLACES, "%s step %d where %s" % [id, i, s.where])
			ok(str(s.text) != "", "%s step %d text" % [id, i])
		var r: Dictionary = q.rewards
		for it: String in (r.get("items", {}) as Dictionary):
			ok(Items.DEFS.has(it), "%s reward item %s" % [id, it])
		for u: Variant in r.get("unlocks", []) as Array:
			ok(Progression.UNLOCKS.has(str(u)), "%s unlock %s" % [id, u])
	ok(mains == 14 and sides == 7, "14 main + 7 side quests")
	ok(int(Quests.quest("m01").minutes) <= 2, "first quest about 2 minutes")
	ok(all_min >= 120 and all_min <= 180, "whole chain 2-3 h (%d min)" % all_min)
	print("  design time: main %d min, all %d min" % [main_min, all_min])


func _check_basics() -> void:
	# quest() is an id index now: same entries as a scan of DATA, {} for unknown ids
	var all_found: bool = true
	for qd: Dictionary in Quests.DATA:
		all_found = all_found and Quests.quest(str(qd.id)).get("id") == qd.id
	ok(all_found and Quests.quest("nao_existe").is_empty(), "quest() index matches DATA")
	var p: Progression = Progression.new()
	var lv: Array[int] = []
	p.leveled_up.connect(func(l: int) -> void: lv.append(l))
	ok(p.level == 1 and p.gold == 0 and p.seeds.is_empty(), "start from zero")
	p.gain_xp(Progression.xp_to_next(1) - 1)
	ok(p.level == 1, "not yet level 2")
	p.gain_xp(1 + Progression.xp_to_next(2))
	ok(p.level == 3 and lv == [2, 3] and p.points == 2, "two level-ups with signal")
	ok(p.spend_point("vigor") and int(p.attrs.vigor) == 2, "spend point")
	ok(not p.spend_point("nada"), "bad attr refused")
	ok(float(p.stats().max_hp) > 100.0, "vigor raises hp")
	ok(not p.spend_gold(1), "no gold to spend")

	var it: Items = Items.new()
	var look: Dictionary = it.look()
	ok(look.outfit == "Peasant" and look.weapon == "" and look.shield == "", "starts in peasant clothes, no weapon")
	ok(it.weapon_damage() == Items.UNARMED_DMG, "unarmed damage")
	ok(not it.equip("espada_relha"), "can't equip what you don't have")
	it.add("pao_rosa", 2)
	ok(it.use("pao_rosa") == 35 and it.count("pao_rosa") == 1, "eat bread")
	ok(it.use("nabo") == 0, "can't eat quest item")
	it.raise_refill("frasco", 2)
	it.use("frasco")
	it.use("frasco")
	ok(it.count("frasco") == 0, "flasks used")
	it.refill()
	ok(it.count("frasco") == 2, "flasks refill")
	p.add_gold(10)
	ok(it.buy("pao_rosa", p) and p.gold == 4, "buy bread")


func _play_chain() -> void:
	var q: Quests = Quests.new(Progression.new(), Items.new())
	var done: Array[String] = []
	var levels: Array[int] = []
	q.quest_done.connect(func(id: String, _r: Dictionary) -> void: done.append(id))
	q.prog.leveled_up.connect(func(l: int) -> void: levels.append(l))
	q.start_new()
	ok(q.status("m01") == "active", "m01 starts by itself")
	var c: Dictionary = q.current()
	ok(c.id == "m01" and c.type == "talk" and c.pos_kind == "npc" and c.pos_key == "innkeeper", "tracker shows Rosa")

	# stray events do nothing harmful
	q.notify("interact", "forja_joana")
	q.notify("reach", "castle")
	ok(q.status("m03") == "locked" and q.is_target("talk", "innkeeper"), "stray events ignored")

	var saved_at: String = ""
	var guard: int = 0
	while guard < 1000:
		guard += 1
		c = q.current()
		if c.is_empty():
			break
		var before: String = str(c.id)
		q.notify(str(c.type), str(c.target))
		# checkpoints right after a quest finishes
		if q.is_done(before) and done.size() > 0 and done[-1] == before:
			_checkpoint(q, before)
			if before == "m07" and saved_at == "":
				saved_at = before
				q = _round_trip(q)
				# keep listening on the reloaded instance
				q.quest_done.connect(func(id: String, _r: Dictionary) -> void: done.append(id))
				q.prog.leveled_up.connect(func(l: int) -> void: levels.append(l))
	ok(guard < 1000, "chain finishes")
	ok(saved_at == "m07", "save round trip mid-chain")
	for d: Dictionary in Quests.DATA:
		ok(q.is_done(str(d.id)), "quest done: " + str(d.id))
	print("  order: ", ", ".join(done))
	print("  final: level %d, gold %d, seeds %d, kills %s" % [q.prog.level, q.prog.gold, q.prog.seeds.size(), q.prog.kills])
	ok(q.prog.seeds.size() == Progression.SEEDS_TOTAL, "all 12 seeds at the end")
	ok(q.prog.level >= 10 and q.prog.level <= 16, "end level 10-16 (got %d)" % q.prog.level)
	ok(q.prog.has_unlock("fim"), "ending unlocked")
	ok(q.prog.has_unlock("desconto_bene") and q.prog.has_unlock("bencao_repouso"), "side unlocks")
	ok(q.items.look().outfit == "Ranger" and q.items.armor() == 11, "reinforced gibão from s5")
	ok(int(q.items.refill_max.frasco) == 4, "4 flasks: m04 2 + m13 1 + s4 1")
	ok(q.items.has("cavalinho_de_pau") and not q.items.has("nabo") and not q.items.has("elmo_vigilia"), "quest items handed in")
	ok(q.current().is_empty(), "nothing left to track")


func _checkpoint(q: Quests, id: String) -> void:
	var look: Dictionary = q.items.look()
	match id:
		"m01":
			ok(q.items.count("pao_rosa") == 3 and q.prog.gold == 10, "m01 bread and gold")
			ok(q.status("m02") == "active", "talking to the elder also starts m02")
		"m02":
			ok(q.items.count("nabo") == 0, "turnips handed in")
		"m05":
			ok(q.status("s3") == "offered", "s3 offered after m05 (its bells lie past the toll bridge)")
		"m03":
			ok(look.weapon == "Sword_Bronze" and q.items.weapon_damage() == 12, "first weapon from Joana")
		"m04":
			ok(q.prog.has_unlock("descanso") and q.prog.last_marco == "marco_quinta", "rest points unlocked")
			ok(q.items.count("frasco") == 2, "2 flasks")
			ok(q.status("s2") == "offered" and q.status("s4") == "offered", "s2 and s4 offered")
		"m06":
			ok(look.shield == "Shield_Wooden" and q.prog.has_unlock("bloqueio"), "shield and block")
		"m07":
			ok(q.prog.seeds == ["semente_carvalha"] and q.prog.skills() == ["sopro_brasa"], "1st seed and skill")
		"m08":
			ok(q.prog.seeds.size() == 2 and q.prog.has_unlock("paz_sem_terra"), "2nd seed")
		"m09":
			ok(look.outfit == "Ranger", "Ranger outfit")
		"m10":
			ok(q.prog.seeds.size() == 3 and q.prog.has_unlock("calor_lar"), "3rd seed and heal skill")
		"m11":
			ok(q.prog.seeds.size() == 4 and q.prog.has_unlock("tunel_castelo"), "4th seed and tunnel")
		"m12":
			ok(look.tier == 2 and q.items.weapon_damage() == 24 and q.items.block_mult() == 0.8, "tier 2 gear")
		"m13":
			ok(q.prog.has_unlock("castelo"), "castle access")
		"m14":
			ok(q.prog.seeds.size() == 12, "12 seeds in the reliquary")
	print("  %s done: level %d, xp %d, gold %d" % [id, q.prog.level, q.prog.xp, q.prog.gold])


func _round_trip(q: Quests) -> Quests:
	ok(q.save_game(TEST_SAVE), "save written")
	var q2: Quests = Quests.new(Progression.new(), Items.new())
	ok(q2.load_game(TEST_SAVE), "save loaded")
	ok(JSON.stringify(q2.prog.to_dict()) == JSON.stringify(q.prog.to_dict()), "progression round trip")
	ok(JSON.stringify(q2.items.to_dict()) == JSON.stringify(q.items.to_dict()), "items round trip")
	ok(JSON.stringify(q2.to_dict()) == JSON.stringify(q.to_dict()), "quests round trip")
	ok(JSON.stringify(q2.current()) == JSON.stringify(q.current()), "tracker same after load")
	ok(not Quests.new().load_game("user://nope_missing.json"), "missing save returns false")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	return q2


# world/gates.gd: every gate names a real quest step and a hint; no quest step (main or side) ever sends the
# player past a gate that is still closed at that point of the story; a gate opens at its step, and stays open
# through a save round trip
func _check_gates() -> void:
	var data: Array = preload("res://world/gates.gd").DATA
	ok(data.size() >= 4, "story gates exist")
	var ids: Array = data.map(func(d: Dictionary) -> String: return str(d.id))
	ok(ids.has("passo_escama") and ids.has("mina_portao"), "pass and mine gates")
	for d: Dictionary in data:
		var gq: Dictionary = Quests.quest(str(d.quest))
		ok(not gq.is_empty() and int(d.step) < (gq.steps as Array).size(), "gate %s opens at a real step" % d.id)
		ok(str(d.hint).length() > 10 and str(d.area) != "", "gate %s has a hint and an area" % d.id)
	for qd: Dictionary in Quests.DATA:
		var before: Dictionary = _closure(qd)
		for i in (qd.steps as Array).size():
			var st: Dictionary = Quests.step_of(qd, i)
			for d: Dictionary in data:
				if not (st.where in d.guards or st.target in d.guards):
					continue
				var open: bool = before.has(str(d.quest)) or (str(d.quest) == str(qd.id) and int(d.step) >= 0 and i >= int(d.step))
				ok(open, "%s step %d (%s) is behind gate %s while it is closed" % [qd.id, i, st.target, d.id])
	var Gates: GDScript = preload("res://world/gates.gd")
	var q := Quests.new(Progression.new(), Items.new())
	q.start_new()
	var bridge: Dictionary = data[ids.find("ponte_dizimo")]
	ok(not Gates.earned(bridge, q), "the toll bridge starts closed")
	q.state["m05"] = "active"
	q.step_i["m05"] = 1
	ok(Gates.earned(bridge, q), "the toll bridge opens at m05 step 1")
	ok(not Gates.earned(data[ids.find("passo_escama")], q), "the pass is still closed")
	q.state["m14"] = "done"
	var q2 := Quests.new(Progression.new(), Items.new())
	q2.from_dict(q.to_dict())
	ok(Gates.earned(data[ids.find("passo_escama")], q2) and Gates.earned(bridge, q2), "a loaded save keeps earned gates open")


# quest ids that must be done before this quest can run (its requires, transitively)
func _closure(qd: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var todo: Array = (qd.requires as Array).duplicate()
	while not todo.is_empty():
		var id: String = str(todo.pop_back())
		if not out.has(id):
			out[id] = true
			todo.append_array(Quests.quest(id).requires as Array)
	return out
