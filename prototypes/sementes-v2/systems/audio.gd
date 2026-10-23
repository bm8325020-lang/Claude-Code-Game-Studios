# PROTOTYPE - NOT FOR PRODUCTION
# Music, area ambience and small feedback cues (owner: audio agent).
#   var audio := GameAudio.new(); add_child(audio); audio.bind(prog, quests)
#   audio.update(zone_id, GameAudio.mood(actors, hero_pos, boss))   a few times a second; cheap when nothing changes
#   audio.cue("tap" | "pickup" | "chest" | "quest" | "level")
# Music: the four CC0 tracks in assets/music (town, forest, dungeon, boss), crossfaded; "fight" swaps to the dungeon
# theme and holds it a few seconds after the last enemy calms down, "boss" plays while the Conde fights.
# Ambience: no recorded beds exist in the repo, so each area type gets a 12 s loop synthesised once (filtered noise
# for wind/water/murmur, sine chirps for birds, drips with echoes) on a worker thread, 8 kHz mono, then cached.
# Buses (default_bus_layout.tres): Music, SFX, Ambience (sends to SFX, so the "Efeitos" slider covers it).
# Every node here runs while paused, so the menu does not cut the music.
class_name GameAudio
extends Node

const RATE: int = 8000
const FADE_S: float = 2.5
const FIGHT_HOLD: float = 6.0
const MUSIC_VOL: float = 0.5   # linear; the Options slider scales the Music bus on top
const AMB_VOL: float = 0.45
const CALM: Array[String] = ["patrol", "idle", "return", "sleep", "guard", "dead"]

# zone id -> ambience bed / exploration track; anything else (roads, fields) gets "meadow" / "forest"
const AREA_BED: Dictionary = {"village": "village", "farm": "village", "forest": "forest", "bandit_camp": "forest",
	"watchtower": "meadow", "river": "water", "lake": "water", "mine": "mine", "mina_fundo": "mine", "castle": "castle"}
const AREA_MUSIC: Dictionary = {"village": "town", "farm": "town", "mine": "dungeon", "mina_fundo": "dungeon",
	"castle": "dungeon"}
const BEDS: Dictionary = {
	"village": {"wind": 0.08, "birds": 6, "chatter": 0.35},
	"meadow": {"wind": 0.16, "birds": 4},
	"forest": {"wind": 0.2, "birds": 11},
	"water": {"water": 0.22, "wind": 0.05, "birds": 2},
	"mine": {"rumble": 0.25, "drips": 8},
	"castle": {"wind": 0.32},
}
# cue -> [[sfx name, dB, pitch], ...] (all from assets/sfx)
const CUES: Dictionary = {
	"tap": [["impactWood_medium_002", -20.0, 1.8]],
	"pickup": [["impactGlass_heavy_001", -14.0, 2.0], ["cloth1", -10.0, 1.2]],
	"chest": [["impactWood_heavy_000", -8.0, 0.9], ["impactGlass_heavy_002", -14.0, 1.6]],
	"quest": [["jingle_win", -5.0, 1.0]],
	"level": [["jingle_win", -5.0, 1.25]],
}

var music: Array[AudioStreamPlayer] = []
var amb: Array[AudioStreamPlayer] = []
var music_key: String = ""
var amb_key: String = ""
var _music_i: int = 0
var _amb_i: int = 0
var _want_amb: String = ""
var _hold: float = 0.0
var _tracks: Dictionary = {}
var _beds: Dictionary = {}
var _jobs: Dictionary = {}  # bed kind -> [task id, [result]]
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_i: int = 0
var _sfx: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		music.append(_player("Music"))
		amb.append(_player("Ambience"))
	for i in 3:
		_cue_players.append(_player("SFX"))
	# every menu/dialog button gets a soft tap; the touch pad is not a BaseButton, so attacks stay quiet
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			(n as BaseButton).pressed.connect(cue.bind("tap")))


func _exit_tree() -> void:
	for k: String in _jobs:
		WorkerThreadPool.wait_for_task_completion(int(_jobs[k][0]))
	_jobs.clear()


