class_name MenuScreen
extends PxScreen
## Main menu. Up/Down/Enter or the mouse. Offers RESUME RUN when a run is in progress.

var can_resume := false
var hot := 0
var _items: Array = []


func _ready() -> void:
	if can_resume:
		_items.append(["RESUME RUN", "resume", Px.GOLD])
		_items.append(["NEW RUN", "newrun", Px.ROYAL])
	else:
		_items.append(["PLAY", "newrun", Px.GOLD])
	_items.append(["HOW TO PLAY", "help", Px.ROYAL])
	_items.append(["PAYTABLE", "paytable", Px.ROYAL])
	_items.append(["RECORDS", "records", Px.ROYAL])
	_items.append(["SETTINGS", "settings", Px.ROYAL])
	_items.append(["QUIT", "quit", Px.DIM])
	for i in _items.size():
		var b := add_btn(_items[i][0], _items[i][2], Rect2(80, 214 + i * 40, 200, 30), func(): go.emit(_items[i][1]))
		b.mouse_entered.connect(func():
			if hot != i:
				hot = i
				Sfx.play("tick"))


func _paint() -> void:
	logo(W / 2.0, 60, 32)
	draw_rect(Rect2(W / 2.0 - 112, 108, 224, 3), Px.GOLD)
	draw_rect(Rect2(W / 2.0 - 112, 113, 224, 1), Px.RED)
	ball(W / 2.0 - 22.0, 138.0 - absf(sin(t * 3.0)) * 10.0, 3)
	Px.text_center(self, W / 2.0, 176, "WIN HANDS. READ THE DEFENSE. BET YARDS.", 0, Px.DIM)
	var y := 214 + hot * 40 + 9
	if int(t * 3.0) % 2 == 0:
		Px.text(self, 58, y, ">", 2, Px.GOLD)
		Px.text(self, 294, y, "<", 2, Px.GOLD)
	var best := float(Save.rec("peak", 0.0))
	if best > 0.0:
		Px.text_center(self, W / 2.0, 574, "BEST PEAK %.1f   MOST TD %d   RUNS %d" % [best, int(Save.rec("best_tds")), int(Save.rec("runs"))], 0, Px.DIM)
	Px.text_center(self, W / 2.0, 606, "v0.2", 0, Px.LINE)


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	match e.keycode:
		KEY_UP:
			hot = posmod(hot - 1, _items.size())
			Sfx.play("tick")
		KEY_DOWN:
			hot = posmod(hot + 1, _items.size())
			Sfx.play("tick")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			go.emit(_items[hot][1])
		KEY_ESCAPE:
			if can_resume:
				go.emit("resume")
