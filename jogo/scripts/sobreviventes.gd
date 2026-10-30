# Rastros de quem tentou sobreviver (plano aprovado pelo dono, 30/10): REFÚGIOS (casas com barricada de entulho na
# frente, com arame farpado que corta e prende quem encosta), PICHAÇÕES nas fachadas e BILHETES largados no chão
# (chegou perto, lê; alguns dão dica de onde tem coisa boa). Tudo determinístico pelo nome (igual em todo aparelho).
class_name Sobreviventes
extends Node3D

const N_REFUGIOS: int = 6
const PICHACOES: Array[String] = ["NÃO ENTRE", "TEM ZUMBI", "SOCORRO", "FOMOS PRO NORTE", "MORTOS LÁ DENTRO",
	"3 VIVOS AQUI", "SEM ÁGUA", "DEUS NOS ABANDONOU", "NÃO ABRA", "INFECTADOS", "MARIA ESTÁ NO MORRO", "ATIRAMOS EM QUEM CHEGA",
	"NÃO SAIA À NOITE", "EVACUAÇÃO CANCELADA"]
## bilhetes (texto curto e crível, sem cara de jogo); os com {raid} apontam a delegacia
const BILHETES: Array[String] = [
	"Dia 12. Acabou a comida. Vou tentar a delegacia, dizem que tem arma lá. Se eu não voltar, não venham atrás.",
	"Eles não sobem escada direito. Fiquem nos telhados.",
	"A Júlia foi mordida no braço. Ela disse que tá bem. Não está.",
	"O rádio parou de falar ontem. Ninguém vem buscar a gente.",
	"Tranquei a porta dos fundos com a geladeira. À noite eles ficam rápidos demais.",
	"Se você achar isso: tem antibiótico no arsenal da delegacia. Cuidado com os policiais. Eles atiram.",
	"Quem passa pelo rio fica lento. Eles também. Não fique no meio da água.",
	"Escutei tiro perto da caixa d'água. Pode ter gente viva. Ou pode ser isca.",
	"Pai, fui pra casa da tia Rosa. Não espera. Te amo.",
	"Os do uniforme amarelo aguentam mais bala. Mira na cabeça.",
	"Não durma na rua. Achei uma cama inteira numa das casas grandes.",
	"Fiz barricada com o sofá. Aguentou duas noites. Não sei se aguenta a terceira.",
]
const ARAME_DANO: int = 3
const ARAME_A_CADA: float = 0.5  # s

var _b: Bairro
var _rng := RandomNumberGenerator.new()


func monta(b: Bairro) -> void:
	_b = b
	_rng.seed = 777
	var casas: Array = b.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Casa_") and n.has_meta("frente") and n.has_meta("modelo"))
	casas.sort_custom(func(x: Node, y: Node) -> bool: return hash(String(x.name)) < hash(String(y.name)))
	for k in mini(N_REFUGIOS, casas.size()):
		_refugio(casas[k])
	# casas queimadas não: a parede da frente caiu e a pichação ficaria no ar
	var fachadas: Array = b.get_children().filter(func(n: Node) -> bool: return n.has_meta("poly") and n.has_meta("frente") and n.get_meta("modelo", "") not in ["casa_r4", "casa_r6"])
	for k in fachadas.size():
		if hash(String(fachadas[k].name) + "pixo") % 4 == 0:
			_picha(fachadas[k], PICHACOES[k % PICHACOES.size()])
	if b.has_node("Delegacia"):
		_picha(b.get_node("Delegacia"), "NÃO ENTRE — POLÍCIA MORTA")
	var n: int = 0
	for c: Node3D in casas.slice(N_REFUGIOS):
		if n >= BILHETES.size():
			break
		if hash(String(c.name) + "bilhete") % 3 == 0:
			_bilhete(c, BILHETES[n])
			n += 1
	for k in mini(N_REFUGIOS, casas.size()):  # todo refúgio tem um bilhete de quem ficou lá
		if n < BILHETES.size():
			_bilhete(casas[k], BILHETES[n])
			n += 1


