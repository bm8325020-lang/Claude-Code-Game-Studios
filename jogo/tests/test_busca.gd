# A busca no Wi-Fi acha a partida só perguntando (sem ouvir broadcast, como num Android sem multicast lock).
# Rodar: godot --headless --path . -s res://tests/test_busca.gd
extends SceneTree


func _init() -> void:
	var host := Rede.new()
	root.add_child(host)
	var busca := Rede.new()
	root.add_child(busca)
	await process_frame
	var ok_criar: bool = host.criar("Anfitrião") == OK
	host.anunciando = false  # sem broadcast: só a resposta à pergunta
	busca.procurar()
	busca._escuta.close()     # e sem ouvir broadcast
	var t0: int = Time.get_ticks_msec()
	while busca.partidas.is_empty() and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
		OS.delay_msec(16)
	var achou: bool = not busca.partidas.is_empty() and String(busca.partidas.values()[0].nick) == "Anfitrião"
	print("BUSCA: %s %s" % ["PASS" if ok_criar and achou else "FAIL", busca.partidas])
	host.sair()
	quit(0 if ok_criar and achou else 1)
