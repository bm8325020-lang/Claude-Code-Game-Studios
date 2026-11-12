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
## [capítulo, objetivo, evento, quantos, alvo no mapa, preparar ao começar, fala ao terminar, config]
## config (opcional): ondas/zumbis/raio/centro = luta obrigatória; timer = s para cumprir (senão recomeça o passo);
## cena = câmera de cinema mostrando o lugar; susto = zumbis atrás de você e um grito; premio = [tipo, qtd, ...];
## chefe = barra de vida + fase na metade (reforço); local = linha embaixo do cartão do capítulo.
const ROTEIRO: Array = [
	["0 · A ESTRADA", "Entre no carro e siga a estrada até Senoia", "chegou", 1, "", "",
		"Senoia. 4 mil habitantes. Nenhum vivo à vista.", {"local": "Estrada 16, entrada de Senoia",
		"radio": "Alguém na estrada? Aqui é Dana Price, da TV. A pé você não chega: pegue o carro e entre em Senoia."}],
	["1 · A PRIMEIRA NOITE", "Você está só no soco: pegue o FACÃO marcado no mapa", "facao", 1, "item:facao", "facao_inicio", "",
		{"local": "Senoia, Geórgia",
		"radio": "Você está de mãos vazias? Assim não dura uma noite. Tem um facão num quintal perto de você. Marquei no seu mapa."}],
	["1 · A PRIMEIRA NOITE", "RAID NA DELEGACIA: pegue a PISTOLA do arsenal", "pistola", 1, "item:pistola", "delegacia", "",
		{"local": "Delegacia de Senoia", "cena": "raid:DELEGACIA", "premio": ["municao", 24],
		"radio": "Boa. Agora, armamento de verdade: a delegacia tem um arsenal. Está cheia de policiais mortos... vai com cuidado."}],
	["1 · A PRIMEIRA NOITE", "Ache um refúgio (casa com tábuas e lampião)", "segura", 1, "refugio", "", "",
		{"radio": "Escurece rápido. Procure uma casa com tábuas nas janelas e um lampião aceso: é um refúgio."}],
	["1 · A PRIMEIRA NOITE", "Os mortos te ouviram! DEFENDA O REFÚGIO (%d/%d)", "limpou", 1, "refugio", "", "",
		{"ondas": 3, "zumbis": 4, "raio": 30.0, "centro": "eu", "premio": ["municao", 24, "bandagem", 2],
		"radio": "Cuidado! Eles ouviram você. Estão vindo de todos os lados. Segure o refúgio!"}],
	["2 · A VAN DA TV", "Vá até a van da TV no centro e fale com a Dana", "fala:dana", 1, "dana", "dana", "",
		{"local": "Centro de Senoia", "cena": "dana",
		"radio": "Você aguentou! Venha até a van da TV, no centro. Pessoalmente eu explico tudo."}],
	["2 · A VAN DA TV", "Alguém grita no rádio! SALVE O TOMMY, cercado na rua (%d/%d)", "limpou", 1, "tommy", "tommy", "",
		{"ondas": 2, "zumbis": 5, "raio": 28.0, "centro": "tommy",
		"radio": "Ouviu isso? Um rapaz pedindo socorro, aqui perto. Está cercado na rua. Vai, rápido!"}],
	["2 · A VAN DA TV", "Leve o TOMMY vivo até a van da Dana", "escolta", 1, "dana", "",
		"TOMMY: \"Valeu, cara... Eu vi a Mia. Levaram ela pro hospital, depois pros caminhões do Exército.\"",
		{"premio": ["espingarda", 1, "cartucho", 12], "radio": "Traga ele até a van. Fique perto dele: ele não tem arma."}],
	["3 · O HOSPITAL", "Vá ao HOSPITAL atrás da sua irmã Mia", "chegar", 1, "raid:HOSPITAL MUNICIPAL", "hospital", "",
		{"local": "Hospital Municipal de Senoia", "cena": "raid:HOSPITAL MUNICIPAL",
		"radio": "O hospital fica no norte da cidade. Aquilo virou um ninho. Entre devagar."}],
	["3 · O HOSPITAL", "Ache o DIÁRIO DA MIA no hospital", "diario", 1, "item:diario", "",
		"DIÁRIO DA MIA: \"A Dra. Okafor vai nos levar para a QUARENTENA. Só os Corvos têm explosivo para abrir aquilo.\"",
		{"susto": true, "radio": "A Mia escrevia tudo num diário. Se ele ainda estiver aí, vai dizer para onde ela foi."}],
	["4 · OS CORVOS", "Mate WADE HARLAN, o líder dos Corvos, no mercado", "morto:wade", 1, "raid:OS CORVOS", "wade",
		"Wade cai. Na mochila dele: uma bomba do Exército e uma fita.",
		{"local": "Mercado — território dos Corvos", "cena": "raid:OS CORVOS", "chefe": "wade", "premio": ["fuzil", 1, "municao_fuzil", 30],
		"radio": "Os Corvos tomaram o mercado. O líder é Wade Harlan, e ele tem o explosivo. Não vai entregar por bem."}],
	["4 · OS CORVOS", "Pegue a BOMBA que o Wade largou", "bomba", 1, "item:bomba", "", "",
		{"radio": "Ele largou a bomba. Pegue antes que outro Corvo pegue."}],
	["5 · A QUARENTENA", "Exploda o portão da QUARENTENA com a bomba", "portao", 1, "quarentena", "", "",
		{"local": "Quarentena do Exército", "cena": "quarentena",
		"radio": "Agora, o portão da quarentena. Arme a bomba e saia de perto."}],
	["5 · A QUARENTENA", "LIMPE AS TENDAS da quarentena (%d/%d)", "limpou", 1, "quarentena", "", "",
		{"ondas": 2, "zumbis": 6, "raio": 32.0, "centro": "dentro",
		"radio": "As tendas estão infestadas. Limpe tudo antes de procurar a Mia."}],
	["5 · A QUARENTENA", "Ache a MIA nas tendas da quarentena", "fala:mia", 1, "mia", "mia", "",
		{"radio": "A Mia tem que estar numa dessas tendas. Procure!"}],
	["5 · A QUARENTENA", "A febre da Mia sobe! Traga um ANTIBIÓTICO a tempo", "remedio", 1, "mia", "",
		"MIA: \"Melhorou... Vai, o Mercer tem as peças do rádio. Eu te encontro no heliponto.\"",
		{"timer": 300.0, "radio": "Ela está ardendo em febre. Precisa de antibiótico, agora! Farmácia, hospital, qualquer lugar. Rápido!"}],
	["5 · A QUARENTENA", "Mate o SARGENTO MERCER (virou zumbi) no laboratório", "morto:mercer", 1, "item:mercer", "mercer",
		"Mercer caiu. Uma peça do rádio militar e mais uma fita.", {"chefe": "mercer", "premio": ["bandagem", 3, "antibiotico", 1],
		"radio": "O sargento Mercer está no laboratório. Ele virou um deles... e está com a peça do rádio."}],
	["6 · O SINAL", "Junte as 3 PEÇAS DO RÁDIO: Mercer, ferro-velho e posto (%d/3)", "peca_radio", 3, "item:peca_radio", "pecas", "",
		{"local": "Ferro-velho e estrada",
		"radio": "Faltam as peças do rádio militar: uma com o Mercer, uma no ferro-velho e uma no posto."}],
	["6 · O SINAL", "Suba na TORRE DE ÁGUA e chame o Exército pelo rádio", "torre", 1, "torre", "",
		"RÁDIO MILITAR: \"...Senoia, entendido. Helicóptero no heliponto do hospital na próxima noite. Aguentem.\"",
		{"cena": "torre", "radio": "Rádio montado. Suba na torre de água: lá de cima ele alcança o Exército."}],
	["7 · AS FITAS", "Junte as fitas da Dra. Okafor (%d/5) e vá ao HELIPONTO do hospital", "chegar", 1, "heliponto", "fitas", "",
		{"local": "Escola e Igreja Matriz",
		"radio": "O helicóptero vem. Se puder, junte as fitas da doutora pelo caminho. Depois, heliponto do hospital."}],
	["8 · A ÚLTIMA NOITE", "Aguente no heliponto até o helicóptero chegar", "sobreviveu", 1, "heliponto", "", "",
		{"local": "Heliponto do hospital", "radio": "Eles estão vindo. Todos eles. Aguente firme até o helicóptero chegar!"}],
	["8 · A ÚLTIMA NOITE", "CORRA PARA O HELICÓPTERO!", "chegar", 1, "helicoptero", "helicoptero", "",
		{"radio": "O helicóptero pousou! Corre, corre!"}],
]
## O que cada fita conta (pega a fita -> legenda), na ordem em que você acha.
const FITAS_TXT: Array = [
	"Dia 3. Quarenta pacientes com febre e pele cinzenta. Todos comeram pão da padaria que usa o milho da Hollis Feed.",
	"Dia 6. A Halverson Agro mandou dois homens buscar as amostras. Disseram que o milho era 'experimental'.",
	"Dia 9. O primeiro morto levantou no necrotério. O Exército fechou as estradas na mesma noite.",
	"Dia 12. O fungo está no milho. A Halverson sabia desde o lote 7. Tenho os papéis e o nome de quem assinou.",
	"Dia 14. Se alguém achar isto: entregue à imprensa. A Mia, minha enfermeira, sabe onde estão as outras fitas.",
]
const TOMMY: Array = ["Socorro! Aqui! Eles estão por todo lado!"]
## 07/11: pedágio dos Corvos ("uma lata por pessoa"): perto da base deles com comida, paga sozinho e ganha trégua até
## amanhecer. Não vale no capítulo de matar o Wade.
func _pedagio() -> void:
	var c := get_tree().get_first_node_in_group("ciclo") as Ciclo
	var b: Bairro = _bairro()
	if c == null or b == null or _j.tregua_dia == c.dia or _j.mochila.conta("comida") < 1:
		return
	if _i < ROTEIRO.size() and String(ROTEIRO[_i][2]) == "morto:wade":
		return
	var base: Node3D = b.get_node_or_null("Mercado")
	if base == null or not base.has_meta("frente") or (base.get_meta("frente") as Vector3).distance_to(_j.global_position) > 22.0:
		return
	_j.mochila.tirar("comida", 1)
	_j.tregua_dia = c.dia
	legenda("WADE", PEDAGIO_VOZ, 6.0, false)


