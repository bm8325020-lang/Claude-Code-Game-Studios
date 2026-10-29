# Robô jogador: faz cada movimento como um jogador faria e tira 6 fotos de cada um, da câmera do jogo,
# montando folhas de contato (uma linha por movimento) para avaliar as animações sem abrir o jogo.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/bot.gd -- pasta/
# Só alguns: -- pasta/ pulo,agachado  (roda só os movimentos com esses pedaços no nome)
# Saída: pasta/bot_1.png, bot_2.png ... (7 movimentos por folha).
extends SceneTree

const FOTOS: int = 6
const LARGURA: int = 240  # recorte em volta do boneco (zoom)
const ALTURA: int = 300
const POR_FOLHA: int = 5

var main: Node3D
var j: Jogador
var linhas: Array = []  # [nome, [Image]]


func _init() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _espera(10)
	main.iniciar_solo("Robô")
	await _espera(5)
	j = main.jogador
	main.controles.jogador = null
	main.ciclo.tempo = 0.0
	main.ciclo.set_process(false)
	main.ciclo._process(0.0)
	for z in main.zumbis.get_children():
		z.free()
	j.vida = 100000
	j.fome = Jogador.FOME_TEMPO
	j.sede = Jogador.SEDE_TEMPO

	# cada movimento: nome, o que segurar na entrada, quanto tempo (s), apertos no começo
	await _faz("parado", {}, 1.5)
	await _faz("andando", {"move": Vector2(0, 1), "andar": true}, 1.5)
	await _faz("correndo (trote)", {"move": Vector2(0, 1)}, 1.5)
	await _faz("disparada", {"move": Vector2(0, 1), "correr": true}, 1.5)
	await _faz("de lado", {"move": Vector2(1, 0)}, 1.5)
	await _faz("de costas", {"move": Vector2(0, -1)}, 1.5)
	await _faz("pulo parado", {}, 1.2, ["pular"])
	await _faz("pulo correndo", {"move": Vector2(0, 1)}, 1.2, ["pular"])
	await _faz("agachado", {"agachar": true}, 1.5)
	await _faz("agachado andando", {"agachar": true, "move": Vector2(0, 1)}, 1.5)
	await _faz("facão: golpe", {}, 1.2, ["atacar"])
	await _faz("facão: 3 golpes seguidos", {}, 2.0, ["atacar"], 0.4)
	await _faz("pistola: mirando", {"arma": "pistola", "mira_segurando": true}, 1.5)
	await _faz("pistola: mirando de lado", {"arma": "pistola", "mira_segurando": true, "move": Vector2(1, 0)}, 1.5)
	await _faz("pistola: agachado mirando", {"arma": "pistola", "mira_segurando": true, "agachar": true}, 1.5)
	await _tiro()
	await _faz("pistola: correndo sem mirar", {"arma": "pistola", "move": Vector2(0, 1)}, 1.5)
	await _faz("pistola: recarga", {"arma": "pistola"}, 2.0, ["recarregar"])
	await _pega_item()
	await _zumbi_ataca()
	await _salva()
	quit()


func _espera(n: int) -> void:
	for i in n:
		await process_frame


## Solta tudo, segura `segura` por `tempo` s, aperta `apertos` no começo (e a cada `repete` s, se > 0).
func _faz(nome: String, segura: Dictionary, tempo: float, apertos: Array = [], repete: float = 0.0) -> void:
	var filtro: PackedStringArray = OS.get_cmdline_user_args()[1].split(",") if OS.get_cmdline_user_args().size() > 1 else PackedStringArray()
	if not filtro.is_empty() and not Array(filtro).any(func(f: String) -> bool: return f in nome):
		return
	_solta()
	j.arma = segura.get("arma", "facao")
	j.global_position = j.inicio  # cada movimento começa no mesmo lugar livre
	j.velocity = Vector3.ZERO
	j.camera.virar(0.0)
	if j.agachado != segura.get("agachar", false):
		j.entrada["agachar"] = true  # agachar é liga/desliga
	await _espera(20)  # assenta a pose anterior
	for k: String in segura:
		if k != "agachar":
			j.entrada[k] = segura[k]
	var quadros: int = int(tempo * 60)
	var fotos: Array = []
	for i in quadros:
		if i == 0 or (repete > 0.0 and i % int(repete * 60) == 0):
			for a: String in apertos:
				j.entrada[a] = true
		if i % int(quadros / FOTOS) == 0 and fotos.size() < FOTOS:
			fotos.append(_foto())
		await process_frame
	linhas.append([nome, fotos])
	print("robô: ", nome, " -> ", j.clipe_atual())


