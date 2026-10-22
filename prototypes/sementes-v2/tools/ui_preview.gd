# PROTOTYPE - NOT FOR PRODUCTION
# UI preview (UI agent): HUD + touch controls over a painted background, every pause-menu tab and the dialog,
# with real Progression/Quests/Items state and the map's places (no 3D build). Saves tools/shots/ui_*.png.
# Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/ui_preview.gd
extends SceneTree

var out_dir: String = ProjectSettings.globalize_path("res://tools/shots/")
var hud: Hud
var touch: Touch
var menu: GameMenu
var dlg: DialogBox


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir + name + ".png")
	print("saved ", out_dir + name + ".png")


func _run() -> void:
	await process_frame
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	root.add_child(bg_layer)
	bg_layer.add_child(_background())
	var ui := CanvasLayer.new()
	root.add_child(ui)

	var prog := Progression.new()
	var items := Items.new()
	var quests := Quests.new(prog, items)
	var map := GameMap.new()
	map.call("_define_places")
	root.add_child(map)

	hud = Hud.new()
	ui.add_child(hud)
	touch = Touch.new()
	ui.add_child(touch)
	menu = GameMenu.new()
	ui.add_child(menu)
	dlg = DialogBox.new()
	ui.add_child(dlg)
	var npcs := Npcs.new()
	root.add_child(npcs)
	dlg.npcs = npcs
	menu.bind(prog, quests, items, map)
	hud.bind(prog, quests, map)

	# a believable mid-game state
	quests.start_new()
	for ev: Array in [["talk", "innkeeper"], ["reach", "village"], ["talk", "elder"], ["reach", "farm"]]:
		quests.notify(ev[0], ev[1])
	for i in 2:
		quests.notify("collect", "nabo")
	prog.gain_xp(130)
	prog.add_gold(57)
	for id: String in ["espada_relha", "escudo_tonel", "gibao_patrulheiro", "pao_rosa", "semente_carvalha", "sino_vaca"]:
		items.add(id)
	items.raise_refill("frasco", 3)
	items.equip("espada_relha")
	items.equip("escudo_tonel")
	prog.add_seed("semente_carvalha")
	prog.unlock("descanso")
	prog.unlock("bloqueio")
	await _frames(40)  # let the startup toasts pass

	hud.set_life(78, 124)
	hud.set_stamina(52, 86)
	hud.set_player(Vector3(150, 0, 30), 0.4)
	hud.boss_show("Dom Aurélio de Vigília", 610, 900)
	await _frames(2)
	hud.set_life(61, 124)  # damage ghost
	hud.show_area("Quinta do Rego")
	hud.level_up(prog.level, 1)
	Touch.show_interact("Falar")
	Touch.set_badge("potion", "3")
	Touch.set_cooldown("skill", 0.45)
	await _frames(45)
	await _shot("ui_hud")
	hud.boss_hide()
	hud._toasts.clear()
	hud.level_up(3, 1)
	await _frames(20)
	await _shot("ui_hud_levelup")
	await _touch_selfcheck()

	var mp := Node3D.new()
	root.add_child(mp)
	mp.position = Vector3(95, 0, 60)
	mp.rotation.y = 2.2
	menu.player = mp
	for t: String in ["char", "inv", "quests", "map", "options"]:
		menu.open(t)
		if t == "inv":
			menu._sel_item = "espada_relha"
			menu.show_tab(t)
		await _frames(6)
		await _shot("ui_menu_" + t)
	menu.close()

	dlg.open("blacksmith", ["Espada eu faço. Coragem você traz de casa. Se não trouxe, volta e procura."],
		[{"id": "m03_accept", "text": "Traga a relha velha"}])
	await _frames(90)
	await _shot("ui_dialog")
	dlg.close()
	quit()


# thumb on ATACAR: pressed() true for exactly one frame, held() while down; left side drives the stick
func _touch_selfcheck() -> void:
	var a: Vector2 = touch.get_global_transform_with_canvas() * Vector2(touch.size.x - 215.0, touch.size.y - 205.0)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = a
	e.pressed = true
	touch._input(e)
	touch._process(0.0)  # what the engine does first in the frame (priority -1000), before the hero reads it
	assert(Touch.pressed("attack") and Touch.held("attack"), "attack edge")
	await process_frame
	await process_frame
	assert(not Touch.pressed("attack") and Touch.held("attack"), "edge lasts one frame")
	e.pressed = false
	touch._input(e)
	assert(not Touch.held("attack"), "released")
	var s := InputEventScreenTouch.new()
	s.index = 1
	s.position = touch.get_global_transform_with_canvas() * Vector2(300, touch.size.y - 300)
	s.pressed = true
	touch._input(s)
	var d := InputEventScreenDrag.new()
	d.index = 1
	d.position = s.position + touch.get_global_transform_with_canvas().basis_xform(Vector2(200, 0))
	touch._input(d)
	assert(Touch.move_vector().x > 0.9, "stick right")
	s.pressed = false
	touch._input(s)
	assert(Touch.move_vector() == Vector2.ZERO, "stick released")
	print("touch self-check ok")


func _background() -> Control:
	var t := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.55, 1.0])
	g.gradient.colors = PackedColorArray([Color(0.98, 0.78, 0.5), Color(0.95, 0.85, 0.65), Color(0.45, 0.58, 0.3), Color(0.3, 0.42, 0.2)])
	g.fill_to = Vector2(0, 1)
	g.width = 64
	g.height = 256
	t.texture = g
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return t
