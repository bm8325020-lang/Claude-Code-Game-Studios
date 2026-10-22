# PROTOTYPE - NOT FOR PRODUCTION
# Boss: Dom Aurélio de Vigília, "o Conde que Não Dorme" (LORE.md). Three moments:
#   1. O cavaleiro: salutes when he sees the hero, then a clean, courteous longsword duel (combos, heavy, dash).
#   2. A lasca (below 50%): tears off the breastplate (invulnerable pause), the shard glows on his chest, he gets
#      faster and every strike leaves burning embers on the floor.
#   3. O cansaço (below 20%): slow, desperate swings, some miss from sleepiness, he speaks of his son.
# He never dies: the blow that would kill him leaves him at 1 hp, kneeling, and he falls asleep on the crypt floor.
#
#   var b := Boss.spawn_boss(parent, pos)
#
# Signals (plus Enemy's): phase_changed(phase: int), spoke(line: String), fell_asleep. `died` is also emitted when he
# falls asleep (quest "kill boss" counts it), with `dead` = true so the hero stops targeting him; the body stays.
# The wing shadow on the crypt wall (phase 2) is left to the map/main: listen to phase_changed(2).
class_name Boss
extends Enemy

signal phase_changed(phase: int)
signal spoke(line: String)
signal fell_asleep

const SON: String = "meu menino"  # LORE: he says his son's name; the name is not written yet
const LINES: Dictionary = {
	"salute": "Ninguém mais morre de frio enquanto eu vigiar.",
	"shard": "Ela ainda está acordada... e eu também!",
	"tired": "Dorme, %s... o pai está vigiando...",
	"sleep": "...tão cansado...",
}
const DATA: Dictionary = {"name": "Dom Aurélio de Vigília", "scale": 1.1,
	"look": {"body": "Male", "outfit": "Ranger", "pauldrons": true, "hair": "Hair_Long", "beard": true,
		"hair_color": Color(0.62, 0.6, 0.58), "tint": Color(0.36, 0.3, 0.34), "weapon": "Sword_Bronze"},
	"hp": 900.0, "dmg": 20.0, "speed": 3.4, "poise": 140.0, "radius": 0.5, "height": 1.95, "reach": 2.2, "notice": 22.0,
	"xp": 400, "armor": true, "idle": "Idle", "combat_idle": "Sword_Idle", "walk": "Loco_Walk", "run": "Loco_Jog",
	"hurt": "hit_light", "stagger": "hit_heavy", "die": "death",
	"attacks": [{"anim": "light1", "slow": 0.6, "lunge": 3.0, "mult": 0.9, "next": 1},
		{"anim": "light2", "slow": 0.85, "lunge": 2.5, "mult": 0.9, "next": 2, "chain_only": true},
		{"anim": "light3", "slow": 0.8, "lunge": 2.5, "mult": 1.1, "chain_only": true},
		{"anim": "heavy", "slow": 0.45, "lunge": 3.0, "mult": 1.8, "kind": "heavy"},
		{"anim": "sprint_attack", "slow": 0.55, "lunge": 2.0, "mult": 1.5, "kind": "heavy", "far": true}]}

var phase: int = 1
var _saluted: bool = false
var _shard: OmniLight3D
var _zzz_t: float = 0.0


static func spawn_boss(parent: Node, pos: Vector3) -> Boss:
	var b := Boss.new()
	b.setup("boss", 1)
	parent.add_child(b)
	b.global_position = pos
	b.home = pos
	return b


func setup(_k: String, _lvl: int) -> void:
	kind = "boss"
	level = 1
	data = DATA
	_apply_stats()
	heals_home = false


func _say(key: String) -> void:
	var line: String = LINES[key]
	if key == "tired":
		line = line % SON
	spoke.emit(line)
	Fx.text(self, global_position + Vector3(0, target_height + 0.8, 0), line, Color(1.0, 0.92, 0.8), 40, 0.25, 3.2)


func notice(spread: bool = true) -> void:
	if not _saluted and state in ["idle", "return"]:
		_saluted = true
		_set_state("salute", 2.4)
		_play("Idle_Rail_Call", 0.2)
		_say("salute")
		noticed.emit(self)
		return
	super.notice(spread)


func _custom_state(_dt: float, _to: Vector3, _dist: float) -> Array:
	match state:
		"salute":
			if t > _state_len:
				_set_state("combat")
		"phase":
			if t > 1.0 and _shard == null:
				_tear_breastplate()
			if t > _state_len:
				_set_state("combat")
	return [Vector3.ZERO, state == "salute"]


