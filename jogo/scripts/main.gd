# Pista de teste da mecânica 1 (andar + câmera): chão xadrez, caixas, rampas de 15°, 30° e 50° (íngreme demais),
# escada, túnel baixo para agachar, muros para testar a câmera contra paredes e um "carro" parado.
# Mecânica 5: zumbis do outro lado do túnel (só o servidor cria e controla; o spawner replica).
extends Node3D

## O jogador deste aparelho (null até a partida começar).
var jogador: Jogador
var controles: Controles
var rede: Rede
var menu: Menu
var jogadores: Node3D
var spawner: MultiplayerSpawner
var zumbis: Node3D
var soltos: Node3D  # itens largados (spawner: aparecem em todos os aparelhos)
var spawner_itens: MultiplayerSpawner
var spawner_zumbis: MultiplayerSpawner
var navegacao: NavigationRegion3D
var ciclo: Ciclo
## Onde os zumbis nascem (e levantam depois de mortos).
const PONTOS_ZUMBI: Array[Vector3] = [Vector3(-6, 0, 22), Vector3(0, 0, 26), Vector3(6, 0, 22), Vector3(24, 0, 0)]
## zumbis de tocaia: deitados ao lado do carro e no corredor entre os muros
const PONTOS_TOCAIA: Array[Vector3] = [Vector3(3.2, 0, 9.5), Vector3(13.5, 0, 9)]
## zumbis de patrulha: rota em volta da casinha (longe o bastante do início para não ver quem nasce)
const PATRULHAS: Array = [[Vector3(-32, 0, -9), Vector3(-32, 0, 5), Vector3(-19, 0, 5), Vector3(-19, 0, -9)]]
## zumbi chefe: grandão parado no fundo da pista, longe do início
const PONTOS_CHEFE: Array[Vector3] = [Vector3(0, 0, 40)]
var nick_local: String = "Jogador"


func _ready() -> void:
	add_to_group("principal")
	Config.carrega()
	_luz()
	_chao()
	_obstaculos()
	_baus()
	jogadores = Node3D.new()
	jogadores.name = "Jogadores"
	add_child(jogadores)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(jogadores)
	spawner.spawn_function = _cria_jogador
	jogadores.child_entered_tree.connect(_jogador_entrou)
	soltos = Node3D.new()
	soltos.name = "ItensSoltos"
	add_child(soltos)
	spawner_itens = MultiplayerSpawner.new()
	spawner_itens.name = "SpawnerItens"
	add_child(spawner_itens)
	spawner_itens.spawn_path = spawner_itens.get_path_to(soltos)
	spawner_itens.spawn_function = _cria_item_solto
	zumbis = Node3D.new()
	zumbis.name = "Zumbis"
	add_child(zumbis)
	spawner_zumbis = MultiplayerSpawner.new()
	spawner_zumbis.name = "SpawnerZumbis"
	add_child(spawner_zumbis)
	spawner_zumbis.spawn_path = spawner_zumbis.get_path_to(zumbis)
	spawner_zumbis.spawn_function = _cria_zumbi
	rede = Rede.new()
	rede.name = "Rede"
	add_child(rede)
	controles = Controles.new()
	add_child(controles)
	multiplayer.peer_connected.connect(_peer_conectou)
	multiplayer.peer_disconnected.connect(_peer_saiu)
	multiplayer.connection_failed.connect(_caiu_conexao.bind("Não conectou no servidor"))
	multiplayer.server_disconnected.connect(_caiu_conexao.bind("O servidor fechou a partida"))
	menu = Menu.new()
	menu.main = self
	add_child(menu)
	if "dedicado" in OS.get_cmdline_user_args():
		iniciar_servidor.call_deferred()