## Rádio que reage ao que você faz (06/11): chave -> [fala, s até poder repetir]
const RADIO_EV: Dictionary = {
	"sequencia": ["Nossa! Quantos foram? Continue assim, mas não faça barulho demais.", 120.0],
	"vida_baixa": ["Você está muito ferido. Use uma bandagem e saia daí.", 90.0],
	"sangrando": ["Isso é sangue? Amarra uma bandagem nisso antes que piore.", 150.0],
	"carro": ["Pegou um carro? Ótimo. Mas o motor chama atenção, cuidado.", 100000.0],
	"amanheceu": ["Amanheceu. De dia eles ficam mais lentos. Aproveite.", 300.0],
	"refugio": ["Aí dentro você está seguro. Descanse e se cure.", 400.0],
	"fome": ["Você precisa comer alguma coisa. Procure nas cozinhas.", 240.0],
	"sede": ["Ache água. Sem água você não aguenta muito tempo.", 240.0],
}
var _radio_ev_ms: Dictionary = {}
## 06/11 (dono: "aprimore o modo história"): com o rádio quieto, a Dana conta pedaços da história, um de cada vez;
## Corvos por perto = você pega o rádio deles (Wade falando com o bando).
const LORE: Array = [
	"Sabe o que mais me assusta? A Halverson ainda não mandou ninguém procurar sobreviventes. Só as amostras.",
	"Eu cobria a feira do milho todo ano. Senoia era tranquila. Ninguém trancava a porta.",
	"Se achar algum documento da Halverson, guarde. Cada papel conta.",
	"O Exército passou por aqui na terceira noite. Atiraram em quem tossia. Em todo mundo que tossia.",
	"Às vezes eu pego rádio de outras cidades. Depois, só chiado.",
	"A Mia salvou meu sobrinho no primeiro dia. Ela não merecia isso.",
	"O Wade trabalhava na Hollis Feed. Foi ele quem dirigiu os caminhões do lote 7.",
	"O sargento Mercer prometeu evacuar a cidade. Depois trancaram o portão por fora.",
	"Escuta: se o helicóptero vier, você sobe primeiro com a Mia. Eu sou só a mensageira.",
	"Promete uma coisa: se eu não sair daqui, conta a história por mim.",
]
const CORVOS_RADIO: Array = [
	"Aqui é o Wade. Tem um forasteiro andando pela nossa cidade. Quem trouxer a mochila dele ganha munição.",
	"Corvos, atenção: os mortos estão vindo para o mercado. Segurem a porta e não desperdicem bala.",
	"Ouvi tiro no centro. Se for o forasteiro, quero ele vivo. Ele sabe onde a jornalista está.",
]
const LORE_QUIETO: float = 200.0
## 06/11 (dono): falas na hora da ação (com voz): chefe provoca, Tommy fica para trás, relógio do remédio, última noite
const MOMENTO: Dictionary = {
	"wade": ["WADE", "Então você é o forasteiro. A Halverson paga bem pela cabeça de quem fala demais. Corvos, peguem ele!"],
	"tommy_longe": ["TOMMY", "Ei, espera! Não corre tanto, eu não tenho arma!"],
	"remedio_meio": ["RÁDIO · DANA", "Metade do tempo já foi. A febre dela não vai esperar!"],
	"remedio_fim": ["RÁDIO · DANA", "Último minuto! Corre com esse remédio!"],
	"noite_meio": ["RÁDIO · DANA", "Estou ouvindo o helicóptero! Aguenta mais um pouco!"],
	"noite_fim": ["RÁDIO · DANA", "Mais trinta segundos! Não deixa eles subirem!"],
	"morte": ["RÁDIO · DANA", "Levanta! Eu ainda preciso de você aí fora!"],
	"mercer": ["RÁDIO · DANA", "É o Mercer... ele virou um deles. Mira na cabeça!"],
}
var _momentos: Dictionary = {}  # o que já foi dito neste passo
var _tommy_ms: int = 0


func _momento(k: String, uma_vez: bool = true) -> void:
	if uma_vez and _momentos.has(k):
		return
	_momentos[k] = true
	legenda(String(MOMENTO[k][0]), String(MOMENTO[k][1]), 6.0, String(MOMENTO[k][0]).begins_with("RÁDIO"))
var _quieto_t: float = 0.0
var _lore_i: int = 0
var _corvos_ms: int = -10000000


