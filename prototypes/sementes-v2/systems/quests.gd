# PROTOTYPE - NOT FOR PRODUCTION
# Quests: the LORE.md chain (14 main + 7 side) as data, quest state, rewards, resting at the Marcos de Lume and the
# save file. Owns the Progression and Items it is given and applies rewards to them.
#
# Glue (main.gd) calls notify(event, target) for everything that happens in the world:
#   notify("talk", role)        after talking to an NPC; role = map npc_spots role (innkeeper, elder, blacksmith, ...)
#   notify("reach", place_id)   when the hero enters a map place radius (village, farm, ...) or the spawn "mina_fundo"
#   notify("kill", kind)        when an enemy dies; kind = combat kind (wolf_imp, bandit, ..., "boss" for Dom Aurélio)
#                               also grants that kind's XP and gold (Progression.KILL_REWARD)
#   notify("collect", item_id)  when the hero picks something up (adds 1 to Items; seeds also go to Progression.seeds)
#   notify("interact", id)      when the hero uses a map interactable (forja_joana, marco_*, mina_portao, ...);
#                               a marco_* id also rests there once "descanso" is unlocked (emits rested)
# Repeat "reach" calls are harmless. is_target(event, target) says whether an event would progress anything now
# (use it to show a quest marker or spawn a pickup).
#
# Assumed ids not in ARCHITECTURE.md (from LORE.md "Ids para os módulos"): interactables marco_vila, marco_quinta,
# marco_bosque, marco_atalaia, marco_fundo, forja_joana, poste_treino, pombal, moinho_comporta, ponte_rio,
# carvalha_mae, tenda_tobias, farol_atalaia, barco_celeste, insone_tome, mina_portao, castelo_portao, relicario;
# reach target mina_fundo; pickups nabo (farm), relha_velha (farm barn), farinha (river mill), semente_* ,
# livro_desenterro (watchtower), cartas_rosa (village inn), sino_vaca (farm/forest/river), elmo_vigilia (knight drop),
# peixe_lua (lake).
class_name Quests
extends RefCounted

signal quest_offered(id: String)
signal quest_started(id: String)
signal step_done(id: String, step: int)
signal progress(id: String, have: int, need: int)
signal quest_done(id: String, rewards: Dictionary)
signal rested(marco_id: String)

const SAVE_PATH: String = "user://sementes2_save.json"
const SAVE_VERSION: int = 1

const NPC_NAME: Dictionary = {
	"innkeeper": "Rosa", "elder": "Vó Cândida", "blacksmith": "Mestra Joana", "farmer": "Matias",
	"guard_captain": "Capitão Rui", "priest": "Frei Anselmo", "fisher": "Dona Celeste", "miner": "Gaspar",
	"merchant": "Seu Bené",
}

