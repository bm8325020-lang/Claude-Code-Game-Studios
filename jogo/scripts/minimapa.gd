# Minimapa do canto (pedido do dono 05/11: "parecido com o de GTA 5"): retângulo de cantos redondos que gira com a câmera,
# você é a seta branca um pouco abaixo do meio, N na borda, zumbis perto em vermelho, amigos em azul, raids (caveira);
# raids/amigos ficam presos na borda quando longe (marcos e salas seguras só dentro do quadro). No carro o mapa abre mais
# (como no GTA). Imagem da cidade:
# assets/mapa/minimapa.png (tools/mapa/minimapa.py; 1 px = 1 m, centro = origem do Bairro).
class_name Minimapa
extends Control

const IMAGEM := "res://assets/mapa/minimapa.png"
const TAM := Vector2(230, 170)
const METROS := 150.0  # largura mostrada a pé (no carro x2)
const CENTRO := Vector2(0.5, 0.62)  # onde fica o jogador no quadro
const ZUMBI_VE := 30.0  # zumbi aparece a até esta distância, se estiver na sua frente (07/11, era 45 em volta toda)
const VISTA_CONE := 0.45  # cos do meio campo de visão (~63°)
const SAQUEADOR_VE := 160.0  # saqueador (Corvo) aparece bem mais longe
const COR_RAID := Color(0.9, 0.2, 0.15)
const COR_MARCO := Color(1.0, 0.8, 0.2)
const COR_SEGURA := Color(0.35, 0.9, 0.4)
const COR_AMIGO := Color(0.35, 0.65, 1.0)

var jogador: Jogador
## Destino marcado no mapa grande (TelaMapa); INF = nenhum. Some ao chegar perto.
static var destino: Vector3 = Vector3.INF
const CHEGOU: float = 8.0
signal abrir_mapa


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and not ev.pressed:
		abrir_mapa.emit()
		accept_event()
var _fundo: ColorRect
var _mat: ShaderMaterial
var _metros: float = METROS
var _ang: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # tocar no minimapa abre o mapa grande
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -TAM.x - 20
	offset_right = -20
	offset_top = 82
	offset_bottom = 82 + TAM.y
	_fundo = ColorRect.new()
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("mapa", load(IMAGEM) if ResourceLoader.exists(IMAGEM) else null)
	_mat.set_shader_parameter("centro_q", CENTRO)
	_mat.set_shader_parameter("aspecto", TAM.y / TAM.x)
	_fundo.material = _mat
	add_child(_fundo)
	_fundo.show_behind_parent = true


func _process(dt: float) -> void:
	var b: Bairro = _bairro()
	visible = jogador != null and b != null and ResourceLoader.exists(IMAGEM)
	if not visible:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		var f: Vector3 = -cam.global_basis.z
		_ang = atan2(-f.x, -f.z)
	_metros = lerpf(_metros, METROS * (2.0 if jogador.carro else 1.0), minf(dt * 2.0, 1.0))
	var p: Vector3 = jogador.global_position - Bairro.ORIGEM
	_atualiza_cache(dt)
	_mat.set_shader_parameter("pos", Vector2(p.x, p.z))
	_mat.set_shader_parameter("ang", _ang)
	_mat.set_shader_parameter("metros", _metros)
	queue_redraw()


func _bairro() -> Bairro:
	var m: Node = get_tree().get_first_node_in_group("principal")
	return m.bairro if m and "bairro" in m else null


