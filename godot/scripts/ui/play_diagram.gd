class_name PlayDiagram
extends Control
## A little play-call sketch: the offense lined up in its formation with each route or run path drawn on top.
## Pure data in, pixels out: it reads the card's `info` (formation key and routes) from plays.json via Deck52.
## Coordinates are in yards: `lat` is sideways (positive = right) and `fwd` is toward the defense (up the screen).

const K := 3.0                         # pixels per yard
const OL_LAT := [-8.0, -4.0, 0.0, 4.0, 8.0]
const POS_COLORS := {"QB": Color("f4f6ff"), "RB": Color("ff9a1f"), "FB": Color("ff9a1f"), "WR": Color("8fb0ff"), "TE": Color("5fe0c0")}

var card: Dictionary = {}


func _init() -> void:
	size = Vector2(170, 135)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_card(c: Dictionary) -> void:
	card = c
	queue_redraw()


func _to_px(lat: float, fwd: float) -> Vector2:
	return Vector2(size.x / 2.0 + lat * K, size.y - 28.0 - fwd * K)


## Route/run path as a list of Vector2(lat, fwd) in yards, from the player's own start spot.
static func path_for(start: Vector2, spec: String) -> Array:
	var parts := spec.split(":")
	var kind := parts[0]
	var d := float(parts[1]) if parts.size() > 1 else 8.0
	d = minf(d, 34.0)
	var lat := start.x
	var out := signf(lat) if lat != 0.0 else 1.0
	var inn := -out
	var s := start
	match kind:
		"GO", "SEAM": return [s, s + Vector2(0, d)]
		"POST": return [s, s + Vector2(0, 0.65 * d), s + Vector2(inn * 0.35 * d, d)]
		"CORNER": return [s, s + Vector2(0, 0.65 * d), s + Vector2(out * 0.35 * d, d)]
		"SLANT": return [s, s + Vector2(0, 2), s + Vector2(inn * 0.6 * d, d)]
		"OUT": return [s, s + Vector2(0, d), s + Vector2(out * 8, d)]
		"IN": return [s, s + Vector2(0, d), s + Vector2(inn * 14, d)]
		"CROSS": return [s, s + Vector2(0, 3), s + Vector2(inn * 28, d)]
		"HITCH": return [s, s + Vector2(0, d), s + Vector2(0, d - 2)]
		"CURL": return [s, s + Vector2(0, d), s + Vector2(inn * 3, d - 3)]
		"FLAT": return [s, s + Vector2(out * 12, d)]
		"SWING": return [s, s + Vector2(out * 4, -2), s + Vector2(out * 12, 3)]
		"WHEEL": return [s, s + Vector2(out * 6, 2), s + Vector2(out * 8, d)]
		"SCREEN": return [s, s + Vector2(0, -1.5), s + Vector2(out * 5, -1)]
		"DOUBLE": return [s, s + Vector2(0, 6), s + Vector2(out * 3, 9), s + Vector2(out * 3, d)]
		"BLOCK": return [s, s + Vector2(0, 2)]
		"DIVE", "DRAW": return [s, Vector2(lat, 1), Vector2(lat, 8)]
		"DIVE_R": return [s, Vector2(lat + 1, 0), Vector2(lat + 3, 8)]
		"SNEAK": return [s, Vector2(lat, 3)]
		"SWEEP_R": return [s, Vector2(lat + 10, s.y - 1), Vector2(lat + 16, 4), Vector2(lat + 17, 12)]
		"SWEEP_L": return [s, Vector2(lat - 10, s.y - 1), Vector2(lat - 16, 4), Vector2(lat - 17, 12)]
		"TACKLE_R": return [s, Vector2(lat + 4, 0), Vector2(lat + 8, 10)]
		"COUNTER_R": return [s, Vector2(lat - 3, s.y - 1), Vector2(lat + 2, s.y - 1), Vector2(lat + 6, 4), Vector2(lat + 8, 12)]
		"COUNTER_L": return [s, Vector2(lat + 3, s.y - 1), Vector2(lat - 2, s.y - 1), Vector2(lat - 6, 4), Vector2(lat - 8, 12)]
		"READ_R": return [s, Vector2(lat + 4, s.y - 1), Vector2(lat + 9, 3), Vector2(lat + 11, 10)]
		"READ_L": return [s, Vector2(lat - 4, s.y - 1), Vector2(lat - 9, 3), Vector2(lat - 11, 10)]
		"OPTION_R": return [s, Vector2(lat + 8, s.y - 1), Vector2(lat + 14, 2), Vector2(lat + 16, 8)]
		"BOOT_R": return [s, Vector2(lat + 4, s.y - 3), Vector2(lat + 10, s.y - 3), Vector2(lat + 13, 2)]
	return [s, s + Vector2(0, d)]


