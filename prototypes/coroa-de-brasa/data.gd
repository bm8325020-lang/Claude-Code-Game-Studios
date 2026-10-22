# PROTOTYPE - NOT FOR PRODUCTION
# Every number of the game in one place: heroes, their moves and skills, enemies, bosses, run blessings,
# village upgrades and the floors of the dungeon.
extends RefCounted

# ------------------------------------------------------------------ heroes
# attack: the basic combo, one entry per hit: anim, dmg, hit (fraction of the clip when it lands), speed,
# range, arc (radians), lunge (m/s while swinging), shot (a projectile instead of a swing)
# skills: [id, name, cooldown seconds]; the code for each id is in hero.gd
const HEROES := {
	"knight": {"name": "Cavaleiro", "model": "Knight", "desc": "Espada e escudo. Resistente, empurra e protege.",
		"hp": 160, "speed": 6.0, "right": "sword_1handed", "left": "shield_round", "unlock": 0,
		"attack": [
			{"anim": "Melee_1H_Attack_Chop", "dmg": 22, "hit": 0.42, "speed": 1.5, "range": 2.4, "arc": 1.3, "lunge": 3.0},
			{"anim": "Melee_1H_Attack_Slice_Diagonal", "dmg": 24, "hit": 0.4, "speed": 1.5, "range": 2.4, "arc": 1.5, "lunge": 3.0},
			{"anim": "Melee_1H_Attack_Stab", "dmg": 38, "hit": 0.38, "speed": 1.6, "range": 2.8, "arc": 0.9, "lunge": 6.0}],
		"skills": [["charge", "Investida", 5.0], ["bash", "Muralha de Escudo", 8.0], ["spin", "Golpe Giratório", 14.0]]},
	"barbarian": {"name": "Bárbaro", "model": "Barbarian", "desc": "Dois machados. Muito dano, pouca defesa.",
		"hp": 140, "speed": 6.3, "right": "axe_1handed", "left": "axe_1handed", "unlock": 120,
		"attack": [
			{"anim": "Melee_Dualwield_Attack_Chop", "dmg": 26, "hit": 0.4, "speed": 1.45, "range": 2.5, "arc": 1.4, "lunge": 3.0},
			{"anim": "Melee_Dualwield_Attack_Slice", "dmg": 28, "hit": 0.38, "speed": 1.45, "range": 2.5, "arc": 1.8, "lunge": 3.0},
			{"anim": "Melee_2H_Attack_Chop", "dmg": 48, "hit": 0.45, "speed": 1.5, "range": 2.8, "arc": 1.2, "lunge": 4.0}],
		"skills": [["leap", "Salto Esmagador", 6.0], ["rage", "Fúria", 12.0], ["whirl", "Redemoinho", 14.0]]},
	"mage": {"name": "Maga", "model": "Mage", "desc": "Cajado e magia. Ataca de longe, frágil de perto.",
		"hp": 105, "speed": 6.0, "right": "staff", "left": "", "unlock": 200,
		"attack": [
			{"anim": "Ranged_Magic_Shoot", "dmg": 20, "hit": 0.35, "speed": 1.6, "range": 14.0, "shot": "bolt"},
			{"anim": "Ranged_Magic_Shoot", "dmg": 20, "hit": 0.35, "speed": 1.6, "range": 14.0, "shot": "bolt"},
			{"anim": "Ranged_Magic_Spellcasting", "dmg": 34, "hit": 0.5, "speed": 1.3, "range": 14.0, "shot": "orb"}],
		"skills": [["fireball", "Bola de Fogo", 5.0], ["blink", "Teleporte", 6.0], ["meteors", "Chuva de Meteoros", 16.0]]},
	"rogue": {"name": "Ladina", "model": "Rogue_Hooded", "desc": "Adagas rápidas e facas. Esquiva e golpes críticos.",
		"hp": 115, "speed": 7.0, "right": "dagger", "left": "dagger", "unlock": 300,
		"attack": [
			{"anim": "Melee_Dualwield_Attack_Stab", "dmg": 16, "hit": 0.3, "speed": 2.0, "range": 2.2, "arc": 1.0, "lunge": 4.0},
			{"anim": "Melee_1H_Attack_Slice_Horizontal", "dmg": 16, "hit": 0.32, "speed": 2.0, "range": 2.2, "arc": 1.7, "lunge": 3.0},
			{"anim": "Melee_Dualwield_Attack_Chop", "dmg": 26, "hit": 0.35, "speed": 1.9, "range": 2.3, "arc": 1.2, "lunge": 4.0}],
		"skills": [["knives", "Leque de Facas", 4.0], ["shadow", "Passo Sombrio", 7.0], ["blades", "Tempestade de Lâminas", 14.0]]},
	"ranger": {"name": "Arqueiro", "model": "Ranger", "desc": "Arco longo. Tiros precisos e armadilhas.",
		"hp": 120, "speed": 6.4, "right": "", "left": "bow_withString", "unlock": 400,
		"attack": [
			{"anim": "Ranged_Bow_Release", "dmg": 22, "hit": 0.25, "speed": 1.8, "range": 16.0, "shot": "arrow"},
			{"anim": "Ranged_Bow_Release", "dmg": 22, "hit": 0.25, "speed": 1.8, "range": 16.0, "shot": "arrow"},
			{"anim": "Ranged_Bow_Release_Up", "dmg": 30, "hit": 0.3, "speed": 1.6, "range": 16.0, "shot": "arrow3"}],
		"skills": [["volley", "Rajada", 5.0], ["roll_shot", "Rolamento e Tiro", 6.0], ["rain", "Chuva de Flechas", 14.0]]},
}
# armour colours you can pick for your hero (multiplied over the kit's own texture)
const TINTS := [Color(1, 1, 1), Color(0.75, 0.85, 1.35), Color(1.35, 0.7, 0.65), Color(0.75, 1.3, 0.75), Color(1.35, 1.2, 0.6),
	Color(1.2, 0.8, 1.35), Color(0.55, 0.55, 0.6), Color(1.4, 1.4, 1.4)]
