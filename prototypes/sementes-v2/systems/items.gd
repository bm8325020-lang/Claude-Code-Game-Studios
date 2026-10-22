# PROTOTYPE - NOT FOR PRODUCTION
# Items: every item definition, the inventory, what the hero has equipped and the look it gives CharacterKit.
# Pure data and rules (RefCounted), no scene access, so tests/test_systems.gd checks it headless.
#
# Contract assumptions (other modules):
# - CharacterKit.make(look) reads look keys "outfit" ("Peasant"/"Ranger"), "weapon" (prop name in assets/props or ""),
#   "shield" (prop name or ""). look() also adds "tier" (0..2) and "tint" (Color as html string or "") as hints;
#   CharacterKit may ignore them.
# - Only Sword_Bronze, Axe_Bronze, Pickaxe_Bronze and Shield_Wooden exist in assets/props, so higher tiers reuse
#   the same mesh with a tint.
class_name Items
extends RefCounted

signal changed()
signal equipped(slot: String, id: String)

# kind: weapon | shield | outfit | consumable | seed | quest | material | keepsake
# weapon: dmg (base hit), prop; shield: block (fraction of damage stopped), prop; outfit: armor, look;
# consumable: heal (hp), refill (true: comes back at every Marco up to refill_max)
const DEFS: Dictionary = {
	# weapons
	"espada_relha": {"name": "Espada de Relha", "kind": "weapon", "tier": 1, "dmg": 12, "prop": "Sword_Bronze", "tint": "",
		"desc": "Forjada de uma relha que arou a terra por quarenta anos."},
	"machado_bronze": {"name": "Machado de Lenhador", "kind": "weapon", "tier": 1, "dmg": 15, "prop": "Axe_Bronze", "tint": "",
		"desc": "Pesado e lento. Corta lenha e o que mais vier."},
	"picareta_gaspar": {"name": "Picareta do Gaspar", "kind": "weapon", "tier": 1, "dmg": 13, "prop": "Pickaxe_Bronze", "tint": "",
		"desc": "Setenta anos de mina no cabo."},
	"espada_lume": {"name": "Espada do Lume", "kind": "weapon", "tier": 2, "dmg": 24, "prop": "Sword_Bronze", "tint": "#ff9a3c",
		"desc": "Temperada com minério de brasa. Ainda está morna."},
	# shields
	"escudo_tonel": {"name": "Escudo de Tampa de Tonel", "kind": "shield", "tier": 1, "block": 0.6, "prop": "Shield_Wooden", "tint": "",
		"desc": "Tampa de tonel com alça de couro. Aguenta mais do que parece."},
	"escudo_carvalho": {"name": "Escudo de Carvalho Ferrado", "kind": "shield", "tier": 2, "block": 0.8, "prop": "Shield_Wooden", "tint": "#c9a46a",
		"desc": "Carvalho com aro de ferro, feito por Joana."},
	# outfits
	"roupa_emprestada": {"name": "Camisola Emprestada", "kind": "outfit", "tier": 0, "armor": 0, "look": "Peasant",
		"desc": "Grande demais, mas seca."},
	"roupa_tome": {"name": "Roupas de Camponês", "kind": "outfit", "tier": 0, "armor": 2, "look": "Peasant",
		"desc": "As roupas de Tomé, filho de Rosa."},
	"gibao_patrulheiro": {"name": "Gibão de Patrulheiro", "kind": "outfit", "tier": 1, "armor": 6, "look": "Ranger",
		"desc": "Couro curtido, capuz e bolsos para tudo."},
	"gibao_reforcado": {"name": "Gibão Reforçado", "kind": "outfit", "tier": 2, "armor": 11, "look": "Ranger",
		"desc": "Placas tiradas dos elmos da Vigília, costuradas no couro."},
	# consumables
	"pao_rosa": {"name": "Pão de Rosa", "kind": "consumable", "heal": 35, "refill": false, "desc": "Ainda quente. Cura um pouco."},
	"frasco": {"name": "Frasco de Chá-de-Brasa", "kind": "consumable", "heal": 60, "refill": true,
		"desc": "Enche de novo em cada Marco de Lume."},
	"caldo_rosa": {"name": "Caldo da Rosa", "kind": "consumable", "heal": 120, "refill": true,
		"desc": "Cura muito. A tigela volta cheia em cada Marco."},
	"queijo_quinta": {"name": "Queijo da Quinta", "kind": "consumable", "heal": 50, "refill": false, "desc": "Das vacas santas do Matias."},
	"peixe_assado": {"name": "Peixe Assado", "kind": "consumable", "heal": 45, "refill": false, "desc": "Do Lago Manso."},
	# the Dragon Seeds (keep: never taken by quests)
	"semente_carvalha": {"name": "Semente da Carvalha", "kind": "seed", "keep": true,
		"memory": "O primeiro voo da Lumeira, sobre o mar.", "desc": "Quente como pão saído do forno."},
	"semente_sem_terra": {"name": "Semente Roubada", "kind": "seed", "keep": true,
		"memory": "A Lumeira cansada, voando cada vez mais baixo.", "desc": "Caiu de uma carroça da Vigília."},
	"semente_afogada": {"name": "Semente Afogada", "kind": "seed", "keep": true,
		"memory": "A Lumeira bebendo no lago e decidindo ficar.", "desc": "Ainda pinga água do Lago Manso."},
	"semente_funda": {"name": "Semente Funda", "kind": "seed", "keep": true,
		"memory": "Uma voz grande e cansada, que só diz: \"Deixem.\"", "desc": "Plantada em segredo pelos mineiros."},
	# quest items
	"nabo": {"name": "Nabo", "kind": "quest", "desc": "Do campo cinzento do Matias."},
	"relha_velha": {"name": "Relha Velha", "kind": "quest", "desc": "Ferro de arado gasto, esquecido no celeiro."},
	"farinha": {"name": "Saco de Farinha", "kind": "quest", "desc": "Do Moinho das Três Mós."},
	"carta_matias": {"name": "Carta Sem Assinatura", "kind": "quest", "keep": true, "desc": "A letra é do Matias."},
	"livro_desenterro": {"name": "Livro do Desenterro", "kind": "quest", "keep": true, "desc": "Cada semente e cada lasca arrancada."},
	"cartas_rosa": {"name": "Cartas da Rosa", "kind": "quest", "desc": "Uma por semana, nenhuma mandada."},
	"sino_vaca": {"name": "Sino de Vaca", "kind": "quest", "desc": "Torto. Pode ser da Santa Inês."},
	"elmo_vigilia": {"name": "Elmo da Vigília", "kind": "quest", "desc": "Ainda tem brasa nas frestas."},
	"peixe_lua": {"name": "Peixe-Lua", "kind": "quest", "desc": "Brilha fraquinho. Sabe quando vai chover."},
	"lasca_bene": {"name": "Lasca do Seu Bené", "kind": "quest", "desc": "Uma lasca de semente costurada num forro."},
	# materials and keepsakes
	"minerio_brasa": {"name": "Minério de Brasa", "kind": "material", "desc": "Pedra morna da Mina do Fôlego."},
	"mapa_vale": {"name": "Mapa das Covas", "kind": "keepsake", "keep": true, "desc": "O vale com cada cova marcada."},
	"cavalinho_de_pau": {"name": "Cavalinho de Pau", "kind": "keepsake", "keep": true, "desc": "Feito pela Vó Cândida para o pequeno Aurélio."},
	"anzol_celeste": {"name": "Anzol de Celeste", "kind": "keepsake", "keep": true, "desc": "Do marido dela."},
}

