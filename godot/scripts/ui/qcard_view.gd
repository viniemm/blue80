class_name QCardView
extends Control
## A playing card for the betting game.
##   BRONZE / SILVER  red or black face (by suit) with a bronze or silver border
##   GOLD             solid gold face, dark text
##   PLATINUM         platinum face, black text, and a sheen that sweeps across the card
## mode "mine": rank, play family, play name and tier. mode "theirs": defense card, rank and style chip.

signal tapped(index: int)
signal inspected(index: int)       # right-click or a long press: open the play's info
signal hovered(index: int)

const BORDER := {"BRONZE": Color("cd7f32"), "SILVER": Color("c8d0de"), "GOLD": Color("8a6a00"), "PLATINUM": Color("9fb4c7"), "JOKER": Color("d46bff")}
const RED_FACE := Color("8f1d1d")
const BLACK_FACE := Color("14161c")
const INK_DARK := Color("12100a")
const RED_INK := Color("9a1818")
const SUIT_IS_RED := [false, true, false, true]                       # RUN black, RPO red, PASS black, SHOT red
const SUIT_ICON_KEY := ["RUN", "PA", "MID", "DEEP"]
const STYLE_COLORS := {"BLITZ": Color("ff4d4d"), "ZONE": Color("33c8ff"), "MAN": Color("ffcc33"), "BALANCED": Color("8c97c8"), "WILD": Color("d46bff")}
const SHEEN_PERIOD := 2.4
const STAR := ["00100", "00100", "11111", "01110", "10101"]

var card: Dictionary = {}
var mode := "mine"
var index := 0
var home := Vector2.ZERO          # resting position; animations move the card away from it and back
var lift_y := 0.0:                 # raised while marked for discard or when it is the lead card
	set(v):
		lift_y = v
		if not _dealing:
			position.y = home.y + v
var flash_a := 0.0:
	set(v):
		flash_a = v
		queue_redraw()
var flash_color := Color.WHITE
var eligible := false:             # may be chosen as the play
	set(v):
		eligible = v
		queue_redraw()
var dimmed := false:               # not part of the made hand
	set(v):
		dimmed = v
		queue_redraw()
var face_up := true:
	set(v):
		face_up = v
		queue_redraw()
var marked := false:
	set(v):
		if v == marked:
			return
		marked = v
		queue_redraw()
		_update_lift()
		if v:
			Sfx.play("mark", 0.0, 0.05)
var highlight := false:
	set(v):
		if v == highlight:
			return
		highlight = v
		queue_redraw()
		_update_lift()
		_update_process()

var _dealing := false
var _flip_target := true
var _t_lift: Tween
var _t_flip: Tween
var _t_pop: Tween


func _init(c: Dictionary = {}, mode_value: String = "mine", idx: int = 0) -> void:
	card = c
	mode = mode_value
	index = idx
	var s := Vector2(64, 90) if mode == "mine" else Vector2(62, 52)
	custom_minimum_size = s
	size = s
	pivot_offset = s / 2.0
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "mine" else Control.MOUSE_FILTER_IGNORE
	_update_process()
	mouse_entered.connect(func(): hovered.emit(index))


func set_card(c: Dictionary) -> void:
	card = c
	_update_process()
	queue_redraw()


func _update_process() -> void:
	set_process(highlight or (not card.is_empty() and card.tier in ["PLATINUM", "GOLD", "JOKER"]))


func _process(_delta: float) -> void:
	if face_up:
		queue_redraw()          # keeps the sheen, the twinkle and the lead-card pulse moving


# ------------------------------------------------------------------ animation
func place(p: Vector2) -> void:
	position = p
	home = p


func _update_lift() -> void:
	var target := -10.0 if marked else (-6.0 if highlight else 0.0)
	if _t_lift:
		_t_lift.kill()
	_t_lift = create_tween() if is_inside_tree() else null
	if _t_lift:
		_t_lift.tween_property(self, "lift_y", target, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lift_y = target


## Fly in from `from` (the shoe), spinning slightly, face-down; optionally flip face-up on arrival.
func deal_in(from: Vector2, delay: float, flip_up: bool) -> void:
	face_up = false
	_flip_target = false
	_dealing = true
	Sfx.play("deal", delay, 0.08)
	var spin := randf_range(-0.7, 0.7)
	position = from
	rotation = spin
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_deal_step.bind(from, spin), 0.0, 1.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_deal_done)
	if flip_up:
		flip_to(true, delay + 0.38)


