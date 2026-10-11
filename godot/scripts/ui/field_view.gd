class_name FieldView
extends Control
## Pixel football field (360x120). EAST (blue) always attacks to the right.

const W := 360
const H := 120
const YD := 3
const EZ := 30
const FY0 := 8
const FH := 104
const CY := 60.0

const GRASS1 := Color("1c7d33")
const GRASS2 := Color("176f2c")
const EZ_BLUE := Color("1f3fbf")
const EZ_RED := Color("b32020")
const LINE_C := Color("e8e8f0")
const FAINT := Color("7ab87a")
const HASH := Color("c8e8c8")
const OUT := Color("060b22")
const LOS_C := Color("8fb0ff")
const FIRST_C := Color("ffcc33")
const OFF_C := Color("3d6bff")
const OFF_HI := Color("c4d4ff")
const DEF_C := Color("ff4d4d")
const GHOST := Color("7a4a5e")
const BALL_C := Color("ff9a1f")

# Defender depth in px past the line of scrimmage: DL, LB, CB, [S1, S2]
const DEF_DEPTH := {"dl": 9, "lb": 24, "cb": 27, "s": [78, 42]}

var state: Dictionary = {"distance": 10.0, "yardline_to_opponent_goal": 75.0}

# --- scoreboard plate, goal-line bonus and yardage animation (used by the betting game)
const ORD := ["", "1ST", "2ND", "3RD", "4TH"]
var attack_left := false        # the computer has the ball: the offense drives toward the left end zone
var show_plate := false       # the betting game turns this on
var goal_label := ""          # shown in the opposing end zone, e.g. "+10"
var v_los := -1.0             # displayed line of scrimmage (px); < 0 follows `state`
var v_fd := -1.0
var v_down := 1
var v_dist := 10.0
var plate_x := 200.0
var plate_flip := 1.0
var plate_flash := 0.0
var plate_banner := ""
var plate_banner_color := Color("ffcc33")
var gain_t := 0.0
var gain_text := ""
var gain_color := Color("3fd07a")
var gain_from := 0.0
var ez_flash := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)


func set_state(st: Dictionary) -> void:
	state = st
	_sync_view()
	queue_redraw()


## Snap the displayed line, first-down marker and down & distance to `state` with no animation.
## x of the first-down line `dist` yards ahead of the line of scrimmage, in the attacking direction.
func _fd_x(los: float, dist: float) -> float:
	if attack_left:
		return maxf(float(EZ), los - roundf(dist * YD))
	return minf(float(W - EZ), los + roundf(dist * YD))


func _sync_view() -> void:
	v_los = los_x()
	v_dist = float(state.distance)
	v_down = int(state.get("down", 1))
	v_fd = _fd_x(v_los, v_dist)
	gain_t = 0.0
	plate_banner = ""
	plate_flip = 1.0


## Animate a snap's outcome: the line of scrimmage slides, a yardage label rises, then the plate flips to the new down.
func animate_result(pre: Dictionary, post: Dictionary, res: Dictionary) -> void:
	state = post
	var los0 := los_for(float(pre.yardline_to_opponent_goal))
	var los1 := los_for(float(post.yardline_to_opponent_goal))
	v_los = los0
	gain_from = los0
	var yards := int(res.yards)
	gain_text = "%+d YDS" % yards if yards != 0 else "NO GAIN"
	var good := (yards > 0) != attack_left                     # the computer gaining ground is bad for you
	gain_color = Color("8c97c8") if yards == 0 else (Color("3fd07a") if good else Color("ff4d4d"))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "gain_t", 1.0, 1.7).from(0.0)
	tw.tween_property(self, "v_los", los1, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_apply_down.bind(post, res)).set_delay(0.8)


func _apply_down(post: Dictionary, res: Dictionary) -> void:
	var evt: String = res.event
	var banner := ""
	var col := Color("ffcc33")
	if evt == "TOUCHDOWN":
		banner = "TOUCHDOWN!"
		ez_flash = 1.0
		create_tween().tween_property(self, "ez_flash", 0.0, 1.4)
	elif evt == "FIRST DOWN":
		banner = "FIRST DOWN!"
	elif bool(res.turnover) or evt in ["TURNOVER", "TURNOVER ON DOWNS", "SAFETY"]:
		banner = "TURNOVER!" if evt != "TURNOVER ON DOWNS" else "TURNOVER ON DOWNS"
		col = Color("ff4d4d")
	var tw := create_tween()
	tw.tween_property(self, "plate_flip", 0.05, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		v_down = int(post.get("down", 1))
		v_dist = float(post.distance)
		v_fd = _fd_x(los_for(float(post.yardline_to_opponent_goal)), v_dist)
		plate_banner = banner
		plate_banner_color = col
		plate_flash = 1.0)
	tw.tween_property(self, "plate_flip", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "plate_flash", 0.0, 0.8)
	if banner != "":
		tw.tween_interval(1.0)
		tw.tween_callback(func(): plate_banner = "")