# step: [type, target, count, where (place id for the tracker), text pt-BR]
# rewards: xp, gold, items {id: n}, equip [ids], refill {id: n} (refillable consumables: raise the max),
#          unlocks [ids], seeds [ids not items], rest (marco id), take [item ids removed even if keep]
# minutes: design estimate of play time (balance check in tests)
const DATA: Array = [
	{"id": "m01", "kind": "main", "title": "Pão de Quem Chega", "giver": "innkeeper", "auto": true, "requires": [],
		"level": 1, "minutes": 2,
		"offer": "Acordou, Pé-Molhado! Tava mais azul que ameixa. Senta aí, come, e depois a gente vê o que você sabe fazer.",
		"done": "Rosa dobra a manga da camisa no seu braço e para no meio. \"Ficava bem nele também.\"",
		"steps": [["talk", "innkeeper", 1, "village", "Fale com Rosa na estalagem"],
			["reach", "village", 1, "village", "Vá até a praça da vila"],
			["talk", "elder", 1, "village", "Fale com a Vó Cândida"]],
		"rewards": {"xp": 20, "gold": 10, "items": {"roupa_tome": 1, "pao_rosa": 3}, "equip": ["roupa_tome"]}},
	{"id": "m02", "kind": "main", "title": "Mãos para a Quinta", "giver": "elder", "requires": ["m01"],
		"level": 1, "minutes": 6,
		"offer": "Quem come, trabalha. Vá ajudar o Matias na quinta.",
		"done": "\"Pois é. Era aqui.\" Matias tira o chapéu diante da cova vidrada e morna.",
		"steps": [["reach", "farm", 1, "farm", "Vá até a Quinta do Rego"],
			["collect", "nabo", 5, "farm", "Colha nabos no campo"],
			["talk", "farmer", 1, "farm", "Leve os nabos ao Matias"]],
		"rewards": {"xp": 30, "gold": 15}},
	{"id": "m03", "kind": "main", "title": "A Relha Velha", "giver": "blacksmith", "requires": ["m02"],
		"level": 2, "minutes": 6,
		"offer": "Espada eu faço. Coragem você traz de casa. Me traga a relha velha do celeiro do Matias.",
		"done": "\"Pra ela lembrar que nasceu pra abrir a terra, não gente. Só corte quem precisa.\"",
		"steps": [["talk", "blacksmith", 1, "village", "Fale com a Mestra Joana na forja"],
			["collect", "relha_velha", 1, "farm", "Pegue a relha velha no celeiro da quinta"],
			["interact", "forja_joana", 1, "village", "Leve a relha à forja de Joana"]],
		"rewards": {"xp": 40, "items": {"espada_relha": 1}, "equip": ["espada_relha"]}},
	{"id": "m04", "kind": "main", "title": "Dentes no Galinheiro", "giver": "guard_captain", "requires": ["m03"],
		"level": 2, "minutes": 6,
		"offer": "Tem Diabrete no galinheiro do Matias, recruta. Vá lá testar essa espada.",
		"done": "Você sonha um sonho que não é seu: ovos de dragão, frios. Acorda com gosto de pão na boca.",
		"steps": [["kill", "wolf_imp", 3, "farm", "Expulse os Diabretes do galinheiro"],
			["interact", "marco_quinta", 1, "farm", "Descanse no Marco de Lume da quinta"]],
		"rewards": {"xp": 50, "refill": {"frasco": 2}, "unlocks": ["descanso"], "rest": "marco_quinta"}},
	{"id": "m05", "kind": "main", "title": "O Moinho Parado", "giver": "elder", "requires": ["m04"],
		"level": 3, "minutes": 9,
		"offer": "Sem moinho, sem farinha. Sem farinha, sem pão. Vá ver o que parou a roda.",
		"done": "A roda volta a girar e solta os restos da sua jangada. Um rapaz foge e deixa cair uma carta.",
		"steps": [["reach", "river", 1, "river", "Vá até o moinho no rio"],
			["kill", "bandit", 3, "river", "Enfrente os Sem-Terra na ponte"],
			["interact", "moinho_comporta", 1, "river", "Abra a comporta do moinho"]],
		"rewards": {"xp": 60, "gold": 20, "items": {"carta_matias": 1}}},
	{"id": "m06", "kind": "main", "title": "Escudo Alto, Recruta", "giver": "guard_captain", "requires": ["m05"],
		"level": 4, "minutes": 8,
		"offer": "Escudo alto, recruta. Não é o golpe que mata. É o segundo golpe.",
		"done": "Rui devolve o escudo com as duas mãos, como quem pede desculpa a alguém que não está ali.",
		"steps": [["interact", "poste_treino", 1, "village", "Treine no poste do Capitão Rui"],
			["kill", "wolf_imp", 4, "forest", "Derrote Diabretes na estrada do bosque"],
			["talk", "guard_captain", 1, "village", "Volte ao Capitão Rui"]],
		"rewards": {"xp": 80, "items": {"escudo_tonel": 1}, "equip": ["escudo_tonel"], "unlocks": ["bloqueio", "aparar"]}},
	{"id": "m07", "kind": "main", "title": "Sussurros na Carvalha", "giver": "priest", "requires": ["m06"],
		"level": 5, "minutes": 12,
		"offer": "O bosque está cantando alto demais. Vá ver a Carvalha-Mãe.",
		"done": "A carvalha cantarola a cantiga de Rosa. Você sonha o primeiro voo da Lumeira, sobre o mar.",
		"steps": [["reach", "forest", 1, "forest", "Entre no Bosque dos Sussurros"],
			["kill", "wolf_imp", 5, "forest", "Derrote o bando de Diabretes"],
			["interact", "carvalha_mae", 1, "forest", "Toque a Carvalha-Mãe"],
			["collect", "semente_carvalha", 1, "forest", "Pegue a semente entre as raízes"]],
		"rewards": {"xp": 150, "unlocks": ["sopro_brasa"]}},
	{"id": "m08", "kind": "main", "title": "Pão para os Sem-Terra", "giver": "farmer", "requires": ["m07"],
		"level": 6, "minutes": 14,
		"offer": "Essa letra... é minha. Leve farinha pro meu irmão, o Tobias. Diga que eu mandei.",
		"done": "Tobias lê a carta, ri e chora. \"A Santa Inês fugiu de novo.\" Ele te dá a semente roubada.",
		"steps": [["collect", "farinha", 3, "river", "Pegue 3 sacos de farinha no moinho"],
			["reach", "bandit_camp", 1, "bandit_camp", "Vá ao acampamento dos Sem-Terra"],
			["kill", "bandit_archer", 3, "bandit_camp", "Derrote os atiradores nas pedras"],
			["interact", "tenda_tobias", 1, "bandit_camp", "Entregue a farinha na tenda de Tobias"]],
		"rewards": {"xp": 150, "gold": 40, "items": {"semente_sem_terra": 1}, "unlocks": ["paz_sem_terra"],
			"take": ["carta_matias"]}},
	{"id": "m09", "kind": "main", "title": "O Fogo da Atalaia", "giver": "guard_captain", "requires": ["m08"],
		"level": 7, "minutes": 12,
		"offer": "A Vigília guarda um livro na Atalaia. Quero esse livro, recruta. E quero aquele farol aceso.",
		"done": "Do alto você vê o castelo, todas as janelas acesas. Lá embaixo, a vila sai de casa para olhar o farol.",
		"steps": [["reach", "watchtower", 1, "watchtower", "Suba o morro até a Atalaia"],
			["kill", "knight", 2, "watchtower", "Derrote os Guardas da Vigília"],
			["collect", "livro_desenterro", 1, "watchtower", "Pegue o Livro do Desenterro"],
			["interact", "farol_atalaia", 1, "watchtower", "Acenda o farol"]],
		"rewards": {"xp": 80, "gold": 30, "items": {"gibao_patrulheiro": 1, "mapa_vale": 1}, "equip": ["gibao_patrulheiro"],
			"unlocks": ["mapa_covas"]}},
	{"id": "m10", "kind": "main", "title": "A Semente Afogada", "giver": "fisher", "requires": ["m09"],
		"level": 8, "minutes": 12,
		"offer": "Joguei no fundo pra ninguém ter. Nem eu. Mas os de olho aberto não param de descer até a água.",
		"done": "Os Insones caem dormindo, sorrindo. Celeste cobre cada um com a rede, como quem cobre criança.",
		"steps": [["reach", "lake", 1, "lake", "Vá até o Lago Manso"],
			["kill", "possessed", 3, "lake", "Faça os Insones do píer dormirem"],
			["interact", "barco_celeste", 1, "lake", "Reme no barco de Celeste"],
			["collect", "semente_afogada", 1, "lake", "Mergulhe pela semente afogada"]],
		"rewards": {"xp": 200, "unlocks": ["calor_lar"]}},
	{"id": "m11", "kind": "main", "title": "O Fôlego da Montanha", "giver": "miner", "requires": ["m10"],
		"level": 9, "minutes": 16,
		"offer": "HEIN? A semente funda? Tá lá embaixo, com os Pugos! Toma a chave e não cava nada!",
		"done": "Gaspar põe a mão na pedra e para de gritar. \"Tá morna. Ainda tá morna.\"",
		"steps": [["talk", "miner", 1, "mine", "Fale com Gaspar na boca da mina"],
			["interact", "mina_portao", 1, "mine", "Abra o portão da mina"],
			["kill", "puglin", 6, "mine", "Atravesse as galerias dos Pugos"],
			["reach", "mina_fundo", 1, "mine", "Desça até a câmara funda"],
			["collect", "semente_funda", 1, "mine", "Pegue a semente funda"]],
		"rewards": {"xp": 250, "gold": 30, "items": {"minerio_brasa": 1}, "unlocks": ["tunel_castelo"]}},
	{"id": "m12", "kind": "main", "title": "O Que Joana Forjou", "giver": "blacksmith", "requires": ["m11"],
		"level": 10, "minutes": 4,
		"offer": "Minério de brasa. Sabe o que dá pra fazer com isso? Eu sei. Eu já fiz uma vez.",
		"done": "Joana arranca da bigorna a marca da Vigília. \"Pronto. Agora sou só ferreira.\"",
		"steps": [["talk", "blacksmith", 1, "village", "Fale com a Mestra Joana"],
			["interact", "forja_joana", 1, "village", "Ajude Joana na forja"]],
		"rewards": {"xp": 150, "items": {"espada_lume": 1, "escudo_carvalho": 1}, "equip": ["espada_lume", "escudo_carvalho"],
			"take": ["minerio_brasa"]}},
	{"id": "m13", "kind": "main", "title": "A Cantiga Inteira", "giver": "elder", "requires": ["m12"],
		"level": 10, "minutes": 6,
		"offer": "Antes de subir, fale com o frei. Ele tem uma coisa pra contar. Depois volte aqui.",
		"done": "\"E a última se planta com a mão de quem não é daqui.\" Leve o cavalinho. Se ainda tiver menino lá dentro, ele reconhece.",
		"steps": [["talk", "priest", 1, "village", "Ouça a confissão do Frei Anselmo"],
			["talk", "elder", 1, "village", "Volte à Vó Cândida"]],
		"rewards": {"xp": 150, "items": {"cavalinho_de_pau": 1}, "refill": {"frasco": 1}, "unlocks": ["senha_portao", "castelo"]}},
	{"id": "m14", "kind": "main", "title": "A Vigília", "giver": "elder", "requires": ["m13"],
		"level": 11, "minutes": 20,
		"offer": "Levar as sementes até ele é exatamente o que ele quer. Vá assim mesmo. Vá pelo túnel.",
		"done": "O conde dorme abraçado ao cavalinho. Você abre o relicário por dentro, como Joana disse.",
		"steps": [["reach", "mine", 1, "mine", "Volte à Mina do Fôlego"],
			["reach", "castle", 1, "castle", "Suba pelo túnel até o castelo"],
			["kill", "knight", 6, "castle", "Derrote os Guardas da Vigília"],
			["interact", "castelo_portao", 1, "castle", "Abra o portão interno com a senha"],
			["kill", "boss", 1, "castle", "Enfrente Dom Aurélio, o Conde que Não Dorme"],
			["interact", "relicario", 1, "castle", "Abra o relicário"]],
		"rewards": {"xp": 500, "gold": 100, "unlocks": ["fim"],
			"seeds": ["relicario_1", "relicario_2", "relicario_3", "relicario_4", "relicario_5", "relicario_6",
				"relicario_7", "relicario_8"]}},
	# side quests
	{"id": "s1", "kind": "side", "title": "Cartas Que Não Foram", "giver": "innkeeper", "requires": ["m10"],
		"level": 8, "minutes": 6,
		"offer": "Tem umas cartas debaixo do balcão. Nunca mandei. Se você vir o meu Tomé no lago...",
		"done": "Na quarta linha, Tomé fecha os olhos e dorme sentado. Rosa não chora: vai buscar um cobertor.",
		"steps": [["collect", "cartas_rosa", 1, "village", "Pegue as cartas debaixo do balcão"],
			["reach", "lake", 1, "lake", "Vá até o píer do lago"],
			["interact", "insone_tome", 1, "lake", "Leia uma carta para Tomé"]],
		"rewards": {"xp": 50, "refill": {"caldo_rosa": 1}}},
	{"id": "s2", "kind": "side", "title": "A Lasca do Seu Bené", "giver": "merchant", "requires": ["m04"],
		"level": 3, "minutes": 5,
		"offer": "Você já sonhou que voava, Pé-Molhado? ... Leva isso pra longe de mim. Joga no rio.",
		"done": "\"Eu voei, Pé-Molhado. Toda noite.\" Ele solta a lasca e diz que a Duquesa é que mandou.",
		"steps": [["talk", "merchant", 1, "village", "Fale com o Seu Bené"],
			["reach", "river", 1, "river", "Leve a lasca até o rio"],
			["interact", "ponte_rio", 1, "river", "Jogue a lasca da ponte"]],
		"rewards": {"xp": 60, "unlocks": ["desconto_bene"]}},
	{"id": "s3", "kind": "side", "title": "Os Sinos das Santas", "giver": "farmer", "requires": ["m05"],  # bells and imps lie past the toll bridge (world/gates.gd)
		"level": 3, "minutes": 10,
		"offer": "A Santa Inês fugiu de novo. E as outras foram atrás. Se achar sino torto, é delas.",
		"done": "Santa Inês volta sozinha para casa, tocando nada, ofendida.",
		"steps": [["collect", "sino_vaca", 4, "farm", "Ache os sinos das vacas (quinta, bosque, rio)"],
			["kill", "wolf_imp", 3, "forest", "Desfaça o ninho de Diabretes no bosque"],
			["talk", "farmer", 1, "farm", "Devolva os sinos ao Matias"]],
		"rewards": {"xp": 60, "gold": 30, "items": {"queijo_quinta": 2}}},
	{"id": "s4", "kind": "side", "title": "Os Pombos do Frei", "giver": "pombal", "requires": ["m04"],
		"level": 3, "minutes": 4,
		"offer": "No pombal da capela há uma carta presa na pata de um pombo, endereçada ao castelo.",
		"done": "O frei queima a carta na vela dos esquecidos e acende outra vela, pela irmã.",
		"steps": [["interact", "pombal", 1, "village", "Pegue a carta no pombal"],
			["talk", "priest", 1, "village", "Mostre a carta ao Frei Anselmo"]],
		"rewards": {"xp": 60, "refill": {"frasco": 1}, "unlocks": ["bencao_repouso"]}},
	{"id": "s5", "kind": "side", "title": "Ferro de Arado", "giver": "blacksmith", "requires": ["m09"],
		"level": 8, "minutes": 10,
		"offer": "Elmo da Vigília é ferro bom em cabeça ruim. Me traga três. Viram relha.",
		"done": "Joana martela cantando a cantiga das sementes, desafinada. Primeira vez em vinte anos.",
		"steps": [["kill", "knight", 3, "watchtower", "Derrote Guardas da Vigília na estrada da Atalaia"],
			["collect", "elmo_vigilia", 3, "watchtower", "Recolha 3 elmos da Vigília"],
			["talk", "blacksmith", 1, "village", "Leve os elmos para Joana"]],
		"rewards": {"xp": 120, "items": {"gibao_reforcado": 1}, "equip": ["gibao_reforcado"], "unlocks": ["loja_sem_terra"]}},
	{"id": "s6", "kind": "side", "title": "O Peixe-Lua", "giver": "fisher", "requires": ["m10"],
		"level": 8, "minutes": 6,
		"offer": "O peixe-lua só sobe quando a lua some. Me traga três. Quero ver uma coisa.",
		"done": "Celeste devolve o terceiro peixe à água. \"Não se come quem sabe das coisas.\"",
		"steps": [["collect", "peixe_lua", 3, "lake", "Pesque 3 peixes-lua perto do píer"],
			["talk", "fisher", 1, "lake", "Leve os peixes para Dona Celeste"]],
		"rewards": {"xp": 40, "items": {"anzol_celeste": 1}}},
	{"id": "s7", "kind": "side", "title": "O Sino-Mãe", "giver": "farmer", "requires": ["m14"],
		"level": 12, "minutes": 6,  # fast travel: the Marco da Cauda sits at the head of the pass
		"offer": "Antes do Desenterro a gente subia com o gado pros Pastos da Cauda, pelo Passo da Escama, atrás da Atalaia. Meu pai deixou o Sino-Mãe no curral de lá. Se vai ter inverno, as vacas vão precisar dele pra achar o caminho de casa na neve.",
		"done": "Matias bate o sino uma vez. Lá do pasto, a Santa Inês responde com um mugido ofendido.",
		"steps": [["reach", "cauda", 1, "cauda", "Suba pelo Passo da Escama até os Pastos da Cauda"],
			["kill", "knight", 3, "cauda_ponta", "O poste do curral está vazio: derrote os guardas que cavam a Ponta da Cauda"],
			["interact", "sino_mae", 1, "cauda_ponta", "Pegue o Sino-Mãe na carroça dos guardas"],
			["talk", "farmer", 1, "farm", "Leve o Sino-Mãe ao Matias"]],
		"rewards": {"xp": 300, "gold": 120, "items": {"queijo_quinta": 3}}},
]

