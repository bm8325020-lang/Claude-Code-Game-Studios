# PROTOTYPE - NOT FOR PRODUCTION
# The hero you make yourself: Quaternius Modular Character Outfits (CC0) on the Universal Base Characters rig. Body,
# arms, legs and feet each pick a style (peasant or ranger), with a hood and a pauldron, a head, a hairstyle, a beard
# and colours for the clothes, the skin and the hair. Pieces and colours unlock with your level (LOCKS).
extends RefCounted

const QRig = preload("res://qrig.gd")
const DIR := "res://assets/qchars/"
const DEFAULT := {"sex": "Male", "body": "Ranger", "arms": "Ranger", "legs": "Ranger", "feet": "Ranger", "hood": false,
	"pauldron": false, "hair": "Hair_SimpleParted", "beard": false, "cloth": 0, "skin": 0, "hair_col": 0}
const HAIRS := ["Hair_SimpleParted", "Hair_Long", "Hair_Buns", "Hair_Buzzed", "Hair_BuzzedFemale", ""]
const HAIR_NAMES := ["Repartido", "Longo", "Coque", "Raspado", "Curto", "Careca"]
# colour multipliers over the kit's own textures
const CLOTH := [Color(1, 1, 1), Color(0.55, 0.75, 1.5), Color(1.5, 0.55, 0.5), Color(0.6, 1.35, 0.6), Color(1.5, 1.25, 0.5),
	Color(1.2, 0.6, 1.5), Color(0.45, 0.45, 0.5), Color(1.6, 1.6, 1.6)]
const CLOTH_NAMES := ["Natural", "Azul", "Vermelho", "Verde", "Dourado", "Roxo", "Negro", "Branco"]
const SKIN := [Color(1, 1, 1), Color(1.3, 1.15, 1.05), Color(1.55, 1.35, 1.2), Color(0.75, 0.62, 0.55), Color(0.55, 0.45, 0.4)]
const SKIN_NAMES := ["Morena", "Clara", "Muito clara", "Escura", "Muito escura"]
const HAIR_COL := [Color(0.5, 0.32, 0.18), Color(0.12, 0.1, 0.1), Color(1.0, 0.85, 0.48), Color(0.9, 0.35, 0.12), Color(0.85, 0.85, 0.88),
	Color(0.3, 0.5, 1.0), Color(1.0, 0.5, 0.75)]  # the kit's hair is near white: these are the colours themselves
const HAIR_COL_NAMES := ["Castanho", "Preto", "Loiro", "Ruivo", "Grisalho", "Azul", "Rosa"]
# what you must reach to wear it: [key, value, level]
const LOCKS := [["body", "Ranger", 1], ["arms", "Ranger", 1], ["legs", "Ranger", 1], ["feet", "Ranger", 1],
	["pauldron", true, 5], ["hood", true, 10], ["cloth", 4, 15], ["cloth", 5, 15], ["cloth", 6, 20], ["cloth", 7, 25],
	["hair_col", 5, 12], ["hair_col", 6, 12]]

static func level_needed(key: String, value) -> int:
	for l in LOCKS:
		if l[0] == key and l[1] == value:
			return l[2]
	return 1

# the hero's model and its AnimationPlayer (the Universal Animation Library clips; main.gd adds the sword moves)
static func build(look: Dictionary) -> Array:
	var lk := DEFAULT.merged(look, true)
	var sex: String = lk.sex
	var root: Node3D = load(DIR + "parts/%s_%s_Body.gltf" % [sex, lk.body]).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var feet: String = ("%s_Ranger_Feet_Boots" if sex == "Male" else "%s_Ranger_Feet") % sex if lk.feet == "Ranger" else "%s_Peasant_Feet" % sex
	var parts := [DIR + "parts/%s_%s_Arms.gltf" % [sex, lk.arms], DIR + "parts/%s_%s_Legs.gltf" % [sex, lk.legs], DIR + "parts/%s.gltf" % feet,
		DIR + "Head_%s.glb" % sex, DIR + ("Eyebrows_Regular.gltf" if sex == "Male" else "Eyebrows_Female.gltf")]
	if lk.pauldron:
		parts.append(DIR + "parts/%s_Ranger_Acc_%s.gltf" % [sex, "Pauldron" if sex == "Male" else "Pauldrons"])
	if lk.hood:
		parts.append(DIR + "parts/%s_Ranger_Head_Hood.gltf" % sex)
	elif lk.hair != "":
		parts.append(DIR + lk.hair + ".gltf")
	if lk.beard and sex == "Male":
		parts.append(DIR + "Hair_Beard.gltf")
	for part in parts:
		var src: Node = load(part).instantiate()
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			mi.get_parent().remove_child(mi)
			mi.owner = null
			sk.add_child(mi)
			mi.skeleton = NodePath("..")
		src.free()
	_paint(sk, lk)
	for old in root.find_children("*", "AnimationPlayer", true, false):
		old.queue_free()
	var ap := AnimationPlayer.new()
	sk.get_parent().add_child(ap)
	ap.root_node = NodePath("..")
	var key := "hero|" + sex
	if not QRig.libs.has(key):
		QRig.libs[key] = QRig._build(sk, false)
	ap.add_animation_library("", QRig.libs[key])
	return [root, ap]

# clothes, skin and hair colours: each surface's material is copied and tinted by what its texture is
static func _paint(sk: Skeleton3D, lk: Dictionary) -> void:
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null:
				continue
			var tex := m.albedo_texture.resource_path.get_file() if m.albedo_texture else ""
			var tint := Color.WHITE
			if tex.contains("Peasant") or tex.contains("Ranger"):
				tint = CLOTH[lk.cloth]
			elif tex.contains("Hair") or str(mi.name).contains("Hair") or str(mi.name).contains("Beard") or str(mi.name).contains("Eyebrow"):
				tint = HAIR_COL[lk.hair_col]
			elif tex.contains("Superhero") or tex.contains("Regular"):
				tint = SKIN[lk.skin]
			if tint != Color.WHITE:
				var d: StandardMaterial3D = m.duplicate()
				d.albedo_color = tint
				mi.set_surface_override_material(i, d)
