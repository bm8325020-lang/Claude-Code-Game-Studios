# Pista de teste da mecânica 1 (andar + câmera): chão xadrez, caixas, rampas de 15°, 30° e 50° (íngreme demais),
# escada, túnel baixo para agachar, muros para testar a câmera contra paredes e um "carro" parado.
extends Node3D

## O jogador deste aparelho (null até a partida começar).
var jogador: Jogador
var controles: Controles
var rede: Rede
var menu: Menu
var jogadores: Node3D
var spawner: MultiplayerSpawner
var nick_local: String = "Jogador"


func _ready() -> void:
	_luz()
	_chao()
	_obstaculos()
	jogadores = Node3D.new()
	jogadores.name = "Jogadores"
	add_child(jogadores)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(jogadores)
	spawner.spawn_function = _cria_jogador
	jogadores.child_entered_tree.connect(_jogador_entrou)
	rede = Rede.new()
	rede.name = "Rede"
	add_child(rede)
	controles = Controles.new()
	add_child(controles)
	multiplayer.peer_connected.connect(_peer_conectou)
	multiplayer.peer_disconnected.connect(_peer_saiu)
	menu = Menu.new()
	menu.main = self
	add_child(menu)


## Joga sozinho, sem rede.
func iniciar_solo(nick: String = "Jogador") -> void:
	nick_local = nick
	_comeca()
	spawner.spawn({"id": multiplayer.get_unique_id(), "pos": _ponto_inicial(0)})


## Cria a partida neste aparelho (vira o servidor) e já entra nela.
func criar_partida(nick: String) -> Error:
	nick_local = nick
	var err: Error = rede.criar(nick)
	if err != OK:
		return err
	_comeca()
	spawner.spawn({"id": 1, "pos": _ponto_inicial(0)})
	_aviso("Partida criada. IP para o amigo: " + ", ".join(ips_locais()))
	return OK


## Entra na partida de outro aparelho; o servidor cria o nosso jogador quando a conexão fecha.
func entrar_partida(ip: String, nick: String) -> Error:
	nick_local = nick
	var err: Error = rede.entrar(ip)
	if err != OK:
		return err
	_comeca()
	return OK


## IPs deste aparelho na rede local (o amigo digita um deles se a busca automática não achar).
static func ips_locais() -> Array[String]:
	var out: Array[String] = []
	for ip: String in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			out.append(ip)
	return out


func _aviso(texto: String) -> void:
	var camada := CanvasLayer.new()
	var l := Label.new()
	l.text = texto
	l.position = Vector2(20, 14)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	camada.add_child(l)
	add_child(camada)


func _comeca() -> void:
	menu.visible = false
	rede.parar_procura()


func _peer_conectou(id: int) -> void:
	if multiplayer.is_server():
		spawner.spawn({"id": id, "pos": _ponto_inicial(jogadores.get_child_count())})


func _peer_saiu(id: int) -> void:
	var n: Node = jogadores.get_node_or_null(str(id))
	if n:
		n.queue_free()


func _ponto_inicial(i: int) -> Vector3:
	return Vector3(2.0 * float(i % 6), 0.1, 2.0 * float(i / 6))


# roda em todos os aparelhos (o spawner replica): cria o boneco; o dono controla
func _cria_jogador(dados: Dictionary) -> Node:
	var id: int = int(dados.id)
	var j := Jogador.new()
	j.name = str(id)
	j.set_multiplayer_authority(id)
	j.local = id == multiplayer.get_unique_id()
	j.position = dados.pos
	return j


func _jogador_entrou(n: Node) -> void:
	var j := n as Jogador
	if j and j.local:
		jogador = j
		j.nick = nick_local
		controles.jogador = j


func _luz() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 40.0
	add_child(sol)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.68)  # céu cinza de apocalipse
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.66, 0.68)
	env.fog_density = 0.008
	amb.environment = env
	add_child(amb)


func _mat(cor: Color, xadrez: bool = false) -> Material:
	if not xadrez:
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.9
		return m
	# xadrez de 1 m: dá para ver a velocidade e a distância andando
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec3 a; uniform vec3 b;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = floor(wp.xz);
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(a, b, k);
	ROUGHNESS = 0.95;
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("a", Vector3(cor.r, cor.g, cor.b))
	sm.set_shader_parameter("b", Vector3(cor.r * 0.82, cor.g * 0.82, cor.b * 0.82))
	return sm


