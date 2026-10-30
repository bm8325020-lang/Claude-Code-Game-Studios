# Menu inicial: nome e quatro caminhos (online, Wi-Fi, sozinho, configurações), cada um na sua página.
# Visual de UiTema; feito para o dedo (botões grandes) e funciona com mouse.
class_name Menu
extends CanvasLayer

var main: Node  # o main.gd
var _nick: LineEdit
var _ip: LineEdit
var _lista: VBoxContainer
var _status: Label
var _online: VBoxContainer
var _paginas: Dictionary = {}  # nome -> coluna (só uma visível)
var _t: float = 0.0

## Mensagem para mostrar quando o menu volta (ex.: "Não conectou no servidor").
static var aviso_inicial: String = ""


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = UiTema.tema()
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = UiTema.FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	# início
	var ini := _pagina(raiz, "inicio")
	ini.add_child(UiTema.titulo("SEM NOME", 64, UiTema.DESTAQUE))
	ini.add_child(UiTema.rotulo("sobreviver é com você", 22, UiTema.APAGADO))
	_nick = UiTema.campo("Seu nome", "Jogador%d" % (randi() % 900 + 100))
	ini.add_child(_nick)
	_liga(ini, UiTema.botao("JOGAR ONLINE", true), func() -> void: main.abrir_pvp = false; _mostra("online"); _busca_servidores())
	_liga(ini, UiTema.botao("PVP"), func() -> void: main.abrir_pvp = true; _mostra("online"); _busca_servidores())
	_liga(ini, UiTema.botao("NO WI-FI"), func() -> void: _mostra("wifi"))
	_liga(ini, UiTema.botao("SOZINHO"), func() -> void: main.iniciar_solo(_nome()))
	_liga(ini, UiTema.botao("CONFIGURAÇÕES"), func() -> void: _mostra("config"))
	# online
	var onl := _pagina(raiz, "online")
	onl.add_child(UiTema.titulo("ONLINE", 44, UiTema.DESTAQUE))
	_online = VBoxContainer.new()
	_online.add_theme_constant_override("separation", 10)
	onl.add_child(_online)
	_voltar(onl)
	# Wi-Fi
	var wif := _pagina(raiz, "wifi")
	wif.add_child(UiTema.titulo("NO WI-FI", 44, UiTema.DESTAQUE))
	_liga(wif, UiTema.botao("CRIAR PARTIDA", true), _criar)
	wif.add_child(UiTema.rotulo("Partidas achadas (toque para entrar):", 22, UiTema.APAGADO))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 10)
	wif.add_child(_lista)
	var linha := HBoxContainer.new()
	_ip = UiTema.campo("ou digite o IP")
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(_ip)
	var b_ip := UiTema.botao("ENTRAR")
	b_ip.custom_minimum_size.x = 170
	b_ip.pressed.connect(func() -> void: _entrar(_ip.text.strip_edges()))
	linha.add_child(b_ip)
	wif.add_child(linha)
	_voltar(wif)
	# configurações (a tela completa vem no prompt 0d)
	var cfg := _pagina(raiz, "config", 760.0)
	cfg.add_child(UiTema.titulo("CONFIGURAÇÕES", 44, UiTema.DESTAQUE))
	cfg.add_child(TelaConfig.new())
	_voltar(cfg)
	# faixa de estado embaixo
	_status = UiTema.rotulo(aviso_inicial, 22, UiTema.APAGADO)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.position.y -= 70
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.custom_minimum_size.x = 900
	raiz.add_child(_status)
	aviso_inicial = ""
	_mostra("inicio")
	main.rede.procurar()


func _pagina(raiz: Control, nome: String, largura: float = 620.0) -> VBoxContainer:
	var col := UiTema.painel_central(raiz, largura)
	_paginas[nome] = col
	return col


func _mostra(nome: String) -> void:
	for n: String in _paginas:
		(_paginas[n] as Control).get_parent().get_parent().visible = n == nome  # o CenterContainer da página


