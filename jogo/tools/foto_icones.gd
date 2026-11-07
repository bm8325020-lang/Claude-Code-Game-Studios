# Folha com o ícone de cada item novo (07/11). xvfb ... -s res://tools/foto_icones.gd -- saida.png
extends SceneTree


func _init() -> void:
	var tipos: Array[String] = ["bandagem", "municao_fuzil", "silenciador", "livro", "fita", "peca_radio", "diario", "municao", "comida", "agua"]
	var tex: Array = []
	for t: String in tipos:
		tex.append(Icones.de(t))
	for i in 30: await process_frame
	var out := Image.create(128 * tipos.size(), 128, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.15, 0.15, 0.15))
	for k in tex.size():
		var im: Image = (tex[k] as Texture2D).get_image()
		im.convert(Image.FORMAT_RGBA8)
		out.blend_rect(im, Rect2i(0, 0, 128, 128), Vector2i(k * 128, 0))
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