func _radio_ev(chave: String) -> void:
	var agora: int = Time.get_ticks_msec()
	if agora - int(_radio_ev_ms.get(chave, -10000000)) < int(float(RADIO_EV[chave][1]) * 1000.0) or _i <= 0:
		return
	_radio_ev_ms[chave] = agora
	legenda("RÁDIO · DANA", String(RADIO_EV[chave][0]), 6.0)


const SIRENE_VOZ: String = "Escuta isso? Alguém ligou a sirene. Todos os mortos da cidade vão para lá."
const PEDAGIO_VOZ: String = "Uma lata. Pode passar, forasteiro. Até o sol nascer, ninguém aqui encosta em você."
const NEBLINA_VOZ: String = "Tem uma névoa vermelha descendo sobre a cidade. Eles estão diferentes hoje, mais rápidos. Se esconde."
const NOITE_VOZ: String = "Escureceu. De noite eles correm e ouvem mais longe. Fique perto de um refúgio."
const DICA_VOZ: Array = ["Ainda está aí? Olhe o mapa: eu marquei para onde você tem que ir."]
## Falas soltas com voz ("QUEM|texto"; o que vai entre parênteses na legenda não é falado).
const EXTRAS: Array = ["MIA|...Alex... não estou... aguentando...", "WADE|Corvos, comigo!"]


## Quem fala (para escolher a voz) pelo nome que aparece na legenda.
static func quem(nome: String) -> String:
	var n: String = nome.to_upper()
	for par: Array in [["MILITAR", "militar"], ["CORVOS", "wade"], ["DANA", "dana"], ["MIA", "mia"], ["TOMMY", "tommy"], ["WADE", "wade"],
			["FITA", "okafor"], ["OKAFOR", "okafor"]]:
		if n.contains(par[0]):
			return par[1]
	return "narrador"


## "1 · A PRIMEIRA NOITE" -> "Capítulo 1. A primeira noite." (o narrador lê no cartão do capítulo)
static func capitulo_falado(cap: String) -> String:
	var num: String = cap.get_slice(" · ", 0)
	var nome: String = cap.get_slice(" · ", 1).to_lower()
	nome = nome.left(1).to_upper() + nome.substr(1)
	return ("Prólogo. " if num == "0" else "Capítulo %s. " % num) + nome + "."
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
var _marcador: _Marcador
var _radio: _Radio
var _fundo: Panel
var _bip: AudioStreamPlayer
var _legenda_t: float = 0.0
var _ultima_fala: Array = []
var _fila_radio: Array = []  # [nome, texto, tempo, pelo_radio] esperando a vez (uma fala por vez)
var _check: Vector3 = Vector3.INF  # checkpoint: onde volta ao morrer (último passo feito)
var _morto: bool = false
var _cfg: Dictionary = {}           # config do passo da vez (8ª coluna)
var _onda_nos: Array = []           # zumbis vivos da luta obrigatória
var _onda_resta: int = 0
var _onda_mortos: int = 0
var _onda_total: int = 0
var _onda_centro: Vector3 = Vector3.INF
var _onda_proxima: float = 0.0
var _timer_t: float = -1.0
var _chefe_barra: ProgressBar
var _chefe_nome: Label
var _chefe_fase: bool = false
var _opcional: Label
var _parado_t: float = 0.0          # tempo no passo (dica da Dana)
var _stats := {"abates": 0, "mortes": 0, "tempo": 0.0}
var _trofeus: Dictionary = {}
var _morreu_no_passo: bool = false
var _chiado: AudioStreamPlayer


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
	_fundo = Panel.new()  # 06/11 (dono: "layout mais bonito"): cartão escuro arredondado com faixa laranja
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.05, 0.06, 0.05, 0.62)
	est.set_corner_radius_all(10)
	est.border_width_left = 5
	est.border_color = Color(1.0, 0.62, 0.2, 0.95)
	est.shadow_color = Color(0, 0, 0, 0.35)
	est.shadow_size = 6
	_fundo.add_theme_stylebox_override("panel", est)
	_fundo.size = Vector2(430, 62)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	_titulo = UiTema.rotulo("HISTÓRIA", 19, Color(1.0, 0.68, 0.2))
	_titulo.autowrap_mode = TextServer.AUTOWRAP_OFF  # sem largura, quebrava letra por letra (vídeo do dono)
	_titulo.position = Vector2(16, 4)
	add_child(_titulo)
	_linha = UiTema.rotulo("", 16, Color(1, 1, 1, 0.95))
	_linha.position = Vector2(18, 32)
	_linha.autowrap_mode = TextServer.AUTOWRAP_OFF
	_linha.size = Vector2(500, 28)
	_linha.clip_text = true
	add_child(_linha)
	_marcador = _Marcador.new()  # 07/11: alvo do objetivo na tela com a distância (jogo de história)
	_marcador.top_level = true
	_marcador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marcador)
	_radio = _Radio.new()  # 06/11 (dono): rádio no canto o tempo todo; apita, acende e fala com chiado
	_radio.top_level = true
	_radio.mouse_filter = Control.MOUSE_FILTER_STOP  # tocar no rádio repete a última fala
	_radio.position = Vector2(12, 300)
	_radio.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			repete())
	add_child(_radio)
	_bip = AudioStreamPlayer.new()
	_bip.stream = load("res://assets/sons/radio_bip.wav")
	_bip.volume_db = -4.0
	add_child(_bip)
	_fundo.size = Vector2(516, 64)
	_opcional = UiTema.rotulo("", 14, Color(0.75, 0.78, 0.75))  # objetivo opcional (fitas), em cinza
	_opcional.position = Vector2(18, 58)
	_opcional.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_opcional)
	var topo := VBoxContainer.new()  # barra de vida do chefe no alto, no meio
	topo.top_level = true
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	topo.position = Vector2(-260, 70)
	topo.custom_minimum_size = Vector2(520, 0)
	_chefe_nome = UiTema.rotulo("", 22, Color(1.0, 0.45, 0.35))
	_chefe_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topo.add_child(_chefe_nome)
	_chefe_barra = ProgressBar.new()
	_chefe_barra.custom_minimum_size = Vector2(520, 16)
	_chefe_barra.show_percentage = false
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Color(0.75, 0.12, 0.1)
	_chefe_barra.add_theme_stylebox_override("fill", cheio)
	topo.add_child(_chefe_barra)
	topo.visible = false
	add_child(topo)
	_chiado = AudioStreamPlayer.new()
	_chiado.stream = load("res://assets/sons/amb/chiado.ogg")
	_chiado.volume_db = -10.0
	add_child(_chiado)


## Fala no rádio do canto (06/11, dono): entra na fila; na vez dela o rádio apita, acende, mostra "NOME: texto" e toca a
## voz (filtro de rádio + chiado). pelo_radio = false: fala de quem está do seu lado (sem apito nem chiado).
## Devolve em quantos segundos essa fala termina (o Npc espera isso para dizer a próxima).
func legenda(nome: String, texto: String, tempo: float = 5.0, pelo_radio: bool = true) -> float:
	var falado: String = texto.left(texto.rfind(" (")) if texto.ends_with(")") and texto.contains(" (") else texto
	var dura: float = tempo
	if Voz.tem(falado):
		dura = maxf(1.5, (load(Voz.PASTA % Voz.chave(falado)) as AudioStream).get_length() + 0.6)
	var espera: float = maxf(_legenda_t, 0.0)
	for f: Array in _fila_radio:
		espera += float(f[2])
	_fila_radio.append([nome, texto, dura, pelo_radio, falado])
	if _legenda_t <= 0.0:
		_proxima_fala()
	return espera + dura