## Casa vira refúgio: barricada de entulho na frente (deixa um vão na ponta) com arame farpado.
func _refugio(casa: Node3D) -> void:
	var frente: Vector3 = (casa.get_meta("frente") as Vector3) - Bairro.ORIGEM
	var c: Vector2 = _b._centro(casa.get_meta("poly"))
	var fora := Vector2(frente.x - c.x, frente.z - c.y).normalized()
	var lado := Vector2(fora.y, -fora.x)
	var p: Vector2 = Vector2(frente.x, frente.z) + lado * 1.6 - fora * 0.5
	var bar: Node3D = (load(Bairro.RUINAS % "barricada_sobr") as PackedScene).instantiate()
	bar.name = "Refugio_" + casa.name
	bar.position = Vector3(p.x, _b.altura(p), p.y)
	bar.rotation.y = atan2(fora.x, fora.y)  # frente do modelo (+Z) para a rua
	add_child(bar)
	_b._pinta(bar, Color(0.75, 0.72, 0.66))
	casa.set_meta("refugio", true)
	var arame := Arame.new()
	arame.name = "Arame"
	arame.position = Vector3(-0.5, 0.5, 1.4)
	bar.add_child(arame)


func _picha(no: Node3D, texto: String) -> void:
	var poly: PackedVector2Array = no.get_meta("poly")
	var frente: Vector3 = (no.get_meta("frente") as Vector3) - Bairro.ORIGEM
	var c: Vector2 = _b._centro(poly)
	var fora := Vector2(frente.x - c.x, frente.z - c.y).normalized()
	# ponto da parede da frente: do centro até a borda do lote na direção da rua
	var borda: Variant = _b._corta_borda(c, c + fora * 40.0, poly)
	if borda == null:
		return
	var lado := Vector2(fora.y, -fora.x)
	var p: Vector2 = (borda as Vector2) + fora * 0.16 + lado * _rng.randf_range(-2.0, 2.0)
	var l := Label3D.new()
	l.text = texto
	l.font = load("res://assets/fontes/BebasNeue-Regular.ttf")
	l.font_size = 110
	l.pixel_size = 0.006
	l.outline_size = 0
	l.modulate = [Color(0.7, 0.08, 0.06, 0.88), Color(0.85, 0.83, 0.78, 0.82), Color(0.08, 0.08, 0.08, 0.85)][_rng.randi() % 3]
	l.shaded = true
	l.double_sided = false
	l.position = Vector3(p.x, _b.altura(p) + _rng.randf_range(1.5, 2.3), p.y)
	l.rotation = Vector3(0, atan2(fora.x, fora.y), _rng.randf_range(-0.08, 0.08))
	l.visibility_range_end = 60.0
	add_child(l)


func _bilhete(casa: Node3D, texto: String) -> void:
	var dentro: Vector3 = _b.dentro_da(String(casa.name)) - Bairro.ORIGEM
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.21, 0.29)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.84, 0.76)
	mi.material_override = m
	mi.name = "Bilhete_" + casa.name
	mi.position = dentro + Vector3(_rng.randf_range(-0.6, 0.6), 0.075, _rng.randf_range(-0.6, 0.6))
	mi.rotation.y = _rng.randf() * TAU
	mi.set_meta("texto", texto)
	mi.add_to_group("bilhetes")
	add_child(mi)


## Arame farpado: quem encosta leva corte e fica preso um instante (cada aparelho cuida do seu jogador).
class Arame extends Area3D:
	var _t: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2 | 8  # jogador e zumbi
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(4.8, 1.0, 0.9)
		cs.shape = bx
		add_child(cs)

	func _physics_process(dt: float) -> void:
		_t -= dt
		if _t > 0.0:
			return
		for c: Node3D in get_overlapping_bodies():
			var j := c as Jogador
			if j and j.local and j.vida > 0:
				_t = ARAME_A_CADA
				j.levar_dano(ARAME_DANO, (j.global_position - global_position).normalized() * 0.2)
				j.agarrar(0.6)
