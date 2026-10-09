class_name FloatText
extends Control
## Outlined text that pops in, drifts up and fades. Add it to a layer; it frees itself.

var text := ""
var color := Px.GOLD
var scale_i := 3


func _init(t: String, c: Color, s: int = 3) -> void:
	text = t
	color = c
	scale_i = s
	size = Vector2(360, 24)
	pivot_offset = Vector2(180, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	scale = Vector2(1.7, 1.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - 36.0, 1.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.95)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 1)]:
		Px.text_center(self, 180.0 + o.x, o.y, text, scale_i, Color(0, 0, 0, 0.9))
	Px.text_center(self, 180.0, 0, text, scale_i, color)