var prog: Progression
var items: Items
var state: Dictionary = {}      # quest id -> "offered" | "active" | "done" (absent: locked)
var step_i: Dictionary = {}     # quest id -> current step index
var count_i: Dictionary = {}    # quest id -> progress inside the current step
var tracked: String = ""        # quest the HUD follows ("" = automatic)


func _init(p: Progression = null, i: Items = null) -> void:
	prog = p if p != null else Progression.new()
	items = i if i != null else Items.new()


# fresh game: unlocks the quests with no requirements (m01 starts at once)
func start_new() -> void:
	_refresh()


static var _by_id: Dictionary = {}  # id -> DATA entry; quest() runs hundreds of times a frame via is_target


static func quest(id: String) -> Dictionary:
	if _by_id.is_empty():
		for q: Dictionary in DATA:
			if not _by_id.has(str(q.id)):  # first one wins, like the old linear search
				_by_id[str(q.id)] = q
	return _by_id.get(id, {})


static func step_of(q: Dictionary, i: int) -> Dictionary:
	var a: Array = q.steps[i] as Array
	return {"type": str(a[0]), "target": str(a[1]), "count": int(a[2]), "where": str(a[3]), "text": str(a[4])}


func status(id: String) -> String:
	return str(state.get(id, "locked"))


