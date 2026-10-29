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
	"sombras": true,
	"resolucao": 1.0,           # escala da imagem 3D (abaixar alivia celular fraco)
	"fps": 60,
	"botoes_tamanho": 1.0,      # vale na próxima partida
	"botoes_opacidade": 0.35,
	"mira_cor": 0,              # índice em CORES_MIRA
}
const CORES_MIRA: Array[Color] = [Color(1, 1, 1), Color(0.3, 1, 0.35), Color(1, 0.85, 0.2), Color(0.35, 0.85, 1)]
const NOMES_MIRA: Array[String] = ["Branca", "Verde", "Amarela", "Azul"]

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


static func cor_mira() -> Color:
	return CORES_MIRA[clampi(int(v.mira_cor), 0, CORES_MIRA.size() - 1)]


## Som, quadros por segundo, resolução 3D e sombras (o servidor sem tela não chama).
static func aplica(arvore: SceneTree) -> void:
	Engine.max_fps = int(v.fps)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(v.volume), 0.0001)))
	arvore.root.scaling_3d_scale = float(v.resolucao)
	for sol: Node in arvore.get_nodes_in_group("sol"):
		(sol as DirectionalLight3D).shadow_enabled = bool(v.sombras)