func bind(prog: Object, quests: Object) -> void:
	prog.connect("leveled_up", func(_l: int) -> void: cue("level"))
	quests.connect("quest_done", func(_id: String, _r: Dictionary) -> void: cue("quest"))


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	p.volume_db = -80.0
	add_child(p)
	return p


# "boss" while the Conde is fighting near, "fight" while any enemy near is, else "calm"
static func mood(actors: Array, at: Vector3, boss: Node3D) -> String:
	if is_instance_valid(boss) and not bool(boss.get("dead")) and String(boss.get("state")) not in CALM \
			and boss.global_position.distance_to(at) < 45.0:
		return "boss"
	for a: Variant in actors:
		if a is Enemy and is_instance_valid(a) and not (a as Enemy).dead and (a as Enemy).state not in CALM \
				and (a as Enemy).global_position.distance_to(at) < 25.0:
			return "fight"
	return "calm"


func update(zone: String, m: String) -> void:
	_want_amb = str(AREA_BED.get(zone, "meadow"))
	if m != "calm":
		_hold = FIGHT_HOLD
	var track: String = str(AREA_MUSIC.get(zone, "forest"))
	if m == "boss":
		track = "boss"
	elif _hold > 0.0:
		track = "dungeon"
	if track != music_key:
		music_key = track
		_music_i = 1 - _music_i
		_start(music[_music_i], _track(track))


func _process(dt: float) -> void:
	_hold = maxf(_hold - dt, 0.0)
	if _want_amb != amb_key:
		var s: AudioStreamWAV = _bed(_want_amb)
		if s != null:
			amb_key = _want_amb
			_amb_i = 1 - _amb_i
			_start(amb[_amb_i], s)
	_fade(music, _music_i, MUSIC_VOL, dt)
	_fade(amb, _amb_i, AMB_VOL, dt)


func _start(p: AudioStreamPlayer, s: AudioStream) -> void:
	p.stream = s
	if s != null:
		p.play()


# the current player rises to vol, the other one sinks and stops: a linear crossfade over FADE_S
func _fade(pair: Array[AudioStreamPlayer], cur: int, vol: float, dt: float) -> void:
	for i in 2:
		var p: AudioStreamPlayer = pair[i]
		if not p.playing:
			continue
		var lin: float = move_toward(db_to_linear(p.volume_db), vol if i == cur else 0.0, dt * vol / FADE_S)
		p.volume_db = linear_to_db(maxf(lin, 0.0001))
		if i != cur and lin <= 0.0001:
			p.stop()


func _track(t: String) -> AudioStream:
	if not _tracks.has(t):
		var path: String = "res://assets/music/%s.ogg" % t
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_tracks[t] = s
	return _tracks[t]


# null until the worker thread has made it (first visit only; ~0.7 s on a desktop core, so the bed fades in late)
func _bed(kind: String) -> AudioStreamWAV:
	if _beds.has(kind):
		return _beds[kind]
	if not _jobs.has(kind):
		var box: Array = [null]  # the thread writes only here; read after it finishes
		_jobs[kind] = [WorkerThreadPool.add_task(func() -> void: box[0] = bed(kind)), box]
	var j: Array = _jobs[kind]
	if not WorkerThreadPool.is_task_completed(int(j[0])):
		return null
	WorkerThreadPool.wait_for_task_completion(int(j[0]))
	_jobs.erase(kind)
	_beds[kind] = (j[1] as Array)[0]
	return _beds[kind]


func cue(name: String) -> void:
	for c: Array in CUES.get(name, []):
		var nm: String = str(c[0])
		if not _sfx.has(nm):
			var path: String = Fx.SFX_DIR % nm
			_sfx[nm] = load(path) if ResourceLoader.exists(path) else null
		if _sfx[nm] == null:
			continue
		var p: AudioStreamPlayer = _cue_players[_cue_i]
		_cue_i = (_cue_i + 1) % _cue_players.size()
		p.stream = _sfx[nm]
		p.volume_db = float(c[1])
		p.pitch_scale = float(c[2]) * randf_range(0.97, 1.03)
		p.play()


