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
const PARADA_ACERTO: float = 0.07  # congela a animação um instante quando acerta (peso do golpe)

## Entrada do frame: move (Vector2, -1..1, y = frente), olhar (Vector2, graus), pular (bool, apertou agora),
## correr (bool, segurando), agachar (bool, alternou agora), andar (bool, segurando: passo lento no PC),
## mirar (bool, alternou agora: liga/desliga a mira travada), mira_segurando (null ou bool: PC segura o botão
## direito), atacar (bool, apertou agora: golpe ou tiro), trocar (bool: troca facão/pistola),
## arma ("" ou o tipo: escolhe direto), recarregar (bool), atirando (bool, segurando o gatilho: rajada no
## automático), modo (bool, apertou: troca semi/automático na arma com seletor).
var entrada: Dictionary = {"move": Vector2.ZERO, "olhar": Vector2.ZERO, "pular": false, "correr": false,
	"agachar": false, "andar": false, "mirar": false, "mira_segurando": null, "atacar": false,
	"trocar": false, "arma": "", "recarregar": false, "pegar": false, "comer": false, "beber": false,
	"atirando": false, "modo": false}

## Arma na mão: uma arma branca (Armas.BRANCAS) ou "pistola" (vai pela rede para os outros verem).
var arma: String = "facao":
	set(v):
		arma = v
		if Armas.e_branca(v):
			_ultima_branca = v
		if _facao:
			_facao.visible = Armas.e_branca(v)
			if Armas.e_branca(v) and _facao.get_child_count() > 0 and _facao.get_child(0).name != "Arma_" + v:
				_facao.get_child(0).queue_free()
				var m: Node3D = Armas.modelo(v)
				_facao.add_child(m)
				if camera:  # primeira pessoa: a arma da mão do corpo só faz sombra (a da tela é a Maos)
					for g: GeometryInstance3D in m.find_children("*", "GeometryInstance3D", true, false):
						g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if pistola:
			pistola.visible = v == "pistola"
		if smg:
			smg.visible = v == "smg"
		if e_fogo(v):
			_ultima_fogo = v
var _ultima_branca: String = "facao"
var pistola: Pistola
## Submetralhadora (mesma classe da pistola, com seletor de tiro). Só aparece se estiver na mochila.
var smg: Pistola
var _ultima_fogo: String = "pistola"


## É arma de fogo? (pistola ou submetralhadora)
static func e_fogo(tipo: String) -> bool:
	return tipo == "pistola" or tipo == "smg"


## A arma de fogo da mão (ou a pistola, se a mão está com arma branca).
func fogo() -> Pistola:
	return smg if arma == "smg" and smg else pistola


# balas que estão nos pentes das armas que ainda estão na mochila (vão para o saco junto)
func _balas_pentes() -> int:
	return (pistola.balas if mochila.tem("pistola") else 0) + (smg.balas if smg and mochila.tem("smg") else 0)

const VIDA_MAX: int = 100
const RENASCE: float = 4.0  # s caído até voltar no ponto de início (o resgate do grupo vem depois)
## Vida (quem manda é o dono do jogador; vai pela rede para os outros verem a queda).
var vida: int = VIDA_MAX
## Avisa o HUD que levou dano.
signal dano_levado(dano: int)
var inicio: Vector3
## provisório para testar: todos começam com lanterna; depois só quem achar uma no mapa
var tem_lanterna: bool = true:
	set(v):
		tem_lanterna = v
		if mochila and mochila.tem("lanterna") != v:
			mochila.definir("lanterna", 1 if v else 0)
## Mochila (os 6 primeiros espaços são a barra rápida). Comida, água e a reserva da pistola moram aqui.
var mochila := Mochila.new()
var _lanterna: SpotLight3D
var _pegando: float = 0.0       # > 0: abaixado pegando um item (não anda)
const PEGAR_DUR: float = 1.2  # = clipe "pegar" (abaixa até o chão e levanta)
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
## Infecção (0–100): cada golpe de zumbi tem CHANCE_INFECTAR; a mordida no pescoço infecta sempre. Infectado, sobe
## até 100 em INFECCAO_TEMPO s e mata; o antibiótico tira CURA_ANTIBIOTICO e para de subir.
const CHANCE_INFECTAR: float = 0.12
const INFECCAO_TEMPO: float = 720.0
const CURA_ANTIBIOTICO: int = 60
var infeccao: float = 0.0
var infectado: bool = false
signal infectou
var sede: float = 100.0
var comida: int:
	get:
		return mochila.conta("comida")
	set(v):
		mochila.definir("comida", v)
var agua: int:
	get:
		return mochila.conta("agua")
	set(v):
		mochila.definir("agua", v)
var _fome_t: float = INTERVALO_FOME
## Parte de cima do corpo (mirar/atirar/recarregar) por cima das pernas; vai pela rede.
var cima_rede: String = ""