## Servidor dedicado (na nuvem): sem tela e sem jogador próprio; só recebe os jogadores e roda os zumbis.
## Rodar: godot --headless --main-pack servidor.pck -- dedicado   (com "ws": WebSocket na porta PORTA_WS, para o site)
func iniciar_servidor() -> Error:
	var ws: bool = "ws" in OS.get_cmdline_user_args()
	Rede.servidor_sem_tela = DisplayServer.get_name() == "headless"
	if Rede.servidor_sem_tela:
		Engine.physics_ticks_per_second = 30  # zumbis e colisões a 30 Hz bastam; cada celular roda o próprio a 60
		Engine.max_fps = 30
	var err: Error = rede.criar("Servidor", false, Rede.PORTA_WS if ws else 0)
	if err != OK:
		printerr("SERVIDOR: não abriu a porta %d (erro %d)" % [Rede.PORTA, err])
		get_tree().quit(1)
		return err
	_comeca()
	controles.visible = false
	_poe_zumbis()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("status="):
			_status(a.trim_prefix("status="))
	print("SERVIDOR pronto na porta %d%s (versão de rede %d)" % [Rede.PORTA_WS if ws else Rede.PORTA, " (WebSocket)" if ws else "", Rede.VERSAO])
	return OK


func _caiu_conexao(motivo: String) -> void:
	rede.sair()
	get_tree().reload_current_scene()
	Menu.aviso_inicial = motivo


## Joga sozinho, sem rede.
func iniciar_solo(nick: String = "Jogador") -> void:
	nick_local = nick
	_comeca()
	spawner.spawn({"id": multiplayer.get_unique_id(), "pos": _ponto_inicial(0)})
	_poe_zumbis()


## Cria a partida neste aparelho (vira o servidor) e já entra nela.
func criar_partida(nick: String) -> Error:
	nick_local = nick
	var err: Error = rede.criar(nick)
	if err != OK:
		return err
	_comeca()
	spawner.spawn({"id": 1, "pos": _ponto_inicial(0)})
	_poe_zumbis()
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
		if jogadores.get_child_count() >= limite_jogadores():
			_cheio.rpc_id(id)  # avisa e fecha: acima do limite o servidor pesa e todo mundo sente
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if multiplayer.multiplayer_peer:
					multiplayer.multiplayer_peer.disconnect_peer(id))
			return
		spawner.spawn({"id": id, "pos": _ponto_inicial(jogadores.get_child_count())})


# servidor: a cada 5 s escreve como está (para a página do site e para medir até onde aguenta)
func _status(caminho: String) -> void:
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"jogadores": jogadores.get_child_count(), "limite": limite_jogadores(),
				"zumbis": zumbis.get_child_count(), "fps": Engine.get_frames_per_second(),
				"fisica_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
				"quadro_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
				"memoria_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1), "versao": Rede.VERSAO})))


## Aviso na tela de todos (faixa no alto).
@rpc("authority", "call_local", "reliable")
func aviso_todos(texto: String) -> void:
	if controles:
		controles.aviso(texto)


## Servidor (ou sozinho): põe no chão um item largado/que não coube na mochila.
func solta_item(tipo: String, qtd: int, pos: Vector3, some: float = Item.SOME) -> void:
	var d := {"tipo": tipo, "qtd": qtd, "pos": pos, "some": some}
	if multiplayer.has_multiplayer_peer():
		spawner_itens.spawn(d)
	else:
		soltos.add_child(_cria_item_solto(d))


func _cria_item_solto(d: Dictionary) -> Node:
	if d.has("saco"):
		var b := Bau.new()
		b.saco = true
		b.conteudo = d.saco
		b.position = d.pos
		return b
	var it := Item.new()
	it.tipo = String(d.tipo)
	it.quantidade = int(d.qtd)
	it.solto = true
	it._some_t = float(d.get("some", Item.SOME))
	it.position = d.pos
	return it


## Máximo de jogadores neste servidor: Rede.MAX_JOGADORES, ou "max=N" na linha de comando (servidor pequeno).
func limite_jogadores() -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("max="):
			return int(a.trim_prefix("max="))
	return Rede.MAX_JOGADORES


@rpc("authority", "call_remote", "reliable")
func _cheio() -> void:
	_caiu_conexao("Servidor cheio. Tente de novo mais tarde.")


func _peer_saiu(id: int) -> void:
	var n: Node = jogadores.get_node_or_null(str(id))
	if n:
		if multiplayer.is_server():
			saiu_morrendo(n as Jogador)
		n.queue_free()


