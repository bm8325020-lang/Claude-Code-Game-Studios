# Salas de PvP: só dados, quem chama é o servidor (main.gd). Sala pública aparece na lista; privada só entra com o
# código. O dono começa a partida (com MIN_JOGADORES ou mais); vale abate de jogador da mesma sala até o tempo
# acabar; no fim fica o placar por FIM_T segundos e a sala volta a esperar. Quem está numa sala só vê (e só acerta)
# quem está na mesma sala.
class_name Salas
extends RefCounted

const MIN_JOGADORES: int = 2
const LIMITES: Array[int] = [2, 4, 8, 12, 16]
const MINUTOS: Array[int] = [5, 10, 15]
const RENASCE_T: float = 4.0
const FIM_T: float = 15.0
const LETRAS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # sem I/O/0/1 (confundem)

## código -> {"nome", "publica", "limite", "tempo" (s de partida), "dono" (peer), "jogadores": Array[int],
## "estado": "espera"/"jogando"/"fim", "t": s que faltam (jogando/fim), "placar": nick -> [abates, mortes]}
var salas: Dictionary = {}
## peer -> código
var de: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(semente: int = 0) -> void:
	if semente != 0:
		_rng.seed = semente
	else:
		_rng.randomize()


## Cria e já entra. Devolve o código ("" se não deu).
func criar(peer: int, nome: String, publica: bool, limite: int, minutos: int) -> String:
	sair(peer)
	var cod: String = ""
	while cod == "" or salas.has(cod):
		cod = ""
		for i in 4:
			cod += LETRAS[_rng.randi() % LETRAS.length()]
	salas[cod] = {"nome": nome.strip_edges().left(24), "publica": publica, "limite": clampi(limite, 2, 16),
		"tempo": float(clampi(minutos, 1, 30) * 60), "dono": peer, "jogadores": [peer], "estado": "espera",
		"t": 0.0, "placar": {}}
	de[peer] = cod
	return cod


## Entra pelo código. Devolve "" se entrou, ou o motivo.
func entrar(peer: int, cod: String) -> String:
	cod = cod.strip_edges().to_upper()
	if not salas.has(cod):
		return "Sala não encontrada"
	var s: Dictionary = salas[cod]
	if s.jogadores.size() >= s.limite:
		return "Sala cheia"
	sair(peer)
	s.jogadores.append(peer)
	de[peer] = cod
	return ""


## Sai da sala (se for o dono, passa para o próximo; vazia, some).
func sair(peer: int) -> void:
	if not de.has(peer):
		return
	var cod: String = de[peer]
	de.erase(peer)
	var s: Dictionary = salas[cod]
	s.jogadores.erase(peer)
	if s.jogadores.is_empty():
		salas.erase(cod)
	elif s.dono == peer:
		s.dono = s.jogadores[0]


func sala_de(peer: int) -> String:
	return de.get(peer, "")


## Dois jogadores se veem: os dois fora de sala, ou na mesma sala.
func mesma(a: int, b: int) -> bool:
	return sala_de(a) == sala_de(b)


## Só o dono começa, com MIN_JOGADORES. Devolve "" ou o motivo.
func comecar(peer: int) -> String:
	var cod: String = sala_de(peer)
	if cod == "":
		return "Você não está numa sala"
	var s: Dictionary = salas[cod]
	if s.dono != peer:
		return "Só o dono da sala começa"
	if s.estado == "jogando":
		return "A partida já começou"
	if s.jogadores.size() < MIN_JOGADORES:
		return "Precisa de %d jogadores" % MIN_JOGADORES
	s.estado = "jogando"
	s.t = s.tempo
	s.placar = {}
	return ""


## Vale o tiro/golpe de `a` em `b`? (mesma sala, partida rolando)
func vale(a: int, b: int) -> bool:
	var cod: String = sala_de(a)
	return cod != "" and a != b and cod == sala_de(b) and salas[cod].estado == "jogando"


## `matador` derrubou `vitima` (nicks). Conta no placar da sala de quem matou.
func abate(cod: String, matador: String, vitima: String) -> void:
	var p: Dictionary = salas[cod].placar
	if not p.has(matador):
		p[matador] = [0, 0]
	if not p.has(vitima):
		p[vitima] = [0, 0]
	p[matador][0] += 1
	p[vitima][1] += 1


## Anda o relógio. Eventos: ["fim", código] (acabou o tempo), ["espera", código] (placar saiu, volta a esperar).
func passa(dt: float) -> Array:
	var ev: Array = []
	for cod: String in salas:
		var s: Dictionary = salas[cod]
		if s.estado == "espera":
			continue
		s.t -= dt
		if s.t > 0.0:
			continue
		if s.estado == "jogando":
			s.estado = "fim"
			s.t = FIM_T
			ev.append(["fim", cod])
		else:
			s.estado = "espera"
			ev.append(["espera", cod])
	return ev


## Para a tela: as públicas (não cheias) [{código, nome, n, limite, estado, minutos}].
func lista_publica() -> Array:
	var r: Array = []
	for cod: String in salas:
		var s: Dictionary = salas[cod]
		if s.publica and s.jogadores.size() < s.limite:
			r.append({"codigo": cod, "nome": s.nome, "n": s.jogadores.size(), "limite": s.limite, "estado": s.estado,
				"minutos": int(s.tempo / 60.0)})
	return r


## Placar ordenado por abates: [[nick, abates, mortes], ...]
func placar(cod: String) -> Array:
	var r: Array = []
	for n: String in salas[cod].placar:
		r.append([n, salas[cod].placar[n][0], salas[cod].placar[n][1]])
	r.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))
	return r
