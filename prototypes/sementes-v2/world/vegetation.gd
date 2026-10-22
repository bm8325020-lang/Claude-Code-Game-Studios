# PROTOTYPE - NOT FOR PRODUCTION
# Map module: collects instances of nature models and emits them as chunked MultiMeshes with visibility ranges.
# Rules for *where* things grow live in map.gd; this file only stores and draws.
extends RefCounted

const Kit = preload("res://world/kit.gd")

const CHUNK: float = 64.0

var kit: Kit
# model name -> { "range": float, "shadow": bool, "chunks": { Vector2i: Array[Transform3D] }, "colors": {...} }
var sets: Dictionary = {}
var lod_cache: Dictionary = {}
var count: int = 0


func _init(k: Kit) -> void:
	kit = k


func define(name: String, vis_range: float, shadow: bool) -> void:
	if not sets.has(name):
		sets[name] = {"range": vis_range, "shadow": shadow, "chunks": {}, "colors": {}}


func add(name: String, xf: Transform3D, tint: Color = Color(1, 1, 1, 1)) -> void:
	var s: Dictionary = sets[name]
	var key: Vector2i = Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
	var ch: Dictionary = s.chunks
	if not ch.has(key):
		ch[key] = []
		(s.colors as Dictionary)[key] = []
	(ch[key] as Array).append(xf)
	((s.colors as Dictionary)[key] as Array).append(tint)
	count += 1


# Mesh with generated LODs (Godot picks the LOD per instance group by screen size).
func _lod_mesh(name: String) -> Mesh:
	if lod_cache.has(name):
		return lod_cache[name]
	var src: ArrayMesh = kit.mesh(name)
	var im: ImporterMesh = ImporterMesh.new()
	for s in src.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s), [], {}, src.surface_get_material(s), src.surface_get_name(s))
	im.generate_lods(25.0, 60.0, [])
	var out: ArrayMesh = im.get_mesh()
	lod_cache[name] = out
	return out


func commit(parent: Node3D) -> void:
	for name in sets.keys():
		var s: Dictionary = sets[name]
		var mesh: Mesh = _lod_mesh(name)
		var colors_by_chunk: Dictionary = s.colors
		for key in (s.chunks as Dictionary).keys():
			var arr: Array = s.chunks[key]
			var cols: Array = colors_by_chunk[key]
			var mm: MultiMesh = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = arr.size()
			for i in arr.size():
				mm.set_instance_transform(i, arr[i])
				mm.set_instance_color(i, cols[i])
			var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [name, key.x, key.y]
			mmi.multimesh = mm
			mmi.visibility_range_end = s.range
			mmi.visibility_range_end_margin = 10.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if s.shadow:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)
