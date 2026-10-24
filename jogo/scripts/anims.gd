# Biblioteca de animações (Universal Animation Library 1 e 2, Quaternius, CC0) para o personagem.
# Os clipes da UAL são "no lugar" (o corpo anda, a animação só acompanha). As trilhas são reapontadas para o
# esqueleto do modelo; só o quadril (pelvis) guarda posição, escalada para a altura do quadril do modelo.
class_name Anims
extends RefCounted

const FONTES: Array[String] = ["res://assets/anims/UAL1_Standard.glb", "res://assets/anims/UAL2_Standard.glb"]
const USADAS: Array[String] = ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd",
	"Jump_Start", "Jump", "Jump_Land", "Roll"]
const LOOPS: Array[String] = ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Jump"]

## Velocidade (m/s) em que cada clipe de locomoção parece natural; o jogo escala o clipe pela velocidade real
## para os pés não deslizarem. Ajuste fino a olho.
const VELOCIDADE: Dictionary = {"Walk": 1.45, "Jog_Fwd": 3.9, "Sprint": 6.4, "Crouch_Fwd": 1.35}

static var _lib: AnimationLibrary


## Biblioteca pronta para um AnimationPlayer filho de "Armature" (trilhas "Skeleton3D:<osso>").
static func biblioteca(esqueleto: Skeleton3D) -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var quadril_modelo: float = esqueleto.get_bone_rest(esqueleto.find_bone("pelvis")).origin.length()
	for f: String in FONTES:
		var cena: Node = (load(f) as PackedScene).instantiate()
		var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
		var escala: float = quadril_modelo / maxf(0.01, sk.get_bone_rest(sk.find_bone("pelvis")).origin.length())
		var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
		for nome: StringName in ap.get_animation_list():
			if String(nome) in USADAS and not _lib.has_animation(nome):
				_lib.add_animation(nome, _adapta(String(nome), ap.get_animation(nome), esqueleto, escala))
		cena.free()
	return _lib


static func _adapta(nome: String, a: Animation, sk: Skeleton3D, escala: float) -> Animation:
	var b: Animation = a.duplicate(true)
	for t in range(b.get_track_count() - 1, -1, -1):
		var osso: String = String(b.track_get_path(t)).get_slice(":", 1)
		var tipo: int = b.track_get_type(t)
		if sk.find_bone(osso) < 0 or tipo == Animation.TYPE_SCALE_3D:
			b.remove_track(t)
			continue
		b.track_set_path(t, NodePath("Skeleton3D:" + osso))
		if tipo == Animation.TYPE_POSITION_3D:
			if osso != "pelvis":
				b.remove_track(t)  # só o quadril se desloca; o resto mantém as proporções do modelo
				continue
			for k in b.track_get_key_count(t):
				b.track_set_key_value(t, k, (b.track_get_key_value(t, k) as Vector3) * escala)
	b.loop_mode = Animation.LOOP_LINEAR if nome in LOOPS else Animation.LOOP_NONE
	return b
