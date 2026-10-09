class_name PxScreen
extends Control
## Base for the full-screen pages (splash, menu, help, ...): a backdrop of real game cards drifting upward, the logo
## and a pixel football. Subclasses override `_paint()` and emit `go(target)` to change screens.
## The backdrop lives in child layers drawn behind this node, so `_paint()` text always sits on top of the cards.

signal go(target: String)

const W := 360
const H := 640
const BALL := [
	"000001111100000",
	"001111111111100",
	"011111111111110",
	"111113131311111",
	"111133333331111",
	"022222222222220",
	"002222222222200",
	"000002222200000",
]
const BALL_COLORS := {"1": Color("b4601f"), "2": Color("7a3a12"), "3": Color("f4f6ff")}
const DRIFT_CARDS := 9

class Layer extends Control:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)

var t := 0.0
var _bg: Layer
var _vig: Layer
var _cards: Array = []              # {view: QCardView, x, y, r, s, w}


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = _layer(_draw_bg)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var deck := Deck52.build_all()
	for i in DRIFT_CARDS:
		var c: Dictionary = deck[rng.randi_range(0, deck.size() - 1)]
		var v := QCardView.new(c, "mine", i)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.modulate = Color(1, 1, 1, 0.5)
		v.show_behind_parent = true                   # drawn before this node's own text, after the backdrop
		add_child(v)
		_cards.append({"view": v, "x": rng.randf_range(10, 286), "y": rng.randf_range(0, 760), "r": rng.randf_range(-0.5, 0.5),
				"s": rng.randf_range(6, 16), "w": rng.randf_range(0.3, 0.8)})
	_vig = _layer(_draw_vignette)
	_place_cards()


## Fade the drifting cards (text-heavy pages keep them faint so the words stay readable).
func set_card_alpha(a: float) -> void:
	for c in _cards:
		c.view.modulate = Color(1, 1, 1, a)


func _layer(fn: Callable) -> Layer:
	var l := Layer.new()
	l.size = Vector2(W, H)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.show_behind_parent = true
	l.fn = fn
	add_child(l)
	return l


func _place_cards() -> void:
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var v: QCardView = c.view
		var y := fposmod(float(c.y) - t * float(c.s), H + 160.0) - 90.0
		v.position = Vector2(c.x, y)
		v.rotation = float(c.r) + sin(t * float(c.w) + i) * 0.12


func _process(d: float) -> void:
	t += d
	_place_cards()
	_bg.queue_redraw()
	queue_redraw()


func _draw_bg(l: Control) -> void:
	l.draw_rect(Rect2(0, 0, W, H), Px.BG)
	var off := fposmod(t * 8.0, 48.0)
	for i in range(-1, 15):
		l.draw_rect(Rect2(0, i * 48 + off, W, 24), Color(Px.PANEL2, 0.4))


func _draw_vignette(l: Control) -> void:
	for i in 10:
		var a := 0.55 * (1.0 - i / 10.0)
		l.draw_rect(Rect2(0, i * 6, W, 6), Color(0, 0, 0, a))
		l.draw_rect(Rect2(0, H - (i + 1) * 6, W, 6), Color(0, 0, 0, a))


func _draw() -> void:
	_paint()


func _paint() -> void:
	pass


## "BLUE 80" in Press Start 2P. `anim_t` < INF drops the letters in one by one with a white flash on landing.
func logo(cx: float, y: float, px: int, anim_t: float = INF) -> void:
	var x0 := cx - 3.5 * px
	var word := "BLUE 80"
	for i in word.length():
		if word[i] == " ":
			continue
		var k := clampf((anim_t - 0.4 - i * 0.14) / 0.35, 0.0, 1.0)
		if k <= 0.0:
			continue
		var drop := -pow(1.0 - k, 3.0) * px * 2.0
		var x := x0 + i * px
		var gold := i >= 5
		var shadow := Color("8a1c1c") if gold else Color("1c2f8f")
		var face := Px.GOLD if gold else Px.FG
		if k < 1.0 and k > 0.6:
			face = Color.WHITE
		Px.big(self, x + px / 16.0, y + drop + px / 16.0, word[i], px, shadow)
		Px.big(self, x, y + drop, word[i], px, face)


func ball(x: float, y: float, k: int = 3) -> void:
	for ry in BALL.size():
		var row: String = BALL[ry]
		for rx in row.length():
			var ch := row[rx]
			if ch != "0":
				draw_rect(Rect2(x + rx * k, y + ry * k, k, k), BALL_COLORS[ch])


func banner(title: String) -> void:
	draw_rect(Rect2(0, 0, W, 40), Color("14247a"))
	draw_rect(Rect2(0, 39, W, 1), Px.ROYAL)
	Px.text_center(self, W / 2.0, 12, title, 3, Px.GOLD)


func add_btn(text: String, color: Color, rect: Rect2, cb: Callable) -> PxButton:
	var b := PxButton.new(text, color, rect.size)
	b.position = rect.position
	b.pressed.connect(cb)
	add_child(b)
	return b


func add_back(label: String = "BACK") -> PxButton:
	return add_btn(label, Px.ROYAL, Rect2(110, 594, 140, 30), func(): go.emit("menu"))


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		go.emit("menu")
