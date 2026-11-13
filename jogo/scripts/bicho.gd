# Bichos da floresta (13/11, dono: "inimigos: zumbis, sobreviventes e a própria floresta... animais"): lobo (anda em
# bando, cerca e morde; vê mais de noite), urso (raro, aguenta muito tiro, ataca quem chega perto) e cervo (alce: foge;
# é a caça). 13/11 (dono: "modelos prontos de verdade"): Sketchfab CC BY (lobo ESOOOO, alce e urso WildMesh_3D animados;
# créditos em assets/mundo/LICENCAS.md). O lobo só tem animação parada: o galope é feito no código. Camada 8 + grupo "golpeavel": tiro e golpe acertam
# como num zumbi. Morto larga carne crua (assa na fogueira).
# shortcut: bichos só existem no anfitrião/solo (Fauna não sincroniza pela rede); para o jogo com amigos, sincronizar.
class_name Bicho
extends CharacterBody3D

const TIPOS: Dictionary = {
	"lobo": {"arq": "lobo_e", "vida": 60, "andar": 1.6, "correr": 6.0, "dano": 9, "alcance": 1.7, "ve": 26.0, "altura": 0.95, "raio": 0.32, "carne": 2, "jeito": "caca"},
	"urso": {"arq": "urso", "vida": 320, "andar": 1.3, "correr": 6.3, "dano": 26, "alcance": 2.3, "ve": 16.0, "altura": 1.5, "raio": 0.6, "carne": 6, "jeito": "caca", "escala": 1.0},
	"cervo": {"arq": "cervo", "vida": 70, "andar": 1.4, "correr": 8.0, "dano": 0, "alcance": 0.0, "ve": 22.0, "altura": 2.3, "raio": 0.4, "carne": 4, "jeito": "foge", "escala": 1.15, "parado": "WalkSlow"},
}
## animações por estado (a primeira que existir no modelo; senão a que tiver o nome parecido)
const ANIMS: Dictionary = {
	"parado": ["Stand_Idle_01", "Food_Eating", "Idle", "IDLE"], "anda": ["Walk", "WalkSlow", "Trot"], "corre": ["Run", "Trot", "Walk"],
	"ataca": ["Attack_StandAngry_01_High", "Attack_Run_01_AttackF", "Attack"], "morre": ["Death_Stand_R01", "Death"],
}
const GRAVIDADE: float = 18.0
const ATAQUE_CADA: float = 1.3
const LONGE_DORME: float = 70.0  # m de todos os jogadores: não pensa nem anda (anti-lag)

var tipo: String = "lobo"
var vida: int = 60
var altura_cabeca: float = 0.6  # Pistola: tiro acima disso é na cabeça
var modelo: Node3D
var _anim: AnimationPlayer
var _alvo: Jogador
var _destino: Vector3 = Vector3.INF
var _pensa_t: float = 0.0
var _ataque_t: float = 0.0
var _foge_t: float = 0.0
var _investe: Vector3 = Vector3.ZERO
var _investe_t: float = 0.0
var _desvio: float = 0.0
var _morto: bool = false
var _som: AudioStreamPlayer3D


func _ready() -> void:
	var t: Dictionary = TIPOS[tipo]
	vida = int(t.vida)
	altura_cabeca = float(t.altura) * 0.7
	collision_layer = 8
	collision_mask = 1
	add_to_group("golpeavel")
	add_to_group("bichos")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(t.raio)
	cap.height = maxf(minf(float(t.altura), 1.6), cap.radius * 2.0 + 0.05)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	modelo = (load("res://assets/bichos/%s.glb" % t.arq) as PackedScene).instantiate()
	for g: Node in modelo.find_children("*", "GeometryInstance3D", true, false):
		g.set_meta("sem_estilo", true)  # pelo pintado: o Estilo não deixa em cor lisa
		if String(g.name).begins_with("Icosphere"):
			g.free()  # esfera do fundo do Sketchfab (antes de medir a altura)
	add_child(modelo)
	var caixa := AABB()
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		var c: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		caixa = c if caixa.size == Vector3.ZERO else caixa.merge(c)
	if t.has("escala"):  # urso e alce já vêm em metros (a caixa da malha com esqueleto engana)
		modelo.scale = Vector3.ONE * float(t.escala)
	elif caixa.size.y > 0.01:
		modelo.scale = Vector3.ONE * (float(t.altura) / caixa.size.y)
	_anim = modelo.find_children("*", "AnimationPlayer", true, false).front() if not modelo.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	_toca("parado")
	_som = AudioStreamPlayer3D.new()
	_som.unit_size = 8.0
	_som.max_distance = 60.0
	add_child(_som)
	_pensa_t = randf() * 0.5


