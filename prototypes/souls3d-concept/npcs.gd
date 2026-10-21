# PROTOTYPE - NOT FOR PRODUCTION
# Townsfolk you can talk to. Quaternius models (qrig.gd) that idle, wander near home and turn to face you.
# Talking opens dialog.gd; free questions go to Claude (the player's own API key, set in OPÇÕES) with a persona built
# from the NPC, the world lore and the game state. Without a key or a connection they answer from scripted lines.
extends Node

const QRig = preload("res://qrig.gd")
const Rpg = preload("res://rpg.gd")
const API_URL := "https://api.anthropic.com/v1/messages"
const LORE := """Mundo: Cinzarra, terra coberta de cinzas. O Santuário da Chama é o coração do vale; quem morre desperta \
nas fogueiras. Sete Sementes do Dragão (Fogo, Gelo, Raio, Veneno, Terra, Sombra e a do próprio Dragão) dão poder a quem \
as carrega. O Burgo dos Esquecidos fica ao norte do Santuário, subindo a escadaria; a Igreja do Juramento fica no alto \
do penhasco, com o primeiro Sino do Despertar; o Cemitério dos Juramentados fica a leste, abaixo do Santuário; o \
Jardim Morto, com lobos, fica no vale. Além do vale há cidades muradas com castelos (guardas, carrascos, feiticeiras \
e um Cavaleiro Negro em cada torre de menagem) e vilarejos tomados por possuídos, salteadores e diabretes. \
Brasas são a moeda; titanita reforça armas; frascos de Seiva curam."""

# hand-placed people of the valley: [name, role, model, head, hair, position, idle clip, persona, quick answers]
const VALLEY := [
	["Guardiã Maela", "guardiã", "Female_Peasant.gltf", "Female", "Hair_Buns", Vector3(3.5, 0.0, 4.0), "Idle",
		"Guardiã da Chama do Santuário há mais de cem anos. Calma, cansada, maternal. Sabe acender e cuidar das fogueiras e conhece as lendas das Sementes.",
		{"Quem é você?": "Sou Maela. Cuido desta chama desde antes de o Burgo esquecer o próprio nome.",
		"O que faço agora?": "Suba a escadaria ao norte, até o Burgo. Acenda a fogueira de lá: o fogo lembrará de você.",
		"Fale das Sementes.": "Sete sementes caíram do Dragão quando ele adormeceu. Quem juntar todas pode acordá-lo... ou matá-lo."}],
	["Ferreiro Brann", "ferreiro", "Male_Peasant.gltf", "Male", "Hair_Beard", Vector3(-6.0, 15.0, -79.0), "Idle_FoldArms",
		"Ferreiro do Burgo, rude e honesto, braços queimados. Reforça armas com titanita. Odeia os Cavaleiros Ocos que roubam seu ferro.",
		{"Quem é você?": "Brann. Malho ferro desde que este lugar tinha gente viva. Tem titanita? Então temos negócio.",
		"O que faço agora?": "Os telhados quebrados levam à Igreja. Cuidado com os besteiros nas torres de vigia.",
		"Reforçar arma": "__smith"}],
	["Mercadora Ysa", "mercadora", "Female_Ranger.gltf", "Female", "", Vector3(6.0, 15.0, -70.5), "Idle_Talking",
		"Mercadora viajante esperta e debochada, vende titanita e seiva. Viaja entre as cidades muradas e conhece boatos de todas.",
		{"Quem é você?": "Ysa, a que sobrevive. Compro barato, vendo caro e nunca durmo no mesmo lugar duas vezes.",
		"O que há para comprar?": "__shop",
		"Algum boato?": "Dizem que cada cidade murada guarda um Cavaleiro Negro na torre. E que eles pagam bem... depois de mortos."}],
	["Velho Corvo", "eremita", "Male_Ranger.gltf", "Male", "Hair_Long", Vector3(17.0, -1.2, 5.0), "Idle_Lantern",
		"Eremita meio louco que vigia o caminho do Cemitério. Fala por enigmas, mas sempre diz a verdade.",
		{"Quem é você?": "Corvo, me chamam. Os mortos do cemitério me conhecem pelo nome. Você, eles vão conhecer pelo grito.",
		"O que há no cemitério?": "Juramentados que não sabem que morreram. Fortes demais para você... por enquanto.",
		"Alguma dica?": "Fogo queima os ossos de vez. Ossos queimados não se levantam."}],
]
const TOWN_ROLES := [["taberneira", "Female_Peasant.gltf", "Female", "Hair_Buns", "Idle_Talking"], ["sentinela aposentado", "Male_Ranger.gltf", "Male", "Hair_Beard", "Idle_FoldArms"],
	["camponês", "Male_Peasant.gltf", "Male", "Hair_SimpleParted", "Idle"], ["curandeira", "Female_Ranger.gltf", "Female", "Hair_Long", "Idle_Lantern"]]
