# Tabela de cores do visual de desenho (Estilo): a cor média de cada textura do jogo (arquivos de imagem e as que vêm
# dentro dos .glb/.fbx de personagens e objetos), em assets/estilo_cores.json. Rodar de novo ao pôr textura nova:
#   godot --headless --path . -s res://tools/estilo_cores.gd
extends SceneTree

var cores: Dictionary = {}


func _init() -> void:
	_pasta("res://assets")
	for p: String in _cenas("res://assets"):
		var cena := load(p) as PackedScene
		if cena == null:
			continue
		var raiz: Node = cena.instantiate()
		for mi: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			var me: Mesh = (mi as MeshInstance3D).mesh
			if me == null:
				continue
			for i in me.get_surface_count():
				var b := me.surface_get_material(i) as BaseMaterial3D
				if b and b.albedo_texture and not cores.has(b.albedo_texture.resource_path):
					var img: Image = b.albedo_texture.get_image()
					if img:
						_guarda(b.albedo_texture.resource_path, img)
		raiz.free()
	var f := FileAccess.open("res://assets/estilo_cores.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(cores))
	print("ESTILO_CORES ", cores.size())
	quit()


func _guarda(chave: String, img: Image) -> void:
	if img.is_compressed():
		img.decompress()
	if img.is_compressed() or img.get_width() == 0:
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var s := Vector3.ZERO
	var w: float = 0.0
	for y in 16:
		for x in 16:
			var c: Color = img.get_pixel(x, y)
			s += Vector3(c.r, c.g, c.b) * c.a
			w += c.a
	if w > 0.0:
		s /= w
		cores[chave] = [snappedf(s.x, 0.001), snappedf(s.y, 0.001), snappedf(s.z, 0.001)]


func _pasta(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for sub: String in d.get_directories():
		if sub != "mixamo" or p == "res://assets":
			_pasta(p.path_join(sub))
	for arq: String in d.get_files():
		var e: String = arq.get_extension().to_lower()
		if e in ["png", "jpg", "jpeg", "webp"]:
			var cam: String = p.path_join(arq)
			var img := Image.load_from_file(ProjectSettings.globalize_path(cam))
			if img:
				_guarda(cam, img)


## Modelos com textura dentro (personagens, zumbis, armas, objetos baixados).
func _cenas(p: String) -> Array:
	var r: Array = []
	var d := DirAccess.open(p)
	if d == null:
		return r
	for sub: String in d.get_directories():
		if sub in ["brutos", "zumbi", "zumbi2", "aventura", "machado", "pistola", "rifle", "soltas"]:
			continue  # brutos não são importados; o resto do mixamo é só animação
		r.append_array(_cenas(p.path_join(sub)))
	for arq: String in d.get_files():
		if arq.get_extension().to_lower() in ["glb", "fbx", "gltf"] and FileAccess.file_exists(p.path_join(arq) + ".import"):
			r.append(p.path_join(arq))
	return r
