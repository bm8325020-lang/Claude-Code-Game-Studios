# Ícone de cada item: o próprio modelo 3D renderizado uma vez num SubViewport isolado (nada desenhado à mão
# nem por IA). O SubViewport fica vivo guardando a imagem; `de(tipo)` devolve a textura.
class_name Icones
extends RefCounted

const TAM: int = 128

static var _cache: Dictionary = {}
static var _raiz: Node


static func de(tipo: String) -> Texture2D:
	if _cache.has(tipo):
		return _cache[tipo]
	var arvore := Engine.get_main_loop() as SceneTree
	if _raiz == null or not is_instance_valid(_raiz):
		_raiz = Node.new()
		_raiz.name = "Icones"
		arvore.root.add_child.call_deferred(_raiz)
	var vp := SubViewport.new()
	vp.size = Vector2i(TAM, TAM)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, 35, 0)
	luz.light_energy = 1.3
	vp.add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	var it := Item.new()
	it.tipo = tipo
	it.quantidade = 1
	it.so_visual = true
	it.set_process(false)
	vp.add_child(it)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	_raiz.add_child.call_deferred(vp)
	_enquadra.call_deferred(vp, it, cam)
	var tex: Texture2D = vp.get_texture()
	_cache[tipo] = tex
	return tex


# põe a câmera de modo que o item encha o quadro, olhando de cima e de lado
static func _enquadra(vp: SubViewport, it: Item, cam: Camera3D) -> void:
	it.remove_from_group("itens")  # é só para a foto: ninguém pega
	var caixa := AABB()
	var prim := true
	for mi: MeshInstance3D in it.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.global_transform * mi.get_aabb()
		caixa = a if prim else caixa.merge(a)
		prim = false
	var r: float = maxf(caixa.size.length() * 0.5, 0.01)
	var dist: float = r / sin(deg_to_rad(cam.fov * 0.5)) * 1.05
	cam.look_at_from_position(caixa.get_center() + Vector3(0.6, 0.8, 1.0).normalized() * dist, caixa.get_center())
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
