# PROTOTYPE - NOT FOR PRODUCTION
# Loot: what a defeated enemy's chest holds. Rarity is rolled first (rare tiers are much less likely but much
# stronger), then an item of that rarity from Items.DEFS, plus gold scaled by the enemy's level.
class_name Loot
extends RefCounted

const RARITIES: Array[String] = ["comum", "incomum", "raro", "epico", "lendario"]
# base weights (percent): rarer tiers are uncommon on purpose
const WEIGHT: Dictionary = {"comum": 62.0, "incomum": 26.0, "raro": 9.0, "epico": 2.5, "lendario": 0.5}
const NAME: Dictionary = {"comum": "Comum", "incomum": "Incomum", "raro": "Raro", "epico": "Épico", "lendario": "Lendário"}
const COLOR: Dictionary = {"comum": Color(0.78, 0.78, 0.74), "incomum": Color(0.4, 0.85, 0.35), "raro": Color(0.35, 0.6, 1.0),
	"epico": Color(0.75, 0.4, 1.0), "lendario": Color(1.0, 0.75, 0.2)}
const DROP_CHANCE: float = 0.3  # chance an ordinary enemy leaves a chest


static func pool(rarity: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in Items.DEFS:
		if str((Items.DEFS[id] as Dictionary).get("rarity", "")) == rarity:
			out.append(id)
	return out


# higher-level enemies are a little luckier: the three rare tiers grow 4% per level
static func roll_rarity(level: int, rng: RandomNumberGenerator, min_rarity: String = "comum") -> String:
	var start: int = RARITIES.find(min_rarity)
	var total: float = 0.0
	var w: Array[float] = []
	for i in RARITIES.size():
		var r: String = RARITIES[i]
		var v: float = 0.0 if i < start else float(WEIGHT[r]) * (1.0 + 0.04 * level if i >= 2 else 1.0)
		w.append(v)
		total += v
	var x: float = rng.randf() * total
	for i in RARITIES.size():
		x -= w[i]
		if x <= 0.0 and w[i] > 0.0:
			return RARITIES[i]
	return RARITIES[RARITIES.size() - 1]


# {item: id, rarity, gold}
static func roll(level: int, rng: RandomNumberGenerator, boss: bool = false, min_rarity: String = "") -> Dictionary:
	var rarity: String = roll_rarity(level, rng, min_rarity if min_rarity != "" else ("raro" if boss else "comum"))
	var p: Array[String] = pool(rarity)
	var item: String = p[rng.randi_range(0, p.size() - 1)] if not p.is_empty() else ""
	var gold: int = rng.randi_range(3 * level, 6 * level) + (50 if boss else 0)
	return {"item": item, "rarity": rarity, "gold": gold}
