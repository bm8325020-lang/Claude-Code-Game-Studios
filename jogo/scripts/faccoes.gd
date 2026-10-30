# Facções (prompt 12): só dados, quem chama é o servidor (main.gd). Criar = MIN_CRIAR+ jogadores dentro de uma casa do bairro
# seguram o domínio por DOMINAR_T (menos que MIN_CRIAR dentro pausa; ninguém dentro falha). Facção que já existe redomina com 1
# membro em REDOMINAR_T. Uma facção = uma casa. Membros por nick (vai para a conta no prompt 16).
class_name Faccoes
extends RefCounted

const MIN_CRIAR: int = 1  # pedido do dono: 1 jogador já cria (plano era 3)
const DOMINAR_T: float = 360.0
const REDOMINAR_T: float = 180.0
const LIMITE: int = 10

## nome -> {"membros": Array[String] (nicks), "casa": String ("" = sem casa)}
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
			faccoes[nome] = {"membros": membros, "casa": casa}
		else:
			faccoes[nome].casa = casa
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
