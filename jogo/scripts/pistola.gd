# Pistola de teste. Tiro semiautomático na direção da mira (centro da tela),
# pente + reserva, recarga, dispersão (menor mirando), tiro na cabeça x2, clarão, rastro, coice e som.
# Quem atira manda o efeito para os outros aparelhos (rastro e clarão), o dano é calculado no atirador.
class_name Pistola
extends Node3D

const PENTE: int = 12
const RESERVA_INICIAL: int = 48
const RESERVA_MAX: int = 192  # 12/11: igual ao limite da mochila (dobrado em 07/11)
const DANO: int = 34
const CADENCIA: float = 0.22          # s entre tiros (semiautomática: um tiro por toque)
const RECARGA: float = 1.6
const ALCANCE: float = 80.0
const DISPERSAO_MIRA: float = 0.4     # graus mirando
const DISPERSAO_QUADRIL: float = 3.0  # graus sem mirar
const DISPERSAO_POR_TIRO: float = 1.2 # cresce a cada tiro e volta sozinha
const COICE: float = 1.3              # graus que a câmera sobe por tiro
const BARULHO: float = 20.0           # m: zumbis a essa distância ouvem o tiro e vão ver (35 chamava horda demais)

## Tipo de arma de fogo (FOGO): pistola, smg, espingarda, fuzil, sniper — escolher antes de pôr na árvore.
var tipo: String = "pistola"
## números da arma (vêm de FOGO[tipo]); as constantes acima são os da pistola, usados nos testes
var pente: int = PENTE
var dano: int = DANO
var cadencia: float = CADENCIA
var disp_mira: float = DISPERSAO_MIRA
var disp_quadril: float = DISPERSAO_QUADRIL
var disp_tiro: float = DISPERSAO_POR_TIRO
var coice: float = COICE
var recarga: float = RECARGA
## tem seletor de tiro (só algumas armas); modo_auto = segurando o gatilho sai rajada
var automatica: bool = false
var modo_auto: bool = false
## item da mochila que é a munição desta arma
var municao: String = "municao"
## projéteis por tiro (espingarda: chumbos, cada um com o seu desvio e o seu dano)
var chumbos: int = 1
var alcance: float = ALCANCE
## m: zumbis a essa distância ouvem o tiro
var barulho: float = BARULHO
## silenciador na mochila abafa estas (Simple Zombies: com silenciador o zumbi só ouve bem de perto)
const SILENCIAVEIS: Array[String] = ["pistola", "smg", "fuzil"]
const SILENCIADO: float = 0.35  # fração do barulho com silenciador
## fov da luneta mirando (0 = sem luneta)
var luneta: float = 0.0
const FOGO: Dictionary = {
	"pistola": {},
	"smg": {"pente": 30, "dano": 22, "cadencia": 0.085, "disp_mira": 1.0, "disp_quadril": 4.0, "disp_tiro": 0.7,
		"coice": 0.9, "recarga": 2.2, "automatica": true},
	# 05/11 (dono: "refaça o sistema de tiros, uma animação pra cada arma"): cada uma com o pacote de braços dela (Maos)
	"espingarda": {"pente": 6, "dano": 16, "chumbos": 8, "cadencia": 0.95, "disp_mira": 3.0, "disp_quadril": 4.5,
		"disp_tiro": 0.0, "coice": 4.5, "recarga": 4.2, "alcance": 35.0, "barulho": 32.0, "municao": "cartucho"},
	"fuzil": {"pente": 30, "dano": 30, "cadencia": 0.1, "disp_mira": 0.5, "disp_quadril": 3.5, "disp_tiro": 0.55,
		"coice": 1.2, "recarga": 2.6, "automatica": true, "alcance": 140.0, "barulho": 30.0, "municao": "municao_fuzil"},
	"sniper": {"pente": 5, "dano": 110, "cadencia": 1.4, "disp_mira": 0.03, "disp_quadril": 6.0, "disp_tiro": 0.0,
		"coice": 5.0, "recarga": 3.2, "alcance": 260.0, "barulho": 45.0, "municao": "municao_fuzil", "luneta": 18.0},
}
## arma pronta (tools/assets/normaliza.py ARMAS: cano em +Z, centro no meio): comprimento em metros
const MODELO_3P: Dictionary = {"espingarda": 1.06, "fuzil": 0.94, "sniper": 1.23}
var balas: int = PENTE
## Balas guardadas (moram na mochila do dono; sem dono, aqui mesmo).
var reserva: int:
	get:
		return dono.mochila.conta(municao) if dono else _reserva
	set(v):
		if dono:
			dono.mochila.definir(municao, v)
		else:
			_reserva = v