## x of the line of scrimmage when the offense is `yl` yards from the end zone it attacks.
func los_for(yl: float) -> float:
	return x_of(yl) if attack_left else x_of(100.0 - yl)


## Mirror a point drawn for a right-attacking offense around the line of scrimmage.
func _m(p: Vector2, los: float) -> Vector2:
	return Vector2(2.0 * los - p.x, p.y) if attack_left else p


func x_of(yards: float) -> float:
	return float(EZ) + yards * YD


func los_x() -> float:
	return los_for(float(state.yardline_to_opponent_goal))


# ------------------------------------------------------------------ layout
func offense(los: float) -> Dictionary:
	var p := {}
	var oy := [-10.0, -5.0, 0.0, 5.0, 10.0]
	for i in 5:
		p["ol%d" % i] = Vector2(los - 3, CY + oy[i])
	p["qb_1"] = Vector2(los - 13, CY)
	p["rb_1"] = Vector2(los - 13, CY + 6)
	p["te_1"] = Vector2(los - 3, CY + 15)
	p["wr_x"] = Vector2(los - 3, CY - 40)
	p["wr_z"] = Vector2(los - 3, CY + 40)
	p["wr_slot"] = Vector2(los - 6, CY - 22)
	return p


func defense(los: float) -> Array:
	var d: Dictionary = DEF_DEPTH
	var out: Array = []
	for dy in [-8.0, -3.0, 3.0, 8.0]:
		out.append(Vector2(los + d.dl, CY + dy))
	for dy in [-14.0, 0.0, 14.0]:
		out.append(Vector2(los + d.lb, CY + dy))
	out.append(Vector2(los + d.cb, CY - 40))
	out.append(Vector2(los + d.cb, CY + 40))
	out.append(Vector2(los + d.s[0], CY - 14))
	out.append(Vector2(los + d.s[1], CY + 16))
	return out


# ------------------------------------------------------------------ drawing
func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


func _sprite(p: Vector2, c: Color, hi: Color = Color(0, 0, 0, 0)) -> void:
	_px(p.x - 2, p.y - 2, 5, 5, OUT)
	_px(p.x - 1, p.y - 1, 3, 3, c)
	if hi.a > 0:
		_px(p.x, p.y, 1, 1, hi)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), OUT)
	draw_rect(Rect2(0, FY0, EZ, FH), EZ_BLUE)
	draw_rect(Rect2(W - EZ, FY0, EZ, FH), EZ_RED)
	for b in 20:
		draw_rect(Rect2(x_of(b * 5), FY0, 5 * YD, FH), GRASS2 if b % 2 else GRASS1)
	for y in range(0, 101, 5):
		draw_rect(Rect2(x_of(y), FY0, 1, FH), LINE_C if y % 10 == 0 else FAINT)
	for y in range(1, 100):
		if y % 5 == 0:
			continue
		_px(x_of(y), FY0 + 40, 1, 2, HASH)
		_px(x_of(y), FY0 + FH - 42, 1, 2, HASH)
	for y in range(10, 91, 10):
		var n := y if y <= 50 else 100 - y
		if n == 0:
			continue
		Px.text_center(self, x_of(y), FY0 + 5, str(n), 0, LINE_C)
		Px.text_center(self, x_of(y), FY0 + FH - 18, str(n), 0, LINE_C)
	draw_rect(Rect2(0, FY0 - 2, W, 2), LINE_C)
	draw_rect(Rect2(0, FY0 + FH, W, 2), LINE_C)

	var los := v_los if v_los >= 0.0 else los_x()
	draw_rect(Rect2(roundf(los), FY0, 1, FH), LOS_C)
	var fd := v_fd if v_fd >= 0.0 else _fd_x(los, float(state.distance))
	if absf(fd - los) > 1.0:
		draw_rect(Rect2(roundf(fd), FY0, 1, FH), FIRST_C)

	var off := offense(los)
	var oc := DEF_C if attack_left else OFF_C                  # you are blue, the computer red
	var dc := OFF_C if attack_left else DEF_C
	var ohi := Color("ffd0d0") if attack_left else OFF_HI
	for d in defense(los):
		_sprite(_m(d, los), GHOST)
	for id in off:
		_sprite(_m(off[id], los), oc, ohi if id == "qb_1" else Color(0, 0, 0, 0))
	var ball := _m(Vector2(los - 14, CY - 1), los)
	_px(ball.x, ball.y, 3, 3, BALL_C)
	_draw_fx(los)


