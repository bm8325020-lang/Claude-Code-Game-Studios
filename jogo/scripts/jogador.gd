# Jogador em terceira pessoa: andar, correr, agachar e pular, relativo à câmera.
# A entrada vem de `entrada` (teclado/mouse, toque ou bot de teste preenchem o mesmo dicionário),
# assim a mecânica é a mesma em qualquer aparelho e dá para testar sem tela.
class_name Jogador
extends CharacterBody3D

# --- valores de ajuste (m/s, m/s², s) ---
const ANDAR: float = 1.9
const TROTE: float = 4.6
const CORRER: float = 7.2
const AGACHADO: float = 1.7
const ACEL_CHAO: float = 22.0
const ACEL_AR: float = 18.0        # dá para mudar de direção no meio do pulo
const FREIO: float = 28.0
const GIRO: float = 12.0          # quão rápido o corpo vira para onde anda
const GRAVIDADE: float = 24.0
const PULO: float = 7.9           # ~1,3 m de altura: sobe em capô e caixa de 1 m
const COYOTE: float = 0.12        # ainda pula logo depois de sair da borda
const BUFFER_PULO: float = 0.15   # aperto um pouco antes de tocar o chão também vale
const ALTURA_EM_PE: float = 1.8
const ALTURA_AGACHADO: float = 1.15
const RAIO: float = 0.32
const MIRA_VEL: float = 2.6        # mirando anda devagar (sem correr)
const GIRO_MIRA: float = 30.0      # mirando o corpo acompanha a câmera quase na hora

## Golpes do facão em sequência (aperta de novo durante o golpe = próximo do combo).
## acerto: fração do clipe em que a lâmina pega; arco em graus na frente do corpo; alcance em metros.
const GOLPES: Array[Dictionary] = [
	{"clipe": "golpe1", "acerto": 0.46, "dano": 25, "alcance": 1.8, "arco": 120.0},
	{"clipe": "golpe2", "acerto": 0.37, "dano": 25, "alcance": 1.8, "arco": 120.0},
	{"clipe": "golpe3", "acerto": 0.45, "dano": 45, "alcance": 2.0, "arco": 90.0},
]
const VEL_GOLPE: float = 1.0       # os golpes feitos à mão já têm o tempo certo
const PARADA_ACERTO: float = 0.07  # congela a animação um instante quando acerta (peso do golpe)

## Entrada do frame: move (Vector2, -1..1, y = frente), olhar (Vector2, graus), pular (bool, apertou agora),
## correr (bool, segurando), agachar (bool, alternou agora), andar (bool, segurando: passo lento no PC),
## mirar (bool, alternou agora: liga/desliga a mira travada), mira_segurando (null ou bool: PC segura o botão
## direito), atacar (bool, apertou agora: golpe ou tiro), trocar (bool: troca facão/pistola),
## arma ("" ou "facao"/"pistola": escolhe direto), recarregar (bool).
var entrada: Dictionary = {"move": Vector2.ZERO, "olhar": Vector2.ZERO, "pular": false, "correr": false,
	"agachar": false, "andar": false, "mirar": false, "mira_segurando": null, "atacar": false,
	"trocar": false, "arma": "", "recarregar": false, "pegar": false, "comer": false, "beber": false}

## Arma na mão: "facao" ou "pistola" (vai pela rede para os outros verem).
var arma: String = "facao":
	set(v):
		arma = v
		if _facao:
			_facao.visible = v == "facao"
		if pistola:
			pistola.visible = v == "pistola"
var pistola: Pistola

const VIDA_MAX: int = 100
const RENASCE: float = 4.0  # s caído até voltar no ponto de início (o resgate do grupo vem depois)
## Vida (quem manda é o dono do jogador; vai pela rede para os outros verem a queda).
var vida: int = VIDA_MAX
## Avisa o HUD que levou dano.
signal dano_levado(dano: int)
var inicio: Vector3
## provisório para testar: todos começam com lanterna; depois só quem achar uma no mapa
var tem_lanterna: bool = true
var _lanterna: SpotLight3D
var _pegando: float = 0.0       # > 0: abaixado pegando um item (não anda)
const PEGAR_DUR: float = 0.9
var _lanterna_mao: Node3D
var _ponta: Node3D
## direção da frente do modelo no espaço da mão esquerda (medida na pose parada)
const LANTERNA_EIXO: Vector3 = Vector3(-0.511, 0.769, -0.384)
var _morto_t: float = 0.0

# fome e sede (mecânica 15): caem com o tempo; zeradas, tiram vida aos poucos. Só no aparelho do dono.
const FOME_TEMPO: float = 900.0     # s de cheio (100) até zerar
const SEDE_TEMPO: float = 600.0
const DANO_FOME: int = 2            # vida perdida a cada INTERVALO_FOME com fome ou sede zerada
const INTERVALO_FOME: float = 3.0
const COMIDA_MAX: int = 5
const ENCHE: float = 45.0           # quanto uma lata/garrafa enche
var fome: float = 100.0
var sede: float = 100.0
var comida: int = 0
var agua: int = 0
var _fome_t: float = INTERVALO_FOME
## Parte de cima do corpo (mirar/atirar/recarregar) por cima das pernas; vai pela rede.
var cima_rede: String = ""

