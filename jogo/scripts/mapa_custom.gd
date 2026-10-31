# Mapa montado pelo dono no modo construção (31/10): lista de peças do catálogo (assets/catalogo/catalogo.json, ver
# tools/catalogo/) com posição, giro e tamanho. Salvo em user://meu_mapa.json; o mapa aprovado vira res://assets/mapa/
# mapa_oficial.json. Peças comuns ganham colisão de caixa (as do jogo, de ruína do Blender, já têm a delas); as "jogo:*"
# viram coisa do jogo (nascer, zumbi, baú, sala segura, carro, fogo, luz) na hora de jogar e marcadores no construtor.
class_name MapaCustom

const ARQUIVO: String = "user://meu_mapa.json"
const OFICIAL: String = "res://assets/mapa/mapa_oficial.json"
const CATALOGO: String = "res://assets/catalogo/catalogo.json"
const CORES_JOGO: Dictionary = {"jogo:nascer": Color(0.2, 0.8, 0.3), "jogo:zumbi": Color(0.85, 0.15, 0.1), "jogo:bau": Color(0.75, 0.55, 0.2),
	"jogo:bau_raro": Color(0.9, 0.75, 0.1), "jogo:sala_segura": Color(1.0, 0.7, 0.35), "jogo:carro": Color(0.3, 0.5, 0.9),
	"jogo:fogo": Color(1.0, 0.4, 0.1), "jogo:luz": Color(1.0, 0.95, 0.7)}
const RAIO_SEGURA: float = 6.0
static var _cat: Dictionary = {}
static var _lista: Array = []


static func lista() -> Array:
	if _lista.is_empty():
		_lista = JSON.parse_string(FileAccess.get_file_as_string(CATALOGO))
		for it: Dictionary in _lista:
			_cat[String(it.id)] = it
	return _lista


static func item(id: String) -> Dictionary:
	lista()
	return _cat.get(id, {})


static func carrega(caminho: String = ARQUIVO) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {"base": "vazio", "pecas": []}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return d if d is Dictionary and d.has("pecas") else {"base": "vazio", "pecas": []}


static func salva(dados: Dictionary, caminho: String = ARQUIVO) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(JSON.stringify(dados))


## Texto curto para colar na conversa (o mapa comprimido em base64).
static func para_texto(dados: Dictionary) -> String:
	var bytes: PackedByteArray = JSON.stringify(dados).to_utf8_buffer()
	return "MAPA1:" + Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_GZIP))


static func de_texto(t: String) -> Dictionary:
	t = t.strip_edges()
	if not t.begins_with("MAPA1:"):
		return {}
	var b: PackedByteArray = Marshalls.base64_to_raw(t.substr(6)).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var d: Variant = JSON.parse_string(b.get_string_from_utf8())
	return d if d is Dictionary else {}


## Uma peça pronta para pôr no mundo (sem posição). `jogo`: peças do jogo viram a coisa de verdade; senão, marcador.
static func cria(id: String, bairro: Node, jogo: bool) -> Node3D:
	var it: Dictionary = item(id)
	var peca := Node3D.new()
	peca.set_meta("id", id)
	if id.begins_with("jogo:"):
		if not jogo:
			_marcador(peca, id, String(it.get("nome", id)))
		return peca
	if it.is_empty() or not ResourceLoader.exists(String(it.cena)):
		return peca
	var m: Node3D = (load(String(it.cena)) as PackedScene).instantiate()
	m.scale = Vector3.ONE * float(it.esc)
	peca.add_child(m)
	if String(it.cena).contains("/ruinas/") and bairro and bairro.has_method("_pinta"):
		bairro._pinta(m, Color(0.82, 0.8, 0.76))  # ruína do Blender: troca os materiais pelas texturas do jogo
	elif bool(it.get("col", true)):
		_colisao(peca, m)
	for g: GeometryInstance3D in m.find_children("*", "GeometryInstance3D", true, false):
		var maior: float = maxf(maxf(float(it.tam[0]), float(it.tam[1])), float(it.tam[2]))
		g.visibility_range_end = clampf(maior * 25.0, 30.0, 400.0)  # coisa pequena some de longe (celular)
		if maior < 1.5:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return peca


