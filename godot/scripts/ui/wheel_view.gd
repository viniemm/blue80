class_name WheelView
extends Control
## Outcome gauge. Slice widths are Monte Carlo odds; the real result decides where the spin lands.

const SIZE := 132
const RING_IN := 0.25
const RING_OUT := 0.40
const BULBS := 24
const COLORS := {
	"INTERCEPTION": Color("d62828"), "FUMBLE": Color("ff6a1a"), "LOSS": Color("ffb020"),
	"FIELD_GOAL_MISSED": Color("d62828"), "NO_GAIN": Color("8c97c8"), "PUNT": Color("8c97c8"),
	"GAIN": Color("2fd160"), "BIG_GAIN": Color("33c8ff"), "FIELD_GOAL_GOOD": Color("3cff7a"),
	"TOUCHDOWN": Color("ffe680"),
}
const LABELS := {
	"INTERCEPTION": "INTERCEPTION", "FUMBLE": "FUMBLE", "LOSS": "LOSS OF YARDS", "NO_GAIN": "NO GAIN",
	"GAIN": "GAIN", "BIG_GAIN": "BIG GAIN", "TOUCHDOWN": "TOUCHDOWN", "FIELD_GOAL_GOOD": "FIELD GOAL GOOD",
	"FIELD_GOAL_MISSED": "KICK MISSED", "PUNT": "PUNT",
}
const SHORT := {
	"INTERCEPTION": "INT", "FUMBLE": "FUM", "LOSS": "LOSS", "NO_GAIN": "NO", "GAIN": "GAIN", "BIG_GAIN": "BIG",
	"TOUCHDOWN": "TD", "FIELD_GOAL_GOOD": "FG", "FIELD_GOAL_MISSED": "MISS", "PUNT": "PUNT",
}

var slices: Array = []
var angle := 0.0:
	set(v):
		angle = v
		if _mat:
			_mat.set_shader_parameter("angle", v)
var spinning := false
var focus := -1
var _landed_at := -10.0
var _t := 0.0
var _mat: ShaderMaterial
var _rect: ColorRect
var _overlay: Control
var _last_angle := 0.0
var _vel := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	_rect = ColorRect.new()
	_rect.size = Vector2(SIZE, SIZE)
	_rect.color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/wheel.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_overlay = Control.new()
	_overlay.size = Vector2(SIZE, SIZE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)
	_mat.set_shader_parameter("ring_in", RING_IN)
	_mat.set_shader_parameter("ring_out", RING_OUT)
	set_slices([])


func set_slices(raw: Array) -> void:
	slices = []
	var total := 0.0
	for s in raw:
		total += float(s.pct)
	var acc := 0.0
	for s in raw:
		var start := acc / maxf(total, 0.001)
		acc += float(s.pct)
		var end := acc / maxf(total, 0.001)
		slices.append({"category": s.category, "pct": s.pct, "start": start, "end": end, "mid": (start + end) / 2.0})
	focus = -1
	var cols := PackedColorArray()
	var st := PackedFloat32Array()
	var en := PackedFloat32Array()
	var mi := PackedFloat32Array()
	for i in 10:
		if i < slices.size():
			cols.append(COLORS.get(slices[i].category, Color("7788aa")))
			st.append(slices[i].start)
			en.append(slices[i].end)
			mi.append(slices[i].mid)
		else:
			cols.append(Color.BLACK)
			st.append(2.0)
			en.append(2.0)
			mi.append(2.0)
	_mat.set_shader_parameter("count", slices.size())
	_mat.set_shader_parameter("colors", cols)
	_mat.set_shader_parameter("starts", st)
	_mat.set_shader_parameter("ends", en)
	_mat.set_shader_parameter("mids", mi)
	_mat.set_shader_parameter("focus", -1)
	_mat.set_shader_parameter("pulse", 0.0)
	_overlay.queue_redraw()


## Spin several turns and stop with `landed` under the pointer.
func spin_to(raw: Array, landed: String, dur: float = 3.4) -> void:
	set_slices(raw)
	var idx := 0
	for i in slices.size():
		if slices[i].category == landed:
			idx = i
	var s: Dictionary = slices[idx]
	var target: float = (float(s.start) + (float(s.end) - float(s.start)) * randf_range(0.2, 0.8)) * TAU
	var delta := fposmod(-target - angle, TAU)
	var to := angle + TAU * 6.0 + delta
	spinning = true
	var tw := create_tween()
	tw.tween_property(self, "angle", to, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished
	spinning = false
	focus = idx
	_landed_at = _t
	_mat.set_shader_parameter("focus", idx)


func _process(delta: float) -> void:
	_t += delta
	_vel = (angle - _last_angle) / maxf(delta, 0.001)
	_last_angle = angle
	var since := _t - _landed_at
	_mat.set_shader_parameter("pulse", 0.22 * sin(since * 14.0) * clampf(1.0 - since / 1.6, 0.0, 1.0) if since < 1.6 else 0.0)
	_overlay.queue_redraw()


func _on_overlay_draw() -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	var rmid := (RING_IN + RING_OUT) / 2.0 * SIZE
	# arc labels
	for i in slices.size():
		var s: Dictionary = slices[i]
		var label: String = SHORT.get(s.category, "")
		var arc := (float(s.end) - float(s.start)) * TAU * rmid
		if label == "" or arc < Px.text_width(label, 0) + 4:
			continue
		var phi: float = float(s.mid) * TAU + angle
		var p := c + Vector2(sin(phi), -cos(phi)) * rmid
		var dim := focus >= 0 and focus != i
		var col := Color(1, 1, 1, 0.45) if dim else Color.WHITE
		Px.text_center(_overlay, p.x + 1, p.y - 5, label, 0, Color("060b22"))
		Px.text_center(_overlay, p.x, p.y - 6, label, 0, col)
	# rim lights
	var speed := clampf(absf(_vel) * 3.0 + 6.0, 5.0, 30.0) if spinning else 5.0
	var step := int(_t * speed)
	var flashing := focus >= 0 and _t - _landed_at < 1.6
	var rb := (RING_OUT + 0.075) * SIZE
	for i in BULBS:
		var ph := float(i) / BULBS * TAU
		var p := c + Vector2(sin(ph), -cos(ph)) * rb
		var col := Color("5c4814")
		if flashing:
			col = Color.WHITE if int((_t - _landed_at) / 0.12) % 2 == 0 else Px.GOLD
		elif (i + step) % 3 == 0:
			col = Px.GOLD
		_overlay.draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y) - 1, 3, 3), col)
	# pointer, flicking as ticks pass
	var tick_pos := angle / TAU * 40.0
	var flick := (tick_pos - floorf(tick_pos) - 0.5) * 5.0 if spinning else 0.0
	var top := 1.0
	var tip := Vector2(c.x + flick, (0.5 - RING_OUT) * SIZE + 4)
	var poly := PackedVector2Array([Vector2(c.x - 7, top), Vector2(c.x + 7, top), tip])
	_overlay.draw_colored_polygon(poly, Color("060b22"))
	var inner := PackedVector2Array([Vector2(c.x - 5, top + 1), Vector2(c.x + 5, top + 1), tip - Vector2(0, 3)])
	_overlay.draw_colored_polygon(inner, Px.GOLD)