var agachado: bool = false
## Mira travada: o corpo fica virado para onde a câmera olha e anda de lado/de costas (modo tiro).
var mira_travada: bool = false
var correndo: bool = false
var camera: CameraTerceira
## Rede: true no aparelho que controla este jogador (só ele tem câmera e lê os controles).
var local: bool = true
## Estado enviado pela rede (o dono escreve, os outros aparelhos leem e suavizam).
var pos_rede: Vector3
var rot_rede: float = 0.0
var clipe_rede: String = "parado"
var nick: String = "":
	set(v):
		nick = v
		if _placa:
			_placa.text = v
var _placa: Label3D
var modelo: Node3D
var anim: AnimationPlayer

var _forma: CapsuleShape3D
var _colisor: CollisionShape3D
var _teto: ShapeCast3D
var _coyote: float = 0.0
var _buffer: float = 0.0
var _no_ar_desde: float = 0.0
var _pousando: float = 0.0
var _clipe: String = ""
var _golpe: int = -1          # golpe em andamento (índice em GOLPES), -1 = nenhum
var _golpe_t: float = 0.0
var _golpe_dur: float = 0.0
var _acertou: bool = false
var _proximo: bool = false    # apertou de novo: emenda o próximo golpe
var _parada: float = 0.0
var _som: AudioStreamPlayer3D
var _sons: Dictionary = {}
var _facao: Node3D
var _esq: Skeleton3D
var _cima_peso: float = 0.0     # 0..1: quanto a pose de cima (pistola) manda nos braços
var _cima_t: float = 0.0
var _cima_clipe: String = ""
var _encara: float = 0.0        # depois de atirar sem mirar, o corpo fica virado para a mira um instante
var _tiro_t: float = 9.0
const COICE_GRAUS: float = 20.0  # quanto a arma sobe no tiro
const COICE_DURA: float = 0.3   # s até voltar à mira
const GUARDA_GRAUS: float = 35.0  # sem mirar, a pistola fica baixa (guarda); mirando ou atirando, sobe
var _guarda: float = 0.0
const TRONCO: String = "mixamorig_Spine2"
const MAO: String = "mixamorig_RightHand"


func _ready() -> void:
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	collision_layer = 2
	collision_mask = 1 | 8 | Porta.CAMADA  # mundo, zumbis e portas
	add_to_group("jogadores")
	_forma = CapsuleShape3D.new()
	_forma.radius = RAIO
	_forma.height = ALTURA_EM_PE
	_colisor = CollisionShape3D.new()
	_colisor.shape = _forma
	_colisor.position.y = ALTURA_EM_PE * 0.5
	add_child(_colisor)
	# confere se cabe ficar em pé antes de levantar (túnel baixo, debaixo de carro)
	_teto = ShapeCast3D.new()
	var s := SphereShape3D.new()
	s.radius = RAIO * 0.95
	_teto.shape = s
	_teto.position.y = ALTURA_AGACHADO
	_teto.target_position = Vector3(0, ALTURA_EM_PE - ALTURA_AGACHADO - RAIO + 0.05, 0)
	_teto.collision_mask = 1
	_teto.enabled = true
	add_child(_teto)
	_monta_modelo()
	_monta_arma()
	_monta_lanterna()
	_som = AudioStreamPlayer3D.new()
	_som.max_db = 3.0
	add_child(_som)
	for nome: String in ["knifeSlice", "knifeSlice2", "impactPunch_heavy_000", "impactPunch_heavy_001"]:
		_sons[nome] = load("res://assets/sons/%s.ogg" % nome)
	_placa = Label3D.new()
	_placa.text = nick
	_placa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_placa.position.y = ALTURA_EM_PE + 0.35
	_placa.font_size = 48
	_placa.pixel_size = 0.004
	_placa.outline_size = 10
	_placa.no_depth_test = true
	_placa.visible = not local  # o nome aparece em cima dos outros, não no seu
	add_child(_placa)
	pos_rede = global_position
	inicio = global_position
	_monta_sincronia()
	if local:
		camera = CameraTerceira.new()
		camera.alvo = self
		add_child(camera)
	else:
		collision_layer = 4  # os outros jogadores: não empurram a sua física local por enquanto


# o que vai pela rede: posição e giro sempre (30x/s), animação, agachado e nome quando mudam
func _monta_sincronia() -> void:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:pos_rede", ".:rot_rede"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for p: String in [".:clipe_rede", ".:agachado", ".:nick", ".:arma", ".:cima_rede", ".:vida", ".:tem_lanterna", ".:mira_travada"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_replication_mode(NodePath(p), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sincronia"
	sync.root_path = NodePath("..")
	sync.replication_interval = 1.0 / 30.0
	sync.replication_config = cfg
	sync.set_multiplayer_authority(get_multiplayer_authority())  # criado depois: herda o dono à mão
	add_child(sync)