var _clipe: String = ""
var _galope: float = 0.0
var _ataca_t: float = 0.0


func _toca(estado: String) -> void:
	if _anim == null:
		return
	var lista: PackedStringArray = _anim.get_animation_list()
	var achou: String = ""
	var quais: Array = ANIMS.get(estado, [estado])
	if estado == "parado" and TIPOS[tipo].has("parado"):  # alce não tem animação parado em pé: anda bem devagar no lugar
		quais = [TIPOS[tipo].parado]
	for quer: String in quais:
		for n: String in lista:
			if n == quer or n.ends_with("|" + quer):
				achou = n
				break
		if achou != "":
			break
	if achou == "":
		for quer: String in quais:
			for n: String in lista:
				if n.containsn(quer):
					achou = n
					break
			if achou != "":
				break
	if achou == "" and not lista.is_empty():
		achou = lista[0]
	if achou != "" and achou != _clipe:
		_clipe = achou
		_anim.play(achou, 0.2)
		if estado != "morre":
			_anim.get_animation(achou).loop_mode = Animation.LOOP_LINEAR


func _mais_perto() -> Jogador:
	var melhor: Jogador = null
	var d: float = INF
	for n: Node in get_tree().get_nodes_in_group("jogadores"):
		var j := n as Jogador
		if j and j.vida > 0 and not j.segura:
			var dj: float = j.global_position.distance_to(global_position)
			if dj < d:
				d = dj
				melhor = j
	return melhor


func _physics_process(dt: float) -> void:
	if _morto:
		return
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
	var t: Dictionary = TIPOS[tipo]
	_pensa_t -= dt
	_ataque_t -= dt
	_foge_t -= dt
	_investe_t -= dt
	if _pensa_t <= 0.0:
		_pensa_t = 0.25
		var j: Jogador = _mais_perto()
		var dj: float = j.global_position.distance_to(global_position) if j else INF
		if dj > LONGE_DORME:
			velocity = Vector3.ZERO
			_alvo = null
			set_physics_process(false)  # Fauna acorda quando alguém chega perto
			return
		var ve: float = float(t.ve) * (1.0 + 0.6 * Ciclo.noite_de(get_tree()))
		if j and j.agachado:
			ve *= 0.55  # agachado no mato o bicho demora a notar
		if t.jeito == "foge":
			if j and dj < ve:
				_foge_t = 4.0
				_alvo = j
		elif j and (dj < ve or _alvo != null) and dj < ve * 2.0:
			if _alvo == null and tipo == "lobo":
				_uiva()
				for o: Node in get_tree().get_nodes_in_group("bichos"):  # o bando todo vem junto
					var b := o as Bicho
					if b and b != self and b.tipo == "lobo" and b.global_position.distance_to(global_position) < 25.0:
						b._alvo = j
			_alvo = j
		else:
			_alvo = null
		if _destino == Vector3.INF or global_position.distance_to(_destino) < 1.5 or randf() < 0.05:
			var a: float = randf() * TAU
			_destino = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 15.0)
	var quer := Vector3.ZERO
	var vel: float = float(t.andar)
	if _alvo and is_instance_valid(_alvo) and _alvo.vida > 0:
		var d: Vector3 = _alvo.global_position - global_position
		d.y = 0.0
		if t.jeito == "foge" or float(vida) < float(t.vida) * 0.3:
			quer = -d.normalized()  # foge (lobo ferido também)
			vel = float(t.correr)
		elif t.jeito == "investe":
			if _investe_t > 0.0:
				quer = _investe
				vel = float(t.correr)
			elif d.length() < float(t.ve):
				_investe = d.normalized()  # mira e dispara em linha reta (dá para desviar de lado)
				_investe_t = 1.4
				quer = _investe
				vel = float(t.correr)
		else:
			quer = d.normalized()
			vel = float(t.correr)
		if float(t.dano) > 0.0 and d.length() < float(t.alcance) and _ataque_t <= 0.0:
			_ataque_t = ATAQUE_CADA * (1.4 if tipo == "urso" else 1.0)
			_alvo.levar_dano(int(t.dano), d.normalized() * (0.9 if tipo == "urso" else 0.3))
			_ataca_t = 0.7
			_rosna()

	elif _destino != Vector3.INF:
		quer = _destino - global_position
		quer.y = 0.0
		quer = quer.normalized() * 0.7
	if quer.length() > 0.01:
		var dir: Vector3 = quer.normalized().rotated(Vector3.UP, _desvio)
		velocity.x = dir.x * vel * minf(quer.length(), 1.0)
		velocity.z = dir.z * vel * minf(quer.length(), 1.0)
		modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * dt))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
	var antes: Vector3 = global_position
	move_and_slide()
	var anda: float = Vector2(velocity.x, velocity.z).length()
	if anda > 0.5 and antes.distance_to(global_position) < anda * dt * 0.3:
		_desvio = randf_range(0.8, 1.4) * (1.0 if randf() < 0.5 else -1.0)  # bateu num tronco: contorna
	else:
		_desvio = move_toward(_desvio, 0.0, dt * 0.8)
	_ataca_t -= dt
	_toca("ataca" if _ataca_t > 0.0 else ("corre" if anda > 3.0 else ("anda" if anda > 0.3 else "parado")))
	if _anim:
		_anim.speed_scale = clampf(anda / (float(t.correr) * 0.8 if anda > 3.0 else maxf(float(t.andar), 0.5)), 0.7, 2.0) if anda > 0.3 else (0.15 if t.has("parado") else 1.0)
	if tipo == "lobo":  # o modelo do lobo só tem animação parada: galope no código (sobe e desce, balança)
		_galope += dt * anda * 2.2
		modelo.position.y = absf(sin(_galope)) * 0.09 * minf(anda / 3.0, 1.0)
		modelo.rotation.x = sin(_galope * 2.0) * 0.08 * minf(anda / 3.0, 1.0)


