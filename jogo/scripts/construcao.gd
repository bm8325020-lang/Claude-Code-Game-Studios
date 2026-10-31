# Modo construção (31/10, dono: "quero montar o mapa"): câmera voando, catálogo (MapaCustom.lista: ~2100 peças por
# categoria, com busca), a peça escolhida aparece verde na mira; COLOCAR, APAGAR (o que está na mira), DESFAZER, GIRAR,
# MAIOR/MENOR, SOBE/DESCE (a peça), GRADE (encaixa de 0,5 m em 0,5 m). SALVAR em user://meu_mapa.json, COMPARTILHAR
# (texto comprimido na área de transferência para colar na conversa), COLAR (carrega um mapa copiado), JOGAR.
# Celular: analógico à esquerda anda, arrastar no resto da tela olha, botões ▲▼ sobem/descem a câmera.
# PC: WASD anda, Q/E desce/sobe, botão direito + mouse olha, clique coloca, Del apaga, R gira, Ctrl+Z desfaz.
class_name Construcao
extends Node3D

const VEL: float = 14.0
const GRADE: float = 0.5
var main: Node
var dados: Dictionary = {"base": "vazio", "pecas": []}
var mapa: Node3D
var cam: Camera3D
var yaw: float = 0.0
var pitch: float = -0.55
var _atual: String = ""
var _fantasma: Node3D
var _giro: float = 0.0
var _esc: float = 1.0
var _alto: float = 0.0
var _grade: bool = true
var _desfazer: Array = []
var _sobe: float = 0.0
var _stick := Vector2.ZERO
var _ui: CanvasLayer
var _info: Label
var _aviso: Label
var _aviso_t: float = 0.0
var _catalogo: PanelContainer
var _cats: VBoxContainer
var _itens: VBoxContainer
var _busca: LineEdit
var _toque_olhar: int = -1
var _mira_ponto := Vector3.ZERO
var _mira_alvo: Node3D


func _ready() -> void:
	name = "Construcao"
	cam = Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	cam.global_position = Bairro.ORIGEM + Vector3(0, 25, 40)
	mapa = Node3D.new()
	mapa.name = "Mapa"
	main.add_child(mapa)
	MapaCustom.monta(dados, mapa, main.bairro, false)
	for p: Node in mapa.get_children():
		_guarda_dados(p, dados.pecas[p.get_index()])
	_monta_ui()
	_escolhe("jogo:nascer")


func _guarda_dados(p: Node, d: Dictionary) -> void:
	p.set_meta("dados", d)


