# PROTOTYPE - NOT FOR PRODUCTION
# The village between runs, built from the KayKit Medieval Hexagon Pack: a round island of grass hexes with a
# road to the plaza, houses, a tavern, a forge, a church and a windmill, people at work, and three places to use:
# the hero altar (pick and colour your hero), the forge (upgrades for gold) and the portal (start a run).
extends RefCounted

const Rig = preload("res://rig.gd")
const S := 4.0  # a kit hex (2 units across) becomes 8 m
const ROW := 1.7320508 * S

static func hex_pos(q: int, r: int) -> Vector3:
	return Vector3(S * (2.0 * q + r), 0, ROW * r)

static func build(parent: Node3D) -> Dictionary:
	var node := Node3D.new()
	parent.add_child(node)
	var body := StaticBody3D.new()
	node.add_child(body)
	var box := func(center: Vector3, size: Vector3) -> void:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = center
		body.add_child(cs)
	var put := func(name: String, pos: Vector3, rot := 0.0, sc := S) -> Node3D:
		var p := Rig.prop("village", name)
		p.position = pos
		p.rotation.y = rot
		p.scale = Vector3.ONE * sc
		node.add_child(p)
		return p
	var R := 4
	var roads := {Vector2i(0, 0): true, Vector2i(0, 1): true, Vector2i(0, 2): true, Vector2i(0, 3): true}
	var spots := {  # hex -> building (faces the plaza)
		Vector2i(-2, 0): "building_tavern_blue", Vector2i(2, 0): "building_blacksmith_blue", Vector2i(-1, -2): "building_church_blue",
		Vector2i(2, -2): "building_windmill_blue", Vector2i(-3, 2): "building_home_A_blue", Vector2i(3, -1): "building_market_blue",
		Vector2i(1, -3): "building_home_B_blue", Vector2i(-2, -1): "building_home_A_blue", Vector2i(-4, 2): "building_home_B_blue",
		Vector2i(4, -3): "building_tower_A_blue", Vector2i(-1, 3): "building_well_blue", Vector2i(3, -4): "building_home_A_blue"}
	for q in range(-R, R + 1):
		for r in range(-R, R + 1):
			if absi(q + r) > R:
				continue
			var h := Vector2i(q, r)
			var p := hex_pos(q, r)
			put.call("hex_road_A" if roads.has(h) and h != Vector2i(0, 0) else "hex_grass", p, 2.0 * PI / 3.0 if roads.has(h) else 0.0, S)  # road tile A runs across edges 2 and 5 after two 60-degree turns
			var edge := absi(q) == R or absi(r) == R or absi(q + r) == R
			if spots.has(h):
				var to := -p
				put.call(spots[h], p, atan2(to.x, to.z))
				box.call(p + Vector3(0, 3, 0), Vector3(5, 6, 5))
			elif edge and not roads.has(h):  # a ring of trees and hills around the village
				var deco: String = ["trees_B_large", "trees_A_large", "hills_A_trees", "trees_B_medium", "mountain_A_grass_trees"][absi(hash(h)) % 5]
				put.call(deco, p, absi(hash(h)) % 6 * PI / 3.0)
				box.call(p + Vector3(0, 3, 0), Vector3(7, 6, 7))
			elif absi(hash(h)) % 7 == 0 and h != Vector2i(0, 0) and h.length() > 1.5:
				put.call(["tree_single_A", "tree_single_B", "rock_single_A"][absi(hash(h)) % 3], p, 0.0)
	box.call(Vector3(0, -0.5, 0), Vector3(90, 1, 90))
	# props around the plaza
	put.call("barrel", hex_pos(2, 0) + Vector3(-2.5, 0, 3), 0.0, 2.0)
	put.call("crate_A_big", hex_pos(-2, 0) + Vector3(2.5, 0, 3), 0.4, 2.0)
	put.call("flag_blue", hex_pos(1, 1) + Vector3(0, 0, 0), 0.0, 3.0)
	put.call("flag_blue", hex_pos(-1, 1) + Vector3(0, 0, 0), 0.0, 3.0)
	put.call("weaponrack", hex_pos(2, 0) + Vector3(-1, 0, 3.5), PI, 2.5)
	# the portal in the plaza: a ring of light
	var portal := Node3D.new()
	portal.set_meta("keep", true)
	portal.position = hex_pos(0, -1) + Vector3(0, 0, 2)
	node.add_child(portal)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 2.0
	ring.mesh = tm
	ring.rotation.x = PI / 2.0
	ring.position.y = 2.2
	var gm := StandardMaterial3D.new()
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.5, 0.15)
	gm.emission_energy_multiplier = 3.0
	gm.albedo_color = Color(1, 0.6, 0.2)
	ring.material_override = gm
	portal.add_child(ring)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 1.6
	cm.height = 0.05
	disc.mesh = cm
	disc.rotation.x = PI / 2.0
	disc.position.y = 2.2
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1.0, 0.45, 0.1, 0.55)
	disc.material_override = dm
	portal.add_child(disc)
	var pl := OmniLight3D.new()
	pl.position.y = 2.2
	pl.light_color = Color(1, 0.5, 0.2)
	pl.light_energy = 3.0
	pl.omni_range = 8.0
	portal.add_child(pl)
	Rig.merge_static(node)
	# villagers: KayKit adventurers at work
	var people := [["Barbarian", hex_pos(2, 0) + Vector3(-2.2, 0, 2.6), "Hammering", PI * 0.8, "axe_1handed", ""],
		["Mage", hex_pos(-1, 3) + Vector3(2.5, 0, 0), "Sit_Floor_Idle", -PI / 2.0, "", ""],
		["Rogue", hex_pos(-2, 0) + Vector3(2.8, 0, 1.5), "Waving", PI / 2.0, "", ""],
		["Knight", hex_pos(0, -1) + Vector3(3.2, 0, 2.5), "Idle_B", -PI / 2.0, "sword_1handed", "shield_round"],
		["Ranger", hex_pos(-1, -2) + Vector3(1.5, 0, 4), "Working_A", PI, "", ""]]
	for pp in people:
		var r: Array = Rig.make("heroes", pp[0], pp[4], pp[5])
		r[0].position = pp[1]
		r[0].rotation.y = pp[3]
		node.add_child(r[0])
		r[1].play(pp[2])
	var sun := OmniLight3D.new()
	sun.position = Vector3(0, 10, 0)
	sun.light_color = Color(1, 0.9, 0.75)
	sun.light_energy = 0.5
	sun.omni_range = 30
	node.add_child(sun)
	return {"node": node, "spawn": hex_pos(0, 2) + Vector3(0, 0, 0), "bounds": Rect2(-34, -32, 68, 64),
		"stations": [
			{"pos": portal.position, "label": "ENTRAR NA MASMORRA", "action": "portal"},
			{"pos": hex_pos(-1, -2) + Vector3(1.5, 0, 4.5), "label": "ALTAR DOS HERÓIS", "action": "heroes"},
			{"pos": hex_pos(2, 0) + Vector3(-2.5, 0, 4.2), "label": "FORJA", "action": "forge"}]}