## Servidor: quem sai do jogo caído ou em luta (dano há menos de 10 s) larga o saco com a última cópia da mochila.
func saiu_morrendo(j: Jogador) -> bool:
	var em_luta: bool = Time.get_ticks_msec() / 1000.0 - j.dano_srv_t < 10.0
	if (j.vida <= 0 or em_luta) and not j.copia_mochila.is_empty():
		solta_saco(j.copia_mochila, j.global_position)
		return true
	return false


## Servidor (ou sozinho): saco com as coisas de quem caiu; qualquer um revista. Some vazio ou em 10 min.
func solta_saco(tudo: Array, pos: Vector3) -> void:
	var d := {"saco": tudo, "pos": pos}
	if multiplayer.has_multiplayer_peer():
		spawner_itens.spawn(d)
	else:
		soltos.add_child(_cria_item_solto(d))


# quem manda nos zumbis (sozinho ou servidor): faz a malha de navegação e cria os zumbis
func _poe_zumbis() -> void:
	navegacao = NavigationRegion3D.new()
	var malha := NavigationMesh.new()
	malha.agent_radius = 0.35  # cabe pela porta de 1,3 m
	malha.agent_height = 1.8
	malha.agent_max_climb = 0.35
	malha.agent_max_slope = 40.0
	malha.cell_size = 0.2
	malha.cell_height = 0.1
	malha.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	malha.geometry_collision_mask = 1
	malha.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	malha.geometry_source_group_name = &"cenario"
	malha.filter_baking_aabb = AABB(Vector3(-40, -1, -30), Vector3(80, 10, 70))  # só a pista
	navegacao.navigation_mesh = malha
	add_child(navegacao)
	add_to_group("cenario")
	navegacao.bake_navigation_mesh(false)
	for p: Vector3 in PONTOS_ZUMBI:
		spawner_zumbis.spawn({"pos": p})
	for p: Vector3 in PONTOS_TOCAIA:
		spawner_zumbis.spawn({"pos": p, "tocaia": true})
	for r: Array in PATRULHAS:
		spawner_zumbis.spawn({"pos": r[0], "rota": r})
	for p: Vector3 in PONTOS_CHEFE:
		spawner_zumbis.spawn({"pos": p, "chefe": true})


