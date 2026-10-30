# Facções (prompt 12): só dados, quem chama é o servidor (main.gd). Criar = MIN_CRIAR+ jogadores dentro de uma casa do bairro
# seguram o domínio por DOMINAR_T (menos que MIN_CRIAR dentro pausa; ninguém dentro falha). Facção que já existe redomina com 1
# membro em REDOMINAR_T. Uma facção = uma casa. Membros por nick (vai para a conta no prompt 16).
class_name Faccoes
extends RefCounted

const MIN_CRIAR: int = 1  # pedido do dono: 1 jogador já cria (plano era 3)
const DOMINAR_T: float = 60.0  # dono: diminuir por enquanto (plano: 5–7 min)
const REDOMINAR_T: float = 30.0
const LIMITE: int = 10
## Manutenção (prompt 13): a cada MANUT_DIAS dias do jogo a casa cobra MANUT_CUSTO do fundo da facção (só conta com
## casa); sem dinheiro no fundo perde a casa e o que tinha no baú. Avisa nos últimos AVISO_DIAS dias. Provisório.
const DIA: float = Ciclo.DIA + Ciclo.NOITE
const MANUT_DIAS: int = 7
const MANUT_CUSTO: int = 20000
const AVISO_DIAS: int = 3

## nome -> {"membros": Array[String] (nicks), "casa": String ("" = sem casa), "fundo": int, "prazo": s até a
## próxima cobrança, "guardado": [{tipo, qtd}] (o baú quando a facção está sem casa)}
var faccoes: Dictionary = {}
## casa -> {"faccao": String ("" = criando uma nova), "t": s que faltam, "total": s, "quem": nick de quem começou}
var tentativas: Dictionary = {}


func faccao_de(nick: String) -> String:
	for n: String in faccoes:
		if nick in faccoes[n].membros:
			return n
	return ""


func dona(casa: String) -> String:
	for n: String in faccoes:
		if faccoes[n].casa == casa:
			return n
	return ""


## Começa a dominar `casa`; `dentro` = nicks dentro dela agora. Devolve "" se começou, ou o motivo.
func comecar(casa: String, nick: String, dentro: Array) -> String:
	if tentativas.has(casa):
		return "Já estão dominando esta casa"
	var f: String = faccao_de(nick)
	if f != "" and dona(casa) == f:
		return "A casa já é da sua facção"
	if f != "" and faccoes[f].casa != "":
		return "Sua facção já tem uma casa"
	if f == "" and dentro.size() < MIN_CRIAR:
		return "Precisa de %d dentro da casa para criar a facção" % MIN_CRIAR
	var t: float = REDOMINAR_T if f != "" else DOMINAR_T
	tentativas[casa] = {"faccao": f, "t": t, "total": t, "quem": nick}
	return ""


## Quantos contam dentro da casa para uma tentativa (facção existente: só os membros dela).
func _contam(tent: Dictionary, dentro: Array) -> int:
	if tent.faccao == "":
		return dentro.filter(func(n: String) -> bool: return faccao_de(n) == "").size()
	return dentro.filter(func(n: String) -> bool: return n in faccoes[tent.faccao].membros).size()


## Anda o relógio. `dentro` = casa -> nicks vivos dentro. Devolve eventos: ["sucesso", casa, facção] / ["falha", casa].
func passa(dt: float, dentro: Dictionary) -> Array:
	var ev: Array = []
	for casa: String in tentativas.keys():
		var tent: Dictionary = tentativas[casa]
		var quem: Array = dentro.get(casa, [])
		var n: int = _contam(tent, quem)
		if n == 0:
			tentativas.erase(casa)
			ev.append(["falha", casa])
			continue
		if n < (MIN_CRIAR if tent.faccao == "" else 1):
			continue  # pausa
		tent.t -= dt
		if tent.t > 0.0:
			continue
		tentativas.erase(casa)
		var nome: String = tent.faccao
		var antiga: String = dona(casa)
		if antiga != "":
			faccoes[antiga].casa = ""  # perde a área, não a facção
		if nome == "":
			nome = "Facção de %s" % tent.quem
			var membros: Array = quem.filter(func(x: String) -> bool: return faccao_de(x) == "").slice(0, LIMITE)
			faccoes[nome] = {"membros": membros, "casa": casa, "fundo": 0, "prazo": MANUT_DIAS * DIA, "guardado": []}
		else:
			faccoes[nome].casa = casa
			faccoes[nome].prazo = MANUT_DIAS * DIA
		ev.append(["sucesso", casa, nome])
	return ev


## Põe `nick` na facção de `quem` (só membros adicionam). Devolve "" ou o motivo.
func adicionar(quem: String, nick: String) -> String:
	var f: String = faccao_de(quem)
	if f == "":
		return "Você não tem facção"
	if faccao_de(nick) != "":
		return "Já está numa facção"
	if faccoes[f].membros.size() >= LIMITE:
		return "Facção cheia (%d)" % LIMITE
	faccoes[f].membros.append(nick)
	return ""


## Membro põe dinheiro no fundo da facção.
func depositar(nick: String, valor: int) -> bool:
	var f: String = faccao_de(nick)
	if f == "" or valor <= 0:
		return false
	faccoes[f].fundo += valor
	return true


## Relógio da manutenção. Eventos: ["aviso", facção, dias que faltam] (uma vez por dia, perto do prazo e sem fundo),
## ["pagou", facção], ["perdeu", facção, casa].
func passa_manutencao(dt: float) -> Array:
	var ev: Array = []
	for n: String in faccoes:
		var d: Dictionary = faccoes[n]
		if d.casa == "":
			continue
		var antes: int = ceili(d.prazo / DIA)
		d.prazo -= dt
		var dias: int = ceili(d.prazo / DIA)
		if d.prazo <= 0.0:
			if d.fundo >= MANUT_CUSTO:
				d.fundo -= MANUT_CUSTO
				d.prazo += MANUT_DIAS * DIA
				ev.append(["pagou", n])
			else:
				ev.append(["perdeu", n, d.casa])
				d.casa = ""
		elif dias < antes and dias <= AVISO_DIAS and d.fundo < MANUT_CUSTO:
			ev.append(["aviso", n, dias])
	return ev


## Todos os membros saíram do servidor: a casa fica livre; o baú vai com a facção (`itens` = o que tinha nele).
func liberar(nome: String, itens: Array) -> String:
	var casa: String = faccoes[nome].casa
	faccoes[nome].casa = ""
	faccoes[nome].guardado.append_array(itens)
	return casa
