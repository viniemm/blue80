class_name CardDetail
extends Control
## Full-screen popup with everything about one play card: formation sketch, personnel, routes, a one-line summary,
## which defense styles it likes and fears, and its expected yards against each. Tap anywhere to close.

const TIER_COLORS := {"BRONZE": Color("cd7f32"), "SILVER": Color("c8d0de"), "GOLD": Color("ffcc33"), "PLATINUM": Color("e8f0ff"),
		"JOKER": Color("d46bff")}

signal closed

var card: Dictionary = {}
var diagram: PlayDiagram


func _init() -> void:
	size = Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	diagram = PlayDiagram.new()
	diagram.position = Vector2(36, 150)
	add_child(diagram)


func show_card(c: Dictionary) -> void:
	card = c
	diagram.set_card(c)
	visible = true
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		visible = false
		closed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed:
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()


func _chip(x: float, y: float, w: float, text: String, fill: Color) -> void:
	draw_rect(Rect2(x, y, w, 15), Color("0a0a1a"))
	draw_rect(Rect2(x + 1, y + 1, w - 2, 13), fill)
	Px.text_center(self, x + w / 2.0, y + 1, text, 0, Color("0a0a1a"))


func _draw() -> void:
	if card.is_empty():
		return
	var info: Dictionary = card.info
	var tier: String = card.tier
	var tcol: Color = TIER_COLORS.get(tier, Px.FG)
	draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.84))
	Px.box(self, Rect2(24, 88, 312, 470), Px.PANEL, tcol)
	var form: Dictionary = Deck52.data().formations.get(info.formation, {})
	Px.text(self, 36, 100, "%s  %s" % [card.label, card.name], 3, tcol)
	var fam: String = card.suit_name if not card.get("joker", false) else "WILD CARD"
	Px.text(self, 36, 124, "%s  %s  -  %s" % [tier, fam, form.get("label", "")], 1, Px.DIM)
	# right column: personnel and routes
	var x := 214.0
	var y := 150.0
	Px.text(self, x, y, "PERSONNEL", 0, Px.GOLD)
	y += 13
	for line in Px.wrap(PlayDiagram.personnel(info.formation), 112, 0):
		Px.text(self, x, y, line, 0, Px.FG)
		y += 12
	y += 6
	Px.text(self, x, y, "ROUTES", 0, Px.GOLD)
	y += 13
	for line in PlayDiagram.route_lines(info):
		Px.text(self, x, y, line, 0, Px.FG)
		y += 12
	y = 292.0
	var lx := 36.0
	for item in [["QB", "QB"], ["RB", "RB"], ["WR", "WR"], ["TE", "TE"], ["OL", ""]]:
		var lc: Color = PlayDiagram.POS_COLORS.get(item[1], Color("8c97c8"))
		draw_rect(Rect2(lx, y + 3, 6, 6), lc)
		Px.text(self, lx + 9, y, item[0], 0, Px.DIM)
		lx += 36.0
	# summary
	y = 314.0
	for line in Px.wrap(info.summary, 288, 1):
		Px.text(self, 36, y, line, 1, Px.FG)
		y += 15
	# strength / weakness
	y = maxf(y + 6.0, 372.0)
	var sc: Color = QCardView.STYLE_COLORS[info.strong]
	var wc: Color = QCardView.STYLE_COLORS[info.weak]
	Px.text(self, 36, y + 2, "STRONG vs", 0, Px.GREEN)
	_chip(100, y, 62, info.strong, sc)
	Px.text(self, 176, y + 2, "WEAK vs", 0, Px.RED)
	_chip(228, y, 62, info.weak, wc)
	# expected yards against each style
	y += 26
	Px.text(self, 36, y, "EXPECTED YARDS BY DEFENSE", 0, Px.GOLD)
	y += 14
	var means := {}
	var best := -999.0
	var worst := 999.0
	for st in DefContext.STYLES:
		var m := YardCurve.mean(DefContext.apply(card.theta, st))
		means[st] = m
		best = maxf(best, m)
		worst = minf(worst, m)
	var i := 0
	for st in DefContext.STYLES:
		var cx := 36.0 + i * 72.0
		Px.text(self, cx, y, st, 0, QCardView.STYLE_COLORS[st])
		var col := Px.GREEN if means[st] == best else (Px.RED if means[st] == worst else Px.FG)
		Px.text(self, cx, y + 13, "%.1f" % means[st], 1, col)
		i += 1
	y += 38
	var th := DefContext.apply(card.theta, "BALANCED")
	Px.text(self, 36, y, "turnover %.1f%%   sack or loss %.1f%%   15+ yd play %.1f%%" % [
			100.0 * float(th.p_to), 100.0 * float(th.p_neg), 100.0 * YardCurve.survival(th, 15)], 0, Px.DIM)
	y += 14
	Px.text(self, 36, y, "spread (std dev) %.1f yards" % YardCurve.stdev(th), 0, Px.DIM)
	Px.text_center(self, 180, 540, "tap to close", 0, Px.LINE)
