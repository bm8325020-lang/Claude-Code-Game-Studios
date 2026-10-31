# Progressão (plano aprovado pelo dono, 30/10: "muito difícil, com sentimento de progressão"). XP por zumbi morto (raid e
# chefe valem mais) e por noite sobrevivida; a cada nível 1 ponto para uma de 4 habilidades (até NIVEL_HAB cada):
# Vigor (+vida), Fôlego (corre mais, fome e sede descem mais devagar), Pontaria (menos espalho e mais dano com arma de
# fogo) e Força (mais dano com arma branca). Fica salvo no aparelho, por nome. Só dados: testável sem cena.
class_name Progresso
extends RefCounted

const XP_ZUMBI: int = 10
const XP_RAID: int = 25
const XP_CHEFE: int = 150
const XP_NOITE: int = 60  # sobreviveu a uma noite inteira
const NIVEL_HAB: int = 5
const HABS: Array[String] = ["vigor", "folego", "pontaria", "forca"]
const NOMES: Dictionary = {"vigor": "VIGOR", "folego": "FÔLEGO", "pontaria": "PONTARIA", "forca": "FORÇA"}
const TEXTOS: Dictionary = {"vigor": "+8 de vida por nível", "folego": "+5% de corrida, fome e sede 6% mais devagar",
	"pontaria": "-10% de espalho, +6% de dano com arma de fogo", "forca": "+8% de dano com arma branca"}

var xp: int = 0
var nivel: int = 1
var pontos: int = 0
var hab: Dictionary = {"vigor": 0, "folego": 0, "pontaria": 0, "forca": 0}


## XP que falta do nível `n` para o próximo (sobe cada vez mais: os primeiros vêm rápido, depois demora).
static func xp_para(n: int) -> int:
	return int(80.0 * pow(n, 1.45))


## Soma XP e devolve quantos níveis subiu.
func ganha(qtd: int) -> int:
	xp += qtd
	var subiu: int = 0
	while xp >= xp_para(nivel):
		xp -= xp_para(nivel)
		nivel += 1
		pontos += 1
		subiu += 1
	return subiu


func gasta(h: String) -> bool:
	if pontos <= 0 or not hab.has(h) or int(hab[h]) >= NIVEL_HAB:
		return false
	hab[h] = int(hab[h]) + 1
	pontos -= 1
	return true


var dinheiro: int = 0


func salva(caminho: String) -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "xp", xp)
	cf.set_value("p", "nivel", nivel)
	cf.set_value("p", "pontos", pontos)
	cf.set_value("p", "hab", hab)
	cf.set_value("p", "dinheiro", dinheiro)
	cf.save(caminho)


func carrega(caminho: String) -> void:
	var cf := ConfigFile.new()
	if cf.load(caminho) != OK:
		return
	xp = int(cf.get_value("p", "xp", 0))
	nivel = int(cf.get_value("p", "nivel", 1))
	pontos = int(cf.get_value("p", "pontos", 0))
	dinheiro = int(cf.get_value("p", "dinheiro", 0))
	var h: Dictionary = cf.get_value("p", "hab", {})
	for k: String in HABS:
		hab[k] = clampi(int(h.get(k, 0)), 0, NIVEL_HAB)


static func arquivo(nick: String) -> String:
	return "user://progresso_%s.cfg" % nick.validate_filename()
