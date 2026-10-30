# Grupos (mecânica 9 do loop): convite por nick, aceitar/recusar, até MAX no grupo, sair. Só dados: quem chama é o
# servidor (main.gd), que manda o resultado para todos. Sem fogo amigo entre membros (`mesmo`), para quando o PvP vier.
class_name Grupos
extends RefCounted

const MAX: int = 4
const CONVITE_T: float = 30.0  # s para aceitar

## id do jogador (peer) -> id do grupo (o peer de quem criou)
var de: Dictionary = {}
## convidado -> [quem convidou, tempo restante]
var convites: Dictionary = {}


func membros(g: int) -> Array:
	return de.keys().filter(func(p: int) -> bool: return de[p] == g)


## Sem fogo amigo: true se os dois estão no mesmo grupo.
func mesmo(a: int, b: int) -> bool:
	return a != b and de.has(a) and de.get(a) == de.get(b)


## Convite: devolve "" se foi, ou o motivo de não ir.
func convidar(quem: int, para: int) -> String:
	if quem == para:
		return "Não dá para convidar você mesmo"
	if de.has(para):
		return "Já está num grupo"
	if de.has(quem) and membros(de[quem]).size() >= MAX:
		return "Grupo cheio (%d)" % MAX
	convites[para] = [quem, CONVITE_T]
	return ""


## Resposta do convidado. Devolve o id do grupo (0 = não entrou).
func responder(para: int, aceita: bool) -> int:
	if not convites.has(para):
		return 0
	var quem: int = convites[para][0]
	convites.erase(para)
	if not aceita or de.has(para):
		return 0
	var g: int = de.get(quem, quem)
	if membros(g).size() >= MAX:
		return 0
	de[quem] = g
	de[para] = g
	return g


## Sai do grupo (ou caiu do jogo). Quem fica sozinho também sai.
func sair(p: int) -> void:
	if not de.has(p):
		convites.erase(p)
		return
	var g: int = de[p]
	de.erase(p)
	convites.erase(p)
	var resto: Array = membros(g)
	if resto.size() == 1:
		de.erase(resto[0])


## Convites vencem sozinhos.
func passa(dt: float) -> void:
	for p: int in convites.keys():
		convites[p][1] -= dt
		if convites[p][1] <= 0.0:
			convites.erase(p)


## Resgate (prompt 10): quantos do grupo, vivos, estão a até RESGATE_DIST do caído. `vivos` = peer -> posição.
const RESGATE_DIST: float = 75.0
const RESGATE_MIN: int = 2


func pode_resgate(caido: int, pos: Vector3, vivos: Dictionary) -> bool:
	if not de.has(caido):
		return false
	var n: int = 0
	for p: int in vivos:
		if p != caido and mesmo(p, caido) and (vivos[p] as Vector3).distance_to(pos) <= RESGATE_DIST:
			n += 1
	return n >= RESGATE_MIN


## Quantos zumbis a raid solta: mais com mochila valiosa e com mais zumbis mortos (sem nível: só o registro).
static func zumbis_raid(valor: int, abates: int) -> int:
	return clampi(4 + valor / 200 + abates / 15, 4, 12)
