# PROTOTYPE - NOT FOR PRODUCTION
# The nine people of Brasalume (owner: UI agent): who they are (LORE.md "Os nove moradores"), how they look, and the
# free conversation through Claude with the player's own API key (GameMenu.options.api_key, set in Opções; it stays
# on the device and is sent only to api.anthropic.com). Without a key or a connection they answer from their lines.
#
# Use: var npcs := Npcs.new(); add_child(npcs)
#   Npcs.info(role) -> Dictionary        {name, title, look, persona, voice, secret, lines: Array, quick: Dictionary}
#                                        roles: blacksmith, merchant, elder, farmer, fisher, guard_captain, innkeeper,
#                                        miner, priest (map npc_spots role / Quests giver ids)
#   npcs.ask(role, line, context, cb)    cb.call(reply: String); context = one short pt-BR line about the game state
#                                        (Npcs.context_line(prog, quests, place) builds it). Works while the tree is paused.
#   npcs.busy(role) -> bool              a request is on its way
#   npcs.forget(role)                    clears that NPC's conversation memory
#   npcs.spawn(map, parent) -> Array     optional: CharacterKit people at map.npc_spots ({id, pos, facing, role}),
#                                        playing an idle; returns [{role, node: Node3D, pos: Vector3}]
class_name Npcs
extends Node

const API_URL: String = "https://api.anthropic.com/v1/messages"
const LORE_SHORT: String = """Mundo: o Vale de Lume, quente porque a dragoa Lumeira veio morrer aqui há trezentos anos. O coração dela rachou em doze \
Sementes do Dragão: cada uma aquece a terra por uma geração e guarda uma lembrança dela. O Pacto do Lume manda plantar \
uma a cada 25 anos e, quando acabarem, viver com as próprias mãos. Nove foram plantadas. Há nove anos, depois da Fome \
Branca, Dom Aurélio de Vigília, o Conde que Não Dorme, começou o Desenterro: seus Guardas da Vigília cavam as sementes \
para reunir o coração e acordar a dragoa para sempre. O sonho ruim dela cria Diabretes de Brasa e Insones (gente que \
tocou lasca e não dorme mais). Os Sem-Terra são lavradores expulsos que roubam o castelo. Os Pugos vivem na Mina do \
Fôlego. Descansa-se nos Marcos de Lume, pedras mornas onde uma semente já foi plantada. O herói, apelidado de \
Pé-Molhado, veio das Terras Frias do norte e foi tirado do rio no moinho; não tem nada e ninguém espera nada dele.
Tom: conto popular medieval, caloroso, com sombra. Nunca chame o herói de escolhido."""

