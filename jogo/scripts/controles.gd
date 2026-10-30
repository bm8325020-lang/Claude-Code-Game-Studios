# Controles: transforma teclado/mouse (PC) e toque (celular) na `entrada` do Jogador.
# PC: WASD anda, mouse gira a câmera, Shift corre, Alt anda devagar, Ctrl/C agacha, Espaço pula,
# botão esquerdo do mouse golpeia/atira, segurar o botão direito mira, 1/2 escolhe facão/pistola,
# Q troca de arma, R recarrega, Esc solta o mouse.
# Celular: analógico que aparece onde o polegar esquerdo toca (empurrado até o fim para a frente = corre);
# arrastar no lado direito gira a câmera. Poucos botões, só com ícone: ATAQUE/TIRO grande, MIRA, PULAR e
# AGACHAR sempre; RECARREGAR, PEGAR e o seletor da submetralhadora só quando servem. Trocar de arma, comer e
# beber: tocando na barra rápida. HUD limpo: barras finas no canto de cima, relógio curto, munição embaixo.
class_name Controles
extends CanvasLayer

const RAIO_STICK: float = 110.0
## Cara de filme por cima do 3D (barato: um retângulo): bordas escuras, granulado leve e, abaixo de 40% de vida,
## bordas vermelhas pulsando como coração.
const FILME := """shader_type canvas_item;
uniform float vida = 1.0;
void fragment() {
	vec2 c = (UV - 0.5) * vec2(1.0, 0.7);
	float borda = smoothstep(0.3, 0.75, length(c));
	float grao = fract(sin(dot(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	float perigo = clamp(1.0 - vida * 2.5, 0.0, 1.0);
	float pulso = 0.7 + 0.3 * sin(TIME * 7.0);
	vec3 cor = mix(vec3(0.0), vec3(0.5, 0.0, 0.0), perigo);
	COLOR = vec4(cor + vec3(grao) * 0.5, borda * (0.5 + perigo * 0.45 * pulso) + (grao - 0.5) * 0.035);
}"""
const BOTAO: float = 120.0

## O jogador controlado; os controles só aparecem (e o mouse só é capturado) quando a partida começa.
var jogador: Jogador:
	set(v):
		if jogador and jogador.dano_levado.is_connected(_levou_dano):
			jogador.dano_levado.disconnect(_levou_dano)
			jogador.item_pego.disconnect(_pegou)
			jogador.acertou_alvo.disconnect(_acertou)
		jogador = v
		visible = v != null
		if v:
			v.dano_levado.connect(_levou_dano)
			v.item_pego.connect(_pegou)
			v.acertou_alvo.connect(_acertou)
			v.infectou.connect(func() -> void: aviso("VOCÊ FOI INFECTADO — ache um antibiótico", UiTema.PERIGO))
			v.bau_aberto.connect(func(b: Bau) -> void: _tela_bau.abre(v, b))
			v.bancada_aberta.connect(func() -> void: _tela_bancada.abre(v))
			v.loja_aberta.connect(func() -> void: _tela_loja.abre(v))
			v.fabricou.connect(func(a: String, n: int) -> void:
				if n > 0:
					aviso("%s fabricada" % String(Mochila.NOMES.get(a, a)), Color(0.35, 0.6, 0.9)))
		if v != null and not toque:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
var toque: bool = false  # mostra os controles de toque

var _stick_id: int = -1
var _stick_centro: Vector2
var _stick_vec: Vector2 = Vector2.ZERO
var _olhar_id: int = -1
var _olhar_ult: Vector2
var _base: Control
var _pino: Control
var _btn_agachar: Button
var _btn_mira: Button
var _mira: Control
var _btn_atacar: _Icone
var _btn_recarregar: _Icone
var _municao: Label
var _vermelho: ColorRect
var _filme: ColorRect
var _raid_t: float = 0.0
var _raids_avisadas: Dictionary = {}
var _bilhete_t: float = 0.0
var _lidos: Dictionary = {}  # bordas escuras, granulado e bordas vermelhas pulsando com pouca vida
var _caiu: Label
var _relogio: Label
var _btn_pegar: Button
var _dica_pegar: Label
var _aviso_item: Label
var _aviso_t: float = 0.0
var _faixa: PanelContainer
var _faixa_texto: Label
var _pvp_hud: Label  # relógio e placar da partida de PvP (no alto)
var tela_salas: TelaSalas
var _espera: PanelContainer  # tela de espera da sala de sobrevivência
var _qte: _Qte  # briga com o zumbi mordendo (barra + EMPURRAR)
var _clique_qte: bool = false
var _espera_texto: Label
var _espera_botao: Button
var abre_pvp: Callable  # abre a pausa direto na página do PvP (menu: botão PVP)
var _faixa_estilo: StyleBoxFlat
var _barras: Array[_Barra] = []  # vida, fome, sede, infecção
var _faixa_t: float = 0.0
var _pausa: Control
var _barra: Array = []  # espaços 1–6 da barra rápida (TelaMochila.Espaco)
var _mochila: TelaMochila
var _tela_bau: TelaBau
var _tela_bancada: TelaBancada
var _tela_loja: TelaLoja
var _saldo: Label
var _btn_modo: Button
var _btn_dominar: _Icone
var _btn_deitar: _Icone
var _dominio: Label  # "DOMINANDO 5:32" enquanto tem domínio na casa em que você está
var _lista_faccao: VBoxContainer
var _convite: PanelContainer  # "Fulano te chamou para o grupo" + ACEITAR/RECUSAR
var _convite_t: float = 0.0
var _convite_texto: Label
var _lista_grupo: VBoxContainer
var _marcas: _Marcas
var _estilos_toque: Array[StyleBoxFlat] = []
var _toque_nos: Array[Control] = []  # tudo que _monta_toque cria (refaz ao mudar o tamanho dos botões)
var _tam_botoes: float = -1.0  # fundo dos botões de toque (transparência das configurações)


