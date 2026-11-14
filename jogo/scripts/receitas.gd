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
	"smg": {"pecas": {"mola": 3, "gatilho": 1, "cano": 2, "ferrolho": 1, "carregador": 1}, "raridade": MEDIANA, "categoria": "ARMAS"},
	# 13/11 floresta: feitas na mão (sem bancada), conhecidas desde o começo (Jogador.RECEITAS_MATA)
	"fogueira": {"pecas": {"madeira": 3, "pedra": 3}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"tabuas": {"pecas": {"madeira": 4}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"armadilha": {"pecas": {"madeira": 2, "pedra": 2}, "raridade": SIMPLES, "categoria": "ÚTEIS", "mao": true},
	# 14/11 (dono: item 2 "base que cresce"): fogueira -> barraca -> cabana, e em volta cerca, torre, baú e horta.
	# Os níveis de cima pedem peças que só saem de raid/zumbi (cano, ferrolho, mola): o mapa todo vira motivo.
	"barraca": {"pecas": {"madeira": 6, "tabuas": 1}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"estacas": {"pecas": {"madeira": 6}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"horta": {"pecas": {"madeira": 2, "pedra": 2, "fruta": 4}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"bau_base": {"pecas": {"tabuas": 3, "mola": 1}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"torre": {"pecas": {"madeira": 10, "tabuas": 4, "cano": 1}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
	"cabana": {"pecas": {"tabuas": 8, "pedra": 10, "cano": 2, "ferrolho": 1}, "raridade": SIMPLES, "categoria": "BASE", "mao": true},
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