# ---------- câmera e mira ----------
func _process(dt: float) -> void:
	var mov := _stick
	if not DisplayServer.is_touchscreen_available():
		mov = Vector2(Input.get_axis("esq", "dir") if InputMap.has_action("esq") else 0.0, Input.get_axis("tras", "frente") if InputMap.has_action("frente") else 0.0)
		_sobe = (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	var direita := Vector3(cos(yaw), 0, -sin(yaw))
	var rapido: float = 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	cam.global_position += (frente * mov.y + direita * mov.x) * VEL * rapido * dt + Vector3.UP * _sobe * VEL * 0.7 * dt
	cam.rotation = Vector3(pitch, yaw, 0)
	_atualiza_mira()
	_aviso_t -= dt
	_aviso.visible = _aviso_t > 0.0
	_info.text = "%s   ·   %d peças   ·   giro %d°   ·   tamanho %.1fx   ·   altura %+.1f m%s" % [
		String(MapaCustom.item(_atual).get("nome", "nada")), dados.pecas.size(), roundi(rad_to_deg(_giro)), _esc, _alto,
		"   ·   grade" if _grade else ""]


func _atualiza_mira() -> void:
	var de: Vector3 = cam.global_position
	var para: Vector3 = de - cam.global_basis.z * 400.0
	var q := PhysicsRayQueryParameters3D.create(de, para, 1)
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		_mira_ponto = r.position
		_mira_alvo = _peca_de(r.collider)
	else:
		var t: float = -de.y / minf(-0.001, (para - de).normalized().y) if (para - de).y < 0.0 else 30.0
		_mira_ponto = de + (para - de).normalized() * minf(t, 120.0)
		_mira_alvo = null
	if _grade:
		_mira_ponto.x = snappedf(_mira_ponto.x, GRADE)
		_mira_ponto.z = snappedf(_mira_ponto.z, GRADE)
	if _fantasma:
		_fantasma.global_position = _mira_ponto + Vector3(0, _alto, 0)
		_fantasma.rotation.y = _giro
		_fantasma.scale = Vector3.ONE * _esc


func _peca_de(n: Object) -> Node3D:
	var x: Node = n as Node
	while x and x.get_parent() != mapa:
		x = x.get_parent()
	return x as Node3D


func _unhandled_input(ev: InputEvent) -> void:
	if _catalogo.visible:
		return
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed and _toque_olhar < 0 and t.position.x > get_viewport().get_visible_rect().size.x * 0.3:
			_toque_olhar = t.index
		elif not t.pressed and t.index == _toque_olhar:
			_toque_olhar = -1
	elif ev is InputEventScreenDrag and (ev as InputEventScreenDrag).index == _toque_olhar:
		_olha((ev as InputEventScreenDrag).relative * 0.005)
	elif ev is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_olha((ev as InputEventMouseMotion).relative * 0.004)
	elif ev is InputEventMouseButton and ev.pressed and not DisplayServer.is_touchscreen_available():
		var b := ev as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			coloca()
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_esc = minf(_esc * 1.1, 20.0)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_esc = maxf(_esc / 1.1, 0.05)
	elif ev is InputEventKey and ev.pressed:
		var k := ev as InputEventKey
		if k.keycode == KEY_DELETE:
			apaga()
		elif k.keycode == KEY_R:
			gira()
		elif k.keycode == KEY_Z and k.ctrl_pressed:
			desfaz()


func _olha(d: Vector2) -> void:
	yaw -= d.x
	pitch = clampf(pitch - d.y, -1.5, 1.2)


# ---------- ações ----------
func _escolhe(id: String) -> void:
	_atual = id
	if _fantasma:
		_fantasma.queue_free()
	_fantasma = MapaCustom.cria(id, main.bairro, false)
	add_child(_fantasma)
	var verde := StandardMaterial3D.new()
	verde.albedo_color = Color(0.3, 1.0, 0.4, 0.35)
	verde.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	verde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for g: GeometryInstance3D in _fantasma.find_children("*", "GeometryInstance3D", true, false):
		g.material_overlay = verde
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: CollisionObject3D in _fantasma.find_children("*", "CollisionObject3D", true, false):
		c.collision_layer = 0  # a mira atravessa o fantasma
	var it: Dictionary = MapaCustom.item(id)
	_avisa("Escolhido: " + String(it.get("nome", id)))


func coloca() -> Node3D:
	if _atual == "":
		return null
	var d := {"c": _atual, "p": [snappedf(_mira_ponto.x, 0.01), snappedf(_mira_ponto.y + _alto, 0.01), snappedf(_mira_ponto.z, 0.01)],
		"r": snappedf(_giro, 0.001), "e": snappedf(_esc, 0.01)}
	var p: Node3D = _poe(d)
	_desfazer.append({"tipo": "por", "no": p})
	return p


func _poe(d: Dictionary) -> Node3D:
	var p: Node3D = MapaCustom.cria(String(d.c), main.bairro, false)
	mapa.add_child(p)
	p.global_position = Vector3(float(d.p[0]), float(d.p[1]), float(d.p[2]))
	p.rotation.y = float(d.r)
	p.scale = Vector3.ONE * float(d.e)
	_guarda_dados(p, d)
	dados.pecas.append(d)
	return p


func apaga() -> void:
	if _mira_alvo == null or not is_instance_valid(_mira_alvo):
		_avisa("Mire numa peça para apagar")
		return
	var d: Dictionary = _mira_alvo.get_meta("dados")
	dados.pecas.erase(d)
	_desfazer.append({"tipo": "apagar", "d": d})
	_mira_alvo.free()
	_mira_alvo = null


func desfaz() -> void:
	if _desfazer.is_empty():
		return
	var u: Dictionary = _desfazer.pop_back()
	if u.tipo == "por" and is_instance_valid(u.no):
		dados.pecas.erase((u.no as Node).get_meta("dados"))
		(u.no as Node).free()
	elif u.tipo == "apagar":
		_poe(u.d)


func gira() -> void:
	_giro = fposmod(_giro + deg_to_rad(15.0), TAU)


func salva() -> void:
	MapaCustom.salva(dados)
	_avisa("Mapa salvo (%d peças)" % dados.pecas.size())


func compartilha() -> void:
	salva()
	DisplayServer.clipboard_set(MapaCustom.para_texto(dados))
	_avisa("Mapa copiado! Cole na conversa para mandar")


func cola() -> void:
	var d: Dictionary = MapaCustom.de_texto(DisplayServer.clipboard_get())
	if d.is_empty():
		_avisa("Copie antes um texto de mapa (começa com MAPA1:)")
		return
	for p: Node in mapa.get_children():
		p.free()
	dados = {"base": d.get("base", dados.base), "pecas": []}
	for x: Dictionary in d.pecas:
		_poe(x)
	_desfazer.clear()
	_avisa("Mapa colado (%d peças)" % dados.pecas.size())


func _avisa(t: String) -> void:
	_aviso.text = t
	_aviso_t = 2.5


# ---------- tela ----------
func _monta_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = UiTema.tema()
	_ui.add_child(raiz)
	var mira := ColorRect.new()  # cruz no meio
	mira.color = Color(1, 1, 1, 0.8)
	mira.size = Vector2(6, 6)
	mira.set_anchors_preset(Control.PRESET_CENTER)
	mira.position -= Vector2(3, 3)
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(mira)
	var topo := HBoxContainer.new()
	topo.position = Vector2(12, 10)
	topo.add_theme_constant_override("separation", 8)
	raiz.add_child(topo)
	for par: Array in [["CATÁLOGO", func() -> void: _abre_catalogo(true)], ["SALVAR", salva], ["COMPARTILHAR", compartilha],
			["COLAR", cola], ["JOGAR", func() -> void:
				salva()
				main.jogar_meu_mapa()], ["SAIR", func() -> void:
				salva()
				get_tree().reload_current_scene()]]:
		var b := UiTema.botao(par[0], par[0] == "CATÁLOGO")
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(par[1])
		topo.add_child(b)
	_info = UiTema.rotulo("", 18, Color(1, 1, 1, 0.95))
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.position = Vector2(14, 84)
	raiz.add_child(_info)
	_aviso = UiTema.rotulo("", 24, UiTema.DESTAQUE)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_OFF
	_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso.position = Vector2(-220, 120)
	raiz.add_child(_aviso)
	# botões da direita
	var dir := GridContainer.new()
	dir.columns = 2
	dir.anchor_left = 1.0
	dir.anchor_right = 1.0
	dir.anchor_top = 0.5
	dir.anchor_bottom = 0.5
	dir.offset_left = -330
	dir.offset_top = -200
	dir.add_theme_constant_override("h_separation", 8)
	dir.add_theme_constant_override("v_separation", 8)
	raiz.add_child(dir)
	for par: Array in [["COLOCAR", func() -> void: coloca()], ["APAGAR", apaga], ["GIRAR 15°", gira], ["DESFAZER", desfaz],
			["MAIOR", func() -> void: _esc = minf(_esc * 1.15, 20.0)], ["MENOR", func() -> void: _esc = maxf(_esc / 1.15, 0.05)],
			["PEÇA ▲", func() -> void: _alto += 0.25], ["PEÇA ▼", func() -> void: _alto -= 0.25],
			["GRADE", func() -> void:
				_grade = not _grade
				_avisa("Grade " + ("ligada" if _grade else "desligada"))], ["ZERAR", func() -> void:
				_giro = 0.0
				_esc = 1.0
				_alto = 0.0]]:
		var b := UiTema.botao(par[0], par[0] == "COLOCAR")
		b.custom_minimum_size = Vector2(158, 72)
		b.pressed.connect(par[1])
		dir.add_child(b)
	# analógico e sobe/desce da câmera (esquerda)
	var stick := _Stick.new()
	stick.dono = self
	stick.anchor_top = 1.0
	stick.anchor_bottom = 1.0
	stick.offset_left = 30
	stick.offset_top = -290
	stick.offset_right = 290
	stick.offset_bottom = -30
	raiz.add_child(stick)
	for par: Array in [["▲", 1.0, -440], ["▼", -1.0, -360]]:
		var b := UiTema.botao(par[0])
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.offset_left = 310
		b.offset_right = 390
		b.offset_top = par[2]
		b.offset_bottom = par[2] + 70
		var v: float = par[1]
		b.button_down.connect(func() -> void: _sobe = v)
		b.button_up.connect(func() -> void: _sobe = 0.0)
		raiz.add_child(b)
	_monta_catalogo(raiz)


func _monta_catalogo(raiz: Control) -> void:
	_catalogo = PanelContainer.new()
	_catalogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catalogo.offset_left = 40
	_catalogo.offset_top = 30
	_catalogo.offset_right = -40
	_catalogo.offset_bottom = -30
	_catalogo.visible = false
	raiz.add_child(_catalogo)
	var col := VBoxContainer.new()
	_catalogo.add_child(col)
	var cab := HBoxContainer.new()
	col.add_child(cab)
	_busca = UiTema.campo("Buscar (ex.: carro, sofá, foguete, rua)")
	_busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_busca.text_changed.connect(func(t: String) -> void: _lista_itens("", t))
	cab.add_child(_busca)
	var fecha := UiTema.botao("FECHAR")
	fecha.pressed.connect(func() -> void: _abre_catalogo(false))
	cab.add_child(fecha)
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(corpo)
	var sc1 := ScrollContainer.new()
	sc1.custom_minimum_size = Vector2(380, 0)
	sc1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(sc1)
	_cats = VBoxContainer.new()
	_cats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc1.add_child(_cats)
	var sc2 := ScrollContainer.new()
	sc2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(sc2)
	_itens = VBoxContainer.new()
	_itens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(_itens)
	var conta: Dictionary = {}
	var ordem: Array = []
	for it: Dictionary in MapaCustom.lista():
		if not conta.has(it.cat):
			ordem.append(it.cat)
		conta[it.cat] = int(conta.get(it.cat, 0)) + 1
	ordem.sort()
	ordem.erase("Peças do jogo")
	ordem.push_front("Peças do jogo")
	for c: String in ordem:
		var b := UiTema.botao("%s (%d)" % [c, conta[c]])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: _lista_itens(c, ""))
		_cats.add_child(b)


