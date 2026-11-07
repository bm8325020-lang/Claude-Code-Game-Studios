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
	"dificuldade": 1,           # 07/11: 0 Fácil, 1 Normal, 2 Difícil (DANO_RECEBIDO / DANO_NO_ZUMBI)
	"cfg_versao": 2,            # 2 = já passou pela troca de padrão do celular (anti-travamento 06/11)
}
const NOMES_DIFICULDADE: Array[String] = ["Fácil", "Normal", "Difícil"]
## quanto do dano você leva / quanto do seu dano o zumbi sente, por dificuldade
const DANO_RECEBIDO: Array[float] = [0.6, 1.0, 1.4]
const DANO_NO_ZUMBI: Array[float] = [1.4, 1.0, 0.75]
const CORES_MIRA: Array[Color] = [Color(1, 1, 1), Color(0.3, 1, 0.35), Color(1, 0.85, 0.2), Color(0.35, 0.85, 1)]
const NOMES_MIRA: Array[String] = ["Branca", "Verde", "Amarela", "Azul"]

const NOMES_QUALIDADE: Array[String] = ["Batata", "Média", "Alta", "Ultra"]
## Por nível: sombra (tamanho do mapa, 0 = sem), resolução 3D, antisserrilhado, distância de visão (m) e até onde
## aparecem os detalhes pequenos (molduras, tábuas, galhos).
const QUALIDADE: Array[Dictionary] = [
	# 31/10 (dono: "otimize"): visão mais curta (a neblina já esconde), Alta sem antisserrilhado e um pouco menor
	# 07/11 (dono: "zumbis e o render travam"): lod = quantos pixels de erro o Godot aceita para trocar por malha mais
	# simples (as LODs vêm do import); zumbi = até onde zumbi aparece; sombra_zumbi = zumbi faz sombra
	{"sombra": 0, "resolucao": 0.6, "msaa": Viewport.MSAA_DISABLED, "longe": 100.0, "detalhe": 12.0, "lod": 8.0, "zumbi": 32.0, "sombra_zumbi": false},
	{"sombra": 1024, "resolucao": 0.75, "msaa": Viewport.MSAA_DISABLED, "longe": 150.0, "detalhe": 25.0, "lod": 4.0, "zumbi": 45.0, "sombra_zumbi": false},
	{"sombra": 2048, "resolucao": 0.9, "msaa": Viewport.MSAA_DISABLED, "longe": 280.0, "detalhe": 40.0, "lod": 2.0, "zumbi": 70.0, "sombra_zumbi": true},
	{"sombra": 4096, "resolucao": 1.0, "msaa": Viewport.MSAA_2X, "longe": 450.0, "detalhe": 90.0, "lod": 1.0, "zumbi": 90.0, "sombra_zumbi": true},
]

static var v: Dictionary = PADRAO.duplicate()


static func carrega(caminho: String = ARQUIVO) -> void:
	v = PADRAO.duplicate()
	var cf := ConfigFile.new()
	if cf.load(caminho) != OK:
		if OS.has_feature("mobile"):  # instalação nova no celular já começa leve
			v.qualidade = 1
			v.fps = 30
		return
	for k: String in PADRAO:
		v[k] = cf.get_value("jogo", k, PADRAO[k])
	v.cfg_versao = cf.get_value("jogo", "cfg_versao", 0)  # arquivo de antes da troca não tem a chave
	_padrao_celular()
	if OS.get_environment("DD_QUALIDADE") != "":  # ferramentas de medida (tools/peso_*.gd): qualidade antes do mapa montar
		v.qualidade = int(OS.get_environment("DD_QUALIDADE"))


## Celular (anti-travamento 06/11): Média e 30 quadros por segundo estáveis (60 que o aparelho não sustenta fica
## irregular, que é o "travadinho"). Vale uma vez para quem já tinha configuração salva; depois o jogador muda se quiser.
static func _padrao_celular() -> void:
	if int(v.get("cfg_versao", 0)) >= 2:
		return
	v.cfg_versao = 2
	if OS.has_feature("mobile"):
		v.qualidade = mini(int(v.qualidade), 1)
		v.fps = 30


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
	arvore.root.mesh_lod_threshold = qualidade().lod
	Zumbi.VE_ATE = qualidade().zumbi
	Zumbi.SOMBRA = qualidade().sombra_zumbi
	if qualidade().sombra > 0:
		RenderingServer.directional_shadow_atlas_set_size(qualidade().sombra, true)
	for sol: Node in arvore.get_nodes_in_group("sol"):
		(sol as DirectionalLight3D).shadow_enabled = bool(v.sombras)
		# 07/11: sombra em 4 fatias = cena desenhada 4 vezes a mais; Batata/Média uma fatia só, Alta duas
		(sol as DirectionalLight3D).directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_ORTHOGONAL,
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][clampi(int(v.qualidade), 0, 3)]
	var cam := arvore.root.get_camera_3d()
	if cam:
		cam.far = qualidade().longe
