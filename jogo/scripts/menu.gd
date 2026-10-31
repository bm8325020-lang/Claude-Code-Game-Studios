# Menu inicial: nome, CRIAR SALA, ENTRAR NUMA SALA e configurações. Quem cria hospeda o mundo no celular dele e escolhe
# quantos jogadores; os outros acham a sala na lista (busca pelo nome) ou entram pelo código.
# Visual de UiTema; feito para o dedo e funciona com mouse.
class_name Menu
extends CanvasLayer

const QUANTOS: Array[int] = [1, 2, 3, 4, 6, 8]

var main: Node  # o main.gd
var _nick: LineEdit
var _status: Label
var _lista_salas: VBoxContainer
var _paginas: Dictionary = {}  # nome -> coluna (só uma visível)

## Mensagem para mostrar quando o menu volta (ex.: "Sala não encontrada").
static var aviso_inicial: String = ""


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = UiTema.tema()
	add_child(raiz)
	var capa := TextureRect.new()  # a cidade ao anoitecer (tools/foto_capa.gd), atrás do menu
	capa.texture = load("res://assets/ui/capa.jpg")
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	raiz.add_child(capa)
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.55)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	# início
	var ini := _pagina(raiz, "inicio", 520.0)
	ini.add_child(UiTema.titulo("SEM NOME", 56, UiTema.DESTAQUE))
	ini.add_child(UiTema.rotulo("sobreviver é com você", 20, UiTema.APAGADO))
	_nick = UiTema.campo("Seu nome", "Jogador%d" % (randi() % 900 + 100))
	ini.add_child(_nick)
	_liga(ini, UiTema.botao("CRIAR SALA", true), func() -> void: _mostra("criar"))
	_liga(ini, UiTema.botao("ENTRAR NUMA SALA"), func() -> void:
		_mostra("entrar")
		_status.text = "Procurando salas..."
		main.abre_relay()
		main.relay.lista())
	_liga(ini, UiTema.botao("MODO CONSTRUÇÃO"), func() -> void: _mostra("construir"))
	_liga(ini, UiTema.botao("CONFIGURAÇÕES"), func() -> void: _mostra("config"))
	var con := _pagina(raiz, "construir", 560.0)
	con.add_child(UiTema.titulo("MODO CONSTRUÇÃO", 40, UiTema.DESTAQUE))
	con.add_child(UiTema.rotulo("Monte o seu mapa com mais de 2 mil peças. Salve, jogue nele e compartilhe.", 20, UiTema.APAGADO))
	_liga(con, UiTema.botao("COMEÇAR DO ZERO (TERRENO VAZIO)", true), func() -> void: main.construir(false, "vazio"))
	_liga(con, UiTema.botao("CONSTRUIR EM CIMA DA CIDADE"), func() -> void: main.construir(false, "cidade"))
	_liga(con, UiTema.botao("CONTINUAR MEU MAPA"), func() -> void: main.construir(true))
	_liga(con, UiTema.botao("JOGAR NO MEU MAPA"), func() -> void:
		main.nick_local = _nick.text.strip_edges()
		main.jogar_meu_mapa())
	_voltar(con)
	_monta_criar(raiz)
	_monta_entrar(raiz)
	var cfg := _pagina(raiz, "config", 760.0)
	cfg.add_child(UiTema.titulo("CONFIGURAÇÕES", 40, UiTema.DESTAQUE))
	cfg.add_child(TelaConfig.new())
	_voltar(cfg)
	# faixa de estado embaixo
	_status = UiTema.rotulo(aviso_inicial, 20, UiTema.APAGADO)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.position.y -= 46
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.custom_minimum_size.x = 900
	raiz.add_child(_status)
	aviso_inicial = ""
	main.relay_msg.connect(_relay_msg)
	_mostra("inicio")