func _monta_modelo() -> void:
	modelo = (load(Anims.MODELO) as PackedScene).instantiate()
	add_child(modelo)
	# o material do X Bot vem rosado na importação: corpo cinza claro e juntas escuras
	for m: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.2, 0.22) if m.name.contains("Joints") else Color(0.78, 0.78, 0.8)
		mat.roughness = 0.6
		m.material_override = mat
	anim = AnimationPlayer.new()
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL  # avançado em _process
	modelo.add_child(anim)
	anim.add_animation_library("", Anims.biblioteca())
	_toca("parado", 0.0)


# facão provisório (espada curta do pacote de props) na mão direita
func _monta_arma() -> void:
	_esq = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var mao := BoneAttachment3D.new()
	mao.bone_name = MAO
	_esq.add_child(mao)
	_facao = (load("res://assets/armas/Sword_Bronze.gltf") as PackedScene).instantiate()
	# a lâmina (eixo +Y do modelo) aponta para a frente da mão (medido na pose parada do X Bot)
	_facao.quaternion = Quaternion(Vector3.UP, Vector3(0.975, 0.126, 0.185).normalized())
	_facao.scale = Vector3.ONE * 0.75
	mao.add_child(_facao)
	pistola = Pistola.new()
	pistola.name = "Pistola"
	pistola.dono = self
	var z: Vector3 = PISTOLA_FRENTE.normalized()
	var x: Vector3 = PISTOLA_CIMA.cross(z).normalized()
	pistola.basis = Basis(x, z.cross(x), z)  # cano (+Z) para a frente, ferrolho (+Y) para cima
	pistola.position = PISTOLA_POS
	mao.add_child(pistola)
	arma = arma  # aplica a visibilidade


func _physics_process(dt: float) -> void:
	if not local:
		_segue_rede(dt)
		return
	if vida <= 0:
		_caido(dt)
		return
	var mov: Vector2 = entrada.get("move", Vector2.ZERO)
	if mov.length() > 1.0:
		mov = mov.normalized()
	if entrada.get("pegar", false):
		entrada["pegar"] = false
		_tenta_pegar()
	if entrada.get("comer", false):
		entrada["comer"] = false
		if comida > 0 and fome < 100.0:
			comida -= 1
			fome = minf(100.0, fome + ENCHE)
	if entrada.get("beber", false):
		entrada["beber"] = false
		if agua > 0 and sede < 100.0:
			agua -= 1
			sede = minf(100.0, sede + ENCHE)
	_passa_fome(dt)
	if _pegando > 0.0:
		_pegando -= dt
		mov = Vector2.ZERO
	if entrada.get("agachar", false):
		_alterna_agachar()
		entrada["agachar"] = false
	if entrada.get("pular", false):
		_buffer = BUFFER_PULO
		entrada["pular"] = false
	if entrada.get("mirar", false):
		mira_travada = not mira_travada
		entrada["mirar"] = false
	if entrada.get("mira_segurando") != null:
		mira_travada = bool(entrada["mira_segurando"])
	if entrada.get("trocar", false):
		entrada["trocar"] = false
		_troca_arma("pistola" if arma == "facao" else "facao")
	if String(entrada.get("arma", "")) != "":
		_troca_arma(String(entrada["arma"]))
		entrada["arma"] = ""
	if entrada.get("recarregar", false):
		entrada["recarregar"] = false
		if arma == "pistola":
			pistola.recarregar()
	if entrada.get("atacar", false):
		entrada["atacar"] = false
		if arma == "pistola":
			_atira()
		else:
			_pede_golpe()
	_atualiza_golpe(dt)
	_encara -= dt
	_tiro_t += dt
	correndo = bool(entrada.get("correr", false)) and not agachado and not mira_travada and mov.y > 0.3

	# direção relativa à câmera (só o giro horizontal)
	var yaw: float = camera.yaw if camera else 0.0
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	var direita := Vector3(cos(yaw), 0, -sin(yaw))
	var dir: Vector3 = (direita * mov.x + frente * mov.y)
	var forca: float = mov.length()

	var alvo_vel: float
	if mira_travada:
		alvo_vel = MIRA_VEL
	elif agachado:
		alvo_vel = AGACHADO
	elif correndo:
		alvo_vel = CORRER
	elif entrada.get("andar", false) or forca < 0.55:
		alvo_vel = ANDAR  # stick meio empurrado = andar devagar
	else:
		alvo_vel = TROTE
	if _golpe >= 0:
		alvo_vel *= 0.3  # golpeando quase não anda
	var desejada: Vector3 = dir.normalized() * alvo_vel * clampf(forca / 0.55, 0.0, 1.0) if forca > 0.08 else Vector3.ZERO

	var plano := Vector3(velocity.x, 0, velocity.z)
	var acel: float = (ACEL_CHAO if desejada.length() > plano.length() else FREIO) if is_on_floor() else ACEL_AR
	plano = plano.move_toward(desejada, acel * dt)
	velocity.x = plano.x
	velocity.z = plano.z

	# pulo com coyote time e buffer
	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote -= dt
	_buffer -= dt
	if _buffer > 0.0 and _coyote > 0.0:
		if agachado and not _cabe_em_pe():
			_buffer = 0.0
		else:
			if agachado:
				_alterna_agachar()
			velocity.y = PULO
			_buffer = 0.0
			_coyote = 0.0
			_toca("pulo_inicio", 0.08)
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
		_no_ar_desde += dt
	var estava_no_ar: bool = not is_on_floor()
	move_and_slide()
	if estava_no_ar and is_on_floor() and _no_ar_desde > 0.35:
		_pousando = 0.22
	if is_on_floor():
		_no_ar_desde = 0.0

	# mirando ou com a pistola: o corpo olha para a frente da câmera; senão vira para onde está andando
	if olha_camera():
		modelo.rotation.y = lerp_angle(modelo.rotation.y, yaw + PI, 1.0 - exp(-GIRO_MIRA * dt))
	elif _golpe >= 0:
		pass  # durante o golpe o corpo não gira (o golpe sai para onde você estava virado)
	elif plano.length() > 0.3:
		var ang: float = atan2(plano.x, plano.z)
		modelo.rotation.y = lerp_angle(modelo.rotation.y, ang, 1.0 - exp(-GIRO * dt))
	_anima(dt, plano.length())
	pos_rede = global_position
	rot_rede = modelo.rotation.y
	clipe_rede = _clipe
	cima_rede = _escolhe_cima()


