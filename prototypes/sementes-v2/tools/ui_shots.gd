# PROTOTYPE - NOT FOR PRODUCTION
# UI screenshots of the real game (main.tscn): HUD in the village, quest card, first-time hint, a dialog, every
# pause-menu tab and a toast. Saves <out>/<prefix>_*.png.
# Run (from prototypes/sementes-v2):
#   xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tools/ui_shots.gd -- /abs/out/dir ui_after
extends SceneTree

var out_dir: String = ""
var prefix: String = "ui"
var main: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://tools/shots/")
	prefix = args[1] if args.size() > 1 else "ui"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	var path: String = out_dir.path_join("%s_%s.png" % [prefix, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var t0: int = Time.get_ticks_msec()
	await _frames(90)  # map build, startup toasts and the area banner
	print("warmup ms ", Time.get_ticks_msec() - t0)
	var hud: Hud = main.get("hud")
	hud.set("_toasts", [])
	hud.set("_area_t", 99.0)
	await _shot("hud_start")  # first-time hint (if any) over the HUD
	var hints: Variant = GameMenu.options.get("hints", [])
	GameMenu.options["hints"] = ["move", "attack", "arrow", "talk"]
	await _shot("hud_village")
	GameMenu.options["hints"] = hints  # do not save the shot's skip
	Engine.time_scale = 0.05  # frames take seconds under xvfb: slow time so the toast is still up for the grab
	hud.set("_toast_t", 0.0)
	hud.toast("MISSÃO CONCLUÍDA", "O Pão da Rosa  ·  +40 XP · +25 ouro", "quest")
	await _shot("toast")
	Engine.time_scale = 1.0
	hud.set("_toasts", [])
	main.call("_open_dialog", "innkeeper")
	await _frames(30)
	await _shot("dialog")
	(main.get("dialog") as DialogBox).close()
	var menu: GameMenu = main.get("menu")
	for t: Array in GameMenu.TABS:
		menu.open(str(t[0]))
		await _shot("menu_" + str(t[0]))
	menu.close()
	quit()
