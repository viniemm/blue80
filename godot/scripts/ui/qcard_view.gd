class_name QCardView
extends Control
## A playing card for the betting game.
##   BRONZE / SILVER  red or black face (by suit) with a bronze or silver border
##   GOLD             solid gold face, dark text
##   PLATINUM         platinum face, black text, and a sheen that sweeps across the card
## mode "mine": rank, play family, play name and tier. mode "theirs": defense card, rank and style chip.

signal tapped(index: int)

const BORDER := {"BRONZE": Color("cd7f32"), "SILVER": Color("c8d0de"), "GOLD": Color("8a6a00"), "PLATINUM": Color("9fb4c7")}
const RED_FACE := Color("8f1d1d")
const BLACK_FACE := Color("14161c")
const INK_DARK := Color("12100a")
const RED_INK := Color("9a1818")
const SUIT_IS_RED := [false, true, false, true]                       # RUN black, RPO red, PASS black, SHOT red
const SUIT_ICON_KEY := ["RUN", "PA", "MID", "DEEP"]
const STYLE_COLORS := {"BLITZ": Color("ff4d4d"), "ZONE": Color("33c8ff"), "MAN": Color("ffcc33"), "BALANCED": Color("8c97c8")}
const SHEEN_PERIOD := 2.4

var card: Dictionary = {}
var mode := "mine"
var index := 0
var face_up := true:
	set(v):
		face_up = v
		queue_redraw()
var marked := false:
	set(v):
		marked = v
		queue_redraw()
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()


func _init(c: Dictionary = {}, mode_value: String = "mine", idx: int = 0) -> void:
	card = c
	mode = mode_value
	index = idx
	var s := Vector2(64, 90) if mode == "mine" else Vector2(62, 52)
	custom_minimum_size = s
	size = s
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "mine" else Control.MOUSE_FILTER_IGNORE
	set_process(not c.is_empty() and c.tier in ["PLATINUM", "GOLD"])


func _process(_delta: float) -> void:
	if face_up:
		queue_redraw()          # keeps the sheen and the twinkle moving


func _gui_input(e: InputEvent) -> void:
	if mode == "mine" and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		tapped.emit(index)


# ------------------------------------------------------------------ face painting
## Returns {ink, accent} colors for text and the small rank/suit marks on this card's face.
func _paint_face(w: float, h: float) -> Dictionary:
	var tier: String = card.tier
	var red: bool = SUIT_IS_RED[card.suit]
	var border: Color = Px.GOLD if highlight else BORDER[tier]
	match tier:
		"GOLD":
			draw_rect(Rect2(0, 0, w, h), border)
			draw_rect(Rect2(2, 2, w - 4, h - 4), Color("d9a21c"))
			draw_rect(Rect2(2, 2, w - 4, (h - 4) * 0.62), Color("f2c14e"))
			draw_rect(Rect2(2, 2, w - 4, (h - 4) * 0.28), Color("ffd766"))
			draw_rect(Rect2(3, 3, w - 6, 1), Color("fff0a8"))
			return {"ink": INK_DARK, "accent": RED_INK if red else INK_DARK}
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
		Px.text(self, 5, 5, str(card.label), 2, accent)
		Px.icon(self, w - 15, 5, Cards.SUIT_ICONS[SUIT_ICON_KEY[card.suit]], 2, accent)
		var lines := Px.wrap(card.name, w - 8, 0)
		var lh := Px.line_height(0) - 2
		var y := 18.0 + (h - 38.0 - lines.size() * lh) / 2.0
		for l in lines:
			Px.text_center(self, w / 2.0, y, l, 0, ink)
			y += lh
		draw_rect(Rect2(4, h - 17, w - 8, 1), Color(ink, 0.45))
		Px.text_center(self, w / 2.0, h - 15, tier, 0, ink if tier in ["GOLD", "PLATINUM"] else BORDER[tier])
	else:
		var style: String = QGame.STYLE_OF_SUIT[card.suit]
		Px.text(self, 5, 4, str(card.label), 2, accent)
		draw_rect(Rect2(4, 18, w - 8, 15), Color("0a0a1a"))              # dark outline keeps the chip readable on gold
		draw_rect(Rect2(5, 19, w - 10, 13), STYLE_COLORS[style])
		Px.text_center(self, w / 2.0, 19, style, 0, Color("0a0a1a"))
		Px.text_center(self, w / 2.0, 35, tier, 0, ink if tier in ["GOLD", "PLATINUM"] else BORDER[tier])
	if tier == "PLATINUM":
		_draw_sheen(w, h)
	elif tier == "GOLD":
		_draw_twinkle(w, h)
	if marked:
		draw_rect(Rect2(0, 0, w, h), Color(Px.RED, 0.38))
		Px.text_center(self, w / 2.0, h / 2.0 - 8, "X", 3, Color.WHITE)