# jogador de outro aparelho: vai suave até a última posição recebida e toca a mesma animação
## Está mirando a pistola neste ponto? (para o zumbi desviar; usa o giro do corpo, que vai pela rede)
func mirando_em(ponto: Vector3, graus: float) -> bool:
	if not mira_travada or arma != "pistola" or vida <= 0:
		return false
	var d: Vector3 = ponto - global_position
	var f: Vector3 = modelo.global_basis.z
	return rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2(d.x, d.z))) < graus


## Acertou um zumbi: avisa o HUD (marca na mira) e toca o baque. `forte` = cabeça, golpe forte ou matou.
signal acertou_alvo(forte: bool)


func _confirma_acerto(forte: bool, cabeca: bool) -> void:
	acertou_alvo.emit(forte)
	_som.stream = _sons.get("impactPunch_heavy_000" if cabeca else "impactPunch_heavy_001")
	_som.pitch_scale = 0.75 if cabeca else randf_range(1.2, 1.35)
	_som.volume_db = 2.0 if cabeca else -6.0
	_som.play()


## Item ao alcance agora (para o botão PEGAR), ou null.
func item_perto() -> Item:
	return Item.perto(get_tree(), global_position) if vida > 0 else null


## Porta ao alcance agora (para o botão USAR), ou null.
func porta_perto() -> Porta:
	return Porta.perto(get_tree(), global_position) if vida > 0 else null


# USAR: pega o item perto; se não tiver item, abre/fecha a porta perto
func _tenta_pegar() -> void:
	var it: Item = item_perto()
	if it == null:
		var p: Porta = porta_perto()
		if p:
			if multiplayer.is_server():
				p.alterna_por(self)
			else:
				_pede_porta.rpc_id(1, get_path_to(p))
		return
	if _pegando > 0.0 or _golpe >= 0 or not is_on_floor():
		return
	_pegando = PEGAR_DUR
	mira_travada = false
	_toca("pegar", 0.12)
	if multiplayer.is_server():
		it.pegar_por(self)
	else:
		_pede_item.rpc_id(1, get_path_to(it))


@rpc("any_peer", "call_remote", "reliable")
func _pede_item(caminho: NodePath) -> void:
	# roda no servidor, na cópia deste jogador; só o dono dele pode pedir
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		var it := get_node_or_null(caminho) as Item
		if it:
			it.pegar_por(self)


@rpc("any_peer", "call_remote", "reliable")
func _pede_porta(caminho: NodePath) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		var p := get_node_or_null(caminho) as Porta
		if p:
			p.alterna_por(self)


## Servidor: entrega o item (no aparelho do dono do jogador).
func ganhar(tipo: String, qtd: int) -> void:
	if is_multiplayer_authority():
		_recebe(tipo, qtd)
	else:
		_rede_ganha.rpc_id(get_multiplayer_authority(), tipo, qtd)