var _reserva: int = RESERVA_INICIAL
var recarregando: bool = false
var dono: Jogador
var cano: Node3D                       # ponta do cano (de onde saem clarão e rastro)

var _espera: float = 0.0
var _recarga_t: float = 0.0
var _abertura: float = 0.0             # dispersão extra que cresce com tiros seguidos
var _som: AudioStreamPlayer3D
var _som_tiro: AudioStream
## tiros gravados de verdade (The Free Firearm Sound Library, OpenGameArt CC0): 2 por arma, sorteados
var _tiros: Array[AudioStream] = []
var _som_recarga: AudioStreamPlayer3D
var _luz: OmniLight3D


func _ready() -> void:
	for k: String in FOGO.get(tipo, {}):
		set(k, FOGO[tipo][k])
	balas = pente
	modo_auto = automatica
	_monta_modelo()
	_som = AudioStreamPlayer3D.new()
	_som.max_db = 6.0
	_som.max_polyphony = 4  # rajada: um tiro não corta o eco do outro
	_som.unit_size = 14.0
	add_child(_som)
	_som_tiro = _gera_estampido()
	for k in [1, 2]:
		var arq: String = "res://assets/sons/armas/%s_%d.ogg" % [tipo, k]
		if ResourceLoader.exists(arq):
			_tiros.append(load(arq))
	_som_recarga = AudioStreamPlayer3D.new()
	_som_recarga.stream = load("res://assets/sons/armas/recarga.ogg") if ResourceLoader.exists("res://assets/sons/armas/recarga.ogg") else null
	_som_recarga.volume_db = -6.0
	add_child(_som_recarga)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1, 0.8, 0.45)
	_luz.omni_range = 4.0
	_luz.light_energy = 0.0
	cano.add_child(_luz)


# modelo "Low Poly Pistol" (lowpwpc, CGTrader). O arquivo vem com pente e bala soltos: fica só a pistola.
# No arquivo o cano aponta para -Z; aqui é +Z (cano para a frente), empunhadura para -Y, na mão em (0, -0.04, 0).
func _monta_modelo() -> void:
	if tipo == "smg":
		_monta_smg()
		return
	if MODELO_3P.has(tipo):
		var c: float = MODELO_3P[tipo]
		var a := (load("res://assets/mundo/armas/%s/%s.gltf" % [tipo, tipo]) as PackedScene).instantiate() as Node3D
		for g: GeometryInstance3D in a.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.position = Vector3(0, 0.06, c * 0.22)  # mão no cabo, um quarto atrás do meio
		add_child(a)
		cano = Node3D.new()
		cano.position = Vector3(0, 0.08, c * 0.72)
		add_child(cano)
		return
	var m := (load("res://assets/cgtrader/pistola.glb") as PackedScene).instantiate() as Node3D
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "Pistola":
			mi.free()
		else:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.rotation_degrees.y = 180.0
	m.scale = Vector3.ONE * 0.035  # 5,7 unidades de comprimento no arquivo -> 20 cm
	m.position = Vector3(0, 0.02, 0.066)
	add_child(m)
	cano = Node3D.new()
	cano.position = Vector3(0, 0.06, 0.17)
	add_child(cano)


# "Low Poly MP5A3" (samanthacford, Sketchfab, CC BY): no arquivo o cano aponta para -Z e mede 0,245; aqui +Z, 60 cm
func _monta_smg() -> void:
	var m := (load("res://assets/sketchfab/smg.glb") as PackedScene).instantiate() as Node3D
	for g: GeometryInstance3D in m.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.rotation_degrees.y = 180.0
	m.scale = Vector3.ONE * 2.45
	m.position = Vector3(0, 0.1, 0.1)  # empunhadura na mão
	add_child(m)
	cano = Node3D.new()
	cano.position = Vector3(0, 0.12, 0.34)
	add_child(cano)


