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
const BANDO: int = 2  # zumbis por ponto de zumbi do bairro (provisório)
const PONTOS_ZUMBI: Array[Vector3] = [Vector3(-6, 0, 22), Vector3(0, 0, 26), Vector3(6, 0, 22), Vector3(24, 0, 0)]
## zumbis de tocaia: deitados ao lado do carro e no corredor entre os muros
const PONTOS_TOCAIA: Array[Vector3] = [Vector3(3.2, 0, 9.5), Vector3(13.5, 0, 9)]
## zumbis de patrulha: rota em volta da casinha (longe o bastante do início para não ver quem nasce)
const PATRULHAS: Array = [[Vector3(-32, 0, -9), Vector3(-32, 0, 5), Vector3(-19, 0, 5), Vector3(-19, 0, -9)]]
## zumbi chefe: grandão parado no fundo da pista, longe do início
const PONTOS_CHEFE: Array[Vector3] = [Vector3(0, 0, 40)]
var nick_local: String = "Jogador"
var bairro: Bairro
## nasce no bairro (o jogo); os testes que medem a pista desligam
static var nascer_no_bairro: bool = true
var grupos := Grupos.new()  # servidor: quem está com quem
var horda := Horda.new()  # servidor: horda andarilha (mods de zumbi do GTA V)
var populacao := Populacao.new()  # servidor: zumbis em volta de quem está na cidade (GTAZ: orçamento + fila)
var suprimento := Suprimento.new()  # servidor: caixa que cai do céu (Simple Zombies, Crate Drop)
var faccoes := Faccoes.new()  # servidor: facções e domínios em andamento
var _faccoes_cli: Dictionary = {"f": {}, "t": {}}  # todos: cópia que o servidor manda
var _faccao_tick: float = 0.0
var _grupos_cli: Dictionary = {}  # todos: cópia que o servidor manda (peer -> grupo)
var salas := Salas.new()  # servidor: salas de PvP (prompt 23)
var _salas_cli: Dictionary = {"de": {}, "salas": {}}  # todos: cópia que o servidor manda
var lista_salas: Array = []  # cliente: últimas salas públicas pedidas
var abrir_pvp: bool = false  # entrou pelo botão PVP do menu: abre a página das salas assim que nascer
var _salas_tick: float = 0.0
var _pvp_caido: Dictionary = {}  # servidor: peer derrubado no PvP esperando renascer (não conta duas vezes)
signal salas_mudou(erro: String)


func _ready() -> void:
	add_to_group("principal")
	Config.carrega()
	if "dedicado" in OS.get_cmdline_user_args() and DisplayServer.get_name() == "headless":
		Rede.servidor_sem_tela = true  # antes da cidade: ela pula o que é só enfeite
	if Estilo.LIGADO and not Rede.servidor_sem_tela and not get_tree().node_added.is_connected(Estilo.entrou):
		get_tree().node_added.connect(Estilo.entrou)  # 13/11: visual de desenho em tudo que entra na árvore
	_luz()
	_chao()
	_obstaculos()
	bairro = Bairro.new()
	bairro.name = "Bairro"
	add_child(bairro)
	if Estilo.LIGADO and not Rede.servidor_sem_tela:
		var grama := Grama.new()  # 13/11: grama de folhinhas em volta da câmera
		grama.name = "Grama"
		grama.bairro = bairro
		add_child(grama)
	var fauna := Fauna.new()  # 13/11: lobo, javali e raposa na mata
	fauna.name = "Fauna"
	fauna.principal = self
	add_child(fauna)
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
	bichos_no = Node3D.new()  # 14/11: bichos da floresta pela rede (o servidor cria, todos veem)
	bichos_no.name = "Bichos"
	add_child(bichos_no)
	spawner_bichos = MultiplayerSpawner.new()
	spawner_bichos.name = "SpawnerBichos"
	add_child(spawner_bichos)
	spawner_bichos.spawn_path = spawner_bichos.get_path_to(bichos_no)
	spawner_bichos.spawn_function = func(d: Dictionary) -> Node:
		var b := Bicho.new()
		b.tipo = String(d.tipo)
		b.position = d.pos
		return b
	rede = Rede.new()
	rede.name = "Rede"
	add_child(rede)
	controles = Controles.new()
	add_child(controles)
	if OS.has_feature("mobile"):
		Engine.physics_ticks_per_second = 30  # celular (vídeo do dono: 10-20 quadros/s): física e zumbis a 30 Hz, a tela interpola
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
	# DD_COM_TELA=1: ferramenta de medida sem janela, mas montando tudo que a tela monta (tools/picos.gd)
	Rede.servidor_sem_tela = DisplayServer.get_name() == "headless" and OS.get_environment("DD_COM_TELA") == ""
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
	if "relay" in OS.get_cmdline_user_args():  # o carteiro das salas no mesmo processo (memória do serviço grátis)
		add_child(Relay.new())
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


# --- Salas de sobrevivência (prompt 24): quem cria hospeda o mundo; o carteiro online (relay.gd) lista e repassa ---
const RELAY_URL: String = "wss://zumbi-servidor.onrender.com/salas"
var relay: RelayPeer
## A minha sala: {"codigo", "nome", "max", "n"}; vazio = não é sala de sobrevivência.
var sala_sobrev: Dictionary = {}
## Tela de espera: todos parados até encher a sala ou o dono apertar COMEÇAR.
var esperando: bool = false
signal relay_msg(m: Dictionary)


## Liga no carteiro (para listar, criar ou entrar). Mensagens chegam por relay_msg.
func abre_relay(url: String = RELAY_URL) -> void:
	if relay:
		relay.close()
	relay = RelayPeer.new()
	relay.controle.connect(_relay_controle)
	relay.conecta(url)


func _relay_controle(m: Dictionary) -> void:
	match String(m.get("op", "")):
		"criada":
			sala_sobrev.codigo = m.codigo
			multiplayer.multiplayer_peer = relay
			mostra_carregando()
			for i in 2:  # a tela de carregamento precisa ser desenhada antes de montar o mundo (sem tela: só espera o quadro)
				await (get_tree().process_frame if DisplayServer.get_name() == "headless" else RenderingServer.frame_post_draw)
			_comeca()
			spawner.spawn({"id": 1, "pos": _ponto_inicial(0)})
			_poe_zumbis()
			muda_espera(false)  # começa na hora (dono, 31/10: esperar todos demorava); os amigos entram no meio
		"entrou":
			sala_sobrev = {"codigo": "", "nome": m.get("nome", ""), "max": 0, "n": 0}
		"erro":
			if multiplayer.multiplayer_peer == relay and not multiplayer.is_server():
				_caiu_conexao(String(m.msg))  # entrou com código errado/sala cheia: volta ao menu
	relay_msg.emit(m)


## Cria a sala e hospeda (o mundo roda aqui). `maximo` = quantos jogadores no total, contando quem cria.
## Arma que o jogador local já segura ao nascer nas salas de verdade (os testes seguem com o facão).
var arma_inicial: String = ""


func criar_sala_sobrev(nick: String, nome: String, publica: bool, maximo: int) -> void:
	arma_inicial = "punhos"
	Jogador.inicio_vazio = true  # história: nasce só com o rádio e o soco (06/11)
	nick_local = nick
	sala_sobrev = {"codigo": "", "nome": nome, "max": maximo, "n": 1}
	relay.criar(nome, publica, maximo)


func entrar_sala_sobrev(nick: String, cod: String) -> void:
	arma_inicial = "punhos"
	Jogador.inicio_vazio = true  # história: nasce só com o rádio e o soco (06/11)
	nick_local = nick
	mostra_carregando()
	relay.entrar(cod)
	multiplayer.multiplayer_peer = relay
	_comeca()


