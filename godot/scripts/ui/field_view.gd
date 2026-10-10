class_name FieldView
extends Control
## Pixel football field (360x120). EAST (blue) always attacks to the right.

signal anim_done

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
const ROUTE_C := Color("ffcc33")

# Defender depth in px past the LOS by tier: DL, LB, CB, [S1, S2]
const DEF_DEPTH := {
	1: {"dl": 9, "lb": 42, "cb": 48, "s": [126, 144]},
	2: {"dl": 9, "lb": 30, "cb": 39, "s": [96, 102]},
	3: {"dl": 9, "lb": 24, "cb": 27, "s": [78, 42]},
	4: {"dl": 6, "lb": 15, "cb": 9, "s": [48, 24]},
	5: {"dl": 3, "lb": 6, "cb": 6, "s": [15, 12]},
}

var state: Dictionary = {"distance": 10.0, "yardline_to_opponent_goal": 75.0}
var play: Dictionary = {}
var def_tier := 0            # 0 = not revealed yet (ghost defenders)
var _anim: Dictionary = {}
var _t := 0.0

# --- scoreboard plate, goal-line bonus and yardage animation (used by the betting game)
const ORD := ["", "1ST", "2ND", "3RD", "4TH"]
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
func _sync_view() -> void:
	v_los = los_x()
	v_dist = float(state.distance)
	v_down = int(state.get("down", 1))
	v_fd = minf(float(W - EZ), v_los + roundf(v_dist * YD))
	gain_t = 0.0
	plate_banner = ""
	plate_flip = 1.0


## Animate a snap's outcome: the line of scrimmage slides, a yardage label rises, then the plate flips to the new down.
func animate_result(pre: Dictionary, post: Dictionary, res: Dictionary) -> void:
	state = post
	var los0 := x_of(100.0 - float(pre.yardline_to_opponent_goal))
	var los1 := x_of(100.0 - float(post.yardline_to_opponent_goal))
	v_los = los0
	gain_from = los0
	var yards := int(res.yards)
	gain_text = "%+d YDS" % yards if yards != 0 else "NO GAIN"
	gain_color = Color("3fd07a") if yards > 0 else (Color("ff4d4d") if yards < 0 else Color("8c97c8"))
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
		v_fd = minf(float(W - EZ), x_of(100.0 - float(post.yardline_to_opponent_goal)) + roundf(v_dist * YD))
		plate_banner = banner
		plate_banner_color = col
		plate_flash = 1.0)
	tw.tween_property(self, "plate_flip", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "plate_flash", 0.0, 0.8)
	if banner != "":
		tw.tween_interval(1.0)
		tw.tween_callback(func(): plate_banner = "")


func set_play(p: Dictionary) -> void:
	play = p
	def_tier = 0
	queue_redraw()


func reveal(tier: int) -> void:
	def_tier = tier
	queue_redraw()


func x_of(yards: float) -> float:
	return float(EZ) + yards * YD


func los_x() -> float:
	return x_of(100.0 - float(state.yardline_to_opponent_goal))


# ------------------------------------------------------------------ layout
func offense(los: float) -> Dictionary:
	var iform := String(play.get("formation", "")).contains("I_FORM") or String(play.get("formation", "")).contains("SINGLEBACK")
	var p := {}
	var oy := [-10.0, -5.0, 0.0, 5.0, 10.0]
	for i in 5:
		p["ol%d" % i] = Vector2(los - 3, CY + oy[i])
	p["qb_1"] = Vector2(los - (9 if iform else 13), CY)
	p["rb_1"] = Vector2(los - (18 if iform else 13), CY + (0 if iform else 6))
	p["te_1"] = Vector2(los - 3, CY + 15)
	p["wr_x"] = Vector2(los - 3, CY - 40)
	p["wr_z"] = Vector2(los - 3, CY + 40)
	if iform:
		p["fb"] = Vector2(los - 10, CY + 3)
	else:
		p["wr_slot"] = Vector2(los - 6, CY - 22)
	return p


func defense(los: float) -> Array:
	var d: Dictionary = DEF_DEPTH[def_tier if def_tier > 0 else 3]
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