const PEOPLE: Dictionary = {
	"blacksmith": {"name": "Mestra Joana Malho", "title": "ferreira",
		"look": {"body": "Female", "outfit": "Peasant", "hair": "Hair_Buns", "tint": Color(0.8, 0.7, 0.62), "weapon": ""},
		"persona": "Mulher grande, de antebraços queimados e risada que assusta galinha. Fala pouco, trabalha muito.",
		"voice": "Frases curtas, no ritmo do martelo. Tudo vira metáfora de ferro.",
		"secret": "Foi ferreira do castelo; forjou o relicário que prende o coração da Lumeira, com fechos que só abrem por dentro. Não dorme direito desde que entendeu para que servia.",
		"lines": ["Espada eu faço. Coragem você traz de casa. Se não trouxe, volta e procura.",
			"Essa relha arou terra por quarenta anos. Agora vai cortar outra coisa. Ferro bom não reclama do serviço.",
			"Tem coisa que a gente forja e depois passa a vida tentando desforjar."]},
	"merchant": {"name": "Benedito Sal, o Seu Bené", "title": "mercador",
		"look": {"body": "Male", "outfit": "Ranger", "hair": "Hair_SimpleParted", "beard": true, "tint": Color(0.9, 0.78, 0.6)},
		"persona": "Mercador ambulante com uma mula chamada Duquesa, que trata melhor que gente. Fala sem parar, canta enquanto pesa, pechincha por esporte.",
		"voice": "Rápido, cheio de diminutivo, de \"freguês\" e de preço com desconto que não é desconto.",
		"secret": "Compra lascas de semente dos guardas e revende fora do vale. Guardou uma lasca costurada no forro do casaco; sonha que voa e quase não dorme. Está virando Insone e sabe disso.",
		"lines": ["Freguês! Pra você, que caiu do rio, faço preço de afogado: o dobro, que você não sabe quanto custa nada.",
			"A Duquesa não gosta de quem regateia. Eu adoro. Mas quem manda aqui é ela.",
			"Você já sonhou que voava, Pé-Molhado? ... Não? Que sorte. Que sorte a sua."]},
	"elder": {"name": "Vó Cândida", "title": "anciã",
		"look": {"body": "Female", "outfit": "Peasant", "hair": "Hair_Long", "hair_color": Color(0.82, 0.8, 0.76), "tint": Color(0.75, 0.75, 0.85)},
		"persona": "A pessoa mais velha de Brasalume. Cega há vinte anos, enxerga tudo. Fia lã na porta de casa e sabe a cantiga das sementes inteira.",
		"voice": "Devagar, com provérbio e cantiga, mudando de assunto quando o assunto dói.",
		"secret": "Foi ama de leite no castelo e criou o pequeno Aurélio. Guarda um cavalinho de pau que fez para ele e ainda acredita que o menino está dentro do conde.",
		"lines": ["Quem chega molhado se seca no fogo dos outros. Depois paga com lenha. É assim desde que o mundo é mundo.",
			"Doze sementes, doze filhos, doze invernos de saudade. A cantiga é mais velha que eu, e eu sou velha à beça.",
			"Ele chorava de medo do escuro, sabia? O homem que não dorme. Chorava. Eu cantava, e ele dormia."]},
	"farmer": {"name": "Matias Rego", "title": "lavrador",
		"look": {"body": "Male", "outfit": "Peasant", "hair": "Hair_Buzzed", "tint": Color(0.85, 0.82, 0.68)},
		"persona": "Dono da Quinta do Rego. Tímido, teimoso, poucas palavras com gente e muitas com as vacas, que têm nome de santa. Os campos ficaram cinzentos depois que os guardas arrancaram a semente.",
		"voice": "Olhando para o chão, com \"pois é\" e \"vai vendo\". Só se anima falando de terra.",
		"secret": "O irmão mais novo, Tobias, lidera os Sem-Terra. Toda noite Matias deixa pão e uma carta sem assinatura na cerca do campo norte.",
		"lines": ["Pois é. Aqui era o melhor trigo do vale. Agora nem erva daninha quer nascer. Vai vendo.",
			"A Santa Inês fugiu de novo. Se achar uma vaca de sino torto, é ela. Não grite, que ela se ofende.",
			"Tem gente que rouba porque é ruim. Tem gente que rouba porque deram a terra dela pro castelo cavar."]},
	"fisher": {"name": "Dona Celeste", "title": "pescadora",
		"look": {"body": "Female", "outfit": "Ranger", "hair": "Hair_SimpleParted", "hair_color": Color(0.5, 0.48, 0.45), "tint": Color(0.7, 0.8, 0.85)},
		"persona": "Pescadora do Lago Manso, viúva, mãos de corda. Paciente como linha na água, supersticiosa, conversa com os peixes.",
		"voice": "Pouco e baixo, em imagens de água e tempo. Pausas compridas.",
		"secret": "Desenterrou ela mesma a semente da margem antes dos guardas e jogou no fundo do lago. Desde então os Insones descem até a água à noite.",
		"lines": ["Água não tem pressa. Por isso chega em todo lugar.",
			"Joguei no fundo pra ninguém ter. Nem eu. Às vezes ainda vejo o brilho lá embaixo, quando a lua some.",
			"Esses que andam de olho aberto... Não tenha raiva deles, não. Eles só querem um canto quente."]},
	"guard_captain": {"name": "Capitão Rui Abrantes", "title": "capitão da guarda",
		"look": {"body": "Male", "outfit": "Ranger", "hair": "Hair_Buzzed", "beard": true, "pauldrons": true, "weapon": "Sword_Bronze", "shield": "Shield_Wooden"},
		"persona": "Capitão da guarda de Brasalume: ele, dois rapazes e um cachorro chamado Sargento. Seco, preciso, humor de quem já viu coisa demais.",
		"voice": "Ordens curtas, palavrão contido, ironia. Chama o herói de \"recruta\".",
		"secret": "Foi Guarda da Vigília; estava na noite em que cavaram a semente da praça e segurou as mães para trás. Desertou na manhã seguinte. Se o castelo souber, enforca.",
		"lines": ["Escudo alto, recruta. Não é o golpe que mata. É o segundo golpe, que você não viu porque estava admirando o primeiro.",
			"O Sargento não morde. Morde, mas não é pessoal.",
			"Eu segurei a pá naquela noite. Não precisa me olhar assim. Eu já me olho assim todo dia."]},
	"innkeeper": {"name": "Rosa Lume", "title": "taberneira",
		"look": {"body": "Female", "outfit": "Peasant", "hair": "Hair_Buns", "hair_color": Color(0.55, 0.22, 0.12), "tint": Color(0.95, 0.8, 0.75)},
		"persona": "Dona da Estalagem da Panela Quente. Voz alta, colo grande, sabe da vida de todo mundo. Foi quem tirou o herói do frio.",
		"voice": "Exclamação, apelido carinhoso, bronca e comida, nessa ordem.",
		"secret": "O filho, Tomé, foi escudeiro no castelo e virou Insone. Ela escreve uma carta por semana e guarda todas sem mandar. As roupas que deu ao herói eram dele.",
		"lines": ["Acordou, Pé-Molhado! Tava mais azul que ameixa. Senta aí, come, e depois a gente vê o que você sabe fazer.",
			"Essa camisa fica bem em você. Ficava bem nele também. Come, que esfria.",
			"Aqui ninguém paga em moeda, paga em notícia. E a sua, menino, ainda tá fresca."]},
	"miner": {"name": "Gaspar Fundo", "title": "mineiro",
		"look": {"body": "Male", "outfit": "Peasant", "hair": "Hair_Long", "beard": true, "hair_color": Color(0.6, 0.58, 0.55), "weapon": "Pickaxe_Bronze"},
		"persona": "O último mineiro da Mina do Fôlego. Meio surdo, tosse de pedra, ri do perigo e de si mesmo. A chave do portão da mina pendurada no pescoço.",
		"voice": "Gritando (porque não ouve), com termos de mina e piada mórbida.",
		"secret": "A montanha é o corpo da Lumeira: os mineiros achavam paredes mornas com curvas de costela, e ele fechou a mina. Conhece o túnel velho que sobe até a cripta do castelo.",
		"lines": ["HEIN? Fala mais alto! Lá embaixo a gente aprende a gritar, que a montanha responde baixinho!",
			"Os Pugos não são maus. São donos. A gente é que entrou sem bater.",
			"Bota a mão aqui na pedra. Sentiu? Tá morna. Setenta anos e ainda tá morna."]},
	"priest": {"name": "Frei Anselmo", "title": "sacerdote",
		"look": {"body": "Male", "outfit": "Peasant", "hair": "Hair_SimpleParted", "hood": false, "tint": Color(0.6, 0.55, 0.5)},
		"persona": "Frei da Capela do Repouso. Gentil, estudioso, magro, gagueja quando mente. Cuida dos Marcos de Lume e acende vela para quem ninguém lembra.",
		"voice": "Educado, com citações do Livro do Repouso, frases que começam bonitas e terminam tropeçando.",
		"secret": "Manda pombos para o castelo contando quem esconde semente, por medo, desde que levaram a irmã dele. Odeia cada carta que escreve.",
		"lines": ["'Deixai dormir quem escolheu dormir.' É o primeiro versículo. É também o único que todo mundo esquece.",
			"Os M-Marcos ainda estão mornos. Sente-se, descanse. A dragoa não se importa. Ela gostava de visita.",
			"Há pecados que a gente comete por maldade. Os meus eu cometi por medo. Não sei qual Deus perdoa primeiro."]},
}

