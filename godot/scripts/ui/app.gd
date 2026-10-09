class_name App
extends Control
## Root of the game: splash -> menu -> run, with fades between screens and a scanline overlay on top.
## The run stays alive (out of the tree) while you visit the menu, so RESUME RUN picks up where you left off.

class Overlay extends Control:
	var fade := 0.0
	var lines := true
	func _draw() -> void:
		if lines:
			for y in range(0, 640, 2):
				draw_rect(Rect2(0, y, 360, 1), Color(0, 0, 0, 0.14))
		if fade > 0.0:
			draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, fade))

var screen: Control
var game: QMain
var overlay: Overlay
var busy := false


func _ready() -> void:
	overlay = Overlay.new()
	overlay.size = Vector2(360, 640)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	add_child(overlay)
	_apply_settings()
	_show(_make("splash"))


func _make(target: String) -> Control:
	var s: PxScreen
	match target:
		"splash": s = SplashScreen.new()
		"help": s = HelpScreen.new()
		"paytable": s = PaytableScreen.new()
		"records": s = RecordsScreen.new()
		"settings":
			var st := SettingsScreen.new()
			st.changed.connect(_apply_settings)
			s = st
		_:
			var m := MenuScreen.new()
			m.can_resume = game != null and game.g.phase != "OVER"
			s = m
	s.go.connect(_on_go)
	return s


func _show(s: Control) -> void:
	if screen != null:
		remove_child(screen)
		if screen != game:
			screen.queue_free()
	screen = s
	if s is QMain:
		Sfx.play_music("game")
	elif not (s is SplashScreen):
		Sfx.play_music("menu")
	add_child(s)
	move_child(s, 0)


func _fade_to(s_factory: Callable) -> void:
	if busy:
		return
	busy = true
	var tw := create_tween()
	tw.tween_property(overlay, "fade", 1.0, 0.12)
	tw.tween_callback(func(): _show(s_factory.call()))
	tw.tween_property(overlay, "fade", 0.0, 0.18)
	tw.tween_callback(func(): busy = false)


func _process(_d: float) -> void:
	if busy:
		overlay.queue_redraw()


func _on_go(target: String) -> void:
	match target:
		"quit":
			_quit()
		"newrun":
			_fade_to(_new_game)
		"resume":
			_fade_to(func(): return game)
		_:
			_fade_to(_make.bind(target))


func _new_game() -> Control:
	if game != null:
		game.commit_run()
		game.queue_free()
	game = QMain.new()
	game.exit_requested.connect(_on_go.bind("menu"))
	return game


func _apply_settings() -> void:
	Sfx.apply_settings()
	overlay.lines = bool(Save.setting("scanlines", true))
	overlay.queue_redraw()
	var want_full: bool = bool(Save.setting("fullscreen", false))
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_full != is_full and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)


func _quit() -> void:
	if game != null:
		game.commit_run()
	Save.flush()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_F11:
		Save.set_setting("fullscreen", not bool(Save.setting("fullscreen", false)))
		_apply_settings()
