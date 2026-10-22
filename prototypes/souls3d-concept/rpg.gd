# PROTOTYPE - NOT FOR PRODUCTION
# RPG rules: starting classes, attributes and the stats they give, the talent tree, elements and weaknesses,
# weapon reinforcement and the quest log. Pure data and formulas, so tests/rpg_test.gd can check them headless.
extends RefCounted

const ATTRS := ["vig", "fol", "for", "des", "int"]
const ATTR_NAME := {"vig": "Vigor", "fol": "Fôlego", "for": "Força", "des": "Destreza", "int": "Inteligência"}
const ATTR_DESC := {"vig": "+vida máxima", "fol": "+estamina máxima", "for": "+dano, sobretudo do espadão",
	"des": "+dano da espada, golpes gastam menos estamina", "int": "+dano e essência das Sementes"}

const CLASSES := {
	"cavaleiro": {"name": "Cavaleiro", "desc": "Espada e escudo. Muita vida e força.",
		"attrs": {"vig": 14, "fol": 12, "for": 14, "des": 10, "int": 8}, "flasks": 3},
	"andarilho": {"name": "Andarilho", "desc": "Rápido e ágil. Golpes e rolamentos baratos.",
		"attrs": {"vig": 11, "fol": 15, "for": 9, "des": 15, "int": 8}, "flasks": 3},
	"piromante": {"name": "Piromante", "desc": "Domina as Sementes. Fogo forte, muita essência.",
		"attrs": {"vig": 10, "fol": 10, "for": 9, "des": 11, "int": 18}, "flasks": 2},
}

# three branches of four; a talent needs the one before it in its branch
const TALENTS := {
	"guerreiro": [
		{"id": "lamina", "name": "Lâmina Afiada", "desc": "+10% dano corpo a corpo"},
		{"id": "sangue", "name": "Sede de Sangue", "desc": "Golpes acumulam sangramento: ao encher, 12% da vida do inimigo"},
		{"id": "ferro", "name": "Pele de Ferro", "desc": "-15% dano recebido"},
		{"id": "furia", "name": "Fúria", "desc": "Cada 4 golpes encadeados: +10% dano (até +40%)"},
	],
	"sombra": [
		{"id": "leve", "name": "Passo Leve", "desc": "Rolar gasta 30% menos estamina"},
		{"id": "critico", "name": "Golpe Cruel", "desc": "Críticos (contra-ataques) +50% dano"},
		{"id": "esquiva", "name": "Esquiva Perfeita", "desc": "Rolar através de um ataque: +25 estamina e +30% dano por 3 s"},
		{"id": "vampiro", "name": "Vampirismo", "desc": "Cada inimigo morto cura 8% da vida"},
	],
	"chama": [
		{"id": "brasa", "name": "Brasa Interior", "desc": "+15% dano das Sementes"},
		{"id": "essencia", "name": "Essência Viva", "desc": "Essência se regenera sozinha"},
		{"id": "frasco", "name": "Frasco Abençoado", "desc": "Frascos curam 40% mais"},
		{"id": "dragao", "name": "Coração do Dragão", "desc": "Sementes custam 25% menos"},
	],
}
const BRANCH_NAME := {"guerreiro": "GUERREIRO", "sombra": "SOMBRA", "chama": "CHAMA"}