# caixa de colisão do tamanho do modelo (camada 1: mundo; entra na malha dos zumbis)
static func _colisao(peca: Node3D, m: Node3D) -> void:
	var a: AABB = Moveis._aabb(m)
	if a.size.length() < 0.01:
		return
	a = Transform3D(Basis().scaled(m.scale), Vector3.ZERO) * a
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = a.size.max(Vector3.ONE * 0.05)
	cs.shape = b
	cs.position = a.get_center()
	corpo.add_child(cs)
	peca.add_child(corpo)


static func _marcador(peca: Node3D, id: String, nome: String) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 0.15
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = CORES_JOGO.get(id, Color.WHITE)
	m.emission_enabled = true
	m.emission = m.albedo_color * 0.6
	mi.material_override = m
	mi.position.y = 0.08
	peca.add_child(mi)
	var poste := MeshInstance3D.new()
	var p := BoxMesh.new()
	p.size = Vector3(0.08, 1.6, 0.08)
	poste.mesh = p
	poste.material_override = m
	poste.position.y = 0.8
	peca.add_child(poste)
	var l := Label3D.new()
	l.text = nome
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 1.9
	l.font_size = 40
	l.pixel_size = 0.006
	l.outline_size = 8
	peca.add_child(l)
	var corpo := StaticBody3D.new()  # o construtor acha o marcador pelo raio para apagar
	corpo.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.0, 2.0, 1.0)
	cs.shape = b
	cs.position.y = 1.0
	corpo.add_child(cs)
	peca.add_child(corpo)


## Põe todas as peças de `dados` debaixo de `pai`. `jogo`: liga as peças do jogo (devolve o que precisa o main).
static func monta(dados: Dictionary, pai: Node3D, bairro: Node, jogo: bool) -> Dictionary:
	var out := {"nascer": [], "zumbi": [], "pecas": []}
	var k: int = 0
	for d: Dictionary in dados.get("pecas", []):
		var id: String = String(d.c)
		var peca: Node3D = cria(id, bairro, jogo)
		peca.name = "Peca_%d" % k
		pai.add_child(peca)
		peca.global_position = Vector3(float(d.p[0]), float(d.p[1]), float(d.p[2]))
		peca.rotation.y = float(d.get("r", 0.0))
		peca.scale = Vector3.ONE * float(d.get("e", 1.0))
		out.pecas.append(peca)
		if jogo and id.begins_with("jogo:"):
			_liga_jogo(id, peca, out, k)
		k += 1
	return out


static func _liga_jogo(id: String, peca: Node3D, out: Dictionary, k: int) -> void:
	match id:
		"jogo:nascer":
			out.nascer.append(peca.global_position + Vector3(0, 0.1, 0))
		"jogo:zumbi":
			out.zumbi.append(peca.global_position + Vector3(0, 0.1, 0))
		"jogo:bau", "jogo:bau_raro":
			var b := Bau.new()
			b.name = "MapaBau_%d" % k
			b.raid = id == "jogo:bau_raro"
			peca.add_child(b)
		"jogo:sala_segura":
			peca.add_to_group("salas_seguras")
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.72, 0.42)
			luz.light_energy = 1.6
			luz.omni_range = 7.0
			luz.position.y = 2.0
			peca.add_child(luz)
		"jogo:carro":
			var c := Carro.new()
			c.name = "MapaCarro_%d" % k
			peca.add_child(c)
			var v: Node3D = (load("res://assets/ruinas/carro_r1.glb") as PackedScene).instantiate()
			c.add_child(v)
			c.monta(v)
		"jogo:fogo":
			var f := Fogo.new()
			f.tamanho = 0.35
			f.position.y = 0.9
			peca.add_child(f)
		"jogo:luz":
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.9, 0.7)
			luz.light_energy = 2.0
			luz.omni_range = 12.0
			luz.position.y = 5.0
			peca.add_child(luz)
			var poste := MeshInstance3D.new()
			var p := BoxMesh.new()
			p.size = Vector3(0.15, 5.0, 0.15)
			poste.mesh = p
			poste.position.y = 2.5
			peca.add_child(poste)
