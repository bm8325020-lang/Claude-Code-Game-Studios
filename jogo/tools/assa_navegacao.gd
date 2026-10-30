# Assa as malhas de navegação (pista e cidade) e salva em assets/mapa/nav_*.res, para o jogo não assar ao criar a sala.
# Rodar depois de mudar a cidade (cidade.json) ou as ruínas do Blender:
#   godot --headless --path . -s res://tools/assa_navegacao.gd -- salva_nav
extends SceneTree


func _init() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3: await process_frame
	main.iniciar_solo("Assa")
	print("NAV salva: ", ResourceLoader.exists("res://assets/mapa/nav_bairro.res"))
	quit()