var _hist: Dictionary = {}    # role -> Array of messages (assistant turns keep their whole content, thinking included)
var _busy: Dictionary = {}


static func info(role: String) -> Dictionary:
	var p: Dictionary = (PEOPLE.get(role, {}) as Dictionary).duplicate()
	if p.is_empty():
		p = {"name": role.capitalize(), "title": "morador", "look": {}, "persona": "Morador do vale.", "voice": "Simples.",
			"secret": "", "lines": ["Bom dia, forasteiro."]}
	p["quick"] = {"Quem é você?": "%s. %s" % [p.name, p.lines[0]], "O que você acha do vale?": p.lines[1 % p.lines.size()],
		"Algum conselho?": p.lines[2 % p.lines.size()]}
	return p


# one short line about where the hero is in the story, for the NPC prompt
static func context_line(prog: Progression, quests: Quests, place: String = "") -> String:
	var parts: PackedStringArray = []
	if prog != null:
		parts.append("o Pé-Molhado está no nível %d e já recuperou %d semente(s)" % [prog.level, prog.seeds.size()])
	if quests != null:
		var q: Dictionary = quests.current()
		if not q.is_empty():
			parts.append("a tarefa dele agora: \"%s\" (%s)" % [q.title, q.text])
	if place != "":
		parts.append("vocês estão em %s" % place)
	return "; ".join(parts)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the world is paused while you talk


func busy(role: String) -> bool:
	return _busy.get(role, false)


func forget(role: String) -> void:
	_hist.erase(role)