func _cria_zumbi(dados: Dictionary) -> Node:
	var z := Zumbi.new()
	z.position = dados.pos
	z.casa = dados.pos
	z.tocaia = bool(dados.get("tocaia", false))
	z.rota = dados.get("rota", [])
	z.chefe = bool(dados.get("chefe", false))
	return z


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
	ciclo = Ciclo.new()
	ciclo.name = "Ciclo"
	add_child(ciclo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 40.0
	sol.add_to_group("sol")
	add_child(sol)
	Config.aplica.call_deferred(get_tree())  # sombras, som, resolução e quadros do jogador
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
	ciclo.sol = sol
	ciclo.ambiente = env


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


## Baús da pista (nome fixo: o mesmo em todos os aparelhos). [posição, giro em graus, fácil]
const BAUS: Array = [[Vector3(-26.25, 0, -0.55), 90.0, true], [Vector3(3, 0, -9), 0.0, false],
	[Vector3(-30, 0, 16), 200.0, false], [Vector3(19.5, 0, 13), 270.0, false]]


## Armas brancas largadas pela pista (mecânica 4: arma branca só se acha no mapa). [tipo, posição, giro]
const BRANCAS_MAPA: Array = [["faca", Vector3(-1.5, 0, 1.5), 30.0], ["taco", Vector3(10, 0, 5.5), 100.0],
	["machado", Vector3(-28.6, 0, 2.6), 200.0]]


## Pontos da cidade onde a bancada pode aparecer (ela muda a cada 10 min).
const PONTOS_BANCADA: Array = [Vector3(-6, 0, -2), Vector3(14, 0, -3), Vector3(-17, 0, -12), Vector3(4, 0, 18), Vector3(-30, 0, 9)]
var bancada: Bancada


func _baus() -> void:
	bancada = Bancada.new()
	bancada.name = "Bancada"
	bancada.pontos = PONTOS_BANCADA
	bancada.position = PONTOS_BANCADA[0]
	add_child(bancada)
	bancada.mudou_de_lugar.connect(func() -> void:
		if multiplayer.has_multiplayer_peer():
			aviso_todos.rpc("A bancada apareceu em outro lugar da cidade")
		else:
			aviso_todos("A bancada apareceu em outro lugar da cidade"))
	for k in BRANCAS_MAPA.size():
		var it := Item.new()
		it.name = "Item_branca_%d" % k
		it.tipo = BRANCAS_MAPA[k][0]
		it.quantidade = 1
		it.position = BRANCAS_MAPA[k][1]
		it.rotation_degrees.y = BRANCAS_MAPA[k][2]
		add_child(it)
	for k in BAUS.size():
		var b := Bau.new()
		b.name = "Bau_%d" % k
		b.position = BAUS[k][0]
		b.rotation_degrees.y = BAUS[k][1]
		b.facil = BAUS[k][2]
		add_child(b)


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
	# bonecos de treino para o facão (perto do começo)
	for p: Vector3 in [Vector3(-3, 0, 4), Vector3(-5, 0, 5.5), Vector3(-1.5, 0, 6)]:
		var b := BonecoTreino.new()
		b.position = p
		add_child(b)
	# caixas de munição pelo chão (mesmo nome em todos os aparelhos: só o "pegou ou não" vai pela rede)
	var itens: Array = [[Vector3(2.5, 0, -3), 20.0], [Vector3(-8, 0, 3.5), 75.0], [Vector3(13.5, 0, 3), 160.0],
		[Vector3(-1, 0, 19), 300.0]]
	for k in itens.size():
		var it := Item.new()
		it.name = "Item_%d" % k
		it.tipo = "municao"
		it.quantidade = 24
		it.position = itens[k][0]
		it.rotation_degrees.y = itens[k][1]
		add_child(it)
	# casinha com porta (mecânica 12): 6 x 5 m, porta no lado leste, uma caixa de munição dentro
	var parede := Color(0.6, 0.57, 0.52)
	bloco(Vector3(-24, 1.3, -4.5), Vector3(6.2, 2.6, 0.2), parede)          # sul
	bloco(Vector3(-24, 1.3, 0.5), Vector3(6.2, 2.6, 0.2), parede)           # norte
	bloco(Vector3(-27, 1.3, -2), Vector3(0.2, 2.6, 5.0), parede)            # oeste
	bloco(Vector3(-21, 1.3, -3.625), Vector3(0.2, 2.6, 1.95), parede)       # leste, dos dois lados da porta
	bloco(Vector3(-21, 1.3, -0.375), Vector3(0.2, 2.6, 1.95), parede)
	bloco(Vector3(-21, 2.375, -2), Vector3(0.2, 0.45, 1.3), parede)         # em cima da porta
	bloco(Vector3(-24, 2.7, -2), Vector3(6.6, 0.2, 5.4), Color(0.35, 0.33, 0.3))  # teto
	var porta := Porta.new()
	porta.name = "Porta_0"
	porta.position = Vector3(-21, 0, -2.65)
	porta.rotation_degrees.y = -90.0  # folha para +Z, abre para dentro
	add_child(porta)
	var dentro := Item.new()
	dentro.name = "Item_casa"
	dentro.position = Vector3(-25.8, 0, -3.6)
	add_child(dentro)
	# comida e água (mecânica 15)
	for k in 3:
		for tipo: String in ["comida", "agua"]:
			var it := Item.new()
			it.name = "Item_%s_%d" % [tipo, k]
			it.tipo = tipo
			it.quantidade = 1
			it.position = [Vector3(-3.5, 0, -2.5), Vector3(9, 0, 4), Vector3(-25, 0, -0.8)][k] + (Vector3(0.45, 0, 0.2) if tipo == "agua" else Vector3.ZERO)
			it.rotation_degrees.y = 37.0 * k + (90.0 if tipo == "agua" else 0.0)
			add_child(it)
	# "carro" abandonado
	bloco(Vector3(5, 0.7, 6), Vector3(1.9, 1.0, 4.2), Color(0.3, 0.35, 0.4), Vector3(0, 20, 0))
	bloco(Vector3(5, 1.45, 6), Vector3(1.7, 0.6, 2.2), Color(0.25, 0.3, 0.35), Vector3(0, 20, 0))
