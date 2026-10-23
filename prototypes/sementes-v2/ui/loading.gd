# PROTOTYPE - NOT FOR PRODUCTION
# Loading screen shown while main.gd builds the world: title, a line of text and a progress bar.
#   var ls := Loading.new(); add_child(ls); ls.progress = 0.4; ...; ls.queue_free()
class_name Loading
extends CanvasLayer

var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		if _bar: _bar.value = progress * 100.0
var _bar: ProgressBar


func _ready() -> void:
	layer = 100  # above the HUD
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -90)
	box.add_theme_constant_override("separation", 24)
	bg.add_child(box)
	var title := Label.new()
	title.text = "Sementes do Dragão"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Hud.font(true))
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Despertando o Vale de Lume…"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", Hud.font(false))
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	box.add_child(sub)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(560, 22)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.7, 0.25)
	fill.set_corner_radius_all(8)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.25, 0.17, 0.12)
	back.set_corner_radius_all(8)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	progress = progress
