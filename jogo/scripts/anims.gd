# Animações do Mixamo (X Bot), baixadas pelo usuário, misturadas com algumas da KayKit (CC0) que ficaram
# melhores (pulo, agachar, facão): essas são convertidas para o esqueleto do X Bot ao carregar. Os .fbx ficam em assets/mixamo/ e NÃO vão para o git
# (a licença do Mixamo não deixa redistribuir os arquivos brutos); quem clona precisa baixar de novo.
# O jogo pede animações por nome lógico ("parado", "andar"...); CLIPES diz qual arquivo toca e que trecho
# ("kaykit:<clipe>" = clipe do pacote KayKit convertido; "proprio:<nome>" = feito à mão em golpes.gd).
# Variante "<nome>_p" = mesma ação segurando a pistola (o Jogador usa quando a pistola está na mão).
class_name Anims
extends RefCounted

const PASTA: String = "res://assets/mixamo/"
const MODELO: String = "res://assets/mixamo/xbot.fbx"
## Personagens com roupa e textura (Mixamo, mesmo esqueleto do X Bot): o jogador é fixo por enquanto (editor de
## personagem fica para depois); os zumbis variam entre os três; o chefe é o parasita.
const JOGADOR: String = "sobrevivente"
const ZUMBIS: Array[String] = ["zumbi_policial", "zumbi_mulher", "zumbi_soldado"]
const CHEFE: String = "chefe_parasita"
const ALTURA_XBOT: float = 1.81  # as animações foram feitas para essa altura (posição do quadril)


## Instancia um personagem de assets/mixamo/personagens/ com a altura do X Bot (assim o quadril das
## animações cai no lugar certo). Sem o arquivo (clone sem os .fbx), cai no X Bot.
static func boneco(nome: String) -> Node3D:
	var caminho: String = PASTA + "personagens/%s.fbx" % nome
	if not ResourceLoader.exists(caminho):
		return (load(MODELO) as PackedScene).instantiate()
	var r: Node3D = (load(caminho) as PackedScene).instantiate()
	var h: float = 0.0
	for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		h = maxf(h, (mi.transform * mi.get_aabb()).end.y)
	var esq: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
	esq.scale = Vector3.ONE * (ALTURA_XBOT / h if h > 0.1 else 1.0)
	return r

## nome lógico -> [arquivo, início (s), fim (s, -1 = até o fim)]. Os golpes e a pistola são cortados no
## trecho útil (os clipes do Mixamo têm preparação e volta longas).
const CLIPES: Dictionary = {
	"parado": ["aventura/idle", 0.0, -1.0], "andar": ["aventura/walking", 0.0, -1.0],
	"trote": ["aventura/running", 0.0, -1.0], "correr": ["aventura/running", 0.0, -1.0],
	"agachado": ["kaykit:Crouching", 0.0, -1.0], "agachado_andar": ["kaykit:Sneaking", 0.0, -1.0],
	"pulo_inicio": ["kaykit:Jump_Start", 0.0, -1.0], "no_ar": ["kaykit:Jump_Idle", 0.0, -1.0],
	"pouso": ["kaykit:Jump_Land", 0.0, -1.0],
	# sem arma de fogo: de lado e de costas da KayKit (as do pacote de rifle seguram um rifle)
	"lado_esq": ["kaykit:Running_Strafe_Left", 0.0, -1.0], "lado_dir": ["kaykit:Running_Strafe_Right", 0.0, -1.0],
	"tras": ["kaykit:Walking_Backwards", 0.0, -1.0],
	"morte": ["kaykit:Death_A", 0.0, -1.0], "pegar": ["soltas/pegar_chao", 0.7, 2.8],
	"golpe1": ["proprio:golpe1", 0.0, -1.0], "golpe2": ["proprio:golpe2", 0.0, -1.0],
	"golpe3": ["proprio:golpe3", 0.0, -1.0],
	"pistola_mira": ["soltas/shooting", 0.0, 0.1], "pistola_tiro": ["soltas/shooting", 0.13, 0.6],
	"pistola_recarga": ["soltas/reloading", 0.0, 2.75],
	"agachado_p": ["pistola/pistol_kneeling_idle", 0.0, -1.0],
	"parado_p": ["pistola/pistol_idle", 0.0, -1.0], "andar_p": ["pistola/pistol_walk", 0.0, -1.0],
	"trote_p": ["pistola/pistol_run", 0.0, -1.0], "correr_p": ["pistola/pistol_run", 0.0, -1.0],
	"lado_esq_p": ["pistola/pistol_strafe", 0.0, -1.0], "lado_dir_p": ["pistola/pistol_strafe_2", 0.0, -1.0],
	"tras_p": ["pistola/pistol_run_backward", 0.0, -1.0],
}
const NAO_REPETE: Array[String] = ["morte", "pegar", "pulo_inicio", "pouso", "golpe1", "golpe2", "golpe3", "pistola_tiro", "pistola_recarga"]
const QUADRIL: String = "Skeleton3D:mixamorig_Hips"
## Clipes do KayKit cujos braços abrem demais (em T no começo do pulo, de avião agachado): os braços são
## puxados para os do "parado" nesse tanto (0 = original, 1 = braços do parado). Pernas e tronco não mudam.
const BRACOS_CALMOS: Dictionary = {"agachado": 0.75, "agachado_andar": 0.75, "pulo_inicio": 0.7, "no_ar": 0.5, "pouso": 0.6}
const BRACOS: Array[String] = ["Shoulder", "Arm", "ForeArm", "Hand"]
## clipes tocados mais rápido que o original (x vezes), para caber no tempo do jogo
const ACELERA: Dictionary = {"pegar": 1.75}

