# Fotos da cidade (RAVEN CREEK, tools/mapa/raven_creek.py): vistas da rua e de cima, 2 por linha.
#   xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tools/foto_cidade.gd -- saida.png [lista]
# lista: números das vistas separados por vírgula (padrão: todas). Cada vista: [de (x, z, altura acima do chão), para (x, z, y)].
# Depois da lista, opcional: qualidade (0 Batata .. 3 Ultra) e sombras (0/1), para medir o peso como no celular.
extends SceneTree

const VISTAS: Array = [  # GALENA (13/11, tools/mapa/senoia.py)
	[Vector3(50, 10, 1.7), Vector3(200, -95, 4)],          # 0 Main Street (centro de tijolo) para o nordeste
	[Vector3(-25, 95, 1.7), Vector3(-55, 175, 4)],         # 1 South Main para o sul (delegacia, hospital, mercado)
	[Vector3(225, 145, 1.7), Vector3(300, 230, 3)],        # 2 ponte sobre o Galena River
	[Vector3(-230, 40, 1.7), Vector3(-300, -60, 2)],       # 3 rua de casas no oeste
	[Vector3(-5, -110, 1.7), Vector3(-33, -143, 8)],       # 4 igreja no morro
	[Vector3(-300, -250, 1.7), Vector3(-390, -330, 10)],   # 5 o morro com mata
	[Vector3(-80, 200, 90), Vector3(120, 0, 0)],           # 6 centro de cima
	[Vector3(-300, 350, 220), Vector3(60, -40, 0)],        # 7 a cidade inteira de cima
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	if args.size() > 2:  # depois do _ready do main (ele carrega a configuração salva)
		Config.v.qualidade = int(args[2])
	if args.size() > 3:
		Config.v.sombras = args[3] == "1"
	main.iniciar_solo("Foto")
	for i in 30: await process_frame
	main.ciclo.tempo = 100.0
	if OS.get_environment("CLIMA") != "":
		main.ciclo.clima = OS.get_environment("CLIMA")
	main.controles.visible = false
	for z in main.zumbis.get_children():
		z.visible = false
	var c := Camera3D.new()
	main.add_child(c)
	c.current = true
	c.far = Config.qualidade().longe
	var b: Bairro = main.bairro
	var quais: Array = range(VISTAS.size())
	if args.size() > 1:
		quais = Array(args[1].split(",")).map(func(s: String) -> int: return int(s))
	var linhas: int = (quais.size() + 1) / 2
	var o := Image.create(1280, 360 * linhas, false, Image.FORMAT_RGBA8)
	for k in quais.size():
		var v: Array = VISTAS[quais[k]]
		var de: Vector3 = v[0]
		var para: Vector3 = v[1]
		c.global_position = Bairro.ORIGEM + Vector3(de.x, b.altura(Vector2(de.x, de.y)) + de.z, de.y)
		c.look_at(Bairro.ORIGEM + Vector3(para.x, para.z, para.y))
		for i in 8: await process_frame
		print("vista %d: %d chamadas de desenho, %d objetos, %d triângulos" % [quais[k], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(640, 360)
		o.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i(640 * (k % 2), 360 * (k / 2)))
	o.save_png(args[0])
	quit()
