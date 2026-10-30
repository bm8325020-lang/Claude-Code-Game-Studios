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

## [dia, noite] do céu: topo e horizonte
## Fim do mundo: de dia nuvem cinza-marrom e poeira alaranjada no horizonte; de noite quase preto com o horizonte
## avermelhado dos incêndios.
const CEU_TOPO: Array[Color] = [Color(0.27, 0.26, 0.26), Color(0.05, 0.06, 0.09)]
const CEU_HORIZONTE: Array[Color] = [Color(0.62, 0.47, 0.34), Color(0.16, 0.1, 0.09)]


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


var _era_noite: bool = false


func _process(dt: float) -> void:
	tempo = fmod(tempo + dt, DIA + NOITE)
	var agora: bool = e_noite()
	if _era_noite and not agora and multiplayer.is_server():  # amanheceu: quem está vivo ganha XP de sobrevivente
		for j: Node in get_tree().get_nodes_in_group("jogadores"):
			if (j as Jogador).vida > 0:
				(j as Jogador).ganhar("xp", Progresso.XP_NOITE)
	_era_noite = agora
	var n: float = noite()
	if sol:
		sol.light_energy = lerpf(0.95, 0.3, n)  # noite de luar: escura, mas dá para jogar (pedido do dono)
		sol.light_color = Color(1, 0.8, 0.6).lerp(Color(0.55, 0.6, 0.85), n)  # sol abafado pela fumaça
	if ambiente:
		var ceu: Color = CEU_HORIZONTE[0].lerp(CEU_HORIZONTE[1], n)
		ambiente.background_color = ceu
		ambiente.fog_light_color = ceu
		var mat := ambiente.sky.sky_material as ShaderMaterial if ambiente.sky else null
		if mat:
			mat.set_shader_parameter("topo", CEU_TOPO[0].lerp(CEU_TOPO[1], n))
			mat.set_shader_parameter("horizonte", ceu)
		ambiente.ambient_light_color = Color(0.72, 0.66, 0.6).lerp(Color(0.42, 0.47, 0.62), n)
		ambiente.ambient_light_energy = lerpf(0.6, 0.45, n)
		ambiente.fog_density = lerpf(0.012, 0.02, n)


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