var agachado: bool = false
## Mira travada: o corpo fica virado para onde a câmera olha e anda de lado/de costas (modo tiro).
var mira_travada: bool = false
var correndo: bool = false
var camera: CameraPrimeira
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
	add_to_group("golpeavel")  # só vale no PvP (levar_golpe confere)
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
	# começa com facão, pistola, lanterna (provisório) e um pente de reserva
	mochila.adicionar("facao", 1)
	mochila.adicionar("pistola", 1)
	if tem_lanterna:
		mochila.adicionar("lanterna", 1)
	pistola.reserva = Pistola.RESERVA_INICIAL
	mochila.mudou.connect(func() -> void:
		tem_lanterna = mochila.tem("lanterna")
		if arma != "facao" and not mochila.tem(arma):
			arma = "facao"  # largou/perdeu a arma da mão: volta para o facão
		_copia_t = minf(_copia_t, 0.5))  # manda a cópia ao servidor logo
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
		camera = CameraPrimeira.new()
		camera.alvo = self
		camera.yaw = modelo.rotation.y - PI
		add_child(camera)
		_so_sombra.call_deferred()
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
	sync.replication_interval = 1.0 / 20.0  # quem recebe suaviza (_segue_rede); 30/s pesava no servidor grátis
	sync.replication_config = cfg
	sync.set_multiplayer_authority(get_multiplayer_authority())  # criado depois: herda o dono à mão
	sync.add_visibility_filter(_visivel_para)  # PvP: só quem está na mesma sala vê (o spawner segue isso)
	add_child(sync)


func _visivel_para(peer: int) -> bool:
	var principal := get_tree().get_first_node_in_group("principal") if is_inside_tree() else null
	return peer == 1 or principal == null or principal.mesma_sala(peer, get_multiplayer_authority())


func _monta_modelo() -> void:
	modelo = Anims.boneco(Anims.JOGADOR)  # personagem fixo por enquanto (editor de personagem: depois)
	add_child(modelo)
	anim = AnimationPlayer.new()
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL  # avançado em _process
	modelo.add_child(anim)
	anim.add_animation_library("", Anims.adaptada(Anims.biblioteca(), Anims.JOGADOR))
	_toca("parado", 0.0)


# facão provisório (espada curta do pacote de props) na mão direita
func _monta_arma() -> void:
	_esq = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var osso := BoneAttachment3D.new()
	osso.bone_name = MAO
	_esq.add_child(osso)
	# as posições das armas foram medidas na mão do X Bot: no personagem novo a mão tem outros eixos, então
	# um nó de ajuste gira o espaço da mão dele para o do X Bot
	var mao := Node3D.new()
	mao.basis = Anims.ajuste_osso(_esq, MAO)
	osso.add_child(mao)
	_facao = Node3D.new()  # suporte da arma branca na mão (o modelo vem de Armas)
	# a ponta (+Z do modelo pronto) aponta para a frente da mão (medido na pose parada do X Bot)
	_facao.quaternion = Quaternion(Vector3.BACK, Vector3(0.975, 0.126, 0.185).normalized())
	_facao.add_child(Armas.modelo("facao"))
	mao.add_child(_facao)
	pistola = Pistola.new()
	pistola.name = "Pistola"
	pistola.dono = self
	var z: Vector3 = PISTOLA_FRENTE.normalized()
	var x: Vector3 = PISTOLA_CIMA.cross(z).normalized()
	pistola.basis = Basis(x, z.cross(x), z)  # cano (+Z) para a frente, ferrolho (+Y) para cima
	pistola.position = PISTOLA_POS
	mao.add_child(pistola)
	smg = Pistola.new()
	smg.tipo = "smg"
	smg.name = "Smg"
	smg.dono = self
	smg.basis = pistola.basis
	smg.position = PISTOLA_POS
	mao.add_child(smg)
	arma = arma  # aplica a visibilidade


func _physics_process(dt: float) -> void:
	if not local:
		_segue_rede(dt)
		return
	if vida <= 0:
		_caido(dt)
		return
	if _subindo >= 0.0:
		_escala(dt)
		return
	if deitado:
		_cama(dt)
		_passa_fome(dt)
		pos_rede = global_position
		clipe_rede = _clipe
		return
	if mordida_t > 0.0 and mordida_zumbi:  # zumbi no pescoço: não anda, só briga para se soltar
		_passa_mordida(dt)
		_passa_fome(dt)
		if not is_on_floor():
			velocity.y -= GRAVIDADE * dt
		move_and_slide()
		pos_rede = global_position
		clipe_rede = _clipe
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
	_abre_bau(dt, mov)
	_fabrica(dt)
	_copia_t -= dt
	if _copia_t <= 0.0 and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_copia_t = 5.0
		_copia.rpc_id(1, conteudo_para_saco(mochila, _balas_pentes()))
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
		if e_fogo(arma):
			_troca_arma(_ultima_branca if mochila.tem(_ultima_branca) else "facao")
		else:
			_troca_arma(_ultima_fogo if mochila.tem(_ultima_fogo) else ("pistola" if mochila.tem("pistola") else "smg"))
	if String(entrada.get("arma", "")) != "":
		_troca_arma(String(entrada["arma"]))
		entrada["arma"] = ""
	if entrada.get("recarregar", false):
		entrada["recarregar"] = false
		if e_fogo(arma):
			fogo().recarregar()
	if entrada.get("modo", false):
		entrada["modo"] = false
		if arma == "smg":
			smg.modo_auto = not smg.modo_auto
			item_pego.emit("modo_auto" if smg.modo_auto else "modo_semi", 0)
	if entrada.get("atacar", false):
		entrada["atacar"] = false
		if e_fogo(arma):
			_atira()
		else:
			_pede_golpe()
	elif arma == "smg" and smg.modo_auto and entrada.get("atirando", false):
		_atira()  # automático: segurando o gatilho, a cadência da arma faz a rajada
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

	agarrado_t -= get_physics_process_delta_time()
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
	if agarrado_t > 0.0:
		alvo_vel *= 0.45  # agarrado pelo zumbi policial
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
	elif _subindo < 0.0 and _beirada(mov):
		_subindo = 0.0  # pulou e quase alcançou: agarra a beirada e sobe com os braços
		_golpe = -1
		mira_travada = false

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
	if not mira_travada or not e_fogo(arma) or vida <= 0:
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


