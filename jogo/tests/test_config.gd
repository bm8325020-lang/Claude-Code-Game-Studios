# Configurações: padrão, salvar/ler, voltar ao padrão, sensibilidade mirando por arma e aplicar no jogo.
#   godot --headless --path . -s res://tests/test_config.gd
extends SceneTree

var checks: int = 0
var falhas: int = 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		falhas += 1
		print("FALHA: ", msg)


func _init() -> void:
	var arq := "user://config_teste.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arq))
	Config.carrega(arq)
	ok(Config.v == Config.PADRAO, "sem arquivo, tudo no padrão")
	Config.v.sens = 0.3
	Config.v.inverter_y = true
	Config.v.mira_cor = 2
	Config.salva(arq)
	Config.v = Config.PADRAO.duplicate()
	Config.carrega(arq)
	ok(is_equal_approx(float(Config.v.sens), 0.3) and Config.v.inverter_y and int(Config.v.mira_cor) == 2, "salva e lê de volta")
	ok(is_equal_approx(Config.sensibilidade("pistola", false), 0.3), "sem mirar: sensibilidade geral")
	ok(is_equal_approx(Config.sensibilidade("pistola", true), 0.3 * float(Config.PADRAO.sens_mira_pistola)), "mirando: multiplica pela da arma")
	ok(Config.cor_mira() == Config.CORES_MIRA[2], "cor da mira escolhida")
	Config.v.fps = 30
	Config.v.volume = 0.5
	Config.aplica(self)
	ok(Engine.max_fps == 30, "aplica quadros por segundo")
	ok(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "aplica volume")
	Config.muda("qualidade", 0, self)
	ok(not Config.v.sombras and Config.v.resolucao == 0.6 and root.msaa_3d == Viewport.MSAA_DISABLED, "qualidade Batata: sem sombra, resolução baixa")
	Config.muda("qualidade", 3, self)
	ok(Config.v.sombras and Config.v.resolucao == 1.0 and root.msaa_3d == Viewport.MSAA_4X, "qualidade Ultra: sombra e antisserrilhado")
	Config.v = Config.PADRAO.duplicate()
	Config.salva()
	ok(Config.v.sens == Config.PADRAO.sens and not Config.v.inverter_y, "voltar ao padrão")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arq))
	print("%s: %d checks, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