func _ready() -> void:
	_acoes()
	toque = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if toque:
		_monta_toque()
	_filme = ColorRect.new()
	_filme.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filme.material = ShaderMaterial.new()
	(_filme.material as ShaderMaterial).shader = Shader.new()
	(_filme.material as ShaderMaterial).shader.code = FILME
	add_child(_filme)
	_mira = _Mira.new()
	_mira.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mira)
	_vermelho = ColorRect.new()
	_vermelho.color = Color(0.6, 0.0, 0.0, 0.0)
	_vermelho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vermelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vermelho)
	# vida, fome, sede e infecção (só aparece infectado): barras finas com a porcentagem, no canto de cima à esquerda
	for i in 4:
		var barra := _Barra.new()
		barra.tipo = i
		barra.position = Vector2(24, 20 + i * 24)
		barra.size = Vector2(250, 16)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(barra)
		_barras.append(barra)
	_caiu = Label.new()
	_caiu.text = "VOCÊ CAIU"
	_caiu.set_anchors_preset(Control.PRESET_CENTER)
	_caiu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caiu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caiu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caiu.add_theme_font_size_override("font_size", 46)
	_caiu.add_theme_color_override("font_outline_color", Color.BLACK)
	_caiu.add_theme_constant_override("outline_size", 8)
	_caiu.visible = false
	add_child(_caiu)
	_relogio = _rotulo(20, 0.0)  # curto, no alto do meio: "DIA 4:12" / "NOITE 2:30"
	_relogio.offset_top = 14
	_relogio.visible = true
	_dominio = _rotulo(24, 0.0)
	_dominio.offset_top = 44
	_dominio.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	# "Pegar munição (24)" embaixo do meio da tela quando tem item perto; aviso "+24 munição" ao pegar
	_dica_pegar = _rotulo(22, 0.72)
	_aviso_item = _rotulo(26, 0.62)
	_municao = Label.new()
	_municao.add_theme_color_override("font_outline_color", Color.BLACK)
	_municao.add_theme_constant_override("outline_size", 6)
	_municao.anchor_left = 1.0
	_municao.anchor_right = 1.0
	_municao.anchor_top = 1.0
	_municao.anchor_bottom = 1.0
	_municao.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_municao.offset_left = -420
	_municao.offset_right = -60 if toque else -32  # no celular: acima do botão de tiro
	_municao.offset_top = -380 if toque else -84
	_municao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_municao)
	_monta_aviso()
	_monta_espera()
	_qte = _Qte.new()
	_qte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_qte.visible = false
	add_child(_qte)
	_qte.botao.pressed.connect(func() -> void:
		if jogador:
			jogador.entrada["soltar"] = true)
	_marcas = _Marcas.new()
	_marcas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marcas)
	_monta_convite()
	_monta_barra_rapida()
	_monta_pausa()
	# letras do tema também no HUD
	for l: Label in [_relogio, _municao, _dica_pegar, _aviso_item]:
		l.add_theme_font_override("font", UiTema.tema().default_font)
	_caiu.add_theme_font_override("font", UiTema.fonte_titulo())
	_caiu.add_theme_font_size_override("font_size", 64)
	_municao.add_theme_font_override("font", UiTema.fonte_titulo())
	_municao.add_theme_font_size_override("font_size", 40)
	visible = jogador != null


func _acoes() -> void:
	var mapa: Dictionary = {"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN], "esq": [KEY_A, KEY_LEFT],
		"dir": [KEY_D, KEY_RIGHT], "pular": [KEY_SPACE], "correr": [KEY_SHIFT], "agachar": [KEY_CTRL, KEY_C],
		"andar": [KEY_ALT], "pegar": [KEY_E], "dominar": [KEY_H], "deitar": [KEY_J], "comer": [KEY_F], "beber": [KEY_G], "trocar": [KEY_Q], "recarregar": [KEY_R], "mochila": [KEY_TAB], "modo": [KEY_B],
		"espaco_1": [KEY_1], "espaco_2": [KEY_2], "espaco_3": [KEY_3], "espaco_4": [KEY_4], "espaco_5": [KEY_5], "espaco_6": [KEY_6]}
	for acao: String in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for k: int in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)


func _process(dt: float) -> void:
	if jogador == null:
		return
	var e: Dictionary = jogador.entrada
	_atualiza_barras()
	(_filme.material as ShaderMaterial).set_shader_parameter("vida", float(jogador.vida) / Jogador.VIDA_MAX)
	_avisa_raid(dt)
	_le_bilhete(dt)
	_qte.jogador = jogador
	_qte.visible = jogador.mordida_t > 0.0 and jogador.mordida_zumbi != null
	if _qte.visible:
		_qte.queue_redraw()
		if Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("pegar") or (not toque and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _clique_qte):
			e["soltar"] = true
		_clique_qte = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		e["move"] = Vector2.ZERO
		return
	_atualiza_espera()
	if _espera.visible:
		e["move"] = Vector2.ZERO  # tela de espera da sala: ninguém anda
		return
	if toque:
		e["move"] = _stick_vec
		e["correr"] = _stick_vec.length() > 0.92 and _stick_vec.y > 0.6 and not jogador.agachado  # polegar no fim, para a frente
	else:
		e["move"] = Vector2(Input.get_axis("esq", "dir"), Input.get_axis("tras", "frente"))
		e["correr"] = Input.is_action_pressed("correr")
		e["andar"] = Input.is_action_pressed("andar")
		if Input.is_action_just_pressed("pular"):
			e["pular"] = true
		if Input.is_action_just_pressed("agachar"):
			e["agachar"] = true
		if Input.is_action_just_pressed("trocar"):
			e["trocar"] = true
		if Input.is_action_just_pressed("pegar"):
			e["pegar"] = true
		if Input.is_action_just_pressed("comer"):
			e["comer"] = true
		if Input.is_action_just_pressed("beber"):
			e["beber"] = true
		if Input.is_action_just_pressed("recarregar"):
			e["recarregar"] = true
		for k in Mochila.BARRA:
			if Input.is_action_just_pressed("espaco_%d" % (k + 1)):
				jogador.usar_espaco(k)
		if Input.is_action_just_pressed("mochila"):
			abre_mochila(not _mochila.visible)
	for i in _barra.size():
		var it: Variant = jogador.mochila.espacos[i]
		_barra[i].destaque = it != null and it.tipo == jogador.arma
		_barra[i].mostra(it, false)
	if toque and float(Config.v.botoes_tamanho) != _tam_botoes:
		_refaz_toque()  # tamanho mudou nas configurações: vale na hora
	for est in _estilos_toque:
		est.bg_color.a = float(Config.v.botoes_opacidade)
	if _btn_agachar:
		_btn_agachar.ligado = jogador.agachado
	if _btn_mira:
		_btn_mira.ligado = jogador.mira_travada
	_caiu.visible = jogador.vida <= 0
	if _caiu.visible:
		if jogador.resgate:
			_caiu.text = "VOCÊ CAIU\nO GRUPO PODE TE SALVAR — %d s" % ceili(maxf(jogador._morto_t, 0.0))
		else:
			_caiu.text = "VOCÊ CAIU\n" + ("voltando em %d s" % ceili(maxf(jogador._morto_t, 0.0)))
	_faixa_t -= dt
	_convite_t -= dt
	_convite.visible = _convite_t > 0.0
	var principal := get_tree().get_first_node_in_group("principal")
	_atualiza_dominio(principal)
	_marcas.amigos = principal.amigos() if principal else []
	_faixa.visible = _faixa_t > 0.0
	_faixa.modulate.a = clampf(_faixa_t * 2.0, 0.0, 1.0)
	_atualiza_pvp(principal)
	var ciclo := get_tree().get_first_node_in_group("ciclo") as Ciclo
	if ciclo:
		var f: int = int(ciclo.falta())
		_relogio.text = ("NOITE  %d:%02d" if ciclo.e_noite() else "DIA  %d:%02d") % [f / 60, f % 60]
		_relogio.add_theme_color_override("font_color", Color(0.65, 0.75, 1.0) if ciclo.e_noite() else (Color(1, 0.75, 0.4) if f < 60 else Color.WHITE))
	_vermelho.color.a = move_toward(_vermelho.color.a, 0.35 if jogador.vida <= 0 else 0.0, dt * 0.8)
	var it: Item = jogador.item_perto()
	var bau: Bau = jogador.bau_perto() if it == null else null
	var banc: Bancada = jogador.bancada_perto() if it == null and bau == null else null
	var loja: Lojista = jogador.lojista_perto() if it == null and bau == null and banc == null else null
	var porta: Porta = jogador.porta_perto() if it == null and bau == null and banc == null and loja == null else null
	_dica_pegar.visible = it != null or porta != null or bau != null or banc != null or loja != null
	_saldo.text = "$ %d" % jogador.dinheiro
	if jogador.abrindo:
		_dica_pegar.text = "ABRINDO... %d%%" % roundi((1.0 - jogador.abrindo_t / Bau.ABRIR_T) * 100.0)
	elif banc:
		_dica_pegar.text = ("BANCADA" if toque else "[E] usar a bancada")
	elif loja:
		_dica_pegar.text = ("LOJA" if toque else "[E] falar com o lojista")
	elif bau:
		_dica_pegar.text = ("REVISTAR" if toque else "[E] revistar") if bau.saco else ("ABRIR BAÚ" if toque else "[E] abrir baú")
	elif it:
		_dica_pegar.text = ("PEGAR " if toque else "[E] pegar ") + it.nome()
	elif porta:
		_dica_pegar.text = ("USAR: " if toque else "[E] ") + porta.acao()
	if _btn_pegar:
		_btn_pegar.visible = _dica_pegar.visible
	_aviso_t -= dt
	_aviso_item.visible = _aviso_t > 0.0
	_aviso_item.modulate.a = clampf(_aviso_t, 0.0, 1.0)
	var com_pistola: bool = Jogador.e_fogo(jogador.arma)
	_mira.visible = jogador.mira_travada or com_pistola or (_mira as _Mira).marca_t > 0.0
	_municao.visible = com_pistola
	if _btn_modo:
		_btn_modo.visible = jogador.arma == "smg"
		_btn_modo.ligado = jogador.smg.modo_auto
	if not toque:
		e["atirando"] = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if Input.is_action_just_pressed("modo"):
			e["modo"] = true
	if com_pistola:
		var p: Pistola = jogador.fogo()
		_municao.text = ("..." if p.recarregando else "%d / %d" % [p.balas, p.reserva]) + \
			(("  AUTO" if p.modo_auto else "  SEMI") if p.automatica and not toque else "")
		_municao.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25) if p.balas == 0 else Color(1, 1, 1, 0.92))
	if _btn_atacar:
		_btn_atacar.icone = "tiro" if com_pistola else "corte"
		_btn_recarregar.visible = com_pistola and not jogador.fogo().recarregando and jogador.fogo().balas < jogador.fogo().pente and jogador.fogo().reserva > 0