const TINT_NAMES := ["Original", "Azul", "Rubi", "Esmeralda", "Ouro", "Ametista", "Sombra", "Prata"]

# ------------------------------------------------------------------ enemies
# kind: melee / ranged (shoots) / caster (slow homing orbs, summons); scale > 1 for elites and bosses
const ENEMIES := {
	"minion": {"name": "Esqueleto", "model": "Skeleton_Minion", "hp": 40, "dmg": 10, "speed": 4.2, "range": 1.8, "kind": "melee",
		"attack": "Melee_1H_Attack_Chop", "right": "Skeleton_Blade", "gold": 3, "xp": 4},
	"warrior": {"name": "Guerreiro Ossudo", "model": "Skeleton_Warrior", "hp": 90, "dmg": 18, "speed": 3.4, "range": 2.2, "kind": "melee",
		"attack": "Melee_2H_Attack_Chop", "right": "Skeleton_Axe", "left": "Skeleton_Shield_Large_A", "gold": 6, "xp": 8},
	"rogue": {"name": "Atirador Ossudo", "model": "Skeleton_Rogue", "hp": 50, "dmg": 12, "speed": 4.6, "range": 11.0, "kind": "ranged",
		"attack": "Ranged_1H_Shoot", "right": "Skeleton_Crossbow", "gold": 4, "xp": 6},
	"mage": {"name": "Necromante", "model": "Skeleton_Mage", "hp": 60, "dmg": 16, "speed": 3.2, "range": 10.0, "kind": "caster",
		"attack": "Ranged_Magic_Shoot", "right": "Skeleton_Staff", "gold": 6, "xp": 8},
}
# bosses: a giant of one enemy kind with extra moves; phase 2 under half HP
const BOSSES := [
	{"name": "Rei Esqueleto", "base": "warrior", "scale": 2.4, "hp": 900, "dmg": 28, "moves": ["slam", "summon", "spin"]},
	{"name": "Bruxa dos Ossos", "base": "mage", "scale": 2.3, "hp": 1100, "dmg": 24, "moves": ["nova", "summon", "orbs"]},
	{"name": "Senhor da Brasa", "base": "warrior", "scale": 2.8, "hp": 1600, "dmg": 34, "moves": ["slam", "spin", "nova", "summon"]},
]

