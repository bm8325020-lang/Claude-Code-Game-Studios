# Map agent probe: prints AABB, surfaces and materials of kit models.
extends SceneTree

func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t: Transform3D = xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var a: AABB = t * mi.mesh.get_aabb()
		if acc.is_empty():
			acc.append(a)
		else:
			acc[0] = (acc[0] as AABB).merge(a)
		var mats: Array = []
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var nm: String = ""
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture:
				nm = (m as BaseMaterial3D).albedo_texture.resource_path.get_file()
			acc.append("%s(%s)" % [m.resource_name if m else "null", nm])
	for c in n.get_children():
		_aabb(c, t, acc)

func _init() -> void:
	var dir: String = OS.get_environment("PROBE_DIR")
	var names: PackedStringArray = OS.get_environment("PROBE").split(",")
	for nm in names:
		var ps: PackedScene = load("res://assets/%s/%s.gltf" % [dir, nm])
		if ps == null:
			print(nm, " MISSING")
			continue
		var inst: Node = ps.instantiate()
		var acc: Array = []
		_aabb(inst, Transform3D.IDENTITY, acc)
		if acc.is_empty():
			print(nm, " no mesh")
		else:
			var a: AABB = acc[0]
			print("%s pos=%s size=%s mats=%s" % [nm, a.position, a.size, str(acc.slice(1))])
		inst.free()
	quit()