## Host: liga/desliga a espera (zumbis e relógio parados) e avisa todos. Começou: a lista mostra "jogando".
func muda_espera(e: bool) -> void:
	esperando = e
	zumbis.process_mode = Node.PROCESS_MODE_DISABLED if e else Node.PROCESS_MODE_INHERIT
	ciclo.set_process(not e)
	if not e and relay:
		relay.pede({"op": "comecou"})
	_recebe_espera.rpc(e, sala_sobrev)


@rpc("authority", "call_remote", "reliable")
func _recebe_espera(e: bool, sala: Dictionary) -> void:
	esperando = e
	sala_sobrev = sala


## Dono da sala: COMEÇAR (sozinho ou com quem já entrou).
func comecar_sala_sobrev() -> void:
	if multiplayer.is_server() and esperando:
		muda_espera(false)


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
		_recebe_salas.rpc_id(id, {"de": salas.de, "salas": salas.salas})  # quem chega já sabe das salas (e quem não vê)
		if not sala_sobrev.is_empty():
			sala_sobrev.n = jogadores.get_child_count()
			if esperando and sala_sobrev.n >= sala_sobrev.max:
				muda_espera(false)  # encheu: começa sozinho
			else:
				_recebe_espera.rpc(esperando, sala_sobrev)


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


# --- Campanha anti-lag (06/11) ---
## Anti-engasgo: no celular o shader de um material compila na primeira vez que ele aparece (trava 100-300 ms). Aqui,
## com a tela de carregamento por cima, um quadradinho de cada material da cidade é desenhado na frente da câmera.
func _aquece_shaders(j: Jogador) -> void:
	if Rede.servidor_sem_tela or j.camera == null or j.camera.cam == null:
		return
	var vistos: Dictionary = {}
	for g: Node in find_children("*", "GeometryInstance3D", true, false):
		var lista: Array = []
		if g is GeometryInstance3D and (g as GeometryInstance3D).material_override:
			lista.append((g as GeometryInstance3D).material_override)
		var malha: Mesh = (g as MeshInstance3D).mesh if g is MeshInstance3D else ((g as MultiMeshInstance3D).multimesh.mesh if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh else null)
		if g is CPUParticles3D:
			malha = (g as CPUParticles3D).mesh  # fumaça e faísca do fogo
		if malha:
			for i in malha.get_surface_count():
				if malha.surface_get_material(i):
					lista.append(malha.surface_get_material(i))
		for m: Material in lista:
			vistos[m.get_instance_id()] = m
	var raiz := Node3D.new()
	j.camera.cam.add_child(raiz)
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.02)
	var k: int = 0
	for id: int in vistos:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = vistos[id]
		mi.position = Vector3((k % 20) * 0.021 - 0.2, (k / 20 % 20) * 0.021 - 0.2, -0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		k += 1
	# 12/11 (dono: "do nada dá um pico de lag"): o que só aparece depois também compila na hora e trava. Então, ainda
	# atrás da tela de carregamento: (1) luz de lanterna e de tiro/fogo em cima dos quadradinhos (o primeiro anoitecer
	# ligava a lanterna e travava); (2) um boneco de cada zumbi/Corvo com cada pele (malha com esqueleto é outro shader e
	# a textura só sobe para a placa quando aparece: o primeiro zumbi na tela travava); (3) sangue e clarão de tiro.
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 0, -0.05)
	spot.spot_range = 2.0
	spot.spot_angle = 70.0
	spot.light_energy = 0.02
	raiz.add_child(spot)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 0, -0.3)
	omni.omni_range = 1.5
	omni.light_energy = 0.02
	raiz.add_child(omni)
	var mats_z: Dictionary = {}
	var n_z: int = 0
	for z: Node in zumbis.get_children():
		var zz := z as Zumbi
		if zz == null or zz.modelo == null or n_z >= 24:
			continue
		var novo: bool = false
		for mi: MeshInstance3D in zz.modelo.find_children("*", "MeshInstance3D", true, false):
			for i in (mi.mesh.get_surface_count() if mi.mesh else 0):
				var mt: Material = mi.get_active_material(i)
				if mt and not mats_z.has(mt.get_instance_id()):
					mats_z[mt.get_instance_id()] = true
					novo = true
		if novo:
			var copia: Node3D = zz.modelo.duplicate()
			copia.visible = true
			copia.scale = Vector3.ONE * 0.03
			copia.position = Vector3((n_z % 12) * 0.05 - 0.3, -0.2 - (n_z / 12) * 0.08, -0.7)
			raiz.add_child(copia)
			n_z += 1
	for par: Array in [[false, BaseMaterial3D.CULL_BACK], [true, BaseMaterial3D.CULL_DISABLED]]:  # rastro/clarão/gás
		var mq := StandardMaterial3D.new()
		mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mq.albedo_color = Color(1, 1, 1, 0.02)
		mq.cull_mode = par[1]
		var mi2 := MeshInstance3D.new()
		mi2.mesh = q
		mi2.material_override = mq
		mi2.position = Vector3(0.3 if par[0] else 0.32, 0.2, -0.5)
		raiz.add_child(mi2)
	Pistola.sangue(get_tree(), j.camera.cam.global_position - j.camera.cam.global_basis.z * 0.9, Vector3.UP)
	for t: String in Mochila.NOMES:  # ícones da mochila prontos: abrir a mochila pela primeira vez não trava
		Icones.de(t)
	get_tree().create_timer(0.5).timeout.connect(raiz.queue_free)


## Resolução dinâmica: o FPS caiu do alvo, a imagem 3D fica um pouco menor (o HUD não muda); melhorou, volta.
var _res_t: float = 0.0
var _res_escala: float = 1.0


const ZUMBI_VE_MIN: float = 24.0  # m: menos que isso o zumbi brota na cara


func _resolucao_dinamica(dt: float) -> void:
	_res_t += dt
	if _res_t < 2.0 or jogador == null:
		return
	_res_t = 0.0
	var alvo: float = float(Config.v.fps) if int(Config.v.fps) > 0 else 60.0
	var fps: float = Engine.get_frames_per_second()
	# 07/11 (D1): apertou, primeiro encurta até onde zumbi aparece (a névoa esconde; a imagem não borra), depois a
	# resolução; folgou, volta a resolução e depois os zumbis
	var ve_max: float = float(Config.qualidade().zumbi)
	if fps < alvo * 0.85:
		if Zumbi.VE_ATE > ZUMBI_VE_MIN:
			Zumbi.VE_ATE = maxf(Zumbi.VE_ATE - 6.0, ZUMBI_VE_MIN)
		else:
			_res_escala = maxf(_res_escala - 0.07, 0.6)
	elif fps > alvo * 0.97:
		if _res_escala < 1.0:
			_res_escala = minf(_res_escala + 0.05, 1.0)
		else:
			Zumbi.VE_ATE = minf(Zumbi.VE_ATE + 4.0, ve_max)
	get_tree().root.scaling_3d_scale = float(Config.v.resolucao) * _res_escala


## 12/11 anti-lag (dono: "do nada dá um pico de lag"): bando pedido de uma vez (horda de 13, onda da história, emboscada)
## nascia inteiro no mesmo quadro: ~3 ms por zumbi no PC, mais de 100 ms de trava no celular. Agora entra numa fila e
## nasce um por quadro; `depois` recebe o zumbi quando ele nasce (dar alvo, guardar na lista da onda).
var _fila_zumbis: Array = []


func zumbi_na_fila(d: Dictionary, depois: Callable = Callable()) -> void:
	_fila_zumbis.append([d, depois])


