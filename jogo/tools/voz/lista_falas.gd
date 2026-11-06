# Lista todas as falas com voz (id = Voz.chave, quem fala, texto) em JSON para tools/voz/gera.py.
# Rodar: godot --headless --path . -s res://tools/voz/lista_falas.gd -- saida.json
extends SceneTree


func _init() -> void:
	var l: Array = []
	var poe := func(quem: String, texto: String) -> void:
		if texto.strip_edges() != "" and not l.any(func(x: Dictionary) -> bool: return x.id == Voz.chave(texto)):
			l.append({"id": Voz.chave(texto), "voz": quem, "texto": texto.strip_edges()})
	var visto: Dictionary = {}
	for r: Array in Tarefas.ROTEIRO:
		if not visto.has(r[0]):
			visto[r[0]] = true
			poe.call("narrador", Tarefas.capitulo_falado(String(r[0])))
		if r.size() > 7 and (r[7] as Dictionary).has("radio"):
			poe.call("dana", String(r[7].radio))
		var fala: String = String(r[6])
		if fala == "":
			continue
		var dois: int = fala.find(": ")
		var nome: String = fala.left(dois) if dois > 0 and dois < 24 else ""
		poe.call(Tarefas.quem(nome), fala.substr(dois + 2) if nome != "" else fala)
	for t: String in Tarefas.FITAS_TXT: poe.call("okafor", t)
	for t: String in Tarefas.DANA: poe.call("dana", t)
	for t: String in Tarefas.MIA: poe.call("mia", t)
	for t: String in Tarefas.TOMMY: poe.call("tommy", t)
	for t: String in Tarefas.DICA_VOZ: poe.call("dana", t)
	poe.call("dana", Tarefas.NOITE_VOZ)
	for k: String in Tarefas.RADIO_EV:
		poe.call("dana", String(Tarefas.RADIO_EV[k][0]))
	for t: String in Tarefas.EXTRAS: poe.call(Tarefas.quem(t.get_slice("|", 0)), t.get_slice("|", 1))
	for t: String in Final.BOM + Final.AMARGO: poe.call("dana", t)
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(l, "\t"))
	print("falas: ", l.size())
	quit()
