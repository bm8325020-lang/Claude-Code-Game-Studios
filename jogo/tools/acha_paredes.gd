# Caça parede invisível (06/11, dono: "colisão do item grande demais, meio que uma parede invisível"): monta a cidade,
# pega toda colisão parada na altura do corpo e vê quanto ela sobra para fora do que está desenhado ali.
# Imprime as piores (nome, lugar, quanto sobra). Rodar: godot --headless --path . -s res://tools/acha_paredes.gd [-- 0.5]
extends SceneTree

const CEL: float = 8.0


func _init() -> void:
	var folga: float = 0.5
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_float():
			folga = float(a)
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	main.iniciar_solo("Teste")
	for i in 30:
		await physics_frame
	# o que se vê, numa grade de 8 m
	var grade: Dictionary = {}
	var nv: int = 0
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		if not g.is_visible_in_tree() or g is Label3D or g is GPUParticles3D or g is CPUParticles3D:
			continue
		var caixas: Array[AABB] = []
		var nome_g: String = String(g.name)
		if g is MultiMeshInstance3D:
			var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var ma: AABB = mm.mesh.get_aabb()
			for k in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
				caixas.append(g.global_transform * mm.get_instance_transform(k) * ma)
		else:
			caixas.append(g.global_transform * g.get_aabb())
		for b: AABB in caixas:
			if b.size.length() > 300.0:
				continue  # chão/terreno/malha junta gigante: não ajuda a medir
			nv += 1
			for cx in range(floori(b.position.x / CEL), floori(b.end.x / CEL) + 1):
				for cz in range(floori(b.position.z / CEL), floori(b.end.z / CEL) + 1):
					var ch := Vector2i(cx, cz)
					if not grade.has(ch):
						grade[ch] = []
					grade[ch].append([b, nome_g])
	var ruins: Array = []
	var nc: int = 0
	for c: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		if c.disabled or c.shape == null or not (c.get_parent() is StaticBody3D or c.get_parent() is AnimatableBody3D):
			continue
		if (c.get_parent() as CollisionObject3D).collision_layer & 1 == 0:
			continue
		var dm: ArrayMesh = c.shape.get_debug_mesh()
		if dm == null:
			continue
		var w: AABB = c.global_transform * dm.get_aabb()
		if w.size.length() > 120.0 or w.size.y < 0.3:
			continue  # prédio inteiro / chão: fora
		nc += 1
		# parte da caixa na altura do corpo, comparada com o desenho que encosta nela
		var vis := AABB()
		var perto: String = "-"
		var tem: bool = false
		var ch := Vector2i(floori(w.get_center().x / CEL), floori(w.get_center().z / CEL))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for par: Array in grade.get(ch + Vector2i(dx, dz), []):
					var b: AABB = par[0]
					if b.grow(0.05).intersects(w) and b.size.length() < maxf(6.0, w.size.length() * 2.5):  # prédio inteiro não "cobre" móvel
						vis = b if not tem else vis.merge(b)
						tem = true
						perto = par[1]
		var sobra: float
		if not tem:
			sobra = maxf(w.size.x, w.size.z)
		else:
			sobra = maxf(maxf(vis.position.x - w.position.x, w.end.x - vis.end.x), maxf(vis.position.z - w.position.z, w.end.z - vis.end.z))
		if sobra > folga:
			if String(c.get_parent().name).begins_with("@"):  # só o que foi feito em código (caixa); "-col" do Blender = a própria malha
				ruins.append([sobra, String(main.get_path_to(c.get_parent())) + " ~" + perto, w])
	ruins.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("visuais %d, colisões %d, suspeitas %d" % [nv, nc, ruins.size()])
	var por_nome: Dictionary = {}
	for r: Array in ruins:
		var chave: String = String(r[1]).get_slice("~", 1).rstrip("0123456789_-")
		por_nome[chave] = int(por_nome.get(chave, 0)) + 1
	print("por tipo: ", por_nome)
	for r: Array in ruins.filter(func(x: Array) -> bool: return not (absf((x[2] as AABB).size.y - 3.0) < 0.05 and (x[2] as AABB).size.x < 1.3)).slice(0, 80):
		print("%.1f m  %s  em %s  tam %s" % [r[0], r[1], (r[2] as AABB).get_center().snapped(Vector3.ONE * 0.1), (r[2] as AABB).size.snapped(Vector3.ONE * 0.1)])
	quit()
