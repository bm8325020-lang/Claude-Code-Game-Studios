# Tela do PvP em salas (prompt 23), na pausa: fora de sala lista as públicas, cria sala (pública ou privada, limite,
# tempo) e entra pelo código; dentro mostra o código, quem está, o relógio, o placar, COMEÇAR (dono) e SAIR.
class_name TelaSalas
extends VBoxContainer

var _corpo: VBoxContainer
var _erro: Label
var _principal: Node


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiTema.titulo("PVP", 40, UiTema.DESTAQUE))
	_erro = UiTema.rotulo("", 20, UiTema.PERIGO)
	add_child(_erro)
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 8)
	add_child(_corpo)
	_principal = get_tree().get_first_node_in_group("principal")
	_principal.salas_mudou.connect(func(erro: String) -> void:
		_erro.text = erro
		if is_visible_in_tree():
			monta())


## Refaz a página (e pede a lista de salas públicas quando está fora de sala).
func monta() -> void:
	for c in _corpo.get_children():
		c.queue_free()
	var online: bool = multiplayer.has_multiplayer_peer() and not multiplayer.is_server() \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if not online:
		_corpo.add_child(UiTema.rotulo("Entre num servidor online (JOGAR ONLINE no menu) para jogar PvP.", 22, UiTema.APAGADO))
		return
	var s: Dictionary = _principal.minha_sala()
	if s.is_empty():
		_fora()
	else:
		_dentro(s)


func _fora() -> void:
	_corpo.add_child(UiTema.rotulo("SALAS PÚBLICAS", 24, UiTema.DESTAQUE))
	if _principal.lista_salas.is_empty():
		_corpo.add_child(UiTema.rotulo("Nenhuma sala aberta agora.", 20, UiTema.APAGADO))
	for l: Dictionary in _principal.lista_salas:
		var h := HBoxContainer.new()
		var t := UiTema.rotulo("%s  %d/%d  %d min%s" % [l.nome, l.n, l.limite, l.minutos, "  (jogando)" if l.estado != "espera" else ""], 22)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var b := UiTema.botao("ENTRAR")
		var cod: String = l.codigo
		b.pressed.connect(func() -> void: _principal.pede_entrar_sala.rpc_id(1, cod))
		h.add_child(b)
		_corpo.add_child(h)
	var atualiza := UiTema.botao("ATUALIZAR")
	atualiza.pressed.connect(func() -> void: _principal.pede_lista_salas.rpc_id(1))
	_corpo.add_child(atualiza)
	_corpo.add_child(UiTema.rotulo("ENTRAR COM CÓDIGO", 24, UiTema.DESTAQUE))
	var hc := HBoxContainer.new()
	var campo := UiTema.campo("código (4 letras)")
	campo.max_length = 4
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(campo)
	var entra := UiTema.botao("ENTRAR")
	entra.pressed.connect(func() -> void: _principal.pede_entrar_sala.rpc_id(1, campo.text))
	hc.add_child(entra)
	_corpo.add_child(hc)
	_corpo.add_child(UiTema.rotulo("CRIAR SALA", 24, UiTema.DESTAQUE))
	var nome := UiTema.campo("nome da sala", "Sala de %s" % _principal.nick_local)
	nome.max_length = 24
	_corpo.add_child(nome)
	var publica := CheckButton.new()
	publica.text = "Pública (aparece na lista)"
	publica.button_pressed = true
	publica.add_theme_font_size_override("font_size", 22)
	_corpo.add_child(publica)
	var limite := _opcoes("Jogadores", Salas.LIMITES, 2)
	var tempo := _opcoes("Minutos", Salas.MINUTOS, 1)
	var cria := UiTema.botao("CRIAR SALA", true)
	cria.pressed.connect(func() -> void:
		_principal.pede_criar_sala.rpc_id(1, nome.text if nome.text.strip_edges() != "" else "Sala", publica.button_pressed,
			Salas.LIMITES[limite.selected], Salas.MINUTOS[tempo.selected]))
	_corpo.add_child(cria)
	_principal.pede_lista_salas.rpc_id(1)


func _dentro(s: Dictionary) -> void:
	var titulo := "%s  —  CÓDIGO %s  (%s)" % [s.nome, s.codigo, "pública" if s.publica else "privada"]
	_corpo.add_child(UiTema.rotulo(titulo, 24, UiTema.DESTAQUE))
	var estado: String = {"espera": "Esperando o dono começar", "jogando": "Valendo! Faltam %s" % _relogio(s.t),
		"fim": "Fim da partida"}.get(s.estado, "")
	_corpo.add_child(UiTema.rotulo("%s  ·  %d/%d jogadores  ·  %d min" % [estado, s.jogadores.size(), s.limite, int(s.tempo / 60.0)], 22))
	var nomes: Array[String] = []
	for p: int in s.jogadores:
		var j: Node = _principal.jogadores.get_node_or_null(str(p))
		nomes.append(("%s%s" % [j.nick, " (dono)" if p == s.dono else ""]) if j else "...")
	_corpo.add_child(UiTema.rotulo(", ".join(nomes), 20, UiTema.APAGADO))
	var placar: Array = _principal.placar_sala()
	if not placar.is_empty():
		_corpo.add_child(UiTema.rotulo("PLACAR (abates / mortes)", 22, UiTema.DESTAQUE))
		for l: Array in placar:
			_corpo.add_child(UiTema.rotulo("%s   %d / %d" % [l[0], l[1], l[2]], 22))
	if s.dono == multiplayer.get_unique_id() and s.estado == "espera":
		var comeca := UiTema.botao("COMEÇAR", true)
		comeca.pressed.connect(func() -> void: _principal.pede_comecar_sala.rpc_id(1))
		_corpo.add_child(comeca)
	var sai := UiTema.botao("SAIR DA SALA")
	sai.pressed.connect(func() -> void: _principal.pede_sair_sala.rpc_id(1))
	_corpo.add_child(sai)


func _opcoes(rotulo: String, valores: Array[int], i: int) -> OptionButton:
	var h := HBoxContainer.new()
	var l := UiTema.rotulo(rotulo, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(150, 56)
	for v: int in valores:
		o.add_item(str(v))
	o.selected = i
	h.add_child(o)
	_corpo.add_child(h)
	return o


static func _relogio(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