func _input(ev: InputEvent) -> void:
	if jogador == null:
		return
	if (_pausa.visible or _mochila.visible or _tela_bau.visible or _tela_bancada.visible or _tela_loja.visible) and toque:
		return  # na pausa/mochila o toque é dos botões da tela, não do analógico nem da câmera
	if (_mochila.visible or _tela_bau.visible or _tela_bancada.visible or _tela_loja.visible) and ev is InputEventMouseMotion:
		return
	if not toque:
		if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			jogador.entrada["olhar"] = (jogador.entrada["olhar"] as Vector2) + (ev as InputEventMouseMotion).relative
		elif ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
			pausa(not _pausa.visible)
		elif ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				if mb.pressed:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				jogador.entrada["mira_segurando"] = mb.pressed  # segura para mirar
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				jogador.entrada["atacar"] = true
		return
	var tela: Vector2 = get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			if t.position.x < tela.x * 0.42 and _stick_id == -1 and not _em_botao(t.position):
				_stick_id = t.index
				_stick_centro = t.position
				_base.position = t.position - _base.size * 0.5
				_base.visible = true
			elif t.position.x >= tela.x * 0.42 and _olhar_id == -1 and not _em_botao(t.position):
				_olhar_id = t.index
				_olhar_ult = t.position
		else:
			if t.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
				_base.visible = false
			elif t.index == _olhar_id:
				_olhar_id = -1
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if d.index == _stick_id:
			var v: Vector2 = (d.position - _stick_centro).limit_length(RAIO_STICK)
			_pino.position = _base.size * 0.5 + v - _pino.size * 0.5
			_stick_vec = Vector2(v.x, -v.y) / RAIO_STICK
		elif d.index == _olhar_id:
			jogador.entrada["olhar"] = (jogador.entrada["olhar"] as Vector2) + (d.position - _olhar_ult) * 1.6
			_olhar_ult = d.position


func _rotulo(tam: int, altura: float) -> Label:
	var l := Label.new()
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = altura
	l.anchor_bottom = altura
	l.offset_left = -220
	l.offset_right = 220
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l


## Faixa de aviso no alto da tela que some sozinha (servidor, itens, facção...).
## `cor` é a barrinha da esquerda: laranja = aviso, vermelho = perigo, azul = informação.
func aviso(texto: String, cor: Color = UiTema.DESTAQUE, tempo: float = 3.0) -> void:
	_faixa_texto.text = texto.to_upper()
	_faixa_estilo.border_color = cor
	_faixa_t = tempo


## Abre/fecha a pausa. O jogo não para (é em rede): só tira os controles da mão e mostra o mouse.
func pausa(abrir: bool) -> void:
	_pausa.visible = abrir
	if not toque:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if abrir else Input.MOUSE_MODE_CAPTURED
	if jogador and abrir:
		jogador.entrada["move"] = Vector2.ZERO


func _monta_barra_rapida() -> void:
	var caixa := HBoxContainer.new()
	caixa.anchor_left = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_top = 1.0
	caixa.anchor_bottom = 1.0
	var lado: float = 60.0 if toque else 66.0
	caixa.offset_left = -(lado + 6.0) * (Mochila.BARRA + 1) * 0.5 - (150.0 if toque else 0.0)  # celular: longe dos botões
	caixa.offset_top = -lado - 14.0
	caixa.add_theme_constant_override("separation", 6)
	add_child(caixa)
	for i in Mochila.BARRA:
		var e := TelaMochila.Espaco.new()
		e.indice = i
		e.numero = str(i + 1)
		e.pressed.connect(func() -> void:
			if jogador:
				jogador.usar_espaco(i))
		e.lado = lado
		e.discreto = true
		caixa.add_child(e)
		_barra.append(e)
	var b := _Icone.new()
	b.name = "Mochila"
	b.icone = "mochila"
	b.redondo = false
	b.custom_minimum_size = Vector2(lado, lado)
	b.pressed.connect(func() -> void: abre_mochila(not _mochila.visible))
	caixa.add_child(b)
	_mochila = TelaMochila.new()
	_mochila.visible = false
	add_child(_mochila)
	_tela_bau = TelaBau.new()
	_tela_bau.visible = false
	add_child(_tela_bau)
	_tela_loja = TelaLoja.new()
	_tela_loja.visible = false
	add_child(_tela_loja)
	_tela_loja.visibility_changed.connect(func() -> void:
		if not toque:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tela_loja.visible else Input.MOUSE_MODE_CAPTURED)
	_saldo = Label.new()
	_saldo.add_theme_font_override("font", UiTema.fonte_titulo())
	_saldo.add_theme_font_size_override("font_size", 24)
	_saldo.add_theme_color_override("font_color", Color(0.85, 0.8, 0.55))
	_saldo.add_theme_color_override("font_outline_color", Color.BLACK)
	_saldo.add_theme_constant_override("outline_size", 6)
	_saldo.position = Vector2(24, 92)
	add_child(_saldo)
	_tela_bancada = TelaBancada.new()
	_tela_bancada.visible = false
	add_child(_tela_bancada)
	_tela_bancada.visibility_changed.connect(func() -> void:
		if not toque:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tela_bancada.visible else Input.MOUSE_MODE_CAPTURED)
	_tela_bau.visibility_changed.connect(func() -> void:
		if not toque:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tela_bau.visible else Input.MOUSE_MODE_CAPTURED)


