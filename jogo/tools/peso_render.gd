# Peso do desenho (anti-travamento 07/11): chamadas de desenho, objetos e triângulos em pontos com zumbi, na qualidade
# do celular (Média). Precisa de tela: xvfb-run ... --rendering-driver opengl3 -s res://tools/peso_render.gd [-- qualidade]
extends SceneTree

const PONTOS: Array = [Vector3(30, 422, -90), Vector3(-12, 330, 0), Vector3(-72, 81, 90), Vector3(150, 150, 45)]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	Config.v.qualidade = int(args[0]) if args.size() > 0 else 1
	main.iniciar_solo("Peso")
	for i in 60: await process_frame
	main.jogador.vida = 1000000000
	main.ciclo.tempo = 100.0
	Config.aplica(self)
	var soma := Vector3.ZERO
	for p: Vector3 in PONTOS:
		var q := Vector2(p.x, p.y)
		main.jogador.global_position = Bairro.ORIGEM + Vector3(q.x, main.bairro.altura(q) + 0.2, q.y)
		main.jogador.rotation.y = deg_to_rad(p.z)
		if main.jogador.camera:
			main.jogador.camera.virar(deg_to_rad(p.z), 0.0)
		for i in 90: await process_frame
		var v := Vector3(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		soma += v
		if OS.get_environment("QUEM") != "":
			_quem(main)
		print("RENDER ponto %s: %d chamadas, %d objetos, %d triângulos" % [str(q), v.x, v.y, v.z])
	print("RENDER média: %d chamadas, %d objetos, %d triângulos" % [soma.x / PONTOS.size(), soma.y / PONTOS.size(), soma.z / PONTOS.size()])
	quit()


static var _tris_cache := {}
static func _tris(m: Mesh) -> int:
	if m == null:
		return 0
	if not _tris_cache.has(m):
		var t := 0
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			t += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] else a[Mesh.ARRAY_VERTEX].size()) / 3
		_tris_cache[m] = t
	return _tris_cache[m]


# QUEM=1: triângulos (sem LOD) do que está na frente da câmera, por dono (pai mais alto abaixo do Bairro/main)
func _quem(main: Node) -> void:
	var cam := root.get_camera_3d()
	var por := {}
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		if not g.is_visible_in_tree():
			continue
		var d: float = g.global_position.distance_to(cam.global_position)
		if (g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin) or d > cam.far + 200:
			continue
		var t := 0
		if g is MeshInstance3D:
			t = _tris((g as MeshInstance3D).mesh)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			var mm := (g as MultiMeshInstance3D).multimesh
			t = _tris(mm.mesh) * (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
		var aabb: AABB = g.global_transform * g.get_aabb()
		if not cam.is_position_in_frustum(aabb.get_center()) and aabb.size.length() < 60.0:
			continue
		var n: Node = g
		while n.get_parent() and n.get_parent() != main and n.get_parent() != main.bairro and n.get_parent() != root:
			n = n.get_parent()
		var k: String = String(n.name).rstrip("0123456789_")
		por[k] = por.get(k, 0) + t
	var ks := por.keys()
	ks.sort_custom(func(a, b): return por[a] > por[b])
	for k in ks.slice(0, 14):
		print("RENDER   quem %s: %d triângulos" % [k, por[k]])
