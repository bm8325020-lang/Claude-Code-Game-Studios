# PROTOTYPE - NOT FOR PRODUCTION
# Progression: level, XP curve, attributes and the stats they give, unlocks (skills, rest points, castle access),
# gold, the Dragon Seeds collected and the last Marco de Lume touched. Pure data (RefCounted), tested headless.
#
# Combat reads stats() (max_hp, max_stamina, dmg_mult, skill_mult, armor_mult) and has_unlock("bloqueio") etc.
# Kill rewards (xp, gold) per enemy kind are in KILL_REWARD; Quests.notify("kill", kind) grants them.
class_name Progression
extends RefCounted

signal leveled_up(level: int)
signal xp_changed(xp: int, need: int)
signal gold_changed(gold: int)
signal unlocked(id: String)
signal seed_added(id: String, total: int)

const MAX_LEVEL: int = 30
const SEEDS_TOTAL: int = 12
const POINTS_PER_LEVEL: int = 1

# vigor: life, folego: stamina, forca: weapon damage, fe: skills and healing at the Marcos
const ATTRS: Array[String] = ["vigor", "folego", "forca", "fe"]
const ATTR_NAME: Dictionary = {"vigor": "Vigor", "folego": "Fôlego", "forca": "Força", "fe": "Fé"}
const ATTR_DESC: Dictionary = {"vigor": "+vida máxima", "folego": "+estamina máxima", "forca": "+dano das armas",
	"fe": "+força das habilidades e da cura"}

# every unlock id the game checks; name/desc in pt-BR for the reward popup
const UNLOCKS: Dictionary = {
	"descanso": {"name": "Marcos de Lume", "desc": "Descanse nos Marcos: a vida volta e os frascos enchem."},
	"bloqueio": {"name": "Bloqueio", "desc": "Segure o escudo para parar golpes."},
	"aparar": {"name": "Aparar", "desc": "Bloqueie no último instante para desequilibrar o inimigo."},
	"sopro_brasa": {"name": "Sopro de Brasa", "desc": "Habilidade: um sopro de fagulhas à frente."},
	"calor_lar": {"name": "Calor de Lar", "desc": "Habilidade: cura lenta em volta de você."},
	"mapa_covas": {"name": "Mapa das Covas", "desc": "O mapa do vale mostra as covas e os Marcos."},
	"paz_sem_terra": {"name": "Paz com os Sem-Terra", "desc": "Os Sem-Terra deixam de atacar na estrada."},
	"loja_sem_terra": {"name": "Feira dos Sem-Terra", "desc": "Os Sem-Terra vendem no acampamento."},
	"tunel_castelo": {"name": "Túnel do Castelo", "desc": "O túnel velho da mina sobe até a cripta."},
	"senha_portao": {"name": "Senha do Portão", "desc": "Frei Anselmo contou a senha do portão interno."},
	"castelo": {"name": "Castelo de Vigília", "desc": "O caminho para o castelo está aberto."},
	"desconto_bene": {"name": "Freguês do Seu Bené", "desc": "20% de desconto na carroça do Bené."},
	"bencao_repouso": {"name": "Bênção do Repouso", "desc": "Mais um frasco em cada Marco."},
	"fim": {"name": "A Festa da Semeadura", "desc": "O vale dorme em paz."},
}
const SKILLS: Dictionary = {
	"sopro_brasa": {"name": "Sopro de Brasa", "power": 30.0, "cost": 30.0, "cooldown": 6.0},
	"calor_lar": {"name": "Calor de Lar", "power": 8.0, "cost": 40.0, "cooldown": 20.0},
}

# enemy kind -> [xp, gold]
const KILL_REWARD: Dictionary = {
	"wolf_imp": [8, 1], "bandit": [14, 3], "bandit_archer": [16, 3], "puglin": [18, 2],
	"possessed": [15, 0], "knight": [35, 8], "boss": [300, 100],
}

