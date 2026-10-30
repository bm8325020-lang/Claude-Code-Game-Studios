# Carteiro das salas de sobrevivência (prompt 24): roda no servidor online, não tem mundo nenhum. Guarda a lista de
# salas (nome, pública/privada, código, vagas) e repassa os pacotes entre o celular de quem criou a sala (o host,
# id 1) e os que entraram. O jogo de verdade roda no host. Mensagens de controle são texto JSON; pacotes do jogo são
# binários: [para:int32][modo:u8][canal:u8][dados] chegando, [de:int32][modo][canal][dados] saindo.
# Rodar: godot --headless --main-pack servidor.pck -s res://scripts/relay_main.gd -- porta=7862
class_name Relay
extends Node

const LETRAS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const MAX_SALA: int = 8

var porta: int = 7862
var _tcp := TCPServer.new()
var _con: Array[Dictionary] = []  # {"ws": WebSocketPeer, "sala": código, "id": int}
## código -> {"nome", "publica", "max", "comecou", "host": conexão, "membros": id -> conexão}
var salas: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var err: Error = _tcp.listen(porta)
	print("relay na porta %d: %s" % [porta, error_string(err)])


func _process(_dt: float) -> void:
	while _tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 1 << 20
		ws.outbound_buffer_size = 1 << 22
		ws.max_queued_packets = 4096
		ws.accept_stream(_tcp.take_connection())
		_con.append({"ws": ws, "sala": "", "id": 0, "t": Time.get_ticks_msec()})
	for c: Dictionary in _con.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_saiu(c)
			_con.erase(c)
			continue
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			if Time.get_ticks_msec() - int(c.t) > 10000:  # não virou WebSocket (ex.: página aberta no navegador)
				_con.erase(c)
			continue
		while ws.get_available_packet_count() > 0:
			var p: PackedByteArray = ws.get_packet()
			if ws.was_string_packet():
				var m: Variant = JSON.parse_string(p.get_string_from_utf8())
				if m is Dictionary:
					_controle(c, m)
			elif c.sala != "" and p.size() >= 6:
				_repassa(c, p)


func _manda(c: Dictionary, m: Dictionary) -> void:
	c.ws.send_text(JSON.stringify(m))


func _controle(c: Dictionary, m: Dictionary) -> void:
	match String(m.get("op", "")):
		"lista":
			var busca: String = String(m.get("busca", "")).strip_edges().to_lower()
			var l: Array = []
			for cod: String in salas:
				var s: Dictionary = salas[cod]
				if s.publica and s.membros.size() < s.max and (busca == "" or String(s.nome).to_lower().contains(busca)):
					l.append({"codigo": cod, "nome": s.nome, "n": s.membros.size(), "max": s.max, "comecou": s.comecou})
			_manda(c, {"op": "lista", "salas": l})
		"criar":
			# a versão não é conferida com a do carteiro: ele não precisa ser publicado de novo a cada versão do jogo;
			# quem entra é que tem que ter a mesma versão de quem criou a sala
			if c.sala != "":
				_manda(c, {"op": "erro", "msg": "Já está numa sala"})
				return
			var cod: String = ""
			while cod == "" or salas.has(cod):
				cod = ""
				for i in 4:
					cod += LETRAS[_rng.randi() % LETRAS.length()]
			c.sala = cod
			c.id = 1
			salas[cod] = {"nome": String(m.get("nome", "Sala")).strip_edges().left(24), "publica": bool(m.get("publica", true)),
				"max": clampi(int(m.get("max", 4)), 1, MAX_SALA), "comecou": false, "host": c, "membros": {1: c},
				"versao": int(m.get("versao", 0))}
			_manda(c, {"op": "criada", "codigo": cod})
		"entrar":
			var cod: String = String(m.get("codigo", "")).strip_edges().to_upper()
			if not salas.has(cod):
				_manda(c, {"op": "erro", "msg": "Sala não encontrada"})
			elif int(m.get("versao", 0)) != int(salas[cod].versao):
				_manda(c, {"op": "erro", "msg": "Versão diferente da de quem criou a sala: atualizem os dois"})
			elif salas[cod].membros.size() >= salas[cod].max:
				_manda(c, {"op": "erro", "msg": "Sala cheia"})
			elif c.sala == "":
				var id: int = 0
				while id < 2 or salas[cod].membros.has(id):
					id = _rng.randi_range(2, 1 << 30)
				c.sala = cod
				c.id = id
				salas[cod].membros[id] = c
				_manda(c, {"op": "entrou", "id": id, "nome": salas[cod].nome})
				_manda(salas[cod].host, {"op": "chegou", "id": id})
		"comecou":  # o host avisa que o jogo começou (a lista mostra)
			if c.id == 1 and salas.has(c.sala):
				salas[c.sala].comecou = true
		"expulsa":
			if c.id == 1 and salas.has(c.sala) and salas[c.sala].membros.has(int(m.get("id", 0))):
				salas[c.sala].membros[int(m.id)].ws.close()


## Pacote do jogo: cliente só fala com o host; o host fala com um (id), todos (0) ou todos menos um (-id).
func _repassa(c: Dictionary, p: PackedByteArray) -> void:
	if not salas.has(c.sala):
		return
	var s: Dictionary = salas[c.sala]
	var para: int = p.decode_s32(0)
	p.encode_s32(0, c.id)
	if c.id != 1:
		s.host.ws.put_packet(p)
		return
	for id: int in s.membros:
		if id != 1 and (para == 0 or para == id or (para < 0 and id != -para)):
			s.membros[id].ws.put_packet(p)


func _saiu(c: Dictionary) -> void:
	if c.sala == "" or not salas.has(c.sala):
		return
	var s: Dictionary = salas[c.sala]
	if c.id == 1:  # o host saiu: a sala fecha
		for id: int in s.membros:
			if id != 1:
				_manda(s.membros[id], {"op": "fechou"})
				s.membros[id].ws.close()
		salas.erase(c.sala)
	else:
		s.membros.erase(c.id)
		_manda(s.host, {"op": "saiu", "id": c.id})