func _process(dt: float) -> void:
	Zumbi.tique_sono()
	Estilo.passa()
	if not _fila_zumbis.is_empty():
		var f: Array = _fila_zumbis.pop_front()
		var zf: Zumbi = spawner_zumbis.spawn(f[0])
		if zf and (f[1] as Callable).is_valid():
			(f[1] as Callable).call(zf)
	if not Rede.servidor_sem_tela:
		_resolucao_dinamica(dt)
	if relay and multiplayer.multiplayer_peer != relay:
		relay.poll()  # na tela de salas (ainda não é a conexão do jogo)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_divide_peso(dt)
		grupos.passa(dt)
		horda.passa(self, dt)
		populacao.passa(self, dt)
		suprimento.passa(self, dt)
		_passa_raids(dt)
		_passa_dominio(dt)
		_passa_salas(dt)


## Bomba (07/11): servidor arma; bipa e explode em Jogador.BOMBA_T s: arromba os portões blindados perto, fere quem
## estiver perto e faz o barulho que chama zumbi da cidade.
const BOMBA_RAIO: float = 9.0
const BOMBA_DANO: int = 90
@rpc("any_peer", "call_remote", "reliable")
func pede_bomba(pos: Vector3) -> void:
	var j: Node3D = null
	for jj: Node3D in get_tree().get_nodes_in_group("jogadores"):
		if jj.get_multiplayer_authority() == multiplayer.get_remote_sender_id():
			j = jj
	if j and j.global_position.distance_to(pos) < Jogador.BOMBA_PERTO + 2.0:
		arma_bomba(pos)


func arma_bomba(pos: Vector3) -> void:
	_bomba_fx.rpc(pos, 0)
	await get_tree().create_timer(Jogador.BOMBA_T).timeout
	for p: Porta in get_tree().get_nodes_in_group("portas"):
		if p.blindada and p.centro().distance_to(pos) < BOMBA_RAIO + 4.0:  # o portão inteiro (14 m) cai junto
			p.vida = 0
			p.aberta = true
	for j: Node3D in get_tree().get_nodes_in_group("jogadores"):
		var d: float = j.global_position.distance_to(pos)
		if d < BOMBA_RAIO * 0.7 and j.vida > 0:
			j.levar_dano(roundi(BOMBA_DANO * (1.0 - d / (BOMBA_RAIO * 0.7))), (j.global_position - pos).normalized() * 3.0)
	for z: Node3D in get_tree().get_nodes_in_group("zumbis"):
		var d: float = z.global_position.distance_to(pos)
		if d < BOMBA_RAIO * 0.7 and z.vida > 0:
			z.levar_golpe(roundi(BOMBA_DANO * 2 * (1.0 - d / (BOMBA_RAIO * 0.7))), z.global_position - pos, null)
	Zumbi.barulho(get_tree(), pos, 70.0)
	_bomba_fx.rpc(pos, 1)


## Todos: bip da bomba armada (fase 0) e a explosão (fase 1: clarão, fumaça, estrondo, tremida perto).
@rpc("authority", "call_local", "reliable")
func _bomba_fx(pos: Vector3, fase: int) -> void:
	if Rede.servidor_sem_tela:
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load("res://assets/sons/amb/explosao_longe.ogg") if fase == 1 else load("res://assets/sons/alarme.wav")
	s.max_db = 12.0 if fase == 1 else 0.0
	s.unit_size = 30.0 if fase == 1 else 6.0
	s.pitch_scale = 1.0 if fase == 1 else 2.2
	add_child(s)
	s.global_position = pos + Vector3(0, 1, 0)
	s.finished.connect(s.queue_free)
	s.play()
	if fase == 0:
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(s):
				s.stop()
				s.queue_free())
		if controles:
			controles.aviso("BOMBA ARMADA — SAIA DE PERTO!", Color(1, 0.35, 0.2))
		return
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 12.0
	luz.omni_range = 22.0
	add_child(luz)
	luz.global_position = pos + Vector3(0, 2, 0)
	var t := create_tween()
	t.tween_property(luz, "light_energy", 0.0, 0.9)
	t.tween_callback(luz.queue_free)
	var f := Fogo.new()
	f.tamanho = 1.4
	f.coluna = true
	add_child(f)
	f.global_position = pos
	get_tree().create_timer(25.0).timeout.connect(f.queue_free)
	if jogador and jogador.camera and jogador.global_position.distance_to(pos) < 40.0:
		jogador.camera.tremer(clampf(1.0 - jogador.global_position.distance_to(pos) / 40.0, 0.2, 1.0))


const RAIO_PVP: float = 110.0  # o PvP fica no centro da cidade (a cidade toda é grande demais para poucos)


# --- Resgate com raid (prompt 10): o caído pede, o servidor confere o grupo, solta os zumbis e decide o fim ---
const RESGATE_T: float = 90.0
const RESGATE_DINHEIRO: int = 60
const RESGATE_PECA: float = 0.35
var raids: Dictionary = {}  # servidor: peer caído -> tempo restante


@rpc("any_peer", "call_local", "reliable")
func pede_resgate() -> void:
	if not multiplayer.is_server():
		return
	var caido: int = _quem()
	var j := jogadores.get_node_or_null(str(caido)) as Jogador
	var vivos: Dictionary = {}
	for o: Jogador in jogadores.get_children():
		if o.vida > 0:
			vivos[int(String(o.name))] = o.global_position
	if j == null or raids.has(caido) or not grupos.pode_resgate(caido, j.global_position, vivos):
		if j:
			j.sem_resgate.rpc_id(caido)
		return
	inicia_raid(caido, j.global_position, Lojista.valor(j.copia_mochila), j.abates)


## Servidor: solta os zumbis da raid em volta do caído.
func inicia_raid(caido: int, pos: Vector3, valor: int, abates: int) -> void:
	raids[caido] = RESGATE_T
	var n: int = Grupos.zumbis_raid(valor, abates)
	for i in n:
		var ang: float = TAU * float(i) / float(n)
		var dr := {"pos": pos + Vector3(sin(ang), 0, cos(ang)) * randf_range(8.0, 12.0) + Vector3(0, 0.1, 0), "raid": caido}
		if i == 0:
			spawner_zumbis.spawn(dr)  # o primeiro já: a raid conta os vivos
		else:
			zumbi_na_fila(dr)
	aviso_todos.rpc("Resgate! Matem os %d zumbis" % n)


func restantes_raid(caido: int) -> int:
	return zumbis.get_children().filter(func(z: Zumbi) -> bool: return z.raid == caido and z.vida > 0).size()


func _passa_raids(dt: float) -> void:
	for caido: int in raids.keys():
		raids[caido] -= dt
		var j := jogadores.get_node_or_null(str(caido)) as Jogador
		if j == null or raids[caido] <= 0.0:
			raids.erase(caido)  # tempo acabou (o caído larga tudo sozinho) ou saiu do jogo
			continue
		if restantes_raid(caido) == 0:
			raids.erase(caido)
			j.levanta.rpc_id(caido)
			var rng := RandomNumberGenerator.new()
			for o: Jogador in jogadores.get_children():
				if grupos.mesmo(int(String(o.name)), caido) or o == j:
					o.ganhar("dinheiro", RESGATE_DINHEIRO)
					if rng.randf() < RESGATE_PECA:
						o.ganhar(Loot.PECAS[rng.randi() % Loot.PECAS.size()], 1)
			aviso_todos.rpc("%s foi resgatado" % j.nick)


# --- Grupos (prompt 9): o cliente pede, o servidor decide e manda o resultado para todos ---

