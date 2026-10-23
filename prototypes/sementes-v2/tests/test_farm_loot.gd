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
	await _live()
	print("%s: %d checks, %d failed" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _live() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sementes2_save.json"))  # start from a new game
	var g: Node3D = load("res://main.tscn").instantiate()
	root.add_child(g)
	for i in 5:
		await process_frame
	ok(not g._hunters.is_empty(), "hunters spawned")
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
	# force a chest and open it
	var bag0: int = g.items.list().size()
	g._spawn_chest(g.hero.global_position, 10, true)
	var c: Dictionary = g._nearest_chest()
	ok(not c.is_empty(), "chest in reach")
	g._open_chest(c)
	ok(g.items.list().size() > bag0, "chest item lands in the inventory")
	g.queue_free()