func is_done(id: String) -> bool:
	return status(id) == "done"


func notify(event: String, target: String) -> void:
	match event:
		"kill":
			prog.add_kill(target)
		"collect":
			if Items.DEFS.has(target):
				items.add(target)
				if str(Items.def(target).get("kind", "")) == "seed":
					prog.add_seed(target)
		"interact":
			if target.begins_with("marco_"):
				rest(target)
	var was_offered: Array[String] = _ids("offered")
	for id: String in _ids("active"):
		_advance(id, event, target)
	# quests offered by this NPC or object start now; a main quest this very event unlocked starts too
	# (the elder finishing m01 hands over m02 in the same talk), a new side quest waits for its own talk
	if event == "talk" or event == "interact":
		for id: String in _ids("offered"):
			if str(quest(id).giver) == target and (id in was_offered or str(quest(id).kind) == "main"):
				_start(id)
				var s: Dictionary = step_of(quest(id), 0)
				if s.type == event and s.target == target:
					_advance(id, event, target)


# would this event progress or start anything right now?
func is_target(event: String, target: String) -> bool:
	for id: String in state:
		if state[id] == "active":
			var a: Array = quest(id).steps[int(step_i[id])] as Array  # step_of() without its per-call Dictionary
			if str(a[0]) == event and str(a[1]) == target:
				return true
		elif state[id] == "offered" and (event == "talk" or event == "interact") and str(quest(id).giver) == target:
			return true
	return false


