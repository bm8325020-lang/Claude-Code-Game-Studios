# Rede da mecânica 2: criar partida, achar partidas no mesmo Wi-Fi e entrar.
# Quem cria é o servidor (host); quem entra é cliente. Cada aparelho manda a posição do próprio jogador
# (ENet/UDP). Busca na rede local, de dois jeitos: o host anuncia "ZUMBI|nick|porta" por broadcast a cada
# segundo, e quem procura pergunta "ZUMBI?" direto a cada endereço do Wi-Fi (o host responde direto). O segundo
# jeito existe porque o Android só deixa receber broadcast com uma permissão especial (multicast lock).
class_name Rede
extends Node

const PORTA: int = 7777
const PORTA_ANUNCIO: int = 7778
const PORTA_PERGUNTA: int = 7779
const PORTA_WS: int = 7861  # servidor online: o site (porta 7860) repassa /jogo para cá
const MAX_JOGADORES: int = 40
## Sobe quando o que vai pela rede muda: jogo e servidor precisam ter o mesmo número para jogar juntos.
const VERSAO: int = 33
## Lista de servidores online (o servidor na nuvem se atualiza pela mesma branch).
const LISTA_URL: String = "https://raw.githubusercontent.com/bm8325020-lang/Claude-Code-Game-Studios/servidor-build/servidores.json"

## Servidor dedicado sem tela: ninguém vê nada aqui, então jogadores e zumbis não animam (só a lógica roda).
static var servidor_sem_tela: bool = false

## Partidas achadas no Wi-Fi: ip -> {"nick": String, "porta": int, "visto": float (segundos)}
var partidas: Dictionary = {}
var anunciando: bool = false
var nick_host: String = ""

var _anuncio := PacketPeerUDP.new()
var _escuta := PacketPeerUDP.new()
var _pergunta := PacketPeerUDP.new()   # quem procura: pergunta e recebe as respostas
var _responde := PacketPeerUDP.new()   # o host: ouve as perguntas
var _t_pergunta: float = 0.0
var _t_anuncio: float = 0.0
var _relogio: float = 0.0


## Cria a partida neste aparelho. Retorna OK ou o erro do ENet. `anunciar` = avisar no Wi-Fi (não no servidor).
## `porta_ws` > 0: servidor online por WebSocket nessa porta (o site na frente repassa; ENet/UDP não passa por lá).
func criar(nick: String, anunciar: bool = true, porta_ws: int = 0) -> Error:
	var peer: MultiplayerPeer
	var err: Error
	if porta_ws > 0:
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_server(porta_ws, "127.0.0.1")
		peer = ws
	else:
		var en := ENetMultiplayerPeer.new()
		err = en.create_server(PORTA, MAX_JOGADORES)
		peer = en
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	nick_host = nick
	anunciando = anunciar
	if anunciar:
		_responde.bind(PORTA_PERGUNTA)
	_anuncio.set_broadcast_enabled(true)
	_anuncio.set_dest_address("255.255.255.255", PORTA_ANUNCIO)
	return OK


## Entra na partida de outro aparelho (IP) ou de um servidor online (endereço "wss://...").
func entrar(ip: String) -> Error:
	var peer: MultiplayerPeer
	var err: Error
	if ip.begins_with("ws://") or ip.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_client(ip)
		peer = ws
	else:
		var en := ENetMultiplayerPeer.new()
		err = en.create_client(ip, PORTA)
		peer = en
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Começa a procurar partidas no Wi-Fi.
func procurar() -> void:
	if not _escuta.is_bound():
		_escuta.bind(PORTA_ANUNCIO)
	if not _pergunta.is_bound():
		_pergunta.bind(0)
		_t_pergunta = 0.0


func parar_procura() -> void:
	_escuta.close()
	_pergunta.close()


func sair() -> void:
	anunciando = false
	_anuncio.close()
	_responde.close()
	parar_procura()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _process(dt: float) -> void:
	_relogio += dt
	if anunciando:
		_t_anuncio -= dt
		if _t_anuncio <= 0.0:
			_t_anuncio = 1.0
			_anuncio.put_packet(("ZUMBI|%s|%d" % [nick_host, PORTA]).to_utf8_buffer())
	if _responde.is_bound():
		while _responde.get_available_packet_count() > 0:
			var txt: String = _responde.get_packet().get_string_from_utf8()
			if txt == "ZUMBI?":
				_responde.set_dest_address(_responde.get_packet_ip(), _responde.get_packet_port())
				_responde.put_packet(("ZUMBI|%s|%d" % [nick_host, PORTA]).to_utf8_buffer())
	if _pergunta.is_bound():
		_t_pergunta -= dt
		if _t_pergunta <= 0.0:
			_t_pergunta = 2.0
			for ip: String in _vizinhos():
				_pergunta.set_dest_address(ip, PORTA_PERGUNTA)
				_pergunta.put_packet("ZUMBI?".to_utf8_buffer())
		while _pergunta.get_available_packet_count() > 0:
			var txt: String = _pergunta.get_packet().get_string_from_utf8()
			var partes: PackedStringArray = txt.split("|")
			if partes.size() == 3 and partes[0] == "ZUMBI":
				partidas[_pergunta.get_packet_ip()] = {"nick": partes[1], "porta": int(partes[2]), "visto": _relogio}
	if _escuta.is_bound():
		while _escuta.get_available_packet_count() > 0:
			var txt: String = _escuta.get_packet().get_string_from_utf8()
			var ip: String = _escuta.get_packet_ip()
			var partes: PackedStringArray = txt.split("|")
			if partes.size() == 3 and partes[0] == "ZUMBI":
				partidas[ip] = {"nick": partes[1], "porta": int(partes[2]), "visto": _relogio}
		for ip: String in partidas.keys():
			if _relogio - float(partidas[ip].visto) > 4.0:
				partidas.erase(ip)  # parou de anunciar


# todos os endereços da(s) rede(s) local(is) deste aparelho (x.y.z.1 a x.y.z.254) e o próprio aparelho
static func _vizinhos() -> Array[String]:
	var out: Array[String] = ["127.0.0.1"]
	for meu: String in IP.get_local_addresses():
		var p: PackedStringArray = meu.split(".")
		if p.size() != 4 or not (meu.begins_with("192.168.") or meu.begins_with("10.") or meu.begins_with("172.")):
			continue
		for k in range(1, 255):
			var ip: String = "%s.%s.%s.%d" % [p[0], p[1], p[2], k]
			if ip != meu:
				out.append(ip)
	return out
