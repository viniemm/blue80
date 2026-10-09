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
var shine := false:                 # draws attention: a sheen sweeps across and the outline pulses
	set(v):
		shine = v
		set_process(v)
		queue_redraw()
var _down := false


func _init(text: String = "", color: Color = Px.GOLD, size_px: Vector2 = Vector2(100, 32)) -> void:
	label = text
	fill = color
	custom_minimum_size = size_px
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_d: float) -> void:
	queue_redraw()


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
			Sfx.play("click")
			pressed.emit()


func _draw() -> void:
	var off := 2 if _down else 0
	if not disabled and not _down:
		draw_rect(Rect2(2, 3, size.x - 2, size.y - 2), Color(0, 0, 0, 0.55))     # drop shadow
	var f := Px.LINE if disabled else fill
	var t := Px.DIM if disabled else ink
	draw_rect(Rect2(off, off, size.x - 2, size.y - 2), f)
	Px.text_center(self, off + (size.x - 2) / 2.0, off + (size.y - 2 - Px.line_height(scale_px)) / 2.0, label, scale_px, t)
	if shine and not disabled:
		var now := Time.get_ticks_msec() / 1000.0
		var w := size.x - 2
		var h := size.y - 2
		var k := fposmod(now / 1.6, 1.0)                                 # sheen: a slanted white band sweeping left to right
		var x0 := -40.0 + k * (w + 80.0)
		var slant := 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(x0, off), Vector2(x0 + 26, off), Vector2(x0 + 26 - slant, off + h), Vector2(x0 - slant, off + h)]), Color(1, 1, 1, 0.5))
		var pulse := 0.5 + 0.5 * sin(now * 6.0)
		draw_rect(Rect2(off, off, w, h), Color(1, 1, 1, 0.35 + 0.65 * pulse), false, 2.0)
