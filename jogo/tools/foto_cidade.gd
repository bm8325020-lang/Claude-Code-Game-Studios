# Fotos da cidade (RAVEN CREEK, tools/mapa/raven_creek.py): vistas da rua e de cima, 2 por linha.
#   xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tools/foto_cidade.gd -- saida.png [lista]
# lista: números das vistas separados por vírgula (padrão: todas). Cada vista: [de (x, z, altura acima do chão), para (x, z, y)].
# Depois da lista, opcional: qualidade (0 Batata .. 3 Ultra) e sombras (0/1), para medir o peso como no celular.
extends SceneTree

const VISTAS: Array = [  # SOUTH LA (13/11, tools/mapa/senoia.py CIDADE=la)
	[Vector3(8, 120, 1.7), Vector3(0, -40, 4)],            # 0 Vermont Ave para o norte (comércio)
	[Vector3(-120, -10, 1.7), Vector3(60, -18, 4)],        # 1 Slauson Ave para o leste
	[Vector3(-200, -236, 1.7), Vector3(-380, -236, 3)],    # 2 rua de casas com palmeiras (noroeste)
	[Vector3(200, -330, 1.7), Vector3(380, -330, 3)],      # 3 rua de casas (nordeste)
	[Vector3(-80, 200, 90), Vector3(40, -20, 0)],          # 4 centro de cima
	[Vector3(-300, 350, 220), Vector3(60, -40, 0)],        # 5 o bairro inteiro de cima
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