## Velocidade (m/s) em que cada clipe de locomoção parece natural (deslocamento do quadril no clipe original);
## o clipe é escalado pela velocidade real para os pés não deslizarem.
const VELOCIDADE: Dictionary = {"andar": 1.8, "trote": 4.7, "correr": 5.5, "agachado_andar": 1.4,
	"lado_esq": 3.6, "lado_dir": 3.6, "tras": 1.8,
	"andar_p": 2.7, "trote_p": 5.0, "correr_p": 5.5, "lado_esq_p": 2.25, "lado_dir_p": 2.5, "tras_p": 3.5}

## Zumbi: mesmo esqueleto (X Bot), animações dos pacotes de zumbi.
const CLIPES_ZUMBI: Dictionary = {
	"parado": ["zumbi2/zombie_idle", 0.0, -1.0], "andar": ["zumbi2/walking", 0.0, -1.0],
	"correr": ["zumbi2/zombie_running", 0.0, -1.0], "ataque": ["zumbi2/zombie_punching", 0.0, -1.0],
	"dano": ["zumbi2/zombie_reaction_hit", 0.0, 0.7], "grito": ["zumbi/zombie_scream", 0.0, 1.8],
	"deitado": ["zumbi2/zombie_stand_up", 0.0, 0.5], "levantar": ["zumbi2/zombie_stand_up", 1.2, 2.7], "morte": ["zumbi/zombie_death", 0.0, -1.0],
}
const NAO_REPETE_ZUMBI: Array[String] = ["ataque", "dano", "morte", "grito", "levantar"]
const VELOCIDADE_ZUMBI: Dictionary = {"andar": 0.56, "correr": 3.1}

static var _lib: AnimationLibrary
static var _lib_zumbi: AnimationLibrary
static var _cache: Dictionary = {}


## Biblioteca para um AnimationPlayer filho da raiz do modelo (trilhas "Skeleton3D:mixamorig_<osso>").
static func biblioteca() -> AnimationLibrary:
	if _lib == null:
		_lib = _monta(CLIPES, NAO_REPETE)
		_acalma_bracos(_lib)
	return _lib


## Biblioteca do zumbi (mesmo formato de trilhas).
static func biblioteca_zumbi() -> AnimationLibrary:
	if _lib_zumbi == null:
		_lib_zumbi = _monta(CLIPES_ZUMBI, NAO_REPETE_ZUMBI)
	return _lib_zumbi


