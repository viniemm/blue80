class_name SplashScreen
extends PxScreen
## Title card: the logo drops in, the ball bounces, the tagline types out. Any tap or key skips ahead.

const TAG := "THE QUANT'S FOOTBALL CARD GAME"
const SETTLED := 2.8        # the animation is finished by here
const AUTO := 7.0

var _left := false
var _blips := 0
var _thud := false


func _paint() -> void:
	var letters := 0
	for i in 7:
		if i != 4 and t - 0.4 - i * 0.14 > 0.15:
			letters += 1
	if letters > _blips:
		_blips = letters
		Sfx.play("blip", 0.0, 0.05)
	if t > 2.0 and not _thud:
		_thud = true
		Sfx.play("thud")
	logo(W / 2.0, 190, 32, t)
	var bar := clampf((t - 1.4) / 0.5, 0.0, 1.0)
	var bw := 224.0 * bar
	draw_rect(Rect2(W / 2.0 - bw / 2.0, 238, bw, 3), Px.GOLD)
	draw_rect(Rect2(W / 2.0 - bw / 2.0, 243, bw, 1), Px.RED)
	var u := t - 1.5                                  # ball: falls, then bounces out
	if u > 0.0:
		var rest := 268.0
		var y := rest
		if u < 0.5:
			y = -30.0 + (rest + 30.0) * pow(u / 0.5, 2.0)
		else:
			var u2 := u - 0.5
			y = rest - 26.0 * exp(-3.0 * u2) * absf(sin(9.0 * u2))
		ball(W / 2.0 - 22.0, y, 3)
	var n := int(clampf((t - 2.0) * 30.0, 0.0, float(TAG.length())))
	Px.text_center(self, W / 2.0, 328, TAG.substr(0, n), 1, Px.DIM)
	if t > SETTLED and int(t * 2.0) % 2 == 0:
		Px.text_center(self, W / 2.0, 500, "TAP OR PRESS ANY KEY", 2, Px.GOLD)
	Px.text_center(self, W / 2.0, 604, "MONDAY NIGHT EDITION", 0, Px.ROYAL)
	if t > AUTO:
		_leave()


func _leave() -> void:
	if not _left:
		_left = true
		Sfx.play("start")
		go.emit("menu")


func _advance() -> void:
	if t < SETTLED:
		t = SETTLED
	else:
		_leave()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_advance()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		_advance()
