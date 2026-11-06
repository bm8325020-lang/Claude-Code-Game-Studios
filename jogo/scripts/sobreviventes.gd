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
	var fachadas: Array = b.get_children().filter(func(n: Node) -> bool: return n.has_meta("poly") and n.has_meta("frente") and not Bairro.queimada(String(n.get_meta("modelo", ""))))
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
	_lugares()
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
	_cerca_refugio(Vector2(frente.x, frente.z), fora, lado, String(casa.name))
	bar.position = Vector3(p.x, _b.altura(p), p.y)
	bar.rotation.y = atan2(fora.x, fora.y)  # frente do modelo (+Z) para a rua
	add_child(bar)
	_b._pinta(bar, Color(0.75, 0.72, 0.66))
	casa.set_meta("refugio", true)
	# sala segura (31/10): luz quente de lampião lá dentro; zumbi não persegue quem está aqui e a vida volta devagar
	var luz := OmniLight3D.new()
	luz.name = "Lampiao_" + casa.name
	luz.light_color = Color(1.0, 0.72, 0.42)
	luz.light_energy = 1.6
	luz.omni_range = 7.0
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 40.0
	luz.position = _b.dentro_da(String(casa.name)) - Bairro.ORIGEM + Vector3(0, 2.0, 0)
	add_child(luz)
	var lamp := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radial_segments = 12  # anti-lag: o padrão do Godot é 64
	esf.rings = 6
	esf.radius = 0.09
	esf.height = 0.2
	lamp.mesh = esf
	var brilho := StandardMaterial3D.new()
	brilho.albedo_color = Color(1.0, 0.8, 0.5)
	brilho.emission_enabled = true
	brilho.emission = Color(1.0, 0.7, 0.35)
	brilho.emission_energy_multiplier = 3.0
	lamp.material_override = brilho
	lamp.position = luz.position
	add_child(lamp)
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


# --- 06/11 (dono): abrigo com cara de abrigo e lugares com cara de lugar; história nos bilhetes ---
const PROPS: String = "res://assets/mundo/props/%s/%s.gltf"
const LORE_LUGAR: Dictionary = {
	"Hospital": ["Prontuário 117. Febre de 41 graus, pele cinza. Óbito às 3h10. Às 3h40 o paciente levantou da maca. — Dra. R. Okafor",
		"AVISO DA DIREÇÃO: por ordem da Halverson Agro, as amostras do lote 7 ficam na câmara fria. Ninguém abre. Ninguém comenta."],
	"Delegacia": ["Ocorrência 0452: saque na Hollis Feed. Usavam jaqueta preta com um corvo pintado nas costas. O chefe atende por Wade.",
		"Ordem do Exército: ninguém sai de Senoia. Atirar se preciso. Eu não assino isso. — Sgt. Cole"],
	"Mercado": ["REGRAS DOS CORVOS: 1) o que achar é do bando. 2) mordido sai. 3) forasteiro paga pedágio ou vira isca. — W.H.",
		"O Wade diz que a Halverson pagou pra gente sumir com os caminhões de milho. Agora ninguém paga mais ninguém."],
	"Igreja": ["O padre Tomás abriu a igreja pra quem chegasse. Na quarta noite, foi ele mesmo que abriu a porta pra eles."],
}


## Coloca um modelo pronto (Sketchfab/normaliza.py) no chão, com colisão em caixa (quem passa pula ou contorna).
func _prop(nome: String, p: Vector2, rot: float, colide: bool = true) -> Node3D:
	var arq: String = PROPS % [nome, nome]
	if not ResourceLoader.exists(arq):
		return null
	var m: Node3D = (load(arq) as PackedScene).instantiate()
	m.position = Vector3(p.x, _b.altura(p), p.y)
	m.rotation.y = rot
	add_child(m)
	var caixa := AABB()
	var prim: bool = true
	for g: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 120.0
		caixa = g.get_aabb() if prim else caixa.merge(g.get_aabb())
		prim = false
	if colide and caixa.size.y > 0.4:
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = caixa.size * Vector3(0.92, 1.0, 0.92)
		cs.shape = bx
		cs.position = caixa.get_center()
		corpo.add_child(cs)
		m.add_child(corpo)
	m.set_meta("comp", maxf(maxf(caixa.size.x, caixa.size.z), 0.5))
	m.set_meta("eixo_z", caixa.size.z > caixa.size.x)
	m.set_meta("alto", caixa.size.y)
	return m


## Fileira de um modelo de a até b (sacos de areia, barreiras), virada ao longo da linha.
func _fileira(nome: String, a: Vector2, b: Vector2, andares: int = 1) -> void:
	var d: Vector2 = b - a
	var ang: float = atan2(-d.y, d.x)  # o comprimento do modelo (eixo X) ao longo da linha
	var teste: Node3D = _prop(nome, a, ang)
	if teste == null:
		return
	if bool(teste.get_meta("eixo_z")):  # modelo comprido em Z: gira 90° para deitar ao longo da linha
		ang += PI * 0.5
		teste.rotation.y = ang
	var passo: float = maxf(float(teste.get_meta("comp")) * 0.9, 0.5)
	var alto: float = float(teste.get_meta("alto"))
	var n: int = int(d.length() / passo)
	for andar in andares:
		for k in range(0 if andar > 0 else 1, n + 1):
			var m: Node3D = _prop(nome, a + d.normalized() * (passo * k + (passo * 0.5 if andar % 2 == 1 else 0.0)), ang, andar == 0)
			if m:
				m.position.y += alto * 0.85 * andar