func _quem() -> int:
	var id: int = multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _jogador_nick(nick: String) -> Jogador:
	for j: Jogador in jogadores.get_children():
		if j.nick.to_lower() == nick.strip_edges().to_lower():
			return j
	return null


## Convida pelo nick. Devolve "" se o pedido foi, ou o motivo (o servidor ainda pode recusar e avisa).
func convidar_nick(nick: String) -> String:
	if _jogador_nick(nick) == null:
		return "Ninguém com esse nick"
	_pede_convite.rpc_id(1, nick)
	return ""


@rpc("any_peer", "call_local", "reliable")
func _pede_convite(nick: String) -> void:
	if not multiplayer.is_server():
		return
	var de: int = _quem()
	var alvo := _jogador_nick(nick)
	var motivo: String = "Ninguém com esse nick" if alvo == null else grupos.convidar(de, int(String(alvo.name)))
	if motivo != "":
		aviso_todos.rpc_id(de, motivo)
		return
	var quem := jogadores.get_node_or_null(str(de)) as Jogador
	_recebe_convite.rpc_id(int(String(alvo.name)), quem.nick if quem else "?")


@rpc("authority", "call_local", "reliable")
func _recebe_convite(nick: String) -> void:
	if controles:
		controles.convite(nick)


## Resposta ao convite (botões ACEITAR/RECUSAR).
func responder_convite(aceita: bool) -> void:
	_responde.rpc_id(1, aceita)


@rpc("any_peer", "call_local", "reliable")
func _responde(aceita: bool) -> void:
	if multiplayer.is_server() and grupos.responder(_quem(), aceita) != 0:
		_manda_grupos()


func sair_grupo() -> void:
	_sai.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _sai() -> void:
	if multiplayer.is_server():
		grupos.sair(_quem())
		_manda_grupos()


func _manda_grupos() -> void:
	_recebe_grupos.rpc(grupos.de)


@rpc("authority", "call_local", "reliable")
func _recebe_grupos(d: Dictionary) -> void:
	var antes: bool = grupo_de(multiplayer.get_unique_id()) != 0
	_grupos_cli = d
	var agora: bool = grupo_de(multiplayer.get_unique_id()) != 0
	if controles and antes != agora:
		controles.aviso("Você entrou num grupo" if agora else "Você saiu do grupo", Color(0.35, 0.6, 0.9))


## Grupo de um jogador (0 = sozinho), pela cópia que o servidor mandou.
func grupo_de(peer: int) -> int:
	return int(_grupos_cli.get(peer, 0))


## Os outros jogadores do meu grupo (para o nome e a seta na tela).
func amigos() -> Array:
	var g: int = grupo_de(multiplayer.get_unique_id())
	if g == 0:
		return []
	return jogadores.get_children().filter(func(j: Node) -> bool: return j != jogador and grupo_de(int(String(j.name))) == g)


# --- Facções (prompt 12): dominar uma casa do bairro. O cliente pede, o servidor conta o tempo e decide ---

func _dentro_das_casas() -> Dictionary:
	var d: Dictionary = {}
	for j: Jogador in jogadores.get_children():
		if j.vida > 0 and bairro:
			var c: String = bairro.casa_em(j.global_position)
			if c != "":
				d[c] = d.get(c, []) + [j.nick]
	return d


@rpc("any_peer", "call_local", "reliable")
func pede_dominar() -> void:
	if not multiplayer.is_server():
		return
	var j := jogadores.get_node_or_null(str(_quem())) as Jogador
	if j == null or j.vida <= 0:
		return
	var casa: String = bairro.casa_em(j.global_position)
	var motivo: String = "Entre numa mansão para dominar" if not bairro.dominavel(casa) else faccoes.comecar(casa, j.nick, _dentro_das_casas().get(casa, []))
	if motivo != "":
		aviso_todos.rpc_id(_quem(), motivo)
		return
	aviso_todos.rpc("Alguém está tentando dominar uma casa do bairro")
	_manda_faccoes()


@rpc("any_peer", "call_local", "reliable")
func pede_adicionar(nick: String) -> void:
	if not multiplayer.is_server():
		return
	var j := jogadores.get_node_or_null(str(_quem())) as Jogador
	if j == null or _jogador_nick(nick) == null:
		aviso_todos.rpc_id(_quem(), "Ninguém com esse nick")
		return
	var motivo: String = faccoes.adicionar(j.nick, _jogador_nick(nick).nick)
	aviso_todos.rpc_id(_quem(), motivo if motivo != "" else "%s entrou na facção" % nick)
	_manda_faccoes()


func _passa_dominio(dt: float) -> void:
	_faccao_tick -= dt
	if _faccao_tick > 0.0:
		return
	_faccao_tick = 0.5
	var mudou: bool = not faccoes.tentativas.is_empty()
	var donas_antes: Dictionary = {}
	for n: String in faccoes.faccoes:
		donas_antes[faccoes.faccoes[n].casa] = n
	for ev: Array in faccoes.passa(0.5, _dentro_das_casas()):
		if ev[0] == "sucesso":
			aviso_todos.rpc("%s dominou uma casa" % ev[2])
			var b := bairro.bau_da(ev[1])
			if donas_antes.has(ev[1]) and faccoes.faccoes.has(donas_antes[ev[1]]):
				faccoes.faccoes[donas_antes[ev[1]]].guardado.append_array(b.conteudo)  # quem perdeu a área leva o baú
			b.faccao = ev[2]
			b.conteudo = faccoes.faccoes[ev[2]].guardado.duplicate(true)  # o que a facção tinha guardado volta
			faccoes.faccoes[ev[2]].guardado = []
		else:
			aviso_todos.rpc("O domínio da casa falhou")
	for ev: Array in faccoes.passa_manutencao(0.5):
		mudou = true
		if ev[0] == "aviso":
			_avisa_faccao(ev[1], "Faltam %d dias para perder a casa (fundo sem $%d)" % [ev[2], Faccoes.MANUT_CUSTO])
		elif ev[0] == "pagou":
			_avisa_faccao(ev[1], "Manutenção da casa paga")
		else:
			var b := bairro.bau_da(ev[2])
			b.faccao = ""
			b.conteudo = []  # não pagou: perde a casa e o baú
			_avisa_faccao(ev[1], "A facção perdeu a casa (manutenção não paga)")
	if mudou:
		_manda_faccoes()


func _avisa_faccao(nome: String, texto: String) -> void:
	for j: Jogador in jogadores.get_children():
		if j.nick in faccoes.faccoes[nome].membros:
			aviso_todos.rpc_id(int(String(j.name)), texto)


@rpc("any_peer", "call_local", "reliable")
func pede_depositar(valor: int) -> void:
	var j := jogadores.get_node_or_null(str(_quem())) as Jogador
	if multiplayer.is_server() and j and valor > 0 and valor <= 100000 and faccoes.depositar(j.nick, valor):
		_manda_faccoes()


# servidor: nenhum membro da facção ficou no servidor = casa liberada e o baú vai com a facção
func _libera_casas() -> void:
	var online: Array = jogadores.get_children().filter(func(j: Node) -> bool: return not j.is_queued_for_deletion()).map(func(j: Jogador) -> String: return j.nick)
	for n: String in faccoes.faccoes:
		var d: Dictionary = faccoes.faccoes[n]
		if d.casa != "" and not d.membros.any(func(m: String) -> bool: return m in online):
			var b := bairro.bau_da(d.casa)
			faccoes.liberar(n, b.conteudo)
			b.conteudo = []
			b.faccao = ""
	_manda_faccoes()


func _manda_faccoes() -> void:
	_recebe_faccoes.rpc({"f": faccoes.faccoes, "t": faccoes.tentativas})


