# Modo construção (31/10): do zero não tem cidade; põe peças (casa do jogo, rua da Kenney, móvel do Poly Haven e peças do
# jogo), apaga e desfaz; salva, copia/cola em texto; "jogar no meu mapa" nasce no ponto marcado, tem baú e zumbis.
#   godot --headless --path . --fixed-fps 60 -s res://tests/test_construcao.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MapaCustom.ARQUIVO))
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(10)
	ok(MapaCustom.lista().size() > 1500, "catálogo grande (%d peças)" % MapaCustom.lista().size())
	main.construir(false, "vazio")
	await frames(5)
	var ed: Construcao = main.get_node("Construcao")
	ok(Bairro.vazio and main.bairro.find_children("Casa_*", "", false, false).is_empty(), "do zero: sem cidade")
	var rua: String = ""
	var movel: String = ""
	for it: Dictionary in MapaCustom.lista():
		if rua == "" and it.cat == "Ruas e calçadas":
			rua = it.id
		if movel == "" and it.cat == "Móveis realistas":
			movel = it.id
	var base: Vector3 = Bairro.ORIGEM + Vector3(0, 0.1, 0)
	var ids: Array = ["assets/ruinas/casa_r1.glb", rua, movel, "jogo:nascer", "jogo:zumbi", "jogo:bau"]
	for k in ids.size():
		ed._escolhe(ids[k])
		ed._mira_ponto = base + Vector3(k * 12.0, 0, 0)
		ok(ed.coloca() != null, "põe %s" % ids[k])
	ok(ed.dados.pecas.size() == 6 and ed.mapa.get_child_count() == 6, "6 peças no mapa")
	ed._mira_alvo = ed.mapa.get_child(1)
	ed.apaga()
	await frames(1)
	ok(ed.dados.pecas.size() == 5, "apagar tira a peça")
	ed.desfaz()
	ok(ed.dados.pecas.size() == 6, "desfazer põe de volta")
	ed.salva()
	ok(FileAccess.file_exists(MapaCustom.ARQUIVO), "salvou")
	var texto: String = MapaCustom.para_texto(ed.dados)
	var volta: Dictionary = MapaCustom.de_texto(texto)
	ok(texto.begins_with("MAPA1:") and volta.pecas.size() == 6, "copiar/colar em texto (%d letras)" % texto.length())
	main.jogar_meu_mapa()
	await frames(20)
	var j: Jogador = main.jogador
	ok(j != null and j.global_position.distance_to(base + Vector3(36, 0, 0)) < 3.0, "nasce no ponto marcado (%s)" % (j.global_position if j else "sem jogador"))
	ok(not main.find_children("MapaBau_*", "Bau", true, false).is_empty(), "o baú do mapa existe")
	var perto: int = 0
	for z: Node3D in main.zumbis.get_children():
		if z.global_position.distance_to(base + Vector3(48, 0, 0)) < 8.0:
			perto += 1
	ok(perto >= 1, "zumbis no ponto de zumbi (%d)" % perto)
	print("CONSTRUCAO: %d checks, %d falhas -> %s" % [checks, falhas, "PASS" if falhas == 0 else "FAIL"])
	quit(0 if falhas == 0 else 1)