## Tocou no rádio (06/11, dono): repete a última fala, se ele estiver quieto.
func repete() -> void:
	if not _ultima_fala.is_empty() and _legenda_t <= 0.0 and _fila_radio.is_empty():
		_fila_radio.append(_ultima_fala)
		_proxima_fala()


func _proxima_fala() -> void:
	if _fila_radio.is_empty():
		_radio.fala("", "", false)
		_chiado.stop()
		return
	var f: Array = _fila_radio.pop_front()
	_ultima_fala = f
	_legenda_t = float(f[2])
	_radio.fala(String(f[0]), String(f[1]), bool(f[3]))
	if bool(f[3]):
		_bip.play()
		if _chiado.stream:
			_chiado.volume_db = -20.0  # chiado baixinho por baixo da voz
			_chiado.play()
	Voz.fala(String(f[4]), self, bool(f[3]))


func liga(j: Jogador) -> void:
	_j = j
	j.item_pego.connect(func(t: String, _q: int) -> void: evento(t))
	j.revistou.connect(func() -> void: evento("revistou"))
	j.abateu.connect(func() -> void:
		_stats.abates += 1
		evento("abateu"))
	j.item_pego.connect(func(t: String, _q: int) -> void:
		if t == "sequencia" and _q >= 5:
			_radio_ev("sequencia")
		if t == "fita":  # cada fita conta um pedaço do que aconteceu
			var n: int = _fitas()
			legenda("FITA %d/5 · DRA. OKAFOR" % n, FITAS_TXT[clampi(n - 1, 0, FITAS_TXT.size() - 1)], 9.0, false)
			if n >= FITAS:
				_trofeu("Toda a verdade: as 5 fitas"))
	j.entrou_segura.connect(func(sim: bool) -> void:
		if sim:
			_radio_ev("refugio")
			evento("segura"))
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and principal.has_method("_testando") and principal._testando():
		_i = 1  # teste: sem a abertura da estrada e sem o salvo
	else:
		_salvo = "user://historia_%s.cfg" % j.nick.validate_filename()
		var cf := ConfigFile.new()
		if cf.load(_salvo) == OK:
			_i = int(cf.get_value("historia", "passo", 0))
			_check = cf.get_value("historia", "check", Vector3.INF)
			_stats = cf.get_value("historia", "stats", _stats)
			ng = int(cf.get_value("historia", "ng", 0))
			_tira_mochila(cf)
			if _check.is_finite():  # 07/11: voltando ao jogo, começa no último checkpoint da história
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					if _j and is_instance_valid(_j) and _j.vida > 0:
						_j.global_position = _check + Vector3(0, 0.3, 0)
						_j.velocity = Vector3.ZERO)
			if _i > 1 and _i - 1 < ROTEIRO.size():  # voltando ao jogo: "anteriormente..."
				var antes: String = String(ROTEIRO[_i - 1][6]) if String(ROTEIRO[_i - 1][6]) != "" else String(ROTEIRO[_i - 1][1])
				get_tree().create_timer(2.5).timeout.connect(func() -> void: legenda("ANTERIORMENTE", antes.replace("%d", "?"), 7.0, false))
	_comeca()


## 07/11 (dono): fechar o app não perde mais o loot: a mochila (itens, balas no pente, colete, pilha) vai junto no salvo
## da história, a cada passo e sozinha a cada MOCHILA_A_CADA s.
const MOCHILA_A_CADA: float = 60.0
var _mochila_t: float = MOCHILA_A_CADA


func _poe_mochila(cf: ConfigFile) -> void:
	if _j == null or not is_instance_valid(_j):
		return
	cf.set_value("mochila", "espacos", _j.mochila.espacos.duplicate(true))
	var balas: Dictionary = {}
	for t: String in _j.fogos:
		balas[t] = (_j.fogos[t] as Pistola).balas
	cf.set_value("mochila", "balas", balas)
	cf.set_value("mochila", "colete", _j.colete)
	cf.set_value("mochila", "carga", _j.carga)


func _tira_mochila(cf: ConfigFile) -> void:
	if not cf.has_section_key("mochila", "espacos"):
		return
	var esp: Array = cf.get_value("mochila", "espacos", [])
	for k in mini(esp.size(), Mochila.ESPACOS):
		_j.mochila.espacos[k] = esp[k]
	var balas: Dictionary = cf.get_value("mochila", "balas", {})
	for t: String in balas:
		if _j.fogos.has(t):
			(_j.fogos[t] as Pistola).balas = int(balas[t])
	_j.colete = float(cf.get_value("mochila", "colete", 0.0))
	_j.carga = float(cf.get_value("mochila", "carga", 100.0))
	_j.mochila.mudou.emit()


## 07/11: app indo para o fundo (celular), janela fechando ou foco saindo: salva a mochila na hora.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_salva_mochila(true)


## Salva só a mochila (sem mexer no passo nem avisar), de tempo em tempo.
## 12/11 anti-lag: o arquivo fica em memória e a gravação vai para outra linha de execução (gravar no celular trava o
## quadro); `ja` = grava na hora (app indo para o fundo/fechando: pode não ter depois).
static var _trava := Mutex.new()
var _cf_salvo: ConfigFile


func _salva_mochila(ja: bool = false) -> void:
	if _salvo == "" or _j == null or _j.vida <= 0:
		return
	if _cf_salvo == null:
		_cf_salvo = ConfigFile.new()
		_cf_salvo.load(_salvo)
	_poe_mochila(_cf_salvo)
	_grava(_cf_salvo, ja)


func _grava(cf: ConfigFile, ja: bool) -> void:
	if ja:
		_trava.lock()
		cf.save(_salvo)
		_trava.unlock()
		return
	var txt: String = cf.encode_to_text()
	var caminho: String = _salvo
	WorkerThreadPool.add_task(func() -> void:
		_trava.lock()
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		if f:
			f.store_string(txt)
			f.close()
		_trava.unlock())


func _salva() -> void:
	if _salvo == "":
		return
	var cf := ConfigFile.new()
	cf.set_value("historia", "passo", _i)
	if _check.is_finite():
		cf.set_value("historia", "check", _check)
	cf.set_value("historia", "stats", _stats)
	cf.set_value("historia", "ng", ng)
	_poe_mochila(cf)
	_cf_salvo = cf
	_grava(cf, false)
	var c := get_parent()
	if c and c.has_method("aviso"):
		get_tree().create_timer(7.5).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.aviso("JOGO SALVO", Color(0.6, 0.9, 0.6), 1.5))


