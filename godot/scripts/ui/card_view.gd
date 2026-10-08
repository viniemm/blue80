class_name CardView
extends Control
## A play card: rank + suit icon, name, suit tag. Tap to select; lifts when selected.

signal tapped(card: Dictionary)

const W := 66
const H := 100

var card: Dictionary = {}
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var marked := false:        # marked for discard
	set(v):
		marked = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()


func _init(c: Dictionary = {}) -> void:
	card = c
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		tapped.emit(card)


func _draw() -> void:
	var col: Color = Cards.SUIT_COLORS[card.suit]
	var border := Px.GOLD if selected else col
	draw_rect(Rect2(2, 3, W - 2, H - 2), Color(0, 0, 0, 0.5))
	Px.box(self, Rect2(0, 0, W - 2, H - 2), Px.PANEL2, border)
	if selected:
		draw_rect(Rect2(2, 2, W - 6, H - 6), Px.GOLD, false, 1.0)
	# header strip in the suit color
	draw_rect(Rect2(2, 2, W - 6, 17), Color(col, 0.28))
	Px.text(self, 5, 6, str(card.rank), 2, col)
	Px.icon(self, W - 18, 6, Cards.SUIT_ICONS[card.suit], 2, col)
	# name, wrapped to the card width and centered between the header and the tag
	var lines := Px.wrap(card.name, 56.0, 1)
	var lh := Px.line_height(1) - 2
	var y := 20.0 + (H - 44.0 - lines.size() * lh) / 2.0
	for l in lines:
		Px.text_center(self, (W - 2) / 2.0, y, l, 1, Px.FG)
		y += lh
	# suit tag
	draw_rect(Rect2(2, H - 22, W - 6, 1), Color(col, 0.5))
	Px.text_center(self, (W - 2) / 2.0, H - 19, card.suit, 1, col)
	if dimmed:
		draw_rect(Rect2(0, 0, W - 2, H - 2), Color(0, 0, 0, 0.45))
	if marked:
		draw_rect(Rect2(0, 0, W - 2, H - 2), Color(Px.RED, 0.35))
		Px.text_center(self, (W - 2) / 2.0, 44, "X", 3, Px.RED)
