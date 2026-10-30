# Liga o carteiro das salas (relay.gd) sem mundo nenhum.
#   godot --headless --main-pack servidor.pck -s res://scripts/relay_main.gd -- porta=7862
extends SceneTree


func _init() -> void:
	var r := Relay.new()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("porta="):
			r.porta = int(a.trim_prefix("porta="))
	root.add_child.call_deferred(r)