@rpc("any_peer", "call_remote", "reliable")
func _rede_ganha(tipo: String, qtd: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_recebe(tipo, qtd)


func _recebe(tipo: String, qtd: int) -> void:
	match tipo:
		"municao":
			pistola.reserva = mini(pistola.reserva + qtd, Pistola.RESERVA_MAX)
		"lanterna":
			tem_lanterna = true
		"comida":
			comida = mini(comida + qtd, COMIDA_MAX)
		"agua":
			agua = mini(agua + qtd, COMIDA_MAX)
	item_pego.emit(tipo, qtd)


## Avisa o HUD que pegou algo.
signal item_pego(tipo: String, qtd: int)


## Dano de zumbi (ou, depois, de outro jogador). Quem bate pode estar em outro aparelho: o dano vai para o dono.
func levar_dano(dano: int, dir: Vector3) -> void:
	if is_multiplayer_authority():
		_recebe_dano(dano, dir)
	else:
		_rede_dano.rpc_id(get_multiplayer_authority(), dano, dir)


@rpc("any_peer", "call_remote", "reliable")
func _rede_dano(dano: int, dir: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:  # só o servidor (que roda os zumbis) manda dano
		_recebe_dano(dano, dir)


func _recebe_dano(dano: int, dir: Vector3) -> void:
	if vida <= 0:
		return
	vida = maxi(0, vida - dano)
	velocity += Vector3(dir.x, 0, dir.z) * 3.0  # empurrão
	_toca_som("impactPunch_heavy_00%d" % (randi() % 2), -2.0)
	if camera:
		camera.tremer(0.25)
	dano_levado.emit(dano)
	if vida == 0:
		_cai()


func _passa_fome(dt: float) -> void:
	fome = maxf(0.0, fome - 100.0 / FOME_TEMPO * dt)
	sede = maxf(0.0, sede - 100.0 / SEDE_TEMPO * dt)
	if fome > 0.0 and sede > 0.0:
		_fome_t = INTERVALO_FOME
		return
	_fome_t -= dt
	if _fome_t <= 0.0:
		_fome_t = INTERVALO_FOME
		vida = maxi(0, vida - DANO_FOME)
		dano_levado.emit(DANO_FOME)
		if vida == 0:
			_cai()


# vida zerada: cai e volta no início depois de RENASCE
func _cai() -> void:
	_morto_t = RENASCE
	_golpe = -1
	mira_travada = false
	if pistola.recarregando:
		pistola.recarregando = false
	_toca("morte", 0.1)


func _caido(dt: float) -> void:
	_morto_t -= dt
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * dt)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * dt)
	velocity.y -= GRAVIDADE * dt
	move_and_slide()
	if _morto_t <= 0.0:
		global_position = inicio
		velocity = Vector3.ZERO
		vida = VIDA_MAX
		fome = 100.0
		sede = 100.0
		reset_physics_interpolation()
		_toca("parado", 0.0)
	pos_rede = global_position
	clipe_rede = _clipe
	cima_rede = ""


func _segue_rede(dt: float) -> void:
	var antes: Vector3 = global_position
	if global_position.distance_to(pos_rede) > 6.0:
		global_position = pos_rede  # pulou longe (teleporte/lag grande): não arrasta pelo mapa
	else:
		global_position = global_position.lerp(pos_rede, 1.0 - exp(-15.0 * dt))
	modelo.rotation.y = lerp_angle(modelo.rotation.y, rot_rede, 1.0 - exp(-15.0 * dt))
	_toca(clipe_rede, 0.18)
	var vel: float = Vector2(global_position.x - antes.x, global_position.z - antes.z).length() / maxf(dt, 0.001)
	var base: float = float(Anims.VELOCIDADE.get(clipe_rede, 0.0))
	anim.speed_scale = clampf(vel / base, 0.5, 1.5) if base > 0.1 and vel > 0.15 else 1.0


func _alterna_agachar() -> void:
	if agachado and not _cabe_em_pe():
		return  # tem teto em cima: continua agachado
	agachado = not agachado
	_forma.height = ALTURA_AGACHADO if agachado else ALTURA_EM_PE
	_colisor.position.y = _forma.height * 0.5


func _cabe_em_pe() -> bool:
	_teto.force_shapecast_update()
	return not _teto.is_colliding()


func _anima(dt: float, vel: float) -> void:
	_pousando -= dt
	var clipe: String
	if _golpe >= 0 or _pegando > 0.0:
		return  # o golpe (ou o pegar) controla a animação
	if not is_on_floor() and (_no_ar_desde > 0.12 or velocity.y > 0.5):
		clipe = "no_ar" if _clipe != "pulo_inicio" or not anim.is_playing() else "pulo_inicio"
	elif _pousando > 0.0:
		clipe = "pouso"
	elif agachado:
		clipe = "agachado" if vel < 0.2 else "agachado_andar"
	elif vel < 0.15:
		clipe = "parado"
	elif olha_camera():
		clipe = _clipe_mirando()
	elif vel < 3.0:
		clipe = "andar"
	elif vel < 6.0:
		clipe = "trote"
	else:
		clipe = "correr"
	_toca(clipe, 0.18)
	# pés acompanham o chão: escala a velocidade do clipe pela velocidade real
	var base: float = float(Anims.VELOCIDADE.get(_clipe, 0.0))
	anim.speed_scale = clampf(vel / base, 0.5, 1.5) if base > 0.1 and vel > 0.15 else 1.0


# --- pistola ---
# Orientação da pistola na mão (eixos do modelo no espaço da mão: cano = +Z do modelo).
# frente e cima do mundo no espaço da mão, medidos na pose de mira olhando reto
const PISTOLA_FRENTE: Vector3 = Vector3(-0.226, 0.884, 0.408)
const PISTOLA_CIMA: Vector3 = Vector3(0.963, 0.140, 0.230)
const PISTOLA_POS: Vector3 = Vector3(0, 0.08, 0)


func _troca_arma(nova: String) -> void:
	if nova == arma or _golpe >= 0:
		return
	arma = nova
	if pistola.recarregando:
		pistola.recarregando = false  # trocar cancela a recarga


