# Bot caçador de bugs (06/11, dono): roda o jogo de verdade e procura
#  1) coisas flutuando ou enterradas (árvores, enfeites, carros) comparando com o chão de verdade (raio para baixo);
#  2) carro torto (inclinado demais para o chão) ou sem as 4 rodas;
#  3) lugares onde o jogador fica PRESO: anda por rotas da malha de navegação e anota onde parou sem chegar.
# Rodar com tela (para os enfeites existirem):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/bot_bugs.gd -- pasta [rotas]
# Saída: pasta/relatorio.txt e pasta/preso_k.png / flutua_k.png (fotos dos piores).
extends SceneTree

var main: Node3D
var j: Jogador
var saida: String
var linhas: PackedStringArray = []
var fotos: int = 0


func log_(t: String) -> void:
	print(t)
	linhas.append(t)
	var f := FileAccess.open(saida + "/relatorio.txt", FileAccess.WRITE)  # grava sempre: se o tempo acabar, fica o que deu
	if f:
		f.store_string("\n".join(linhas))


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else "user://bugs"
	var rotas: int = int(args[1]) if args.size() > 1 else 30
	DirAccess.make_dir_recursive_absolute(saida)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	main.iniciar_solo("BotBugs")
	await frames(120)
	j = main.jogador
	j.vida = 1000000
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	for z in main.zumbis.get_children():
		z.queue_free()  # o bot só procura bug do mundo
	Zumbi.ronda_ligada = false
	await frames(5)
	_flutuando()
	_carros()
	await _rotas(rotas)
	var f := FileAccess.open(saida + "/relatorio.txt", FileAccess.WRITE)
	f.store_string("\n".join(linhas))
	quit()


func _chao(p: Vector3, ignora: Array = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.5, 0), p - Vector3(0, 6.0, 0), 1)
	q.exclude = ignora
	return root.get_world_3d().direct_space_state.intersect_ray(q)


# --- 1) flutuando / enterrado
func _flutuando() -> void:
	var ruins: Array = []
	var vistos: int = 0
	for mm: MultiMeshInstance3D in main.find_children("Lote_*", "MultiMeshInstance3D", true, false):
		var m: MultiMesh = mm.multimesh
		if m == null or String(mm.name).contains("Longe_"):
			continue
		var nome: String = String(mm.name).trim_prefix("Lote_").get_slice("_", 0) + "_" + String(mm.name).trim_prefix("Lote_").get_slice("_", 1)
		for k in m.instance_count:
			var t: Transform3D = mm.global_transform * m.get_instance_transform(k)
			var base: Vector3 = t * m.mesh.get_aabb().position
			base = Vector3(t.origin.x, minf(base.y, t.origin.y), t.origin.z)
			if nome.contains("trafo") or nome.begins_with("mancha") or nome.begins_with("fio"):
				continue  # transformador fica no alto do poste; mancha é decalque no chão
			vistos += 1
			# chão = o mais alto entre o terreno e o que tiver logo abaixo (calçada, varanda), sem pegar telhado
			var terreno: float = main.bairro.altura(Vector2(t.origin.x, t.origin.z)) if main.bairro else 0.0
			var q := PhysicsRayQueryParameters3D.create(t.origin + Vector3(0, 0.6, 0), t.origin - Vector3(0, 3.0, 0), 1)
			var h: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
			var chao: float = maxf(terreno, (h.position as Vector3).y) if not h.is_empty() else terreno
			var dif: float = base.y - chao
			if base.y < terreno - 0.6:
				dif = base.y - terreno
			if dif > 0.35 or dif < -0.6:
				ruins.append([absf(dif), nome, t.origin, dif])
	ruins.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var por: Dictionary = {}
	for r: Array in ruins:
		por[r[1]] = int(por.get(r[1], 0)) + 1
	log_("== FLUTUANDO / ENTERRADO: %d de %d enfeites e árvores" % [ruins.size(), vistos])
	log_("   por tipo: " + str(por))
	for r: Array in ruins.slice(0, 25):
		log_("   %s em (%.0f, %.0f, %.0f): %s %.2f m" % [r[1], r[2].x, r[2].y, r[2].z, "FLUTUA" if r[3] > 0 else "ENTERRADO", absf(r[3])])