const UNARMED_DMG: int = 4
const SLOTS: Array[String] = ["weapon", "shield", "outfit"]

# Seu Bené's cart: id -> price in gold (the desconto_bene unlock takes 20% off)
const SHOP: Dictionary = {"pao_rosa": 6, "peixe_assado": 9, "machado_bronze": 90}

var bag: Dictionary = {}          # id -> count
var slots: Dictionary = {"weapon": "", "shield": "", "outfit": "roupa_emprestada"}
var refill_max: Dictionary = {}   # refillable consumable id -> max carried (frasco, caldo_rosa)


func _init() -> void:
	bag["roupa_emprestada"] = 1


static func def(id: String) -> Dictionary:
	return DEFS.get(id, {}) as Dictionary


static func item_name(id: String) -> String:
	return str(def(id).get("name", id))


func count(id: String) -> int:
	return int(bag.get(id, 0))


func has(id: String) -> bool:
	return count(id) > 0


func add(id: String, n: int = 1) -> void:
	if n <= 0 or not DEFS.has(id):
		push_warning("Items.add: unknown item %s" % id)
		return
	bag[id] = count(id) + n
	changed.emit()


func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left: int = count(id) - n
	if left == 0:
		bag.erase(id)
		for s: String in SLOTS:
			if str(slots[s]) == id:
				slots[s] = "roupa_emprestada" if s == "outfit" else ""
				equipped.emit(s, str(slots[s]))
	else:
		bag[id] = left
	changed.emit()
	return true


