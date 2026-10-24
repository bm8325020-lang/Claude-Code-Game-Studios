# Menu inicial da mecânica 2: nome, jogar sozinho, criar partida, ou entrar numa partida achada no Wi-Fi
# (ou digitando o IP). Feito para dedo: botões grandes.
class_name Menu
extends CanvasLayer

var main: Node  # o main.gd
var _nick: LineEdit
var _ip: LineEdit
var _lista: VBoxContainer
var _status: Label
var _t: float = 0.0


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.06, 0.07, 0.08, 0.88)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(640, 0)
	caixa.add_theme_constant_override("separation", 12)
	centro.add_child(caixa)
	var titulo := _rotulo("ZUMBI APOCALIPSE — teste de rede", 34)
	caixa.add_child(titulo)
	_nick = _campo("Seu nome", "Jogador%d" % (randi() % 900 + 100))
	caixa.add_child(_nick)
	var b_solo := _botao("JOGAR SOZINHO")
	b_solo.pressed.connect(func() -> void: main.iniciar_solo(_nome()))
	caixa.add_child(b_solo)
	var b_criar := _botao("CRIAR PARTIDA (no Wi-Fi)")
	b_criar.pressed.connect(_criar)
	caixa.add_child(b_criar)
	caixa.add_child(_rotulo("Partidas no Wi-Fi (toque para entrar):", 24))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 8)
	caixa.add_child(_lista)
	var linha := HBoxContainer.new()
	_ip = _campo("ou digite o IP", "")
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(_ip)
	var b_ip := _botao("ENTRAR")
	b_ip.custom_minimum_size.x = 180
	b_ip.pressed.connect(func() -> void: _entrar(_ip.text.strip_edges()))
	linha.add_child(b_ip)
	caixa.add_child(linha)
	_status = _rotulo("Procurando partidas...", 22)
	caixa.add_child(_status)
	main.rede.procurar()


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
		var b := _botao("Partida de %s  (%s)" % [d.nick, ip])
		b.pressed.connect(func() -> void: _entrar(ip))
		_lista.add_child(b)
	if main.rede.partidas.is_empty():
		_status.text = "Procurando partidas no Wi-Fi... (o outro aparelho precisa tocar em CRIAR PARTIDA)"


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
	var err: Error = main.entrar_partida(ip, _nome())
	if err != OK:
		_status.text = "Não deu para entrar em %s (erro %d)" % [ip, err]


func _rotulo(t: String, tam: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _campo(dica: String, valor: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = dica
	e.text = valor
	e.custom_minimum_size = Vector2(0, 72)
	e.add_theme_font_size_override("font_size", 28)
	return e


func _botao(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 88)
	b.add_theme_font_size_override("font_size", 28)
	return b
