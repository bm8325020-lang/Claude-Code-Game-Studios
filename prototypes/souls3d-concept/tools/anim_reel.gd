# PROTOTYPE - NOT FOR PRODUCTION
# Plays the hand-made hero clips one after another with their names, for review videos.
# usage: godot --path . --rendering-driver opengl3 --write-movie out.png --fixed-fps 30 -s tools/anim_reel.gd
extends SceneTree

const REEL := [["x_slash1", "Combo 1 - corte diagonal"], ["x_slash2", "Combo 2 - corte de volta"], ["x_slash3", "Combo 3 - corte por cima"],
	["x_thrust", "Combo 4 - estocada"], ["x_spin", "Combo 5 - giro"], ["x_heavy", "Golpe pesado"], ["x_run_atk", "Ataque correndo"],
	["x_roll_atk", "Ataque depois de rolar"], ["x_bash", "Pancada de escudo"], ["x_riposte", "Critico"], ["cast", "Fogo da Semente"],
	["drink", "Frasco"], ["parry", "Aparar"]]
var main
var cam: Camera3D
var label: Label
var i := -1
var t := 0.0
var frame := 0

func _init() -> void:
	main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	cam = Camera3D.new()
	cam.fov = 45
	get_root().add_child(cam)
	var ui := CanvasLayer.new()
	ui.layer = 10
	get_root().add_child(ui)
	label = Label.new()
	label.position = Vector2(40, 30)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	ui.add_child(label)

func _process(dt: float) -> bool:
	frame += 1
	if frame == 3:
		main.set_physics_process(false)
		main.ui.visible = false
		for e in main.enemies:
			e.root.visible = false
		main.boss.root.visible = false
	if frame < 4:
		return false
	var p: Vector3 = main.player.position + Vector3(0, 1.0, 0)
	cam.position = p + Vector3(2.4, 0.5, 2.6)
	cam.look_at(p)
	t -= dt
	if t <= 0:
		i += 1
		if i >= REEL.size():
			return true
		label.text = REEL[i][1]
		main.anim.play("p/" + REEL[i][0], 0.15)
		t = main.anim.current_animation_length + 0.5
	return false
