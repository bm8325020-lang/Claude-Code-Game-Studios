# PROTOTYPE - NOT FOR PRODUCTION
# Achievements: small goals with small rewards so a casual player always has something next to aim for.
# The first few are deliberately quick. Pure data + a check function; main.gd feeds the stats and pays out.
class_name Achievements
extends RefCounted

# stat: level | kills | kills_imp | marcos | chests | rarity (best rarity index, 2 = raro) | main_quests | contracts
const DATA: Array[Dictionary] = [
	{"id": "primeiro_passo", "title": "Primeiro Passo", "desc": "Chegue ao nível 2", "stat": "level", "need": 2, "gold": 20},
	{"id": "primeira_caca", "title": "Primeira Caça", "desc": "Derrote 10 inimigos", "stat": "kills", "need": 10, "gold": 30},
	{"id": "bau_aberto", "title": "O Que Tem Aí?", "desc": "Abra 3 baús", "stat": "chests", "need": 3, "gold": 40},
	{"id": "andarilho", "title": "Andarilho", "desc": "Encontre 3 Marcos de Lume", "stat": "marcos", "need": 3, "gold": 40},
	{"id": "historia_5", "title": "Gente do Vale", "desc": "Conclua 5 missões principais", "stat": "main_quests", "need": 5, "gold": 80},
	{"id": "diabretes_25", "title": "Apaga-Brasas", "desc": "Derrote 25 Diabretes", "stat": "kills_imp", "need": 25, "gold": 60},
	{"id": "contratos_5", "title": "Caçador de Aluguel", "desc": "Conclua 5 contratos de caça", "stat": "contracts", "need": 5, "gold": 120},
	{"id": "nivel_10", "title": "Pé-Firme", "desc": "Chegue ao nível 10", "stat": "level", "need": 10, "gold": 100},
	{"id": "raro", "title": "Olho Bom", "desc": "Consiga um item Raro ou melhor", "stat": "rarity", "need": 2, "gold": 80},
	{"id": "cem", "title": "Cem Vitórias", "desc": "Derrote 100 inimigos", "stat": "kills", "need": 100, "gold": 150},
	{"id": "nivel_20", "title": "Guardião do Vale", "desc": "Chegue ao nível 20", "stat": "level", "need": 20, "gold": 250},
	{"id": "lendario", "title": "Sorte de Dragão", "desc": "Consiga um item Lendário", "stat": "rarity", "need": 4, "gold": 300},
]


static func key(id: String) -> String:
	return "conq_" + id


# ids newly reached with these stats (skipping the ones already in `done`)
static func reached(stats: Dictionary, done: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in DATA:
		if not done.call(key(str(a.id))) and int(stats.get(str(a.stat), 0)) >= int(a.need):
			out.append(a)
	return out
