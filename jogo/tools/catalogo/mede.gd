# Mede cada item de assets/catalogo/lista.json (caixa do modelo) e escreve assets/catalogo/medidas.json.
#   godot --headless --path . -s res://tools/catalogo/mede.gd
extends SceneTree


func _init() -> void:
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalogo/lista.json"))
	var out: Dictionary = {}
	for it: Dictionary in lista:
		var c: String = it.cena
		if c.begins_with("jogo:") or not ResourceLoader.exists(c):
			continue
		var cena := load(c) as PackedScene
		if cena == null:
			continue
		var n: Node = cena.instantiate()
		var a := AABB()
		var prim := true
		var tris := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var t: Transform3D = Transform3D.IDENTITY
			var p: Node = mi
			while p != n and p is Node3D:
				t = (p as Node3D).transform * t
				p = p.get_parent()
			var b: AABB = t * mi.get_aabb()
			a = b if prim else a.merge(b)
			prim = false
			for s in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		n.free()
		out[it.id] = {"tam": [snappedf(a.size.x, 0.01), snappedf(a.size.y, 0.01), snappedf(a.size.z, 0.01)],
			"min_y": snappedf(a.position.y, 0.01), "tris": tris}
	var f := FileAccess.open("res://assets/catalogo/medidas.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	print("MEDIDOS ", out.size())
	quit()