# slot this item goes in, or "" if it can't be equipped
static func slot_of(id: String) -> String:
	var k: String = str(def(id).get("kind", ""))
	return k if k in SLOTS else ""


func equip(id: String) -> bool:
	var s: String = slot_of(id)
	if s == "" or not has(id):
		return false
	slots[s] = id
	equipped.emit(s, id)
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if slot == "outfit" or not slots.has(slot):
		return
	slots[slot] = ""
	equipped.emit(slot, "")
	changed.emit()


# heal amount (0 if nothing was used)
func use(id: String) -> int:
	var d: Dictionary = def(id)
	if str(d.get("kind", "")) != "consumable" or not remove(id):
		return 0
	return int(d.get("heal", 0))


# a new refillable (frasco, caldo_rosa): carry n more, and get them now
func raise_refill(id: String, n: int) -> void:
	refill_max[id] = int(refill_max.get(id, 0)) + n
	add(id, n)


# at a Marco de Lume: every refillable back to its max
func refill() -> void:
	for id: String in refill_max:
		bag[id] = maxi(count(id), int(refill_max[id]))
	changed.emit()


func buy(id: String, prog: Progression) -> bool:
	if not SHOP.has(id):
		return false
	if not prog.spend_gold(price(id, prog)):
		return false
	add(id)
	return true


static func price(id: String, prog: Progression) -> int:
	var p: int = int(SHOP.get(id, 0))
	return int(round(p * 0.8)) if prog.has_unlock("desconto_bene") else p


func weapon_damage() -> int:
	return int(def(str(slots.weapon)).get("dmg", UNARMED_DMG))


# fraction of incoming damage stopped while blocking (0 without a shield)
func block_mult() -> float:
	return float(def(str(slots.shield)).get("block", 0.0))


func armor() -> int:
	return int(def(str(slots.outfit)).get("armor", 0))


# the CharacterKit look keys for the equipped gear
func look() -> Dictionary:
	var w: Dictionary = def(str(slots.weapon))
	var sh: Dictionary = def(str(slots.shield))
	var o: Dictionary = def(str(slots.outfit))
	return {"outfit": str(o.get("look", "Peasant")), "weapon": str(w.get("prop", "")), "shield": str(sh.get("prop", "")),
		"tier": int(w.get("tier", 0)), "tint": str(w.get("tint", ""))}


# inventory for the menu: [{id, name, kind, count, equipped, desc}]
func list() -> Array:
	var out: Array = []
	for id: String in bag:
		var d: Dictionary = def(id)
		out.append({"id": id, "name": str(d.get("name", id)), "kind": str(d.get("kind", "")), "count": count(id),
			"equipped": slots.values().has(id), "desc": str(d.get("desc", ""))})
	return out


func to_dict() -> Dictionary:
	return {"bag": bag.duplicate(), "slots": slots.duplicate(), "refill_max": refill_max.duplicate()}


func from_dict(d: Dictionary) -> void:
	bag = {}
	var b: Dictionary = d.get("bag", {}) as Dictionary
	for id: String in b:
		if DEFS.has(id):
			bag[id] = int(b[id])
	var s: Dictionary = d.get("slots", {}) as Dictionary
	for k: String in SLOTS:
		var v: String = str(s.get(k, ""))
		slots[k] = v if (v == "" or has(v)) else ""
	if str(slots.outfit) == "":
		slots.outfit = "roupa_emprestada"
		if not has("roupa_emprestada"):
			bag["roupa_emprestada"] = 1
	refill_max = {}
	var r: Dictionary = d.get("refill_max", {}) as Dictionary
	for id: String in r:
		refill_max[id] = int(r[id])
	changed.emit()