## Dinheiro do jogo (nada com dinheiro real) e quantos zumbis já matou. Por enquanto no aparelho (prompt 16: conta).
var dinheiro: int = 0
var abates: int = 0
func lojista_perto() -> Lojista:
	if vida <= 0:
		return null
	var principal := get_tree().get_first_node_in_group("principal")
	for l: Lojista in get_tree().get_nodes_in_group("lojista"):
		if l.perto(global_position) and (principal == null or principal.pode_usar(l, nick)):
			return l
	return null


## Compra `lotes` do que o lojista vende. Falha sem dinheiro, longe dele ou sem espaço na mochila.
func comprar(tipo: String, lotes: int = 1) -> bool:
	if lojista_perto() == null or not Lojista.VENDE.has(tipo) or lotes <= 0:
		return false
	var qtd: int = int(Lojista.VENDE[tipo][0]) * lotes
	var preco: int = int(Lojista.VENDE[tipo][1]) * lotes
	if dinheiro < preco or mochila.adicionar(tipo, 0) < 0:
		return false
	var coube: int = mochila.adicionar(tipo, qtd)
	if coube < qtd:  # não coube tudo: devolve e não compra
		mochila.tirar(tipo, coube)
		return false
	dinheiro -= preco
	return true


## Vende `qtd` do espaço `i` da mochila para o lojista (qtd < 0 = tudo). Devolve quanto recebeu.
func vender(i: int, qtd: int = -1) -> int:
	var e: Variant = mochila.espacos[i]
	if lojista_perto() == null or e == null or e.tipo in Mochila.PRESOS or Lojista.paga(e.tipo, 1) <= 0:
		return 0
	var n: int = int(e.qtd) if qtd < 0 else mini(qtd, int(e.qtd))
	var tipo: String = e.tipo
	e.qtd = int(e.qtd) - n
	if int(e.qtd) <= 0:
		mochila.espacos[i] = null
	mochila.mudou.emit()
	var valor: int = Lojista.paga(tipo, n)
	dinheiro += valor
	return valor


signal loja_aberta


## Receitas aprendidas (nomes das armas). Por enquanto no aparelho; vão para a conta no prompt 16.
var receitas: Array[String] = []
## Fabricando: segundos que faltam (> 0), qual arma e quantas.
var fabrica_t: float = 0.0
var _fabrica_arma: String = ""
var _fabrica_n: int = 0
signal bancada_aberta
signal fabricou(arma: String, n: int)


func bancada_perto() -> Bancada:
	if vida <= 0:
		return null
	var principal := get_tree().get_first_node_in_group("principal")
	for b: Bancada in get_tree().get_nodes_in_group("bancada"):
		if b.perto(global_position) and (principal == null or principal.pode_usar(b, nick)):
			return b
	return null


## Começa a fabricar `n` da arma (precisa saber a receita, estar na bancada e ter as peças).
func comeca_fabricar(arma: String, n: int) -> bool:
	if not arma in receitas or bancada_perto() == null or n <= 0 or Receitas.quantas(mochila, arma) < n or fabrica_t > 0.0:
		return false
	_fabrica_arma = arma
	_fabrica_n = n
	fabrica_t = Receitas.FABRICAR_T * n
	return true


func _fabrica(dt: float) -> void:
	if fabrica_t <= 0.0:
		return
	if bancada_perto() == null:
		fabrica_t = 0.0  # saiu da bancada: cancela (as peças não foram gastas)
		return
	fabrica_t -= dt
	if fabrica_t <= 0.0:
		fabrica_t = 0.0
		var feitas: int = Receitas.fabrica(mochila, _fabrica_arma, _fabrica_n)
		fabricou.emit(_fabrica_arma, feitas)


## Baú perto (para o botão ABRIR).
func bau_perto() -> Bau:
	return Bau.perto(get_tree(), global_position, self) if vida > 0 else null


## Abrindo baú: segundos que faltam (> 0 = abrindo) e qual.
var abrindo_t: float = 0.0
var abrindo: Bau
## Avisa a tela que o baú abriu.
signal bau_aberto(b: Bau)


## Pede ao servidor o item `i` do baú (i < 0 = tudo).
func pega_do_bau(b: Bau, i: int) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		b.pega_por(self, i)
	else:
		_pede_bau.rpc_id(1, get_path_to(b), i)


## Guarda o espaço `i` da mochila no baú da facção (tira daqui; o servidor põe lá ou devolve).
func guarda_no_bau(b: Bau, i: int) -> void:
	var e: Variant = mochila.espacos[i]
	if e == null or e.tipo in Mochila.PRESOS or not b.de_faccao:
		return
	var tipo: String = e.tipo
	var qtd: int = int(e.qtd)
	mochila.espacos[i] = null
	mochila.mudou.emit()
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		b.guarda_por(self, tipo, qtd)
	else:
		_pede_guardar.rpc_id(1, get_path_to(b), tipo, qtd)