@rpc("authority", "call_local", "reliable")
func _recebe_faccoes(d: Dictionary) -> void:
	_faccoes_cli = d


## Coisa dentro de uma mansão (bancada, loja): só membros da facção dona usam; fora de mansão, todos.
func pode_usar(no: Node, nick: String) -> bool:
	var n: Node = no
	while n and not String(n.name).begins_with("Mansao_"):
		n = n.get_parent()
	if n == null:
		return true
	var f: String = faccao_de(nick)
	return f != "" and String(_faccoes_cli.f[f].casa) == String(n.name)


## Facção de um nick pela cópia do servidor ("" = nenhuma).
func faccao_de(nick: String) -> String:
	for n: String in _faccoes_cli.f:
		if nick in _faccoes_cli.f[n].membros:
			return n
	return ""


## Lugar sorteado para nascer/renascer (prompt 11). Quem tem casa de facção renasce nela (prompt 13).
func ponto_nascer(nick: String = "", chance: float = Bairro.CHANCE_BOM) -> Vector3:
	var f: String = faccao_de(nick) if nick != "" else ""
	if f != "" and String(_faccoes_cli.f[f].casa) != "":
		return bairro.frente_da(_faccoes_cli.f[f].casa)  # quem tem casa de facção renasce nela
	return Bairro.sorteia(_rng_nascer, bairro.pontos_bons, bairro.pontos_ruins, chance)


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
		b.caixa = bool(d.get("caixa", false))
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
	if multiplayer.is_server():  # carro que ele dirigia fica vazio onde parou
		for c: Carro in get_tree().get_nodes_in_group("carros"):
			if c.motorista == id:
				c.motorista = 0
	if multiplayer.is_server():  # os zumbis que o celular dele pensava voltam para o servidor
		for z: Zumbi in zumbis.get_children():
			if z.pensa == id:
				z.muda_pensa.rpc(1)
	if multiplayer.is_server() and not sala_sobrev.is_empty():
		sala_sobrev.n = jogadores.get_child_count() - 1
		_recebe_espera.rpc(esperando, sala_sobrev)
	if multiplayer.is_server() and salas.sala_de(id) != "":
		salas.sair(id)
		_manda_salas()
	if multiplayer.is_server() and grupos.de.has(id):
		grupos.sair(id)
		_manda_grupos()
	var n: Node = jogadores.get_node_or_null(str(id))
	if n:
		if multiplayer.is_server():
			saiu_morrendo(n as Jogador)
		n.queue_free()
		if multiplayer.is_server():
			_libera_casas()


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
	# quem morre levanta zumbi deitado do lado do saco (Project Zomboid, Simple Zombies): acorda quando alguém chega
	if not em_pvp() and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		spawner_zumbis.spawn({"pos": pos + Vector3(0.9, 0.1, 0.0), "horda": Zumbi.DO_MORTO, "tocaia": true})


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
	_assa(navegacao, "pista")
	# a cidade tem a malha dela em pedaços de NAV_PEDACO (1 km² de uma vez estoura o Recast, 05/11): cada pedaço assa a
	# sua caixa com uma borda (border_size) e os vizinhos se ligam pela beira
	var meio: float = Bairro.TAMANHO * 0.5
	var n: int = ceili(Bairro.TAMANHO / NAV_PEDACO)
	var pedacos: Array = []
	for i in n:
		for j in n:
			var nav_b := NavigationRegion3D.new()
			var mb: NavigationMesh = malha.duplicate()
			mb.cell_size = 0.25  # área grande: célula um pouco maior para assar rápido
			mb.agent_radius = 0.25  # múltiplo da célula; 0,35 arredondava para 0,5 e fechava o vão da porta
			mb.border_size = 1.0  # a borda fica dentro da caixa: a caixa cresce 1 m para a malha acabar na linha do vizinho
			var canto: Vector3 = Bairro.ORIGEM - Vector3(meio + 1.0, 4, meio + 1.0) + Vector3(i * NAV_PEDACO, 0, j * NAV_PEDACO)
			mb.filter_baking_aabb = AABB(canto, Vector3(NAV_PEDACO + 2.0, 18, NAV_PEDACO + 2.0))  # rio e morro
			nav_b.navigation_mesh = mb
			add_child(nav_b)
			_assa(nav_b, "bairro_%d_%d" % [i, j])
			pedacos.append(nav_b)
	_liga_pedacos(pedacos, n)
	for p: Vector3 in bairro.pontos_zumbi:  # em bando de BANDO (dono 30/10: muito fácil)
		for k: int in (1 if int(Config.v.qualidade) <= 1 else BANDO):  # celular fraco: 1 por ponto (anti-travamento)
			spawner_zumbis.spawn({"pos": p + Vector3(k * 1.3, 0.1, k * 0.7)})
	for r: Dictionary in bairro.pontos_raid:  # raids: delegacia (policiais), hospital, mercado, igreja; mortos ficam mortos
		var dz := {"pos": r.pos, "armado": r.armado, "de_raid": true}
		if String(r.get("tipo", "")) != "":
			dz.tipo = r.tipo
		if r.get("amigo", false):
			dz.amigo = true
		spawner_zumbis.spawn(dz)
	for p: Vector3 in PONTOS_ZUMBI:
		spawner_zumbis.spawn({"pos": p})
	for p: Vector3 in PONTOS_TOCAIA:
		spawner_zumbis.spawn({"pos": p, "tocaia": true})
	for r: Array in PATRULHAS:
		spawner_zumbis.spawn({"pos": r[0], "rota": r})
	for p: Vector3 in PONTOS_CHEFE:
		spawner_zumbis.spawn({"pos": p, "chefe": true})


var bichos_no: Node3D
var spawner_bichos: MultiplayerSpawner


func _cria_zumbi(dados: Dictionary) -> Node:
	var z := Zumbi.new()
	z.position = dados.pos
	z.casa = dados.pos
	z.tocaia = bool(dados.get("tocaia", false))
	z.rota = dados.get("rota", [])
	z.chefe = bool(dados.get("chefe", false))
	z.raid = int(dados.get("raid", 0))
	z.armado = bool(dados.get("armado", false))
	z.de_raid = bool(dados.get("de_raid", false))
	z.tipo_pedido = String(dados.get("tipo", ""))
	z.amigavel = bool(dados.get("amigo", false))
	z.horda = int(dados.get("horda", 0))
	z.lider = bool(dados.get("lider", false))
	return z


var _rng_nascer := RandomNumberGenerator.new()


## Testes e ferramentas rodam com script na árvore: lá não tem abertura nem chegada pela estrada.
func _testando() -> bool:
	return get_tree().get_script() != null


func _ponto_inicial(i: int) -> Vector3:
	if nascer_no_bairro and bairro and bairro.entrada_pos != Vector3.INF and not _testando():
		# quem chega vem pela estrada do leste, ao lado do carro (HISTORIA.md); os outros um pouco atrás
		return bairro.entrada_pos - bairro.entrada_dir * 2.5 * i + Vector3(-bairro.entrada_dir.z, 0, bairro.entrada_dir.x) * 0.6
	if nascer_no_bairro and bairro and not bairro.pontos_nascer.is_empty():
		return ponto_nascer("", 1.0)  # a primeira vez nasce sempre num lugar bom (novato morria logo de cara)
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
		if Tarefas.HISTORIA and bairro and bairro.entrada_pos != Vector3.INF and not _testando() and not Rede.servidor_sem_tela and not em_pvp():
			var ab := Abertura.new()  # boletim da repórter + tutorial do carro
			ab.jogador = j
			add_child(ab)
			if j.camera:  # olhando para a estrada, na direção da cidade
				j.camera.virar(atan2(-bairro.entrada_dir.x, -bairro.entrada_dir.z), 0.0)
		if _carregando:
			_aquece_shaders(j)  # compila os materiais atrás da tela de carregamento (o engasgo vinha daí)
			var c := _carregando
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if is_instance_valid(c):
					c.queue_free())  # o nosso jogador chegou: pronto para jogar
			if Estilo.LIGADO:
				Estilo.tudo(self)  # 13/11: o que ganhou malha/material depois de entrar (ruas juntas, longe)
		j.nick = nick_local
		controles.jogador = j
		if arma_inicial != "":
			j.entrada["arma"] = arma_inicial
		if abrir_pvp:
			abrir_pvp = false
			controles.abre_pvp.call_deferred()


