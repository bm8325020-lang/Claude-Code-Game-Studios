# História completa (07/11, dono: "modo história completo, do início até zerar; enquanto não completar uma ação não
# libera a próxima"; ideias/dead-district/HISTORIA.md). Painel no canto: capítulo e objetivo da vez. Cada passo:
#  - marca o destino no mapa sozinho (Minimapa.destino);
#  - pode PREPARAR o mundo quando começa (Dana na van, diário no hospital, Wade no mercado, Mia e o Sargento Mercer na
#    quarentena, peças do rádio, fitas, heliponto, horda final, helicóptero) — o que nasce no mundo é do servidor;
#  - fecha com um evento (ação do jogador) e mostra a fala da história.
# A ordem é obrigatória (um passo de cada vez). O passo salvo fica no aparelho (user://historia_<nick>.cfg).
# Depois do fim (Final: boletim + créditos) voltam as tarefas sorteadas. Só no aparelho do jogador (não vai pela rede).
class_name Tarefas
extends Control

const XP: int = 40
const PERTO: float = 14.0
const FITAS: int = 5
const NOITE_FINAL_T: float = 150.0  # s aguentando no heliponto até o helicóptero
const ONDA_A_CADA: float = 18.0
const ONDA_ZUMBIS: int = 7
const HELIPONTO_RAIO: float = 26.0
## [capítulo, objetivo, evento, quantos, alvo no mapa, preparar ao começar, fala ao terminar]
const ROTEIRO: Array = [
	["0 · A ESTRADA", "Entre no carro e siga a estrada até Senoia", "chegou", 1, "", "",
		"Senoia. 4 mil habitantes. Nenhum vivo à vista."],
	["1 · A PRIMEIRA NOITE", "Pegue uma lata de comida", "comida", 1, "", "", ""],
	["1 · A PRIMEIRA NOITE", "Ache um refúgio (casa com tábuas e lampião)", "segura", 1, "refugio", "",
		"RÁDIO (Dana Price): \"Se alguém estiver ouvindo... estou na van da TV, na praça. Venha.\""],
	["2 · A VAN DA TV", "Vá até a van da TV no centro e fale com a Dana", "fala:dana", 1, "dana", "dana",
		"A Dana te deu a frequência do rádio dela. Agora: o hospital."],
	["3 · O HOSPITAL", "Vá ao HOSPITAL atrás da sua irmã Mia", "chegar", 1, "raid:HOSPITAL MUNICIPAL", "hospital", ""],
	["3 · O HOSPITAL", "Ache o DIÁRIO DA MIA no hospital", "diario", 1, "item:diario", "",
		"DIÁRIO DA MIA: \"A Dra. Okafor vai nos levar para a QUARENTENA. Só os Corvos têm explosivo para abrir aquilo.\""],
	["4 · OS CORVOS", "Mate WADE HARLAN, o líder dos Corvos, no mercado", "morto:wade", 1, "raid:OS CORVOS", "wade",
		"Wade cai. Na mochila dele: uma bomba do Exército e uma fita."],
	["4 · OS CORVOS", "Pegue a BOMBA que o Wade largou", "bomba", 1, "item:bomba", "", ""],
	["5 · A QUARENTENA", "Exploda o portão da QUARENTENA com a bomba", "portao", 1, "quarentena", "", ""],
	["5 · A QUARENTENA", "Ache a MIA nas tendas da quarentena", "fala:mia", 1, "mia", "mia", ""],
	["5 · A QUARENTENA", "Traga um ANTIBIÓTICO para a Mia (farmácia, hospital, baús)", "remedio", 1, "mia", "",
		"MIA: \"Melhorou... Vai, o Mercer tem as peças do rádio. Eu te encontro no heliponto.\""],
	["5 · A QUARENTENA", "Mate o SARGENTO MERCER (virou zumbi) no laboratório", "morto:mercer", 1, "item:mercer", "mercer",
		"Mercer caiu. Uma peça do rádio militar e mais uma fita."],
	["6 · O SINAL", "Junte as 3 PEÇAS DO RÁDIO: Mercer, ferro-velho e posto (%d/3)", "peca_radio", 3, "item:peca_radio", "pecas", ""],
	["6 · O SINAL", "Suba na TORRE DE ÁGUA e chame o Exército pelo rádio", "torre", 1, "torre", "",
		"RÁDIO MILITAR: \"...Senoia, entendido. Helicóptero no heliponto do hospital na próxima noite. Aguentem.\""],
	["7 · AS FITAS", "Junte as fitas da Dra. Okafor (%d/5) e vá ao HELIPONTO do hospital", "chegar", 1, "heliponto", "fitas", ""],
	["8 · A ÚLTIMA NOITE", "Aguente no heliponto até o helicóptero chegar", "sobreviveu", 1, "heliponto", "", ""],
	["8 · A ÚLTIMA NOITE", "CORRA PARA O HELICÓPTERO!", "chegar", 1, "helicoptero", "helicoptero", ""],
]
const DEPOIS: Array = [["abateu", 5, "Mate zumbis (%d/%d)"], ["revistou", 5, "Revistar gavetas ou armários (%d/%d)"],
	["agua", 2, "Pegue garrafas de água (%d/%d)"], ["comida", 2, "Pegue latas de comida (%d/%d)"]]