func _deal_step(k: float, from: Vector2, spin: float) -> void:
	position = from.lerp(home + Vector2(0, lift_y), k)
	rotation = spin * (1.0 - clampf(k, 0.0, 1.0))
	var s := lerpf(0.7, 1.0, clampf(k, 0.0, 1.0))
	scale = Vector2(s, s)
	modulate.a = clampf(k * 6.0, 0.0, 1.0)


func _deal_done() -> void:
	_dealing = false
	position = home + Vector2(0, lift_y)
	rotation = 0.0
	scale = Vector2.ONE
	modulate.a = 1.0


## Squash to a sliver, swap the face, and widen again.
func flip_to(up: bool, delay: float = 0.0) -> void:
	if up == _flip_target:
		return
	_flip_target = up
	Sfx.play("flip", delay, 0.05)
	if _t_flip:
		_t_flip.kill()
	_t_flip = create_tween()
	_t_flip.tween_interval(delay)
	_t_flip.tween_property(self, "scale:x", 0.02, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_t_flip.tween_callback(func(): face_up = up)
	_t_flip.tween_property(self, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fly_out(to: Vector2, delay: float = 0.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dealing = true                                   # stops lift/position bookkeeping from fighting the tween
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", to, 0.32).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", randf_range(-0.9, 0.9), 0.32).set_delay(delay)
	tw.tween_property(self, "modulate:a", 0.0, 0.32).set_delay(delay)
	tw.chain().tween_callback(queue_free)


func pop(amount: float = 1.18) -> void:
	if _t_pop:
		_t_pop.kill()
	z_index = 5
	_t_pop = create_tween()
	_t_pop.tween_property(self, "scale", Vector2(amount, amount), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_t_pop.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_t_pop.tween_callback(func(): z_index = 0)


func shake(mag: float = 5.0) -> void:
	var tw := create_tween()
	var x0 := position.x
	for i in 6:
		tw.tween_property(self, "position:x", x0 + (mag if i % 2 == 0 else -mag) * (1.0 - i / 6.0), 0.045)
	tw.tween_property(self, "position:x", x0, 0.04)


func flash(color: Color) -> void:
	flash_color = color
	flash_a = 0.7
	create_tween().tween_property(self, "flash_a", 0.0, 0.5)


var _press_id := 0
var _long := false


## The little (i) badge on a face-up hand card opens the play info with one tap, no hover or long press needed.
func _badge_rect() -> Rect2:
	return Rect2(size.x - 26, size.y - 46, 26, 30)


func _gui_input(e: InputEvent) -> void:
	if mode != "mine" or not (e is InputEventMouseButton):
		return
	if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		inspected.emit(index)
	elif e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and face_up and _badge_rect().has_point(e.position):
			_press_id += 1
			_long = true                                       # swallow the release so it is not a tap
			inspected.emit(index)
		elif e.pressed:
			_press_id += 1
			_long = false
			get_tree().create_timer(0.5).timeout.connect(_long_press.bind(_press_id))
		else:
			_press_id += 1                                 # cancels a pending long press
			if not _long:
				tapped.emit(index)


func _long_press(id: int) -> void:
	if id == _press_id and is_inside_tree():
		_long = true
		inspected.emit(index)


# ------------------------------------------------------------------ face painting
## Returns {ink, accent} colors for text and the small rank/suit marks on this card's face.
func _paint_face(w: float, h: float) -> Dictionary:
	var tier: String = card.tier
	var red: bool = card.suit < 4 and SUIT_IS_RED[card.suit]
	var border: Color = Px.GOLD if highlight else BORDER[tier]
	match tier:
		"GOLD":
			draw_rect(Rect2(0, 0, w, h), border)
			draw_rect(Rect2(2, 2, w - 4, h - 4), Color("d9a21c"))
			draw_rect(Rect2(2, 2, w - 4, (h - 4) * 0.62), Color("f2c14e"))
			draw_rect(Rect2(2, 2, w - 4, (h - 4) * 0.28), Color("ffd766"))
			draw_rect(Rect2(3, 3, w - 6, 1), Color("fff0a8"))
			return {"ink": INK_DARK, "accent": RED_INK if red else INK_DARK}
		"JOKER":
			draw_rect(Rect2(0, 0, w, h), border)
			draw_rect(Rect2(2, 2, w - 4, h - 4), Color("2a1252"))
			var t := Time.get_ticks_msec() / 1000.0
			for i in 6:                                                # a slow rainbow ribbon along the top
				draw_rect(Rect2(2 + i * (w - 4) / 6.0, 2, (w - 4) / 6.0 + 1, 12), Color.from_hsv(fposmod(t * 0.25 + i / 6.0, 1.0), 0.65, 1.0))
			draw_rect(Rect2(2, 2, w - 4, 1), Color(1, 1, 1, 0.6))
			return {"ink": Color("f4f6ff"), "accent": Color("0a0a1a")}
		"PLATINUM":
			draw_rect(Rect2(0, 0, w, h), border)
			draw_rect(Rect2(2, 2, w - 4, h - 4), Color("c3ced9"))
			draw_rect(Rect2(2, 2, w - 4, (h - 4) * 0.6), Color("dde6ef"))
			draw_rect(Rect2(2, 2, w - 4, (h - 4) * 0.25), Color("f2f7fb"))
			draw_rect(Rect2(3, 3, w - 6, 1), Color.WHITE)
			return {"ink": Color.BLACK, "accent": RED_INK if red else Color.BLACK}
		_:
			draw_rect(Rect2(0, 0, w, h), border)
			draw_rect(Rect2(2, 2, w - 4, h - 4), RED_FACE if red else BLACK_FACE)
			draw_rect(Rect2(2, 2, w - 4, 13), Color(1, 1, 1, 0.07))
			return {"ink": Color("f4f6ff"), "accent": Color("ffd0d0") if red else Color("f4f6ff")}


func _draw_sheen(w: float, h: float) -> void:
	var t := fposmod(Time.get_ticks_msec() / 1000.0 / SHEEN_PERIOD + float(index) * 0.17, 1.0)
	var bw := 16.0
	var slant := 24.0
	var x0 := -bw - slant + t * (w + bw + slant * 2.0)
	var poly := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + bw, 0), Vector2(x0 + bw - slant, h), Vector2(x0 - slant, h)])
	draw_colored_polygon(poly, Color(1, 1, 1, 0.42))
	var thin := PackedVector2Array([Vector2(x0 + bw + 3, 0), Vector2(x0 + bw + 6, 0), Vector2(x0 + bw + 6 - slant, h), Vector2(x0 + bw + 3 - slant, h)])
	draw_colored_polygon(thin, Color(1, 1, 1, 0.28))