# céu: degradê do horizonte ao topo e nuvens de ruído que andam devagar (cobrindo mais perto do horizonte)
const CEU: String = """shader_type sky;
// céu de fim do mundo: nuvem grossa e baixa, horizonte cinza (31/10: saiu a poeira laranja), sol atrás das nuvens e colunas de
// fumaça de incêndios longe (três, em direções fixas). Ciclo troca as cores do dia/noite.
uniform vec3 topo;
uniform vec3 horizonte;
// 07/11 (E1 cara nova): nuvens de foto (HDRI CC0 do Poly Haven, assets/ceu) tingidas pela paleta do Ciclo
uniform sampler2D foto : source_color, filter_linear, repeat_enable;
uniform vec3 brasa = vec3(0.95, 0.5, 0.18);  // âmbar/ferrugem no horizonte (luz dos incêndios)
uniform float brasa_forca = 0.35;
uniform vec3 fogo = vec3(0.9, 0.35, 0.1);
uniform float cobertura = 0.72;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float r(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 5; k++) { v += r(p) * a; p *= 2.03; a *= 0.5; } return v; }
void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizonte, topo, clamp(pow(max(y, 0.0), 0.5), 0.0, 1.0));
	if (y < 0.0) {
		c = mix(horizonte, horizonte * 0.5, clamp(-y * 5.0, 0.0, 1.0));
	} else {
		// sol abafado: só um brilho largo e fraco, cor de ferrugem
		if (LIGHT0_ENABLED) {
			float s = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
			c += LIGHT0_COLOR * (pow(s, 60.0) * 0.8 + pow(s, 6.0) * 0.12);
		}
		vec2 uv = vec2(atan(EYEDIR.x, -EYEDIR.z) / 6.2831853 + 0.5 + TIME * 0.0006, acos(clamp(y, -1.0, 1.0)) / 3.14159265);
		float l = dot(texture(foto, uv).rgb, vec3(0.299, 0.587, 0.114));
		vec3 cn = mix(topo * 0.55, horizonte * 1.25, smoothstep(0.25, 0.85, l));
		c = mix(c, cn, smoothstep(0.0, 0.08, y) * 0.9);
		c += brasa * brasa_forca * exp(-y * 9.0) * (0.6 + 0.4 * l);
		// colunas de fumaça subindo no horizonte, tortas pelo vento, com o pé avermelhado do fogo
		float az = atan(EYEDIR.x, EYEDIR.z);
		for (int k = 0; k < 3; k++) {
			float centro = -2.2 + float(k) * 2.1 + y * (0.9 + float(k) * 0.3);
			float largura = 0.05 + y * 0.35;
			float d = abs(az - centro) / largura;
			float massa = exp(-d * d) * smoothstep(0.55, 0.0, y) * (0.55 + 0.6 * fbm(vec2(az * 6.0, y * 9.0 - TIME * 0.08 * (1.0 + float(k)))));
			c = mix(c, vec3(0.2, 0.21, 0.23), clamp(massa, 0.0, 0.6));
			c += fogo * exp(-d * d * 2.0) * smoothstep(0.06, 0.0, y) * 0.12;
		}
	}
	COLOR = c;
}"""


func _luz() -> void:
	var som_amb := SomAmbiente.new()  # vento, sustos, passos, eco, coração, gemidos
	som_amb.name = "SomAmbiente"
	som_amb.principal = self
	add_child(som_amb)
	var postes := PostesPiscam.new()  # 06/11 terror: postes velhos piscando de noite
	postes.principal = self
	add_child(postes)
	var bichos := Bichos.new()  # corvos e papel voando
	bichos.name = "Bichos"
	bichos.principal = self
	add_child(bichos)
	ciclo = Ciclo.new()
	ciclo.name = "Ciclo"
	add_child(ciclo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52, -35, 0)  # 13/11 estilizado: sol alto de dia claro
	sol.light_energy = 1.2
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 40.0
	sol.add_to_group("sol")
	add_child(sol)
	Config.aplica.call_deferred(get_tree())  # sombras, som, resolução e quadros do jogador
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	# céu nublado de fim do mundo: cinza-azulado em cima, horizonte amarelado sujo; névoa leve de profundidade
	var ceu := ShaderMaterial.new()  # céu com nuvens andando (Ciclo troca as cores)
	ceu.shader = Shader.new()
	ceu.shader.code = CEU
	ceu.set_shader_parameter("topo", Ciclo.CEU_TOPO[0])
	ceu.set_shader_parameter("horizonte", Ciclo.CEU_HORIZONTE[0])
	ceu.set_shader_parameter("foto", load("res://assets/ceu/ceu_nublado.jpg"))
	env.sky = Sky.new()
	env.sky.sky_material = ceu
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.72  # 14/11 mais escuro (terror); 13/11 estilizado era 0.82: cores vivas (era 0.72 no realista)
	# 31/10: filtro de cor (LUT), brilho (glow) e ajuste de saturação/contraste deixavam a tela toda rosa no celular
	# (pós-processamento do renderizador de compatibilidade): saíram
	env.fog_enabled = true
	env.fog_light_color = Ciclo.CEU_HORIZONTE[0]
	env.fog_density = 0.012
	env.fog_sky_affect = 0.12 if Estilo.LIGADO else 0.35
	amb.environment = env
	add_child(amb)
	ciclo.sol = sol
	ciclo.ambiente = env


# concreto velho feito em código (sem textura baixada): manchas grandes, grão fino, sujeira subindo do chão e
# marcas de forma a cada 1,2 m; `xadrez` (rampas/plataformas) deixa as marcas a cada 1 m para ver a distância
static var _concreto: Shader


func _mat(cor: Color, xadrez: bool = false) -> Material:
	if _concreto == null:
		_concreto = Shader.new()
		_concreto.code = """shader_type spatial;
uniform vec3 cor; uniform float passo;
varying vec3 wp; varying vec3 wn;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float r(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec2 uv = abs(wn.y) > 0.5 ? wp.xz : (abs(wn.x) > 0.5 ? wp.zy : wp.xy);
	float m = r(uv * 0.7) * 0.6 + r(uv * 3.0) * 0.25 + h(floor(uv * 40.0)) * 0.15;
	vec3 c = cor * (0.68 + m * 0.3);
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.9, wp.y));
	vec2 g = abs(fract(uv / passo) - 0.5);
	c *= 1.0 - 0.18 * step(0.485, max(g.x, g.y));
	ALBEDO = c;
	ROUGHNESS = 0.92;
}"""
	var sm := ShaderMaterial.new()
	sm.shader = _concreto
	sm.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	sm.set_shader_parameter("passo", 1.0 if xadrez else 1.2)
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
	var chao := bloco(Vector3(0, -0.5, -40), Vector3(240, 1, 280), Color.WHITE)
	var m := StandardMaterial3D.new()  # asfalto velho repetindo a cada 4 m
	m.albedo_texture = load("res://assets/sketchfab/asfalto.jpg")
	m.albedo_color = Color(0.42, 0.41, 0.39)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.roughness = 0.95
	(chao.get_child(0) as MeshInstance3D).material_override = m


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
	var loja := Lojista.new()
	loja.name = "Lojista"
	loja.position = Vector3(-14, 0, 1.5)
	loja.rotation_degrees.y = 90.0
	add_child(loja)
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


