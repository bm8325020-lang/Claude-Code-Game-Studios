extends SceneTree
const MapT = preload("res://world/map.gd")
func _init() -> void:
	var map: MapT = MapT.new()
	get_root().add_child(map)
	map.build()
	print("BUILD OK stats=", map.stats)
	print("spawns=", map.spawns.size(), " places=", map.places.size(), " camps=", map.camps.size(), " npcs=", map.npc_spots.size(), " inter=", map.interactables.size())
	var need: Array = ["village","farm","river","forest","bandit_camp","watchtower","mine","castle","lake","mina_fundo"]
	for id in need:
		var ok: bool = false
		for p in map.places:
			if p.id == id: ok = true
		if not ok: print("MISSING PLACE ", id)
	print("area@square=", map.area_name(Vector3(0,0,-20)), " area@lake=", map.area_name(Vector3(30,0,216)))
	quit()