# ---- ambience synthesis (pure function of kind; runs on a worker thread) ----
static func bed(kind: String, secs: float = 12.0) -> AudioStreamWAV:
	var p: Dictionary = BEDS.get(kind, BEDS.meadow)
	var n: int = int(secs * RATE)
	var fade: int = RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	if p.has("wind"):
		_noise(buf, rng, float(p.wind), 0.03, 0.0, 3, 0.6, n)
	if p.has("rumble"):
		_noise(buf, rng, float(p.rumble), 0.008, 0.0, 2, 0.3, n)
	if p.has("water"):
		_noise(buf, rng, float(p.water), 0.4, 0.06, 7, 0.3, n)
	if p.has("chatter"):
		_chatter(buf, rng, float(p.chatter))
	# loop seam: the extra second fades into the head, so the wrap continues the same noise without a click
	var out := buf.slice(0, n)
	for i in fade:
		var k: float = float(i) / fade
		out[i] = buf[i] * k + buf[n + i] * (1.0 - k)
	for g in int(p.get("birds", 0)):
		_chirps(out, rng)
	for d in int(p.get("drips", 0)):
		_drip(out, rng)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(out[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	w.data = data
	return w


# low-passed white noise (a: one-pole coefficient), optional high-pass (b) to take the rumble out of water;
# swells `cycles` whole times per loop so the modulation wraps cleanly too
static func _noise(buf: PackedFloat32Array, rng: RandomNumberGenerator, amp: float, a: float, b: float, cycles: int,
		depth: float, n: int) -> void:
	var y: float = 0.0
	var z: float = 0.0
	var norm: float = 1.0 / sqrt(a / (2.0 - a))
	for i in buf.size():
		y += a * (rng.randf() * 2.0 - 1.0 - y)
		var v: float = y * norm
		if b > 0.0:
			z += b * (v - z)
			v -= z
		buf[i] += v * amp * (1.0 - depth * (0.5 + 0.5 * sin(TAU * cycles * float(i) / n)))


# distant murmur: band-passed noise gated by random syllable-length swells
static func _chatter(buf: PackedFloat32Array, rng: RandomNumberGenerator, amp: float) -> void:
	var y: float = 0.0
	var z: float = 0.0
	var env: float = 0.0
	var target: float = 0.0
	var next: int = 0
	for i in buf.size():
		if i >= next:
			next = i + int(RATE * rng.randf_range(0.09, 0.22))
			target = rng.randf() if rng.randf() < 0.7 else 0.0
		env += 0.004 * (target - env)
		y += 0.4 * (rng.randf() * 2.0 - 1.0 - y)
		z += 0.1 * (y - z)
		buf[i] += (y - z) * env * amp


static func _chirps(out: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var n: int = out.size()
	var t0: int = rng.randi_range(0, n - 1)
	var f0: float = rng.randf_range(2000.0, 3000.0)
	var gain: float = rng.randf_range(0.03, 0.09)
	for k in rng.randi_range(2, 5):
		var len: int = int(RATE * rng.randf_range(0.05, 0.11))
		var start: int = t0 + k * int(RATE * 0.13)
		var up: float = rng.randf_range(-500.0, 800.0)
		var ph: float = 0.0
		for i in len:
			var u: float = float(i) / len
			ph += TAU * (f0 + up * u) / RATE
			out[(start + i) % n] += sin(ph) * sin(PI * u) * gain


static func _drip(out: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var n: int = out.size()
	var t0: int = rng.randi_range(0, n - 1)
	var f: float = rng.randf_range(700.0, 1300.0)
	var len: int = int(RATE * 0.06)
	for e in 3:  # the drop and two echoes off the tunnel walls
		var g: float = 0.18 * pow(0.35, e)
		var start: int = t0 + e * int(RATE * 0.21)
		var ph: float = 0.0
		for i in len:
			var u: float = float(i) / len
			ph += TAU * f * (1.0 + 0.6 * u) / RATE
			out[(start + i) % n] += sin(ph) * exp(-6.0 * u) * g