@rpc("any_peer", "call_remote", "reliable")
func _pede_guardar(caminho: NodePath, tipo: String, qtd: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		var b := get_node_or_null(caminho) as Bau
		if b:
			b.guarda_por(self, tipo, qtd)


@rpc("any_peer", "call_remote", "reliable")
func _pede_bau(caminho: NodePath, i: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		var b := get_node_or_null(caminho) as Bau
		if b:
			b.pega_por(self, i)


# abre o baú parado; andar, cair ou se afastar cancela
func _abre_bau(dt: float, mov: Vector2) -> void:
	if abrindo == null:
		return
	if mov.length() > 0.2 or vida <= 0 or bau_perto() != abrindo:
		abrindo = null
		abrindo_t = 0.0
		return
	abrindo_t -= dt
	if abrindo_t <= 0.0:
		bau_aberto.emit(abrindo)
		abrindo = null


# USAR: pega o item perto; senão abre o baú perto; senão abre/fecha a porta perto
func _tenta_pegar() -> void:
	var it: Item = item_perto()
	if it == null and bau_perto() != null:
		abrindo = bau_perto()
		abrindo_t = Bau.ABRIR_T
		return
	if it == null and bancada_perto() != null:
		bancada_aberta.emit()
		return
	if it == null and lojista_perto() != null:
		loja_aberta.emit()
		return
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
	if tipo == "dinheiro":
		dinheiro += qtd
		item_pego.emit(tipo, qtd)
		return
	if tipo == "abate":
		abates += qtd  # registro de zumbis mortos (sem nível: só o número)
		return
	var coube: int = mochila.adicionar(tipo, qtd)
	if coube < qtd:
		_larga_no_chao(tipo, qtd - coube)  # o que não coube volta para o chão
	if coube > 0:
		item_pego.emit(tipo, coube)


## Larga o que está no espaço `i` da mochila no chão, à frente (facão e pistola não saem).
func largar(i: int) -> void:
	var e: Dictionary = mochila.tirar_espaco(i)
	if not e.is_empty():
		_larga_no_chao(e.tipo, e.qtd)


## Barra rápida: arma vai para a mão; comida e água são consumidas.
func usar_espaco(i: int) -> void:
	var e: Variant = mochila.espacos[i]
	if e == null:
		return
	if Armas.e_branca(String(e.tipo)) or e_fogo(String(e.tipo)):
		entrada["arma"] = e.tipo
		return
	var ensina: String = Receitas.arma_de(String(e.tipo))
	if ensina != "":
		if not ensina in receitas:
			receitas.append(ensina)
			mochila.tirar(String(e.tipo), 1)  # aprendeu: a receita some
			item_pego.emit("aprendeu", 0)
		return
	match String(e.tipo):
		"comida":
			entrada["comer"] = true
		"agua":
			entrada["beber"] = true
		"antibiotico":
			toma_antibiotico()


func _larga_no_chao(tipo: String, qtd: int) -> void:
	var frente: Vector3 = -camera.cam.global_basis.z if camera else modelo.global_basis.z
	frente.y = 0.0
	var pos: Vector3 = global_position + frente.normalized() * 0.9
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		get_tree().get_first_node_in_group("principal").solta_item(tipo, qtd, pos)
	else:
		_pede_largar.rpc_id(1, tipo, qtd, pos)


@rpc("any_peer", "call_remote", "reliable")
func _pede_largar(tipo: String, qtd: int, pos: Vector3) -> void:
	# roda no servidor: só o dono pede, e só perto de onde ele está
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority() \
			and pos.distance_to(global_position) < 2.5 and qtd > 0 and qtd <= 96 and Mochila.NOMES.has(tipo):
		get_tree().get_first_node_in_group("principal").solta_item(tipo, qtd, pos)


## Avisa o HUD que pegou algo.
signal item_pego(tipo: String, qtd: int)


## Dano de zumbi (ou, depois, de outro jogador). Quem bate pode estar em outro aparelho: o dano vai para o dono.
## Agarrado (soco do zumbi policial): anda bem mais devagar por `t` s. Quem manda no movimento é o dono do jogador.
## Mordida no pescoço (Zumbi._segura_mordida): parado, câmera presa no zumbi; ACERTOS_SOLTAR toques com o marcador
## na faixa certa soltam. `qte_pos` 0..1 vai e volta; `qte_faixa` = [início, tamanho].
const ACERTOS_SOLTAR: int = 3
const MORDIDA_INFECCAO: float = 25.0
var mordida_t: float = 0.0
var mordida_zumbi: Node3D
var qte_pos: float = 0.0
var qte_faixa: Vector2 = Vector2(0.4, 0.2)
var qte_acertos: int = 0
var _qte_fase: float = 0.0
signal mordida_fim(escapou: bool)


## Servidor: o zumbi agarrou para morder (avisa o dono do jogador).
func comeca_mordida(z: Node3D) -> void:
	mordida_t = 0.1  # o servidor já sabe (não deixa outro zumbi começar junto)
	if is_multiplayer_authority():
		_inicia_mordida(z)
	else:
		_rede_mordida.rpc_id(get_multiplayer_authority(), get_tree().get_first_node_in_group("principal").get_path_to(z))


@rpc("any_peer", "call_remote", "reliable")
func _rede_mordida(caminho: NodePath) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		var z := get_tree().get_first_node_in_group("principal").get_node_or_null(caminho) as Node3D
		if z:
			_inicia_mordida(z)


func _inicia_mordida(z: Node3D) -> void:
	mordida_zumbi = z
	mordida_t = Zumbi.MORDIDA_T - 0.3  # um pouco antes do servidor: o resultado chega a tempo
	qte_acertos = 0
	_qte_fase = randf() * TAU
	_nova_faixa()
	mira_travada = false
	if camera:
		camera.foco = z
		camera.tremer(0.5)
	_toca_som("impactPunch_heavy_000", 0.0)


func _nova_faixa() -> void:
	var tam: float = 0.22 - qte_acertos * 0.04  # cada acerto a faixa fica menor
	qte_faixa = Vector2(randf_range(0.05, 0.95 - tam), tam)


# roda no dono: marcador indo e voltando cada vez mais rápido; toque (entrada "soltar") dentro da faixa conta
func _passa_mordida(dt: float) -> void:
	mordida_t -= dt
	_qte_fase += dt * (3.2 + qte_acertos * 1.1)
	qte_pos = 0.5 + 0.5 * sin(_qte_fase)
	velocity.x = 0.0
	velocity.z = 0.0
	if entrada.get("soltar", false):
		entrada["soltar"] = false
		if qte_pos >= qte_faixa.x and qte_pos <= qte_faixa.x + qte_faixa.y:
			qte_acertos += 1
			if camera:
				camera.tremer(0.35)
			_toca_som("impactPunch_heavy_001", -4.0)
			if qte_acertos >= ACERTOS_SOLTAR:
				_fim_mordida(true)
				return
			_nova_faixa()
		else:
			mordida_t -= 0.5  # errou o tempo: o zumbi chega mais perto do pescoço
	if mordida_t <= 0.0:
		_fim_mordida(false)


func _fim_mordida(escapou: bool) -> void:
	mordida_t = 0.0
	if camera:
		camera.foco = null
	if mordida_zumbi and is_instance_valid(mordida_zumbi):
		mordida_zumbi.resultado_mordida.rpc_id(1, escapou)
		if escapou:
			var d: Vector3 = global_position - mordida_zumbi.global_position
			velocity += Vector3(d.x, 0, d.z).normalized() * 4.0  # empurrou e se afastou
	mordida_zumbi = null
	mordida_fim.emit(escapou)


## Servidor: o zumbi mordeu (dano e infecção certa, no dono).
func mordido(dano: int) -> void:
	mordida_t = 0.0
	if is_multiplayer_authority():
		_recebe_mordida(dano)
	else:
		_rede_mordido.rpc_id(get_multiplayer_authority(), dano)


@rpc("any_peer", "call_remote", "reliable")
func _rede_mordido(dano: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_recebe_mordida(dano)


func _recebe_mordida(dano: int) -> void:
	if mordida_t > 0.0:
		_fim_mordida(false)
	infecta(MORDIDA_INFECCAO)
	_recebe_dano(dano, Vector3.ZERO)
	if camera:
		camera.tremer(1.0)


var agarrado_t: float = 0.0
func agarrar(t: float) -> void:
	if is_multiplayer_authority():
		agarrado_t = maxf(agarrado_t, t)
	else:
		_rede_agarra.rpc_id(get_multiplayer_authority(), t)


@rpc("any_peer", "call_remote", "reliable")
func _rede_agarra(t: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		agarrado_t = maxf(agarrado_t, minf(t, 5.0))


## Tiro/golpe de outro jogador (no aparelho de quem acertou): no PvP pede o dano ao servidor, que confere a sala.
func levar_golpe(dano: int, dir: Vector3, quem: Node) -> void:
	var principal := get_tree().get_first_node_in_group("principal")
	if quem is Jogador and quem != self and principal and principal.em_pvp():
		principal.pede_dano_pvp.rpc_id(1, int(String(name)), dano, dir)


## Servidor → dono: (re)nasce no PvP em `pos`, com a vida cheia (sem largar nada).
func renasce_pvp(pos: Vector3) -> void:
	_morto_t = 0.0
	resgate = false
	global_position = pos
	velocity = Vector3.ZERO
	vida = VIDA_MAX
	reset_physics_interpolation()
	_toca("parado", 0.0)
	pos_rede = global_position


## Pegou a infecção (golpe de zumbi com azar, ou mordida: `mais` já soma na barra).
func infecta(mais: float) -> void:
	if not infectado:
		infectado = true
		infectou.emit()
	infeccao = minf(100.0, infeccao + mais)


func toma_antibiotico() -> void:
	if infeccao <= 0.0 or not mochila.tem("antibiotico"):
		return
	mochila.tirar("antibiotico", 1)
	infeccao = maxf(0.0, infeccao - CURA_ANTIBIOTICO)
	infectado = false  # parou de subir; outro golpe com azar infecta de novo
	item_pego.emit("antibiotico", 1)


func levar_dano(dano: int, dir: Vector3) -> void:
	dano_srv_t = Time.get_ticks_msec() / 1000.0
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
	if randf() < CHANCE_INFECTAR:
		infecta(0.0)
	velocity += Vector3(dir.x, 0, dir.z) * 3.0  # empurrão
	_toca_som("impactPunch_heavy_00%d" % (randi() % 2), -2.0)
	if camera:
		camera.tremer(0.25)
	dano_levado.emit(dano)
	if vida == 0:
		_cai()


func _passa_fome(dt: float) -> void:
	if infectado and vida > 0:
		infeccao = minf(100.0, infeccao + 100.0 / INFECCAO_TEMPO * dt)
		if infeccao >= 100.0:
			vida = 0  # a infecção venceu
			_cai()
			return
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
	pistola.recarregando = false
	smg.recarregando = false
	_toca("morte", 0.1)
	if not is_multiplayer_authority():
		return
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and principal.em_pvp():
		_morto_t = Salas.RENASCE_T + 1.5  # o servidor manda renascer antes; isto é só se a mensagem não vier
		return  # no PvP não larga nada
	if principal and principal.grupo_de(int(String(name))) != 0:
		# no grupo: espera o resgate (o servidor confere e solta a raid); só larga tudo se não der
		resgate = true
		_morto_t = RESGATE_T
		_copia_agora()
		principal.pede_resgate.rpc_id(1)
	else:
		_larga_tudo()


# cópia da mochila no servidor agora (a raid mede o valor dela; sair no meio larga essa cópia)
func _copia_agora() -> void:
	var tudo: Array = conteudo_para_saco(mochila, _balas_pentes())
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		copia_mochila = tudo
	else:
		_copia.rpc_id(1, tudo)


## Cama da casa da facção (prompt 13): perto dela aparece DEITAR (PC J); deitado cura CURA_CAMA por segundo,
## qualquer movimento levanta.
const CURA_CAMA: float = 8.0
var deitado: bool = false
var _cura_acum: float = 0.0
var _cama_de: Vector3


## A cama da casa da minha facção a menos de 1,8 m (posição dela), ou Vector3.INF.
func cama_perto() -> Vector3:
	var principal := get_tree().get_first_node_in_group("principal")
	var f: String = principal.faccao_de(nick) if principal else ""
	if f == "" or vida <= 0:
		return Vector3.INF
	for c: Node3D in get_tree().get_nodes_in_group("camas"):
		if String(c.get_parent().name) == String(principal._faccoes_cli.f[f].casa) and c.global_position.distance_to(global_position) < 1.8:
			return c.global_position
	return Vector3.INF


## Deita na cama (ou levanta, se já está deitado).
func deitar() -> void:
	if deitado:
		deitado = false
		global_position = _cama_de
		return
	var c: Vector3 = cama_perto()
	if c == Vector3.INF:
		return
	_cama_de = global_position
	deitado = true
	if not agachado:
		_alterna_agachar()  # olhos baixos, como deitado
	global_position = c + Vector3(0, 0.62, 0)


func _cama(dt: float) -> void:
	if not deitado:
		return
	velocity = Vector3.ZERO
	if (entrada.get("move", Vector2.ZERO) as Vector2).length() > 0.3 or vida <= 0:
		deitar()  # mexeu: levanta
		return
	_cura_acum += CURA_CAMA * dt
	if _cura_acum >= 1.0:
		vida = mini(VIDA_MAX, vida + int(_cura_acum))
		_cura_acum -= int(_cura_acum)


## Caído esperando o grupo (prompt 10): não larga nada até o tempo acabar.
const RESGATE_T: float = 90.0
const RESGATE_VIDA: int = 30
var resgate: bool = false


## Servidor → dono: o grupo não está perto o bastante; morte normal.
@rpc("authority", "call_local", "reliable")
func sem_resgate() -> void:
	if resgate and vida <= 0:
		resgate = false
		_morto_t = RENASCE
		_larga_tudo()


## Servidor → dono: o grupo matou a raid; levanta com pouca vida onde caiu.
@rpc("authority", "call_local", "reliable")
func levanta() -> void:
	if resgate and vida <= 0:
		resgate = false
		vida = RESGATE_VIDA
		_morto_t = 0.0
		_toca("parado", 0.2)


## Tudo da mochila (menos o facão) vira um saco no chão onde caiu; as balas do pente vão junto.
func _larga_tudo() -> void:
	var tudo: Array = conteudo_para_saco(mochila, _balas_pentes())
	for i in Mochila.ESPACOS:
		var e: Variant = mochila.espacos[i]
		if e and e.tipo != "facao":
			mochila.espacos[i] = null
	if not mochila.tem("pistola"):
		pistola.balas = 0
	if not mochila.tem("smg"):
		smg.balas = 0
	mochila.mudou.emit()
	if tudo.is_empty():
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		get_tree().get_first_node_in_group("principal").solta_saco(tudo, global_position)
	else:
		_pede_saco.rpc_id(1, tudo)


## O que vai para o saco: tudo menos o facão, juntando o mesmo tipo; `pente` = balas na pistola.
static func conteudo_para_saco(m: Mochila, pente: int) -> Array:
	var junta: Dictionary = {}
	for e: Variant in m.espacos:
		if e and e.tipo != "facao":
			junta[e.tipo] = int(junta.get(e.tipo, 0)) + int(e.qtd)
	if pente > 0 and (junta.has("pistola") or junta.has("smg")):
		junta["municao"] = int(junta.get("municao", 0)) + pente
	var out: Array = []
	for t: String in junta:
		out.append({"tipo": t, "qtd": junta[t]})
	return out


@rpc("any_peer", "call_remote", "reliable")
func _pede_saco(tudo: Array) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority() and tudo.size() <= Mochila.ESPACOS:
		get_tree().get_first_node_in_group("principal").solta_saco(tudo, global_position)


## Servidor: última cópia da mochila deste jogador (o dono manda) e quando levou dano pela última vez —
## para largar o saco se ele sair do jogo caído ou em luta.
var copia_mochila: Array = []
var dano_srv_t: float = -99.0
var _copia_t: float = 0.0


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _copia(tudo: Array) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority() and tudo.size() <= Mochila.ESPACOS:
		copia_mochila = tudo


## Escalar (sugestão do dono): no ar, empurrando para a frente, com parede na frente e o alto dela entre
## BEIRADA_MIN e BEIRADA_MAX acima dos pés e lugar em pé lá em cima → agarra e sobe em ESCALAR_T.
const ESCALAR_T: float = 1.1
const BEIRADA_MIN: float = 0.6
const BEIRADA_MAX: float = 2.0
var _subindo: float = -1.0
var _sobe_de: Vector3
var _sobe_ate: Vector3


func _beirada(mov: Vector2) -> bool:
	if mov.y < 0.3 or velocity.y > 2.5 or agachado:
		return false
	var fr: Vector3 = -camera.cam.global_basis.z if camera else modelo.global_basis.z
	fr.y = 0.0
	if fr.length() < 0.1:
		return false
	fr = fr.normalized()
	var esp := get_world_3d().direct_space_state
	var pe: Vector3 = global_position
	var q := PhysicsRayQueryParameters3D.create(pe + Vector3(0, 0.9, 0), pe + Vector3(0, 0.9, 0) + fr * (RAIO + 0.45), 1)
	q.exclude = [get_rid()]
	var parede: Dictionary = esp.intersect_ray(q)
	if parede.is_empty():
		return false
	var cima: Vector3 = parede.position + fr * 0.35
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(cima.x, pe.y + BEIRADA_MAX + 0.3, cima.z), Vector3(cima.x, pe.y + BEIRADA_MIN, cima.z), 1)
	q2.exclude = [get_rid()]
	var topo: Dictionary = esp.intersect_ray(q2)
	if topo.is_empty() or (topo.normal as Vector3).y < 0.7:
		return false
	var h: float = (topo.position as Vector3).y - pe.y
	if h < BEIRADA_MIN or h > BEIRADA_MAX:
		return false
	var q3 := PhysicsRayQueryParameters3D.create(topo.position + Vector3(0, 0.05, 0), topo.position + Vector3(0, ALTURA_EM_PE, 0), 1)
	q3.exclude = [get_rid()]
	if not esp.intersect_ray(q3).is_empty():
		return false  # sem lugar para ficar em pé lá em cima
	_sobe_de = pe
	_sobe_ate = topo.position + Vector3(0, 0.03, 0) + fr * 0.15
	return true


# sobe primeiro (braços puxando) e só no fim vai para a frente, por cima da beirada
func _escala(dt: float) -> void:
	_subindo += dt
	var t: float = clampf(_subindo / ESCALAR_T, 0.0, 1.0)
	var sobe: float = smoothstep(0.0, 0.7, t)
	var vai: float = smoothstep(0.55, 1.0, t)
	global_position = Vector3(lerpf(_sobe_de.x, _sobe_ate.x, vai), lerpf(_sobe_de.y, _sobe_ate.y, sobe), lerpf(_sobe_de.z, _sobe_ate.z, vai))
	velocity = Vector3.ZERO
	if anim.has_animation("escalar"):
		_toca("escalar", 0.1)
		anim.speed_scale = anim.get_animation("escalar").length / ESCALAR_T
	if t >= 1.0:
		_subindo = -1.0
		anim.speed_scale = 1.0
	pos_rede = global_position
	clipe_rede = _clipe
	cima_rede = ""


func _caido(dt: float) -> void:
	_morto_t -= dt
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * dt)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * dt)
	velocity.y -= GRAVIDADE * dt
	move_and_slide()
	if _morto_t <= 0.0 and resgate:
		resgate = false  # o resgate não veio a tempo: morte normal
		_larga_tudo()
	if _morto_t <= 0.0:
		var principal := get_tree().get_first_node_in_group("principal")
		if principal and principal.em_pvp():
			inicio = principal.ponto_pvp()
		elif principal and principal.nascer_no_bairro and principal.bairro:
			inicio = principal.ponto_nascer(nick)  # casa da facção, ou um lugar sorteado (75% bom)
		global_position = inicio
		velocity = Vector3.ZERO
		vida = VIDA_MAX
		infeccao = 0.0
		infectado = false
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
	if Rede.servidor_sem_tela:
		return
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
	elif _clipe_mirando() != "trote":
		clipe = _clipe_mirando()  # de lado ou de costas (para a frente usa andar/trote/correr)
	elif mira_travada:
		clipe = "trote"
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
	if nova == arma or _golpe >= 0 or not mochila.tem(nova):
		return
	arma = nova
	pistola.recarregando = false  # trocar cancela a recarga
	if smg:
		smg.recarregando = false


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
	var f: Pistola = fogo()
	if not f.pronta() and f.balas > 0:
		return
	var yaw: float = camera.yaw if camera else modelo.rotation.y - PI
	modelo.rotation.y = yaw + PI  # vira para a mira na hora do tiro
	var r: Array[Vector3] = raio_mira()
	var res: Dictionary = f.atirar(r[0], r[1], mira_travada)
	if not res.atirou:
		return
	_encara = 0.7
	_tiro_t = 0.0
	if multiplayer.is_server():  # quem roda os zumbis ouve aqui; os tiros dos clientes chegam por _rede_tiro
		Zumbi.barulho(get_tree(), global_position, Pistola.BARULHO)
	if camera:
		camera.coice(f.coice)
	if res.acertou is Zumbi:
		var z: Zumbi = res.acertou
		# no servidor a vida já caiu; no cliente o dano ainda vai chegar: prevê se matou
		var morreu: bool = z.vida <= 0 if multiplayer.is_server() else z.vida - f.dano * (2 if res.cabeca else 1) <= 0
		_confirma_acerto(res.cabeca or morreu, res.cabeca)
	elif res.acertou is Jogador:
		_confirma_acerto(res.cabeca, res.cabeca)
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		for peer: int in multiplayer.get_peers():  # só quem vê este jogador (sala de PvP)
			if _visivel_para(peer):
				_rede_tiro.rpc_id(peer, res.ponto, res.acertou != null, res.carne)


@rpc("authority", "call_remote", "unreliable")
func _rede_tiro(ponto: Vector3, bateu: bool, carne: bool) -> void:
	fogo().efeito(ponto, bateu, carne)
	if multiplayer.is_server():
		Zumbi.barulho(get_tree(), global_position, Pistola.BARULHO)


## O corpo fica virado para a câmera? (mirando, logo depois do tiro, ou com a pistola sem correr)
func olha_camera() -> bool:
	return true  # primeira pessoa: o corpo sempre vira junto com o olhar (os outros veem andar de lado/de costas)


# primeira pessoa: o próprio corpo (com as armas e a lanterna da mão) some da tela mas continua fazendo sombra
func _so_sombra() -> void:
	for g: GeometryInstance3D in modelo.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


# pose da parte de cima: recarregar > tiro recente > mirando/encarando > segurando a pistola
func _escolhe_cima() -> String:
	if not e_fogo(arma) or vida <= 0:
		return ""
	if fogo().recarregando:
		return "pistola_recarga"
	if _tiro_t < maxf(0.18, COICE_DURA):
		return "pistola_tiro"
	# como na maioria dos jogos: arma baixa e relaxada andando/parado (o clipe "_p" da locomoção); braços
	# esticados apontando só mirando ou logo depois de atirar
	if mira_travada or entrada.get("mira_segurando", false) or _tiro_t < MIRA_DEPOIS_TIRO:
		return "pistola_mira"
	return ""


## Segundos com a arma apontada depois do último tiro (depois volta para a guarda baixa).
const MIRA_DEPOIS_TIRO: float = 1.2


func _process(dt: float) -> void:
	if Rede.servidor_sem_tela:
		return  # animação, braços e lanterna são só para ver
	anim.advance(dt)
	_atualiza_lanterna()
	var cima: String = cima_rede if not local else _escolhe_cima()
	if cima != _cima_clipe:
		if cima != "":
			_cima_t = 0.0
		if cima != "" or _cima_peso <= 0.01:
			_cima_clipe = cima if cima != "" else _cima_clipe
	_cima_peso = move_toward(_cima_peso, 1.0 if cima != "" else 0.0, dt * 8.0)
	var em_guarda: bool = not mira_travada and _tiro_t > 0.6 and not fogo().recarregando
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
	# modelo "Flashlight" (mar.cos., Sketchfab): no arquivo fica deitado na diagonal, cabeça para EIXO_ARQ;
	# aqui o eixo +Y é para onde aponta, com a cabeça em y = 0,125
	var m := (load("res://assets/sketchfab/lanterna.glb") as PackedScene).instantiate() as Node3D
	const EIXO_ARQ := Vector3(0.9276, 0.0383, 0.3716)
	const CENTRO_ARQ := Vector3(0.0211, 0.0141, 0.0093)
	const K := 1.5  # 13 cm no arquivo -> 20 cm
	var r := Basis(Quaternion(EIXO_ARQ.normalized(), Vector3.UP))
	m.transform = Transform3D(r.scaled(Vector3.ONE * K), Vector3(0, 0.125 - 0.059 * K, 0) - r * CENTRO_ARQ * K)
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lanterna_mao.add_child(m)
	var lente := StandardMaterial3D.new()
	lente.albedo_color = Color(1, 0.95, 0.8)
	lente.emission_enabled = true
	lente.emission = Color(1, 0.93, 0.75)
	_lente = _cilindro(0.03, 0.004, Vector3(0, 0.126, 0), lente)  # vidro que acende à noite
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
		if camera:
			# primeira pessoa: a luz sai de perto do olho, um pouco à esquerda, para onde se olha
			var b: Basis = camera.cam.global_basis
			_lanterna.global_position = camera.cam.global_position + b * Vector3(-0.2, -0.15, 0.0)
			_lanterna.global_basis = b
		else:
			var frente: Vector3 = modelo.global_basis.z
			frente.y = 0.0
			var p: float = 0.0  # os outros não mandam o olhar vertical: luz reta para a frente
			var dir: Vector3 = (frente.normalized() * cos(p) - Vector3.UP * sin(p)).normalized()
			_lanterna.global_position = _ponta.global_position
			_lanterna.global_basis = Basis.looking_at(dir)  # SpotLight ilumina para -Z, que é o looking_at


# sobrepõe nos ossos de cima a pose do clipe da pistola (as pernas continuam com a locomoção)
func _aplica_cima(clipe: String, t: float, peso: float) -> void:
	var a: Animation = anim.get_animation(clipe)
	if a == null:
		return
	if clipe == "pistola_recarga":
		t = t * a.length / fogo().recarga  # encaixa o clipe no tempo da recarga
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
	_golpe_dur = anim.get_animation(c).length / _vel_golpe()
	_clipe = c
	anim.play(c, 0.08)
	anim.speed_scale = _vel_golpe()
	var som: String = String(Armas.BRANCAS.get(arma, Armas.BRANCAS.facao).som)
	_toca_som(som if i != 1 or som != "knifeSlice" else "knifeSlice2", -4.0)


func _vel_golpe() -> float:
	return float(Armas.BRANCAS.get(arma, Armas.BRANCAS.facao).vel)


func _atualiza_golpe(dt: float) -> void:
	if _golpe < 0:
		return
	if _parada > 0.0:
		_parada -= dt
		anim.speed_scale = 0.0 if _parada > 0.0 else _vel_golpe()
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
	var a: Dictionary = Armas.BRANCAS.get(arma, Armas.BRANCAS.facao)
	g = g.duplicate()
	g.dano = int(a.dano[clampi(_golpe, 0, 2)])
	g.alcance = float(a.alcance)
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
		alvo.call("levar_golpe", int(g.dano), d.normalized() * float(a.empurra), self)
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
	if e_fogo(arma) and anim.has_animation(clipe + "_p"):
		clipe += "_p"  # mesma ação segurando a pistola
	if clipe == _clipe:
		return
	_clipe = clipe
	anim.play(clipe, mistura)


## Clipe tocando agora (para testes e depuração).
func clipe_atual() -> String:
	return _clipe
