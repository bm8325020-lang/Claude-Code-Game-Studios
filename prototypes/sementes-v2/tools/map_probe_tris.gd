# Map agent probe: triangle counts of kit models.
extends SceneTree

func _count(n: Node) -> int:
	var t: int = 0
	if n is MeshInstance3D:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if idx.size() > 0:
				t += idx.size() / 3
			else:
				t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in n.get_children():
		t += _count(c)
	return t

func _init() -> void:
	var dir: String = OS.get_environment("PROBE_DIR")
	for nm in OS.get_environment("PROBE").split(","):
		var inst: Node = (load("res://assets/%s/%s.gltf" % [dir, nm]) as PackedScene).instantiate()
		print(nm, " tris=", _count(inst))
		inst.free()
	quit()
