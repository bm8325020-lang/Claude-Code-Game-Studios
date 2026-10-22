# PROTOTYPE - NOT FOR PRODUCTION
# Self-check for rpg.gd. Run: godot --headless --path . -s tests/rpg_test.gd  (prints RPG TESTS OK or the failure)
extends SceneTree

const Rpg = preload("res://rpg.gd")

func _init() -> void:
	var base := {"vig": 10, "fol": 10, "for": 10, "des": 10, "int": 10}
	var s := Rpg.derive(base, {})
	assert(s.max_hp == 150.0 and s.max_stamina == 100.0 and s.max_essence == 100.0)
	assert(is_equal_approx(s.sword_mult, 1.0) and is_equal_approx(s.seed_mult, 1.0))
	# vigor softens past 30
	var tank := base.duplicate()
	tank.vig = 40
	assert(Rpg.derive(tank, {}).max_hp == 100.0 + 150.0 + 20.0)
	# talents stack on top of attributes
	var t := Rpg.derive(base, {"lamina": true, "ferro": true, "leve": true})
	assert(is_equal_approx(t.sword_mult, 1.1) and t.taken_mult == 0.85 and t.roll_cost == 0.7)
	# destreza makes swings cheaper, never below 70%
	var nimble := base.duplicate()
	nimble.des = 60
	assert(Rpg.derive(nimble, {}).stamina_cost == 0.7)
	# the tree is ordered within a branch
	assert(Rpg.can_learn("lamina", {}) and not Rpg.can_learn("sangue", {}) and Rpg.can_learn("sangue", {"lamina": true}))
	assert(not Rpg.can_learn("lamina", {"lamina": true}) and not Rpg.can_learn("nope", {}))
	assert(Rpg.talent_points(1, 0, 0) == 0 and Rpg.talent_points(5, 1, 1) == 4)
	# every class spends the same attribute budget
	for k in Rpg.CLASSES:
		var sum := 0
		for a in Rpg.ATTRS:
			sum += Rpg.CLASSES[k].attrs[a]
		assert(sum == 58, k)
	assert(Rpg.weakness("sentinel", "raio") > 1.0 and Rpg.weakness("sentinel", "fogo") < 1.0 and Rpg.weakness("minion", "gelo") == 1.0)
	assert(Rpg.upgrade_cost(0) == [1, 200] and is_equal_approx(Rpg.upgrade_mult(5), 1.5))
	var qs := {"lit": {"Santuário da Chama": true}, "sentinels_dead": false, "bells": 0, "elevator_open": false,
		"shards_found": 0, "best_upgrade": 0, "talents": 0, "kills": 0}
	assert(Rpg.current_objective(qs) == "Acenda a fogueira do Burgo dos Esquecidos")
	qs.lit["Burgo dos Esquecidos"] = true
	assert(Rpg.current_objective(qs).begins_with("Atravesse"))
	print("RPG TESTS OK")
	quit()