func _comeca() -> void:
	_feito = 0
	_momentos.clear()
	if _i < ROTEIRO.size():
		var r: Array = ROTEIRO[_i]
		_atual = [r[2], r[3], r[1]]
		_cfg = r[7] if r.size() > 7 else {}
		_titulo.text = "HISTÓRIA · CAP. " + String(r[0])
		if String(r[0]) != _cap:
			if _cap != "":
				_cartao("CAPÍTULO " + String(r[0]) + "\n" + _hora() + ("  ·  " + String(_cfg.local) if _cfg.has("local") else ""))
				Voz.fala(capitulo_falado(String(r[0])), self)
			_cap = String(r[0])
		_prepara(String(r[5]))
		_alvo = _onde(String(r[4]))
		Minimapa.destino = _alvo
		_parado_t = 0.0
		_morreu_no_passo = false
		_timer_t = float(_cfg.get("timer", -1.0))
		_chefe_fase = false
		if _cfg.has("ondas"):
			_comeca_luta()
		if _cfg.has("cena") and _onde(String(_cfg.cena)).is_finite():
			_cena(_onde(String(_cfg.cena)))
		if _cfg.get("susto", false):
			_susto()
		if _cfg.has("radio"):  # 06/11 (dono): o objetivo chega pelo rádio, com voz
			legenda("RÁDIO · DANA", String(_cfg.radio), 6.0)
		if String(r[2]) == "peca_radio" and _j:
			_feito = _j.mochila.conta("peca_radio")
	else:
		_atual = DEPOIS[randi() % DEPOIS.size()]
		_titulo.text = "TAREFAS"
		_alvo = Vector3.INF
	_mostra()


func _mostra() -> void:
	var texto: String = String(_atual[2])
	if _atual[0] == "limpou":
		texto = texto % [_onda_mortos, _onda_total]
	elif texto.count("%d") == 2:
		texto = texto % [_feito, int(_atual[1])]
	elif texto.count("%d") == 1:
		texto = texto % (_fitas() if _atual[0] == "chegar" else _feito)
	if _timer_t >= 0.0:
		texto += "  (%d:%02d)" % [int(_timer_t) / 60, int(_timer_t) % 60]
	_linha.text = "•  " + texto
	var achou: int = _fitas()
	_opcional.text = "Opcional: fitas da Dra. Okafor %d/5" % achou if _i >= 8 and _i < ROTEIRO.size() and achou < FITAS else ""
	_fundo.size.y = 86.0 if _opcional.text != "" else 64.0


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
	elif alvo == "eu":
		return _j.global_position if _j else Vector3.INF
	elif alvo == "dentro" and b.marcos_pos.has("quarentena"):
		return b.marcos_pos.quarentena + Vector3(0, 0, 30)
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
		"facao_inicio":  # 06/11 (dono): nasce sem nada; o primeiro facão fica a uns 35 m, num lugar andável
			var de: Vector3 = _j.global_position if _j else Bairro.ORIGEM
			var a: float = randf() * TAU
			_solta("facao", _chao(de + Vector3(cos(a), 0, sin(a)) * 35.0))
		"delegacia":  # raid: a pistola fica no arsenal (meio da delegacia), com munição do lado
			var d: Vector3 = _onde("raid:DELEGACIA")
			if not d.is_finite():
				d = _chao((_j.global_position if _j else Bairro.ORIGEM) + Vector3(60, 0, 0))
			_solta("municao", _chao(d + Vector3(1.2, 0, 0.6)))
			_solta("pistola", _chao(d))
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
		"tommy":  # sobrevivente cercado numa rua perto da van (luta + escolta)
			var p2: Vector3 = _chao(_npc.dana.global_position + Vector3(70, 0, 40)) if _npc.has("dana") else _chao(Bairro.ORIGEM + Vector3(55, 0, 265))
			_poe_npc("tommy", "TOMMY", TOMMY, p2)
		"helicoptero":
			for k: Array in [["dana", "DANA PRICE", Vector3(3, 0, 2)], ["mia", "MIA", Vector3(-3, 0, 2)]]:  # elas embarcam com você
				if k[0] == "dana" and dana_morreu:
					continue  # 07/11: a Dana ficou na última noite
				if not _npc.has(k[0]):
					_poe_npc(k[0], k[1], [], _heliponto + k[2])
				(_npc[k[0]] as Npc).falou = true
				(_npc[k[0]] as Node3D).global_position = _chao(_heliponto + k[2])
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
	if fala != "":
		var dois: int = fala.find(": ")
		legenda(fala.left(dois) if dois > 0 and dois < 24 else "", fala.substr(dois + 2) if dois > 0 and dois < 24 else fala, 8.0, fala.begins_with("RÁDIO"))
	if c and c.has_method("aviso"):
		c.aviso("OBJETIVO CONCLUÍDO", UiTema.DESTAQUE, 2.0)
	if _j and _j.vida > 0 and _j.carro == null:
		_check = _j.global_position
	var premio: Array = _cfg.get("premio", [])
	for k in range(0, premio.size(), 2):  # recompensa do passo (arma, munição...)
		_j.ganhar(String(premio[k]), int(premio[k + 1]))
	if premio.size() > 0 and c and c.has_method("aviso"):
		get_tree().create_timer(4.5).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.aviso("RECOMPENSA: " + Mochila.NOMES.get(String(premio[0]), String(premio[0])), Color(0.55, 0.85, 1.0), 2.5))
	if tipo == "limpou" and not _morreu_no_passo:
		_trofeu("Sem um arranhão: luta sem morrer")
	if tipo.begins_with("morto:"):
		_trofeu("Derrubou " + ("Wade Harlan" if tipo == "morto:wade" else "o Sargento Mercer"))
	if Minimapa.destino == _alvo:
		Minimapa.destino = Vector3.INF
	_i += 1
	if _i == ROTEIRO.size():
		_trofeu("Saiu de Senoia")
		_fim()
	_salva()
	_comeca()


func _fim() -> void:
	var f := Final.new()
	f.bom = _fitas() >= FITAS
	f.dana_viva = not dana_morreu
	f.stats = "Tempo: %d min    Zumbis mortos: %d    Mortes: %d    Fitas: %d/5    Troféus: %d" % [
		int(_stats.tempo / 60.0), _stats.abates, _stats.mortes, _fitas(), _trofeus.size()]
	f.novo_jogo_mais.connect(novo_jogo_mais)
	get_tree().root.add_child(f)


## 07/11 (ideia aprovada): Novo Jogo+: a história recomeça do capítulo 1 com a sua mochila; a cada volta (ng) os
## zumbis batem e aguentam mais (Zumbi._aplica / Jogador._recebe_dano). Salvo junto com a história.
static var ng: int = 0


func novo_jogo_mais() -> void:
	ng += 1
	for n: Variant in _npc.values():
		if n and is_instance_valid(n):
			(n as Node).queue_free()
	_npc.clear()
	if _heli and is_instance_valid(_heli):
		_heli.queue_free()
	_heli = null
	_itens.clear()
	_chefe.clear()
	_cap = ""
	_i = 1
	_check = _j.global_position
	_comeca()
	_salva()
	var c := get_parent()
	if c and c.has_method("aviso"):
		c.aviso("NOVO JOGO+ %d: SENOIA ESTÁ MAIS PERIGOSA" % ng, Color(1.0, 0.4, 0.3), 4.0)