## Bloco sólido com colisão (centro, tamanho, giro em graus).
func bloco(c: Vector3, tam: Vector3, cor: Color, rot: Vector3 = Vector3.ZERO, xadrez: bool = false) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.position = c
	corpo.rotation_degrees = rot
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor, xadrez)
	corpo.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	corpo.add_child(cs)
	add_child(corpo)
	return corpo


func _chao() -> void:
	bloco(Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color(0.42, 0.41, 0.38), Vector3.ZERO, true)


func _rampa(base: Vector3, graus: float, comprimento: float, largura: float, cor: Color) -> void:
	# rampa subindo para +Z a partir de `base`, seguida de uma plataforma no topo
	var h: float = sin(deg_to_rad(graus)) * comprimento
	var meio: Vector3 = base + Vector3(0, h * 0.5, cos(deg_to_rad(graus)) * comprimento * 0.5)
	bloco(meio - Vector3(0, 0.1, 0), Vector3(largura, 0.2, comprimento), cor, Vector3(-graus, 0, 0), true)
	var topo_z: float = base.z + cos(deg_to_rad(graus)) * comprimento
	bloco(Vector3(base.x, h * 0.5 - 0.01, topo_z + 2.0), Vector3(largura, h, 4.0), cor, Vector3.ZERO, true)


func _obstaculos() -> void:
	var concreto := Color(0.55, 0.53, 0.5)
	var ferrugem := Color(0.5, 0.33, 0.22)
	# caixas: 0,4 m (pulo fácil), 1,0 m (pulo no limite), 2,5 m (não dá)
	bloco(Vector3(-4, 0.2, -6), Vector3(1.2, 0.4, 1.2), ferrugem)
	bloco(Vector3(-6, 0.5, -6), Vector3(1.2, 1.0, 1.2), ferrugem)
	bloco(Vector3(-8.5, 1.25, -6), Vector3(1.5, 2.5, 1.5), ferrugem)
	# rampas
	_rampa(Vector3(6, 0, -14), 15.0, 8.0, 3.0, concreto)
	_rampa(Vector3(11, 0, -14), 30.0, 6.0, 3.0, concreto)
	_rampa(Vector3(16, 0, -14), 50.0, 4.0, 3.0, Color(0.6, 0.4, 0.38))  # íngreme demais: escorrega
	# escada: degraus de 0,2 m; uma rampa invisível embaixo deixa subir sem pular
	for i in 8:
		var alto: float = (i + 1) * 0.2
		bloco(Vector3(-14, alto * 0.5, -10 - i * 0.35), Vector3(2.4, alto, 0.35), concreto)
	var ang: float = rad_to_deg(atan2(1.6, 2.8))
	var rampa_escada := bloco(Vector3(-14, 0.78, -10.875), Vector3(2.4, 0.05, Vector2(2.8, 1.6).length()), concreto, Vector3(ang, 0, 0))
	(rampa_escada.get_child(0) as MeshInstance3D).visible = false
	# túnel baixo (1,4 m): só passa agachado
	bloco(Vector3(0, 1.6, 12), Vector3(3, 0.4, 6), concreto)
	bloco(Vector3(-1.7, 0.7, 12), Vector3(0.4, 1.4, 6), concreto)
	bloco(Vector3(1.7, 0.7, 12), Vector3(0.4, 1.4, 6), concreto)
	# muros e um corredor estreito: a câmera tem que chegar perto sem atravessar
	bloco(Vector3(12, 2, 8), Vector3(0.5, 4, 14), concreto)
	bloco(Vector3(15, 2, 8), Vector3(0.5, 4, 14), concreto)
	bloco(Vector3(-12, 3, 10), Vector3(8, 6, 8), Color(0.48, 0.47, 0.46))  # "prédio"
	# "carro" abandonado
	bloco(Vector3(5, 0.7, 6), Vector3(1.9, 1.0, 4.2), Color(0.3, 0.35, 0.4), Vector3(0, 20, 0))
	bloco(Vector3(5, 1.45, 6), Vector3(1.7, 0.6, 2.2), Color(0.25, 0.3, 0.35), Vector3(0, 20, 0))