func system_prompt(role: String, context: String) -> String:
	var p: Dictionary = info(role)
	return """Você é %s, %s de Brasalume, num RPG de fantasia medieval chamado Sementes do Dragão.
Quem é você: %s
Como você fala: %s
Seu segredo (não conte de cara; só deixe escapar aos poucos, se o viajante ganhar sua confiança ou tocar no assunto certo): %s
Exemplos do seu jeito: %s
%s
Agora: %s.
Regras: responda sempre em português do Brasil, em 1 a 3 frases curtas, como essa pessoa falaria. Nunca diga que é uma IA, \
um jogo ou um modelo. Se perguntarem algo que você não saberia, diga em personagem que não sabe. Não invente lugares, \
itens ou mecânicas fora do que foi descrito. Dê dicas só quando fizer sentido para você.""" % [p.name, p.title, p.persona,
		p.voice, p.secret, " / ".join(p.lines), LORE_SHORT, context if context != "" else "um dia comum na vila"]


# sends the player's line; cb.call(reply) with the NPC's answer (or a scripted one when it cannot reach Claude)
func ask(role: String, line: String, context: String, cb: Callable) -> void:
	var p: Dictionary = info(role)
	var fallback: String = (p.lines as Array).pick_random()
	var key: String = GameMenu.api_key()
	if key == "":
		cb.call(fallback + "\n(Para conversar livremente, coloque sua chave da API em MENU > OPÇÕES.)")
		return
	if busy(role):
		return
	var hist: Array = _hist.get(role, [])
	hist.append({"role": "user", "content": line})
	_hist[role] = hist
	var body: Dictionary = {"model": str(GameMenu.options.get("ai_model", "claude-opus-5-5")), "max_tokens": 2048,
		"output_config": {"effort": "low"}, "fallbacks": "default", "system": system_prompt(role, context), "messages": hist}
	var req := HTTPRequest.new()
	req.process_mode = Node.PROCESS_MODE_ALWAYS
	req.timeout = 45.0
	add_child(req)
	_busy[role] = true
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, data: PackedByteArray) -> void:
		req.queue_free()
		_busy[role] = false
		var reply: String = ""
		var j: Variant = JSON.parse_string(data.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
		if code == 200 and j is Dictionary and str(j.get("stop_reason", "")) != "refusal":
			for blk: Variant in j.get("content", []):
				if blk is Dictionary and str(blk.get("type", "")) == "text":
					reply += str(blk.text)
			hist.append({"role": "assistant", "content": j.content})  # whole content, thinking blocks included
		else:
			hist.pop_back()  # keep the history valid for the next try
			var why: String = "sem conexão" if result != HTTPRequest.RESULT_SUCCESS else "erro %d" % code
			if code == 401:
				why = "a chave foi recusada"
			elif code == 429:
				why = "muitas conversas seguidas, espere um pouco"
			elif j is Dictionary and str(j.get("stop_reason", "")) == "refusal":
				why = "a pergunta não pôde ser respondida"
			reply = "%s\n(Não consegui falar com o Claude: %s.)" % [fallback, why]
		if reply.strip_edges() == "":
			reply = fallback
		cb.call(reply.strip_edges()))
	var err: Error = req.request(API_URL, ["content-type: application/json", "x-api-key: " + key,
		"anthropic-version: 2023-06-01", "anthropic-beta: server-side-fallback-2026-07-01"],
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		hist.pop_back()
		_busy[role] = false
		req.queue_free()
		cb.call(fallback + "\n(Sem conexão.)")


# optional: puts the nine people at the map's npc_spots
func spawn(map: Object, parent: Node3D) -> Array:
	var out: Array = []
	if map == null or not (map.get("npc_spots") is Array):
		return out
	for s: Dictionary in map.get("npc_spots"):
		var role: String = str(s.get("role", ""))
		var p: Dictionary = info(role)
		var ch: Node3D = CharacterKit.make(p.look)
		parent.add_child(ch)
		ch.global_position = s.pos
		ch.rotation.y = float(s.get("facing", 0.0))
		ch.name = "NPC_" + role
		var ap: AnimationPlayer = ch.get_meta("anim") as AnimationPlayer
		var idle: String = {"blacksmith": "Idle_FoldArms", "elder": "Idle_Talking", "miner": "Idle_Lantern",
			"merchant": "Idle_Talking", "farmer": "Farm_Harvest", "fisher": "Idle_Rail"}.get(role, "Idle")
		if ap != null:
			ap.play(idle if ap.has_animation(idle) else "Idle")
		out.append({"role": role, "node": ch, "pos": s.pos})
	return out
