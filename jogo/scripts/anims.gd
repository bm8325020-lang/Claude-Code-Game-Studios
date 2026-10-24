# Animações de teste: KayKit Character Animations 1.1 (Kay Lousberg, CC0), no esqueleto Rig_Medium do manequim
# que vem no pacote. Provisório até chegarem as animações do Mixamo.
# O jogo pede animações por nome lógico ("parado", "andar"...); NOMES diz qual clipe do pacote toca.
class_name Anims
extends RefCounted

const PASTA: String = "res://assets/kaykit/"
const MODELO: String = "res://assets/kaykit/Mannequin_Medium.glb"
const FONTES: Array[String] = ["Rig_Medium_General.glb", "Rig_Medium_MovementBasic.glb", "Rig_Medium_MovementAdvanced.glb",
	"Rig_Medium_CombatMelee.glb", "Rig_Medium_CombatRanged.glb"]

## nome lógico -> clipe do KayKit
const NOMES: Dictionary = {
	"parado": "Idle_A", "andar": "Walking_A", "trote": "Running_A", "correr": "Running_B",
	"agachado": "Crouching", "agachado_andar": "Sneaking",
	"pulo_inicio": "Jump_Start", "no_ar": "Jump_Idle", "pouso": "Jump_Land",
	"lado_esq": "Running_Strafe_Left", "lado_dir": "Running_Strafe_Right", "tras": "Walking_Backwards",
	"golpe1": "Melee_1H_Attack_Slice_Horizontal", "golpe2": "Melee_1H_Attack_Slice_Diagonal",
	"golpe3": "Melee_1H_Attack_Chop",
	"pistola_mira": "Ranged_1H_Aiming", "pistola_tiro": "Ranged_1H_Shoot", "pistola_recarga": "Ranged_1H_Reload",
}
const LOOPS: Array[String] = ["parado", "andar", "trote", "correr", "agachado", "agachado_andar", "no_ar",
	"lado_esq", "lado_dir", "tras", "pistola_mira"]

## Velocidade (m/s) em que cada clipe de locomoção parece natural; o clipe é escalado pela velocidade real
## para os pés não deslizarem. Ajuste fino a olho.
const VELOCIDADE: Dictionary = {"andar": 1.6, "trote": 4.2, "correr": 6.2, "agachado_andar": 1.4,
	"lado_esq": 3.6, "lado_dir": 3.6, "tras": 1.8}

static var _lib: AnimationLibrary


## Biblioteca para um AnimationPlayer filho da raiz do modelo (trilhas "Rig_Medium/Skeleton3D:<osso>").
static func biblioteca() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var achados: Dictionary = {}
	for f: String in FONTES:
		var cena: Node = (load(PASTA + f) as PackedScene).instantiate()
		var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
		for nome: StringName in ap.get_animation_list():
			achados[String(nome)] = ap.get_animation(nome)
		cena.free()
	for logico: String in NOMES:
		var a: Animation = (achados[NOMES[logico]] as Animation).duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR if logico in LOOPS else Animation.LOOP_NONE
		_lib.add_animation(logico, a)
	return _lib