func route_points(start: Vector2, route: String, depth: float) -> Array:
	var D := maxf(6.0, absf(depth) * YD)
	var s := 1.0 if start.y <= CY else -1.0                # inward = toward the middle
	var r := route.to_upper()
	var rel: Array
	if r.contains("POST"):
		rel = [[0, 0], [0.65 * D, 0], [D, s * 0.3 * D]]
	elif r.contains("CORNER"):
		rel = [[0, 0], [0.65 * D, 0], [D, -s * 0.28 * D]]
	elif r.contains("SLANT"):
		rel = [[0, 0], [3, 0], [D, s * D * 0.6]]
	elif r.contains("QUICK_OUT") or r == "OUT":
		rel = [[0, 0], [D, 0], [D, -s * 11]]
	elif r.contains("DIG") or r == "IN":
		rel = [[0, 0], [D, 0], [D, s * 18]]
	elif r.contains("CROSS") or r.contains("MESH"):
		rel = [[0, 0], [6, 0], [9, s * 34]]
	elif r.contains("HITCH") or r.contains("CURL"):
		rel = [[0, 0], [D, 0], [D - 5, -s * 3]]
	elif r.contains("FLAT"):
		rel = [[0, 0], [4, -s * 14]]
	elif r.contains("WHEEL"):
		rel = [[0, 0], [6, -s * 12], [D, -s * 14]]
	elif r.contains("SCREEN"):
		rel = [[0, 0], [-5, -s * 6], [-3, -s * 16]]
	else:
		rel = [[0, 0], [D, 0]]
	var pts: Array = []
	for q in rel:
		pts.append(start + Vector2(q[0], q[1]))
	return pts


# ------------------------------------------------------------------ drawing
func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


func _dashed(pts: Array, c: Color) -> void:
	var n := 0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
		for t in steps + 1:
			n += 1
			if n % 3 == 2:
				continue
			var k := float(t) / maxf(1.0, float(steps))
			var p := a.lerp(b, k)
			_px(p.x, p.y, 1, 1, c)
	if pts.size() >= 2:
		var end: Vector2 = pts[pts.size() - 1]
		var prev: Vector2 = pts[pts.size() - 2]
		var ang := (end - prev).angle()
		for off in [2.2, -2.2]:
			for t in range(1, 4):
				var q := end - Vector2.from_angle(ang + off * 0.4) * float(t)
				_px(q.x, q.y, 1, 1, c)


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
	var fd := v_fd if v_fd >= 0.0 else minf(float(W - EZ), los + roundf(float(state.distance) * YD))
	if fd > los + 1:
		draw_rect(Rect2(roundf(fd), FY0, 1, FH), FIRST_C)

	var off := offense(los)
	var moving := not _anim.is_empty()
	if not moving and not play.is_empty():
		if Sim.is_run(play):
			var rb: Vector2 = off["rb_1"]
			var dirs := {"LEFT": -11.0, "MIDDLE": 0.0, "RIGHT": 11.0}
			var dy: float = dirs.get(play.get("run_direction", "MIDDLE") if play.get("run_direction") != null else "MIDDLE", 0.0)
			_dashed([rb, Vector2(los - 1, rb.y + dy * 0.4), Vector2(los + 14, rb.y + dy)], ROUTE_C)
		else:
			for r in play.read_progression:
				if off.has(r.eligible_id):
					_dashed(route_points(off[r.eligible_id], r.route, float(r.depth_yards) if r.get("depth_yards") != null else 8.0), ROUTE_C)
	var ghost := def_tier == 0
	for d in defense(los):
		_sprite(d, GHOST if ghost else DEF_C)
	var carrier: String = _anim.get("carrier", "")
	for id in off:
		if carrier == id:
			continue
		_sprite(off[id], OFF_C, OFF_HI if id == "qb_1" else Color(0, 0, 0, 0))
	if moving:
		var pos: Vector2 = _anim.pos
		if carrier == "def":
			_sprite(pos + Vector2(0, 4), DEF_C, BALL_C)
		elif carrier != "":
			_sprite(pos, OFF_C, OFF_HI)
		if _anim.arc > 0:
			_px(pos.x, _anim.ground_y + 2, 3, 1, Color(0, 0, 0, 0.35))
		_px(pos.x - 1, pos.y - 1, 3, 3, DEF_C if _anim.bad_end else BALL_C)
	else:
		_px(los - 14, CY - 1, 3, 3, BALL_C)
	_draw_fx(los)


func _outlined(cx: float, y: float, s: String, scale_i: int, col: Color) -> void:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		Px.text_center(self, cx + o.x, y + o.y, s, scale_i, Color(0.02, 0.04, 0.13, 0.95))
	Px.text_center(self, cx, y, s, scale_i, col)