const DANA: Array = ["Graças a Deus, alguém vivo! Sou a Dana, da WSB.",
	"Não foi acidente: a Febre Cinzenta saiu do milho da Hollis Feed. A Halverson Agro testava algo ali.",
	"A Dra. Okafor gravou tudo em fitas. São cinco. Sem elas, ninguém vai acreditar.",
	"Sua irmã, a Mia? Vi enfermeiras no hospital no dia 20. Comece por lá.",
	"Leve este rádio. Eu falo com você por ele. Boa sorte."]
const MIA: Array = ["...Alex? Você veio... eu disse para não vir.",
	"Fui mordida. A doutora me dava remédio para segurar a febre. Preciso de um ANTIBIÓTICO."]

var _j: Jogador
var _i: int = 0
var _feito: int = 0
var _atual: Array = []
var _alvo: Vector3 = Vector3.INF
var _titulo: Label
var _linha: Label
var _t: float = 0.0
var _era_noite: bool = false
var _npc: Dictionary = {}       # "dana"/"mia" -> Npc
var _chefe: Dictionary = {}     # "wade"/"mercer" -> Zumbi
var _itens: Dictionary = {}     # "diario"/"bomba"/"peca_radio"/"mercer" -> posição para marcar
var _heliponto: Vector3 = Vector3.INF
var _resiste_t: float = 0.0
var _onda_t: float = 0.0
var _heli: Node3D
var _salvo: String = ""
var _cap: String = ""


## Cartão do capítulo no meio da tela (aparece, fica e some), como nos jogos de história.
func _cartao(texto: String) -> void:
	var c := CanvasLayer.new()
	c.layer = 20
	var l := UiTema.rotulo(texto, 52, Color(1.0, 0.72, 0.25))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.modulate.a = 0.0
	c.add_child(l)
	get_tree().root.add_child(c)
	var tw := c.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(c.queue_free)


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.size = Vector2(430, 62)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_titulo = UiTema.rotulo("HISTÓRIA", 19, Color(1.0, 0.68, 0.2))
	_titulo.autowrap_mode = TextServer.AUTOWRAP_OFF  # sem largura, quebrava letra por letra (vídeo do dono)
	_titulo.position = Vector2(10, 2)
	add_child(_titulo)
	_linha = UiTema.rotulo("", 16, Color(1, 1, 1, 0.95))
	_linha.position = Vector2(14, 30)
	_linha.autowrap_mode = TextServer.AUTOWRAP_OFF
	_linha.size = Vector2(412, 28)
	_linha.clip_text = true
	add_child(_linha)


func liga(j: Jogador) -> void:
	_j = j
	j.item_pego.connect(func(t: String, _q: int) -> void: evento(t))
	j.revistou.connect(func() -> void: evento("revistou"))
	j.abateu.connect(func() -> void: evento("abateu"))
	j.entrou_segura.connect(func(sim: bool) -> void:
		if sim:
			evento("segura"))
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and principal.has_method("_testando") and principal._testando():
		_i = 1  # teste: sem a abertura da estrada e sem o salvo
	else:
		_salvo = "user://historia_%s.cfg" % j.nick.validate_filename()
		var cf := ConfigFile.new()
		if cf.load(_salvo) == OK:
			_i = int(cf.get_value("historia", "passo", 0))
	_comeca()