# botão redondo de voltar no canto de cima à esquerda (some junto com a página)
func _voltar(col: VBoxContainer) -> void:
	var b := UiTema.botao_voltar()
	b.position = Vector2(36, 28)
	b.pressed.connect(func() -> void: _mostra("inicio"))
	col.get_parent().get_parent().add_child(b)  # no CenterContainer não: fica no canto
	b.top_level = true


func _liga(pai: Control, b: Button, acao: Callable) -> void:
	b.pressed.connect(acao)
	pai.add_child(b)


func _process(dt: float) -> void:
	if not visible:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	for c in _lista.get_children():
		c.queue_free()
	for ip: String in main.rede.partidas:
		var d: Dictionary = main.rede.partidas[ip]
		var b := UiTema.botao("%s  (%s)" % [d.nick, ip])
		b.pressed.connect(func() -> void: _entrar(ip))
		_lista.add_child(b)
	if main.rede.partidas.is_empty() and _lista.get_child_count() == 0 and (_paginas["wifi"] as Control).get_parent().get_parent().visible:
		_status.text = "Procurando partidas no Wi-Fi... (o outro aparelho toca em CRIAR PARTIDA)"


# baixa a lista de servidores (arquivo no GitHub) e mostra um botão por servidor
func _busca_servidores() -> void:
	for c in _online.get_children():
		c.queue_free()
	_online.add_child(UiTema.rotulo("Buscando servidores...", 22, UiTema.APAGADO))
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(res: int, cod: int, _h: PackedStringArray, corpo: PackedByteArray) -> void:
		for c in _online.get_children():
			c.queue_free()
		var dados: Variant = JSON.parse_string(corpo.get_string_from_utf8()) if res == OK and cod == 200 else null
		if not dados is Dictionary or (dados as Dictionary).get("servidores", []).is_empty():
			_online.add_child(UiTema.rotulo("Nenhum servidor online agora.", 22, UiTema.APAGADO))
			return
		if int(dados.get("versao", 0)) != Rede.VERSAO:
			_online.add_child(UiTema.rotulo("O servidor está numa versão diferente: atualize o jogo.", 22, UiTema.PERIGO))
			return
		for s: Dictionary in dados.servidores:
			var b := UiTema.botao("%s" % s.get("nome", s.ip), true)
			b.pressed.connect(func() -> void: _entrar(String(s.ip)))
			_online.add_child(b)
		http.queue_free())
	if http.request(Rede.LISTA_URL) != OK:
		(_online.get_child(_online.get_child_count() - 1) as Label).text = "Sem internet para buscar servidores."


func _nome() -> String:
	var n: String = _nick.text.strip_edges()
	return n if n != "" else "Jogador"


func _criar() -> void:
	var err: Error = main.criar_partida(_nome())
	if err != OK:
		_status.text = "Não deu para criar a partida (erro %d)" % err


func _entrar(ip: String) -> void:
	if ip == "":
		_status.text = "Digite o IP ou escolha uma partida da lista"
		return
	if ip.begins_with("ws://") or ip.begins_with("wss://"):
		_acorda(ip)
		return
	_conecta(ip)


func _conecta(ip: String) -> void:
	var err: Error = main.entrar_partida(ip, _nome())
	if err != OK:
		_status.text = "Não deu para entrar em %s (erro %d)" % [ip, err]


# o servidor online (site grátis) dorme sem visitas: abre a página dele primeiro e só conecta quando responder
func _acorda(ip: String) -> void:
	_status.text = "Acordando o servidor (pode levar até 1 minuto)..."
	var http := HTTPRequest.new()
	http.timeout = 90.0
	add_child(http)
	http.request_completed.connect(func(res: int, _cod: int, _h: PackedStringArray, _c: PackedByteArray) -> void:
		http.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS:
			_status.text = "O servidor não respondeu. Tente de novo."
			return
		_status.text = "Entrando..."
		_conecta(ip))
	var pagina: String = ip.replace("wss://", "https://").replace("ws://", "http://").get_slice("/jogo", 0) + "/"
	if http.request(pagina) != OK:
		_status.text = "Sem internet."
