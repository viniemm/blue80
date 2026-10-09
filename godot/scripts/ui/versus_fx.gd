class_name VersusFx
extends Control
## The showdown banner: your hand slides in from the left, the defense's from the right, a VS pops, and the verdict
## stamps down. The winner's plate lights up and the loser's dims. Call finish() to fade it out.

const BAND_Y := 214.0
const BAND_H := 106.0
const PLATE_W := 160.0
const PLATE_H := 50.0

var mine := ""
var mine_mult := 1.0
var theirs := ""
var theirs_mult := 1.0
var win := 0                       # 1 you, -1 defense, 0 tie
var detail := ""                   # small line under the stamp
var t := 0.0
var _leaving := -1.0
var _sound := 0


func _init(my_hand: String, my_m: float, their_hand: String, their_m: float, result: int, note: String) -> void:
	mine = my_hand
	mine_mult = my_m
	theirs = their_hand
	theirs_mult = their_m
	win = result
	detail = note
	size = Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func finish() -> void:
	if _leaving < 0.0:
		_leaving = t


func _process(d: float) -> void:
	t += d
	if _sound == 0 and t >= 0.1:
		_sound = 1
		Sfx.play("vs_in")
	if _sound == 1 and t >= 1.0:
		_sound = 2
		Sfx.play("slam")
		Sfx.play("win" if win == 1 else ("lose" if win == -1 else "push"), 0.12)
	queue_redraw()
	if _leaving >= 0.0 and t - _leaving > 0.3:
		queue_free()


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


func _plate(x: float, y: float, title: String, hand: String, mult: float, col: Color, state: int, shake: float) -> void:
	# state: 1 winner, -1 loser, 0 undecided/tie
	var a := 0.45 if state == -1 else 1.0
	var px := x + shake
	draw_rect(Rect2(px + 3, y + 3, PLATE_W, PLATE_H), Color(0, 0, 0, 0.5 * a))
	draw_rect(Rect2(px, y, PLATE_W, PLATE_H), Color(col, a))
	draw_rect(Rect2(px + 3, y + 3, PLATE_W - 6, PLATE_H - 6), Color(0.03, 0.05, 0.16, 0.95 * a if state != -1 else 0.7))
	if state == 1:
		var pulse := 0.5 + 0.5 * sin(t * 12.0)
		draw_rect(Rect2(px - 2, y - 2, PLATE_W + 4, PLATE_H + 4), Color(Px.GOLD, 0.5 + 0.5 * pulse), false, 3.0)
	Px.text_center(self, px + PLATE_W / 2.0, y + 6, title, 0, Color(col, a))
	Px.text_center(self, px + PLATE_W / 2.0, y + 18, hand, 2, Color(1, 1, 1, a))
	Px.text_center(self, px + PLATE_W / 2.0, y + 32, "x%.1f" % mult, 1, Color(Px.GOLD, a))


func _draw() -> void:
	var fade := 1.0
	if _leaving >= 0.0:
		fade = clampf(1.0 - (t - _leaving) / 0.3, 0.0, 1.0)
	modulate.a = fade
	var band := _ease_out(t / 0.25)
	draw_rect(Rect2(0, BAND_Y + (1.0 - band) * BAND_H / 2.0, 360, BAND_H * band), Color(0.01, 0.02, 0.08, 0.86))
	draw_rect(Rect2(0, BAND_Y + (1.0 - band) * BAND_H / 2.0, 360, 2), Color(Px.GOLD, 0.8 * band))
	draw_rect(Rect2(0, BAND_Y + BAND_H * band - 2 + (1.0 - band) * BAND_H / 2.0, 360, 2), Color(Px.GOLD, 0.8 * band))
	var decided := t > 1.0
	var my_state := (win if decided else 0)
	var their_state := (-win if decided else 0)
	var slide := _ease_out((t - 0.12) / 0.38)
	var lx := lerpf(-PLATE_W - 10.0, 12.0, slide)
	var rx := lerpf(370.0, 360.0 - PLATE_W - 12.0, slide)
	var py := BAND_Y + 8.0
	var shake_me := 0.0
	var shake_them := 0.0
	if decided and t < 1.4:
		var s := sin(t * 70.0) * (1.4 - t) * 8.0
		if win == 1:
			shake_them = s
		elif win == -1:
			shake_me = s
	_plate(lx, py, "YOUR HAND", mine, mine_mult, Color("3d6bff"), my_state, shake_me)
	_plate(rx, py, "DEFENSE", theirs, theirs_mult, Color("ff4d4d"), their_state, shake_them)
	# VS pops between the plates
	var vs := clampf((t - 0.45) / 0.2, 0.0, 1.0)
	if vs > 0.0 and not decided:
		var sc := 1.0 + (1.0 - vs) * 1.4
		draw_set_transform(Vector2(180, py + 24), 0.0, Vector2(sc, sc))
		Px.text_center(self, 0, -9, "VS", 3, Px.GOLD)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the verdict stamp
	if decided:
		var k := clampf((t - 1.0) / 0.22, 0.0, 1.0)
		var text := "YOU WIN" if win == 1 else ("DEFENSE WINS" if win == -1 else "PUSH")
		var col := Px.GREEN if win == 1 else (Px.RED if win == -1 else Px.DIM)
		var sc := lerpf(2.6, 1.0, _ease_out(k))
		var cy := BAND_Y + 76.0
		draw_set_transform(Vector2(180, cy), deg_to_rad(-5.0) * k, Vector2(sc, sc))
		var w := Px.text_width(text, 3)
		draw_rect(Rect2(-w / 2.0 - 10, -12, w + 20, 24), Color(0, 0, 0, 0.75 * k))
		draw_rect(Rect2(-w / 2.0 - 10, -12, w + 20, 24), Color(col, k), false, 2.0)
		Px.text_center(self, 0, -8, text, 3, Color(col, k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if detail != "" and k >= 1.0:
			Px.text_center(self, 180, BAND_Y + 92.0, detail, 0, Color(1, 1, 1, 0.85))