# rest at a Marco de Lume (needs the "descanso" unlock); glue heals the hero on the rested signal
func rest(marco_id: String) -> bool:
	if not prog.has_unlock("descanso"):
		return false
	prog.last_marco = marco_id
	items.refill()
	rested.emit(marco_id)
	return true


func track(id: String) -> void:
	tracked = id if status(id) in ["active", "offered"] else ""


# what the HUD tracker shows: {} when nothing is left
# {id, title, kind, state: "active"|"offered", text, type, target, count, have, step, steps,
#  pos_kind: "npc"|"place"|"interactable", pos_key, where}
# pos_kind npc: pos_key is a map npc_spots role; place: a map places id (or the spawn "mina_fundo");
# interactable: a map interactables id. "where" is always a place id near the target.
func current() -> Dictionary:
	var id: String = tracked if status(tracked) in ["active", "offered"] else ""
	if id == "":
		for pick: Array in [["active", "main"], ["offered", "main"], ["active", "side"], ["offered", "side"]]:
			for q: Dictionary in DATA:
				if status(str(q.id)) == pick[0] and str(q.kind) == pick[1]:
					id = str(q.id)
					break
			if id != "":
				break
	if id == "":
		return {}
	var q: Dictionary = quest(id)
	var out: Dictionary = {"id": id, "title": str(q.title), "kind": str(q.kind), "state": status(id),
		"steps": (q.steps as Array).size()}
	if status(id) == "offered":
		var giver: String = str(q.giver)
		var is_npc: bool = NPC_NAME.has(giver)
		out.merge({"text": ("Fale com %s" % NPC_NAME[giver]) if is_npc else str(q.offer), "type": "talk" if is_npc else "interact",
			"target": giver, "count": 1, "have": 0, "step": -1, "pos_kind": "npc" if is_npc else "interactable",
			"pos_key": giver, "where": step_of(q, 0).where})
		return out
	var i: int = int(step_i[id])
	var s: Dictionary = step_of(q, i)
	var have: int = _have(id, s)
	var text: String = str(s.text)
	if int(s.count) > 1:
		text += " (%d/%d)" % [have, int(s.count)]
	var pk: String = {"talk": "npc", "reach": "place", "interact": "interactable"}.get(s.type, "place")
	out.merge({"text": text, "type": s.type, "target": s.target, "count": s.count, "have": have, "step": i,
		"pos_kind": pk, "pos_key": s.where if pk == "place" and s.type != "reach" else s.target, "where": s.where})
	return out


