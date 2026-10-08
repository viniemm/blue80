class_name PxButton
extends Control
## A chunky pixel button. Emits `pressed` on tap.

signal pressed

var label := "BUTTON"
var fill := Px.GOLD
var ink := Color("000000")
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var scale_px := 2
var _down := false


func _init(text: String = "", color: Color = Px.GOLD, size_px: Vector2 = Vector2(100, 32)) -> void:
	label = text
	fill = color
	custom_minimum_size = size_px
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_label(t: String) -> void:
	label = t
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_down = e.pressed
		queue_redraw()
		if not e.pressed:
			pressed.emit()


func _draw() -> void:
	var off := 2 if _down else 0
	if not disabled and not _down:
		draw_rect(Rect2(2, 3, size.x - 2, size.y - 2), Color(0, 0, 0, 0.55))     # drop shadow
	var f := Px.LINE if disabled else fill
	var t := Px.DIM if disabled else ink
	draw_rect(Rect2(off, off, size.x - 2, size.y - 2), f)
	Px.text_center(self, off + (size.x - 2) / 2.0, off + (size.y - 2 - Px.line_height(scale_px)) / 2.0, label, scale_px, t)