const FIRST := ["Alda", "Bertram", "Cora", "Dimas", "Elvira", "Fausto", "Gilda", "Hugo", "Inês", "Jorge", "Leda", "Marco", "Nádia", "Otto"]

var main: Node
var people: Array = []  # {name, role, persona, quick, root, ap, home, target, hist, interact, idle, town}

func setup(m: Node) -> void:
	main = m
	for v in VALLEY:
		add(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], "")

func add(name: String, role: String, model: String, head: String, hair: String, pos: Vector3, idle: String, persona: String, quick: Dictionary, town: String) -> Dictionary:
	var r: Array = QRig.instance("res://assets/qchars/" + model, false, head, hair)
	var root := Node3D.new()
	root.position = pos
	main.add_child(root)
	root.add_child(r[0])
	var p := {"name": name, "role": role, "persona": persona, "quick": quick, "root": root, "ap": r[1], "home": pos, "target": pos,
		"hist": [], "idle": idle, "town": town, "t": randf() * 4.0}
	r[1].play(idle)
	p.interact = {"pos": pos, "r": 2.6, "label": "FALAR", "do": func(): main.dialog.open_with(p)}
	main.interacts.append(p.interact)
	people.append(p)
	return p

# two townsfolk per town, made up from its seed; they come and go with the town
func populate_town(t: Dictionary, rng: RandomNumberGenerator, spots: Array) -> void:
	for i in mini(2, spots.size()):
		var role: Array = TOWN_ROLES[rng.randi() % TOWN_ROLES.size()]
		var name: String = FIRST[rng.randi() % FIRST.size()]
		var persona := "%s de %s, %s. %s" % [role[0].capitalize(), t.name, "uma cidade murada com castelo" if t.city else "um vilarejo pobre",
			["Medroso, fala baixo, teme o castelo.", "Orgulhoso, fala da glória antiga da cidade.", "Desconfiado de forasteiros, mas ama boatos.", "Gentil, quer que alguém salve a família."][rng.randi() % 4]]
		var quick := {"Quem é você?": "Me chamo %s. Sou %s aqui em %s." % [name, role[0], t.name],
			"O que há por aqui?": ("O castelo no centro tem um Cavaleiro Negro. Os guardas não deixam ninguém passar." if t.city else "Os mortos andam pelas casas à noite. Os possuídos eram nossos vizinhos."),
			"Alguma dica?": ["Os carrascos são lentos: role e acerte as costas.", "A Peste envenena; beba seiva para curar.", "Raio fura armadura de metal."][rng.randi() % 3]}
		var p := add(name, role[0], role[1], role[2], role[3], spots[i], role[4], persona, quick, t.name)
		t.npcs = t.get("npcs", []) + [p]

func remove_town(t: Dictionary) -> void:
	for p in t.get("npcs", []):
		main.interacts.erase(p.interact)
		people.erase(p)
		p.root.queue_free()
	t.npcs = []