## Scoreboard plate, goal-line bonus and the rising yardage label.
func _draw_fx(los: float) -> void:
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	if goal_label != "":
		var cx := float(W - EZ / 2)
		if ez_flash > 0.0:
			draw_rect(Rect2(W - EZ, FY0, EZ, FH), Color(1, 0.95, 0.5, ez_flash * 0.7))
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
	var ytg := (float(W - EZ) - los) / float(YD)
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
func _build(out: Dictionary) -> Array:
	var r: Dictionary = out.result
	var pre: Dictionary = out.pre
	var los := x_of(100.0 - float(pre.yardline_to_opponent_goal))
	var ys := func(v: float) -> float:
		return clampf(x_of(100.0 - float(pre.yardline_to_opponent_goal) + v), float(EZ), float(W - 2))
	var end: float = ys.call(float(r.yards))
	var qb := Vector2(los - 13, CY)
	var offp := offense(los)
	var segs: Array = []
	var carry := func(f: Vector2, t: Vector2, id: String) -> void:
		segs.append({"d": maxf(0.5, absf(t.x - f.x) / 70.0), "f": f, "t": t, "arc": 0.0, "carrier": id})
	var o: String = r.outcome
	var code: String = out.card.code
	if o in ["FIELD_GOAL_GOOD", "FIELD_GOAL_MISSED"]:
		segs.append({"d": 1.4, "f": Vector2(los - 8, CY), "t": Vector2(W - EZ + 4, CY if o == "FIELD_GOAL_GOOD" else CY + 14), "arc": 40.0, "carrier": ""})
	elif o in ["PUNT", "TOUCHBACK"]:
		segs.append({"d": 1.6, "f": Vector2(los - 12, CY), "t": Vector2(minf(W - 4.0, maxf(los + 20, end + 20)), CY + 10), "arc": 48.0, "carrier": ""})
	elif Sim.is_run(play) or (code in ["KNL", "SPK"]):
		var rb: Vector2 = offp["rb_1"]
		segs.append({"d": 0.3, "f": Vector2(los, CY), "t": rb, "arc": 0.0, "carrier": ""})
		var dirs := {"LEFT": -9.0, "MIDDLE": 0.0, "RIGHT": 9.0}
		var rd = play.get("run_direction")
		carry.call(rb, Vector2(end, rb.y + float(dirs.get(rd if rd != null else "MIDDLE", 0.0))), "rb_1")
	else:
		segs.append({"d": 0.3, "f": Vector2(los, CY), "t": qb, "arc": 0.0, "carrier": ""})
		var reads: Array = play.read_progression
		var pick: Dictionary = reads[abs(hash(r.get("target_name", "x"))) % reads.size()] if reads.size() > 0 else {}
		var tgt: Vector2 = offp.get(pick.get("eligible_id", "wr_x"), offp["wr_x"])
		var air: float = ys.call(maxf(1.0, float(pick.get("depth_yards", 5.0)) if pick.get("depth_yards") != null else 5.0))
		if o == "SACK":
			carry.call(qb, Vector2(ys.call(float(r.yards)), qb.y + 3), "qb_1")
		elif o == "SCRAMBLE":
			carry.call(qb, Vector2(end, qb.y + 8), "qb_1")
		elif o in ["THROWAWAY", "INCOMPLETE"]:
			segs.append({"d": 0.9, "f": qb, "t": Vector2(air, tgt.y + (4.0 if o == "INCOMPLETE" else 16.0)), "arc": 16.0, "carrier": ""})
		elif o == "INTERCEPTION":
			segs.append({"d": 0.9, "f": qb, "t": Vector2(air, tgt.y), "arc": 16.0, "carrier": ""})
			carry.call(Vector2(air, tgt.y), Vector2(air - 20, tgt.y + 5), "def")
		else:
			segs.append({"d": 0.9, "f": qb, "t": Vector2(air, tgt.y), "arc": 16.0, "carrier": ""})
			if end > air:
				carry.call(Vector2(air, tgt.y), Vector2(end, tgt.y), "")
	return segs


func animate(out: Dictionary) -> void:
	var segs := _build(out)
	_t = 0.0
	_anim = {"segs": segs, "i": 0, "pos": Vector2.ZERO, "carrier": "", "arc": 0.0, "ground_y": 0.0,
			"bad_end": bool(out.result.turnover), "hold": 0.0}
	set_process(true)


func _process(delta: float) -> void:
	if _anim.is_empty():
		if show_plate or goal_label != "":
			queue_redraw()                    # the plate, pulse and tweens redraw every frame
		else:
			set_process(false)
		return
	var segs: Array = _anim.segs
	_t += delta
	while _anim.i < segs.size() and _t >= float(segs[_anim.i].d):
		_t -= float(segs[_anim.i].d)
		_anim.i += 1
	if _anim.i >= segs.size():
		var last: Dictionary = segs[segs.size() - 1]
		_anim.pos = last.t
		_anim.carrier = last.carrier
		_anim.arc = 0.0
		_anim.ground_y = last.t.y
		_anim.hold += delta
		if _anim.hold > 0.5:
			_anim = {}
			anim_done.emit()
	else:
		var seg: Dictionary = segs[_anim.i]
		var k: float = clampf(_t / float(seg.d), 0.0, 1.0)
		var e: float = k * (2.0 - k)
		var base: Vector2 = seg.f.lerp(seg.t, e)
		_anim.ground_y = base.y
		_anim.pos = Vector2(base.x, base.y - float(seg.arc) * sin(PI * k))
		_anim.carrier = seg.carrier
		_anim.arc = seg.arc
	queue_redraw()