func _salva() -> void:
	if _salvo == "":
		return
	var cf := ConfigFile.new()
	cf.set_value("historia", "passo", _i)
	cf.save(_salvo)


func _comeca() -> void:
	_feito = 0
	if _i < ROTEIRO.size():
		var r: Array = ROTEIRO[_i]
		_atual = [r[2], r[3], r[1]]
		_titulo.text = "HISTÓRIA · CAP. " + String(r[0])
		if String(r[0]) != _cap:
			if _cap != "":
				_cartao("CAPÍTULO " + String(r[0]))
			_cap = String(r[0])
		_prepara(String(r[5]))
		_alvo = _onde(String(r[4]))
		Minimapa.destino = _alvo
		if String(r[2]) == "peca_radio" and _j:
			_feito = _j.mochila.conta("peca_radio")
	else:
		_atual = DEPOIS[randi() % DEPOIS.size()]
		_titulo.text = "TAREFAS"
		_alvo = Vector3.INF
	_mostra()


func _mostra() -> void:
	var texto: String = String(_atual[2])
	if texto.count("%d") == 2:
		texto = texto % [_feito, int(_atual[1])]
	elif texto.count("%d") == 1:
		texto = texto % (_fitas() if _atual[0] == "chegar" else _feito)
	_linha.text = "•  " + texto


func _fitas() -> int:
	return _j.mochila.conta("fita") if _j else 0


func _bairro() -> Bairro:
	var principal := get_tree().get_first_node_in_group("principal") if is_inside_tree() else null
	return principal.bairro if principal else null


func _servidor() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## Onde fica o alvo de um passo (global), ou INF.
func _onde(alvo: String) -> Vector3:
	var b: Bairro = _bairro()
	if b == null or alvo == "":
		return Vector3.INF
	if alvo.begins_with("raid:"):
		for r: Dictionary in b.raids:
			if r.nome == alvo.substr(5):
				return r.pos
	elif alvo.begins_with("item:"):
		return _itens.get(alvo.substr(5), Vector3.INF)
	elif alvo == "quarentena" and b.marcos_pos.has("quarentena"):
		return b.marcos_pos.quarentena
	elif alvo == "torre":
		var s: Subida = b.get_node_or_null("Subida_0") as Subida
		return s.baixo if s else Vector3.INF
	elif alvo == "heliponto":
		return _heliponto
	elif alvo == "helicoptero":
		return _heli.global_position if _heli else _heliponto
	elif _npc.has(alvo):
		return (_npc[alvo] as Node3D).global_position
	elif alvo == "refugio" and _j:
		var melhor := Vector3.INF
		for c: Node in b.get_children():
			if c.has_meta("refugio"):
				var p: Vector3 = b.frente_da(String(c.name))
				if p.distance_to(_j.global_position) < melhor.distance_to(_j.global_position):
					melhor = p
		return melhor
	return Vector3.INF


## Lugar no chão perto de `p` (malha de navegação), para pôr gente e item na rua e não dentro da parede.
func _chao(p: Vector3) -> Vector3:
	var mapa: RID = get_viewport().world_3d.navigation_map
	var q: Vector3 = NavigationServer3D.map_get_closest_point(mapa, p)
	return q if q.is_finite() and q != Vector3.ZERO else p


func _solta(tipo: String, p: Vector3) -> void:
	if _servidor():
		get_tree().get_first_node_in_group("principal").solta_item(tipo, 1, p + Vector3(0, 0.3, 0), 1.0e9)
	_itens[tipo] = p


func _poe_npc(chave: String, nome: String, falas: Array, p: Vector3) -> void:
	var n := Npc.new()
	n.nome = nome
	n.falas = falas
	_bairro().add_child(n)
	n.global_position = p
	_npc[chave] = n


