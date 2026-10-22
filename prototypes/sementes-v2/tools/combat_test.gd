# PROTOTYPE - NOT FOR PRODUCTION
# Combat test: flat meadow, the hero on autopilot fights each enemy kind in waves (bare fists against imps, then
# sword and shield), then Dom Aurélio through his three phases. Damage goes through a stand-in main.damage() on the
# scene root, so the routing contract is exercised too.
#   headless: $G --headless --path . --fixed-fps 60 -s tools/combat_test.gd
#   shots:    xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --resolution 1280x720 \
#               --fixed-fps 60 -s tools/combat_test.gd      -> tools/shots/combat_*.png
extends SceneTree

const SHOTS: String = "res://tools/shots/"
const WAVES: Array = [
	{"name": "imps_unarmed", "kinds": ["wolf_imp", "wolf_imp", "wolf_imp"], "level": 1, "time": 50.0},
	{"name": "bandits", "kinds": ["bandit", "bandit", "bandit_archer"], "level": 1, "time": 60.0},
	{"name": "puglins", "kinds": ["puglin", "puglin", "puglin", "puglin"], "level": 2, "time": 50.0},
	{"name": "possessed", "kinds": ["possessed", "possessed"], "level": 1, "time": 60.0},
	{"name": "knight", "kinds": ["knight"], "level": 1, "time": 70.0},
	{"name": "boss", "kinds": ["boss"], "level": 1, "time": 200.0},
]
const MAIN_SRC: String = "extends Node3D\nvar routed: int = 0\nfunc damage(target, amount, source, kind):\n\trouted += 1\n\treturn target.take_hit(amount, source, kind)\n"

var world: Node3D
var hero: Hero
var hud: Label
var headless: bool = false
var wave: int = -1
var wave_t: float = 0.0
var sim_t: float = 0.0
var alive: Array = []
var stats: Dictionary = {"kills": 0, "hits": 0, "blocked": 0, "parried": 0, "dodged": 0, "hurt": 0, "deaths": 0, "timeouts": 0, "potions": 0}
var shots: Array[String] = []
var _pending_shot: String = ""
var _shot_delay: int = 0
var _boss: Boss = null
var _done_t: float = -1.0
# bot memory
var _b_press: float = 0.0
var _b_block: float = 0.0
var _b_side: float = 1.0
var _b_react_cd: float = 0.0


func _initialize() -> void:
	seed(12345)


# Built on the first frame: nodes added during _initialize are not inside the tree yet.
func _setup() -> void:
	headless = DisplayServer.get_name() == "headless"
	world = Node3D.new()
	var gs := GDScript.new()
	gs.source_code = MAIN_SRC
	gs.reload()
	world.set_script(gs)
	root.add_child(world)
	current_scene = world
	_build_arena()
	hero = Hero.new()
	world.add_child(hero)
	hero.global_position = Vector3(0, 0.05, 0)
	hero.max_hp = 400.0
	hero.max_potions = 12
	hero.potion_heal = 120.0
	hero.refill()
	hero.set_bot(_bot)
	hero.hit_landed.connect(func(_t: Node3D, _a: float, r: String) -> void:
		stats["hits"] += 1
		_wave_hits += 1
		if r == "blocked":
			stats["blocked"] += 1)
	hero.hurt.connect(func(_a: float, _s: Node, r: String) -> void:
		if r == "parried":
			stats["parried"] += 1
		else:
			stats["hurt"] += 1)
	hero.died.connect(func() -> void:
		stats["deaths"] += 1
		print("hero died in wave ", wave)
		create_timer(2.0).timeout.connect(func() -> void: hero.revive(hero.global_position)))
	hero.potions_changed.connect(func(_n: int) -> void: stats["potions"] += 1)
	var cl := CanvasLayer.new()
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	cl.add_child(hud)
	world.add_child(cl)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	_next_wave()


