# Esconderijo (14/11, ESTACAO.md): armário, debaixo do beliche/maca, freezer. USAR perto entra (o jogador some, não
# anda, a tela escurece pelas frestas); USAR de novo sai em `saida`. O Paciente Zero não vê nem ouve quem está escondido,
# a não ser que tenha visto entrar (aí ele abre e pega). Cada um aguenta 2 vezes seguidas; na 3ª ele vem checar.
class_name Esconderijo
extends Node3D

const ALCANCE: float = 2.0
const VEZES: int = 2
var tipo: String = "armario"    # armario / beliche / maca / freezer
var saida: Vector3              # local: onde o jogador fica ao sair
var usos: int = 0               # entradas seguidas (zera quando outro esconderijo é usado)


func _ready() -> void:
	add_to_group("esconderijos")


func ponto_saida() -> Vector3:
	return get_parent().to_global(saida) if get_parent() is Node3D else saida


static func perto(arvore: SceneTree, pos: Vector3) -> Esconderijo:
	var melhor: Esconderijo = null
	var dist: float = ALCANCE
	for n: Node in arvore.get_nodes_in_group("esconderijos"):
		var e := n as Esconderijo
		var d: float = Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d < dist:
			dist = d
			melhor = e
	return melhor
