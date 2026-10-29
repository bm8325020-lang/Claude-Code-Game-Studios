# Mochila do jogador: espaços com itens (os 6 primeiros são a barra rápida 1–6). Itens empilháveis (munição,
# comida, água) enchem as pilhas que já existem antes de ocupar espaço novo. Só dados: a tela é TelaMochila.
# Por enquanto o dono do jogador guarda a mochila (como a vida e a munição); passar para o servidor junto com a
# conta salva (prompt 16).
class_name Mochila
extends RefCounted

signal mudou

const ESPACOS: int = 24
const BARRA: int = 6
## tamanho da pilha por espaço (o que não está aqui não empilha)
const PILHA: Dictionary = {"municao": 48, "comida": 5, "agua": 5, "mola": 10, "gatilho": 10, "cano": 10, "cabo": 10,
	"ferrolho": 10, "carregador": 10}
## quanto dá para carregar no total (provisório, até existir peso)
const LIMITE: Dictionary = {"municao": 96, "comida": 5, "agua": 5, "lanterna": 1, "facao": 1, "pistola": 1,
	"faca": 1, "taco": 1, "machado": 1, "mola": 30, "gatilho": 30, "cano": 30, "cabo": 30, "ferrolho": 30, "carregador": 30}
## não dá para largar (são a mão do jogador por enquanto)
const PRESOS: Array[String] = ["facao", "pistola"]
const NOMES: Dictionary = {"municao": "Munição", "comida": "Lata de comida", "agua": "Garrafa de água",
	"lanterna": "Lanterna", "facao": "Facão", "pistola": "Pistola 9 mm", "faca": "Faca de açougueiro",
	"taco": "Taco de beisebol", "machado": "Machado de bombeiro", "mola": "Mola", "gatilho": "Gatilho", "cano": "Cano",
	"cabo": "Empunhadura", "ferrolho": "Ferrolho", "carregador": "Carregador"}
const TEXTOS: Dictionary = {
	"municao": "Balas 9 mm para a pistola.",
	"comida": "Conserva sem rótulo. Enche a fome.",
	"agua": "Água de garrafa. Mata a sede.",
	"lanterna": "Acende sozinha à noite.",
	"facao": "Arma branca. Corta zumbi sem fazer barulho.",
	"pistola": "Semiautomática, 12 no pente. O tiro chama zumbi.",
	"faca": "Rápida e leve. Tira pouco, mas não para de cortar.",
	"taco": "Pesado. Empurra o zumbi para longe.",
	"machado": "Lento e brutal. Derruba até o grandão.",
	"mola": "Peça de arma. Comum.",
	"gatilho": "Peça de arma. Comum.",
	"cano": "Peça de arma. Pouco comum.",
	"cabo": "Peça de arma (cabo de pistola). Pouco comum.",
	"ferrolho": "Peça de arma. Rara.",
	"carregador": "Peça de arma. Rara.",
}

var espacos: Array = []  # null ou {"tipo": String, "qtd": int}


func _init() -> void:
	espacos.resize(ESPACOS)


static func pilha(tipo: String) -> int:
	return int(PILHA.get(tipo, 1))


func conta(tipo: String) -> int:
	var n: int = 0
	for e: Variant in espacos:
		if e and e.tipo == tipo:
			n += int(e.qtd)
	return n


func tem(tipo: String) -> bool:
	return conta(tipo) > 0


## Põe até `qtd`; devolve quanto coube (respeita LIMITE e espaço livre).
func adicionar(tipo: String, qtd: int) -> int:
	var falta: int = mini(qtd, int(LIMITE.get(tipo, 9999)) - conta(tipo))
	var pos: int = 0
	for i in ESPACOS:  # primeiro completa as pilhas
		if falta <= 0:
			break
		var e: Variant = espacos[i]
		if e and e.tipo == tipo and int(e.qtd) < pilha(tipo):
			var n: int = mini(falta, pilha(tipo) - int(e.qtd))
			e.qtd = int(e.qtd) + n
			falta -= n
			pos += n
	for i in ESPACOS:  # depois usa espaço vazio
		if falta <= 0:
			break
		if espacos[i] == null:
			var n: int = mini(falta, pilha(tipo))
			espacos[i] = {"tipo": tipo, "qtd": n}
			falta -= n
			pos += n
	if pos > 0:
		mudou.emit()
	return pos


## Tira até `qtd` (das últimas pilhas para as primeiras); devolve quanto tirou.
func tirar(tipo: String, qtd: int) -> int:
	var falta: int = qtd
	for i in range(ESPACOS - 1, -1, -1):
		if falta <= 0:
			break
		var e: Variant = espacos[i]
		if e and e.tipo == tipo:
			var n: int = mini(falta, int(e.qtd))
			e.qtd = int(e.qtd) - n
			falta -= n
			if int(e.qtd) <= 0:
				espacos[i] = null
	if falta < qtd:
		mudou.emit()
	return qtd - falta


## Deixa o total de `tipo` igual a `n` (usado por quem só conhece o número: a reserva da pistola, comida...).
func definir(tipo: String, n: int) -> void:
	var c: int = conta(tipo)
	if n > c:
		adicionar(tipo, n - c)
	elif n < c:
		tirar(tipo, c - n)


## Esvazia o espaço e devolve o que tinha ({} se vazio ou preso).
func tirar_espaco(i: int) -> Dictionary:
	var e: Variant = espacos[i]
	if e == null or e.tipo in PRESOS:
		return {}
	espacos[i] = null
	mudou.emit()
	return e


## Divide a pilha ao meio num espaço vazio. Devolve se dividiu.
func dividir(i: int) -> bool:
	var e: Variant = espacos[i]
	if e == null or int(e.qtd) < 2:
		return false
	var vazio: int = espacos.find(null)
	if vazio < 0:
		return false
	var metade: int = int(e.qtd) / 2
	e.qtd = int(e.qtd) - metade
	espacos[vazio] = {"tipo": e.tipo, "qtd": metade}
	mudou.emit()
	return true


## Move o espaço `de` para `para`: junta se for o mesmo tipo empilhável, senão troca de lugar.
func mover(de: int, para: int) -> void:
	if de == para:
		return
	var a: Variant = espacos[de]
	var b: Variant = espacos[para]
	if a and b and a.tipo == b.tipo and pilha(a.tipo) > 1:
		var n: int = mini(int(a.qtd), pilha(a.tipo) - int(b.qtd))
		b.qtd = int(b.qtd) + n
		a.qtd = int(a.qtd) - n
		if int(a.qtd) <= 0:
			espacos[de] = null
	else:
		espacos[de] = b
		espacos[para] = a
	mudou.emit()


## Primeiro espaço com esse tipo (-1 se não tem).
func onde(tipo: String) -> int:
	for i in ESPACOS:
		if espacos[i] and espacos[i].tipo == tipo:
			return i
	return -1