func _process(dt: float) -> void:
	_t -= dt
	if _legenda_t > 0.0:
		_legenda_t -= dt
		if _legenda_t <= 0.0:
			_proxima_fala()
	if _j == null or not is_instance_valid(_j) or _atual.is_empty():
		return
	_marcador.jogador = _j
	# checkpoint: morreu e voltou -> renasce no último passo feito da história
	_stats.tempo += dt
	if _j.vida <= 0:
		if not _morto:
			_stats.mortes += 1
			_morreu_no_passo = true
			if _i < ROTEIRO.size():
				_momento("morte", false)
				legenda("VOCÊ MORREU", "Volta no último checkpoint. Objetivo: " + String(ROTEIRO[_i][1]).replace(" (%d/%d)", "").replace(" (%d/3)", "").replace(" (%d/5)", ""), 5.0, false)
		_morto = true
	elif _morto:
		_morto = false
		if _check.is_finite() and _j.carro == null:
			_j.global_position = _check + Vector3(0, 0.3, 0)
			_j.velocity = Vector3.ZERO
			var c := get_parent()
			if c and c.has_method("aviso"):
				c.aviso("DE VOLTA AO ÚLTIMO CHECKPOINT", UiTema.DESTAQUE, 2.5)
	var ev: String = String(_atual[0])
	if ev == "sobreviveu":
		_noite_final(dt)
	if _timer_t >= 0.0:
		_timer_t -= dt
		var total: float = float(_cfg.get("timer", 300.0))
		if _timer_t < total * 0.5:
			_momento("remedio_meio")
		if _timer_t < 60.0:
			_momento("remedio_fim")
		if _timer_t <= 0.0:  # não deu tempo: recomeça o passo do checkpoint
			_timer_t = float(_cfg.get("timer", 300.0))
			legenda("MIA", "...Alex... não estou... aguentando... (tempo esgotado: tente de novo)", 5.0, false)
			if _check.is_finite():
				_j.global_position = _check + Vector3(0, 0.3, 0)
	_chefe_ui()
	if _onda_total > 0 and ev == "limpou":
		_luta(dt)
	_parado_t += dt
	if _parado_t > 150.0 and _alvo.is_finite():  # perdido: a Dana dá a direção pelo rádio
		_parado_t = 0.0
		var rumo: Vector3 = _alvo - _j.global_position
		legenda("RÁDIO · DANA", DICA_VOZ[0] + " (fica ao %s, uns %d m)" % [Horda.lado(rumo), int(rumo.length() / 10.0) * 10], 6.0)
	_mochila_t -= dt
	if _mochila_t <= 0.0:
		_mochila_t = MOCHILA_A_CADA
		_salva_mochila()
	if _t > 0.0:
		return
	_t = 0.4
	if _j.vida > 0 and _j.vida < 30:
		_radio_ev("vida_baixa")
	_quieto_t = _quieto_t + 0.4 if _legenda_t <= 0.0 and _fila_radio.is_empty() else 0.0
	if _quieto_t > LORE_QUIETO and _i > 5 and _lore_i < LORE.size():
		_quieto_t = 0.0
		legenda("RÁDIO · DANA", String(LORE[_lore_i]), 7.0)
		_lore_i += 1
	if Time.get_ticks_msec() - _corvos_ms > 300000:
		for z: Node in get_tree().get_nodes_in_group("zumbis"):
			if (z as Zumbi).humano() and (z as Zumbi).vida > 0 and (z as Node3D).global_position.distance_to(_j.global_position) < 70.0:
				_corvos_ms = Time.get_ticks_msec()
				legenda("RÁDIO DOS CORVOS · WADE", String(CORVOS_RADIO[randi() % CORVOS_RADIO.size()]), 7.0)
				break
	if _j.sangrando:
		_radio_ev("sangrando")
	_pedagio()
	if _j.carro:
		_radio_ev("carro")
	if _j.fome < 20.0:
		_radio_ev("fome")
	if _j.sede < 20.0:
		_radio_ev("sede")
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var noite: bool = ciclo.e_noite()
		if _era_noite and not noite:
			evento("amanheceu")
			_radio_ev("amanheceu")
		if noite and not _era_noite and _i > 0:  # 06/11: a Dana avisa a noite pelo rádio
			legenda("RÁDIO · DANA", NEBLINA_VOZ if ciclo.clima == "neblina_vermelha" else NOITE_VOZ, 6.0)
			if randf() < 0.25 and _servidor():  # 07/11: sirene da cidade chama a horda para um ponto (às vezes)
				var a: float = randf() * TAU
				var p: Vector3 = _chao(_j.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(60.0, 120.0))
				var sr := Sirene.new()
				get_tree().get_first_node_in_group("principal").add_child(sr)
				sr.global_position = p
				legenda("RÁDIO · DANA", SIRENE_VOZ + " (fica ao %s, uns %d m)" % [Horda.lado(p - _j.global_position), int(p.distance_to(_j.global_position) / 10.0) * 10], 6.0)
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
		"escolta":
			var tm: Npc = _npc.get("tommy")
			if tm and tm.global_position.distance_to(_j.global_position) > 14.0 and Time.get_ticks_msec() - _tommy_ms > 20000:
				_tommy_ms = Time.get_ticks_msec()
				_momento("tommy_longe", false)
			var tommy: Npc = _npc.get("tommy")
			var dana: Node3D = _npc.get("dana")
			if tommy and tommy.segue == null:
				tommy.segue = _j
			# Tommy para a 2,5 m de você: vale chegar com ele perto da van (antes exigia ele colado nela e travava)
			if tommy and dana and tommy.global_position.distance_to(dana.global_position) < PERTO + 4.0:
				tommy.segue = null
				evento("escolta")
			_mostra()
		"remedio":
			_mostra()
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
## 07/11: consequência — longe do heliponto mais que DANA_SOZINHA s durante a defesa, a Dana morre (final muda).
const DANA_SOZINHA: float = 30.0
const DANA_MORRE: String = "Eles entraram! Alex, eles estão em todo lugar... corre! Salva a Mia, por favor!"
var dana_morreu: bool = false
var _longe_t: float = 0.0


func _noite_final(dt: float) -> void:
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	var noite: bool = ciclo != null and ciclo.e_noite()
	var perto: bool = _heliponto.is_finite() and _heliponto.distance_to(_j.global_position) < HELIPONTO_RAIO
	if not noite:
		_linha.text = "•  Espere ANOITECER no heliponto do hospital"
		return
	if not perto:
		_linha.text = "•  Volte para o HELIPONTO! A Dana está sozinha! (%d s)" % int(maxf(DANA_SOZINHA - _longe_t, 0.0))
		if _resiste_t > 0.0 and not dana_morreu:  # 07/11: longe demais com a defesa começada: os mortos pegam a Dana
			_longe_t += dt
			if _longe_t > DANA_SOZINHA:
				dana_morreu = true
				legenda("RÁDIO · DANA", DANA_MORRE, 6.0)
				var dn: Node = _npc.get("dana")
				if dn and is_instance_valid(dn):
					(dn as Node).queue_free()
				_npc.erase("dana")
		return
	_longe_t = 0.0
	_resiste_t += dt
	if _resiste_t > NOITE_FINAL_T * 0.5:
		_momento("noite_meio")
	if _resiste_t > NOITE_FINAL_T - 30.0:
		_momento("noite_fim")
	_linha.text = "•  Aguente no heliponto: %d s" % int(maxf(NOITE_FINAL_T - _resiste_t, 0.0))
	_onda_t -= dt
	if _onda_t <= 0.0 and _servidor():
		_onda_t = ONDA_A_CADA
		var principal := get_tree().get_first_node_in_group("principal")
		for k in ONDA_ZUMBIS:
			var a: float = randf() * TAU
			principal.zumbi_na_fila({"pos": _chao(_heliponto + Vector3(cos(a), 0, sin(a)) * randf_range(28.0, 40.0)) + Vector3(0, 0.1, 0), "horda": Zumbi.DO_MORTO}, _da_alvo)
	if _resiste_t >= NOITE_FINAL_T:
		evento("sobreviveu")



