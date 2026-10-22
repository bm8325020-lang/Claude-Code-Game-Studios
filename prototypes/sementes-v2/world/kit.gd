# PROTOTYPE - NOT FOR PRODUCTION
# Map module helper: loads Quaternius kit models once, flattens each one into a single ArrayMesh
# (one surface per material), and merges many placed copies into one mesh per material
# so a whole village costs a handful of draw calls.
class_name MapKit
extends RefCounted

const DIRS: Array[String] = ["village", "nature", "props"]

var _mesh_cache: Dictionary = {}       # "dir/Name" -> ArrayMesh
var _mat_by_name: Dictionary = {}      # material resource_name -> Material (first one seen)


func path_of(name: String) -> String:
	if name.contains("/"):
		return "res://assets/%s.gltf" % name
	for d in DIRS:
		var p: String = "res://assets/%s/%s.gltf" % [d, name]
		if ResourceLoader.exists(p):
			return p
	push_error("MapKit: model not found " + name)
	return ""


# The whole model as one ArrayMesh, one surface per material, in model space.
# "Name#variant" returns a copy with tinted materials (wheat, grey, dark, moss).
const VARIANTS: Dictionary = {
	"wheat": Color(1.55, 1.12, 0.42), "grey": Color(0.78, 0.74, 0.66), "dark": Color(0.62, 0.66, 0.58),
	"autumn": Color(1.35, 0.85, 0.45), "moss": Color(0.75, 0.95, 0.6),
}


func mesh(name: String) -> ArrayMesh:
	if _mesh_cache.has(name):
		return _mesh_cache[name]
	if name.contains("#"):
		var parts: PackedStringArray = name.split("#")
		var src: ArrayMesh = mesh(parts[0])
		var tint: Color = VARIANTS.get(parts[1], Color.WHITE)
		var v: ArrayMesh = ArrayMesh.new()
		for s in src.get_surface_count():
			v.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
			var key: String = src.surface_get_name(s) + "#" + parts[1]
			if not _mat_by_name.has(key):
				var m: Material = src.surface_get_material(s)
				if m is BaseMaterial3D:
					var bm: BaseMaterial3D = (m as BaseMaterial3D).duplicate()
					bm.albedo_color = bm.albedo_color * tint
					m = bm
				_mat_by_name[key] = m
			v.surface_set_material(s, _mat_by_name[key])
			v.surface_set_name(s, key)
		_mesh_cache[name] = v
		return v
	var p: String = path_of(name)
	var out: ArrayMesh = ArrayMesh.new()
	if p == "":
		_mesh_cache[name] = out
		return out
	var ps: PackedScene = load(p)
	var root: Node = ps.instantiate()
	var tools: Dictionary = {}   # mat name -> SurfaceTool
	_collect(root, Transform3D.IDENTITY, tools)
	root.free()
	var keys: Array = tools.keys()
	keys.sort()
	for k in keys:
		var st: SurfaceTool = tools[k]
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _mat_by_name[k])
		out.surface_set_name(out.get_surface_count() - 1, k)
	_mesh_cache[name] = out
	return out


func _collect(n: Node, xf: Transform3D, tools: Dictionary) -> void:
	var t: Transform3D = xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var key: String = _mat_key(m)
			if not tools.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = st
			(tools[key] as SurfaceTool).append_from(mi.mesh, s, t)
	for c in n.get_children():
		_collect(c, t, tools)


func _mat_key(m: Material) -> String:
	var key: String = "null"
	if m != null:
		key = m.resource_name
		if key == "":
			key = str(m.get_instance_id())
	if not _mat_by_name.has(key):
		var use: Material = m
		if m is BaseMaterial3D:
			use = (m as BaseMaterial3D).duplicate()
			_tune(use as BaseMaterial3D, key)
		_mat_by_name[key] = use
	return key


# Small art-direction fixes on kit materials (all opaque kit surfaces get the same treatment).
func _tune(m: BaseMaterial3D, key: String) -> void:
	if key.begins_with("Leaves") or key == "Grass" or key == "Flowers" or key.begins_with("MI_Vine"):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
	if key.begins_with("Leaves") or key.begins_with("Bark") or key == "Grass" or key == "Flowers" or key == "Rocks" or key == "PathRocks" or key == "Leaves":
		# lets MultiMesh instance colours tint vegetation (variation without new materials)
		m.vertex_color_use_as_albedo = true
	if key == "MI_WindowGlass":
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color = Color(0.22, 0.20, 0.17)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.62, 0.28)
		m.emission_energy_multiplier = 0.35


func material(key: String) -> Material:
	return _mat_by_name.get(key, null)


# ---------------------------------------------------------------- batching
class Batch:
	extends RefCounted
	var kit: RefCounted
	var tools: Dictionary = {}   # mat key -> SurfaceTool
	var tris: int = 0

	func _init(k: RefCounted) -> void:
		kit = k

	func add(name: String, xf: Transform3D) -> void:
		add_mesh(kit.mesh(name), xf)

	func add_mesh(m: ArrayMesh, xf: Transform3D) -> void:
		for s in m.get_surface_count():
			var key: String = m.surface_get_name(s)
			if key == "":
				key = str(m.surface_get_material(s).get_instance_id())
				kit._mat_by_name[key] = m.surface_get_material(s)
			if not tools.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = st
			(tools[key] as SurfaceTool).append_from(m, s, xf)

	# One MeshInstance3D per material under parent.
	func commit(parent: Node3D, label: String, shadows: bool, vis_end: float = 0.0) -> void:
		for key in tools.keys():
			var st: SurfaceTool = tools[key]
			st.index()
			var am: ArrayMesh = st.commit()
			if am.get_surface_count() == 0:
				continue
			am.surface_set_material(0, kit.material(key))
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "%s_%s" % [label, key]
			mi.mesh = am
			if shadows:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if vis_end > 0.0:
				mi.visibility_range_end = vis_end
				mi.visibility_range_end_margin = vis_end * 0.1
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			parent.add_child(mi)
		tools.clear()


func batch() -> Batch:
	return Batch.new(self)