# quest log for the menu: [{id, title, kind, state, text}] in data order, locked ones left out
func journal() -> Array:
	var out: Array = []
	for q: Dictionary in DATA:
		var id: String = str(q.id)
		if status(id) == "locked":
			continue
		var t: String = "Concluída" if is_done(id) else ""
		if status(id) == "active":
			t = step_of(q, int(step_i[id])).text
		elif status(id) == "offered":
			t = "Fale com %s" % NPC_NAME.get(str(q.giver), str(q.giver))
		out.append({"id": id, "title": str(q.title), "kind": str(q.kind), "state": status(id), "text": t})
	return out


func _ids(st: String) -> Array[String]:
	var out: Array[String] = []
	for q: Dictionary in DATA:
		if status(str(q.id)) == st:
			out.append(str(q.id))
	return out


func _have(id: String, s: Dictionary) -> int:
	if s.type == "collect":
		return mini(items.count(str(s.target)), int(s.count))
	return int(count_i.get(id, 0))


func _start(id: String) -> void:
	state[id] = "active"
	step_i[id] = 0
	count_i[id] = 0
	quest_started.emit(id)
	_skip_collected(id)


func _advance(id: String, event: String, target: String) -> void:
	var q: Dictionary = quest(id)
	var s: Dictionary = step_of(q, int(step_i[id]))
	if s.type != event or s.target != target:
		return
	if event != "collect":
		count_i[id] = int(count_i.get(id, 0)) + 1
	var have: int = _have(id, s)
	progress.emit(id, have, int(s.count))
	if have >= int(s.count):
		_next_step(id)


