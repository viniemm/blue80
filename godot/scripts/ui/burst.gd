class_name Burst
extends Control
## A one-shot spray of pixel confetti from `origin`. Frees itself when it has faded.

var parts: Array = []
var age := 0.0
var life := 1.4


func _init(origin: Vector2, count: int, colors: Array, power: float = 170.0) -> void:
	size = Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var sp := randf_range(0.35, 1.0) * power
		parts.append({"p": origin, "v": Vector2(cos(a), sin(a)) * sp, "c": colors[randi() % colors.size()], "s": 2 + randi() % 2})


func _process(d: float) -> void:
	age += d
	for q in parts:
		q.v.y += 430.0 * d
		q.p += q.v * d
	queue_redraw()
	if age > life:
		queue_free()


func _draw() -> void:
	var a := clampf(1.6 - age / life * 1.6, 0.0, 1.0)
	for q in parts:
		draw_rect(Rect2(q.p.round(), Vector2(q.s, q.s)), Color(q.c, a))
