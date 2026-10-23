# PROTOTYPE - NOT FOR PRODUCTION
# Farm: repeatable hunting contracts (Blox Fruits style). A hunter in each zone offers "defeat N <kind>"; the
# hero accepts, kills of that kind count, and the reward (XP and gold scaled by zone level) pays out at once.
# Then talk to a hunter again for the next contract. One contract at a time.
class_name Farm
extends RefCounted

signal accepted(c: Dictionary)
signal progress(have: int, need: int)
signal finished(c: Dictionary)

const KIND_NAME: Dictionary = {"wolf_imp": "Diabretes", "bandit": "Bandidos", "bandit_archer": "Bandidos Arqueiros",
	"puglin": "Puglins", "possessed": "Insones", "knight": "Cavaleiros da Vigília"}
const NEED: int = 5

var active: Dictionary = {}  # {place, kind, need, have, xp, gold, level}


# a contract for this zone's enemy kind
static func offer(place: String, kind: String) -> Dictionary:
	var r: Array = Zones.range_of(place)
	var lvl: int = int(r[1])
	return {"place": place, "kind": kind, "need": NEED, "have": 0, "level": lvl,
		"xp": 40 + 30 * lvl, "gold": 10 + 6 * lvl}


static func text(c: Dictionary) -> String:
	return "Derrote %d %s (Nv %d)" % [int(c.need), str(KIND_NAME.get(c.kind, c.kind)), int(c.level)]


func accept(c: Dictionary) -> void:
	active = c.duplicate()
	accepted.emit(active)


func has_active() -> bool:
	return not active.is_empty()


# call on every kill; returns the finished contract (rewards to pay) or {}
func on_kill(kind: String) -> Dictionary:
	if active.is_empty() or kind != str(active.kind):
		return {}
	active.have = int(active.have) + 1
	progress.emit(int(active.have), int(active.need))
	if int(active.have) < int(active.need):
		return {}
	var done: Dictionary = active
	active = {}
	finished.emit(done)
	return done


func to_dict() -> Dictionary:
	return {"active": active.duplicate()}


func from_dict(d: Dictionary) -> void:
	active = (d.get("active", {}) as Dictionary).duplicate()