func _solta() -> void:
	for k: String in j.entrada:
		var v = j.entrada[k]
		j.entrada[k] = Vector2.ZERO if v is Vector2 else (null if k == "mira_segurando" else ("" if v is String else false))


func _foto() -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var meio: Vector2 = cam.unproject_position(j.global_position + Vector3(0, 0.9, 0))
	var alto: int = int(img.get_height() * 0.6)
	var largo: int = int(alto * float(LARGURA) / ALTURA)
	var x: int = clampi(int(meio.x) - largo / 2, 0, img.get_width() - largo)
	var y: int = clampi(int(meio.y) - alto / 2, 0, img.get_height() - alto)
	var corte: Image = img.get_region(Rect2i(x, y, largo, alto))
	corte.resize(LARGURA, ALTURA, Image.INTERPOLATE_BILINEAR)
	return corte


## mira parado, atira e fotografa: 1 antes e 5 a cada 2 quadros depois (o coice dura ~0,2 s)
func _tiro() -> void:
	var nome := "pistola: tiro (1ª foto antes)"
	var filtro: PackedStringArray = OS.get_cmdline_user_args()[1].split(",") if OS.get_cmdline_user_args().size() > 1 else PackedStringArray()
	if not filtro.is_empty() and not Array(filtro).any(func(f: String) -> bool: return f in nome):
		return
	_solta()
	j.arma = "pistola"
	j.global_position = j.inicio
	j.camera.virar(0.0)
	j.entrada["mira_segurando"] = true
	await _espera(60)
	var fotos: Array = [_foto()]
	j.entrada["atacar"] = true
	for i in 10:
		await process_frame
		if i % 2 == 1:
			fotos.append(_foto())
	linhas.append([nome, fotos])
	print("robô: ", nome, " -> ", j.clipe_atual())


func _pega_item() -> void:
	_solta()
	var it := Item.new()
	it.tipo = "comida"
	it.quantidade = 1
	main.add_child(it)
	it.global_position = j.global_position + (j.camera.global_basis * Vector3.FORWARD * Vector3(1, 0, 1)).normalized() * 1.0
	j.comida = 0
	await _faz("pegando lata do chão", {}, 1.5, ["pegar"])


func _zumbi_ataca() -> void:
	var z := Zumbi.new()
	var frente: Vector3 = (j.camera.global_basis * Vector3.FORWARD * Vector3(1, 0, 1)).normalized()
	z.position = j.global_position + frente * 6.0
	z.casa = z.position
	main.zumbis.add_child(z)
	await _espera(2)
	z._sem_gritar = INF
	await _faz("zumbi vindo e atacando", {}, 3.0)


func _salva() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/"
	var folha: int = 0
	for ini in range(0, linhas.size(), POR_FOLHA):
		folha += 1
		var parte: Array = linhas.slice(ini, ini + POR_FOLHA)
		var img := Image.create(LARGURA * FOTOS, ALTURA * parte.size(), false, Image.FORMAT_RGB8)
		for l in parte.size():
			var fotos: Array = parte[l][1]
			for c in fotos.size():
				var f: Image = fotos[c]
				f.convert(Image.FORMAT_RGB8)
				img.blit_rect(f, Rect2i(0, 0, LARGURA, ALTURA), Vector2i(c * LARGURA, l * ALTURA))
		img.save_png(pasta.path_join("bot_%d.png" % folha))
		var nomes: PackedStringArray = []
		for l in parte:
			nomes.append(l[0])
		print("bot_%d.png: %s" % [folha, ", ".join(nomes)])
