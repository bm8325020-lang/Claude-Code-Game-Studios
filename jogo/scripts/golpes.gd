# Golpes do facão feitos à mão (pedido do dono: os prontos não ficaram bons). Cada golpe é uma lista de poses-
# chave: giro e inclinação do tronco, giro do quadril, direção do braço, do antebraço e da lâmina, no espaço do
# modelo (+Z frente, +X esquerda, +Y cima). As pernas vêm da base de luta do pacote do machado (Mixamo).
# A animação é montada no esqueleto do X Bot quando o jogo carrega.
class_name Golpes
extends RefCounted

const BASE: String = "machado/standing_idle"   # base de luta: joelhos dobrados, peso na frente
const FPS: float = 30.0
## direção da lâmina no espaço da mão direita (o facão é preso assim em Jogador._monta_arma)
const LAMINA: Vector3 = Vector3(0.975, 0.126, 0.185)

const GUARDA: Dictionary = {"giro": -10.0, "quadril": -5.0, "inclina": 5.0, "baixa": 0.0,
	"braco": Vector3(-0.3, -0.85, 0.42), "antebraco": Vector3(-0.05, 0.25, 0.97), "lamina": Vector3(0.15, 0.75, 0.64),
	"braco_e": Vector3(0.35, -0.8, 0.35), "antebraco_e": Vector3(-0.35, 0.3, 0.88)}

## nome -> [[tempo (s), pose], ...]; o que a pose não diz vem da guarda
const POSES: Dictionary = {
	# 1: corte na horizontal, da direita para a esquerda
	"golpe1": [
		[0.0, {}],
		[0.16, {"giro": -45.0, "quadril": -15.0, "braco": Vector3(-0.85, 0.15, -0.5), "antebraco": Vector3(-0.6, 0.2, -0.78),
			"lamina": Vector3(-0.45, 0.3, -0.84)}],
		[0.25, {"giro": 0.0, "quadril": 0.0, "braco": Vector3(-0.35, 0.05, 0.94), "antebraco": Vector3(-0.05, 0.05, 1.0),
			"lamina": Vector3(0.25, 0.05, 0.97)}],
		[0.34, {"giro": 40.0, "quadril": 15.0, "braco": Vector3(0.45, -0.1, 0.88), "antebraco": Vector3(0.85, -0.15, 0.5),
			"lamina": Vector3(0.95, -0.15, 0.25)}],
		[0.6, {}],
	],
	# 2: de volta, subindo na diagonal, da esquerda para a direita
	"golpe2": [
		[0.0, {"giro": 30.0, "quadril": 10.0, "braco": Vector3(0.4, -0.35, 0.85), "antebraco": Vector3(0.8, -0.35, 0.48),
			"lamina": Vector3(0.85, -0.45, 0.25)}],
		[0.12, {"giro": 38.0, "quadril": 12.0, "braco": Vector3(0.5, -0.45, 0.74), "antebraco": Vector3(0.85, -0.45, 0.27),
			"lamina": Vector3(0.8, -0.55, 0.1)}],
		[0.22, {"giro": -5.0, "quadril": 0.0, "braco": Vector3(-0.25, 0.1, 0.96), "antebraco": Vector3(-0.1, 0.25, 0.96),
			"lamina": Vector3(-0.3, 0.35, 0.89)}],
		[0.32, {"giro": -40.0, "quadril": -12.0, "braco": Vector3(-0.85, 0.35, 0.4), "antebraco": Vector3(-0.75, 0.55, 0.36),
			"lamina": Vector3(-0.65, 0.7, 0.3)}],
		[0.6, {}],
	],
	# 3: de cima para baixo, com o corpo todo (mais forte e mais lento)
	"golpe3": [
		[0.0, {}],
		[0.26, {"giro": -15.0, "inclina": -15.0, "braco": Vector3(-0.3, 0.94, -0.15), "antebraco": Vector3(-0.1, 0.55, -0.83),
			"lamina": Vector3(0.0, 0.15, -0.99), "braco_e": Vector3(0.45, 0.3, 0.84), "antebraco_e": Vector3(0.1, 0.45, 0.89)}],
		[0.36, {"giro": 0.0, "inclina": 25.0, "baixa": 0.06, "braco": Vector3(-0.15, 0.25, 0.96), "antebraco": Vector3(-0.05, -0.15, 0.99),
			"lamina": Vector3(0.0, -0.4, 0.92)}],
		[0.46, {"giro": 5.0, "inclina": 32.0, "baixa": 0.09, "braco": Vector3(-0.15, -0.35, 0.92), "antebraco": Vector3(-0.05, -0.65, 0.76),
			"lamina": Vector3(0.0, -0.88, 0.47)}],
		[0.8, {}],
	],
}

static var _sk: Skeleton3D
static var _base: Animation


