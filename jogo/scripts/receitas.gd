# Receitas de fabricação (mecânica 6 do loop): o que cada arma pede de peças. A receita é um item da mochila
# ("receita_<arma>"); usar ensina (fica na lista do jogador) e ela some. Fabricar só perto da bancada.
# Raridade da receita: simples (baú/zumbi), mediana (difícil), rara (muito difícil: baú raro, drop, chefe).
class_name Receitas
extends RefCounted

const SIMPLES: int = 0
const MEDIANA: int = 1
const RARA: int = 2
const FABRICAR_T: float = 3.0  # s por unidade

## arma -> {"pecas": {peça: qtd}, "raridade", "categoria"}
const LISTA: Dictionary = {
	"pistola": {"pecas": {"mola": 2, "gatilho": 1, "cano": 1, "cabo": 1}, "raridade": SIMPLES, "categoria": "ARMAS"},
}
const CATEGORIAS: Array[String] = ["ARMAS", "ÚTEIS", "SAÚDE", "BASE"]


static func item_de(arma: String) -> String:
	return "receita_" + arma


static func arma_de(item: String) -> String:
	return item.trim_prefix("receita_") if item.begins_with("receita_") else ""


## Quantas unidades dá para fazer com o que tem na mochila.
static func quantas(m: Mochila, arma: String) -> int:
	var n: int = 999
	var pecas: Dictionary = LISTA[arma].pecas
	for p: String in pecas:
		n = mini(n, m.conta(p) / int(pecas[p]))
	return n


## Gasta as peças e põe `n` unidades da arma na mochila. Devolve quantas fez (0 se faltar peça ou espaço).
static func fabrica(m: Mochila, arma: String, n: int) -> int:
	n = mini(n, quantas(m, arma))
	var feitas: int = 0
	for k in n:
		if m.adicionar(arma, 1) == 0:
			break  # sem espaço / no limite
		for p: String in LISTA[arma].pecas:
			m.tirar(p, int(LISTA[arma].pecas[p]))
		feitas += 1
	return feitas