## Abre/fecha a tela da mochila (Tab no PC, botão MOCHILA no celular).
func abre_mochila(abrir: bool) -> void:
	_mochila.jogador = jogador
	_mochila.visible = abrir
	_mochila.move_to_front()  # por cima do HUD
	if not toque:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if abrir else Input.MOUSE_MODE_CAPTURED
	if jogador and abrir:
		jogador.entrada["move"] = Vector2.ZERO


func _monta_aviso() -> void:
	_faixa = PanelContainer.new()
	_faixa.theme = UiTema.tema()
	_faixa_estilo = StyleBoxFlat.new()
	_faixa_estilo.bg_color = Color(0.12, 0.13, 0.14, 0.9)
	_faixa_estilo.border_width_left = 6
	_faixa_estilo.content_margin_left = 28
	_faixa_estilo.content_margin_right = 28
	_faixa_estilo.content_margin_top = 12
	_faixa_estilo.content_margin_bottom = 12
	_faixa.add_theme_stylebox_override("panel", _faixa_estilo)
	_faixa.anchor_left = 0.5
	_faixa.anchor_right = 0.5
	_faixa.offset_left = -330
	_faixa.offset_right = 330
	_faixa.offset_top = 96
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.visible = false
	add_child(_faixa)
	_pvp_hud = UiTema.titulo("", 26)
	_pvp_hud.anchor_left = 0.5
	_pvp_hud.anchor_right = 0.5
	_pvp_hud.offset_left = -330
	_pvp_hud.offset_right = 330
	_pvp_hud.offset_top = 52
	_pvp_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pvp_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_pvp_hud.add_theme_constant_override("outline_size", 6)
	_pvp_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pvp_hud.visible = false
	add_child(_pvp_hud)
	_faixa_texto = UiTema.titulo("", 28)
	_faixa_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faixa.add_child(_faixa_texto)


func _atualiza_barras() -> void:
	_barras[0].valor = clampf(float(jogador.vida) / Jogador.VIDA_MAX * 100.0, 0.0, 100.0)
	_barras[1].valor = jogador.fome
	_barras[2].valor = jogador.sede
	_barras[3].valor = jogador.infeccao
	_barras[3].visible = jogador.infeccao > 0.0
	_saldo.position.y = 116.0 if _barras[3].visible else 92.0


func _monta_espera() -> void:
	_espera = PanelContainer.new()
	_espera.theme = UiTema.tema()
	_espera.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.03, 0.035, 0.04, 0.88)
	_espera.add_theme_stylebox_override("panel", fundo)
	_espera.visible = false
	add_child(_espera)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_espera.add_child(col)
	_espera_texto = UiTema.titulo("", 32)
	_espera_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_espera_texto)
	_espera_botao = UiTema.botao("COMEÇAR SOZINHO", true)
	_espera_botao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_espera_botao.custom_minimum_size.x = 420
	_espera_botao.pressed.connect(func() -> void: get_tree().get_first_node_in_group("principal").comecar_sala_sobrev())
	col.add_child(_espera_botao)


func _atualiza_espera() -> void:
	var principal := get_tree().get_first_node_in_group("principal")
	_espera.visible = principal != null and principal.esperando
	if not _espera.visible:
		return
	var s: Dictionary = principal.sala_sobrev
	var cod: String = String(s.get("codigo", ""))
	_espera_texto.text = "%s\nCÓDIGO: %s\n\n%d de %d jogadores\nEsperando todos entrarem..." % [s.get("nome", ""), cod if cod != "" else "...", int(s.get("n", 1)), int(s.get("max", 1))]
	_espera_botao.visible = multiplayer.is_server()
	_espera_botao.text = "COMEÇAR SOZINHO" if int(s.get("n", 1)) <= 1 else "COMEÇAR AGORA"
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _atualiza_pvp(principal: Node) -> void:
	var s: Dictionary = principal.minha_sala() if principal else {}
	_pvp_hud.visible = s.get("estado", "espera") != "espera"
	if not _pvp_hud.visible:
		return
	var eu: Array = [0, 0]
	for l: Array in principal.placar_sala():
		if l[0] == jogador.nick:
			eu = [l[1], l[2]]
	_pvp_hud.text = ("%s   ·   %d abates  %d mortes" % [TelaSalas._relogio(s.t), eu[0], eu[1]]) if s.estado == "jogando" else "FIM DA PARTIDA (placar na pausa: PVP)"


func _monta_pausa() -> void:
	var b := _Icone.new()
	b.icone = "pausa"
	b.name = "Pausa"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -76
	b.offset_right = -20
	b.offset_top = 14
	b.offset_bottom = 70
	b.pressed.connect(func() -> void: pausa(true))
	add_child(b)
	_pausa = Control.new()
	_pausa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pausa.theme = UiTema.tema()
	_pausa.visible = false
	add_child(_pausa)
	var fundo := ColorRect.new()
	fundo.color = Color(UiTema.FUNDO, 0.7)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pausa.add_child(fundo)
	var col := UiTema.painel_central(_pausa, 520.0)
	col.add_child(UiTema.rotulo("PAUSA", 34, UiTema.DESTAQUE))
	col.add_child(UiTema.rotulo("O jogo continua para os outros.", 20, UiTema.APAGADO))
	var cont := UiTema.botao("CONTINUAR", true)
	cont.pressed.connect(func() -> void: pausa(false))
	col.add_child(cont)
	var cfg := UiTema.botao("CONFIGURAÇÕES")
	col.add_child(cfg)
	var col_cfg := UiTema.painel_central(_pausa, 760.0)
	col_cfg.add_child(UiTema.titulo("CONFIGURAÇÕES", 40, UiTema.DESTAQUE))
	col_cfg.add_child(TelaConfig.new())
	var volta := UiTema.botao("VOLTAR", true)
	col_cfg.add_child(volta)
	var p_menu: Control = UiTema.pagina(col)
	var p_cfg: Control = UiTema.pagina(col_cfg)
	p_cfg.visible = false
	cfg.pressed.connect(func() -> void:
		p_menu.visible = false
		p_cfg.visible = true)
	volta.pressed.connect(func() -> void:
		p_cfg.visible = false
		p_menu.visible = true)
	var grupo := UiTema.botao("GRUPO")
	col.add_child(grupo)
	var col_g := UiTema.painel_central(_pausa, 620.0)
	col_g.add_child(UiTema.titulo("GRUPO", 40, UiTema.DESTAQUE))
	col_g.add_child(UiTema.rotulo("Até %d no grupo. Convide pelo nome:" % Grupos.MAX, 20, UiTema.APAGADO))
	_lista_grupo = VBoxContainer.new()
	_lista_grupo.add_theme_constant_override("separation", 8)
	col_g.add_child(_lista_grupo)
	var sai_g := UiTema.botao("SAIR DO GRUPO")
	sai_g.pressed.connect(func() -> void: get_tree().get_first_node_in_group("principal").sair_grupo())
	col_g.add_child(sai_g)
	var volta_g := UiTema.botao("VOLTAR", true)
	col_g.add_child(volta_g)
	var p_g: Control = UiTema.pagina(col_g)
	p_g.visible = false
	grupo.pressed.connect(func() -> void:
		_monta_lista_grupo()
		p_menu.visible = false
		p_g.visible = true)
	volta_g.pressed.connect(func() -> void:
		p_g.visible = false
		p_menu.visible = true)
	var fac := UiTema.botao("FACÇÃO")
	col.add_child(fac)
	var col_f := UiTema.painel_central(_pausa, 620.0)
	col_f.add_child(UiTema.titulo("FACÇÃO", 40, UiTema.DESTAQUE))
	_lista_faccao = VBoxContainer.new()
	_lista_faccao.add_theme_constant_override("separation", 8)
	col_f.add_child(_lista_faccao)
	var volta_f := UiTema.botao("VOLTAR", true)
	col_f.add_child(volta_f)
	var p_f: Control = UiTema.pagina(col_f)
	p_f.visible = false
	fac.pressed.connect(func() -> void:
		_monta_faccao()
		p_menu.visible = false
		p_f.visible = true)
	volta_f.pressed.connect(func() -> void:
		p_f.visible = false
		p_menu.visible = true)
	var pvp := UiTema.botao("PVP")  # PvP fora do menu por enquanto (pedido do dono): a página fica pronta para voltar
	var col_p := UiTema.painel_central(_pausa, 1000.0)
	tela_salas = TelaSalas.new()
	col_p.add_child(tela_salas)
	var volta_p := UiTema.botao("VOLTAR", true)
	col_p.add_child(volta_p)
	var p_p: Control = UiTema.pagina(col_p)
	p_p.visible = false
	pvp.pressed.connect(func() -> void:
		p_menu.visible = false
		p_p.visible = true
		tela_salas.monta())
	volta_p.pressed.connect(func() -> void:
		p_p.visible = false
		p_menu.visible = true)
	abre_pvp = func() -> void:
		pausa(true)
		pvp.pressed.emit()
	var sair := UiTema.botao("SAIR DA PARTIDA")
	sair.pressed.connect(func() -> void:
		pausa(false)
		get_tree().get_first_node_in_group("principal")._caiu_conexao(""))
	col.add_child(sair)