func _build_arena() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.6, 0.85)
	sm.sky_horizon_color = Color(0.95, 0.8, 0.6)
	sm.ground_horizon_color = Color(0.8, 0.7, 0.55)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.9, 0.8, 0.65)
	e.fog_density = 0.004
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-40), 0)
	world.add_child(sun)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	cs.shape = box
	cs.position.y = -0.5
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	var mat := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	nt.noise = fn
	nt.seamless = true
	nt.color_ramp = Gradient.new()
	nt.color_ramp.set_color(0, Color(0.36, 0.45, 0.2))
	nt.color_ramp.set_color(1, Color(0.55, 0.58, 0.3))
	mat.albedo_texture = nt
	mat.uv1_scale = Vector3(12, 12, 1)
	mat.roughness = 0.95
	pm.material = mat
	mi.mesh = pm
	ground.add_child(mi)
	world.add_child(ground)
	# a little dressing so the screenshots read as a place
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var props: Array[String] = ["res://assets/nature/CommonTree_1.gltf", "res://assets/nature/CommonTree_3.gltf",
		"res://assets/nature/Pine_2.gltf", "res://assets/nature/Bush_Common_Flowers.gltf", "res://assets/props/Barrel.gltf",
		"res://assets/props/Crate_Wooden.gltf", "res://assets/nature/Grass_Common_Tall.gltf"]
	for i in 46:
		var p: String = props[rng.randi() % props.size()]
		if not ResourceLoader.exists(p):
			continue
		var n: Node3D = (load(p) as PackedScene).instantiate()
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(16.0, 34.0) if p.contains("Tree") or p.contains("Pine") else rng.randf_range(9.0, 22.0)
		n.position = Vector3(cos(a) * r, 0, sin(a) * r)
		n.rotation.y = rng.randf() * TAU
		n.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		world.add_child(n)


var _wave_hits: int = 0
func _next_wave() -> void:
	if wave >= 0:
		print("  wave ", wave, " ended: hits=", _wave_hits, " t=", snappedf(wave_t, 0.1))
	_wave_hits = 0
	wave += 1
	wave_t = 0.0
	alive.clear()
	_boss = null
	if wave >= WAVES.size():
		_done_t = 0.0
		return
	var w: Dictionary = WAVES[wave]
	if wave == 1:
		hero.equip({"body": "Male", "outfit": "Ranger", "hair": "Hair_SimpleParted", "weapon": "Sword_Bronze", "shield": "Shield_Wooden"})
	hero.refill()
	var kinds: Array = w["kinds"]
	var fwd: Vector3 = hero.global_position + Vector3(0, 0, -12)
	for i in kinds.size():
		var a: float = (float(i) - float(kinds.size() - 1) * 0.5) * 0.5
		var p: Vector3 = fwd + Vector3(sin(a) * 4.0, 0.1, cos(a) * 2.0)
		var en: Enemy
		if String(kinds[i]) == "boss":
			_boss = Boss.spawn_boss(world, p)
			en = _boss
			_boss.phase_changed.connect(func(ph: int) -> void:
				print("boss phase ", ph, " at t=", snappedf(wave_t, 0.1))
				_queue_shot("boss_phase%d" % ph, 40))
			_boss.spoke.connect(func(l: String) -> void: print("boss says: ", l))
			_boss.fell_asleep.connect(func() -> void: _queue_shot("boss_asleep", 150))
		else:
			en = Enemy.spawn(world, String(kinds[i]), int(w["level"]), p)
		en.died.connect(func(x: Enemy) -> void:
			stats["kills"] += 1
			print("  died: ", x.display_name, " hp=", snappedf(x.hp,0.1), " t=", snappedf(wave_t,0.1), " state=", x.state)
			alive.erase(x))
		alive.append(en)
	print("wave ", wave, " ", w["name"], " ", kinds)


func _queue_shot(nm: String, delay_frames: int) -> void:
	if headless or _pending_shot != "":
		return
	_pending_shot = nm
	_shot_delay = delay_frames


func _process(dt: float) -> bool:
	if world == null:
		_setup()
		return false
	sim_t += dt
	wave_t += dt
	_b_press -= dt
	_b_block -= dt
	_b_react_cd -= dt
	if _pending_shot != "":
		_shot_delay -= 1
		if _shot_delay <= 0:
			var img: Image = root.get_texture().get_image()
			var path: String = SHOTS + "combat_%02d_%s.png" % [shots.size() + 1, _pending_shot]
			img.save_png(path)
			shots.append(path)
			print("shot ", path)
			_pending_shot = ""
	if _done_t >= 0.0:
		_done_t += dt
		if _done_t > 6.0 and _pending_shot == "":
			_finish()
			return true
		_update_hud()
		return false
	var w: Dictionary = WAVES[wave]
	if wave_t > 7.0 and wave_t - dt <= 7.0:
		_queue_shot(String(w["name"]), 1)
	if wave_t > 13.0 and wave_t - dt <= 13.0 and String(w["name"]) != "boss":
		_queue_shot(String(w["name"]) + "_b", 1)
	if wave_t > float(w["time"]):
		print("TIMEOUT wave ", wave, " alive ", alive.size())
		stats["timeouts"] += 1
		for en in alive.duplicate():
			if is_instance_valid(en) and not (en as Enemy).dead:
				(en as Enemy).take_hit(99999.0, hero, "heavy")
		alive.clear()
	if alive.is_empty() and _pending_shot == "":
		_next_wave()
	if sim_t > 900.0:
		print("SIM CAP")
		_finish()
		return true
	_update_hud()
	return false