func _next_step(id: String) -> void:
	step_done.emit(id, int(step_i[id]))
	step_i[id] = int(step_i[id]) + 1
	count_i[id] = 0
	if int(step_i[id]) >= (quest(id).steps as Array).size():
		_complete(id)
	else:
		_skip_collected(id)


# a collect step whose items are already in the bag is done at once
func _skip_collected(id: String) -> void:
	if state.get(id) != "active":
		return
	var s: Dictionary = step_of(quest(id), int(step_i[id]))
	if s.type == "collect" and _have(id, s) >= int(s.count):
		_next_step(id)


func _complete(id: String) -> void:
	var q: Dictionary = quest(id)
	state[id] = "done"
	step_i.erase(id)
	count_i.erase(id)
	if tracked == id:
		tracked = ""
	# hand over what was collected (seeds and keepsakes stay)
	for a: Variant in q.steps:
		var s: Array = a as Array
		if str(s[0]) == "collect" and not bool(Items.def(str(s[1])).get("keep", false)):
			items.remove(str(s[1]), mini(int(s[2]), items.count(str(s[1]))))
	var r: Dictionary = q.rewards
	for t: Variant in r.get("take", []) as Array:
		items.remove(str(t), items.count(str(t)))
	var it: Dictionary = r.get("items", {}) as Dictionary
	for item_id: String in it:
		items.add(item_id, int(it[item_id]))
		if str(Items.def(item_id).get("kind", "")) == "seed":
			prog.add_seed(item_id)
	for e: Variant in r.get("equip", []) as Array:
		items.equip(str(e))
	var rf: Dictionary = r.get("refill", {}) as Dictionary
	for item_id: String in rf:
		items.raise_refill(item_id, int(rf[item_id]))
	for u: Variant in r.get("unlocks", []) as Array:
		prog.unlock(str(u))
	for sd: Variant in r.get("seeds", []) as Array:
		prog.add_seed(str(sd))
	if r.has("gold"):
		prog.add_gold(int(r.gold))
	if r.has("rest"):
		rest(str(r.rest))
	quest_done.emit(id, r)
	if r.has("xp"):
		prog.gain_xp(int(r.xp))
	_refresh()


