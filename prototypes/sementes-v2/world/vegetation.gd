# PROTOTYPE - NOT FOR PRODUCTION
# Map module: collects instances of nature models and emits them as chunked MultiMeshes with visibility ranges.
# Rules for *where* things grow live in map.gd; this file only stores and draws.
# Sets with a `far` distance get two versions per chunk: the full mesh up close (casts shadows) and the lowest
# generated LOD beyond `far` (no shadows), so a forest on the horizon costs a fraction of the triangles.
extends RefCounted

const Kit = preload("res://world/kit.gd")

const CHUNK: float = 64.0
# Phone budget: cap how far vegetation draws and thin dense scatter. Trees (shadow=true) keep most of their
# count so the forests still read; small ground scatter (grass/flowers/pebbles, shadow=false) is thinned hard.
const MAX_RANGE: float = 70.0
const MAX_FAR: float = 42.0
const KEEP_SHADOW: float = 0.75
const KEEP_SCATTER: float = 0.4

var kit: Kit
# model name -> { range, far, shadow, chunks: { Vector2i: Array[Transform3D] }, colors }
var sets: Dictionary = {}
var count: int = 0


func _init(k: Kit) -> void:
	kit = k


func define(name: String, vis_range: float, shadow: bool, far: float = 0.0) -> void:
	if not sets.has(name):
		sets[name] = {"range": vis_range, "shadow": shadow, "far": far, "chunks": {}, "colors": {}}


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


# Low-poly version: the coarsest LOD meshoptimizer gives, as its own mesh.
func _far_mesh(name: String) -> ArrayMesh:
	var src: ArrayMesh = kit.mesh(name)
	var im: ImporterMesh = ImporterMesh.new()
	for s in src.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s), [], {}, src.surface_get_material(s), src.surface_get_name(s))
	im.generate_lods(60.0, 0.0, [])
	var out: ArrayMesh = ArrayMesh.new()
	for s in im.get_surface_count():
		var arr: Array = im.get_surface_arrays(s)
		var n: int = im.get_surface_lod_count(s)
		if n > 0:
			arr[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(s, n - 1)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, im.get_surface_material(s))
	return out


func _mmi(name: String, mesh: Mesh, arr: Array, cols: Array, key: Vector2i) -> MultiMeshInstance3D:
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
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return mmi


func commit(parent: Node3D) -> void:
	for name in sets.keys():
		var s: Dictionary = sets[name]
		var mesh: Mesh = kit.mesh(name)
		var far: float = s.far
		var far_mesh: Mesh = null
		if far > 0.0:
			far_mesh = _far_mesh(name)
		var colors_by_chunk: Dictionary = s.colors
		var vis_end: float = minf(far if far > 0.0 else float(s.range), MAX_RANGE)
		far = minf(far, MAX_FAR) if far > 0.0 else far
		var keep: float = KEEP_SHADOW if s.shadow else KEEP_SCATTER
		for key in (s.chunks as Dictionary).keys():
			var arr: Array = _thin(s.chunks[key], keep)
			var cols: Array = _thin(colors_by_chunk[key], keep)
			var near: MultiMeshInstance3D = _mmi(name, mesh, arr, cols, key)
			near.visibility_range_end = far if far > 0.0 else vis_end
			near.visibility_range_end_margin = 8.0
			if s.shadow and not OS.has_feature("mobile"):  # tree shadows re-draw the forest; too much for phones
				near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(near)
			if far_mesh != null:
				var fm: MultiMeshInstance3D = _mmi(name + "_far", far_mesh, arr, cols, key)
				fm.visibility_range_begin = far
				fm.visibility_range_begin_margin = 8.0
				fm.visibility_range_end = vis_end
				fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(fm)


# Keep a deterministic fraction of a chunk's instances (even stride, so coverage stays uniform).
func _thin(items: Array, keep: float) -> Array:
	if keep >= 1.0:
		return items
	var out: Array = []
	var acc: float = 0.0
	for it in items:
		acc += keep
		if acc >= 1.0:
			acc -= 1.0
			out.append(it)
	return out
