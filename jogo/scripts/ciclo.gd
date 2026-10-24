# Dia e noite (mecânica 9): dia de 8 min, noite de 5 min (anotado com o dono), com 30 s de anoitecer e de
# amanhecer. Escurece o céu, o sol e a névoa; à noite os zumbis ficam mais fortes (Zumbi lê `forca_noite()`).
# Quem manda no horário é o servidor (ou o aparelho jogando sozinho); os outros recebem o tempo 1x por segundo
# e andam o relógio sozinhos entre uma atualização e outra.
class_name Ciclo
extends Node

const DIA: float = 480.0
const NOITE: float = 300.0
const TRANSICAO: float = 30.0
## provisório para testar: a partida começa com a noite chegando em 1 min 30 s
const INICIO: float = DIA - 90.0

## segundos desde o começo do dia (0 .. DIA + NOITE)
var tempo: float = INICIO
var sol: DirectionalLight3D
var ambiente: Environment

const CEU_DIA := Color(0.62, 0.66, 0.68)
const CEU_NOITE := Color(0.05, 0.06, 0.09)


func _ready() -> void:
	add_to_group("ciclo")
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:tempo"))
	cfg.property_set_replication_mode(NodePath(".:tempo"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_interval = 1.0
	sync.replication_config = cfg
	add_child(sync)


func _process(dt: float) -> void:
	tempo = fmod(tempo + dt, DIA + NOITE)
	var n: float = noite()
	if sol:
		sol.light_energy = lerpf(1.2, 0.04, n)
		sol.light_color = Color(1, 0.96, 0.9).lerp(Color(0.55, 0.65, 1.0), n)
	if ambiente:
		var ceu: Color = CEU_DIA.lerp(CEU_NOITE, n)
		ambiente.background_color = ceu
		ambiente.fog_light_color = ceu
		ambiente.ambient_light_color = Color(0.7, 0.72, 0.75).lerp(Color(0.35, 0.42, 0.6), n)
		ambiente.ambient_light_energy = lerpf(0.6, 0.12, n)
		ambiente.fog_density = lerpf(0.008, 0.03, n)


## 0 = dia claro, 1 = noite fechada (sobe no anoitecer e desce no amanhecer).
func noite() -> float:
	if tempo < DIA - TRANSICAO:
		return 0.0
	if tempo < DIA:
		return (tempo - (DIA - TRANSICAO)) / TRANSICAO
	if tempo < DIA + NOITE - TRANSICAO:
		return 1.0
	return 1.0 - (tempo - (DIA + NOITE - TRANSICAO)) / TRANSICAO


func e_noite() -> bool:
	return tempo >= DIA


## Segundos até a próxima virada (noite chegando ou dia chegando).
func falta() -> float:
	return (DIA - tempo) if tempo < DIA else (DIA + NOITE - tempo)


## Multiplicador da força dos zumbis agora (1 de dia; MAIS_FORTE com a noite fechada).
static func forca_noite(arvore: SceneTree, mais_forte: float) -> float:
	var c := arvore.get_first_node_in_group("ciclo") as Ciclo
	return lerpf(1.0, mais_forte, c.noite()) if c else 1.0