func _abre_catalogo(sim: bool) -> void:
	_catalogo.visible = sim
	if sim and _itens.get_child_count() == 0:
		_lista_itens("Peças do jogo", "")


## Lista as peças de uma categoria (ou as que batem com a busca).
func _lista_itens(cat: String, busca: String) -> void:
	for c in _itens.get_children():
		c.queue_free()
	var b: String = busca.strip_edges().to_lower()
	var n: int = 0
	for it: Dictionary in MapaCustom.lista():
		if (b == "" and it.cat == cat) or (b != "" and (String(it.nome).to_lower().contains(b) or String(it.cat).to_lower().contains(b))):
			var t: Array = it.tam
			var bt := UiTema.botao("%s   ·   %.1f × %.1f × %.1f m" % [it.nome, float(t[0]), float(t[1]), float(t[2])] if not String(it.id).begins_with("jogo:") else String(it.nome))
			bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var id: String = it.id
			bt.pressed.connect(func() -> void:
				_escolhe(id)
				_abre_catalogo(false))
			_itens.add_child(bt)
			n += 1
			if n >= 300:
				break


## Analógico de andar (toque).
class _Stick extends Control:
	var dono: Construcao
	var _toque: int = -1
	var _centro := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			var t := ev as InputEventScreenTouch
			if t.pressed and _toque < 0:
				_toque = t.index
				_centro = t.position
			elif not t.pressed and t.index == _toque:
				_toque = -1
				dono._stick = Vector2.ZERO
			queue_redraw()
		elif ev is InputEventScreenDrag and (ev as InputEventScreenDrag).index == _toque:
			var d: Vector2 = ((ev as InputEventScreenDrag).position - _centro) / 90.0
			dono._stick = Vector2(d.x, -d.y).limit_length(1.0)
			queue_redraw()

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.45, Color(1, 1, 1, 0.12))
		draw_circle(size * 0.5 + Vector2(dono._stick.x, -dono._stick.y) * 70.0 if dono else size * 0.5, 40.0, Color(1, 1, 1, 0.35))
