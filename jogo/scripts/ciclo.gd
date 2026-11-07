# Dia e noite (mecânica 9): dia de 8 min, noite de 5 min (anotado com o dono), com 30 s de anoitecer e de
# amanhecer. Escurece o céu, o sol e a névoa; à noite os zumbis ficam mais fortes (Zumbi lê `forca_noite()`).
# Quem manda no horário é o servidor (ou o aparelho jogando sozinho); os outros recebem o tempo 1x por segundo
# e andam o relógio sozinhos entre uma atualização e outra.
class_name Ciclo
extends Node

const DIA: float = 420.0   # 06/11 terror: dia mais curto, noite mais longa
const NOITE: float = 360.0
const TRANSICAO: float = 30.0
## provisório para testar: a partida começa com a noite chegando em 1 min 30 s
const INICIO: float = DIA - 90.0

## segundos desde o começo do dia (0 .. DIA + NOITE)
var tempo: float = INICIO
var sol: DirectionalLight3D
var ambiente: Environment
## clima do dia (Clima.TIPOS): o servidor sorteia ao amanhecer e manda junto com o tempo
var clima: String = "limpo"
var dia: int = 0
var _clima: Clima
var _rng_clima := RandomNumberGenerator.new()

## [dia, noite] do céu: topo e horizonte
## Fim do mundo: de dia nuvem cinza-marrom e poeira alaranjada no horizonte; de noite quase preto com o horizonte
## avermelhado dos incêndios.
# 31/10 (dono: "não gosto desse céu, pegada feia"): saiu o poeirão laranja; dia nublado frio, cinza-azulado, e noite azul-escura
# 07/11 (E1 cara nova, dono: "tirar a cara de morto e genérico"): paleta própria — ferrugem/âmbar das luzes e do
# horizonte em brasa contra o azul-petróleo das sombras e da noite (nada de cinza neutro)
const CEU_TOPO: Array[Color] = [Color(0.3, 0.37, 0.41), Color(0.04, 0.09, 0.12)]
const CEU_HORIZONTE: Array[Color] = [Color(0.54, 0.53, 0.5), Color(0.1, 0.19, 0.21)]
const SOL_COR: Array[Color] = [Color(1.0, 0.8, 0.58), Color(0.5, 0.72, 0.82)]  # sol âmbar abafado; luar petróleo
const AMBIENTE_COR: Array[Color] = [Color(0.52, 0.6, 0.64), Color(0.34, 0.5, 0.56)]  # sombra fria (petróleo)


func _ready() -> void:
	add_to_group("ciclo")
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:tempo"))
	cfg.property_set_replication_mode(NodePath(".:tempo"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	cfg.add_property(NodePath(".:clima"))
	cfg.property_set_replication_mode(NodePath(".:clima"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_rng_clima.randomize()
	if not Rede.servidor_sem_tela:
		_clima = Clima.new()
		_clima.name = "Clima"
		add_child(_clima)
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
	if _era_noite and not agora:
		dia += 1  # 07/11: conta os dias (o comerciante andarilho muda de lugar a cada amanhecer)
	if _era_noite and not agora and multiplayer.is_server():  # amanheceu: quem está vivo ganha XP de sobrevivente
		for j: Node in get_tree().get_nodes_in_group("jogadores"):
			if (j as Jogador).vida > 0:
				(j as Jogador).ganhar("xp", Progresso.XP_NOITE)
	if _era_noite and not agora and multiplayer.is_server():
		clima = Clima.sorteia(_rng_clima)
	_era_noite = agora
	var n: float = noite()
	var c: Array = Clima.TIPOS.get(clima, Clima.TIPOS.limpo)
	var flash: float = 0.0
	if _clima:
		_clima.passa(clima, dt)
		flash = _clima.flash
	if sol:
		sol.light_energy = lerpf(0.62, 0.32, n) * float(c[3]) + flash * 2.5  # 06/11 terror: noite escura (a lanterna manda)  # noite de luar: escura, mas dá para jogar (pedido do dono)
		sol.light_color = SOL_COR[0].lerp(SOL_COR[1], n)
	if ambiente:
		var ceu: Color = CEU_HORIZONTE[0].lerp(CEU_HORIZONTE[1], n)
		ambiente.background_color = ceu
		ambiente.fog_light_color = ceu.lerp(Color(0.85, 0.87, 0.9), 0.6) if clima == "nevasca" else ceu  # nevasca: névoa branca
		if clima == "neblina_vermelha":
			ambiente.fog_light_color = ceu.lerp(Color(0.75, 0.12, 0.08), 0.75)
		var mat := ambiente.sky.sky_material as ShaderMaterial if ambiente.sky else null
		if mat:
			mat.set_shader_parameter("topo", CEU_TOPO[0].lerp(CEU_TOPO[1], n))
			mat.set_shader_parameter("horizonte", ceu)
			mat.set_shader_parameter("brasa_forca", lerpf(0.3, 0.18, n))  # de noite o brilho dos incêndios fica mais vermelho e baixo
		ambiente.ambient_light_color = AMBIENTE_COR[0].lerp(AMBIENTE_COR[1], n)
		ambiente.ambient_light_energy = lerpf(0.4, 0.42, n)  # 06/11: dia escurecido (dono: "muito claro"); a noite segue jogável
		# 06/11 (dono: "bastante atmosfera"): névoa mais grossa e cerração rente ao chão
		ambiente.fog_density = lerpf(0.02, 0.028, n) * float(c[2])  # a névoa fecha a visão
		ambiente.fog_height = 3.0
		ambiente.fog_height_density = lerpf(0.06, 0.12, n)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.y < -10.0:  # porão (Porao, 40 m abaixo): sem névoa de altura (virava parede azul)
			ambiente.fog_height_density = 0.0
			ambiente.fog_density = 0.06  # pó no ar, a lanterna corta


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


## Quanto é noite agora (0 dia, 1 noite fechada); sem ciclo na cena, 0.
static func noite_de(arvore: SceneTree) -> float:
	var c := arvore.get_first_node_in_group("ciclo") as Ciclo
	return c.noite() if c else 0.0


## Multiplicador da força dos zumbis agora (1 de dia; MAIS_FORTE com a noite fechada).
static func forca_noite(arvore: SceneTree, mais_forte: float) -> float:
	var c := arvore.get_first_node_in_group("ciclo") as Ciclo
	if c == null:
		return 1.0
	var f: float = lerpf(1.0, mais_forte, c.noite())
	if c.clima == "neblina_vermelha" and mais_forte > 1.0:
		f = lerpf(f, f * 1.25, c.noite())  # noite de neblina vermelha: os mortos ainda mais fortes
	return f
