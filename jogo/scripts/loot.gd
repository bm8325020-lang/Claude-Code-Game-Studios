# Tabela de loot: o que pode sair num baú, com que peso (chance relativa) e quanto. O servidor sorteia.
# Raridade só muda o peso e a cor do nome na tela. Valores provisórios.
class_name Loot
extends RefCounted

const COMUM: int = 0
const INCOMUM: int = 1
const RARO: int = 2
const CORES: Array[Color] = [Color(0.85, 0.84, 0.8), Color(0.45, 0.75, 0.4), Color(0.4, 0.6, 0.95)]

## [tipo, peso, mínimo, máximo, raridade]
const TABELA: Array = [
	["municao", 30, 6, 18, COMUM],
	["comida", 26, 1, 2, COMUM],
	["agua", 26, 1, 2, COMUM],
	["municao", 8, 24, 36, INCOMUM],
	["lanterna", 4, 1, 1, RARO],
	["antibiotico", 4, 1, 1, RARO],
	["faca", 6, 1, 1, INCOMUM],
	["taco", 4, 1, 1, INCOMUM],
	["machado", 2, 1, 1, RARO],
	["mola", 5, 1, 2, COMUM],
	["gatilho", 4, 1, 1, COMUM],
	["cano", 3, 1, 1, INCOMUM],
	["cabo", 3, 1, 1, INCOMUM],
	["ferrolho", 1, 1, 1, RARO],
	["carregador", 1, 1, 1, RARO],
	["receita_pistola", 3, 1, 1, INCOMUM],
	["smg", 1, 1, 1, RARO],
	["receita_smg", 1, 1, 1, RARO],
]
## peças de arma (para fabricar, prompt 6)
const PECAS: Array[String] = ["mola", "gatilho", "cano", "cabo", "ferrolho", "carregador"]
## o que cai de zumbi morto (drop de zumbi é importante: é a fonte principal de peças)
const DROP_ZUMBI: Array = [
	["mola", 10, 1, 1, COMUM],
	["gatilho", 8, 1, 1, COMUM],
	["cano", 5, 1, 1, INCOMUM],
	["cabo", 5, 1, 1, INCOMUM],
	["ferrolho", 2, 1, 1, RARO],
	["carregador", 2, 1, 1, RARO],
	["municao", 12, 4, 10, COMUM],
	["comida", 5, 1, 1, COMUM],
	["receita_pistola", 1, 1, 1, RARO],
	["receita_smg", 1, 1, 1, RARO],
]
const CHANCE_ZUMBI: float = 0.35  # zumbi comum: chance de largar alguma coisa
const CHEFE_ROLAGENS: Vector2i = Vector2i(2, 3)  # chefe sempre larga, mais coisas
const CHEFE_RARO: float = 3.0  # e as raras ficam 3x mais prováveis
## cidade inicial: mais comida e água (mais fácil para quem acabou de nascer)
const FACIL: Dictionary = {"comida": 1.6, "agua": 1.6}
const ITENS_MIN: int = 2
const ITENS_MAX: int = 4


static func raridade(tipo: String) -> int:
	var r: int = COMUM
	for l: Array in TABELA + DROP_ZUMBI:
		if l[0] == tipo:
			r = maxi(r, int(l[4]))
	return r


## Sorteia o conteúdo de um baú: lista de {"tipo", "qtd"} (tipos repetidos se juntam).
static func sorteia(rng: RandomNumberGenerator, facil: bool = false) -> Array:
	return _rola(TABELA, rng, rng.randi_range(ITENS_MIN, ITENS_MAX), FACIL if facil else {}, 1.0)


## O que um zumbi morto larga (lista vazia = nada). O chefe sempre larga, mais e mais raro.
static func drop(rng: RandomNumberGenerator, chefe: bool = false) -> Array:
	if chefe:
		return _rola(DROP_ZUMBI, rng, rng.randi_range(CHEFE_ROLAGENS.x, CHEFE_ROLAGENS.y), {}, CHEFE_RARO)
	if rng.randf() >= CHANCE_ZUMBI:
		return []
	return _rola(DROP_ZUMBI, rng, 1, {}, 1.0)


# `vezes` sorteios na tabela (peso × multiplicador por tipo; raras × `raro`), juntando o mesmo tipo
static func _rola(tabela: Array, rng: RandomNumberGenerator, vezes: int, mult: Dictionary, raro: float) -> Array:
	var pesos: Array[float] = []
	var total: float = 0.0
	for l: Array in tabela:
		var p: float = float(l[1]) * float(mult.get(l[0], 1.0)) * (raro if int(l[4]) == RARO else 1.0)
		pesos.append(p)
		total += p
	var junta: Dictionary = {}
	for k in vezes:
		var x: float = rng.randf() * total
		for i in tabela.size():
			x -= pesos[i]
			if x <= 0.0:
				var l: Array = tabela[i]
				junta[l[0]] = int(junta.get(l[0], 0)) + rng.randi_range(int(l[2]), int(l[3]))
				break
	var out: Array = []
	for t: String in junta:
		out.append({"tipo": t, "qtd": junta[t]})
	return out
