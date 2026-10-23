# PROTOTYPE - NOT FOR PRODUCTION
# Headless checks for the Blox-Fruits-style loop: zone levels, loot rarity odds, hunting contracts, and the live
# game path (accept a contract at a hunter, kill through main.damage, a chest drops, opening it adds the item).
#   godot --headless --path . -s tests/test_farm_loot.gd
extends SceneTree

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	# zones
	ok(Zones.level_for("village", 0) == 1, "village starts at 1")
	ok(Zones.level_for("castle", 3) == 25, "castle range wraps to 25")
	ok(Zones.danger(20, 5) == 2 and Zones.danger(7, 5) == 1 and Zones.danger(5, 5) == 0, "danger bands")
	# loot odds: rarer is rarer, every rarity has items, boss never drops below raro
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n: Dictionary = {}
	for i in 20000:
		var r: String = Loot.roll_rarity(1, rng)
		n[r] = int(n.get(r, 0)) + 1
	print("  rarity x20000 at lvl1: ", n)
	ok(int(n.comum) > int(n.incomum) and int(n.incomum) > int(n.raro) and int(n.raro) > int(n.epico) and int(n.epico) > int(n.get("lendario", 0)), "rarity order")
	ok(int(n.get("lendario", 0)) > 0 and int(n.get("lendario", 0)) < 300, "legendary is rare but possible")
	for r: String in Loot.RARITIES:
		ok(not Loot.pool(r).is_empty(), "items exist for " + r)
	for i in 200:
		ok(Loot.RARITIES.find(Loot.roll(26, rng, true).rarity) >= 2, "boss chest is raro+")
	# rarer weapons hit harder
	ok(int(Items.def("machado_dragao").dmg) > int(Items.def("espada_brasa").dmg) and int(Items.def("espada_brasa").dmg) > int(Items.def("espada_vigilia").dmg)
		and int(Items.def("espada_vigilia").dmg) > int(Items.def("espada_soldado").dmg) and int(Items.def("espada_soldado").dmg) > int(Items.def("espada_enferrujada").dmg), "weapon power follows rarity")
	# contract
	var f := Farm.new()
	f.accept(Farm.offer("forest", "wolf_imp"))
	for i in 4:
		ok(f.on_kill("wolf_imp").is_empty(), "not done yet")
	ok(f.on_kill("bandit").is_empty() and int(f.active.have) == 4, "other kinds do not count")
	var done: Dictionary = f.on_kill("wolf_imp")
	ok(not done.is_empty() and not f.has_active(), "5th kill finishes")
	# Joana's forge and selling
	var it := Items.new()
	var pr := Progression.new()
	it.add("espada_soldado")
	it.equip("espada_soldado")
	var base: int = it.weapon_damage()
	pr.add_gold(300)
	ok(it.upgrade("espada_soldado", pr) and it.upgrade("espada_soldado", pr), "two upgrades for 100 + 200 gold")
	ok(pr.gold == 0 and it.upgrade_level("espada_soldado") == 2, "gold spent, level 2")
	ok(it.weapon_damage() > base, "upgraded weapon hits harder")
	ok(not it.upgrade("espada_soldado", pr), "no upgrade without gold")
	ok(it.sell_price("espada_soldado") == 0, "the only copy you hold in hand is not for sale")
	it.add("espada_enferrujada", 3)
	ok(it.sell_duplicate_commons(pr) == 2 * int(Items.SELL["comum"]) and it.count("espada_enferrujada") == 1, "duplicate commons sold, one kept")
	ok(it.sell_price("nabo") == 0 and it.sell_price("semente_carvalha") == 0, "quest items and seeds are not for sale")
	var it2 := Items.new()
	it2.from_dict(it.to_dict())
	ok(it2.upgrade_level("espada_soldado") == 2, "upgrades survive save/load")
	# achievements: quick first goals, nothing twice
	var ach_done: Dictionary = {}
	var got: Array = Achievements.reached({"level": 2, "kills": 10}, func(k: String) -> bool: return ach_done.has(k))
	ok(got.size() == 2, "level 2 + 10 kills unlock the first two achievements")
	for a in got: ach_done[Achievements.key(str(a.id))] = true
	ok(Achievements.reached({"level": 2, "kills": 10}, func(k: String) -> bool: return ach_done.has(k)).is_empty(), "no achievement twice")
	await _live()
	print("%s: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# the Pastos da Cauda: the place, its Marco, camps and the s7 targets exist, and the drove road up the Passo da
# Escama never gets steeper than a walkable grade
func _check_cauda(g: Node3D) -> void:
	var ids: Dictionary = {}
	for p: Dictionary in g.map.places:
		ids[str(p.id)] = p
	ok(ids.has("cauda") and ids.has("cauda_ponta") and ids.has("passo_escama"), "Pastos da Cauda places exist")
	ok(Zones.LEVELS.has("cauda") and int(Zones.range_of("cauda_ponta")[1]) > int(Zones.range_of("castle")[1]), "Cauda levels continue past the castle")
	var it_ids: Dictionary = {}
	for it: Dictionary in g.map.interactables:
		it_ids[str(it.id)] = it
	ok(it_ids.has("marco_cauda") and it_ids.has("sino_mae"), "Marco da Cauda and the Sino-Mãe are on the map")
	var q: Dictionary = Quests.quest("s7")
	var kinds_at: Dictionary = {}
	for c: Dictionary in g.map.camps:
		for k: String in c.kinds:
			kinds_at[str(c.place) + ":" + k] = true
	for i in (q.steps as Array).size():
		var s: Dictionary = Quests.step_of(q, i)
		match s.type:
			"reach": ok(ids.has(s.target), "s7 reach target %s is a place" % s.target)
			"interact": ok(it_ids.has(s.target), "s7 interact target %s is on the map" % s.target)
			"kill": ok(kinds_at.has(s.where + ":" + s.target), "s7 kill target %s camps at %s" % [s.target, s.where])
	var road: Dictionary = {}
	for r: Dictionary in g.map.terrain.roads:
		if str(r.id) == "cauda":
			road = r
	var pts: PackedVector3Array = road.pts
	var steep: float = 0.0
	for k in pts.size() - 1:
		var run: float = Vector2(pts[k + 1].x - pts[k].x, pts[k + 1].z - pts[k].z).length()
		steep = maxf(steep, absf(g.map.ground_y(pts[k + 1].x, pts[k + 1].z) - g.map.ground_y(pts[k].x, pts[k].z)) / maxf(run, 0.5))
	ok(steep < 0.5, "the drove road up the pass is walkable (max grade %.2f)" % steep)
	ok(g.map.ground_y(376, 12) > 25.0 and g.map.ground_y(292, 30) > g.map.ground_y(292, 11) + 25.0, "the Cauda is a plateau reached through a gorge")


func _live() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sementes2_save.json"))  # start from a new game
	var g: Node3D = load("res://main.tscn").instantiate()
	root.add_child(g)
	for i in 5:
		await process_frame
	ok(not g._hunters.is_empty(), "hunters spawned")
	# audio: buses exist, the ambience bed follows the area and the music follows the mood
	ok(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Ambience") >= 0, "audio buses Music/SFX/Ambience")
	var w: AudioStreamWAV = GameAudio.bed("forest", 2.0)
	ok(w.loop_end == 2 * GameAudio.RATE and w.data.size() == 4 * GameAudio.RATE and w.data.count(0) < w.data.size() / 2, "a synthesised ambience bed loops and is not silent")
	var au: GameAudio = g.audio
	ok(au != null and au.is_inside_tree(), "the audio node exists")
	au.update("village", "calm")
	for i in 600:
		if au.amb_key == "village":
			break
		await process_frame
	var village_bed: AudioStream = au.amb[au._amb_i].stream
	ok(au.amb_key == "village" and village_bed != null and au.music_key == "town", "village ambience + town music (%s, %s)" % [au.amb_key, au.music_key])
	au.update("mine", "calm")
	for i in 600:
		if au.amb_key == "mine":
			break
		await process_frame
	ok(au.amb_key == "mine" and au.amb[au._amb_i].stream != village_bed and au.music_key == "dungeon", "entering the mine switches the ambience stream and music")
	au.update("forest", "fight")
	ok(au.music_key == "dungeon", "a fight nearby swaps to the fight track")
	au.update("forest", "boss")
	ok(au.music_key == "boss", "the Conde gets the boss track")
	au._hold = 0.0
	au.update("forest", "calm")
	ok(au.music_key == "forest", "calm again: exploration track")
	ok(GameAudio.mood([], Vector3.ZERO, null) == "calm", "no enemies, calm mood")
	ok(g._boss != null and is_instance_valid(g._boss), "the final boss exists in the world (it did not, so the game could not be finished)")
	var guard: Enemy = g._spawn_enemy("knight", 24, g._boss.global_position + Vector3(6, 0, 0))
	g._clear_duel()
	ok(not g._actors.has(guard), "knights near the Conde leave when the duel starts")
	var mc: bool = false
	for it: Dictionary in g.map.interactables:
		mc = mc or str(it.id) == "marco_castelo"
	ok(mc, "a Marco waits outside the castle gate")
	_check_cauda(g)
	# a pickup the quest is collecting beats the townsperson standing next to it (Rosa at her inn door)
	var cartas: Dictionary = {}
	for it: Dictionary in g.map.interactables:
		if str(it.id) == "cartas_rosa":
			cartas = it
	g.quests.state["s1"] = "active"
	g.quests.step_i["s1"] = 0
	g.hero.global_position = cartas.pos + Vector3(0.5, 0.3, 0)
	g._on_interact()
	ok(g._taken.has("cartas_rosa") and not g.dialog.visible, "quest pickup taken instead of opening the innkeeper's dialog")
	if g.dialog.visible:
		g.dialog.close()
	# the pier's fishing spot gives a fish every cast (it gave nothing: the side quest stalled at the extras)
	var spot: Dictionary = {}
	for it: Dictionary in g.map.interactables:
		if str(it.get("kind", "")) == "fishing":
			spot = it
	g.quests.state["s6"] = "active"
	g.quests.step_i["s6"] = 0
	var fish0: int = g.items.count("peixe_lua")
	for k in 3:
		g._use_interactable(spot)
	ok(g.items.count("peixe_lua") == fish0 + 3 and int(g.quests.step_i["s6"]) >= 1, "three casts at the pier land three peixes-lua")
	# Noites de Brasa: after the story one golden elite per area, each beaten once and saved, epic chest
	g._elites_tick()
	ok(g._elites.is_empty(), "no elites before the ending")
	g.quests.state["m14"] = "done"
	g._elites_tick()
	ok(g._elites.size() == g._elite_places().size() and g._elites.size() >= 8, "one elite per area after the ending (%d)" % g._elites.size())
	ok(not Hud.idle_fn.call().is_empty(), "with no quest the card points at an elite")
	var el: Enemy = g._elites[0]
	var nchest: int = g._chests.size()
	while not el.dead:
		g.damage(el, 99999.0, g.hero, "light")
	ok(g._elites_beaten() == 1 and g._chests.filter(func(c: Dictionary) -> bool: return c.has("epic")).size() == 1, "a beaten elite is saved and leaves an epic chest")
	ok(Loot.RARITIES.find(Loot.roll(30, g.rng, false, "epico").rarity) >= 3, "an elite chest rolls epico or better")
	var keep: Array = g._elites.duplicate()
	g._elites.clear()
	ok(str(Hud.idle_fn.call().get("title", "")) == "Tesouros escondidos", "with every elite down the card counts the hidden treasure")
	g._elites.assign(keep)
	g.quests.state.erase("m14")
	# hidden treasure: 12 chests that never expire, found ones counted and saved
	var tr: Array = g._chests.filter(func(c: Dictionary) -> bool: return c.has("treasure"))
	ok(tr.size() == g.TREASURES, "all 12 hidden treasures placed (%d)" % tr.size())
	var t0: Dictionary = tr[0]
	g._age_chests(1000.0)
	ok(g._chests.has(t0), "a treasure does not expire like an enemy chest")
	g._open_chest(t0)
	ok(g._treasures_found() == 1 and g.prog.has_unlock(str(t0.treasure)), "opening a treasure counts and saves it")
	var h: Dictionary = g._hunters[0]
	g.hero.global_position = h.pos + Vector3(1, 0, 0)
	g._open_hunter(h)
	g._on_choice("cacador", "aceitar")
	ok(g.farm.has_active(), "contract accepted at the hunter")
	var kind: String = str(g.farm.active.kind)
	g.rng.seed = 1
	var killed: int = 0
	var lvl0: int = g.prog.level
	for e in get_nodes_in_group("enemies"):
		if e is Enemy and not (e as Enemy).dead and (e as Enemy).kind == kind and not e is Boss and killed < 5:
			g.damage(e, 99999.0, null, "heavy")
			killed += 1
	ok(killed == 5 and not g.farm.has_active(), "5 kills finish the contract in game (killed %d)" % killed)
	ok(g.prog.level > lvl0, "xp from kills + contract levels the hero")
	ok(g.prog.points == 0, "level-up points are spent automatically by default")
	# fast travel between two discovered Marcos
	var rests: Array = g.map.interactables.filter(func(it): return str(it.kind) == "rest")
	ok(rests.size() >= 2, "at least two Marcos exist")
	g._marcos_seen[str(rests[0].id)] = rests[0].pos
	g._marcos_seen[str(rests[1].id)] = rests[1].pos
	g._offer_travel(str(rests[0].id))
	g._on_choice("marco", "tp:" + str(rests[1].id))
	ok(g.hero.global_position.distance_to(rests[1].pos) < 3.0, "fast travel lands at the chosen Marco")
	# special moves unlock by level
	g.prog.level = 10
	g._update_skill(true)
	ok(g.hero.skill_tier == 1 and str(Touch.label_override.get("skill", "")) == "INVESTIDA", "Investida at level 10")
	g.prog.level = 20
	g._update_skill(true)
	ok(g.hero.skill_tier == 2 and str(Touch.label_override.get("skill", "")) == "GIRO", "Giro at level 20")
	# force a chest and open it
	var bag0: int = g.items.list().size()
	g._spawn_chest(g.hero.global_position, 10, true)
	var c: Dictionary = g._nearest_chest()
	ok(not c.is_empty(), "chest in reach")
	g._open_chest(c)
	ok(g.items.list().size() > bag0, "chest item lands in the inventory")
	g.queue_free()
