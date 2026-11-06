# Narração (06/11, dono: "narração nas falas e tudo, voz pronta"): cada fala da história tem um .ogg pronto
# (ElevenLabs, gerado por tools/voz/gera.py; nome = md5 do texto). `fala(texto)` põe na fila (uma voz por vez, sem
# cortar a outra) e devolve em quantos segundos ela termina (0 = sem voz para esse texto).
class_name Voz

const PASTA: String = "res://assets/voz/%s.ogg"
static var _player: AudioStreamPlayer
static var _fila: Array[AudioStream] = []


static func chave(texto: String) -> String:
	return texto.strip_edges().md5_text().left(12)


static func tem(texto: String) -> bool:
	return texto.strip_edges() != "" and ResourceLoader.exists(PASTA % chave(texto))


static func fala(texto: String, perto: Node) -> float:
	if Rede.servidor_sem_tela or perto == null or not perto.is_inside_tree() or not tem(texto):
		return 0.0
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.volume_db = 2.0
		perto.get_tree().root.add_child(_player)
		_player.finished.connect(_proxima)
	var s: AudioStream = load(PASTA % chave(texto))
	var espera: float = 0.0
	if _player.playing:
		espera = _player.stream.get_length() - _player.get_playback_position()
		for f: AudioStream in _fila:
			espera += f.get_length()
		_fila.append(s)
	else:
		_player.stream = s
		_player.play()
	return espera + s.get_length()


static func _proxima() -> void:
	if not _fila.is_empty() and is_instance_valid(_player):
		_player.stream = _fila.pop_front()
		_player.play()


static func cala() -> void:
	_fila.clear()
	if _player and is_instance_valid(_player):
		_player.stop()
