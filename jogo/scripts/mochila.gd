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
const PILHA: Dictionary = {"molotov": 3, "sinalizador": 3, "pilha": 6, "bandagem": 10, "municao": 96, "cartucho": 48, "municao_fuzil": 120, "comida": 10, "agua": 10, "antibiotico": 6, "mola": 20, "gatilho": 20, "cano": 20, "cabo": 20,
	"ferrolho": 20, "carregador": 20, "receita_pistola": 10, "receita_smg": 10, "chave": 10, "bomba": 4, "fita": 5, "peca_radio": 3}
## quanto dá para carregar no total (07/11, dono: limites dobrados; arma continua 1 de cada)
const LIMITE: Dictionary = {"molotov": 4, "sinalizador": 6, "pilha": 12, "bandagem": 20, "silenciador": 1, "livro": 1, "municao": 192, "cartucho": 96, "municao_fuzil": 240, "espingarda": 1, "fuzil": 1, "sniper": 1, "comida": 10, "agua": 10, "antibiotico": 6, "lanterna": 1, "facao": 1, "pistola": 1,
	"faca": 1, "taco": 1, "machado": 1, "mola": 60, "gatilho": 60, "cano": 60, "cabo": 60, "ferrolho": 60, "carregador": 60, "receita_pistola": 10, "smg": 1, "receita_smg": 10, "chave": 10, "taco_pregos": 1, "bomba": 4, "fita": 5, "peca_radio": 3, "diario": 1}
## não dá para largar (são a mão do jogador por enquanto)
const PRESOS: Array[String] = ["facao", "pistola"]
const NOMES: Dictionary = {"chave": "Chave", "municao": "Munição", "comida": "Lata de comida", "agua": "Garrafa de água", "antibiotico": "Antibiótico",
	"livro": "Livro de habilidades", "lanterna": "Lanterna", "facao": "Facão", "taco_pregos": "Taco com pregos", "pistola": "Pistola 9 mm", "faca": "Faca de açougueiro",
	"taco": "Taco de beisebol", "machado": "Machado de bombeiro", "mola": "Mola", "gatilho": "Gatilho", "cano": "Cano",
	"cabo": "Empunhadura", "ferrolho": "Ferrolho", "carregador": "Carregador", "receita_pistola": "Receita: Pistola 9 mm",
	"smg": "Submetralhadora MP5", "receita_smg": "Receita: Submetralhadora", "espingarda": "Espingarda Remington",
	"molotov": "Coquetel molotov", "sinalizador": "Sinalizador", "pilha": "Pilha", "bandagem": "Bandagem", "silenciador": "Silenciador", "fuzil": "Fuzil AK-74", "sniper": "Rifle de precisão Mosin", "cartucho": "Cartuchos 12", "municao_fuzil": "Munição de fuzil", "bomba": "Bomba (C4)", "fita": "Fita da Dra. Okafor",
	"peca_radio": "Peça de rádio militar", "diario": "Diário da Mia"}
const TEXTOS: Dictionary = {
	"municao": "Balas 9 mm para a pistola.",
	"fita": "Fita cassete gravada pela Dra. Ruth Okafor: a prova do que a Halverson Agro fez. Junte as 5.",
	"peca_radio": "Peça do rádio militar do Sargento Mercer. Com 3, dá para chamar o Exército do alto da torre.",
	"diario": "Diário da Mia, sua irmã. A última página fala da quarentena.",
	"bomba": "Explosivo plástico com relógio. USAR perto do portão blindado da quarentena: explode em %d s (saia de perto)." % int(Jogador.BOMBA_T),
	"taco_pregos": "Taco de beisebol com pregos e arame farpado. Lento, mas derruba.",
	"chave": "Chave velha. Abre um armário de metal trancado (o bilhete perto dele diz onde ela estava).",
	"comida": "Conserva sem rótulo. Enche a fome.",
	"agua": "Água de garrafa. Mata a sede.",
	"antibiotico": "Segura a infecção da mordida: tira %d%% e para de subir." % Jogador.CURA_ANTIBIOTICO,
	"livro": "Abra para gastar os pontos de nível.",
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
	"receita_pistola": "Ensina a fazer a pistola na bancada (arma simples). USAR para aprender.",
	"smg": "9 mm, 30 no pente. Semi ou automática (botão MODO). Rajada chama zumbi de longe.",
	"receita_smg": "Ensina a fazer a submetralhadora na bancada (arma mediana). USAR para aprender.",
	"espingarda": "Calibre 12, 6 no tubo. Oito chumbos por tiro: de perto derruba qualquer um. Recarga lenta.",
	"fuzil": "Munição de fuzil, 30 no pente. Semi ou automático (botão MODO). Alcance longo, barulho alto.",
	"sniper": "Munição de fuzil, 5 tiros. Mirar abre a luneta. Um tiro na cabeça de longe resolve; o estampido chama a rua inteira.",
	"cartucho": "Cartuchos calibre 12 para a espingarda.",
	"molotov": "Garrafa com gasolina e pano. USAR: joga à frente e vira fogo que queima os zumbis por 12 s (cuidado com você).",
	"sinalizador": "Sinalizador vermelho. USAR: joga à frente; a luz e o barulho chamam os zumbis por 25 s.",
	"pilha": "Pilha para a lanterna. USAR: troca a pilha (a lanterna apaga quando acaba).",
	"bandagem": "Faixa de pano limpo. USAR: cura %d de vida na hora." % Jogador.CURA_BANDAGEM,
	"silenciador": "Na mochila, abafa o tiro da pistola, da submetralhadora e do fuzil: o zumbi só ouve bem de perto.",
	"municao_fuzil": "Balas de fuzil (AK-74 e Mosin).",
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