func _process(dt: float) -> void:
	_espera -= dt
	_abertura = move_toward(_abertura, 0.0, dt * 4.0)
	_luz.light_energy = move_toward(_luz.light_energy, 0.0, dt * 60.0)
	if recarregando:
		_recarga_t -= dt
		if _recarga_t <= 0.0:
			var falta: int = mini(pente - balas, reserva)
			balas += falta
			reserva -= falta
			recarregando = false


## 13/11 (mira de FPS): graus de desvio do próximo tiro (a mira da tela abre e fecha com isso).
func dispersao(mirando: bool) -> float:
	return ((disp_mira if mirando else disp_quadril) + _abertura) * (dono.mult_espalho() if dono else 1.0)


## Pode atirar agora? (tem bala, não está recarregando, já passou a cadência)
func pronta() -> bool:
	return balas > 0 and not recarregando and _espera <= 0.0


## Tenta atirar a partir de `origem` na direção `dir` (raio da mira). Pente vazio = recarrega.
## Retorna o resultado: {"atirou": bool, "acertou": Node ou null, "ponto": Vector3, "cabeca": bool}.
func atirar(origem: Vector3, dir: Vector3, mirando: bool) -> Dictionary:
	var res: Dictionary = {"atirou": false, "acertou": null, "ponto": Vector3.ZERO, "cabeca": false, "carne": false}
	if balas <= 0:
		recarregar()
		return res
	if not pronta():
		return res
	balas -= 1
	_espera = cadencia
	# dispersão: um pequeno desvio aleatório dentro de um cone (cresce a cada tiro seguido)
	var graus: float = ((disp_mira if mirando else disp_quadril) + _abertura) * (dono.mult_espalho() if dono else 1.0)
	_abertura = minf(_abertura + disp_tiro, 4.0 if not automatica else 6.0)
	var pvp: bool = dono != null and dono.is_inside_tree() and dono.get_tree().get_first_node_in_group("principal") != null \
		and dono.get_tree().get_first_node_in_group("principal").em_pvp()
	res.atirou = true
	for k in chumbos:  # espingarda: cada chumbo com o seu desvio (o resultado é o do primeiro que pegou em alguém)
		var desvio := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var d: Vector3 = dir.rotated(dir.cross(desvio).normalized(), deg_to_rad(randf() * graus)) if dir.cross(desvio).length() > 0.01 else dir
		var q := PhysicsRayQueryParameters3D.create(origem, origem + d * alcance, 1 | 8 | (4 if pvp else 0))  # mundo, zumbis (e jogadores no PvP)
		q.exclude = [dono.get_rid()] if dono else []
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var ponto: Vector3 = hit.position if not hit.is_empty() else origem + d * alcance
		var pegou: Node3D = null
		var cabeca: bool = false
		if not hit.is_empty() and (hit.collider as Node).is_in_group("golpeavel"):
			pegou = hit.collider
			var altura: Variant = pegou.get("altura_cabeca")
			cabeca = ponto.y - pegou.global_position.y > (float(altura) if altura != null else 1.65)
			var alt: float = 99.0 if pegou.get("_deitado") else ponto.y - pegou.global_position.y  # deitado não tem "perna"
			pegou.call("levar_golpe", dano_em(origem.distance_to(ponto), alt, cabeca), d, dono)
		if not hit.is_empty() and hit.collider is Carro:
			(hit.collider as Carro).dispara_alarme()  # tiro em carro: alarme chama a horda (Dying Light/L4D)
			(hit.collider as Carro).leva_tiro(ponto)  # na altura da janela o vidro estoura
		if k == 0 or (pegou and res.acertou == null):
			res.ponto = ponto
			res.acertou = pegou
			res.cabeca = cabeca
		var carne: bool = pegou is Zumbi or pegou is Jogador
		if k < 4:  # rastro e marca: no máximo 4 por tiro (celular)
			efeito(ponto, not hit.is_empty(), carne, k == 0)
	res.carne = res.acertou is Zumbi or res.acertou is Jogador
	return res