func _na_vista(w: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return true
	var d: Vector3 = w - cam.global_position
	d.y = 0.0
	var f: Vector3 = -cam.global_basis.z
	f.y = 0.0
	return f.normalized().dot(d.normalized()) > VISTA_CONE


## Ponto do mundo -> posição no quadro (px). Gira ao contrário da câmera: a frente fica para cima.
func no_quadro(w: Vector3) -> Vector2:
	var d: Vector3 = w - jogador.global_position
	var s := Vector2(cos(_ang) * d.x - sin(_ang) * d.z, sin(_ang) * d.x + cos(_ang) * d.z)
	return CENTRO * TAM + s * (TAM.x / _metros)


## Prende na borda (com folga) o que está fora do quadro; devolve [posição, está fora].
func _na_borda(q: Vector2) -> Array:
	var c: Vector2 = CENTRO * TAM
	var m := Rect2(Vector2(10, 10), TAM - Vector2(20, 20))
	if m.has_point(q):
		return [q, false]
	var d: Vector2 = q - c
	var t: float = 1.0
	if d.x != 0.0:
		t = minf(t, ((m.end.x if d.x > 0 else m.position.x) - c.x) / d.x)
	if d.y != 0.0:
		t = minf(t, ((m.end.y if d.y > 0 else m.position.y) - c.y) / d.y)
	return [c + d * t, true]


## 12/11 anti-lag: o desenho varria 2.061 gavetas, 179 baús e todos os zumbis A CADA QUADRO (custava ~1/3 da CPU do
## jogo). Agora o que está perto fica em listas refeitas de tempo em tempo; gaveta e baú não andam: posições guardadas.
const CACHE_A_CADA: float = 1.0
const CACHE_ZUMBI: float = 0.25
var _cache_t: float = 0.0
var _cache_z_t: float = 0.0
var _z_perto: Array = []
var _baus_perto: Array = []
var _gav_perto: Array = []
var _gav_nos: Array = []
var _gav_pos: PackedVector3Array = []


func _atualiza_cache(dt: float) -> void:
	var p: Vector3 = jogador.global_position
	_cache_z_t -= dt
	if _cache_z_t <= 0.0:
		_cache_z_t = CACHE_ZUMBI
		_z_perto.clear()
		var m: Node = get_tree().get_first_node_in_group("principal")
		if m and m.zumbis:
			var lim: float = (SAQUEADOR_VE + 15.0) * (SAQUEADOR_VE + 15.0)
			for z: Node in m.zumbis.get_children():
				if (z as Node3D).global_position.distance_squared_to(p) < lim:
					_z_perto.append(z)
	_cache_t -= dt
	if _cache_t > 0.0:
		return
	_cache_t = CACHE_A_CADA
	var n: int = get_tree().get_node_count_in_group("gavetas")
	if n != _gav_nos.size():  # mundo mudou (carregou): guarda de novo quem é gaveta de móvel e onde fica
		_gav_nos.clear()
		_gav_pos.clear()
		for g: Node in get_tree().get_nodes_in_group("gavetas"):
			_gav_nos.append(g)
			_gav_pos.append((g as Node3D).global_position if (g as Gaveta).movel != "porta_malas" else Vector3.INF)
	_gav_perto.clear()
	for k in _gav_pos.size():
		if _gav_pos[k].distance_squared_to(p) < 900.0:  # 30 m: quem pode entrar nos 15 m até a próxima volta
			_gav_perto.append(_gav_nos[k])
	_baus_perto.clear()
	for b: Node in get_tree().get_nodes_in_group("baus"):
		if (b as Node3D).global_position.distance_squared_to(p) < 2500.0:
			_baus_perto.append(b)


func _draw() -> void:
	if not visible or jogador == null:
		return
	var b: Bairro = _bairro()
	var m: Node = get_tree().get_first_node_in_group("principal")
	# zumbis perto (pontinhos vermelhos, sem prender na borda)
	if m and m.zumbis:
		for z: Variant in _z_perto:
			if not is_instance_valid(z):
				continue
			var zz := z as Zumbi
			if zz == null or zz.vida <= 0:
				continue
			var dz: float = zz.global_position.distance_to(jogador.global_position)
			if zz.humano():  # 07/11 (dono): saqueador marcado no mapa de longe: losango laranja com borda preta
				if dz < SAQUEADOR_VE:
					var qs: Vector2 = no_quadro(zz.global_position)
					if Rect2(Vector2.ZERO, TAM).has_point(qs):
						var pts := PackedVector2Array([qs + Vector2(0, -5.5), qs + Vector2(5.5, 0), qs + Vector2(0, 5.5), qs + Vector2(-5.5, 0)])
						draw_colored_polygon(pts, Color(1.0, 0.55, 0.1))
						draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.05, 0.05, 0.05), 1.5)
			elif dz < 6.0 or (dz < ZUMBI_VE and _na_vista(zz.global_position)):  # 07/11: só o que você vê (ou ouve colado)
				var q: Vector2 = no_quadro(zz.global_position)
				if Rect2(Vector2.ZERO, TAM).has_point(q):
					draw_circle(q, 3.2, Color(0.95, 0.15, 0.1))
	# 07/11: comerciante andarilho ($ verde, preso na borda quando longe)
	for ln: Node in get_tree().get_nodes_in_group("lojista"):
		if String(ln.name) == "Comerciante":
			var ql: Vector2 = no_quadro((ln as Node3D).global_position)
			ql = ql.clamp(Vector2(8, 8), TAM - Vector2(8, 8))
			draw_circle(ql, 7.0, Color(0.15, 0.6, 0.25))
			draw_string(get_theme_default_font(), ql + Vector2(-4, 5), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# 07/11: baús com loot a até 30 m (quadradinho amarelo; vazio não aparece)
	for bn: Variant in _baus_perto:
		if not is_instance_valid(bn):
			continue
		var bb := bn as Bau
		if bb == null or bb.conteudo.is_empty() or bb.global_position.distance_to(jogador.global_position) > 30.0:
			continue
		var qb: Vector2 = no_quadro(bb.global_position)
		if Rect2(Vector2.ZERO, TAM).has_point(qb):
			draw_rect(Rect2(qb - Vector2(3.5, 3.5), Vector2(7, 7)), Color(1.0, 0.82, 0.2))
			draw_rect(Rect2(qb - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.1, 0.1, 0.1), false, 1.2)
	# 07/11: gavetas e armários ainda não revistados a até 15 m (pontinho azul)
	for gn: Variant in _gav_perto:
		if not is_instance_valid(gn):
			continue
		var gg := gn as Gaveta
		if gg == null or gg.aberta or gg.global_position.distance_to(jogador.global_position) > 15.0:
			continue
		var qg: Vector2 = no_quadro(gg.global_position)
		if Rect2(Vector2.ZERO, TAM).has_point(qg):
			draw_circle(qg, 2.4, Color(0.4, 0.75, 1.0))
	# salas seguras, marcos e raids (presos na borda quando longe)
	for s: Node in get_tree().get_nodes_in_group("salas_seguras"):
		_blip((s as Node3D).global_position, COR_SEGURA, "casa", false)
	for k: String in b.marcos_pos:
		_blip(b.marcos_pos[k], COR_MARCO, "marco", false)
	for c: Node in get_tree().get_nodes_in_group("suprimento"):
		_blip((c as Node3D).global_position, Color(0.3, 0.95, 0.3), "caixa", true)
	for r: Dictionary in b.raids:
		_blip(r.pos, COR_RAID, "raid", true)
	if m and m.has_method("amigos"):
		for a: Node in m.amigos():
			_blip((a as Node3D).global_position, COR_AMIGO, "amigo", true)
	# destino marcado no mapa grande: alfinete amarelo preso na borda e a distância
	if destino.is_finite():
		var dd: float = Vector2(destino.x - jogador.global_position.x, destino.z - jogador.global_position.z).length()
		if dd < CHEGOU:
			destino = Vector3.INF
		else:
			var rd: Array = _na_borda(no_quadro(destino))
			draw_circle(rd[0], 8.5, Color(0, 0, 0, 0.85))
			draw_circle(rd[0], 6.5, Color(1.0, 0.85, 0.15))
			draw_string(ThemeDB.fallback_font, Vector2(8, TAM.y - 8), "%d m" % roundi(dd), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.4))
	# N na borda
	var n: Array = _na_borda(no_quadro(jogador.global_position + Vector3(0, 0, -10000)))
	draw_circle(n[0], 10, Color(0.1, 0.1, 0.1, 0.85))
	draw_string(ThemeDB.fallback_font, n[0] + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color.WHITE)
	# você: seta branca com contorno, sempre para cima (o mapa é que gira)
	var c: Vector2 = CENTRO * TAM
	var seta := PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, 8), c + Vector2(0, 4), c + Vector2(-7, 8)])
	draw_colored_polygon(seta, Color.WHITE)
	draw_polyline(seta + PackedVector2Array([seta[0]]), Color(0, 0, 0, 0.8), 1.5)