## Little four-point stars that blink at fixed spots on gold cards (offset per card so they don't pulse in sync).
func _draw_twinkle(w: float, h: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 5:
		var px := 7.0 + fposmod(float(i) * 37.0 + float(index) * 13.0, w - 16.0)
		var py := 6.0 + fposmod(float(i) * 53.0 + float(index) * 29.0, h - 28.0)
		var b: float = pow(maxf(0.0, sin(t * 2.4 + float(i) * 1.7 + float(index) * 0.9)), 7.0)
		if b < 0.12:
			continue
		var col := Color(1.0, 0.98, 0.82, minf(1.0, b * 1.3))
		var x := roundf(px)
		var y := roundf(py)
		draw_rect(Rect2(x, y, 1, 1), col)
		draw_rect(Rect2(x - 1, y, 3, 1), col)
		draw_rect(Rect2(x, y - 1, 1, 3), col)
		if b > 0.55:
			draw_rect(Rect2(x - 2, y, 5, 1), col)
			draw_rect(Rect2(x, y - 2, 1, 5), col)


func _draw() -> void:
	var w := size.x - 2
	var h := size.y - 2
	draw_rect(Rect2(2, 3, w, h), Color(0, 0, 0, 0.5))
	if not face_up:
		Px.box(self, Rect2(0, 0, w, h), Color("1c2f8f"), Px.ROYAL)
		for i in range(-int(h), int(w), 6):
			draw_line(Vector2(i, 0), Vector2(i + h, h), Color("2a4fd6"), 1.0)
		Px.text_center(self, w / 2.0, h / 2.0 - 6, "?", 3, Px.GOLD)
		return
	var tier: String = card.tier
	var paint := _paint_face(w, h)
	var ink: Color = paint.ink
	var accent: Color = paint.accent
	if mode == "mine":
		var joker: bool = card.get("joker", false)
		Px.text(self, 5, 5, str(card.label), 2, accent if not joker else Color("0a0a1a"))
		if joker:
			Px.icon(self, w - 15, 5, STAR, 2, Color("0a0a1a"))
		else:
			Px.icon(self, w - 15, 5, Cards.SUIT_ICONS[SUIT_ICON_KEY[card.suit]], 2, accent)
		var lines := Px.wrap(card.name, w - 8, 0)
		var lh := Px.line_height(0) - 2
		var y := 19.0 + (h - 62.0 - lines.size() * lh) / 2.0
		for l in lines:
			Px.text_center(self, w / 2.0, y, l, 0, ink)
			y += lh
		# strength and weakness: the defense styles this play likes and fears
		var info: Dictionary = card.get("info", {})
		if not info.is_empty():
			var good := Color("1c7a3a") if tier in ["GOLD", "PLATINUM"] else Color("6fe39a")
			var bad := Color("a01818") if tier in ["GOLD", "PLATINUM"] else Color("ff7a7a")
			Px.text(self, 5, h - 41, "+" + info.strong, 0, good)
			Px.text(self, 5, h - 29, "-" + info.weak, 0, bad)
		var bx := w - 14.0
		var by := h - 33.0
		draw_circle(Vector2(bx, by), 7.0, Color(ink, 0.9))
		draw_circle(Vector2(bx, by), 5.5, Color("1c2f8f") if tier not in ["GOLD", "PLATINUM"] else Color("3a4a8a"))
		Px.text_center(self, bx, by - 6, "i", 0, Color.WHITE)
		draw_rect(Rect2(4, h - 17, w - 8, 1), Color(ink, 0.45))
		var tcol: Color = ink if tier in ["GOLD", "PLATINUM", "JOKER"] else BORDER[tier]
		Px.text_center(self, w / 2.0, h - 15, "WILD" if card.get("joker", false) else tier, 0, tcol)
	else:
		var style: String = QGame.STYLE_OF_SUIT[card.suit] if card.suit < 4 else "WILD"
		Px.text(self, 5, 4, str(card.label), 2, accent)
		draw_rect(Rect2(4, 18, w - 8, 15), Color("0a0a1a"))              # dark outline keeps the chip readable on gold
		draw_rect(Rect2(5, 19, w - 10, 13), STYLE_COLORS[style])
		Px.text_center(self, w / 2.0, 19, style, 0, Color("0a0a1a"))
		Px.text_center(self, w / 2.0, 35, tier, 0, ink if tier in ["GOLD", "PLATINUM"] else BORDER[tier])
	if tier == "PLATINUM":
		_draw_sheen(w, h)
	elif tier == "JOKER":
		_draw_twinkle(w, h)
	elif tier == "GOLD":
		_draw_twinkle(w, h)
	if highlight and mode == "mine":
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		draw_rect(Rect2(0, 0, w, h), Color(Px.GOLD, 0.12 + 0.12 * pulse))               # a warm wash over the whole card
		draw_rect(Rect2(0, 0, w, h), Color(Px.GOLD, 0.6 + 0.4 * pulse), false, 3.0)
		draw_rect(Rect2(3, h - 17, w - 6, 15), Px.GOLD)                                   # PLAY tag replaces the tier line
		Px.text_center(self, w / 2.0, h - 16, "> PLAY <", 0, Color("0a0a1a"))
	elif highlight:
		var pulse2 := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		draw_rect(Rect2(0, 0, w, h), Color(Px.GOLD, pulse2), false, 2.0)
	if eligible and not highlight:
		draw_rect(Rect2(0, 0, w, h), Color(Px.GOLD, 0.55), false, 2.0)
		draw_rect(Rect2(3, h - 17, w - 6, 15), Color("0a0a1a"))
		draw_rect(Rect2(3, h - 17, w - 6, 15), Color(Px.GOLD, 0.7), false, 1.0)
		Px.text_center(self, w / 2.0, h - 16, "TAP TO PLAY", 0, Px.GOLD)
	if flash_a > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(flash_color, flash_a))
	if dimmed:
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.04, 0.13, 0.6))
	if marked:
		draw_rect(Rect2(0, 0, w, h), Color(Px.RED, 0.38))
		Px.text_center(self, w / 2.0, h / 2.0 - 8, "X", 3, Color.WHITE)