## Dano de um projétil (06/11, tiro renovado): cabeça x2, perna x0,7 (abaixo de PERNA m), cai até QUEDA_MIN no fim do
## alcance (a partir da metade), e a força do jogador (habilidade).
const PERNA: float = 0.85
const QUEDA_MIN: float = 0.5


func dano_em(dist: float, altura: float, cabeca: bool) -> int:
	var queda: float = lerpf(1.0, QUEDA_MIN, clampf((dist / alcance - 0.5) * 2.0, 0.0, 1.0))
	var parte: float = 2.0 if cabeca else (0.7 if altura < PERNA else 1.0)
	return maxi(1, roundi(dano * parte * queda * (dono.mult_fogo() if dono else 1.0)))


## O máximo que um tiro desta arma pode tirar (o servidor corta o que passar disso no PvP).
static func dano_maximo(t: String) -> int:
	var f: Dictionary = FOGO.get(t, {})
	return roundi(float(f.get("dano", DANO)) * 2.0 * 1.5) * int(f.get("chumbos", 1))


func recarregar() -> void:
	if recarregando or balas == pente or reserva <= 0:
		return
	recarregando = true
	_recarga_t = recarga
	if _som_recarga.stream:
		_som_recarga.pitch_scale = clampf(1.6 / recarga, 0.7, 1.3)  # recarga lenta, som mais arrastado
		_som_recarga.play()


## Clarão, som e rastro até `ponto` (também chamado nos outros aparelhos quando alguém atira).
## `carne` = acertou zumbi: sangue no lugar da faísca.
## Barulho do tiro agora (m): com silenciador na mochila cai para SILENCIADO.
func barulho_atual() -> float:
	return barulho * (SILENCIADO if silenciada() else 1.0)


func silenciada() -> bool:
	return dono != null and tipo in SILENCIAVEIS and dono.mochila.tem("silenciador")


func efeito(ponto: Vector3, bateu: bool, carne: bool = false, estampido: bool = true) -> void:
	if estampido:  # chumbos da espingarda: um estampido só
		_luz.light_energy = 3.0
		_som.stream = _tiros[randi() % _tiros.size()] if not _tiros.is_empty() else _som_tiro
		_som.pitch_scale = randf_range(0.95, 1.05) * (0.75 if chumbos > 1 or luneta > 0.0 else 1.0)  # arma grande: mais grave
		_som.volume_db = -14.0 if silenciada() else 0.0
		_som.play()
	var de: Vector3 = cano.global_position
	if dono and dono.camera:  # primeira pessoa: o rastro sai da arma da tela, não da do corpo (só sombra)
		de = dono.camera.maos.boca(tipo)
	var rastro := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.008
	cil.bottom_radius = 0.008
	cil.height = maxf(de.distance_to(ponto), 0.01)
	cil.radial_segments = 4
	cil.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.9, 0.6, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cil.material = m
	rastro.mesh = cil
	rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child(rastro)
	rastro.global_position = (de + ponto) * 0.5
	var eixo: Vector3 = (ponto - de).normalized()
	if absf(eixo.dot(Vector3.UP)) < 0.999:
		rastro.global_basis = Basis(Quaternion(Vector3.UP, eixo))
	var t := rastro.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, 0.08)
	t.tween_callback(rastro.queue_free)
	var dir: Vector3 = (ponto - de).normalized()
	if carne:
		Pistola.sangue(get_tree(), ponto, dir)
		# o sangue que passa suja a parede ou o chão atrás (até 3 m)
		var atras := _bate(ponto + dir * 0.4, ponto + dir * 3.0 + Vector3(0, -0.6, 0))
		if atras:
			Pistola.marca(get_tree(), atras.position, atras.normal, "sangue")
	elif bateu:
		_faisca(ponto)
		var r := _bate(de, ponto + dir * 0.2)
		if r:
			Pistola.marca(get_tree(), r.position, r.normal, "furo")


