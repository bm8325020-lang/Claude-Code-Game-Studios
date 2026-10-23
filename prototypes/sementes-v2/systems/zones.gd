# PROTOTYPE - NOT FOR PRODUCTION
# Zones: the level ladder of the valley (Blox Fruits style). Every place id from the map has a level range; its
# enemies spawn inside that range, the area banner shows it, and walking in under-levelled is meant to kill you.
class_name Zones
extends RefCounted

# place id -> [min level, max level]
const LEVELS: Dictionary = {
	"village": [1, 2],
	"farm": [2, 4],
	"river": [4, 6],
	"forest": [6, 9],
	"lake": [9, 12],
	"bandit_camp": [12, 15],
	"watchtower": [15, 18],
	"mine": [18, 21],
	"mina_fundo": [19, 22],
	"castle": [22, 25],
}
const BOSS_LEVEL: int = 26


static func range_of(place: String) -> Array:
	return LEVELS.get(place, [1, 1]) as Array


# deterministic spread inside the zone's range (i: index of the body in its camp)
static func level_for(place: String, i: int) -> int:
	var r: Array = range_of(place)
	var lo: int = int(r[0])
	var hi: int = int(r[1])
	return lo + (i % (hi - lo + 1))


# "Bosque dos Sussurros · Nv 6–9"
static func label(place: String, place_name: String) -> String:
	if not LEVELS.has(place):
		return place_name
	var r: Array = range_of(place)
	return "%s · Nv %d–%d" % [place_name, int(r[0]), int(r[1])]


# how dangerous a level is for the hero: 0 safe, 1 hard, 2 deadly
static func danger(enemy_level: int, hero_level: int) -> int:
	var d: int = enemy_level - hero_level
	if d >= 5:
		return 2
	if d >= 2:
		return 1
	return 0