func _refresh() -> void:
	for q: Dictionary in DATA:
		var id: String = str(q.id)
		if state.has(id):
			continue
		var ok: bool = true
		for req: Variant in q.requires:
			ok = ok and is_done(str(req))
		if not ok:
			continue
		state[id] = "offered"
		quest_offered.emit(id)
		if bool(q.get("auto", false)):
			_start(id)


func to_dict() -> Dictionary:
	return {"state": state.duplicate(), "step_i": step_i.duplicate(), "count_i": count_i.duplicate(), "tracked": tracked}


func from_dict(d: Dictionary) -> void:
	state = {}
	step_i = {}
	count_i = {}
	var st: Dictionary = d.get("state", {}) as Dictionary
	var si: Dictionary = d.get("step_i", {}) as Dictionary
	var ci: Dictionary = d.get("count_i", {}) as Dictionary
	for id: String in st:
		if quest(id).is_empty():
			continue
		state[id] = str(st[id])
		if state[id] == "active":
			step_i[id] = clampi(int(si.get(id, 0)), 0, (quest(id).steps as Array).size() - 1)
			count_i[id] = int(ci.get(id, 0))
	tracked = str(d.get("tracked", ""))
	_refresh()


# the whole game state (progression, items, quests) as one JSON file
func save_game(path: String = SAVE_PATH) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "progression": prog.to_dict(), "items": items.to_dict(),
		"quests": to_dict()}, "\t"))
	f.close()
	return true


# false (and nothing changed) when there is no valid save
func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var d: Dictionary = parsed as Dictionary
	prog.from_dict(d.get("progression", {}) as Dictionary)
	items.from_dict(d.get("items", {}) as Dictionary)
	from_dict(d.get("quests", {}) as Dictionary)
	return true


static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)
