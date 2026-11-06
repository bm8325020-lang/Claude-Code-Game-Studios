# Narração (06/11, dono: "narração nas falas e tudo, voz pronta"): cada fala da história tem um .ogg pronto
# (ElevenLabs, gerado por tools/voz/gera.py; nome = md5 do texto). `fala(texto)` põe na fila (uma voz por vez, sem
# cortar a outra) e devolve em quantos segundos ela termina (0 = sem voz para esse texto).
class_name Voz

const PASTA: String = "res://assets/voz/%s.ogg"
static var _player: AudioStreamPlayer
static var _fila: Array = []  # [AudioStream, bus]


static func chave(texto: String) -> String:
	return texto.strip_edges().md5_text().left(12)


static func tem(texto: String) -> bool:
	return texto.strip_edges() != "" and ResourceLoader.exists(PASTA % chave(texto))


## radio = voz passando pelo rádio (filtro de rádio: só os médios, um pouco de distorção).
static func fala(texto: String, perto: Node, radio: bool = false) -> float:
	if Rede.servidor_sem_tela or perto == null or not perto.is_inside_tree() or not tem(texto):
		return 0.0
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.volume_db = 2.0
		perto.get_tree().root.add_child(_player)
		_player.finished.connect(_proxima)
	var s: AudioStream = load(PASTA % chave(texto))
	var bus: String = _bus_radio() if radio else "Master"
	var espera: float = 0.0
	if _player.playing:
		espera = _player.stream.get_length() - _player.get_playback_position()
		for f: Array in _fila:
			espera += (f[0] as AudioStream).get_length()
		_fila.append([s, bus])
	else:
		_player.bus = bus
		_player.stream = s
		_player.play()
	return espera + s.get_length()


static func _proxima() -> void:
	if not _fila.is_empty() and is_instance_valid(_player):
		var f: Array = _fila.pop_front()
		_player.bus = f[1]
		_player.stream = f[0]
		_player.play()


## Canal "Radio" (feito uma vez): passa-banda nos médios + distorção leve = voz de walkie-talkie. Custa quase nada.
static func _bus_radio() -> String:
	if AudioServer.get_bus_index("Radio") < 0:
		AudioServer.add_bus()
		var i: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Radio")
		AudioServer.set_bus_send(i, "Master")
		var bp := AudioEffectBandPassFilter.new()
		bp.cutoff_hz = 1700.0
		bp.resonance = 0.6
		AudioServer.add_bus_effect(i, bp)
		var di := AudioEffectDistortion.new()
		di.mode = AudioEffectDistortion.MODE_OVERDRIVE
		di.drive = 0.25
		di.post_gain = 2.0
		AudioServer.add_bus_effect(i, di)
	return "Radio"


static func cala() -> void:
	_fila.clear()
	if _player and is_instance_valid(_player):
		_player.stop()