# --- 2) carros
func _carros() -> void:
	var tortos: int = 0
	var flutua: int = 0
	var sem_roda: int = 0
	var n: int = 0
	for c: Node in get_nodes_in_group("carros"):
		var car := c as Carro
		if car == null:
			continue
		n += 1
		var h: Dictionary = _chao(car.global_position, [car.get_rid()])
		if not h.is_empty():
			var ang: float = rad_to_deg(car.global_basis.y.normalized().angle_to(h.normal))
			var dif: float = car.global_position.y - (h.position as Vector3).y
			if ang > 12.0:
				tortos += 1
				log_("   carro %s TORTO %.0f° em (%.0f, %.0f)" % [car.name, ang, car.global_position.x, car.global_position.z])
			if dif > 0.6:
				flutua += 1
				log_("   carro %s FLUTUANDO %.2f m em (%.0f, %.0f)" % [car.name, dif, car.global_position.x, car.global_position.z])
		if car._rodas.size() < 4:
			sem_roda += 1
	log_("== CARROS: %d; tortos %d, flutuando %d, sem as 4 rodas achadas %d" % [n, tortos, flutua, sem_roda])


# --- 3) preso andando
func _rotas(n: int) -> void:
	var mapa: RID = root.get_world_3d().navigation_map
	var presos: Array = []
	var feitas: int = 0
	log_("== ROTAS A PÉ: %d" % n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for r in n:
		var de: Vector3 = NavigationServer3D.map_get_random_point(mapa, 1, true)
		var ate: Vector3 = NavigationServer3D.map_get_random_point(mapa, 1, true)
		if de.distance_to(ate) < 25.0 or de.distance_to(ate) > 70.0:
			ate = NavigationServer3D.map_get_closest_point(mapa, de + Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45)))
		var cam: PackedVector3Array = NavigationServer3D.map_get_path(mapa, de, ate, true)
		if cam.size() < 2:
			continue
		feitas += 1
		j.global_position = de + Vector3(0, 0.3, 0)
		j.velocity = Vector3.ZERO
		await frames(10)
		var i: int = 1
		var parado_t: float = 0.0
		var ult: Vector3 = j.global_position
		var t: float = 0.0
		for z in main.zumbis.get_children():
			z.queue_free()  # a população põe zumbis de novo: o bot só quer o mundo
		while i < cam.size() and t < 15.0:
			var alvo: Vector3 = cam[i]
			var d: Vector3 = alvo - j.global_position
			d.y = 0.0
			if d.length() < 0.6:
				i += 1
				continue
			var yaw: float = atan2(-d.x, -d.z)
			if j.camera:
				j.camera.yaw = yaw
				j.camera.set("_yaw_alvo", yaw)
			j.entrada["move"] = Vector2(0, 1)
			await frames(6)
			t += 0.1
			parado_t = parado_t + 0.1 if j.global_position.distance_to(ult) < 0.12 else 0.0
			ult = j.global_position
			if parado_t > 2.0:
				presos.append([j.global_position, alvo, _quem_trava(j.global_position, d)])
				j.global_position = alvo + Vector3(0, 0.3, 0)  # pula o trecho e segue
				parado_t = 0.0
				i += 1
		j.entrada["move"] = Vector2.ZERO
	log_("   rotas feitas %d, travou %d vezes" % [feitas, presos.size()])
	for p: Array in presos:
		log_("   PRESO em (%.1f, %.1f, %.1f) indo para (%.0f, %.0f): %s" % [p[0].x, p[0].y, p[0].z, p[1].x, p[1].z, p[2]])
	for k in mini(presos.size(), 6):
		await _foto(presos[k][0], "preso_%d" % k)


## O que está na frente travando (nome do nó da colisão).
func _quem_trava(p: Vector3, d: Vector3) -> String:
	var esp := root.get_world_3d().direct_space_state
	var nomes: PackedStringArray = []
	for alt: float in [0.25, 0.9, 1.5]:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, alt, 0), p + Vector3(0, alt, 0) + d.normalized() * 1.2, 1 | 16)
		q.exclude = [j.get_rid()]
		var h: Dictionary = esp.intersect_ray(q)
		if not h.is_empty():
			var c: Node = h.collider
			nomes.append("%.2fm:%s" % [alt, String(c.get_parent().name) + "/" + String(c.name)])
	return ", ".join(nomes) if not nomes.is_empty() else "nada na frente (degrau/buraco?)"


func _foto(p: Vector3, nome: String) -> void:
	j.global_position = p + Vector3(0, 0.3, 0)
	await frames(20)
	root.get_viewport().get_texture().get_image().save_png(saida + "/" + nome + ".png")
