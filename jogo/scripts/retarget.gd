# Converte clipes do KayKit (esqueleto Rig_Medium do manequim) para o esqueleto do X Bot (Mixamo).
# Os dois têm repouso em T, de frente para +Z, esquerda em +X: a rotação de cada osso em relação ao repouso,
# no espaço do modelo, é copiada para o osso equivalente. Ossos sem par seguem o pai na pose de repouso.
# A altura do quadril é escalada pela altura das pernas (o manequim é baixinho).
class_name Retarget
extends RefCounted

const KAYKIT: Array[String] = ["res://assets/kaykit/Rig_Medium_General.glb", "res://assets/kaykit/Rig_Medium_MovementBasic.glb",
	"res://assets/kaykit/Rig_Medium_MovementAdvanced.glb", "res://assets/kaykit/Rig_Medium_CombatMelee.glb"]
const ORIGEM_MODELO: String = "res://assets/kaykit/Mannequin_Medium.glb"
const FPS: float = 30.0

## osso KayKit -> osso Mixamo
const PARES: Dictionary = {
	"hips": "mixamorig_Hips", "spine": "mixamorig_Spine", "chest": "mixamorig_Spine2", "head": "mixamorig_Head",
	"upperarm.l": "mixamorig_LeftArm", "lowerarm.l": "mixamorig_LeftForeArm", "wrist.l": "mixamorig_LeftHand",
	"upperarm.r": "mixamorig_RightArm", "lowerarm.r": "mixamorig_RightForeArm", "wrist.r": "mixamorig_RightHand",
	"upperleg.l": "mixamorig_LeftUpLeg", "lowerleg.l": "mixamorig_LeftLeg", "foot.l": "mixamorig_LeftFoot",
	"toes.l": "mixamorig_LeftToeBase", "upperleg.r": "mixamorig_RightUpLeg", "lowerleg.r": "mixamorig_RightLeg",
	"foot.r": "mixamorig_RightFoot", "toes.r": "mixamorig_RightToeBase",
}

static var _clipes: Dictionary = {}


## Clipe `nome` do KayKit já no esqueleto do X Bot (trilhas "Skeleton3D:mixamorig_<osso>").
static func converte(nome: String) -> Animation:
	if _clipes.is_empty():
		for f: String in KAYKIT:
			var cena: Node = (load(f) as PackedScene).instantiate()
			var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
			for n: StringName in ap.get_animation_list():
				_clipes[String(n)] = ap.get_animation(n)
			cena.free()
	var orig: Animation = _clipes[nome]
	var raiz_k: Node = (load(ORIGEM_MODELO) as PackedScene).instantiate()
	var raiz_x: Node = (load(Anims.MODELO) as PackedScene).instantiate()
	var ks: Skeleton3D = raiz_k.find_children("*", "Skeleton3D", true, false)[0]
	var xs: Skeleton3D = raiz_x.find_children("*", "Skeleton3D", true, false)[0]
	# para cada osso do X Bot: osso equivalente no KayKit (-1 = sem par) e a correção de repouso
	var par: Array[int] = []
	var corr: Array[Basis] = []
	for j in xs.get_bone_count():
		var origem: String = String(PARES.find_key(xs.get_bone_name(j))) if PARES.values().has(xs.get_bone_name(j)) else ""
		var b: int = ks.find_bone(origem) if origem != "" else -1
		par.append(b)
		corr.append(_rest_global(ks, b).basis.orthonormalized().inverse() * _rest_global(xs, j).basis.orthonormalized() if b >= 0 else Basis())
	var prefixo: String = "Rig_Medium/Skeleton3D:"
	var escala: float = _rest_global(xs, xs.find_bone("mixamorig_Hips")).origin.y / _rest_global(ks, ks.find_bone("hips")).origin.y

	# trilhas de origem por osso
	var rot_t: Dictionary = {}
	var pos_t: Dictionary = {}
	for t in orig.get_track_count():
		var osso: String = String(orig.track_get_path(t)).trim_prefix(prefixo)
		if orig.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_t[osso] = t
		elif orig.track_get_type(t) == Animation.TYPE_POSITION_3D:
			pos_t[osso] = t

	var a := Animation.new()
	a.length = orig.length
	var trilhas: Array[int] = []
	for j in xs.get_bone_count():
		var nt: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(nt, NodePath("Skeleton3D:" + xs.get_bone_name(j)))
		trilhas.append(nt)
	var tq: int = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tq, NodePath("Skeleton3D:mixamorig_Hips"))
	var quadril_x: int = xs.find_bone("mixamorig_Hips")
	var quadril_k: int = ks.find_bone("hips")

	var n: int = int(ceil(orig.length * FPS))
	for i in n + 1:
		var tempo: float = minf(i / FPS, orig.length)
		# pose global da origem
		var gk: Array[Transform3D] = []
		for b in ks.get_bone_count():
			var nome_b: String = ks.get_bone_name(b)
			var local: Transform3D = ks.get_bone_rest(b)
			if rot_t.has(nome_b):
				local.basis = Basis(orig.rotation_track_interpolate(rot_t[nome_b], tempo))
			if pos_t.has(nome_b):
				local.origin = orig.position_track_interpolate(pos_t[nome_b], tempo)
			var pai: int = ks.get_bone_parent(b)
			gk.append(gk[pai] * local if pai >= 0 else local)
		# pose global do destino
		var gx: Array[Basis] = []
		for j in xs.get_bone_count():
			var pai: int = xs.get_bone_parent(j)
			var gpai: Basis = gx[pai] if pai >= 0 else Basis()
			var g: Basis
			if par[j] >= 0:
				g = gk[par[j]].basis.orthonormalized() * corr[j]
			else:
				g = gpai * xs.get_bone_rest(j).basis.orthonormalized()
			gx.append(g)
			a.rotation_track_insert_key(trilhas[j], tempo, (gpai.inverse() * g).get_rotation_quaternion())
		var pq: Vector3 = gk[quadril_k].origin * escala
		a.position_track_insert_key(tq, tempo, Vector3(xs.get_bone_rest(quadril_x).origin.x, pq.y, xs.get_bone_rest(quadril_x).origin.z))
	raiz_k.free()
	raiz_x.free()
	return a


static func _rest_global(sk: Skeleton3D, b: int) -> Transform3D:
	var t: Transform3D = sk.get_bone_rest(b)
	var pai: int = sk.get_bone_parent(b)
	while pai >= 0:
		t = sk.get_bone_rest(pai) * t
		pai = sk.get_bone_parent(pai)
	return t