# criar: nome da sala, pública/privada, quantos jogadores (o mundo roda neste celular)
func _monta_criar(raiz: Control) -> void:
	var pg := _pagina(raiz, "criar", 560.0)
	pg.add_child(UiTema.titulo("CRIAR SALA", 40, UiTema.DESTAQUE))
	var nome := UiTema.campo("nome da sala")
	nome.max_length = 24
	pg.add_child(nome)
	var publica := CheckButton.new()
	publica.text = "Pública (aparece na lista)"
	publica.button_pressed = true
	pg.add_child(publica)
	var h := HBoxContainer.new()
	var l := UiTema.rotulo("Jogadores na sala", 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var qtos := OptionButton.new()
	qtos.custom_minimum_size = Vector2(110, UiTema.ALTURA_BOTAO)
	for n: int in QUANTOS:
		qtos.add_item(str(n))
	qtos.selected = 3
	h.add_child(qtos)
	pg.add_child(h)
	pg.add_child(UiTema.rotulo("Privada: os amigos entram com o código que aparece na espera.", 18, UiTema.APAGADO))
	_liga(pg, UiTema.botao("CRIAR", true), func() -> void:
		var n: String = nome.text.strip_edges() if nome.text.strip_edges() != "" else "Sala de %s" % _nome()
		_status.text = "Criando a sala..."
		main.abre_relay()
		main.criar_sala_sobrev(_nome(), n, publica.button_pressed, QUANTOS[qtos.selected]))
	_voltar(pg)


# entrar: buscar pelo nome, lista das públicas, ou o código
func _monta_entrar(raiz: Control) -> void:
	var pg := _pagina(raiz, "entrar", 640.0)
	pg.add_child(UiTema.titulo("ENTRAR NUMA SALA", 40, UiTema.DESTAQUE))
	var hc := HBoxContainer.new()
	var cod := UiTema.campo("código da sala")
	cod.max_length = 4
	cod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(cod)
	var bc := UiTema.botao("ENTRAR", true)
	bc.pressed.connect(func() -> void: _entra_sala(cod.text))
	hc.add_child(bc)
	pg.add_child(hc)
	pg.add_child(UiTema.secao("SALAS PÚBLICAS"))
	var hb := HBoxContainer.new()
	var busca := UiTema.campo("buscar pelo nome")
	busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(busca)
	var bb := UiTema.botao("BUSCAR")
	bb.pressed.connect(func() -> void: main.relay.lista(busca.text))
	busca.text_submitted.connect(func(_t: String) -> void: main.relay.lista(busca.text))
	hb.add_child(bb)
	pg.add_child(hb)
	_lista_salas = VBoxContainer.new()
	_lista_salas.add_theme_constant_override("separation", 8)
	pg.add_child(_lista_salas)
	_voltar(pg)


func _relay_msg(m: Dictionary) -> void:
	if m.get("op", "") == "erro":
		_status.text = String(m.msg)
	if m.get("op", "") != "lista":
		return
	_status.text = ""
	for c in _lista_salas.get_children():
		c.queue_free()
	if m.salas.is_empty():
		_lista_salas.add_child(UiTema.rotulo("Nenhuma sala pública aberta. Crie a sua!", 20, UiTema.APAGADO))
	for l: Dictionary in m.salas:
		var b := UiTema.botao("%s   ·   %d/%d%s" % [l.nome, int(l.n), int(l.max), "   ·   já começou" if l.comecou else ""])
		var c: String = l.codigo
		b.pressed.connect(func() -> void: _entra_sala(c))
		_lista_salas.add_child(b)


func _entra_sala(cod: String) -> void:
	if cod.strip_edges().length() != 4:
		_status.text = "O código tem 4 letras"
		return
	_status.text = "Entrando..."
	main.entrar_sala_sobrev(_nome(), cod)


func _nome() -> String:
	var n: String = _nick.text.strip_edges()
	return n if n != "" else "Jogador"


func _pagina(raiz: Control, nome: String, largura: float = 620.0) -> VBoxContainer:
	var col := UiTema.painel_central(raiz, largura)
	_paginas[nome] = col
	return col


func _mostra(nome: String) -> void:
	for n: String in _paginas:
		UiTema.pagina(_paginas[n] as Control).visible = n == nome


# botão redondo de voltar no canto de cima à esquerda (some junto com a página)
func _voltar(col: VBoxContainer) -> void:
	var b := UiTema.botao_voltar()
	b.position = Vector2(30, 22)
	b.pressed.connect(func() -> void: _mostra("inicio"))
	UiTema.pagina(col).add_child(b)
	b.top_level = true


func _liga(pai: Control, b: Button, acao: Callable) -> void:
	b.pressed.connect(acao)
	pai.add_child(b)
