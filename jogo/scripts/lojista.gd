# Lojista (mecânica 8 do loop): vendedor parado numa barraca. Compra qualquer item (menos o facão) e vende
# munição, comida e água. Preços provisórios, em dinheiro do jogo (nada com dinheiro real).
class_name Lojista
extends Node3D

const ALCANCE: float = 2.4
## o que ele vende: tipo -> [quantidade por compra, preço]
const VENDE: Dictionary = {"municao": [12, 30], "comida": [1, 15], "agua": [1, 10]}
## quanto ele paga por unidade
const PAGA: Dictionary = {"municao": 1, "comida": 5, "agua": 3, "lanterna": 25, "faca": 20, "taco": 30, "machado": 60,
	"pistola": 120, "smg": 400, "mola": 4, "gatilho": 6, "cano": 12, "cabo": 12, "ferrolho": 40, "carregador": 40,
	"receita_pistola": 50, "receita_smg": 200}

var _anim: AnimationPlayer
## loja da facção (dentro da mansão): só o balcão com as caixas, sem vendedor; só membros da dona compram
var so_balcao: bool = false


func _ready() -> void:
	add_to_group("lojista")
	_monta()


func perto(pos: Vector3) -> bool:
	return Vector2(global_position.x - pos.x, global_position.z - pos.z).length() < ALCANCE


## Quanto paga por `n` unidades de `tipo` (0 = não compra isso).
static func paga(tipo: String, n: int) -> int:
	return int(PAGA.get(tipo, 0)) * n


## Valor de uma lista de itens ({tipo, qtd}) pelo que o lojista paga (raid do resgate usa).
static func valor(itens: Array) -> int:
	var v: int = 0
	for e: Dictionary in itens:
		v += paga(String(e.tipo), int(e.qtd))
	return v


# barraca: bancada de caixotes com lona por cima e o vendedor atrás, parado
func _monta() -> void:
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.45, 0.33, 0.2)
	madeira.roughness = 0.9
	var lona := StandardMaterial3D.new()
	lona.albedo_color = Color(0.3, 0.36, 0.28)
	lona.roughness = 1.0
	lona.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bloco(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.6), madeira)  # balcão de caixotes
	for x in [-0.95, 0.95]:
		_bloco(Vector3(x, 1.2, -0.55), Vector3(0.06, 2.4, 0.06), madeira)  # postes
	_bloco(Vector3(0, 2.38, -0.4), Vector3(2.3, 0.04, 1.4), lona).rotation_degrees.x = 8.0  # lona
	var oliva := StandardMaterial3D.new()
	oliva.albedo_color = Color(0.29, 0.33, 0.2)  # caixa de munição à mostra
	var lata := StandardMaterial3D.new()
	lata.albedo_color = Color(0.55, 0.53, 0.48)
	lata.metallic = 0.6
	_bloco(Vector3(-0.5, 0.97, 0.05), Vector3(0.3, 0.14, 0.14), oliva)
	_bloco(Vector3(0.45, 0.96, 0.0), Vector3(0.1, 0.12, 0.1), lata)
	var corpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.0, 0.9, 0.6)
	cs.shape = b
	cs.position.y = 0.45
	corpo.add_child(cs)
	add_child(corpo)
	# o vendedor: o mesmo boneco dos jogadores, parado atrás do balcão
	if so_balcao:
		return
	var vendedor := Anims.boneco(Anims.JOGADOR)
	vendedor.position = Vector3(0, 0, -0.75)
	add_child(vendedor)
	if not Rede.servidor_sem_tela:
		_anim = AnimationPlayer.new()
		vendedor.add_child(_anim)
		_anim.root_node = NodePath("..")
		_anim.add_animation_library("", Anims.adaptada(Anims.biblioteca(), Anims.JOGADOR))
		_anim.play("parado")


func _bloco(p: Vector3, tam: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	add_child(mi)
	return mi