## Raio da mira: do centro da tela para a frente, começando na altura do jogador (não acerta o que está
## entre a câmera e ele). Sem câmera (testes, outros aparelhos): reto na frente do corpo.
func raio_mira() -> Array[Vector3]:
	if camera == null:
		return [global_position + Vector3(0, 1.4, 0), modelo.global_basis.z.normalized()]
	var c: Camera3D = camera.cam
	var dir: Vector3 = -c.global_basis.z.normalized()
	var origem: Vector3 = c.global_position
	origem += dir * maxf(0.0, (global_position + Vector3(0, 1.3, 0) - origem).dot(dir))
	return [origem, dir]


func _atira() -> void:
	if not pistola.pronta() and pistola.balas > 0:
		return
	var yaw: float = camera.yaw if camera else modelo.rotation.y - PI
	modelo.rotation.y = yaw + PI  # vira para a mira na hora do tiro
	var r: Array[Vector3] = raio_mira()
	var res: Dictionary = pistola.atirar(r[0], r[1], mira_travada)
	if not res.atirou:
		return
	_encara = 0.7
	_tiro_t = 0.0
	if multiplayer.is_server():  # quem roda os zumbis ouve aqui; os tiros dos clientes chegam por _rede_tiro
		Zumbi.barulho(get_tree(), global_position, Pistola.BARULHO)
	if camera:
		camera.coice(Pistola.COICE)
	if res.acertou is Zumbi:
		var z: Zumbi = res.acertou
		# no servidor a vida já caiu; no cliente o dano ainda vai chegar: prevê se matou
		var morreu: bool = z.vida <= 0 if multiplayer.is_server() else z.vida - Pistola.DANO * (2 if res.cabeca else 1) <= 0
		_confirma_acerto(res.cabeca or morreu, res.cabeca)
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rede_tiro.rpc(res.ponto, res.acertou != null, res.carne)


@rpc("authority", "call_remote", "unreliable")
func _rede_tiro(ponto: Vector3, bateu: bool, carne: bool) -> void:
	pistola.efeito(ponto, bateu, carne)
	if multiplayer.is_server():
		Zumbi.barulho(get_tree(), global_position, Pistola.BARULHO)


## O corpo fica virado para a câmera? (mirando, logo depois do tiro, ou com a pistola sem correr)
func olha_camera() -> bool:
	return mira_travada or _encara > 0.0 or (arma == "pistola" and not correndo)


# pose da parte de cima: recarregar > tiro recente > mirando/encarando > segurando a pistola
func _escolhe_cima() -> String:
	if arma != "pistola" or vida <= 0:
		return ""
	if pistola.recarregando:
		return "pistola_recarga"
	if _tiro_t < maxf(0.18, COICE_DURA):
		return "pistola_tiro"
	if olha_camera():
		return "pistola_mira"
	return ""


func _process(dt: float) -> void:
	anim.advance(dt)
	_atualiza_lanterna()
	var cima: String = cima_rede if not local else _escolhe_cima()
	if cima != _cima_clipe:
		if cima != "":
			_cima_t = 0.0
		if cima != "" or _cima_peso <= 0.01:
			_cima_clipe = cima if cima != "" else _cima_clipe
	_cima_peso = move_toward(_cima_peso, 1.0 if cima != "" else 0.0, dt * 8.0)
	var em_guarda: bool = not mira_travada and _tiro_t > 0.6 and not pistola.recarregando
	_guarda = move_toward(_guarda, 1.0 if em_guarda else 0.0, dt * (3.0 if em_guarda else 9.0))
	if _cima_peso > 0.0 and _cima_clipe != "":
		_cima_t += dt
		_aplica_cima(_cima_clipe, _cima_t, _cima_peso)


# lanterna na mão esquerda (a direita é da arma). A luz sai da ponta mas aponta para onde o jogador olha,
# senão o facho ficaria balançando com a animação do braço.
func _monta_lanterna() -> void:
	var mao := BoneAttachment3D.new()
	mao.bone_name = "mixamorig_LeftHand"
	_esq.add_child(mao)
	_lanterna_mao = Node3D.new()
	_lanterna_mao.quaternion = Quaternion(Vector3.UP, LANTERNA_EIXO.normalized())
	_lanterna_mao.position = Vector3(0, 0.07, 0)
	mao.add_child(_lanterna_mao)
	var corpo := StandardMaterial3D.new()
	corpo.albedo_color = Color(0.12, 0.12, 0.13)
	corpo.metallic = 0.4
	corpo.roughness = 0.5
	_cilindro(0.02, 0.15, Vector3.ZERO, corpo)                      # cabo (eixo +Y = para onde aponta)
	_cilindro(0.032, 0.05, Vector3(0, 0.095, 0), corpo)             # cabeça
	var lente := StandardMaterial3D.new()
	lente.albedo_color = Color(1, 0.95, 0.8)
	lente.emission_enabled = true
	lente.emission = Color(1, 0.93, 0.75)
	_lente = _cilindro(0.027, 0.006, Vector3(0, 0.121, 0), lente)
	_lente_mat = lente
	_ponta = Node3D.new()
	_ponta.position = Vector3(0, 0.13, 0)
	_lanterna_mao.add_child(_ponta)
	_lanterna = SpotLight3D.new()
	_lanterna.light_color = Color(1.0, 0.93, 0.8)
	_lanterna.spot_range = 24.0
	_lanterna.spot_angle = 24.0
	_lanterna.spot_attenuation = 0.8
	_lanterna.light_energy = 0.0
	add_child(_lanterna)


