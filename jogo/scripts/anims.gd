# Animações do Mixamo (X Bot), baixadas pelo usuário, misturadas com algumas da KayKit (CC0) que ficaram
# melhores (pulo, agachar, facão): essas são convertidas para o esqueleto do X Bot ao carregar. Os .fbx ficam em assets/mixamo/ e NÃO vão para o git
# (a licença do Mixamo não deixa redistribuir os arquivos brutos); quem clona precisa baixar de novo.
# O jogo pede animações por nome lógico ("parado", "andar"...); CLIPES diz qual arquivo toca e que trecho
# ("kaykit:<clipe>" = clipe do pacote KayKit convertido).
# Variante "<nome>_p" = mesma ação segurando a pistola (o Jogador usa quando a pistola está na mão).
class_name Anims
extends RefCounted

const PASTA: String = "res://assets/mixamo/"
const MODELO: String = "res://assets/mixamo/xbot.fbx"

## nome lógico -> [arquivo, início (s), fim (s, -1 = até o fim)]. Os golpes e a pistola são cortados no
## trecho útil (os clipes do Mixamo têm preparação e volta longas).
const CLIPES: Dictionary = {
	"parado": ["aventura/idle", 0.0, -1.0], "andar": ["aventura/walking", 0.0, -1.0],
	"trote": ["aventura/running", 0.0, -1.0], "correr": ["aventura/running", 0.0, -1.0],
	"agachado": ["kaykit:Crouching", 0.0, -1.0], "agachado_andar": ["kaykit:Sneaking", 0.0, -1.0],
	"pulo_inicio": ["kaykit:Jump_Start", 0.0, -1.0], "no_ar": ["kaykit:Jump_Idle", 0.0, -1.0],
	"pouso": ["kaykit:Jump_Land", 0.0, -1.0],
	"lado_esq": ["rifle/strafe_2", 0.0, -1.0], "lado_dir": ["rifle/strafe", 0.0, -1.0],
	"tras": ["rifle/run_backwards", 0.0, -1.0],
	"golpe1": ["kaykit:Melee_1H_Attack_Slice_Horizontal", 0.0, -1.0],
	"golpe2": ["kaykit:Melee_1H_Attack_Slice_Diagonal", 0.0, -1.0],
	"golpe3": ["kaykit:Melee_1H_Attack_Chop", 0.0, -1.0],
	"pistola_mira": ["soltas/shooting", 0.0, 0.1], "pistola_tiro": ["soltas/shooting", 0.13, 0.6],
	"pistola_recarga": ["soltas/reloading", 0.0, 2.75],
	"parado_p": ["pistola/pistol_idle", 0.0, -1.0], "andar_p": ["pistola/pistol_walk", 0.0, -1.0],
	"trote_p": ["pistola/pistol_run", 0.0, -1.0], "correr_p": ["pistola/pistol_run", 0.0, -1.0],
	"lado_esq_p": ["pistola/pistol_strafe", 0.0, -1.0], "lado_dir_p": ["pistola/pistol_strafe_2", 0.0, -1.0],
	"tras_p": ["pistola/pistol_run_backward", 0.0, -1.0],
}
const NAO_REPETE: Array[String] = ["pulo_inicio", "pouso", "golpe1", "golpe2", "golpe3", "pistola_tiro", "pistola_recarga"]
const QUADRIL: String = "Skeleton3D:mixamorig_Hips"

## Velocidade (m/s) em que cada clipe de locomoção parece natural (deslocamento do quadril no clipe original);
## o clipe é escalado pela velocidade real para os pés não deslizarem.
const VELOCIDADE: Dictionary = {"andar": 1.8, "trote": 4.7, "correr": 5.5, "agachado_andar": 1.4,
	"lado_esq": 2.85, "lado_dir": 3.3, "tras": 2.6,
	"andar_p": 2.7, "trote_p": 5.0, "correr_p": 5.5, "lado_esq_p": 2.25, "lado_dir_p": 2.5, "tras_p": 3.5}

static var _lib: AnimationLibrary


## Biblioteca para um AnimationPlayer filho da raiz do modelo (trilhas "Skeleton3D:mixamorig_<osso>").
static func biblioteca() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var cache: Dictionary = {}
	for logico: String in CLIPES:
		var c: Array = CLIPES[logico]
		if not cache.has(c[0]):
			if String(c[0]).begins_with("kaykit:"):
				cache[c[0]] = Retarget.converte(String(c[0]).get_slice(":", 1))
			else:
				var cena: Node = (load(PASTA + c[0] + ".fbx") as PackedScene).instantiate()
				cache[c[0]] = (cena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation("mixamo_com")
				cena.free()
		var a: Animation = _corta(cache[c[0]], c[1], c[2])
		_no_lugar(a)
		a.loop_mode = Animation.LOOP_NONE if logico in NAO_REPETE else Animation.LOOP_LINEAR
		_lib.add_animation(logico, a)
	return _lib


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