## prende = fica na borda quando longe (raid e amigo); o resto só aparece dentro do quadro (sem poluir a borda)
func _blip(w: Vector3, cor: Color, tipo: String, prende: bool) -> void:
	var r: Array = _na_borda(no_quadro(w))
	if r[1] and not prende:
		return
	var q: Vector2 = r[0]
	var raio: float = 5.0 if r[1] else 7.0
	draw_circle(q, raio + 1.5, Color(0, 0, 0, 0.8))
	draw_circle(q, raio, cor)
	if tipo == "raid":  # caveira simplificada: olhos pretos
		draw_circle(q + Vector2(-2.2, -1), 1.3, Color.BLACK)
		draw_circle(q + Vector2(2.2, -1), 1.3, Color.BLACK)


const SHADER := """shader_type canvas_item;
uniform sampler2D mapa : filter_linear, repeat_disable;
uniform vec2 pos = vec2(0.0);       // jogador em metros (local do Bairro)
uniform float ang = 0.0;            // giro da câmera
uniform float metros = 150.0;       // largura mostrada
uniform vec2 centro_q = vec2(0.5, 0.62);
uniform float aspecto = 0.74;       // altura / largura do quadro
const float N = 1024.0;
void fragment() {
	vec2 p = (UV - centro_q) * vec2(1.0, aspecto) * metros;  // metros na tela (x direita, y baixo)
	vec2 d = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang))) * p;
	vec2 uv = (pos + d + N * 0.5) / N;
	vec3 c = texture(mapa, uv).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) c = vec3(0.17, 0.2, 0.17);
	// cantos redondos e borda escura (retângulo do radar do GTA V)
	vec2 q = abs((UV - 0.5) * vec2(1.0, aspecto)) - (vec2(0.5, 0.5 * aspecto) - 0.06);
	float dist = length(max(q, 0.0)) - 0.06;
	if (dist > 0.0) discard;
	float borda = smoothstep(-0.018, 0.0, dist);
	COLOR = vec4(mix(c, vec3(0.04), borda), 0.9);
}"""