# --- PvP em salas (prompt 23): o servidor guarda as salas; cada sala só vê e só acerta quem está nela ---

@rpc("any_peer", "call_local", "reliable")
func pede_lista_salas() -> void:
	if multiplayer.is_server():
		_recebe_lista.rpc_id(_quem(), salas.lista_publica())


@rpc("authority", "call_local", "reliable")
func _recebe_lista(l: Array) -> void:
	lista_salas = l
	salas_mudou.emit("")


@rpc("any_peer", "call_local", "reliable")
func pede_criar_sala(nome: String, publica: bool, limite: int, minutos: int) -> void:
	if multiplayer.is_server():
		salas.criar(_quem(), nome, publica, limite, minutos)
		_manda_salas()


@rpc("any_peer", "call_local", "reliable")
func pede_entrar_sala(cod: String) -> void:
	if not multiplayer.is_server():
		return
	var erro: String = salas.entrar(_quem(), cod)
	if erro != "":
		_erro_sala.rpc_id(_quem(), erro)
	else:
		_manda_salas()


@rpc("any_peer", "call_local", "reliable")
func pede_sair_sala() -> void:
	if multiplayer.is_server():
		salas.sair(_quem())
		_manda_salas()


@rpc("any_peer", "call_local", "reliable")
func pede_comecar_sala() -> void:
	if not multiplayer.is_server():
		return
	var erro: String = salas.comecar(_quem())
	if erro != "":
		_erro_sala.rpc_id(_quem(), erro)
		return
	var cod: String = salas.sala_de(_quem())
	for p: int in salas.salas[cod].jogadores:
		_pvp_caido.erase(p)
		_pvp_vai.rpc_id(p, ponto_pvp())
	_manda_salas()
	_aviso_sala(cod, "VALENDO! %d MINUTOS" % int(salas.salas[cod].tempo / 60.0))


@rpc("authority", "call_local", "reliable")
func _erro_sala(erro: String) -> void:
	salas_mudou.emit(erro)


## Servidor → jogador da sala: começou (ou renasce) no PvP: vai para `pos` com a vida cheia.
@rpc("authority", "call_local", "reliable")
func _pvp_vai(pos: Vector3) -> void:
	if jogador:
		jogador.renasce_pvp(pos)


## Quem atirou/bateu (no aparelho dele) pede o dano no jogador `alvo`; o servidor confere a sala.
@rpc("any_peer", "call_local", "reliable")
func pede_dano_pvp(alvo: int, dano: int, dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var q: int = _quem()
	var j := jogadores.get_node_or_null(str(alvo)) as Jogador
	var atirador := jogadores.get_node_or_null(str(q)) as Jogador
	if j == null or atirador == null or not salas.vale(q, alvo) or _pvp_caido.has(alvo) or j.vida <= 0:
		return
	# o dano vem do aparelho de quem atirou: nunca mais que a arma dele tira (cabeça, força máxima)
	var teto: int = Pistola.dano_maximo(atirador.arma) if Jogador.e_fogo(atirador.arma) else 200
	dano = clampi(dano, 0, teto)
	var morreu: bool = j.vida - dano <= 0
	j.levar_dano(dano, dir)
	if not morreu:
		return
	_pvp_caido[alvo] = true
	var cod: String = salas.sala_de(q)
	salas.abate(cod, atirador.nick, j.nick)
	var com: String = Mochila.NOMES.get(atirador.arma, atirador.arma).to_upper()
	_aviso_sala(cod, "%s DERRUBOU %s  [%s]" % [atirador.nick.to_upper(), j.nick.to_upper(), com])
	_manda_salas()
	get_tree().create_timer(Salas.RENASCE_T).timeout.connect(func() -> void:
		_pvp_caido.erase(alvo)
		if salas.sala_de(alvo) == cod and jogadores.has_node(str(alvo)):
			_pvp_vai.rpc_id(alvo, ponto_pvp()))


func _aviso_sala(cod: String, texto: String) -> void:
	for p: int in salas.salas[cod].jogadores:
		aviso_todos.rpc_id(p, texto)


func _passa_salas(dt: float) -> void:
	_salas_tick += dt
	if _salas_tick < 1.0:
		return
	_salas_tick = 0.0
	var rolando: bool = false
	for cod: String in salas.salas:
		rolando = rolando or salas.salas[cod].estado != "espera"
	for ev: Array in salas.passa(1.0):
		if ev[0] == "fim":
			var top: Array = salas.placar(ev[1])
			_aviso_sala(ev[1], "FIM! %s VENCEU" % String(top[0][0]).to_upper() if not top.is_empty() else "FIM!")
	if rolando:
		_manda_salas()  # relógio da partida


func _manda_salas() -> void:
	_recebe_salas.rpc({"de": salas.de, "salas": salas.salas})


@rpc("authority", "call_local", "reliable")
func _recebe_salas(d: Dictionary) -> void:
	_salas_cli = d
	for j: Node in jogadores.get_children():
		var sinc: MultiplayerSynchronizer = j.get_node_or_null("Sincronia")
		if sinc:
			sinc.update_visibility()
	salas_mudou.emit("")


## Minha sala (cópia do servidor), ou {} fora de sala. Tem "codigo".
func minha_sala() -> Dictionary:
	var cod: String = _salas_cli.de.get(multiplayer.get_unique_id(), "") if multiplayer.has_multiplayer_peer() else ""
	if cod == "" or not _salas_cli.salas.has(cod):
		return {}
	var s: Dictionary = _salas_cli.salas[cod].duplicate()
	s.codigo = cod
	return s


## Partida de PvP rolando para este aparelho?
func em_pvp() -> bool:
	return minha_sala().get("estado", "") == "jogando"


## Os dois se veem? (mesma sala, ou os dois fora de sala)
func mesma_sala(a: int, b: int) -> bool:
	return _salas_cli.de.get(a, "") == _salas_cli.de.get(b, "")


## Placar da minha sala: [[nick, abates, mortes], ...] por abates.
func placar_sala() -> Array:
	var s: Dictionary = minha_sala()
	var r: Array = []
	for n: String in s.get("placar", {}):
		r.append([n, s.placar[n][0], s.placar[n][1]])
	r.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))
	return r


## Onde nasce no PvP: na frente de uma construção do centro da cidade (sorteado).
func ponto_pvp() -> Vector3:
	var perto: Array = bairro.pontos_nascer.filter(func(p: Vector3) -> bool: return p.distance_to(Bairro.ORIGEM) < RAIO_PVP)
	if perto.is_empty():
		perto = bairro.pontos_nascer
	return perto[_rng_nascer.randi() % perto.size()]



# --- dividir o peso (31/10): cada zumbi comum é pensado pelo celular do jogador mais perto dele ---
const PESO_A_CADA: float = 2.0
const PESO_RAIO: float = 45.0   # m: mais longe que isso de todos, quem pensa é o servidor
const PESO_FOLGA: float = 8.0   # m: só troca se o novo estiver bem mais perto (não fica trocando)
var _peso_t: float = 0.0