## Hora do dia pelo relógio do jogo (o dia vai das 6h às 18h, a noite das 18h às 6h), para o cartão do capítulo.
func _hora() -> String:
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo == null:
		return "DIA 31"
	var h: float = 6.0 + 12.0 * ciclo.tempo / Ciclo.DIA if ciclo.tempo < Ciclo.DIA else fmod(18.0 + 12.0 * (ciclo.tempo - Ciclo.DIA) / Ciclo.NOITE, 24.0)
	return "DIA 31  ·  %02d:%02d" % [int(h), int((h - int(h)) * 60.0)]


## Luta obrigatória: ondas de zumbis em volta do centro; o passo só fecha quando todas morrem. Fugiu da área: volta.
func _comeca_luta() -> void:
	var cen: String = String(_cfg.get("centro", "eu"))
	_onda_centro = _onde(cen)
	if not _onda_centro.is_finite() and _j:
		_onda_centro = _j.global_position
	var extra: int = int(String(ROTEIRO[_i][0]).left(1)) if String(ROTEIRO[_i][0]).left(1).is_valid_int() else 0
	_onda_resta = int(_cfg.ondas)
	_onda_mortos = 0
	_onda_total = int(_cfg.ondas) * (int(_cfg.zumbis) + extra)  # cada capítulo, ondas um pouco maiores
	_onda_nos.clear()
	_onda_proxima = 2.0
	_alvo = _onda_centro


## Zumbi da fila de nascimento (main.zumbi_na_fila) chegou: vem atrás de você / entra na onda da luta.
func _da_alvo(z: Zumbi) -> void:
	if z and _j and is_instance_valid(_j):
		z.alvo = _j


func _entra_na_onda(z: Zumbi) -> void:
	if z == null:
		return
	z.alvo = _j
	z.luta = true
	_onda_nos.append(z)


func _luta(dt: float) -> void:
	for z: Variant in _onda_nos.duplicate():
		if z == null or not is_instance_valid(z) or (z as Zumbi).vida <= 0:
			_onda_nos.erase(z)
			_onda_mortos += 1
			_mostra()
	_cutuca_onda(dt)
	if _onda_centro.distance_to(_j.global_position) > float(_cfg.raio) * 2.2 and _j.carro == null:
		var c2 := get_parent()  # fugiu da luta (também entre as ondas): volta
		if c2 and c2.has_method("aviso"):
			c2.aviso("NÃO DÁ PARA FUGIR: VOLTE PARA A LUTA", Color(1.0, 0.35, 0.3), 2.5)
		_j.global_position = _chao(_onda_centro + (_j.global_position - _onda_centro).normalized() * float(_cfg.raio)) + Vector3(0, 0.3, 0)
	if _onda_nos.is_empty():
		if _onda_resta <= 0:
			_onda_total = 0
			evento("limpou")
			return
		_onda_proxima -= dt
		if _onda_proxima <= 0.0:
			_onda_proxima = 4.0
			_onda_resta -= 1
			var principal := get_tree().get_first_node_in_group("principal")
			var n: int = _onda_total / int(_cfg.ondas)
			if principal and _servidor():
				for k in n:
					var a: float = TAU * k / n + randf() * 0.4
					var dz := {"pos": _chao(_onda_centro + Vector3(cos(a), 0, sin(a)) * float(_cfg.raio) * randf_range(0.6, 0.95)) + Vector3(0, 0.1, 0), "horda": Zumbi.DO_MORTO}
					if k == 0:
						_entra_na_onda(principal.spawner_zumbis.spawn(dz))  # o primeiro já: a onda só acaba com a lista vazia
					else:
						principal.zumbi_na_fila(dz, _entra_na_onda)  # 12/11: o resto um por quadro
			var c := get_parent()
			if c and c.has_method("aviso"):
				c.aviso("ONDA %d/%d" % [int(_cfg.ondas) - _onda_resta, int(_cfg.ondas)], Color(1.0, 0.4, 0.3), 2.0)


## Zumbi da onda nunca some do jogo (dono 06/11: travou em 9/15 porque um ficou preso/perdido e a onda seguinte não vinha):
## todo segundo ele volta a te caçar; quem não chega perto em PRESO_T s (preso em parede, dormindo longe, perdido)
## reaparece no chão andável a uns 14 m de você.
const PRESO_T: float = 18.0
var _cutuca_t: float = 0.0


func _cutuca_onda(dt: float) -> void:
	_cutuca_t -= dt
	if _cutuca_t > 0.0 or _j == null or _j.vida <= 0:
		return
	_cutuca_t = 1.0
	for z: Variant in _onda_nos:
		if z == null or not is_instance_valid(z) or (z as Zumbi).vida <= 0:
			continue
		var zz: Zumbi = z
		zz.alvo = _j
		var d: float = zz.global_position.distance_to(_j.global_position)
		var melhor: float = float(zz.get_meta("luta_d", INF))
		if d < melhor - 1.0 or d < 6.0:  # está chegando: zera o relógio
			zz.set_meta("luta_d", d)
			zz.set_meta("luta_t", 0.0)
			continue
		var t: float = float(zz.get_meta("luta_t", 0.0)) + 1.0
		zz.set_meta("luta_t", t)
		if t >= PRESO_T or d > float(_cfg.raio) * 2.5:
			var a: float = randf() * TAU
			zz.global_position = _chao(_j.global_position + Vector3(cos(a), 0, sin(a)) * 14.0) + Vector3(0, 0.1, 0)
			zz.velocity = Vector3.ZERO
			zz.set_meta("luta_d", INF)
			zz.set_meta("luta_t", 0.0)


## Barra de vida do chefe no alto; na metade da vida ele chama reforço (Wade: Corvos; Mercer: zumbis).
func _chefe_ui() -> void:
	var qual: String = String(_cfg.get("chefe", ""))
	var z: Zumbi = _chefe.get(qual) if qual != "" else null
	var vivo: bool = z != null and is_instance_valid(z) and z.vida > 0
	_chefe_barra.get_parent().visible = vivo and _j.global_position.distance_to(z.global_position) < 60.0
	if not vivo:
		return
	_chefe_nome.text = "WADE HARLAN — LÍDER DOS CORVOS" if qual == "wade" else "SARGENTO COLE MERCER"
	if _j.global_position.distance_to(z.global_position) < 35.0:
		_momento(qual)  # Wade provoca; no Mercer a Dana avisa pelo rádio
	_chefe_barra.max_value = z._vida_max
	_chefe_barra.value = z.vida
	if not _chefe_fase and z.vida < z._vida_max * 0.5 and _servidor():
		_chefe_fase = true
		var principal := get_tree().get_first_node_in_group("principal")
		for k in (3 if qual == "wade" else 6):
			var a: float = TAU * k / 6.0
			var d := {"pos": _chao(z.global_position + Vector3(cos(a), 0, sin(a)) * 10.0) + Vector3(0, 0.1, 0)}
			if qual == "wade":
				d.merge({"armado": true, "tipo": "corvo", "de_raid": true})
			else:
				d.horda = Zumbi.DO_MORTO
			principal.zumbi_na_fila(d, _da_alvo)
		legenda(qual.to_upper(), "Corvos, comigo!" if qual == "wade" else "(o Sargento solta um berro que ecoa pela quarentena)", 3.5, false)