func _bate(de: Vector3, ate: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1)  # só o cenário
	return get_world_3d().direct_space_state.intersect_ray(q)


## Marcas que ficam: sangue espirrado e buraco de bala (as mais velhas somem depois de MARCAS_MAX).
const MARCAS_MAX: int = 80
static var _marcas: Array[Node3D] = []
static var _mat_marca: Dictionary = {}


static func marca(arvore: SceneTree, ponto: Vector3, normal: Vector3, tipo: String) -> void:
	if not _mat_marca.has(tipo):
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = MARCA
		m.set_shader_parameter("cor", Color(0.22, 0.01, 0.0, 0.9) if tipo == "sangue" else Color(0.03, 0.03, 0.03, 0.95))
		m.set_shader_parameter("furo", tipo == "furo")
		_mat_marca[tipo] = m
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var tam: float = randf_range(0.5, 1.1) if tipo == "sangue" else 0.07
	q.size = Vector2(tam, tam)
	mi.mesh = q
	mi.material_override = _mat_marca[tipo]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arvore.root.add_child(mi)
	var cima: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.global_transform = Transform3D(Basis.looking_at(-normal, cima).rotated(normal, randf() * TAU), ponto + normal * 0.012)
	_marcas.append(mi)
	if _marcas.size() > MARCAS_MAX:
		var velha: Node3D = _marcas.pop_front()
		if is_instance_valid(velha):
			velha.queue_free()


const MARCA := """shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;
uniform vec4 cor : source_color;
uniform bool furo;
void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c);
	if (furo) {
		if (d > 0.5) discard;
		ALBEDO = mix(cor.rgb, vec3(0.35, 0.33, 0.3), smoothstep(0.18, 0.45, d));  // buraco escuro e borda lascada
		ALPHA = cor.a * (1.0 - smoothstep(0.42, 0.5, d));
	} else {
		float a = atan(c.y, c.x);
		float borda = 0.25 + 0.08 * sin(a * 7.0 + UV.x * 3.0) + 0.05 * sin(a * 13.0);
		float pingo = step(length(c - vec2(0.3 * cos(a * 3.0), 0.3 * sin(a * 5.0)) * 0.9), 0.05);  // gotas em volta
		if (d > borda && pingo < 0.5) discard;
		ALBEDO = cor.rgb;
		ALPHA = cor.a;
	}
}"""


## Respingo de sangue escuro em `ponto`, espirrando para a direção `dir` (tiro ou facão).
static func sangue(arvore: SceneTree, ponto: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 18
	p.lifetime = 0.55
	p.direction = dir
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.025
	m.height = 0.05
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.02, 0.02)
	mat.roughness = 0.4
	m.material = mat
	p.mesh = m
	arvore.root.add_child(p)
	p.global_position = ponto
	p.emitting = true
	p.finished.connect(p.queue_free)


func _faisca(p: Vector3) -> void:
	var f := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radial_segments = 12  # anti-lag: o padrão do Godot é 64
	e.rings = 6
	e.radius = 0.06
	e.height = 0.12
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	e.material = m
	f.mesh = e
	get_tree().root.add_child(f)
	f.global_position = p
	var t := f.create_tween()
	t.tween_property(f, "scale", Vector3.ONE * 2.2, 0.12)
	t.parallel().tween_property(m, "albedo_color:a", 0.0, 0.12)
	t.tween_callback(f.queue_free)


# estampido gerado no código (não há som de tiro nos pacotes grátis): estalo de ruído com queda rápida
static func _gera_estampido() -> AudioStreamWAV:
	var taxa: int = 22050
	var n: int = int(taxa * 0.35)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var baixo: float = 0.0
	for i in n:
		var t: float = float(i) / taxa
		var ruido: float = randf_range(-1.0, 1.0)
		baixo = lerpf(baixo, ruido, 0.18)  # filtro passa-baixa: corpo do estampido
		var env: float = exp(-t * 22.0)
		var v: float = (ruido * 0.35 * exp(-t * 60.0) + baixo * 1.6) * env
		v += sin(TAU * 70.0 * t) * 0.5 * exp(-t * 14.0)  # pancada grave
		dados.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	return w
