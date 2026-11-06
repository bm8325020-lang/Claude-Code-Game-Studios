# Abertura (06/11, dono: "tela preta com uma jornalista contando o relato da cidade, quantos infectados"; a história está
# em ideias/dead-district/HISTORIA.md). Assim que se entra no mundo: tela preta, chiado de TV, o último boletim da
# repórter aparecendo linha a linha. Depois, o mini tutorial: entrar no carro e seguir a estrada até a placa da cidade.
# Só para o jogador daqui; não roda em teste (a árvore do teste tem script) nem no servidor sem tela.
class_name Abertura
extends CanvasLayer

const BOLETIM: Array[String] = [
	"WSB CHANNEL 2 — ATLANTA",
	"BOLETIM URGENTE  ·  DIA 31",
	"",
	"Aqui é Dana Price, ao vivo da Route 85, a quinze quilômetros de Senoia.",
	"Há trinta e um dias, o hospital da cidade recebeu os primeiros casos da chamada Febre Cinzenta.",
	"Febre alta, pele acinzentada, agressividade. Em nove dias, os mortos começaram a se levantar.",
	"O Exército fechou as estradas. Ninguém entrava, ninguém saía.",
	"Há duas semanas, a quarentena caiu numa noite de tempestade.",
	"Estimativa oficial: três mil e oitocentos infectados. Duzentos sobreviventes, talvez menos.",
	"O Exército ainda solta caixas de suprimento sobre a cidade.",
	"Se você está ouvindo isto e tem para onde ir... não vá para Senoia.",
	"...",
	"[sinal perdido]",
]
const POR_LINHA: float = 3.2   # s de cada linha na tela
const LETRA: float = 0.028     # s por letra (máquina de escrever)

var jogador: Jogador
var _fundo: ColorRect
var _texto: Label
var _linha: int = 0
var _t: float = 0.0
var _chiado: AudioStreamPlayer
var _passo: int = 0  # 0 boletim, 1 entrar no carro, 2 seguir a estrada, 3 fim
var _aviso_t: float = 0.0


func _ready() -> void:
	layer = 50
	_fundo = ColorRect.new()
	_fundo.color = Color.BLACK
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	_texto = Label.new()
	_texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 30)
	_texto.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	_texto.offset_left = 120
	_texto.offset_right = -120
	_fundo.add_child(_texto)
	var pula := UiTema.botao("PULAR")
	pula.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pula.position = Vector2(-220, -110)
	pula.size = Vector2(180, 70)
	pula.pressed.connect(_acaba_boletim)
	_fundo.add_child(pula)
	_chiado = AudioStreamPlayer.new()
	_chiado.stream = _gera_chiado()
	_chiado.volume_db = -22.0
	add_child(_chiado)
	_chiado.play()


func _process(dt: float) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	if _passo == 0:
		jogador.entrada["move"] = Vector2.ZERO
		_t += dt
		var l: String = BOLETIM[_linha]
		_texto.text = l.left(int(_t / LETRA))
		_texto.add_theme_color_override("font_color", UiTema.DESTAQUE if _linha < 2 else Color(0.85, 0.85, 0.82))
		if _t > POR_LINHA or (l == "" and _t > 0.4):
			_t = 0.0
			_linha += 1
			if _linha >= BOLETIM.size():
				_acaba_boletim()
		return
	_aviso_t -= dt
	var principal := get_tree().get_first_node_in_group("principal")
	var b: Bairro = principal.bairro if principal else null
	if _passo == 1:
		if _muro == null and b:
			_poe_muro(b)
		if jogador.carro != null:
			_passo = 2
			_aviso_t = 0.0
			if _muro:
				_muro.queue_free()  # pegou o carro: a estrada abre
		elif _aviso_t <= 0.0:
			_aviso_t = 3.5
			principal.controles.aviso("ENTRE NO CARRO (botão USAR)")
	elif _passo == 2:
		if b and jogador.global_position.distance_to(b.entrada_pos) > 160.0:
			_passo = 3
			principal.controles.aviso("BEM-VINDO A SENOIA. ACHE COMIDA, ÁGUA E UM LUGAR SEGURO.", UiTema.DESTAQUE, 6.0)
			if principal.controles._tarefas:
				principal.controles._tarefas.evento("chegou")  # capítulo 0 da história fechado
			queue_free()
		elif _aviso_t <= 0.0:
			_aviso_t = 4.0
			principal.controles.aviso("SIGA A ESTRADA ATÉ A CIDADE")


## 07/11 (dono: "é obrigado a pegar o carro, não pode ir direto para a cidade"): a pé, um muro invisível largo atravessa
## a estrada e o mato na frente do carro; some quando você entra no carro.
var _muro: StaticBody3D
func _poe_muro(b: Bairro) -> void:
	_muro = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = Vector3(260.0, 8.0, 1.0)
	cs.shape = f
	_muro.add_child(cs)
	b.add_child(_muro)
	_muro.global_position = b.entrada_pos + b.entrada_dir * 22.0 + Vector3(0, 3.0, 0)
	_muro.rotation.y = atan2(b.entrada_dir.x, b.entrada_dir.z)


func _acaba_boletim() -> void:
	if _passo != 0:
		return
	_passo = 1
	_fundo.queue_free()
	_chiado.stop()


## Chiado de TV ligada sem sinal (ruído branco baixo, em laço).
static func _gera_chiado() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.mix_rate = 22050
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var n: int = 22050
	w.loop_end = n
	var d := PackedByteArray()
	d.resize(n)
	for i in n:
		d[i] = int(randf_range(-1, 1) * 60.0) & 0xFF
	w.data = d
	return w