## Cena de cinema: a câmera gira em volta do lugar com as barras pretas, e volta para você.
func _cena(onde: Vector3) -> void:
	if _j == null or _j.camera == null or Rede.servidor_sem_tela:
		return
	var cam := Camera3D.new()
	_bairro().add_child(cam)
	cam.global_position = onde + Vector3(22, 14, 22)
	cam.look_at(onde + Vector3(0, 2, 0))
	cam.make_current()
	var barras := CanvasLayer.new()
	barras.layer = 15
	for cima in [true, false]:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if cima else Control.PRESET_BOTTOM_WIDE)
		r.custom_minimum_size = Vector2(0, 90)
		if not cima:
			r.position.y -= 90
		barras.add_child(r)
	get_tree().root.add_child(barras)
	_j.set_physics_process(false)
	var tw := cam.create_tween()
	tw.tween_method(func(a: float) -> void:
		cam.global_position = onde + Vector3(cos(a) * 30.0, 14.0, sin(a) * 30.0)
		cam.look_at(onde + Vector3(0, 2, 0)), 0.8, 2.2, 4.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_j):
			_j.set_physics_process(true)
			if _j.camera and _j.camera.cam:
				_j.camera.cam.make_current()
		cam.queue_free()
		barras.queue_free())


## Susto roteirizado: grito longe e zumbis atrás de você.
func _susto() -> void:
	var principal := get_tree().get_first_node_in_group("principal")
	if principal == null or _j == null:
		return
	var s := AudioStreamPlayer.new()
	s.stream = load("res://assets/sons/amb/grito.ogg")
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
	if _j.camera:
		_j.camera.tremer(0.5)
	if _servidor():
		var atras: Vector3 = -_j.global_basis.z
		for k in 4:
			principal.zumbi_na_fila({"pos": _chao(_j.global_position - atras * 7.0 + Vector3(k * 1.2 - 2.0, 0, 0)) + Vector3(0, 0.1, 0), "horda": Zumbi.DO_MORTO}, _da_alvo)


func _trofeu(nome: String) -> void:
	if _trofeus.has(nome):
		return
	_trofeus[nome] = true
	var c := get_parent()
	if c and c.has_method("aviso"):
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.aviso("TROFÉU: " + nome, Color(1.0, 0.82, 0.25), 3.5))


## Alvo do objetivo na tela (como nos jogos de história): losango amarelo onde fica Minimapa.destino, com a distância;
## atrás de você ou fora da tela, fica preso na borda.
## O rádio do canto: walkie-talkie desenhado (antena, alto-falante, luz). Parado: apagado e pequeno. Falando: a luz pisca,
## ele cresce um pouco e abre a faixa com quem fala e o texto.
class _Radio extends Control:
	var _nome: String = ""
	var _texto: String = ""
	var _radio: bool = true
	var _t: float = 0.0
	var _brilho: float = 0.0
	var _faixa: RichTextLabel

	func _ready() -> void:
		size = Vector2(60, 100)
		_faixa = RichTextLabel.new()
		_faixa.bbcode_enabled = true
		_faixa.fit_content = true
		_faixa.scroll_active = false
		_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_faixa.position = Vector2(70, 8)
		_faixa.custom_minimum_size = Vector2(440, 0)
		_faixa.size = Vector2(440, 0)
		_faixa.add_theme_font_size_override("normal_font_size", 19)
		_faixa.add_theme_font_size_override("bold_font_size", 19)
		_faixa.add_theme_color_override("font_outline_color", Color.BLACK)
		_faixa.add_theme_constant_override("outline_size", 4)
		_faixa.visible = false
		add_child(_faixa)

	func fala(nome: String, texto: String, pelo_radio: bool) -> void:
		_nome = nome
		_texto = texto
		_radio = pelo_radio
		_faixa.visible = texto != ""
		if texto != "":
			var cor: String = "#ffb347" if pelo_radio else "#9fd8ff"
			_faixa.text = ("[b][color=%s]%s[/color][/b]\n%s" % [cor, nome, texto]) if nome != "" else texto
		queue_redraw()

	func _process(dt: float) -> void:
		var alvo: float = 1.0 if _texto != "" else 0.0
		if absf(_brilho - alvo) > 0.01 or _texto != "":
			_brilho = move_toward(_brilho, alvo, dt * 4.0)
			_t += dt
			scale = Vector2.ONE * (1.0 + 0.12 * _brilho)
			queue_redraw()

	func _draw() -> void:
		var falando: bool = _texto != ""
		if falando:  # fundo da faixa do texto
			var h: float = maxf(_faixa.get_content_height() + 16.0, 60.0)
			var est := StyleBoxFlat.new()
			est.bg_color = Color(0.05, 0.07, 0.05, 0.78 * _brilho)
			est.set_corner_radius_all(10)
			est.border_width_left = 5
			est.border_color = Color(1.0, 0.6, 0.2, _brilho) if _radio else Color(0.6, 0.85, 1.0, _brilho)
			draw_style_box(est, Rect2(62, 0, 456, h))
		var a: float = 0.55 + 0.45 * _brilho
		if _brilho > 0.05 and _radio:  # brilho em volta quando fala
			draw_rect(Rect2(-4, 14, 52, 90), Color(1.0, 0.6, 0.2, 0.25 * _brilho), false, 4.0)
		draw_line(Vector2(36, 16), Vector2(40, -6), Color(0.15, 0.15, 0.14, a), 4.0)  # antena
		draw_rect(Rect2(0, 16, 44, 84), Color(0.16, 0.19, 0.14, a))  # corpo
		draw_rect(Rect2(0, 16, 44, 84), Color(0.05, 0.05, 0.05, a), false, 2.0)
		draw_rect(Rect2(6, 24, 32, 16), Color(0.85, 0.6, 0.2, 0.9) if falando else Color(0.2, 0.22, 0.18, a))  # visor
		for k in 5:  # alto-falante
			draw_line(Vector2(8, 52 + k * 7), Vector2(36, 52 + k * 7), Color(0.04, 0.05, 0.04, a), 3.0)
		var luz: Color = Color(0.25, 0.8, 0.3, a)
		if falando and _radio:
			luz = Color(1.0, 0.15, 0.1) if fmod(_t, 0.5) < 0.3 else Color(0.35, 0.05, 0.05)
		draw_circle(Vector2(8, 20), 3.5, luz)


class _Marcador extends Control:
	var jogador: Jogador

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if jogador == null or not is_instance_valid(jogador) or not Minimapa.destino.is_finite():
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var alvo: Vector3 = Minimapa.destino + Vector3(0, 1.6, 0)
		var tela: Vector2 = get_viewport().get_visible_rect().size
		var atras: bool = cam.is_position_behind(alvo)
		var q: Vector2 = cam.unproject_position(alvo)
		if atras:
			q = tela - q  # atrás: aparece do lado oposto
		var m := Rect2(Vector2(40, 90), tela - Vector2(80, 220))
		var dentro: bool = not atras and m.has_point(q)
		q = q.clamp(m.position, m.end)
		var d: float = Vector2(Minimapa.destino.x - jogador.global_position.x, Minimapa.destino.z - jogador.global_position.z).length()
		var r: float = 11.0 if dentro else 9.0
		var pts := PackedVector2Array([q + Vector2(0, -r), q + Vector2(r, 0), q + Vector2(0, r), q + Vector2(-r, 0)])
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.2, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 2.0)
		draw_string(ThemeDB.fallback_font, q + Vector2(-30, r + 22), "%d m" % roundi(d), HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color(1, 0.92, 0.5))
