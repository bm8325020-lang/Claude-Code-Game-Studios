# Tamanho no chão (paredes de fora, como o Bairro mede) de cada modelo de assets/ruinas, para a planta da cidade:
#   $G --headless --path . -s res://tools/mapa/mede_ruinas.gd   (grava tools/mapa/medidas.json)
extends SceneTree


func _init() -> void:
	var b := Bairro.new()
	var out: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://assets/ruinas"):
		if f.ends_with(".glb"):
			var t: Vector2 = b._tam_ruina(f.get_basename())
			if t != Vector2.ZERO:
				out[f.get_basename()] = [snappedf(t.x, 0.01), snappedf(t.y, 0.01)]
	var arq := FileAccess.open("res://tools/mapa/medidas.json", FileAccess.WRITE)
	arq.store_string(JSON.stringify(out, "", true))
	b.free()
	quit()