func _update_hud() -> void:
	var w: String = String(WAVES[mini(wave, WAVES.size() - 1)]["name"]) if wave < WAVES.size() else "fim"
	var txt: String = "onda %d: %s   t=%.0fs\nherói  vida %d/%d  vigor %d  frascos %d  estado %s%s\n" % [wave, w, wave_t,
		int(hero.hp), int(hero.max_hp), int(hero.stamina), hero.potions, hero.state, "  [ALVO]" if hero.lock_target != null else ""]
	for en in alive:
		if is_instance_valid(en):
			var e: Enemy = en
			txt += "%s  vida %d/%d  %s\n" % [e.display_name, int(e.hp), int(e.max_hp), e.state]
	hud.text = txt


func _finish() -> void:
	print("RESULT ", stats, " routed_by_main=", world.get("routed"), " sim_t=", snappedf(sim_t, 0.1))
	print("SHOTS ", shots)
	quit()


# ---------------------------------------------------------------- autopilot

func _bot(h: Hero) -> Dictionary:
	var out: Dictionary = {"move": Vector2.ZERO, "pressed": [], "held": []}
	var pressed: Array = out["pressed"]
	var held: Array = out["held"]
	var target: Enemy = null
	var best: float = INF
	for en in alive:
		if is_instance_valid(en) and not (en as Enemy).dead:
			var d: float = (en as Enemy).global_position.distance_to(h.global_position)
			if d < best:
				best = d
				target = en
	if target == null:
		return out
	var to: Vector3 = target.global_position - h.global_position
	to.y = 0
	var dist: float = to.length()
	if h.lock_target == null and dist < 12.0 and _b_press <= 0.0 and randf() < 0.05:
		pressed.append("lock")
		_b_press = 0.2
	elif h.lock_target != null and h.lock_target != target and _b_press <= 0.0 and randf() < 0.02:
		pressed.append("lock")  # release; relocks on the nearest next time
		_b_press = 0.2
	# react to a swing that is about to land
	var threat: Enemy = null
	for en in alive:
		if not is_instance_valid(en):
			continue
		var e: Enemy = en
		if e.dead or e.state != "attack" or bool(e.get("_atk_done")):
			continue
		var pos: float = e.ap.current_animation_position
		var hit_at: float = float(e.get("_atk_hit"))
		var ed: float = e.global_position.distance_to(h.global_position)
		if pos > hit_at - 0.3 and ed < e.reach + e.radius + 2.5:
			threat = e
	if threat != null and _b_react_cd <= 0.0 and h.state in ["free", "block", "attack"]:
		_b_react_cd = 0.9
		var r: float = randf()
		if r < 0.4:
			var side: Vector3 = Vector3(-to.z, 0, to.x).normalized() * _b_side
			_b_side = -_b_side
			out["move"] = h.stick_for(side)
			pressed.append("dodge")
			return out
		elif r < 0.75 and h.has_shield():
			_b_block = 0.6
	if _b_block > 0.0:
		held.append("block")
		out["move"] = h.stick_for(to) * 0.3
		return out
	if h.hp < h.max_hp * 0.35 and h.potions > 0 and dist > 3.0 and h.state == "free":
		pressed.append("potion")
		return out
	var touch: float = 1.6 + target.radius
	if dist > touch:
		out["move"] = h.stick_for(to)
	elif dist < 0.9:
		out["move"] = h.stick_for(-to) * 0.5
	if dist < touch + 0.6 and _b_press <= 0.0:
		_b_press = 0.22
		if target.is_open() or randf() < 0.1:
			pressed.append("heavy")
		else:
			pressed.append("attack")
	return out