# página da facção: nome, membros e adicionar pelo nick (ou como criar, se não tem)
func _monta_faccao() -> void:
	for c in _lista_faccao.get_children():
		c.queue_free()
	var principal := get_tree().get_first_node_in_group("principal")
	var f: String = principal.faccao_de(jogador.nick)
	if f == "":
		_lista_faccao.add_child(UiTema.rotulo("Você não tem facção. Entre numa das mansões da cidade e aperte DOMINAR (bandeira). Fique %d min dentro dela." % int(Faccoes.DOMINAR_T / 60.0), 22, UiTema.APAGADO))
		return
	var d: Dictionary = principal._faccoes_cli.f[f]
	_lista_faccao.add_child(UiTema.rotulo(f.to_upper(), 30))
	_lista_faccao.add_child(UiTema.rotulo(("Casa: %s" % d.casa) if d.casa != "" else "Sem casa agora (domine outra com 1 membro em %d min)" % int(Faccoes.REDOMINAR_T / 60.0), 20, UiTema.APAGADO))
	_lista_faccao.add_child(UiTema.rotulo("Membros (%d/%d): %s" % [d.membros.size(), Faccoes.LIMITE, ", ".join(d.membros)], 20))
	if d.casa != "":
		var dias: int = ceili(float(d.prazo) / Faccoes.DIA)
		_lista_faccao.add_child(UiTema.rotulo("Fundo: $%d. Manutenção de $%d em %d dias do jogo (sem fundo = perde a casa e o baú)." % [int(d.fundo), Faccoes.MANUT_CUSTO, dias], 20))
	var dep := HBoxContainer.new()
	for v: int in [100, 1000]:
		var b := UiTema.botao("DEPOSITAR $%d" % v)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			if jogador.dinheiro >= v:
				jogador.dinheiro -= v
				principal.pede_depositar.rpc_id(1, v)
				aviso("$%d no fundo da facção" % v, Color(0.35, 0.6, 0.9))
			else:
				aviso("Sem dinheiro"))
		dep.add_child(b)
	_lista_faccao.add_child(dep)
	for j: Jogador in principal.jogadores.get_children():
		if j == jogador or principal.faccao_de(j.nick) != "":
			continue
		var linha := HBoxContainer.new()
		var nome := UiTema.rotulo(j.nick, 24)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)
		var b := UiTema.botao("ADICIONAR")
		b.pressed.connect(func() -> void:
			principal.pede_adicionar.rpc_id(1, j.nick)
			b.disabled = true)
		linha.add_child(b)
		_lista_faccao.add_child(linha)


# lista dos outros jogadores da partida: nome + CONVIDAR (ou "no seu grupo")
func _monta_lista_grupo() -> void:
	for c in _lista_grupo.get_children():
		c.queue_free()
	var principal := get_tree().get_first_node_in_group("principal")
	var meu: int = principal.grupo_de(multiplayer.get_unique_id())
	var algum: bool = false
	for j: Jogador in principal.jogadores.get_children():
		if j == jogador:
			continue
		algum = true
		var linha := HBoxContainer.new()
		var nome := UiTema.rotulo(j.nick, 24)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)
		if meu != 0 and principal.grupo_de(int(String(j.name))) == meu:
			linha.add_child(UiTema.rotulo("NO GRUPO", 20, Color(0.35, 0.6, 0.9)))
		else:
			var b := UiTema.botao("CONVIDAR")
			b.pressed.connect(func() -> void:
				var motivo: String = principal.convidar_nick(j.nick)
				aviso(motivo if motivo != "" else "Convite enviado", Color(0.35, 0.6, 0.9))
				b.disabled = true)
			linha.add_child(b)
		_lista_grupo.add_child(linha)
	if not algum:
		_lista_grupo.add_child(UiTema.rotulo("Ninguém mais na partida.", 20, UiTema.APAGADO))


## Convite recebido: faixa com ACEITAR/RECUSAR por Grupos.CONVITE_T segundos.
func convite(nick: String) -> void:
	_convite_texto.text = "%s TE CHAMOU PARA O GRUPO" % nick.to_upper()
	_convite_t = Grupos.CONVITE_T
	_convite.move_to_front()


func _monta_convite() -> void:
	_convite = PanelContainer.new()
	_convite.theme = UiTema.tema()
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.12, 0.13, 0.14, 0.92)
	est.border_width_left = 6
	est.border_color = Color(0.35, 0.6, 0.9)
	est.set_content_margin_all(14)
	_convite.add_theme_stylebox_override("panel", est)
	_convite.anchor_left = 0.5
	_convite.anchor_right = 0.5
	_convite.offset_left = -330
	_convite.offset_right = 330
	_convite.offset_top = 160
	_convite.visible = false
	add_child(_convite)
	var col := VBoxContainer.new()
	_convite.add_child(col)
	_convite_texto = UiTema.titulo("", 26)
	_convite_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_convite_texto)
	var bots := HBoxContainer.new()
	bots.add_theme_constant_override("separation", 12)
	col.add_child(bots)
	for aceita: bool in [true, false]:
		var b := UiTema.botao("ACEITAR" if aceita else "RECUSAR", aceita)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			get_tree().get_first_node_in_group("principal").responder_convite(aceita)
			_convite_t = 0.0)
		bots.add_child(b)


func _acertou(forte: bool) -> void:
	(_mira as _Mira).marca(forte)


