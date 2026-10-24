# Rede da mecânica 2: criar partida, achar partidas no mesmo Wi-Fi e entrar.
# Quem cria é o servidor (host); quem entra é cliente. Cada aparelho manda a posição do próprio jogador
# (ENet/UDP). Busca na rede local: o host anuncia "ZUMBI|nick|porta" por broadcast a cada segundo.
class_name Rede
extends Node

const PORTA: int = 7777
const PORTA_ANUNCIO: int = 7778
const MAX_JOGADORES: int = 30
## Sobe quando o que vai pela rede muda: jogo e servidor precisam ter o mesmo número para jogar juntos.
const VERSAO: int = 1
## Lista de servidores online (o servidor na nuvem se atualiza pela mesma branch).
const LISTA_URL: String = "https://raw.githubusercontent.com/bm8325020-lang/Claude-Code-Game-Studios/servidor-build/servidores.json"

## Partidas achadas no Wi-Fi: ip -> {"nick": String, "porta": int, "visto": float (segundos)}
var partidas: Dictionary = {}
var anunciando: bool = false
var nick_host: String = ""

var _anuncio := PacketPeerUDP.new()
var _escuta := PacketPeerUDP.new()
var _t_anuncio: float = 0.0
var _relogio: float = 0.0


## Cria a partida neste aparelho. Retorna OK ou o erro do ENet. `anunciar` = avisar no Wi-Fi (não no servidor).
func criar(nick: String, anunciar: bool = true) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(PORTA, MAX_JOGADORES)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	nick_host = nick
	anunciando = anunciar
	_anuncio.set_broadcast_enabled(true)
	_anuncio.set_dest_address("255.255.255.255", PORTA_ANUNCIO)
	return OK


## Entra na partida de outro aparelho.
func entrar(ip: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, PORTA)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Começa a procurar partidas no Wi-Fi.
func procurar() -> void:
	if not _escuta.is_bound():
		_escuta.bind(PORTA_ANUNCIO)


func parar_procura() -> void:
	_escuta.close()


func sair() -> void:
	anunciando = false
	_anuncio.close()
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