# every enemy: its name, which AI it uses (warrior, minion, caster, rogue, archer, sentinel, wolf), model and weapons
# (assets/foes, tools/make_foes.py), scale, health, poise, embers, melee damage, walking speed; poison: its hits poison
const FOES := {
	"minion": {"name": "Esquecido", "ai": "minion", "model": "Hollow", "gear": [["handslot.r", "sword"]], "scale": 0.95, "hp": 55.0, "poise": 22.0, "reward": 35, "dmg": 20.0, "speed": 3.9},
	"warrior": {"name": "Cavaleiro Oco", "ai": "warrior", "model": "Knight", "gear": [["handslot.r", "sword"]], "scale": 1.05, "hp": 90.0, "poise": 40.0, "reward": 60, "dmg": 30.0, "speed": 3.0},
	"caster": {"name": "Clérigo da Cinza", "ai": "caster", "model": "Cultist", "gear": [["handslot.r", "staff"]], "scale": 0.95, "hp": 45.0, "poise": 15.0, "reward": 50, "dmg": 20.0, "speed": 3.0},
	"rogue": {"name": "Espreitador", "ai": "rogue", "model": "Stalker", "gear": [["handslot.r", "dagger"], ["handslot.l", "dagger"]], "scale": 0.95, "hp": 60.0, "poise": 25.0, "reward": 45, "dmg": 16.0, "speed": 4.4, "poison": 0.4},
	"archer": {"name": "Besteiro Espreitador", "ai": "archer", "model": "Stalker", "gear": [["handslot.l", "crossbow"]], "scale": 0.95, "hp": 50.0, "poise": 18.0, "reward": 45, "dmg": 18.0, "speed": 3.0},
	"sentinel": {"name": "Sentinela de Pedra", "ai": "sentinel", "model": "Sentinel", "gear": [["handslot.r", "greatsword"]], "scale": 1.6, "hp": 380.0, "poise": 90.0, "reward": 300, "dmg": 40.0, "speed": 2.4},
	"wolf": {"name": "Lobo da Cinza", "ai": "wolf", "model": "", "gear": [], "scale": 1.0, "hp": 70.0, "poise": 30.0, "reward": 40, "dmg": 18.0, "speed": 5.0},
	# the walled cities of the wide world
	"guard": {"name": "Guarda da Muralha", "ai": "warrior", "model": "Guard", "gear": [["handslot.r", "halberd"]], "scale": 1.05, "hp": 110.0, "poise": 45.0, "reward": 70, "dmg": 32.0, "speed": 3.0},
	"wallbow": {"name": "Besteiro da Muralha", "ai": "archer", "model": "Guard", "gear": [["handslot.l", "crossbow"]], "scale": 1.05, "hp": 70.0, "poise": 25.0, "reward": 60, "dmg": 22.0, "speed": 3.0},
	"executioner": {"name": "Carrasco", "ai": "sentinel", "model": "Executioner", "gear": [["handslot.r", "greataxe"]], "scale": 1.35, "hp": 260.0, "poise": 80.0, "reward": 220, "dmg": 48.0, "speed": 2.9},
	"sorceress": {"name": "Feiticeira da Torre", "ai": "caster", "model": "Sorceress", "gear": [["handslot.r", "staff"]], "scale": 1.0, "hp": 70.0, "poise": 18.0, "reward": 90, "dmg": 24.0, "speed": 3.0},
	"plague": {"name": "Andarilho da Peste", "ai": "rogue", "model": "Plague", "gear": [["handslot.r", "cleaver"]], "scale": 1.0, "hp": 80.0, "poise": 28.0, "reward": 75, "dmg": 18.0, "speed": 4.0, "poison": 1.0},
	# Quaternius models (rig "q": qrig.gd, Universal Animation Library clips)
	"bandit": {"name": "Salteador", "ai": "rogue", "rig": "q", "model": "Male_Ranger.gltf", "head": "Male", "gear": [["hand_r", "sword"]], "scale": 1.0, "hp": 85.0, "poise": 30.0, "reward": 70, "dmg": 22.0, "speed": 4.2},
	"knifethrower": {"name": "Atiradora de Facas", "ai": "archer", "rig": "q", "model": "Female_Ranger.gltf", "head": "Female", "gear": [["hand_r", "dagger"]], "scale": 1.0, "hp": 60.0, "poise": 20.0, "reward": 65, "dmg": 20.0, "speed": 3.6},
	"possessed": {"name": "Aldeão Possuído", "ai": "minion", "rig": "q", "shamble": true, "model": "Male_Peasant.gltf", "head": "Male", "hair": "Hair_Beard", "gear": [], "scale": 1.0, "hp": 60.0, "poise": 20.0, "reward": 40, "dmg": 18.0, "speed": 2.6},
	"possessed_f": {"name": "Aldeã Possuída", "ai": "minion", "rig": "q", "shamble": true, "model": "Female_Peasant.gltf", "head": "Female", "hair": "Hair_Long", "gear": [], "scale": 1.0, "hp": 55.0, "poise": 18.0, "reward": 40, "dmg": 16.0, "speed": 2.8},
	"imp": {"name": "Diabrete", "ai": "minion", "rig": "q", "model": "Imp.glb", "gear": [], "scale": 1.0, "hp": 50.0, "poise": 15.0, "reward": 50, "dmg": 18.0, "speed": 4.6},
	"puglin": {"name": "Puglin Saqueador", "ai": "warrior", "rig": "q", "model": "Puglin.glb", "gear": [["hand_r", "cleaver"]], "scale": 1.0, "hp": 95.0, "poise": 35.0, "reward": 75, "dmg": 26.0, "speed": 3.4},
	"blackknight": {"name": "Cavaleiro Negro", "ai": "warrior", "model": "BlackKnight", "gear": [["handslot.r", "sword"], ["handslot.l", "shield"]], "scale": 1.3, "hp": 520.0, "poise": 110.0, "reward": 800, "dmg": 45.0, "speed": 3.2},
}

