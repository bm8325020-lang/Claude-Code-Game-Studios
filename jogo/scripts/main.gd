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
var bairro: Bairro
## nasce no bairro (o jogo); os testes que medem a pista desligam
static var nascer_no_bairro: bool = true
var grupos := Grupos.new()  # servidor: quem está com quem
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
	_luz()
	_chao()
	_obstaculos()
	bairro = Bairro.new()
	bairro.name = "Bairro"
	add_child(bairro)
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
		_recebe_salas.rpc_id(id, {"de": salas.de, "salas": salas.salas})  # quem chega já sabe das salas (e quem não vê)


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


func _process(dt: float) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		grupos.passa(dt)
		_passa_raids(dt)
		_passa_dominio(dt)
		_passa_salas(dt)


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
		spawner_zumbis.spawn({"pos": pos + Vector3(sin(ang), 0, cos(ang)) * randf_range(8.0, 12.0) + Vector3(0, 0.1, 0), "raid": caido})
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
func ponto_nascer(nick: String = "") -> Vector3:
	var f: String = faccao_de(nick) if nick != "" else ""
	if f != "" and String(_faccoes_cli.f[f].casa) != "":
		return bairro.frente_da(_faccoes_cli.f[f].casa)  # quem tem casa de facção renasce nela
	return Bairro.sorteia(_rng_nascer, bairro.pontos_bons, bairro.pontos_ruins)


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
	# o bairro tem a malha dele (outra região, só a área dele)
	var nav_b := NavigationRegion3D.new()
	var mb: NavigationMesh = malha.duplicate()
	mb.cell_size = 0.25  # área grande: célula um pouco maior para assar rápido
	mb.agent_radius = 0.25  # múltiplo da célula; 0,35 arredondava para 0,5 e fechava o vão da porta
	var meio: float = Bairro.TAMANHO * 0.5
	mb.filter_baking_aabb = AABB(Bairro.ORIGEM - Vector3(meio, 1, meio), Vector3(meio * 2.0, 10, meio * 2.0))
	nav_b.navigation_mesh = mb
	add_child(nav_b)
	nav_b.bake_navigation_mesh(false)
	for p: Vector3 in bairro.pontos_zumbi:
		spawner_zumbis.spawn({"pos": p + Vector3(0, 0.1, 0)})
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
	z.raid = int(dados.get("raid", 0))
	return z


var _rng_nascer := RandomNumberGenerator.new()


func _ponto_inicial(i: int) -> Vector3:
	if nascer_no_bairro and bairro and not bairro.pontos_nascer.is_empty():
		return ponto_nascer()
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
		if abrir_pvp:
			abrir_pvp = false
			controles.abre_pvp.call_deferred()


# céu: degradê do horizonte ao topo e nuvens de ruído que andam devagar (cobrindo mais perto do horizonte)
const CEU: String = """shader_type sky;
uniform vec3 topo;
uniform vec3 horizonte;
uniform float cobertura = 0.55;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float r(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 4; k++) { v += r(p) * a; p *= 2.03; a *= 0.5; } return v; }
void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizonte, topo, clamp(pow(max(y, 0.0), 0.6), 0.0, 1.0));
	if (y < 0.0) {
		c = mix(horizonte, horizonte * 0.55, clamp(-y * 5.0, 0.0, 1.0));
	} else {
		vec2 p = EYEDIR.xz / (y + 0.15) * 1.4 + vec2(TIME * 0.006, TIME * 0.003);
		float n = fbm(p);
		float nuvem = smoothstep(1.0 - cobertura, 1.0 - cobertura + 0.35, n);
		vec3 cn = mix(horizonte * 1.08, topo * 0.75 + vec3(0.06), smoothstep(0.4, 0.9, n));
		c = mix(c, cn, nuvem * smoothstep(0.0, 0.12, y) * 0.9);
	}
	COLOR = c;
}"""


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
	# céu nublado de fim do mundo: cinza-azulado em cima, horizonte amarelado sujo; névoa leve de profundidade
	var ceu := ShaderMaterial.new()  # céu com nuvens andando (Ciclo troca as cores)
	ceu.shader = Shader.new()
	ceu.shader.code = CEU
	ceu.set_shader_parameter("topo", Ciclo.CEU_TOPO[0])
	ceu.set_shader_parameter("horizonte", Ciclo.CEU_HORIZONTE[0])
	env.sky = Sky.new()
	env.sky.sky_material = ceu
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78  # cor lavada, fria
	env.adjustment_contrast = 1.08
	env.fog_enabled = true
	env.fog_light_color = Ciclo.CEU_HORIZONTE[0]
	env.fog_density = 0.008
	env.fog_sky_affect = 0.35
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
	var morreu: bool = j.vida - dano <= 0
	j.levar_dano(dano, dir)
	if not morreu:
		return
	_pvp_caido[alvo] = true
	var cod: String = salas.sala_de(q)
	salas.abate(cod, atirador.nick, j.nick)
	_aviso_sala(cod, "%s DERRUBOU %s" % [atirador.nick.to_upper(), j.nick.to_upper()])
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
