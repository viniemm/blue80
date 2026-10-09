class_name SettingsScreen
extends PxScreen
## Toggles saved to Save.settings. App applies them live through the `changed` signal.

signal changed

const OPTIONS := [
	["sfx", "SOUND EFFECTS", true],
	["music", "MUSIC", true],
	["scanlines", "CRT SCANLINES", true],
	["counter", "SHOE COUNTER", true],
	["fullscreen", "FULLSCREEN", false],
]

var _btns := {}


func _ready() -> void:
	set_card_alpha(0.22)
	for i in OPTIONS.size():
		var key: String = OPTIONS[i][0]
		_btns[key] = add_btn("", Px.GREEN, Rect2(240, 76 + i * 44, 100, 28), _toggle.bind(key))
	_sync()
	add_back("MENU")


func _toggle(key: String) -> void:
	for o in OPTIONS:
		if o[0] == key:
			Save.set_setting(key, not bool(Save.setting(key, o[2])))
	_sync()
	changed.emit()


func _sync() -> void:
	for o in OPTIONS:
		var on := bool(Save.setting(o[0], o[2]))
		_btns[o[0]].set_label("ON" if on else "OFF")
		_btns[o[0]].fill = Px.GREEN if on else Px.LINE
		_btns[o[0]].queue_redraw()


func _paint() -> void:
	banner("SETTINGS")
	for i in OPTIONS.size():
		Px.text(self, 18, 82 + i * 44, OPTIONS[i][1], 2, Px.FG)
	Px.text(self, 18, 82 + OPTIONS.size() * 44, "F11 also toggles fullscreen.", 0, Px.DIM)
	Px.text(self, 18, 82 + OPTIONS.size() * 44 + 14, "The counter hides the cards-left strip while you play.", 0, Px.DIM)