static func _monta(clipes: Dictionary, nao_repete: Array[String]) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var cache: Dictionary = _cache
	for logico: String in clipes:
		var c: Array = clipes[logico]
		if not cache.has(c[0]):
			if String(c[0]).begins_with("proprio:"):
				cache[c[0]] = Golpes.cria(String(c[0]).get_slice(":", 1))
			elif String(c[0]).begins_with("kaykit:"):
				cache[c[0]] = Retarget.converte(String(c[0]).get_slice(":", 1))
			else:
				var cena: Node = (load(PASTA + c[0] + ".fbx") as PackedScene).instantiate()
				cache[c[0]] = (cena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation("mixamo_com")
				cena.free()
		var a: Animation = _corta(cache[c[0]], c[1], c[2])
		_no_lugar(a)
		if ACELERA.has(logico):
			for t in a.get_track_count():
				for k in a.track_get_key_count(t):
					a.track_set_key_time(t, k, a.track_get_key_time(t, k) / ACELERA[logico])
			a.length /= ACELERA[logico]
		a.loop_mode = Animation.LOOP_NONE if logico in nao_repete else Animation.LOOP_LINEAR
		lib.add_animation(logico, a)
	return lib


static func _acalma_bracos(lib: AnimationLibrary) -> void:
	var ref: Animation = lib.get_animation("parado")
	for logico: String in BRACOS_CALMOS:
		var a: Animation = lib.get_animation(logico)
		for lado in ["Left", "Right"]:
			for osso in BRACOS:
				var trilha := NodePath("Skeleton3D:mixamorig_%s%s" % [lado, osso])
				var t: int = a.find_track(trilha, Animation.TYPE_ROTATION_3D)
				var tr: int = ref.find_track(trilha, Animation.TYPE_ROTATION_3D)
				if t < 0 or tr < 0:
					continue
				for k in a.track_get_key_count(t):
					var q: Quaternion = a.track_get_key_value(t, k)
					var calmo: Quaternion = ref.rotation_track_interpolate(tr, fmod(a.track_get_key_time(t, k), ref.length))
					a.track_set_key_value(t, k, q.slerp(calmo, BRACOS_CALMOS[logico]))


# cópia só com as chaves entre ini e fim (fim < 0 = até o fim), começando em 0
static func _corta(orig: Animation, ini: float, fim: float) -> Animation:
	if fim < 0.0:
		fim = orig.length
	var a := Animation.new()
	a.length = fim - ini
	for t in orig.get_track_count():
		var nt: int = a.add_track(orig.track_get_type(t))
		a.track_set_path(nt, orig.track_get_path(t))
		a.track_set_interpolation_type(nt, orig.track_get_interpolation_type(t))
		for k in orig.track_get_key_count(t):
			var tk: float = orig.track_get_key_time(t, k)
			if tk >= ini - 0.001 and tk <= fim + 0.001:
				a.track_insert_key(nt, tk - ini, orig.track_get_key_value(t, k))
		if a.track_get_key_count(nt) == 0:  # trilha sem chave no trecho: guarda o valor do início
			a.track_insert_key(nt, 0.0, orig.value_track_interpolate(t, ini) if orig.track_get_type(t) == Animation.TYPE_VALUE
				else _amostra(orig, t, ini))
	return a


static func _amostra(a: Animation, t: int, tempo: float) -> Variant:
	match a.track_get_type(t):
		Animation.TYPE_POSITION_3D:
			return a.position_track_interpolate(t, tempo)
		Animation.TYPE_ROTATION_3D:
			return a.rotation_track_interpolate(t, tempo)
		_:
			return a.scale_track_interpolate(t, tempo)


# tira o deslocamento do quadril no chão (o clipe anda no lugar; quem move é o CharacterBody3D)
static func _no_lugar(a: Animation) -> void:
	var tp: int = a.find_track(NodePath(QUADRIL), Animation.TYPE_POSITION_3D)
	if tp >= 0 and a.track_get_key_count(tp) > 0:
		var p0: Vector3 = a.track_get_key_value(tp, 0)
		for k in a.track_get_key_count(tp):
			var p: Vector3 = a.track_get_key_value(tp, k)
			a.track_set_key_value(tp, k, Vector3(p0.x, p.y, p0.z))
