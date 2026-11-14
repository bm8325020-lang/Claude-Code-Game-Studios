# Porta do bunker (14/11, ESTACAO.md etapa 1): a saída do jogo. Com os cartões (verde, azul e amarelo; o vermelho entra na
# etapa 2) e USAR perto, o servidor liga a abertura: CONTAGEM s de alarme, o Paciente Zero em fúria e o barulho chama
# tudo. Quando abre, quem entra na área da porta foge (Jogador "fugiu" -> tela de fim).
class_name Bunker
extends Node3D

const CARTOES: Array[String] = ["verde", "azul", "amarelo"]
const CONTAGEM: float = 90.0
const ALCANCE: float = 2.6
var contagem: float = -1.0    # servidor: s até abrir (< 0 = parada)
var aberto: bool = false
var _aviso_t: float = 0.0
var _disco: MeshInstance3D
var _luz: OmniLight3D


func _ready() -> void:
	add_to_group("bunker")
	var a := Area3D.new()  # quem pisa aqui com a porta aberta desce no túnel
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.4, 2.0, 1.6)
	cs.shape = b
	cs.position = Vector3(0, 1.0, 0.9)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_entrou)
	set_process(false)
	if Rede.servidor_sem_tela:
		return
	_disco = MeshInstance3D.new()  # porta redonda de aço, encostada na parede
	var c := CylinderMesh.new()
	c.top_radius = 1.2
	c.bottom_radius = 1.2
	c.height = 0.3
	c.radial_segments = 24
	c.rings = 1
	_disco.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.47, 0.5)
	m.metallic = 0.6
	m.roughness = 0.5
	_disco.material_override = m
	_disco.rotation.x = PI * 0.5
	_disco.position = Vector3(0, 1.3, 0.15)
	_disco.set_meta("sem_estilo", true)
	add_child(_disco)
	for k in CARTOES.size():  # uma luz por cartão no leitor do lado
		var l := MeshInstance3D.new()
		var q := BoxMesh.new()
		q.size = Vector3(0.12, 0.12, 0.05)
		l.mesh = q
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Estacao.CORES[CARTOES[k]]
		lm.emission_enabled = true
		lm.emission = Estacao.CORES[CARTOES[k]]
		lm.emission_energy_multiplier = 1.5
		l.material_override = lm
		l.position = Vector3(1.7, 1.0 + k * 0.2, 0.05)
		add_child(l)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.15, 0.1)
	_luz.light_energy = 0.0
	_luz.omni_range = 9.0
	_luz.position = Vector3(0, 2.8, 1.0)
	add_child(_luz)


## Jogador perto com todos os cartões: liga a abertura (servidor).
func comeca() -> void:
	if contagem >= 0.0 or aberto:
		return
	contagem = CONTAGEM
	set_process(true)
	_alarme.rpc()
	var pz := get_tree().get_first_node_in_group("paciente_zero")
	if pz:
		pz.furia = true
	Zumbi.barulho(get_tree(), global_position, 250.0)  # o alarme chama tudo
	var principal := get_tree().get_first_node_in_group("principal")
	if principal:
		principal.aviso_todos.rpc("ALARME DE CONTENÇÃO: A PORTA DO BUNKER ABRE EM %d s. AGUENTE!" % int(CONTAGEM))


func _process(dt: float) -> void:
	if _luz:
		_luz.light_energy = 2.0 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)) if contagem >= 0.0 else 0.0
	if contagem < 0.0 or not (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		return
	contagem -= dt
	_aviso_t -= dt
	if _aviso_t <= 0.0 and contagem > 1.0:
		_aviso_t = 15.0
		var principal := get_tree().get_first_node_in_group("principal")
		if principal:
			principal.aviso_todos.rpc("BUNKER ABRE EM %d s" % int(contagem))
	if contagem <= 0.0:
		contagem = -1.0
		_abre.rpc()


@rpc("authority", "call_local", "reliable")
func _alarme() -> void:
	contagem = maxf(contagem, 0.0)
	set_process(true)


@rpc("authority", "call_local", "reliable")
func _abre() -> void:
	aberto = true
	contagem = -1.0
	if _disco:
		create_tween().tween_property(_disco, "position:x", 2.6, 2.5)  # a porta rola para o lado
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and principal.controles:
		principal.controles.aviso("A PORTA DO BUNKER ABRIU! CORRA PARA O TÚNEL!", Color(0.4, 1.0, 0.5), 5.0)
	for n: Node3D in get_tree().get_nodes_in_group("jogadores"):
		if (n as Jogador).local and n.global_position.distance_to(global_position) < 2.5:
			_entrou(n)


func _entrou(corpo: Node3D) -> void:
	var j := corpo as Jogador
	if aberto and j and j.local and j.vida > 0:
		j.item_pego.emit("fugiu", 0)