# damage taken by kind, per element (1 = normal); missing means 1
const WEAK := {
	"minion": {"fogo": 1.5},
	"warrior": {"raio": 1.5, "fogo": 0.8},
	"caster": {"fogo": 1.4, "gelo": 0.5},
	"rogue": {"gelo": 1.4},
	"archer": {"gelo": 1.4},
	"sentinel": {"raio": 1.6, "fogo": 0.5, "fis": 0.8},
	"wolf": {"fogo": 1.5},
	"guard": {"raio": 1.4},
	"wallbow": {"raio": 1.3},
	"executioner": {"gelo": 1.4, "fis": 0.85},
	"sorceress": {"fis": 1.3, "raio": 0.6},
	"plague": {"fogo": 1.6, "gelo": 0.7},
	"blackknight": {"raio": 1.3, "fogo": 0.7, "fis": 0.85},
	"bandit": {"gelo": 1.3},
	"knifethrower": {"gelo": 1.3},
	"possessed": {"fogo": 1.6},
	"possessed_f": {"fogo": 1.6},
	"imp": {"gelo": 1.6, "fogo": 0.3},
	"puglin": {"raio": 1.4},
}
const MAX_UPGRADE := 5

static func class_attrs(cls: String) -> Dictionary:
	return CLASSES[cls].attrs.duplicate()

# every stat the game reads, from attributes, talents (id -> true) and the weapon's reinforcement level
static func derive(a: Dictionary, talents: Dictionary) -> Dictionary:
	var vig: int = a.vig
	return {
		"max_hp": 100.0 + 5.0 * mini(vig, 30) + 2.0 * maxi(vig - 30, 0),
		"max_stamina": 60.0 + 4.0 * a.fol,
		"max_essence": 100.0 + 5.0 * (a.int - 10),
		"sword_mult": (1.0 + 0.03 * (a.for - 10) + 0.03 * (a.des - 10)) * (1.1 if talents.has("lamina") else 1.0),
		"great_mult": (1.0 + 0.05 * (a.for - 10) + 0.01 * (a.des - 10)) * (1.1 if talents.has("lamina") else 1.0),
		"seed_mult": (1.0 + 0.05 * (a.int - 10)) * (1.15 if talents.has("brasa") else 1.0),
		"stamina_cost": maxf(0.7, 1.0 - 0.015 * (a.des - 10)),
		"roll_cost": 0.7 if talents.has("leve") else 1.0,
		"crit_mult": 1.5 if talents.has("critico") else 1.0,
		"taken_mult": 0.85 if talents.has("ferro") else 1.0,
		"flask_mult": 1.4 if talents.has("frasco") else 1.0,
		"seed_cost": 0.75 if talents.has("dragao") else 1.0,
	}

static func level_cost(level: int) -> int:
	return 100 + 50 * level

static func weakness(kind: String, element: String) -> float:
	return WEAK.get(kind, {}).get(element, 1.0)

static func upgrade_mult(lvl: int) -> float:
	return 1.0 + 0.1 * lvl

# [titanite, embers] to go from lvl to lvl + 1
static func upgrade_cost(lvl: int) -> Array:
	return [lvl + 1, 200 * (lvl + 1)]

static func talent_points(level: int, bells: int, bosses: int) -> int:
	return level / 2 + bells + bosses

static func can_learn(id: String, talents: Dictionary) -> bool:
	if talents.has(id):
		return false
	for b in TALENTS:
		var list: Array = TALENTS[b]
		for i in list.size():
			if list[i].id == id:
				return i == 0 or talents.has(list[i - 1].id)
	return false

# the quest log: [title, done]; main quests in order, then side quests with progress
static func quests(s: Dictionary) -> Dictionary:
	var main := [
		["Acenda a fogueira do Burgo dos Esquecidos", s.lit.has("Burgo dos Esquecidos")],
		["Atravesse os Telhados Quebrados até a Igreja", s.lit.has("Igreja do Juramento")],
		["Derrote as Sentinelas de Pedra", s.sentinels_dead],
		["Toque o 1º Sino do Despertar", s.bells >= 1],
		["Abra o atalho do elevador", s.elevator_open],
	]
	var side := [
		["Fragmentos de Seiva (%d/2)" % s.shards_found, s.shards_found >= 2],
		["Reforce uma arma até +3", s.best_upgrade >= 3],
		["Aprenda 3 talentos", s.talents >= 3],
		["Derrote 50 inimigos (%d/50)" % mini(s.kills, 50), s.kills >= 50],
	]
	return {"main": main, "side": side}

static func current_objective(s: Dictionary) -> String:
	for q in quests(s).main:
		if not q[1]:
			return q[0]
	return "Siga para a Ponte do Dragão (em breve)"