func _pegou(tipo: String, qtd: int) -> void:
	if tipo == "antibiotico" and jogador and not jogador.infectado:
		aviso("Antibiótico tomado: a infecção parou", Color(0.45, 0.75, 0.4))
		return
	if tipo == "aprendeu":
		aviso("Receita aprendida", Color(0.35, 0.6, 0.9))
		return
	if tipo == "dinheiro":
		_aviso_item.text = "+$ %d" % qtd
		_aviso_t = 1.2
		return
	if tipo.begins_with("modo_"):
		aviso("Automático" if tipo == "modo_auto" else "Tiro a tiro", Color(0.35, 0.6, 0.9), 1.2)
		return
	var nome: String = String(Mochila.NOMES.get(tipo, tipo))
	_aviso_item.text = ("+%d %s" % [qtd, nome.to_lower()]) if qtd > 1 else nome
	_aviso_t = 1.6


func _levou_dano(dano: int) -> void:
	_vermelho.color.a = clampf(0.15 + dano * 0.012, 0.0, 0.45)


func _em_botao(p: Vector2) -> bool:
	for b: Control in [_btn_agachar, _btn_mira, _btn_atacar, _btn_recarregar, _btn_pegar, get_node_or_null("Pular") as Control,
			get_node_or_null("Pausa") as Control, get_node_or_null("Mochila") as Control, get_node_or_null("Trocar") as Control, _btn_modo, _btn_dominar, _btn_deitar] + _barra:
		if b and b.is_visible_in_tree() and b.get_global_rect().grow(10).has_point(p):
			return true
	return false


# casa em que você está: botão DOMINAR (se dá) e o relógio do domínio em andamento
func _atualiza_dominio(principal: Node) -> void:
	var casa: String = principal.bairro.casa_em(jogador.global_position) if principal and principal.bairro and jogador.vida > 0 else ""
	var tent: Variant = principal._faccoes_cli.t.get(casa) if casa != "" else null
	var minha: String = principal.faccao_de(jogador.nick) if principal else ""
	var dona: String = ""
	if casa != "":
		for n: String in principal._faccoes_cli.f:
			if principal._faccoes_cli.f[n].casa == casa:
				dona = n
	var pode: bool = casa != "" and principal.bairro.dominavel(casa) and tent == null and (minha == "" or dona != minha)
	if _btn_dominar:
		_btn_dominar.visible = pode
	if pode and not toque and Input.is_action_just_pressed("dominar"):
		principal.pede_dominar.rpc_id(1)
	_dominio.visible = tent != null or (casa != "" and dona != "")
	if tent != null:
		var f: int = ceili(float(tent.t))
		_dominio.text = "DOMINANDO  %d:%02d" % [f / 60, f % 60]
	elif _dominio.visible:
		_dominio.text = "CASA DA %s" % dona.to_upper()
	if pode and not toque and not _dica_pegar.visible:
		_dica_pegar.visible = true
		_dica_pegar.text = "[H] dominar a casa"
	var cama: bool = jogador.deitado or jogador.cama_perto() != Vector3.INF
	if _btn_deitar:
		_btn_deitar.visible = cama
		_btn_deitar.ligado = jogador.deitado
	if cama and not toque:
		if Input.is_action_just_pressed("deitar"):
			jogador.deitar()
		if not _dica_pegar.visible or jogador.deitado:
			_dica_pegar.visible = true
			_dica_pegar.text = "[J] levantar (descansando)" if jogador.deitado else "[J] deitar na cama"


func _refaz_toque() -> void:
	for n in _toque_nos:
		if is_instance_valid(n):
			n.queue_free()
	_toque_nos.clear()
	_estilos_toque.clear()
	_monta_toque()
	_pausa.move_to_front()  # a pausa (com as configurações abertas) continua por cima


# botões de toque em arco em volta do de ataque, no canto de baixo à direita; só ícone, sem texto
func _monta_toque() -> void:
	_tam_botoes = float(Config.v.botoes_tamanho)
	_base = _circulo(RAIO_STICK * 2.0, Color(1, 1, 1, 0.12))
	_base.visible = false
	add_child(_base)
	_toque_nos.append(_base)
	_pino = _circulo(80.0, Color(1, 1, 1, 0.35))
	_base.add_child(_pino)
	_pino.position = _base.size * 0.5 - _pino.size * 0.5
	_btn_atacar = _botao("corte", Vector2(-210, -210), 150.0)
	_btn_atacar.button_down.connect(func() -> void:
		jogador.entrada["atacar"] = true
		jogador.entrada["atirando"] = true)
	_btn_atacar.button_up.connect(func() -> void: jogador.entrada["atirando"] = false)
	_btn_mira = _botao("mira", Vector2(-350, -128), 92.0)
	_btn_mira.button_down.connect(func() -> void: jogador.entrada["mirar"] = true)
	var pular := _botao("pular", Vector2(-128, -350), 92.0)
	pular.name = "Pular"
	pular.button_down.connect(func() -> void: jogador.entrada["pular"] = true)
	_btn_agachar = _botao("agachar", Vector2(-300, -300), 80.0)
	_btn_agachar.button_down.connect(func() -> void: jogador.entrada["agachar"] = true)
	_btn_recarregar = _botao("recarga", Vector2(-410, -250), 72.0)
	_btn_recarregar.button_down.connect(func() -> void: jogador.entrada["recarregar"] = true)
	_btn_modo = _botao("modo", Vector2(-410, -350), 72.0)
	_btn_modo.name = "Modo"
	_btn_modo.button_down.connect(func() -> void: jogador.entrada["modo"] = true)
	_btn_modo.visible = false
	var trocar := _botao("trocar", Vector2(-128, -470), 72.0)  # troca entre a arma branca e a de fogo
	trocar.name = "Trocar"
	trocar.button_down.connect(func() -> void: jogador.entrada["trocar"] = true)
	_btn_deitar = _botao("deitar", Vector2(-540, -400), 84.0)
	_btn_deitar.button_down.connect(func() -> void: jogador.deitar())
	_btn_deitar.visible = false
	_btn_dominar = _botao("dominar", Vector2(-540, -300), 84.0)
	_btn_dominar.button_down.connect(func() -> void: get_tree().get_first_node_in_group("principal").pede_dominar.rpc_id(1))
	_btn_dominar.visible = false
	_btn_pegar = _botao("pegar", Vector2(-540, -170), 100.0)
	_btn_pegar.button_down.connect(func() -> void: jogador.entrada["pegar"] = true)
	_btn_pegar.visible = false


func _botao(icone: String, desloc: Vector2, tam: float = BOTAO) -> _Icone:
	var k: float = float(Config.v.botoes_tamanho)
	desloc *= k
	tam *= k
	var b := _Icone.new()
	b.icone = icone
	b.custom_minimum_size = Vector2(tam, tam)
	b.size = Vector2(tam, tam)
	_estilos_toque.append(b.estilo)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = desloc.x
	b.offset_top = desloc.y
	b.offset_right = desloc.x + tam
	b.offset_bottom = desloc.y + tam
	add_child(b)
	_toque_nos.append(b)
	return b