func update(dt: float) -> void:
	for p in people:
		var root: Node3D = p.root
		var d: Vector3 = main.player.position - root.position
		if d.length_squared() > 3600.0:
			continue
		p.interact.pos = root.position
		p.t -= dt
		if d.length() < 4.0:  # turn to face whoever comes close
			root.rotation.y = lerp_angle(root.rotation.y, atan2(d.x, d.z), 0.1)
			p.target = root.position
			if p.ap.current_animation != p.idle:
				p.ap.play(p.idle, 0.3)
			continue
		var to: Vector3 = p.target - root.position
		to.y = 0.0
		if to.length() > 0.4:
			root.position += to.normalized() * 1.1 * dt
			root.rotation.y = lerp_angle(root.rotation.y, atan2(to.x, to.z), 0.1)
			root.position.y = main._ground_y(root.position, root.position.y)
			if p.ap.current_animation != "Walk":
				p.ap.play("Walk", 0.3)
		elif p.t <= 0.0:  # idle a while, then stroll somewhere near home
			p.t = randf_range(5.0, 12.0)
			if randf() < 0.5:
				p.target = p.home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			if p.ap.current_animation != p.idle:
				p.ap.play(p.idle, 0.3)

# ------------------------------------------------------------------ Claude
func system_prompt(p: Dictionary) -> String:
	var s: Dictionary = main._quest_state()
	return """Você é %s, %s, um personagem de um RPG sombrio de fantasia medieval (estilo Dark Souls) chamado Sementes do Dragão.
Quem é você: %s
%s
O viajante com quem você fala: um %s de nível %d. Objetivo atual dele: %s. Onde vocês estão: %s.
Regras: responda sempre em português do Brasil, em 1 a 3 frases curtas, como esse personagem falaria (vocabulário medieval, \
tom sombrio). Nunca diga que é uma IA, um jogo ou um modelo. Se perguntarem algo que o personagem não saberia, responda \
em personagem que não sabe. Dê dicas úteis só quando fizer sentido para o personagem. Não invente lugares, itens ou \
mecânicas fora do que foi descrito.""" % [p.name, p.role, p.persona, LORE, Rpg.CLASSES[main.cls].name, main.level,
		Rpg.current_objective(s), p.town if p.town != "" else "o vale do Santuário"]

# sends the player's line; calls back cb(text) with the NPC's answer (or a scripted one when it cannot reach Claude)
func ask(p: Dictionary, line: String, cb: Callable) -> void:
	var key: String = main.menu.options.get("api_key", "")
	if key.strip_edges() == "":
		cb.call("(Para conversar livremente, coloque sua chave da API Anthropic em MENU > OPÇÕES.) " + p.quick.values()[0])
		return
	p.hist.append({"role": "user", "content": line})
	var body := {"model": main.menu.options.get("ai_model", "claude-opus-5-5"), "max_tokens": 1024,
		"output_config": {"effort": "low"}, "system": system_prompt(p), "messages": p.hist}
	var req := HTTPRequest.new()
	req.process_mode = Node.PROCESS_MODE_ALWAYS  # the world is paused while you talk
	req.timeout = 30.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, data: PackedByteArray):
		req.queue_free()
		var reply := ""
		var j = JSON.parse_string(data.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
		if code == 200 and j is Dictionary and j.get("stop_reason", "") != "refusal":
			for blk in j.content:
				if blk.get("type", "") == "text":
					reply += blk.text
			p.hist.append({"role": "assistant", "content": j.content})  # the whole content, thinking blocks included
		else:
			p.hist.pop_back()  # keep the history valid for the next try
			var why: String = (j.get("error", {}).get("message", "") if j is Dictionary else "") if code != 0 else "sem conexão"
			reply = "(Não consegui falar com a IA: %s) %s" % [why if why != "" else "erro %d" % code, p.quick.values()[0]]
		cb.call(reply.strip_edges()))
	var err := req.request(API_URL, ["content-type: application/json", "x-api-key: " + key, "anthropic-version: 2023-06-01"],
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		p.hist.pop_back()
		req.queue_free()
		cb.call("(Sem conexão.) " + p.quick.values()[0])