## Monta o golpe `nome` (trilhas "Skeleton3D:mixamorig_<osso>", igual às outras animações do X Bot).
static func cria(nome: String) -> Animation:
	if _sk == null:
		var x: Node = (load(Anims.MODELO) as PackedScene).instantiate()
		_sk = x.get_node("Skeleton3D")
		x.remove_child(_sk)
		x.free()
		var c: Node = (load(Anims.PASTA + BASE + ".fbx") as PackedScene).instantiate()
		_base = (c.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation("mixamo_com")
		c.free()
	var chaves: Array = POSES[nome]
	var a := Animation.new()
	a.length = float(chaves[-1][0])
	var trilhas: Dictionary = {}
	for b in _sk.get_bone_count():
		var t: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + _sk.get_bone_name(b)))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		trilhas[b] = t
	var tq: int = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tq, NodePath("Skeleton3D:mixamorig_Hips"))
	a.track_set_interpolation_type(tq, Animation.INTERPOLATION_CUBIC)
	for ch: Array in chaves:
		var pose: Dictionary = GUARDA.duplicate()
		pose.merge(ch[1], true)
		var locais: Array[Quaternion] = _pose(pose)
		for b in _sk.get_bone_count():
			a.rotation_track_insert_key(trilhas[b], float(ch[0]), locais[b])
		var q: Vector3 = _valor_base(Animation.TYPE_POSITION_3D, "mixamorig_Hips")
		a.position_track_insert_key(tq, float(ch[0]), Vector3(q.x, q.y - float(pose.baixa), q.z))
	return a


# rotações locais de todos os ossos para uma pose
static func _pose(p: Dictionary) -> Array[Quaternion]:
	var loc: Array[Quaternion] = []
	for b in _sk.get_bone_count():
		var r: Variant = _valor_base(Animation.TYPE_ROTATION_3D, _sk.get_bone_name(b))
		loc.append(r if r != null else _sk.get_bone_rest(b).basis.get_rotation_quaternion())
	var cima := Vector3.UP
	_gira(loc, "mixamorig_Hips", Quaternion(cima, deg_to_rad(float(p.quadril))))
	for osso: String in ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]:
		_gira(loc, osso, Quaternion(cima, deg_to_rad(float(p.giro) - float(p.quadril)) / 3.0))
		_gira(loc, osso, Quaternion(Vector3.RIGHT, deg_to_rad(float(p.inclina)) / 3.0))
	_aponta(loc, "mixamorig_RightArm", "mixamorig_RightForeArm", p.braco)
	_aponta(loc, "mixamorig_RightForeArm", "mixamorig_RightHand", p.antebraco)
	_aponta_eixo(loc, "mixamorig_RightHand", LAMINA, p.lamina)
	_aponta(loc, "mixamorig_LeftArm", "mixamorig_LeftForeArm", p.braco_e)
	_aponta(loc, "mixamorig_LeftForeArm", "mixamorig_LeftHand", p.antebraco_e)
	return loc


static func _valor_base(tipo: int, osso: String) -> Variant:
	var t: int = _base.find_track(NodePath("Skeleton3D:" + osso), tipo)
	if t < 0:
		return null
	return _base.rotation_track_interpolate(t, 0.0) if tipo == Animation.TYPE_ROTATION_3D else _base.position_track_interpolate(t, 0.0)


static func _global(loc: Array[Quaternion], b: int) -> Quaternion:
	var g: Quaternion = loc[b]
	var pai: int = _sk.get_bone_parent(b)
	while pai >= 0:
		g = loc[pai] * g
		pai = _sk.get_bone_parent(pai)
	return g


# aplica uma rotação no espaço do modelo ao osso (os filhos vão junto)
static func _gira(loc: Array[Quaternion], osso: String, r: Quaternion) -> void:
	var b: int = _sk.find_bone(osso)
	var pai: int = _sk.get_bone_parent(b)
	var gp: Quaternion = _global(loc, pai) if pai >= 0 else Quaternion()
	loc[b] = (gp.inverse() * r * gp * loc[b]).normalized()


# gira o osso para que ele aponte (do osso até o filho) na direção `dir` do modelo
static func _aponta(loc: Array[Quaternion], osso: String, filho: String, dir: Vector3) -> void:
	var eixo: Vector3 = _sk.get_bone_rest(_sk.find_bone(filho)).origin.normalized()
	_aponta_eixo(loc, osso, eixo, dir)


static func _aponta_eixo(loc: Array[Quaternion], osso: String, eixo_local: Vector3, dir: Vector3) -> void:
	var b: int = _sk.find_bone(osso)
	var atual: Vector3 = _global(loc, b) * eixo_local.normalized()
	_gira(loc, osso, Quaternion(atual.normalized(), dir.normalized()))
