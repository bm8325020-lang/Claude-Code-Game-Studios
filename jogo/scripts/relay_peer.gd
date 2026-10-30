# Ligação do celular com o carteiro (relay.gd): primeiro serve para listar/criar/entrar em sala (mensagens de
# controle), depois vira o MultiplayerPeer do jogo (quem criou é o servidor, id 1; o carteiro só repassa).
class_name RelayPeer
extends MultiplayerPeerExtension

## Mensagem de controle do carteiro: {"op": "lista"/"criada"/"entrou"/"erro"/"fechou", ...}
signal controle(m: Dictionary)

var ws := WebSocketPeer.new()
var codigo: String = ""
var _id: int = 0
var _status: int = MultiplayerPeer.CONNECTION_CONNECTING
var _fila: Array[Array] = []  # [de, modo, canal, dados]
var _alvo: int = 0
var _modo: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _canal: int = 0
var _recusa: bool = false
var _pendentes: Array[String] = []  # controle pedido antes de abrir


func conecta(url: String) -> Error:
	ws.inbound_buffer_size = 1 << 22
	ws.outbound_buffer_size = 1 << 20
	ws.max_queued_packets = 4096
	return ws.connect_to_url(url)


func aberto() -> bool:
	return ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func pede(m: Dictionary) -> void:
	if aberto():
		ws.send_text(JSON.stringify(m))
	else:
		_pendentes.append(JSON.stringify(m))


func lista(busca: String = "") -> void:
	pede({"op": "lista", "busca": busca})


func criar(nome: String, publica: bool, maximo: int) -> void:
	pede({"op": "criar", "nome": nome, "publica": publica, "max": maximo, "versao": Rede.VERSAO})


func entrar(cod: String) -> void:
	pede({"op": "entrar", "codigo": cod, "versao": Rede.VERSAO})


func _poll() -> void:
	ws.poll()
	var st: int = ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		if _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
			_status = MultiplayerPeer.CONNECTION_DISCONNECTED
			if _id > 1:
				peer_disconnected.emit(1)
		return
	if st != WebSocketPeer.STATE_OPEN:
		return
	for t: String in _pendentes:
		ws.send_text(t)
	_pendentes.clear()
	while ws.get_available_packet_count() > 0:
		var p: PackedByteArray = ws.get_packet()
		if ws.was_string_packet():
			var m: Variant = JSON.parse_string(p.get_string_from_utf8())
			if m is Dictionary:
				_controle(m)
		elif p.size() >= 6:
			_fila.append([p.decode_s32(0), p[4], p[5], p.slice(6)])


func _controle(m: Dictionary) -> void:
	match String(m.get("op", "")):
		"criada":
			codigo = m.codigo
			_id = 1
			_status = MultiplayerPeer.CONNECTION_CONNECTED
		"entrou":
			_id = int(m.id)
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			peer_connected.emit(1)
		"chegou":
			peer_connected.emit(int(m.id))
		"saiu":
			peer_disconnected.emit(int(m.id))
		"fechou":
			ws.close()
	controle.emit(m)


func _get_available_packet_count() -> int:
	return _fila.size()


func _get_max_packet_size() -> int:
	return 1 << 20


func _get_packet_script() -> PackedByteArray:
	return _fila.pop_front()[3] if not _fila.is_empty() else PackedByteArray()


func _get_packet_peer() -> int:
	return _fila[0][0] if not _fila.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return _fila[0][1] if not _fila.is_empty() else TRANSFER_MODE_RELIABLE


func _get_packet_channel() -> int:
	return _fila[0][2] if not _fila.is_empty() else 0


func _put_packet_script(dados: PackedByteArray) -> Error:
	if not aberto() or _id == 0:
		return ERR_UNCONFIGURED
	var p := PackedByteArray()
	p.resize(6)
	p.encode_s32(0, _alvo if _id == 1 else 1)
	p[4] = _modo
	p[5] = _canal
	p.append_array(dados)
	return ws.put_packet(p)


func _set_transfer_mode(m: TransferMode) -> void:
	_modo = m


func _get_transfer_mode() -> TransferMode:
	return _modo as TransferMode


func _set_transfer_channel(c: int) -> void:
	_canal = c


func _get_transfer_channel() -> int:
	return _canal


func _set_target_peer(p: int) -> void:
	_alvo = p


func _is_server() -> bool:
	return _id == 1


func _get_unique_id() -> int:
	return _id


func _get_connection_status() -> ConnectionStatus:
	return _status as ConnectionStatus


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(r: bool) -> void:
	_recusa = r


func _is_refusing_new_connections() -> bool:
	return _recusa


func _disconnect_peer(p: int, _forca: bool) -> void:
	if _id == 1:
		pede({"op": "expulsa", "id": p})


func _close() -> void:
	ws.close()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
