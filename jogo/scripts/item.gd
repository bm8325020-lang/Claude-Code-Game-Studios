# Item largado no chão (mecânica 11): caixa de munição ou lanterna. Fica parado no chão, sem brilho nem giro;
# quem chega perto vê o botão PEGAR. Quem decide se pegou é o servidor (ou o aparelho jogando sozinho):
# o item some para todos e volta no mesmo lugar depois de VOLTA segundos (provisório, para testar).
# Os itens fazem parte do mapa (mesmo nome em todos os aparelhos); só o "ativo" vai pela rede.
class_name Item
extends Node3D

const ALCANCE: float = 1.6   # m: perto assim aparece o PEGAR
const VOLTA: float = 60.0

## "municao" ou "lanterna"
@export var tipo: String = "municao"
@export var quantidade: int = 24
## false = já pegaram (escondido até voltar)
var ativo: bool = true:
	set(v):
		ativo = v
		visible = v
var _volta_t: float = 0.0
## Largado por alguém (não faz parte do mapa): some ao ser pego ou depois de SOME segundos.
var solto: bool = false
const SOME: float = 600.0
var _some_t: float = SOME


## Só o desenho (ícone da mochila): sem grupo nem rede.
var so_visual: bool = false


func _ready() -> void:
	_monta_modelo()
	if so_visual:
		return
	add_to_group("itens")
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:ativo"))
	cfg.property_set_replication_mode(NodePath(".:ativo"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_config = cfg
	add_child(sync)


## Nome para o botão ("munição (24)", "lanterna").
func nome() -> String:
	match tipo:
		"municao":
			return "munição (%d)" % quantidade
		"comida":
			return "lata de comida"
		"antibiotico":
			return "antibiótico" + (" (%d)" % quantidade if quantidade > 1 else "")
		"agua":
			return "garrafa de água"
		"facao", "pistola", "faca", "taco", "machado", "mola", "gatilho", "cano", "cabo", "ferrolho", "carregador", "receita_pistola", "smg", "receita_smg":
			return Mochila.NOMES[tipo].to_lower() + (" (%d)" % quantidade if quantidade > 1 else "")
	return "lanterna"


## O item ativo mais perto de `pos` a até ALCANCE, ou null.
static func perto(arvore: SceneTree, pos: Vector3) -> Item:
	var melhor: Item = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("itens"):
		var it := n as Item
		var d: float = it.global_position.distance_to(pos)
		if it.ativo and d < dist:
			dist = d
			melhor = it
	return melhor


## Servidor: `j` quer pegar este item. Confere e entrega. Retorna se pegou.
func pegar_por(j: Jogador) -> bool:
	if not ativo or j.vida <= 0 or j.global_position.distance_to(global_position) > ALCANCE + 0.6:
		return false
	if tipo == "lanterna" and j.tem_lanterna:
		return false
	if (tipo == "comida" and j.comida >= Jogador.COMIDA_MAX) or (tipo == "agua" and j.agua >= Jogador.COMIDA_MAX):
		return false  # mochila cheia disso
	ativo = false
	_volta_t = VOLTA
	j.ganhar(tipo, quantidade)
	if solto:
		queue_free()  # o spawner tira dos outros aparelhos
	return true


func _process(dt: float) -> void:
	if solto:
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			_some_t -= dt
			if _some_t <= 0.0:
				queue_free()
		return
	if not ativo and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_volta_t -= dt
		if _volta_t <= 0.0:
			ativo = true


func _monta_modelo() -> void:
	if tipo == "municao":
		# caixa de munição de lata, verde-oliva, com tampa
		var lata := StandardMaterial3D.new()
		lata.albedo_color = Color(0.29, 0.33, 0.2)
		lata.roughness = 0.6
		lata.metallic = 0.3
		_bloco(Vector3(0, 0.07, 0), Vector3(0.3, 0.14, 0.14), lata)
		var tampa := StandardMaterial3D.new()
		tampa.albedo_color = Color(0.24, 0.27, 0.16)
		_bloco(Vector3(0, 0.145, 0), Vector3(0.31, 0.012, 0.15), tampa)
		var alca := StandardMaterial3D.new()
		alca.albedo_color = Color(0.1, 0.1, 0.1)
		_bloco(Vector3(0, 0.158, 0), Vector3(0.12, 0.012, 0.025), alca)

	elif tipo in Loot.PECAS:
		_monta_peca()
	elif tipo.begins_with("receita_"):
		# folha dobrada com o desenho da arma (papel envelhecido e o traço azul da planta)
		var papel := StandardMaterial3D.new()
		papel.albedo_color = Color(0.82, 0.78, 0.66)
		papel.roughness = 1.0
		var traco := StandardMaterial3D.new()
		traco.albedo_color = Color(0.2, 0.3, 0.5)
		_bloco(Vector3(0, 0.002, 0), Vector3(0.21, 0.004, 0.15), papel).rotation_degrees.y = 12.0
		_bloco(Vector3(0.01, 0.005, 0.01), Vector3(0.12, 0.002, 0.05), traco).rotation_degrees.y = 12.0
	elif Armas.e_branca(tipo):
		var pega: Node3D = Armas.modelo(tipo)
		pega.rotation_degrees = Vector3(0, 0, 90)  # deitada de lado no chão
		pega.position = Vector3(0, 0.04, -float(Armas.BRANCAS[tipo].tam) * 0.35)
		add_child(pega)
	elif tipo == "smg":
		_modelo("res://assets/sketchfab/smg.glb", 0.6, Vector3(0, 0, 90))
	elif tipo == "pistola":
		_modelo("res://assets/cgtrader/pistola.glb", 0.2, Vector3(0, 0, 90), "Pistola")
	elif tipo == "comida":
		_modelo("res://assets/sketchfab/lata_comida.glb", 0.12, Vector3.ZERO, "alta")  # o arquivo tem 4 latas
	elif tipo == "agua":
		_modelo("res://assets/sketchfab/garrafa_agua.glb", 0.24, Vector3(0, 0, 90))  # deitada
	elif tipo == "antibiotico":
		_monta_remedio()
	elif tipo == "chave":  # chave velha de latão: argola, haste e dente
		var latao := StandardMaterial3D.new()
		latao.albedo_color = Color(0.72, 0.58, 0.25)
		latao.metallic = 0.8
		latao.roughness = 0.35
		_bloco(Vector3(-0.035, 0.005, 0), Vector3(0.03, 0.008, 0.03), latao)
		_bloco(Vector3(0.01, 0.005, 0), Vector3(0.07, 0.006, 0.01), latao)
		_bloco(Vector3(0.04, 0.005, 0.01), Vector3(0.012, 0.006, 0.02), latao)
	else:
		_modelo("res://assets/sketchfab/lanterna.glb", 0.2, Vector3.ZERO)


# frasco de remédio laranja meio transparente com tampa branca e rótulo
func _monta_remedio() -> void:
	var frasco := StandardMaterial3D.new()
	frasco.albedo_color = Color(0.85, 0.45, 0.1, 0.8)
	frasco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frasco.roughness = 0.25
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color(0.93, 0.93, 0.9)
	for parte: Array in [[0.03, 0.09, 0.045, frasco], [0.032, 0.025, 0.1, branco], [0.0305, 0.04, 0.04, branco]]:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = parte[0]
		c.bottom_radius = parte[0]
		c.height = parte[1]
		mi.mesh = c
		mi.material_override = parte[3]
		mi.position.y = parte[2]
		add_child(mi)


## Põe um modelo do Sketchfab com o lado maior medindo `tam` m, apoiado no chão e centrado.
## `so`: fica só com as malhas cujo nome tem esse pedaço (arquivos que trazem vários objetos).
func _modelo(caminho: String, tam: float, giro: Vector3, so: String = "") -> void:
	var m := (load(caminho) as PackedScene).instantiate() as Node3D
	m.rotation_degrees = giro
	add_child(m)
	var caixa := AABB()
	var primeiro := true
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		if so != "" and not (mi as MeshInstance3D).mesh.resource_name.containsn(so):
			mi.free()
			continue
		var c: AABB = (m.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		caixa = c if primeiro else caixa.merge(c)
		primeiro = false
	var k: float = tam / maxf(caixa.size[caixa.get_longest_axis_index()], 0.001)
	m.scale = Vector3.ONE * k
	var giro_b: Basis = Basis.from_euler(giro * PI / 180.0)
	var baixo: float = INF
	for i in 8:
		baixo = minf(baixo, (giro_b * caixa.get_endpoint(i)).y)
	var meio: Vector3 = giro_b * caixa.get_center() * k
	m.position = Vector3(-meio.x, -baixo * k, -meio.z)


# peças de arma: metal oxidado ou polímero preto, deitadas no chão
func _monta_peca() -> void:
	var aco := StandardMaterial3D.new()
	aco.albedo_color = Color(0.32, 0.32, 0.33)
	aco.metallic = 0.5
	aco.roughness = 0.45
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color(0.08, 0.08, 0.09)
	preto.roughness = 0.7
	match tipo:
		"mola":
			for k in 7:  # espiras
				var mi := MeshInstance3D.new()
				var t := TorusMesh.new()
				t.inner_radius = 0.008
				t.outer_radius = 0.012
				mi.mesh = t
				mi.material_override = aco
				mi.rotation_degrees.z = 90
				mi.position = Vector3(-0.024 + k * 0.008, 0.012, 0)
				add_child(mi)
		"gatilho":
			_bloco(Vector3(0, 0.006, 0), Vector3(0.03, 0.012, 0.012), preto)
			_bloco(Vector3(0.008, 0.018, 0), Vector3(0.008, 0.026, 0.01), preto).rotation_degrees.z = -18.0
		"cano":
			var mi := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.009
			c.bottom_radius = 0.009
			c.height = 0.11
			mi.mesh = c
			mi.material_override = aco
			mi.rotation_degrees.z = 90
			mi.position.y = 0.009
			add_child(mi)
		"cabo":
			_bloco(Vector3(0, 0.014, 0), Vector3(0.032, 0.028, 0.1), preto).rotation_degrees.y = 8.0
		"ferrolho":
			_bloco(Vector3(0, 0.014, 0), Vector3(0.16, 0.028, 0.03), aco)
			_bloco(Vector3(0.02, 0.029, 0), Vector3(0.05, 0.004, 0.02), preto)  # janela de ejeção
		"carregador":
			_bloco(Vector3(0, 0.011, 0), Vector3(0.025, 0.022, 0.11), preto)
			_bloco(Vector3(0, 0.011, -0.058), Vector3(0.028, 0.024, 0.008), aco)  # base


func _bloco(p: Vector3, tam: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = m
	mi.position = p
	add_child(mi)
	return mi