var _lente: MeshInstance3D
var _lente_mat: StandardMaterial3D


func _cilindro(raio: float, alto: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = alto
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lanterna_mao.add_child(mi)
	return mi


func _atualiza_lanterna() -> void:
	_lanterna_mao.visible = tem_lanterna
	var c := get_tree().get_first_node_in_group("ciclo") as Ciclo
	var forca: float = clampf(c.noite() * 1.5 - 0.2, 0.0, 1.0) if c and tem_lanterna and vida > 0 else 0.0
	_lanterna.light_energy = 3.0 * forca
	_lanterna.visible = forca > 0.0
	_lente_mat.emission_energy_multiplier = 3.0 * forca
	if forca > 0.0:
		var p: float = camera.pitch if camera else 0.0
		var frente: Vector3 = modelo.global_basis.z
		frente.y = 0.0
		var dir: Vector3 = (frente.normalized() * cos(p) - Vector3.UP * sin(p)).normalized()
		_lanterna.global_position = _ponta.global_position
		_lanterna.global_basis = Basis.looking_at(dir)  # SpotLight ilumina para -Z, que é o looking_at


# sobrepõe nos ossos de cima a pose do clipe da pistola (as pernas continuam com a locomoção)
func _aplica_cima(clipe: String, t: float, peso: float) -> void:
	var a: Animation = anim.get_animation(clipe)
	if a == null:
		return
	if clipe == "pistola_recarga":
		t = t * a.length / Pistola.RECARGA  # encaixa o clipe no tempo da recarga
	t = fmod(t, a.length) if a.loop_mode != Animation.LOOP_NONE else minf(t, a.length)
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var osso: String = String(a.track_get_path(i)).get_slice(":", 1)
		if not _osso_de_cima(osso):
			continue
		var idx: int = _esq.find_bone(osso)
		var q: Quaternion = a.rotation_track_interpolate(i, t)
		_esq.set_bone_pose_rotation(idx, _esq.get_bone_pose_rotation(idx).slerp(q, peso))
	if clipe.begins_with("pistola"):
		_aponta_tronco(peso)
		if _guarda > 0.01:
			_gira_bracos(-GUARDA_GRAUS * _guarda, 0.0)
		if _tiro_t < COICE_DURA:
			_coice()


# coice do tiro, por cima da mira (que senão anularia o coice do clipe): sobe rápido e volta devagar
func _coice() -> void:
	var k: float = minf(_tiro_t / 0.035, 1.0) * pow(1.0 - _tiro_t / COICE_DURA, 1.5)
	_gira_bracos(COICE_GRAUS * k, 0.3)


# sobe (graus > 0) ou baixa os dois braços em volta dos ombros; o peito acompanha uma fração
func _gira_bracos(graus: float, tronco: float) -> void:
	var xf: Transform3D = _esq.global_transform
	var ombro: Vector3 = xf * _esq.get_bone_global_pose(_esq.find_bone("mixamorig_RightArm")).origin
	var mao: Vector3 = xf * _esq.get_bone_global_pose(_esq.find_bone(MAO)).origin
	var braco: Vector3 = (mao - ombro).normalized()
	var gira: Quaternion = Quaternion(braco, (braco + Vector3.UP * tan(deg_to_rad(graus))).normalized())
	for osso: String in [TRONCO, "mixamorig_RightArm", "mixamorig_LeftArm"]:
		var r: Quaternion = Quaternion.IDENTITY.slerp(gira, tronco) if osso == TRONCO else gira
		if r.is_equal_approx(Quaternion.IDENTITY):
			continue
		var i: int = _esq.find_bone(osso)
		var q_pai: Quaternion = (xf.basis * _esq.get_bone_global_pose(_esq.get_bone_parent(i)).basis).orthonormalized().get_rotation_quaternion()
		_esq.set_bone_pose_rotation(i, (q_pai.inverse() * r * q_pai * _esq.get_bone_pose_rotation(i)).normalized())


# braços, mãos, dedos, tronco e cabeça (as pernas e o quadril ficam com a locomoção)
func _osso_de_cima(osso: String) -> bool:
	return osso.contains("Arm") or osso.contains("Hand") or osso.contains("Shoulder") or osso.ends_with("Spine1") \
		or osso.ends_with("Spine2") or osso.contains("Neck") or osso.contains("Head")


# gira o peito para o braço direito apontar exatamente para a mira (frente do corpo inclinada pelo ângulo da
# câmera). Mede o braço como está agora, então serve em pé, agachado, andando ou com a pose de tiro torta.
func _aponta_tronco(peso: float) -> void:
	var xf: Transform3D = _esq.global_transform
	var ombro: Vector3 = xf * _esq.get_bone_global_pose(_esq.find_bone("mixamorig_RightArm")).origin
	var mao: Vector3 = xf * _esq.get_bone_global_pose(_esq.find_bone(MAO)).origin
	var p: float = camera.pitch if camera else 0.0
	var frente: Vector3 = modelo.global_basis.z
	frente.y = 0.0
	var quer: Vector3 = (frente.normalized() * cos(p) - Vector3.UP * sin(p)).normalized()
	var r: Quaternion = Quaternion.IDENTITY.slerp(Quaternion((mao - ombro).normalized(), quer), peso)
	var ic: int = _esq.find_bone(TRONCO)
	var q_pai: Quaternion = (xf.basis * _esq.get_bone_global_pose(_esq.get_bone_parent(ic)).basis).orthonormalized().get_rotation_quaternion()
	_esq.set_bone_pose_rotation(ic, (q_pai.inverse() * r * q_pai * _esq.get_bone_pose_rotation(ic)).normalized())


# --- facão: combo de 3 golpes ---
func _pede_golpe() -> void:
	if not is_on_floor() and _no_ar_desde > 0.12:
		return
	if _golpe < 0:
		_inicia_golpe(0)
	elif _golpe < GOLPES.size() - 1:
		_proximo = true  # guarda o aperto: emenda depois que este golpe pegar


func _inicia_golpe(i: int) -> void:
	_golpe = i
	_golpe_t = 0.0
	_acertou = false
	_proximo = false
	if agachado and _cabe_em_pe():
		_alterna_agachar()
	var c: String = GOLPES[i].clipe
	_golpe_dur = anim.get_animation(c).length / VEL_GOLPE
	_clipe = c
	anim.play(c, 0.08)
	anim.speed_scale = VEL_GOLPE
	_toca_som("knifeSlice" if i != 1 else "knifeSlice2", -4.0)


func _atualiza_golpe(dt: float) -> void:
	if _golpe < 0:
		return
	if _parada > 0.0:
		_parada -= dt
		anim.speed_scale = 0.0 if _parada > 0.0 else VEL_GOLPE
		return
	_golpe_t += dt
	var g: Dictionary = GOLPES[_golpe]
	if not _acertou and _golpe_t >= _golpe_dur * float(g.acerto):
		_acertou = true
		_acerta(g)
	# depois do acerto, se pediu o próximo, emenda; senão termina o clipe
	if _proximo and _golpe_t >= _golpe_dur * (float(g.acerto) + 0.15):
		_inicia_golpe(_golpe + 1)
	elif _golpe_t >= _golpe_dur * 0.85:
		_golpe = -1
		_clipe = ""


## Quem leva o golpe: nós no grupo "golpeavel" com levar_golpe(dano, direção, quem).
func _acerta(g: Dictionary) -> void:
	var frente: Vector3 = modelo.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var pegou: bool = false
	for alvo: Node in get_tree().get_nodes_in_group("golpeavel"):
		var n3 := alvo as Node3D
		if n3 == null or n3 == self:
			continue
		var d: Vector3 = n3.global_position - global_position
		d.y = 0.0
		if d.length() > float(g.alcance) + 0.3 or d.length() < 0.01:
			continue
		if rad_to_deg(frente.angle_to(d.normalized())) > float(g.arco) * 0.5:
			continue
		alvo.call("levar_golpe", int(g.dano), d.normalized(), self)
		if alvo is Zumbi:
			Pistola.sangue(get_tree(), n3.global_position + Vector3(0, 1.2, 0), d.normalized())
			_confirma_acerto(_golpe == 2 or (alvo as Zumbi).vida <= 0, false)
		pegou = true
	if pegou:
		_parada = PARADA_ACERTO
		_toca_som("impactPunch_heavy_00%d" % (randi() % 2), 0.0)
		if camera:
			camera.tremer(0.12 if _golpe < 2 else 0.22)


func _toca_som(nome: String, db: float) -> void:
	if _sons.has(nome):
		_som.stream = _sons[nome]
		_som.volume_db = db
		_som.pitch_scale = randf_range(0.92, 1.08)
		_som.play()


## Golpe em andamento (-1 = nenhum), para testes.
func golpe_atual() -> int:
	return _golpe


# andando com a mira travada: frente, lados ou costas conforme a direção em relação ao corpo
func _clipe_mirando() -> String:
	var local: Vector3 = modelo.global_transform.basis.inverse() * Vector3(velocity.x, 0, velocity.z)
	if absf(local.x) > absf(local.z):
		return "lado_esq" if local.x > 0.0 else "lado_dir"
	return "trote" if local.z > 0.0 else "tras"


func _toca(clipe: String, mistura: float) -> void:
	if arma == "pistola" and anim.has_animation(clipe + "_p"):
		clipe += "_p"  # mesma ação segurando a pistola
	if clipe == _clipe:
		return
	_clipe = clipe
	anim.play(clipe, mistura)


## Clipe tocando agora (para testes e depuração).
func clipe_atual() -> String:
	return _clipe
