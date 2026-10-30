# Configurações do jogador (sensibilidade, som, gráficos, botões de toque, mira), salvas em user://config.cfg
# e aplicadas na hora. Quem precisa lê `Config.v["chave"]`; a tela é a TelaConfig.
class_name Config
extends RefCounted

const ARQUIVO: String = "user://config.cfg"
const PADRAO: Dictionary = {
	"sens": 0.18,               # graus por pixel de mouse/arrasto
	"sens_mira_pistola": 0.55,  # multiplica a sensibilidade mirando, por arma
	"sens_mira_facao": 0.8,
	"inverter_y": false,
	"fov": 70.0,
	"volume": 0.8,
	"qualidade": 2,             # 0 Batata, 1 Média, 2 Alta, 3 Ultra (ver QUALIDADE)
	"sombras": true,
	"resolucao": 1.0,           # escala da imagem 3D (abaixar alivia celular fraco)
	"fps": 60,
	"botoes_tamanho": 1.0,
	"botoes_opacidade": 0.35,
	"mira_cor": 0,              # índice em CORES_MIRA
}
const CORES_MIRA: Array[Color] = [Color(1, 1, 1), Color(0.3, 1, 0.35), Color(1, 0.85, 0.2), Color(0.35, 0.85, 1)]
const NOMES_MIRA: Array[String] = ["Branca", "Verde", "Amarela", "Azul"]

const NOMES_QUALIDADE: Array[String] = ["Batata", "Média", "Alta", "Ultra"]
## Por nível: sombra (tamanho do mapa, 0 = sem), resolução 3D, antisserrilhado, distância de visão (m) e até onde
## aparecem os detalhes pequenos (molduras, tábuas, galhos).
const QUALIDADE: Array[Dictionary] = [
	{"sombra": 0, "resolucao": 0.6, "msaa": Viewport.MSAA_DISABLED, "longe": 140.0, "detalhe": 12.0},
	{"sombra": 1024, "resolucao": 0.8, "msaa": Viewport.MSAA_DISABLED, "longe": 260.0, "detalhe": 30.0},
	{"sombra": 2048, "resolucao": 1.0, "msaa": Viewport.MSAA_2X, "longe": 450.0, "detalhe": 45.0},
	{"sombra": 4096, "resolucao": 1.0, "msaa": Viewport.MSAA_4X, "longe": 700.0, "detalhe": 90.0},
]

static var v: Dictionary = PADRAO.duplicate()


static func carrega(caminho: String = ARQUIVO) -> void:
	v = PADRAO.duplicate()
	var cf := ConfigFile.new()
	if cf.load(caminho) != OK:
		return
	for k: String in PADRAO:
		v[k] = cf.get_value("jogo", k, PADRAO[k])


static func salva(caminho: String = ARQUIVO) -> void:
	var cf := ConfigFile.new()
	for k: String in v:
		cf.set_value("jogo", k, v[k])
	cf.save(caminho)


## Muda um valor, salva e aplica no jogo.
static func muda(chave: String, valor: Variant, arvore: SceneTree = null) -> void:
	v[chave] = valor
	if chave == "qualidade":  # o nível já acerta sombra e resolução (dá para ajustar depois)
		v.sombras = qualidade().sombra > 0
		v.resolucao = qualidade().resolucao
	salva()
	if arvore:
		aplica(arvore)


static func padrao(arvore: SceneTree = null) -> void:
	v = PADRAO.duplicate()
	salva()
	if arvore:
		aplica(arvore)


## Sensibilidade do olhar agora (mirando, multiplica pela da arma).
static func sensibilidade(arma: String, mirando: bool) -> float:
	var s: float = float(v.sens)
	if mirando:
		s *= float(v.get("sens_mira_" + arma, 0.7))
	return s


static func qualidade() -> Dictionary:
	return QUALIDADE[clampi(int(v.qualidade), 0, QUALIDADE.size() - 1)]


static func cor_mira() -> Color:
	return CORES_MIRA[clampi(int(v.mira_cor), 0, CORES_MIRA.size() - 1)]


## Som, quadros por segundo, resolução 3D, sombras, antisserrilhado e distância de visão (o servidor sem tela não chama).
static func aplica(arvore: SceneTree) -> void:
	Engine.max_fps = int(v.fps)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(v.volume), 0.0001)))
	arvore.root.scaling_3d_scale = float(v.resolucao)
	arvore.root.msaa_3d = qualidade().msaa
	if qualidade().sombra > 0:
		RenderingServer.directional_shadow_atlas_set_size(qualidade().sombra, true)
	for sol: Node in arvore.get_nodes_in_group("sol"):
		(sol as DirectionalLight3D).shadow_enabled = bool(v.sombras)
	var cam := arvore.root.get_camera_3d()
	if cam:
		cam.far = qualidade().longe