func _outlined(cx: float, y: float, s: String, scale_i: int, col: Color) -> void:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		Px.text_center(self, cx + o.x, y + o.y, s, scale_i, Color(0.02, 0.04, 0.13, 0.95))
	Px.text_center(self, cx, y, s, scale_i, col)


## Scoreboard plate, goal-line bonus and the rising yardage label.
func _draw_fx(los: float) -> void:
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	if goal_label != "":
		var cx := float(EZ / 2) if attack_left else float(W - EZ / 2)          # the end zone being attacked
		if ez_flash > 0.0:
			draw_rect(Rect2(0 if attack_left else W - EZ, FY0, EZ, FH), Color(1, 0.95, 0.5, ez_flash * 0.7))
		draw_circle(Vector2(cx, FY0 + 28), 8.0, Color("060b22"))
		draw_circle(Vector2(cx, FY0 + 28), 7.0, Color("ffcc33").lerp(Color.WHITE, 0.3 * pulse))
		draw_circle(Vector2(cx, FY0 + 28), 4.0, Color("d9a21c"))
		Px.text_center(self, cx, FY0 + 41, "TD", 2, Color.WHITE)
		Px.text_center(self, cx, FY0 + 54, goal_label, 2, Color("ffe680").lerp(Color.WHITE, 0.4 * pulse))
	# gain / loss ruler along the bottom lane and the rising label
	if gain_t > 0.0 and gain_t < 1.0:
		var a := minf(gain_from, los)
		var b := maxf(gain_from, los)
		var fade := 1.0 - clampf((gain_t - 0.6) / 0.4, 0.0, 1.0)
		var gc := Color(gain_color, fade)
		draw_rect(Rect2(a, FY0 + FH - 6, maxf(2.0, b - a), 3), gc)
		draw_rect(Rect2(los - 1, FY0 + FH - 10, 3, 11), gc)
		_outlined(clampf(los, 50.0, W - 50.0), FY0 + FH - 36.0 - 12.0 * gain_t, gain_text, 3, gc)
	if not show_plate:
		return
	# down & distance plate: sits on the side of the field away from the line of scrimmage
	var ytg := (los - float(EZ)) / float(YD) if attack_left else (float(W - EZ) - los) / float(YD)
	var dist := int(roundf(v_dist))
	var text := "%s & %s" % [ORD[clampi(v_down, 1, 4)], "GOAL" if v_dist >= ytg - 0.5 else str(dist)]
	var shown := plate_banner if plate_banner != "" else text
	var pw := Px.text_width(shown, 3) + 22.0
	var target := float(W - EZ) - pw / 2.0 - 8.0 if los < W * 0.5 else float(EZ) + pw / 2.0 + 8.0
	plate_x = target if absf(plate_x - target) < 0.5 else plate_x + (target - plate_x) * 0.18
	var ph := 26.0
	var cy := FY0 + 3.0 + ph / 2.0
	draw_set_transform(Vector2(plate_x, cy), 0.0, Vector2(1.0, plate_flip))
	var border := plate_banner_color if plate_banner != "" else (Color("ff4d4d") if v_down == 4 else Color("ffcc33"))
	var fill := Color(0.02, 0.04, 0.13, 0.9).lerp(border, plate_flash * 0.8)
	draw_rect(Rect2(-pw / 2.0 - 1, -ph / 2.0 - 1, pw + 2, ph + 2), Color("060b22"))
	draw_rect(Rect2(-pw / 2.0, -ph / 2.0, pw, ph), border)
	draw_rect(Rect2(-pw / 2.0 + 2, -ph / 2.0 + 2, pw - 4, ph - 4), fill)
	Px.text_center(self, 0.0, -8.0, shown, 3, Color("060b22") if plate_flash > 0.5 else (border if plate_banner != "" else Color.WHITE))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ animation
func _process(_delta: float) -> void:
	if show_plate or goal_label != "":
		queue_redraw()                    # the plate, pulse and tweens redraw every frame
	else:
		set_process(false)