## Refúgio de verdade: quintal da frente fechado com sacos de areia e barreira (um portão estreito no meio),
## barraca, holofote e placa "VIVOS AQUI".
func _cerca_refugio(f: Vector2, fora: Vector2, lado: Vector2, nome: String) -> void:
	var l: float = 5.0
	var fundo: float = 3.6
	_fileira("sacos_areia", f + lado * l, f + lado * l + fora * fundo, 2)
	_fileira("sacos_areia", f - lado * l, f - lado * l + fora * fundo, 2)
	_fileira("sacos_areia", f + lado * l + fora * fundo, f + lado * 1.4 + fora * fundo, 2)
	_fileira("barreira", f - lado * l + fora * fundo, f - lado * 1.4 + fora * fundo)
	if hash(nome) % 2 == 0:
		_prop("tenda", f + lado * 3.8 + fora * 3.0, atan2(fora.x, fora.y))
	_prop("holofote", f - lado * 4.5 + fora * 4.6, atan2(fora.x, fora.y), false)
	var placa := Label3D.new()
	placa.text = "VIVOS AQUI\nBATA 3 VEZES"
	placa.font_size = 64
	placa.modulate = Color(0.95, 0.9, 0.75)
	placa.outline_size = 10
	placa.position = Vector3(f.x + fora.x * fundo, _b.altura(f) + 1.6, f.y + fora.y * fundo) + Vector3(lado.x, 0, lado.y) * 2.4
	placa.rotation.y = atan2(fora.x, fora.y)
	placa.visibility_range_end = 60.0
	add_child(placa)


## Hospital, delegacia, mercado dos Corvos e igreja com cara de lugar (na frente de cada um) + bilhetes da história.
func _lugares() -> void:
	for nome: String in ["Hospital", "Delegacia", "Mercado", "Igreja"]:
		var no: Node3D = _b.get_node_or_null(nome)
		if no == null or not no.has_meta("frente"):
			continue
		var fr3: Vector3 = (no.get_meta("frente") as Vector3) - Bairro.ORIGEM
		var f := Vector2(fr3.x, fr3.z)
		var c: Vector2 = _b._centro(no.get_meta("poly")) if no.has_meta("poly") else f - Vector2(0, 10)
		var fora: Vector2 = (f - c).normalized()
		var lado := Vector2(fora.y, -fora.x)
		var rot: float = atan2(fora.x, fora.y)
		match nome:
			"Hospital":  # triagem do Exército na porta: barracas, macas de corpos, barreiras e holofote
				_prop("tenda", f + fora * 7.0 + lado * 7.0, rot)
				_prop("tenda", f + fora * 7.0 - lado * 7.0, rot)
				for k in 6:
					_prop("saco_corpo", f + fora * 3.5 + lado * (k - 2.5) * 1.0, rot + PI * 0.5, false)
				_fileira("barreira", f + fora * 11.0 + lado * 9.0, f + fora * 11.0 + lado * 2.0)
				_prop("holofote", f + fora * 9.0 - lado * 2.5, rot, false)
				_letreiro("HOSPITAL MUNICIPAL\n✚", f + fora * 1.0, rot, Color(0.95, 0.2, 0.15))
			"Delegacia":  # polícia caiu atrás de sacos de areia
				_fileira("sacos_areia", f + fora * 4.0 + lado * 6.0, f + fora * 4.0 + lado * 1.5)
				_fileira("sacos_areia", f + fora * 4.0 - lado * 1.5, f + fora * 4.0 - lado * 6.0)
				_fileira("barreira", f + fora * 9.0 + lado * 5.0, f + fora * 9.0 - lado * 5.0)
			"Mercado":  # base dos Corvos: muralha de sacos e contêiner, torre de vigia, placa pichada
				_fileira("sacos_areia", f + fora * 5.0 + lado * 10.0, f + fora * 5.0 + lado * 2.0)
				_fileira("sacos_areia", f + fora * 5.0 - lado * 2.0, f + fora * 5.0 - lado * 10.0)
				_prop("torre_vigia", f + fora * 8.0 + lado * 11.0, rot)
				_prop("conteiner", f + fora * 9.0 - lado * 13.0, rot + PI * 0.5)
				_letreiro("TERRITÓRIO DOS CORVOS\nPEDÁGIO OU MORTE", f + fora * 5.2, rot, Color(0.9, 0.15, 0.1))
			"Igreja":
				for k in 4:
					_prop("saco_corpo", f + fora * 2.5 + lado * (k - 1.5) * 1.1, rot + PI * 0.5, false)
		var textos: Array = LORE_LUGAR.get(nome, [])
		for k in textos.size():
			_bilhete_em(f + fora * (2.0 + k * 1.5) + lado * (1.5 - k * 3.0), String(textos[k]))


func _letreiro(texto: String, p: Vector2, rot: float, cor: Color) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 120
	l.modulate = cor
	l.outline_size = 14
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector3(p.x, _b.altura(p) + 4.2, p.y)
	l.rotation.y = rot
	l.visibility_range_end = 140.0
	add_child(l)


func _bilhete_em(p: Vector2, texto: String) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.21, 0.29)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.84, 0.76)
	mi.material_override = m
	mi.position = Vector3(p.x, _b.altura(p) + 0.075, p.y)
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