func _uiva() -> void:
	if _som and not Rede.servidor_sem_tela:
		_som.stream = load("res://assets/sons/amb/lobo_%d.ogg" % randi_range(1, 2))
		_som.pitch_scale = randf_range(0.8, 1.0)
		_som.play()


func _rosna() -> void:
	if _som and not Rede.servidor_sem_tela and tipo != "cervo":
		_som.stream = load("res://assets/sons/amb/lobo_%d.ogg" % randi_range(1, 2)) if tipo == "lobo" else load("res://assets/sons/amb/rosnado_%d.ogg" % randi_range(1, 16))
		_som.pitch_scale = randf_range(1.1, 1.3) if tipo == "lobo" else randf_range(0.45, 0.55)
		_som.play()


## Tiro e golpe (o mesmo do zumbi).
func levar_golpe(dano: int, dir: Vector3, quem: Node) -> void:
	if _morto:
		return
	vida -= dano
	velocity += Vector3(dir.x, 0, dir.z).normalized() * 2.5
	if quem is Jogador:
		_alvo = quem
		if TIPOS[tipo].jeito == "foge":
			_foge_t = 6.0
		elif tipo == "lobo":
			_rosna()
	set_physics_process(true)
	if vida <= 0:
		_morre()


func _morre() -> void:
	_morto = true
	remove_from_group("golpeavel")
	collision_layer = 0
	_toca("morre")
	if _clipe == "" or not _clipe.containsn("Death"):  # sem animação de morrer (lobo): tomba de lado
		if _anim:
			_anim.stop()
		var tw := create_tween()
		tw.tween_property(modelo, "rotation:z", PI * 0.5, 0.35)
	var principal := get_tree().get_first_node_in_group("principal")
	if principal and multiplayer.is_server():
		principal.solta_item("carne_crua", int(TIPOS[tipo].carne), global_position + Vector3(0, 0.3, 0), 240.0)
	get_tree().create_timer(20.0).timeout.connect(queue_free)
