extends SceneTree
## Walks every menu screen and the pause overlay, screenshotting each.
##   godot --path godot --resolution 540x960 -s tests/menu_shots.gd -- <out_dir>

var out_dir := "user://"


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _init() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out_dir = OS.get_cmdline_user_args()[0]
	var app: App = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _wait(0.9)
	_save("m1_splash_a")
	await _wait(1.8)
	_save("m2_splash_b")
	await _wait(1.2)
	_save("m3_splash_done")
	app._on_go("menu")
	await _wait(0.6)
	_save("m4_menu")
	for name in ["help", "paytable", "records", "settings"]:
		app._on_go(name)
		await _wait(0.6)
		_save("m5_" + name)
	app._on_go("newrun")
	await _wait(0.6)
	_save("m6_game")
	app.game._on_pause()
	await _wait(0.2)
	_save("m7_pause")
	app.game._on_exit()
	await _wait(0.6)
	_save("m8_menu_resume")
	print("screen: ", app.screen.get_class(), " can_resume ", (app.screen as MenuScreen).can_resume)
	quit()


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