func _prepara(o_que: String) -> void:
	var b: Bairro = _bairro()
	if b == null or o_que == "":
		return
	var principal := get_tree().get_first_node_in_group("principal")
	match o_que:
		"dana":  # van da TV na praça do centro, Dana do lado
			var p: Vector3 = _chao(Bairro.ORIGEM + Vector3(-15, 0, 225))
			var van: Node3D = b._veiculo("mundo:van", Color.WHITE)
			van.global_position = p + Vector3(2.5, 0, 0)
			_poe_npc("dana", "DANA PRICE", DANA, p)
		"hospital":  # diário da Mia e a 1ª fita na frente do hospital
			var h: Vector3 = _onde("raid:HOSPITAL MUNICIPAL")
			_solta("diario", _chao(h + Vector3(6, 0, 4)))
			_solta("fita", _chao(h + Vector3(-5, 0, 6)))
		"wade":
			var m: Vector3 = _chao(_onde("raid:OS CORVOS"))
			if _servidor():
				var z: Zumbi = principal.spawner_zumbis.spawn({"pos": m + Vector3(0, 0.1, 0), "armado": true, "tipo": "corvo", "de_raid": true, "lider": true})
				_chefe["wade"] = z
				get_tree().create_timer(0.2).timeout.connect(func() -> void:
					if is_instance_valid(z) and z._fala_lbl:
						z._fala_lbl.text = "WADE HARLAN")
		"mia":
			var q: Vector3 = b.marcos_pos.get("quarentena", Bairro.ORIGEM)
			_poe_npc("mia", "MIA", MIA, _chao(q + Vector3(0, 0, 30)))
		"mercer":
			var q2: Vector3 = _chao(b.marcos_pos.get("quarentena", Bairro.ORIGEM) + Vector3(25, 0, 45))
			_itens["mercer"] = q2
			if _servidor():
				_chefe["mercer"] = principal.spawner_zumbis.spawn({"pos": q2 + Vector3(0, 0.1, 0), "chefe": true, "de_raid": true})
		"pecas":  # a 1ª veio do Mercer; as outras no ferro-velho e nas bombas de gasolina
			for k: String in ["BauLugar_0", "BauLugar_%d" % (b.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("BauLugar_")).size() - 1)]:
				var bl: Node3D = b.get_node_or_null(k)
				if bl:
					_solta("peca_radio", _chao(bl.global_position + Vector3(1.5, 0, 1.5)))
		"fitas":  # as que faltam: escola e igreja (hospital, Wade e Mercer já deram 3)
			for alvo: String in ["raid:IGREJA MATRIZ"]:
				_solta("fita", _chao(_onde(alvo) + Vector3(0, 0, 8)))
			var esc: Node3D = b.get_node_or_null("BauLugar_2")
			if esc:
				_solta("fita", _chao(esc.global_position + Vector3(1, 0, -1)))
			var h2: Vector3 = _onde("raid:HOSPITAL MUNICIPAL")
			var fr: Vector3 = b.get_node("Hospital").get_meta("frente") if b.has_node("Hospital") and b.get_node("Hospital").has_meta("frente") else h2 + Vector3(20, 0, 0)
			_heliponto = _chao(fr + (fr - h2).normalized() * 10.0)
			_marca_heliponto()
		"helicoptero":
			_heli = (load(Bairro.RUINAS % "helicoptero") as PackedScene).instantiate()
			b.add_child(_heli)
			var pouso: Vector3 = _chao(_heliponto + Vector3(25, 0, 0))
			_heli.global_position = pouso + Vector3(0, 60, 0)  # desce do céu
			var tw := create_tween()
			tw.tween_property(_heli, "global_position", pouso, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _marca_heliponto() -> void:
	var l := Label3D.new()
	l.text = "H"
	l.font_size = 400
	l.modulate = Color(1.0, 0.85, 0.2, 0.9)
	l.rotation_degrees.x = -90
	_bairro().add_child(l)
	l.global_position = _heliponto + Vector3(0, 0.08, 0)


func evento(tipo: String) -> void:
	if _atual.is_empty() or tipo != String(_atual[0]):
		return
	_feito += 1
	if _feito < int(_atual[1]):
		_mostra()
		return
	if _j and is_instance_valid(_j):
		_j._recebe("xp", XP)
	var fala: String = String(ROTEIRO[_i][6]) if _i < ROTEIRO.size() else ""
	var c := get_parent()
	if c and c.has_method("aviso"):
		c.aviso(fala if fala != "" else "FEITO  +%d XP" % XP, UiTema.DESTAQUE, 7.0 if fala != "" else 2.0)
	if Minimapa.destino == _alvo:
		Minimapa.destino = Vector3.INF
	_i += 1
	if _i == ROTEIRO.size():
		_fim()
	_salva()
	_comeca()


func _fim() -> void:
	var f := Final.new()
	f.bom = _fitas() >= FITAS
	get_tree().root.add_child(f)


func _process(dt: float) -> void:
	_t -= dt
	if _j == null or not is_instance_valid(_j) or _atual.is_empty():
		return
	var ev: String = String(_atual[0])
	if ev == "sobreviveu":
		_noite_final(dt)
	if _t > 0.0:
		return
	_t = 0.4
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var noite: bool = ciclo.e_noite()
		if _era_noite and not noite:
			evento("amanheceu")
		_era_noite = noite
	if _alvo.is_finite() and Minimapa.destino != _alvo and Minimapa.destino.is_finite() == false:
		Minimapa.destino = _alvo
	match ev:
		"chegar":
			if _atual[2].contains("%d"):
				_mostra()
			var qual: String = String(ROTEIRO[_i][4]) if _i < ROTEIRO.size() else ""
			var a: Vector3 = _onde(qual) if qual != "" else _alvo
			var raio: float = 6.0 if qual == "helicoptero" else PERTO
			if qual == "helicoptero" and _heli and _heli.global_position.y > _heliponto.y + 3.0:
				return  # ainda descendo
			if a.is_finite() and Vector2(a.x - _j.global_position.x, a.z - _j.global_position.z).length() < raio:
				evento("chegar")
		"torre":
			if _alvo.is_finite() and _j.global_position.y > _alvo.y + 12.0:
				if _j.mochila.tem("peca_radio"):
					evento("torre")
		"portao":
			var b: Bairro = _bairro()
			var p: Porta = b.get_node_or_null("Portao_0") as Porta if b else null
			if p and p.arrombada():
				evento("portao")
		"remedio":
			var mia: Node3D = _npc.get("mia")
			if mia and mia.global_position.distance_to(_j.global_position) < 4.0 and _j.mochila.tem("antibiotico"):
				_j.mochila.tirar("antibiotico", 1)
				evento("remedio")
		_:
			if ev.begins_with("fala:"):
				var n: Npc = _npc.get(ev.substr(5))
				if n and n.falou:
					evento(ev)
			elif ev.begins_with("morto:"):
				var z: Node = _chefe.get(ev.substr(6))
				if _servidor() and (z == null or not is_instance_valid(z) or (z as Zumbi).vida <= 0):
					var onde: Vector3 = (z as Node3D).global_position if z and is_instance_valid(z) else _alvo
					if ev == "morto:wade":
						_solta("bomba", onde)
						_solta("fita", onde + Vector3(1, 0, 0))
					else:
						_solta("peca_radio", onde)
						_solta("fita", onde + Vector3(1, 0, 0))
					evento(ev)


## Última noite: espera anoitecer no heliponto; de noite, perto dele, conta o tempo e chama ondas de zumbis.
func _noite_final(dt: float) -> void:
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	var noite: bool = ciclo != null and ciclo.e_noite()
	var perto: bool = _heliponto.is_finite() and _heliponto.distance_to(_j.global_position) < HELIPONTO_RAIO
	if not noite:
		_linha.text = "•  Espere ANOITECER no heliponto do hospital"
		return
	if not perto:
		_linha.text = "•  Volte para o HELIPONTO! (%d s)" % int(NOITE_FINAL_T - _resiste_t)
		return
	_resiste_t += dt
	_linha.text = "•  Aguente no heliponto: %d s" % int(maxf(NOITE_FINAL_T - _resiste_t, 0.0))
	_onda_t -= dt
	if _onda_t <= 0.0 and _servidor():
		_onda_t = ONDA_A_CADA
		var principal := get_tree().get_first_node_in_group("principal")
		for k in ONDA_ZUMBIS:
			var a: float = randf() * TAU
			var z: Zumbi = principal.spawner_zumbis.spawn({"pos": _chao(_heliponto + Vector3(cos(a), 0, sin(a)) * randf_range(28.0, 40.0)) + Vector3(0, 0.1, 0), "horda": Zumbi.DO_MORTO})
			if z:
				z.alvo = _j
	if _resiste_t >= NOITE_FINAL_T:
		evento("sobreviveu")
