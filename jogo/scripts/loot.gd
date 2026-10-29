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
	["faca", 6, 1, 1, INCOMUM],
	["taco", 4, 1, 1, INCOMUM],
	["machado", 2, 1, 1, RARO],
]
## cidade inicial: mais comida e água (mais fácil para quem acabou de nascer)
const FACIL: Dictionary = {"comida": 1.6, "agua": 1.6}
const ITENS_MIN: int = 2
const ITENS_MAX: int = 4


static func raridade(tipo: String) -> int:
	var r: int = COMUM
	for l: Array in TABELA:
		if l[0] == tipo:
			r = maxi(r, int(l[4]))
	return r


## Sorteia o conteúdo de um baú: lista de {"tipo", "qtd"} (tipos repetidos se juntam).
static func sorteia(rng: RandomNumberGenerator, facil: bool = false) -> Array:
	var pesos: Array[float] = []
	var total: float = 0.0
	for l: Array in TABELA:
		var p: float = float(l[1]) * (float(FACIL.get(l[0], 1.0)) if facil else 1.0)
		pesos.append(p)
		total += p
	var junta: Dictionary = {}
	for k in rng.randi_range(ITENS_MIN, ITENS_MAX):
		var x: float = rng.randf() * total
		for i in TABELA.size():
			x -= pesos[i]
			if x <= 0.0:
				var l: Array = TABELA[i]
				junta[l[0]] = int(junta.get(l[0], 0)) + rng.randi_range(int(l[2]), int(l[3]))
				break
	var out: Array = []
	for t: String in junta:
		out.append({"tipo": t, "qtd": junta[t]})
	return out