# ------------------------------------------------------------------ the dungeon
# floors: biome, rooms before the boss, which enemies appear
const FLOORS := [
	{"name": "Cripta Esquecida", "biome": "crypt", "rooms": 5, "pool": ["minion", "minion", "warrior", "rogue"]},
	{"name": "Floresta Sombria", "biome": "forest", "rooms": 5, "pool": ["minion", "rogue", "warrior", "mage"]},
	{"name": "Fortaleza da Brasa", "biome": "fort", "rooms": 6, "pool": ["warrior", "rogue", "mage", "minion", "warrior"]},
]

# blessings offered after each room (pick 1 of 3): stat changes on the run
const BLESSINGS := [
	{"id": "dmg", "name": "Lâmina Afiada", "desc": "+20% de dano", "col": Color(1, 0.4, 0.3)},
	{"id": "aspd", "name": "Mãos Ligeiras", "desc": "+15% velocidade de ataque", "col": Color(1, 0.8, 0.3)},
	{"id": "hp", "name": "Coração de Ferro", "desc": "+30 de vida máxima e cura 30", "col": Color(0.4, 1, 0.4)},
	{"id": "crit", "name": "Olho do Falcão", "desc": "+12% de chance de crítico (dano x2)", "col": Color(1, 1, 0.5)},
	{"id": "leech", "name": "Sede de Sangue", "desc": "Cada golpe cura 2 de vida", "col": Color(0.9, 0.2, 0.3)},
	{"id": "cdr", "name": "Mente Rápida", "desc": "Habilidades recarregam 20% mais rápido", "col": Color(0.5, 0.7, 1)},
	{"id": "burn", "name": "Toque de Brasa", "desc": "Golpes queimam: 12 de dano em 3 s", "col": Color(1, 0.55, 0.15)},
	{"id": "chain", "name": "Raio Encadeado", "desc": "25% de chance de um raio pular para 2 inimigos", "col": Color(0.6, 0.9, 1)},
	{"id": "thorns", "name": "Pele de Espinhos", "desc": "Quem te bate leva 15 de dano", "col": Color(0.6, 0.8, 0.4)},
	{"id": "speed", "name": "Botas Leves", "desc": "+12% velocidade de movimento", "col": Color(0.8, 1, 1)},
	{"id": "potion", "name": "Frasco Extra", "desc": "+1 poção de cura", "col": Color(1, 0.4, 0.6)},
	{"id": "gold", "name": "Bolsa Funda", "desc": "+40% de ouro", "col": Color(1, 0.85, 0.2)},
]

# village upgrades bought with gold between runs: [id, name, description, base cost, max level]
const UPGRADES := [
	["vida", "Vitalidade", "+12 de vida máxima por nível", 40, 10],
	["forca", "Força", "+6% de dano por nível", 50, 10],
	["pocao", "Alquimia", "+1 poção por nível", 120, 3],
	["sorte", "Sorte", "+4% de crítico por nível", 80, 5],
	["ganancia", "Ganância", "+10% de ouro por nível", 60, 5],
]

static func upgrade_cost(base: int, lv: int) -> int:
	return int(base * pow(1.6, lv))

# XP to go from level n to n + 1 (a hero's level: +6% HP and damage each)
static func xp_need(lv: int) -> int:
	return 30 + lv * lv * 12