func _circulo(diam: float, cor: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(diam, diam)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var est := StyleBoxFlat.new()
	est.bg_color = cor
	est.set_corner_radius_all(int(diam * 0.5))
	p.add_theme_stylebox_override("panel", est)
	return p


# mira no centro da tela: ponto + quatro tracinhos
class _Mira:
	extends Control

	## tempo restante da marca de acerto (X em volta do centro)
	var marca_t: float = 0.0
	var marca_forte: bool = false

	func marca(forte: bool) -> void:
		marca_t = 0.25
		marca_forte = forte
		queue_redraw()

	func _process(dt: float) -> void:
		if marca_t > 0.0:
			marca_t -= dt
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var cor := Color(Config.cor_mira(), 0.9)
		draw_circle(c, 2.5, cor)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * 8.0, c + d * 18.0, cor, 2.5)
		draw_arc(c, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)
		if marca_t > 0.0:
			var a: float = clampf(marca_t / 0.25, 0.0, 1.0)
			var mc := Color(0.95, 0.15, 0.1, a) if marca_forte else Color(1, 1, 1, a)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				draw_line(c + d.normalized() * 10.0, c + d.normalized() * 19.0, mc, 3.0)


# amigos do grupo: nome em cima da cabeça quando aparece na tela; seta na borda quando está fora dela
class _Marcas:
	extends Control

	var amigos: Array = []:
		set(v):
			amigos = v
			queue_redraw()

	func _process(_dt: float) -> void:
		if not amigos.is_empty():
			queue_redraw()

	func _draw() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var f: Font = UiTema.tema().default_font
		var cor := Color(0.45, 0.7, 1.0)
		var c: Vector2 = size * 0.5
		for j: Jogador in amigos:
			if not is_instance_valid(j):
				continue
			var p: Vector3 = j.global_position + Vector3(0, 2.1, 0)
			var dist: int = roundi(cam.global_position.distance_to(j.global_position))
			var tela: Vector2 = cam.unproject_position(p)
			var frente: bool = not cam.is_position_behind(p)
			if frente and Rect2(Vector2(40, 40), size - Vector2(80, 80)).has_point(tela):
				draw_string(f, tela + Vector2(-100, 0), "%s  %d m" % [j.nick, dist], HORIZONTAL_ALIGNMENT_CENTER, 200, 20, cor)
				draw_colored_polygon(PackedVector2Array([tela + Vector2(-7, 6), tela + Vector2(7, 6), tela + Vector2(0, 16)]), cor)
				continue
			var d: Vector2 = (tela - c) * (1.0 if frente else -1.0)
			if d.length() < 1.0:
				d = Vector2.DOWN
			d = d.normalized()
			var borda: Vector2 = c + d * minf((c.x - 50) / maxf(absf(d.x), 0.01), (c.y - 50) / maxf(absf(d.y), 0.01))
			var lado := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([borda + d * 18, borda - d * 8 + lado * 12, borda - d * 8 - lado * 12]), cor)
			draw_string(f, borda - d * 34 + Vector2(-100, 6), j.nick, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, cor)


# barra fina de vida/fome/sede: ícone pequeno à esquerda e a barra; pisca quando está baixa
class _Barra:
	extends Control

	const CORES: Array[Color] = [Color(0.82, 0.84, 0.8), Color(0.85, 0.6, 0.3), Color(0.4, 0.62, 0.85), Color(0.55, 0.75, 0.25)]
	## 0 vida, 1 fome, 2 sede, 3 infecção (pisca quando está ALTA)
	var tipo: int = 0
	var valor: float = 100.0:
		set(v):
			if absf(v - valor) > 0.2 or int(v) != int(valor) or _perigo(v) != _perigo(valor):
				queue_redraw()
			valor = v

	func _perigo(v: float) -> bool:
		return v > 70.0 if tipo == 3 else v < 20.0

	func _process(_dt: float) -> void:
		if _perigo(valor):
			queue_redraw()  # piscando

	func _draw() -> void:
		var h: float = size.y
		var x0: float = h + 8.0
		var w: float = size.x - x0 - 46.0  # o resto é a porcentagem
		var y: float = h * 0.5 - 3.0
		draw_rect(Rect2(x0, y, w, 6), Color(0, 0, 0, 0.45))
		var cor: Color = CORES[tipo]
		draw_string(UiTema.tema().default_font, Vector2(x0 + w + 8.0, h - 1.0), "%d%%" % roundi(valor), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(cor, 0.9))
		if _perigo(valor):
			cor = Color(0.85, 0.2, 0.15)
			cor.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
		draw_rect(Rect2(x0, y, w * clampf(valor / 100.0, 0.0, 1.0), 6), cor)
		_icone(Vector2(h * 0.5, h * 0.5), h * 0.45, Color(cor, 0.95))

	# cruz, garfo, gota e risco biológico (três círculos) em traços simples (sem imagem)
	func _icone(c: Vector2, r: float, b: Color) -> void:
		match tipo:
			3:
				for k in 3:
					draw_arc(c + Vector2(0, -r * 0.45).rotated(TAU * k / 3.0), r * 0.5, 0, TAU, 12, b, 1.6)
				draw_circle(c, r * 0.2, b)
			0:
				draw_rect(Rect2(c.x - r * 0.3, c.y - r, r * 0.6, r * 2), b)
				draw_rect(Rect2(c.x - r, c.y - r * 0.3, r * 2, r * 0.6), b)
			1:
				draw_line(c + Vector2(0, -r), c + Vector2(0, r), b, 2.0)
				for dx in [-r * 0.5, r * 0.5]:
					draw_line(c + Vector2(dx, -r), c + Vector2(dx, -r * 0.2), b, 1.5)
				draw_line(c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(r * 0.5, -r * 0.2), b, 1.5)
			_:
				draw_circle(c + Vector2(0, r * 0.3), r * 0.62, b)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.1), c + Vector2(r * 0.55, r * 0.1), c + Vector2(0, -r)]), b)