static func is_block(spec: String) -> bool:
	return spec.begins_with("BLOCK")


## Human-readable route list for the card's text column: one line per player with a route.
static func route_lines(info: Dictionary) -> Array:
	var f: Dictionary = Deck52.data().formations.get(info.formation, {})
	var by_id := {}
	for p in f.get("players", []):
		by_id[p.id] = p
	var out: Array = []
	for id in info.routes:
		var spec: String = info.routes[id]
		var parts := spec.split(":")
		var pos: String = by_id[id].pos if by_id.has(id) else "?"
		var kind: String = String(parts[0]).replace("_R", " R").replace("_L", " L").replace("_", " ")
		out.append("%s %s%s" % [pos, kind, " %sy" % parts[1] if parts.size() > 1 else ""])
	return out


## "QB, RB, 3 WR, TE" for a formation.
static func personnel(formation: String) -> String:
	var f: Dictionary = Deck52.data().formations.get(formation, {})
	var counts := {}
	var order: Array = []
	for p in f.get("players", []):
		if not counts.has(p.pos):
			order.append(p.pos)
		counts[p.pos] = int(counts.get(p.pos, 0)) + 1
	var bits: Array = []
	for pos in order:
		bits.append(pos if counts[pos] == 1 else "%d %s" % [counts[pos], pos])
	return ", ".join(bits)


func _dashed(pts: Array, col: Color, arrow: bool) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = _to_px(pts[i].x, pts[i].y)
		var b: Vector2 = _to_px(pts[i + 1].x, pts[i + 1].y)
		var n := int(maxf(1.0, a.distance_to(b) / 3.0))
		for t in n:
			if t % 3 == 2:
				continue
			var p := a.lerp(b, float(t) / n)
			draw_rect(Rect2(roundf(p.x), roundf(p.y), 2, 2), col)
	if arrow and pts.size() >= 2:
		var e: Vector2 = _to_px(pts[pts.size() - 1].x, pts[pts.size() - 1].y)
		var pv: Vector2 = _to_px(pts[pts.size() - 2].x, pts[pts.size() - 2].y)
		var ang := (e - pv).angle()
		for off in [2.6, -2.6]:
			for t in range(1, 5):
				var q := e - Vector2.from_angle(ang + off * 0.33) * float(t) * 1.4
				draw_rect(Rect2(roundf(q.x), roundf(q.y), 2, 2), col)


func _dot(lat: float, fwd: float, col: Color) -> void:
	var p := _to_px(lat, fwd)
	draw_rect(Rect2(roundf(p.x) - 4, roundf(p.y) - 4, 8, 8), Color("060b22"))
	draw_rect(Rect2(roundf(p.x) - 3, roundf(p.y) - 3, 6, 6), col)


func _draw() -> void:
	Px.box(self, Rect2(0, 0, size.x, size.y), Color("0d2a1c"), Px.LINE)
	for y in range(10, 40, 10):                                         # yard lines every ten yards
		var p := _to_px(0, y)
		draw_rect(Rect2(2, p.y, size.x - 4, 1), Color("1d5a38"))
	var los := _to_px(0, 0)
	draw_rect(Rect2(2, los.y, size.x - 4, 1), Px.ROYAL)
	if card.is_empty() or not card.has("info"):
		return
	var info: Dictionary = card.info
	var form: Dictionary = Deck52.data().formations.get(info.formation, {})
	for l in OL_LAT:
		_dot(l, 0.0, Color("8c97c8"))
	for p in form.get("players", []):
		if info.routes.has(p.id):
			var spec: String = info.routes[p.id]
			_dashed(path_for(Vector2(p.y, p.x), spec), Px.GOLD, not is_block(spec))
	for p in form.get("players", []):
		_dot(p.y, p.x, POS_COLORS.get(p.pos, Px.FG))