func _divide_peso(dt: float) -> void:
	_peso_t -= dt
	if _peso_t > 0.0 or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or multiplayer.get_peers().is_empty():
		return
	_peso_t = PESO_A_CADA
	var vivos: Array = jogadores.get_children().filter(func(j: Jogador) -> bool: return j.vida > 0)
	for z: Zumbi in zumbis.get_children():
		if z.chefe or z.armado or z.horda != 0 or z.vida <= 0 or z._deitado or z._mordendo > 0.0:
			continue
		var melhor: Jogador = null
		var d_melhor: float = PESO_RAIO
		var d_atual: float = INF
		for j: Jogador in vivos:
			var d: float = j.global_position.distance_to(z.global_position)
			if d < d_melhor:
				melhor = j
				d_melhor = d
			if j.get_multiplayer_authority() == z.pensa:
				d_atual = d
		var novo: int = melhor.get_multiplayer_authority() if melhor else 1
		if novo != z.pensa and (d_atual > PESO_RAIO or d_melhor + PESO_FOLGA < d_atual):
			z.muda_pensa.rpc(novo)



# --- malha de navegação pronta (31/10: assar a cidade levava ~5 s no PC e bem mais no celular ao criar a sala) ---
const NAV_PRONTA := "res://assets/mapa/nav_%s.res"
const NAV_PEDACO: float = 250.0  # lado de cada pedaço da malha da cidade
const NAV_VERSAO: int = 5  # subir ao mudar a pista ou o jeito de assar (3: escadas nos fundos dos sobrados)


## Usa a malha que vem pronta no APK se o mapa e as ruínas são os mesmos de quando foi assada; senão assa aqui.
## Gerar de novo: `$G --headless --path . -s res://tools/assa_navegacao.gd` (depois de mudar cidade/ruínas).
func _assa(regiao: NavigationRegion3D, nome: String) -> void:
	var chave: String = chave_nav()
	var caminho: String = NAV_PRONTA % nome
	if ResourceLoader.exists(caminho):
		var pronta := load(caminho) as NavigationMesh
		if pronta and String(pronta.get_meta("chave", "")) == chave:
			regiao.navigation_mesh = pronta
			return
	regiao.bake_navigation_mesh(false)
	if OS.get_cmdline_user_args().has("salva_nav"):
		regiao.navigation_mesh.set_meta("chave", chave)
		ResourceSaver.save(regiao.navigation_mesh, caminho)


## Liga os pedaços vizinhos da malha da cidade com NavigationLink3D nas beiras. A ligação automática do Godot compara
## toda beira solta com toda beira solta de todas as regiões: com 1 km² o mapa levava ~45 s para ficar pronto.
## As ligações ficam salvas na malha do pedaço 0_0 (meta "ligacoes", mesma chave da malha).
func _liga_pedacos(pedacos: Array, n: int) -> void:
	var primeira: NavigationMesh = (pedacos[0] as NavigationRegion3D).navigation_mesh
	var chave: String = chave_nav()
	var ligs: PackedVector3Array
	if String(primeira.get_meta("ligacoes_chave", "")) == chave:
		ligs = primeira.get_meta("ligacoes")
	else:
		ligs = _calcula_ligacoes(pedacos, n)
		if OS.get_cmdline_user_args().has("salva_nav"):
			primeira.set_meta("ligacoes", ligs)
			primeira.set_meta("ligacoes_chave", chave)
			ResourceSaver.save(primeira, NAV_PRONTA % "bairro_0_0")
	for r: NavigationRegion3D in pedacos:
		r.use_edge_connections = false
	if navegacao:
		navegacao.use_edge_connections = false
	for k in range(0, ligs.size() - 1, 2):
		var l := NavigationLink3D.new()
		l.bidirectional = true
		l.start_position = ligs[k]
		l.end_position = ligs[k + 1]
		add_child(l)


## Beiras dos pedaços que coincidem com a do vizinho (mesma linha, trechos que se cobrem, alturas parecidas): uma
## ligação (2 pontos) a cada LIGA_PASSO metros de beira andável.
const LIGA_PASSO: float = 3.0
static func _calcula_ligacoes(pedacos: Array, n: int) -> PackedVector3Array:
	var meio: float = Bairro.TAMANHO * 0.5
	var base: Vector3 = Bairro.ORIGEM - Vector3(meio, 0, meio)
	var beiras: Dictionary = {}  # "x<linha>_<j>" / "z<i>_<linha>" -> [[lado 0 (depois da linha) | 1 (antes)], ...]
	for idx in pedacos.size():
		var i: int = idx / n
		var j: int = idx % n
		var nm: NavigationMesh = (pedacos[idx] as NavigationRegion3D).navigation_mesh
		var v: PackedVector3Array = nm.get_vertices()
		var xa: float = base.x + i * NAV_PEDACO
		var za: float = base.z + j * NAV_PEDACO
		for p in nm.get_polygon_count():
			var pol: PackedInt32Array = nm.get_polygon(p)
			for e in pol.size():
				var a: Vector3 = v[pol[e]]
				var b: Vector3 = v[pol[(e + 1) % pol.size()]]
				for lado in 2:
					var xl: float = xa + lado * NAV_PEDACO
					if absf(a.x - xl) < 0.15 and absf(b.x - xl) < 0.15:
						var k: String = "x%d_%d" % [i + lado, j]
						if not beiras.has(k):
							beiras[k] = [[], []]
						beiras[k][1 - lado].append([minf(a.z, b.z), maxf(a.z, b.z), (a.y + b.y) * 0.5, xl])
					var zl: float = za + lado * NAV_PEDACO
					if absf(a.z - zl) < 0.15 and absf(b.z - zl) < 0.15:
						var k2: String = "z%d_%d" % [i, j + lado]
						if not beiras.has(k2):
							beiras[k2] = [[], []]
						beiras[k2][1 - lado].append([minf(a.x, b.x), maxf(a.x, b.x), (a.y + b.y) * 0.5, zl])
	var out := PackedVector3Array()
	for k: String in beiras:
		var antes: Array = beiras[k][1]
		var depois: Array = beiras[k][0]
		var marcas: Array[float] = []
		for e1: Array in antes:
			for e0: Array in depois:
				var lo: float = maxf(e1[0], e0[0])
				var hi: float = minf(e1[1], e0[1])
				if hi - lo < 0.4 or absf(float(e1[2]) - float(e0[2])) > 0.5:
					continue
				var m: float = lo + 0.2
				while m <= hi - 0.2:
					if marcas.all(func(q: float) -> bool: return absf(q - m) > LIGA_PASSO):
						marcas.append(m)
						var y: float = (float(e1[2]) + float(e0[2])) * 0.5
						var l: float = e1[3]
						if k.begins_with("x"):
							out.append(Vector3(l - 0.35, y, m))
							out.append(Vector3(l + 0.35, y, m))
						else:
							out.append(Vector3(m, y, l - 0.35))
							out.append(Vector3(m, y, l + 0.35))
					m += LIGA_PASSO
	return out


## Muda quando o mapa ou qualquer ruína do Blender muda (aí a malha pronta não serve mais).
static func chave_nav() -> String:
	var partes: PackedStringArray = [str(NAV_VERSAO), FileAccess.get_md5(Bairro.MAPA)]
	var arqs: PackedStringArray = DirAccess.get_files_at("res://assets/ruinas")
	arqs.sort()
	for a: String in arqs:
		if a.ends_with(".glb"):
			partes.append(FileAccess.get_md5("res://assets/ruinas/" + a))
	return "|".join(partes).md5_text()



var _carregando: Carregando


func mostra_carregando() -> void:
	if _carregando == null or not is_instance_valid(_carregando):
		_carregando = Carregando.new()
		add_child(_carregando)
