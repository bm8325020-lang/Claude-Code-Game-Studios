# História (07/11, dono: "falta objetivo, tá chato"; modo história, ideias/dead-district/HISTORIA.md): painel no canto
# de cima com o capítulo e o objetivo da vez. Cada passo que tem lugar marca o destino no mapa sozinho
# (Minimapa.destino) e, ao fechar, mostra uma fala curta da história (rádio da Dana, diário da Mia). Depois do último
# capítulo voltam as tarefas sorteadas. Cada passo dá XP. Só no aparelho do jogador (não vai pela rede).
class_name Tarefas
extends Control

const XP: int = 30
const PERTO: float = 16.0  # m para contar "chegou"
## [capítulo, objetivo, evento, quantos, alvo (onde marcar no mapa: "" = nenhum), fala ao terminar]
const ROTEIRO: Array = [
	["1 · A PRIMEIRA NOITE", "Pegue uma lata de comida", "comida", 1, "", ""],
	["1 · A PRIMEIRA NOITE", "Ache um refúgio (casa com tábuas e lampião)", "segura", 1, "refugio",
		"RÁDIO (Dana Price): \"Quem estiver ouvindo... o hospital ainda tinha gente no dia 20.\""],
	["2 · O HOSPITAL", "Vá até o HOSPITAL atrás da Mia", "chegar", 1, "raid:HOSPITAL MUNICIPAL", ""],
	["2 · O HOSPITAL", "Revistar o hospital atrás de pistas (%d/%d)", "revistou", 3, "raid:HOSPITAL MUNICIPAL",
		"DIÁRIO DA MIA: \"A doutora Okafor vai nos levar para a QUARENTENA. Tem um laboratório lá.\""],
	["3 · OS CORVOS", "Os Corvos dominam o MERCADO. Passe por lá e sobreviva", "chegar", 1, "raid:OS CORVOS",
		"RÁDIO (Dana): \"Os Corvos têm explosivo do exército. É o único jeito de abrir a quarentena.\""],
	["3 · OS CORVOS", "Consiga uma BOMBA (baú raro, Corvos ou loja)", "bomba", 1, "raid:OS CORVOS", ""],
	["4 · A QUARENTENA", "Exploda o portão da QUARENTENA", "portao", 1, "quarentena",
		"Do outro lado do muro: tendas, sangue e saqueadores. A Mia esteve aqui."],
	["4 · A QUARENTENA", "Elimine os saqueadores da quarentena (%d/%d)", "abateu", 5, "quarentena",
		"Um bilhete da Mia na tenda: \"Fomos para o alto. Procure um sinal de rádio.\""],
	["5 · O SINAL", "Suba na TORRE DE ÁGUA e procure o sinal", "torre", 1, "torre",
		"RÁDIO MILITAR: \"...helicóptero... heliponto do hospital... ao amanhecer...\""],
	["5 · O SINAL", "Sobreviva até amanhecer", "amanheceu", 1, "",
		"FIM DO CAPÍTULO 5 — a história continua nas próximas versões."],
]
const DEPOIS: Array = [["abateu", 5, "Mate zumbis (%d/%d)"], ["revistou", 5, "Revistar gavetas ou armários (%d/%d)"],
	["agua", 2, "Pegue garrafas de água (%d/%d)"], ["comida", 2, "Pegue latas de comida (%d/%d)"]]

var _j: Jogador
var _i: int = 0
var _feito: int = 0
var _atual: Array = []
var _alvo: Vector3 = Vector3.INF
var _titulo: Label
var _linha: Label
var _t: float = 0.0
var _era_noite: bool = false


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.4)
	fundo.size = Vector2(380, 62)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_titulo = UiTema.rotulo("HISTÓRIA", 20, Color(1.0, 0.68, 0.2))
	_titulo.autowrap_mode = TextServer.AUTOWRAP_OFF  # sem largura, quebrava letra por letra (vídeo do dono)
	_titulo.position = Vector2(10, 2)
	add_child(_titulo)
	_linha = UiTema.rotulo("", 17, Color(1, 1, 1, 0.95))
	_linha.position = Vector2(14, 30)
	_linha.autowrap_mode = TextServer.AUTOWRAP_OFF
	_linha.size = Vector2(362, 28)
	_linha.clip_text = true
	add_child(_linha)
	_comeca()