func take_hit(amount: float, source: Node, k: String = "light") -> Dictionary:
	if dead or state in ["phase", "salute"]:
		return {"result": "ignored", "damage": 0.0}
	if hp - amount <= 1.0:
		hp = 1.0
		damaged.emit(self, amount)
		_fall_asleep()
		return {"result": "hit", "damage": amount}
	return super.take_hit(amount, source, k)


func _on_damaged() -> void:
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		_set_state("phase", 2.6)
		_play("Interact", 0.15, 1.3)
		phase_changed.emit(2)
	elif phase == 2 and hp < max_hp * 0.2:
		phase = 3
		_say("tired")
		phase_changed.emit(3)


func _tear_breastplate() -> void:
	var chest: Vector3 = global_position + Vector3(0, 1.4, 0)
	Fx.embers(self, chest, 60)
	Fx.sfx(self, "dragon_roar", chest, 0.0)
	_shard = OmniLight3D.new()
	_shard.light_color = Color(1.0, 0.55, 0.2)
	_shard.light_energy = 2.2
	_shard.omni_range = 5.0
	_shard.shadow_enabled = false
	_shard.position = Vector3(0, 1.35, 0.25)
	model.add_child(_shard)
	var h: Node = hero()
	if h != null and h.has_method("shake"):
		h.call("shake", 0.7)
	_say("shard")


func _attack_speed() -> float:
	match phase:
		2:
			return 1.18
		3:
			return 0.72
	return 1.0


func _choose_attack(dist: float) -> Dictionary:
	var atks: Array = data["attacks"]
	if phase == 3 and randf() < 0.5:
		return atks[3]  # desperate heavy swings
	return atks[3] if randf() < 0.3 else atks[0]


func _strike(a: Dictionary, to: Vector3, dist: float) -> void:
	if phase == 3 and randf() < 0.35:
		# misses from sleepiness: the blade goes wide
		_yaw += randf_range(0.8, 1.2) * (1.0 if randf() < 0.5 else -1.0)
		Fx.text(self, global_position + Vector3(0, target_height + 0.3, 0), "...", Color(0.8, 0.8, 0.9), 64)
	super._strike(a, to, dist)


func _after_strike(_a: Dictionary) -> void:
	if phase >= 2:
		var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
		var z := FireZone.new()
		z.boss = self
		get_parent().add_child(z)
		z.global_position = global_position + fwd * reach * 0.8 + Vector3(0, 0.03, 0)


func _fall_asleep() -> void:
	dead = true
	engaging = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	_set_state("sleep")
	_play("Fixing_Kneeling", 0.3, 0.4)
	if _shard != null:
		var tw: Tween = _shard.create_tween()
		tw.tween_property(_shard, "light_energy", 0.4, 3.0)
	_say("sleep")
	_zzz_t = 2.6
	fell_asleep.emit()
	died.emit(self)


func _dead_update(dt: float) -> void:
	velocity = Vector3(0, -1.0 if is_on_floor() else velocity.y - GRAVITY * dt, 0)
	move_and_slide()
	t += dt
	if t > 2.4 and t - dt <= 2.4:
		_play("death", 0.6)  # lies down on the crypt floor
	_zzz_t -= dt
	if _zzz_t <= 0.0:
		_zzz_t = 2.5
		Fx.text(self, global_position + Vector3(0, 0.9, 0), "Zzz", Color(0.75, 0.85, 1.0), 70, 1.0, 2.2)


# Embers left by his strikes in phase 2+: burns the hero standing in it.
class FireZone extends Node3D:
	const RADIUS: float = 1.1
	var boss: Node = null
	var life: float = 5.0
	var _tick: float = 0.3
	var _mat: StandardMaterial3D

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(RADIUS * 2.2, RADIUS * 2.2)
		q.orientation = PlaneMesh.FACE_Y
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.albedo_texture = Fx.glow_texture()
		_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.9)
		q.material = _mat
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		Fx.embers(self, global_position + Vector3(0, 0.2, 0), 16)

	func _physics_process(dt: float) -> void:
		life -= dt
		_tick -= dt
		_mat.albedo_color.a = clampf(life, 0.0, 1.0) * (0.75 + 0.2 * sin(life * 9.0))
		if _tick <= 0.0:
			_tick = 0.5
			Fx.burst(self, global_position + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6)), Color(1.0, 0.6, 0.2), 4, 1.5, 0.6, 0.08, -2.0, true, 30.0)
			var h: Node3D = get_tree().get_first_node_in_group("hero") as Node3D
			if h != null and boss != null and is_instance_valid(boss):
				var d: Vector3 = h.global_position - global_position
				if Vector2(d.x, d.z).length() < RADIUS and absf(d.y) < 1.0:
					Fx.deal(boss, h, 4.0, "fire")
		if life <= 0.0:
			queue_free()
