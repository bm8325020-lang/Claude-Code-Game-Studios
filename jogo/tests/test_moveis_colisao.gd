# Parede invisível dos móveis (06/11, dono: "a colisão do item é grande demais"): o modelo pronto entra no lugar da caixa
# do Blender, mas cabe nela só num eixo; a colisão tem que virar a do modelo (não sobrar mais que uns cm em volta).
# Rodar: godot --headless --path . --fixed-fps 60 -s res://tests/test_moveis_colisao.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, o_que: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", o_que)


func _init() -> void:
	Rede.servidor_sem_tela = false  # o teste é sem tela, mas aqui queremos os modelos
	var trocados: int = 0
	var sobra_max: float = 0.0
	var velhas_ligadas: int = 0
	var com_corpo: int = 0
	for nome: String in ["casa_r1", "casa_r5", "casa_r11", "casa_r2"]:
		var casa: Node3D = (load(Bairro.RUINAS % nome) as PackedScene).instantiate()
		root.add_child(casa)
		trocados += Moveis.troca(casa)
		for sup: Node3D in casa.find_children("Real_*", "Node3D", true, false):
			var mi: MeshInstance3D = sup.get_parent().get_node_or_null(String(sup.name).substr(5))
			if mi == null:
				continue
			var irma: Node = mi.get_parent().get_node_or_null(String(mi.name) + "_c")
			for c: CollisionShape3D in mi.find_children("*", "CollisionShape3D", true, false) + (irma.find_children("*", "CollisionShape3D", true, false) if irma else []):
				if not c.disabled:
					velhas_ligadas += 1
			var corpo: StaticBody3D = null
			for f in sup.get_children():
				if f is StaticBody3D:
					corpo = f
			if corpo == null:
				continue  # quadro na parede / móvel sem colisão
			var forma: BoxShape3D = (corpo.get_child(0) as CollisionShape3D).shape
			com_corpo += 1
			var modelo: Node3D = null
			for f in sup.get_children():
				if not (f is StaticBody3D):
					modelo = f
			var vis: AABB = Moveis._aabb(modelo)
			vis = AABB(vis.position * modelo.scale + modelo.position, vis.size * modelo.scale)
			sobra_max = maxf(sobra_max, maxf(forma.size.x - vis.size.x, forma.size.z - vis.size.z))
		casa.free()
	ok(trocados > 5, "trocou móveis (%d)" % trocados)
	ok(velhas_ligadas == 0, "colisão da caixa velha desligada (%d ligadas)" % velhas_ligadas)
	ok(com_corpo > 5, "móveis com colisão nova (%d)" % com_corpo)
	ok(sobra_max <= 0.01, "colisão não sobra do modelo (%.2f m)" % sobra_max)
	print("%s: %d/%d" % ["PASS" if falhas == 0 else "FAIL", checks - falhas, checks])
	quit(1 if falhas else 0)