# botão só com ícone desenhado (círculo escuro com borda fina); `ligado` acende (agachado, mira, automático)
class _Icone:
	extends Button

	var icone: String = "":
		set(v):
			if v != icone:
				icone = v
				queue_redraw()
	var ligado: bool = false:
		set(v):
			if v != ligado:
				ligado = v
				queue_redraw()
	var redondo: bool = true
	var estilo := StyleBoxFlat.new()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		estilo.bg_color = Color(0, 0, 0, 0.3)
		estilo.border_color = Color(1, 1, 1, 0.35)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(int(size.x * 0.5) if redondo else 4)
		for e: String in ["normal", "pressed", "hover"]:
			add_theme_stylebox_override(e, estilo)
		button_down.connect(func() -> void: modulate = Color(1, 1, 1, 0.6))
		button_up.connect(func() -> void: modulate = Color.WHITE)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.24
		var b := Color(1.0, 0.78, 0.35) if ligado else Color(1, 1, 1, 0.9)
		var g: float = maxf(2.5, size.x * 0.035)
		match icone:
			"corte":  # lâmina na diagonal com o cabo
				draw_line(c + Vector2(-r, r), c + Vector2(r * 1.1, -r * 1.1), b, g * 2.2)
				draw_line(c + Vector2(-r * 1.3, r * 0.3), c + Vector2(-r * 0.3, r * 1.3), b, g)
			"tiro":  # bala
				draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.3, r * 0.7, r * 1.3), b)
				draw_circle(c + Vector2(0, -r * 0.3), r * 0.35, b)
				draw_rect(Rect2(c.x - r * 0.45, c.y + r * 1.0, r * 0.9, r * 0.2), b)
			"mira":
				draw_arc(c, r, 0, TAU, 32, b, g)
				for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + d * r * 0.4, c + d * r * 1.35, b, g)
			"pular":
				for k in 2:
					var y: float = c.y - r * 0.15 + k * r * 0.7
					draw_polyline(PackedVector2Array([Vector2(c.x - r, y), Vector2(c.x, y - r * 0.8), Vector2(c.x + r, y)]), b, g)
			"agachar":
				draw_polyline(PackedVector2Array([Vector2(c.x - r, c.y - r * 0.5), Vector2(c.x, c.y + r * 0.3), Vector2(c.x + r, c.y - r * 0.5)]), b, g)
				draw_line(Vector2(c.x - r, c.y + r * 0.9), Vector2(c.x + r, c.y + r * 0.9), b, g)
			"recarga":  # seta em volta
				draw_arc(c, r, -PI * 0.35, PI * 1.35, 24, b, g)
				var p: Vector2 = c + Vector2.from_angle(-PI * 0.35) * r
				draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, -r * 0.1), p + Vector2(r * 0.3, -r * 0.45), p + Vector2(r * 0.25, r * 0.4)]), b)
			"modo":  # três balinhas = automático
				for k in 3:
					draw_rect(Rect2(c.x - r + k * r * 0.75, c.y - r * 0.6, r * 0.45, r * 1.2), b if ligado or k == 1 else Color(b, 0.3))
			"pegar":  # seta para baixo entrando na mão aberta
				draw_line(c + Vector2(0, -r * 1.1), c + Vector2(0, r * 0.3), b, g)
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.15), c + Vector2(0, r * 0.35), c + Vector2(r * 0.45, -r * 0.15)]), b, g)
				draw_polyline(PackedVector2Array([c + Vector2(-r, r * 0.4), c + Vector2(-r, r), c + Vector2(r, r), c + Vector2(r, r * 0.4)]), b, g)
			"mochila":
				draw_rect(Rect2(c.x - r, c.y - r * 0.6, r * 2, r * 1.7), b, false, g)
				draw_arc(c + Vector2(0, -r * 0.6), r * 0.5, PI, TAU, 12, b, g)
				draw_line(c + Vector2(-r, r * 0.1), c + Vector2(r, r * 0.1), b, g)
			"trocar":  # duas setas em sentidos opostos
				draw_line(c + Vector2(-r, -r * 0.4), c + Vector2(r, -r * 0.4), b, g)
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 1.25, -r * 0.4), c + Vector2(r * 0.6, -r * 0.85), c + Vector2(r * 0.6, r * 0.05)]), b)
				draw_line(c + Vector2(r, r * 0.45), c + Vector2(-r, r * 0.45), b, g)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.25, r * 0.45), c + Vector2(-r * 0.6, 0.0), c + Vector2(-r * 0.6, r * 0.9)]), b)
			"deitar":  # cama: colchão e travesseiro
				draw_rect(Rect2(c.x - r * 1.1, c.y, r * 2.2, r * 0.5), b)
				draw_rect(Rect2(c.x - r * 1.1, c.y - r * 0.5, r * 0.6, r * 0.45), b)
				draw_line(c + Vector2(-r * 1.1, r * 0.5), c + Vector2(-r * 1.1, r * 0.9), b, g)
				draw_line(c + Vector2(r * 1.1, r * 0.5), c + Vector2(r * 1.1, r * 0.9), b, g)
			"dominar":  # bandeira
				draw_line(c + Vector2(-r * 0.6, -r * 1.1), c + Vector2(-r * 0.6, r * 1.1), b, g)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 1.1), c + Vector2(r, -r * 0.6), c + Vector2(-r * 0.6, -r * 0.1)]), b)
			"pausa":
				draw_rect(Rect2(c.x - r * 0.7, c.y - r * 0.8, r * 0.5, r * 1.6), b)
				draw_rect(Rect2(c.x + r * 0.2, c.y - r * 0.8, r * 0.5, r * 1.6), b)


# briga com o zumbi no pescoço: tela avermelhada pulsando, "SE SOLTA!", barra com a faixa verde e o marcador indo e
# voltando, bolinhas dos acertos e o botão EMPURRAR (PC: espaço, E ou clique) — toque quando o marcador estiver no verde
class _Qte:
	extends Control

	var jogador: Jogador
	var botao: Button

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao = UiTema.botao("EMPURRAR!", true)
		botao.theme = UiTema.tema()
		botao.add_theme_font_size_override("font_size", 34)
		botao.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		botao.custom_minimum_size = Vector2(380, 110)
		botao.grow_horizontal = Control.GROW_DIRECTION_BOTH
		botao.grow_vertical = Control.GROW_DIRECTION_BEGIN
		botao.position.y -= 60
		add_child(botao)

	func _draw() -> void:
		if jogador == null:
			return
		var t: float = Time.get_ticks_msec() * 0.001
		var pulso: float = 0.25 + 0.12 * sin(t * 9.0)
		var w: float = size.x
		var h: float = size.y
		for k in 6:  # bordas vermelhas (mais forte na beirada)
			var a: float = pulso * (1.0 - k / 6.0)
			var m: float = 26.0 * k
			draw_rect(Rect2(m, m, w - 2 * m, h - 2 * m), Color(0.55, 0.0, 0.0, a * 0.5), false, 26.0)
		var fonte: Font = UiTema.fonte_titulo()
		draw_string(fonte, Vector2(0, h * 0.24), "SE SOLTA!", HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(1, 0.85, 0.8))
		var bw: float = minf(620.0, w * 0.6)
		var bx: float = (w - bw) * 0.5
		var by: float = h * 0.36
		draw_rect(Rect2(bx - 4, by - 4, bw + 8, 36), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bx + bw * jogador.qte_faixa.x, by, bw * jogador.qte_faixa.y, 28), Color(0.35, 0.8, 0.3, 0.9))
		var mx: float = bx + bw * jogador.qte_pos
		draw_rect(Rect2(mx - 4, by - 10, 8, 48), Color.WHITE)
		for k in Jogador.ACERTOS_SOLTAR:
			var c := Vector2(w * 0.5 + (k - 1) * 40.0, by + 62.0)
			draw_circle(c, 11.0, Color(0.35, 0.8, 0.3) if k < jogador.qte_acertos else Color(1, 1, 1, 0.25))
		var resta: float = clampf(jogador.mordida_t / Zumbi.MORDIDA_T, 0.0, 1.0)
		draw_rect(Rect2(bx, by + 86, bw * resta, 6), Color(0.85, 0.2, 0.15))


## Chegando perto de uma raid (a até 35 m), avisa uma vez o que tem lá.
func _avisa_raid(dt: float) -> void:
	_raid_t -= dt
	if _raid_t > 0.0:
		return
	_raid_t = 1.0
	var principal := get_tree().get_first_node_in_group("principal")
	if principal == null or principal.bairro == null:
		return
	for r: Dictionary in principal.bairro.raids:
		if not _raids_avisadas.has(r.nome) and jogador.global_position.distance_to(r.pos) < 35.0:
			_raids_avisadas[r.nome] = true
			aviso("%s — zumbis armados lá dentro, loot raro" % r.nome, UiTema.PERIGO)


## Bilhete no chão a até 1,6 m: mostra o que está escrito (uma vez cada).
func _le_bilhete(dt: float) -> void:
	_bilhete_t -= dt
	if _bilhete_t > 0.0:
		return
	_bilhete_t = 0.3
	for b: Node3D in get_tree().get_nodes_in_group("bilhetes"):
		if not _lidos.has(b) and jogador.global_position.distance_to(b.global_position) < 1.6:
			_lidos[b] = true
			aviso("BILHETE: " + String(b.get_meta("texto")), UiTema.TEXTO, 9.0)
			return