func liga(j: Jogador) -> void:
	_j = j
	j.item_pego.connect(func(t: String, _q: int) -> void: evento(t))
	j.revistou.connect(func() -> void: evento("revistou"))
	j.abateu.connect(func() -> void: evento("abateu"))
	j.entrou_segura.connect(func(sim: bool) -> void:
		if sim:
			evento("segura"))
	_comeca()


## Passo da vez: do roteiro da história; acabou, sorteia.
func _comeca() -> void:
	_feito = 0
	if _i < ROTEIRO.size():
		var r: Array = ROTEIRO[_i]
		_atual = [r[2], r[3], r[1]]
		_titulo.text = "HISTÓRIA · CAP. " + String(r[0])
		_alvo = _onde(String(r[4]))
		if _alvo.is_finite():
			Minimapa.destino = _alvo
	else:
		_atual = DEPOIS[randi() % DEPOIS.size()]
		_titulo.text = "TAREFAS"
		_alvo = Vector3.INF
	_mostra()


func _mostra() -> void:
	var texto: String = String(_atual[2])
	if texto.contains("%d"):
		texto = texto % [_feito, int(_atual[1])]
	_linha.text = "•  " + texto


## Onde fica o alvo de um passo (global), ou INF.
func _onde(alvo: String) -> Vector3:
	var principal := get_tree().get_first_node_in_group("principal") if is_inside_tree() else null
	var b: Bairro = principal.bairro if principal else null
	if b == null or alvo == "":
		return Vector3.INF
	if alvo.begins_with("raid:"):
		for r: Dictionary in b.raids:
			if r.nome == alvo.substr(5):
				return r.pos
	elif alvo == "quarentena" and b.marcos_pos.has("quarentena"):
		return b.marcos_pos.quarentena
	elif alvo == "torre":
		var s: Subida = b.get_node_or_null("Subida_0") as Subida
		return s.baixo if s else Vector3.INF
	elif alvo == "refugio" and _j:
		var melhor := Vector3.INF
		for c: Node in b.get_children():
			if c.has_meta("refugio"):
				var p: Vector3 = b.frente_da(String(c.name))
				if p.distance_to(_j.global_position) < melhor.distance_to(_j.global_position):
					melhor = p
		return melhor
	return Vector3.INF


func evento(tipo: String) -> void:
	if _atual.is_empty() or tipo != String(_atual[0]):
		return
	_feito += 1
	if _feito < int(_atual[1]):
		_mostra()
		return
	if _j and is_instance_valid(_j):
		_j._recebe("xp", XP)
	var fala: String = String(ROTEIRO[_i][5]) if _i < ROTEIRO.size() else ""
	var c := get_parent()
	if c and c.has_method("aviso"):
		c.aviso(fala if fala != "" else "FEITO  +%d XP" % XP, UiTema.DESTAQUE, 6.0 if fala != "" else 2.0)
	if _alvo.is_finite() and Minimapa.destino == _alvo:
		Minimapa.destino = Vector3.INF
	_i += 1
	_comeca()


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or _j == null or not is_instance_valid(_j):
		return
	_t = 0.5
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var noite: bool = ciclo.e_noite()
		if _era_noite and not noite:
			evento("amanheceu")
		_era_noite = noite
	if _atual.is_empty():
		return
	var ev: String = String(_atual[0])
	if ev == "chegar" and _alvo.is_finite() and _alvo.distance_to(_j.global_position) < PERTO:
		evento("chegar")
	elif ev == "torre" and _alvo.is_finite() and _j.global_position.y > _alvo.y + 12.0:
		evento("torre")
	elif ev == "portao":
		var principal := get_tree().get_first_node_in_group("principal")
		var p: Porta = principal.bairro.get_node_or_null("Portao_0") as Porta if principal and principal.bairro else null
		if p and p.arrombada():
			evento("portao")