var level: int = 1
var xp: int = 0           # xp inside the current level
var points: int = 0       # attribute points not spent yet
var attrs: Dictionary = {"vigor": 1, "folego": 1, "forca": 1, "fe": 1}
var gold: int = 0
var unlocks: Dictionary = {}    # id -> true
var seeds: Array[String] = []   # seed ids in the order found (4 found + 8 from the reliquary = 12)
var last_marco: String = ""     # interactable id of the last Marco de Lume rested at ("" = the inn bed)
var kills: Dictionary = {}      # kind -> count


# XP needed to go from level l to l + 1: 60, 100, 140 ... (about level 12-14 at the boss with normal play)
static func xp_to_next(l: int) -> int:
	return 60 + 40 * (l - 1)


static func kill_xp(kind: String) -> int:
	var r: Array = KILL_REWARD.get(kind, [0, 0]) as Array
	return int(r[0])


static func kill_gold(kind: String) -> int:
	var r: Array = KILL_REWARD.get(kind, [0, 0]) as Array
	return int(r[1])


func gain_xp(n: int) -> void:
	if n <= 0:
		return
	xp += n
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		points += POINTS_PER_LEVEL
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
	xp_changed.emit(xp, xp_to_next(level))


func spend_point(attr: String) -> bool:
	if points <= 0 or not attrs.has(attr):
		return false
	points -= 1
	attrs[attr] = int(attrs[attr]) + 1
	return true


func add_gold(n: int) -> void:
	gold = maxi(0, gold + n)
	gold_changed.emit(gold)


func spend_gold(n: int) -> bool:
	if n > gold:
		return false
	add_gold(-n)
	return true


func unlock(id: String) -> void:
	if unlocks.has(id):
		return
	unlocks[id] = true
	unlocked.emit(id)


func has_unlock(id: String) -> bool:
	return unlocks.has(id)


func skills() -> Array[String]:
	var out: Array[String] = []
	for id: String in SKILLS:
		if has_unlock(id):
			out.append(id)
	return out


func add_seed(id: String) -> void:
	if id in seeds:
		return
	seeds.append(id)
	seed_added.emit(id, seeds.size())


func add_kill(kind: String) -> void:
	kills[kind] = int(kills.get(kind, 0)) + 1
	gain_xp(kill_xp(kind))
	add_gold(kill_gold(kind))


# derived numbers combat and HUD read; armor comes from Items.armor()
func stats(armor: int = 0) -> Dictionary:
	var vig: int = int(attrs.vigor)
	var fol: int = int(attrs.folego)
	var forc: int = int(attrs.forca)
	var fe: int = int(attrs.fe)
	return {
		"max_hp": 100.0 + 12.0 * (vig - 1) + 10.0 * (level - 1),  # levels alone keep you alive, points are a bonus
		"max_stamina": 80.0 + 6.0 * (fol - 1),
		"dmg_mult": 1.0 + 0.06 * (forc - 1),
		"skill_mult": 1.0 + 0.08 * (fe - 1),
		"heal_mult": 1.0 + 0.04 * (fe - 1),
		"armor_mult": 100.0 / (100.0 + 4.0 * armor),   # damage taken multiplier
	}


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "points": points, "attrs": attrs.duplicate(), "gold": gold,
		"unlocks": unlocks.keys(), "seeds": seeds.duplicate(), "last_marco": last_marco, "kills": kills.duplicate()}


func from_dict(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = int(d.get("xp", 0))
	points = int(d.get("points", 0))
	var a: Dictionary = d.get("attrs", {}) as Dictionary
	for k: String in ATTRS:
		attrs[k] = int(a.get(k, 1))
	gold = int(d.get("gold", 0))
	unlocks = {}
	for id: Variant in d.get("unlocks", []) as Array:
		unlocks[str(id)] = true
	seeds = []
	for id: Variant in d.get("seeds", []) as Array:
		seeds.append(str(id))
	last_marco = str(d.get("last_marco", ""))
	kills = {}
	var k2: Dictionary = d.get("kills", {}) as Dictionary
	for kind: String in k2:
		kills[kind] = int(k2[kind])
