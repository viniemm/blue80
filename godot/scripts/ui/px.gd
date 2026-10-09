class_name Px
extends RefCounted
## Palette, pixel fonts and small drawing helpers shared by every view.

const BG := Color("060b22")
const PANEL := Color("0a1230")
const PANEL2 := Color("101c4a")
const LINE := Color("2a3a7a")
const FG := Color("f4f6ff")
const DIM := Color("8c97c8")
const GOLD := Color("ffcc33")
const RED := Color("ff4d4d")
const GREEN := Color("3fd07a")
const ROYAL := Color("6f8cff")

## Text scales: 0 = tiny and 1 = body (VT323), 2 = small heading and 3 = big heading (Press Start 2P).
const SIZES := {0: 12, 1: 14, 2: 8, 3: 16}
const BODY_PATH := "res://assets/fonts/VT323-Regular.ttf"
const HEAD_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

static var _body: FontFile
static var _head: FontFile


static func _load(path: String) -> FontFile:
	# load() uses the imported font, which is what an exported build contains; reading the .ttf from disk only works
	# when running from the editor (the web build rendered every glyph as an empty box).
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE      # keep pixel edges hard
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


static func font(scale: int) -> FontFile:
	if scale >= 2:
		if _head == null:
			_head = _load(HEAD_PATH)
		return _head
	if _body == null:
		_body = _load(BODY_PATH)
	return _body


static func line_height(scale: int = 1) -> int:
	return int(font(scale).get_height(SIZES[scale]))


## Draw text with its top-left at (x, y).
static func text(ci: CanvasItem, x: float, y: float, s: String, scale: int = 1, color: Color = FG) -> void:
	var f := font(scale)
	var size: int = SIZES[scale]
	ci.draw_string(f, Vector2(roundf(x), roundf(y) + f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Press Start 2P at an arbitrary pixel size (multiples of 8 stay crisp), for logos.
static func big(ci: CanvasItem, x: float, y: float, s: String, size: int, color: Color) -> void:
	var f := font(3)
	ci.draw_string(f, Vector2(roundf(x), roundf(y) + f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(s: String, scale: int = 1) -> float:
	return font(scale).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZES[scale]).x


static func text_center(ci: CanvasItem, cx: float, y: float, s: String, scale: int = 1, color: Color = FG) -> void:
	text(ci, cx - text_width(s, scale) / 2.0, y, s, scale, color)


static func text_right(ci: CanvasItem, rx: float, y: float, s: String, scale: int = 1, color: Color = FG) -> void:
	text(ci, rx - text_width(s, scale), y, s, scale, color)


## Draw a 5x5 (or any) bitmap icon given as rows of '0'/'1' strings, scaled by `k`.
static func icon(ci: CanvasItem, x: float, y: float, rows: Array, k: int, color: Color) -> void:
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "1":
				ci.draw_rect(Rect2(x + rx * k, y + ry * k, k, k), color)


## Box with a 1px border.
static func box(ci: CanvasItem, r: Rect2, fill: Color, border: Color) -> void:
	ci.draw_rect(r, border)
	ci.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill)


## Word-wrap `s` into lines no wider than `max_px`.
static func wrap(s: String, max_px: float, scale: int = 1) -> Array:
	var lines: Array = []
	var cur := ""
	for word in s.split(" "):
		if cur == "":
			cur = word
		elif text_width(cur + " " + word, scale) <= max_px:
			cur += " " + word
		else:
			lines.append(cur)
			cur = word
	if cur != "":
		lines.append(cur)
	return lines
