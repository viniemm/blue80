extends Control
## Card-betting game screen. Flow per down: DRAW (tap up to 3 cards to swap) -> BET (read the 2 face-up defense
## cards, pick a yardage line and a stake) -> SHOWDOWN -> RESULT.

class DrawPanel extends Control:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


const STYLE_NOTES := {
	"BLITZ": "sacks, turnovers, big plays up; normal gains down",
	"ZONE": "fewer sacks, far fewer big plays",
	"MAN": "a few more big plays, a few more sacks",
	"BALANCED": "no change",
}
const ROW_H := 21

var g: QGame
var field: FieldView
var hud: DrawPanel
var tells_panel: DrawPanel
var hand_info: DrawPanel
var bet_panel: DrawPanel
var stake_panel: DrawPanel
var preview_panel: DrawPanel
var result_panel: DrawPanel
var overlay: DrawPanel
var hand_layer: Control
var btn_draw: PxButton
var btn_stand: PxButton
var btn_show: PxButton
var btn_next: PxButton
var btn_minus: PxButton
var btn_plus: PxButton
var btn_max: PxButton
var btn_nobet: PxButton
var btn_new: PxButton
var my_views: Array = []
var def_views: Array = []
var marked: Array = []
var stake := 2.0
var last_res: Dictionary = {}


func _ready() -> void:
	g = QGame.new()
	_build_ui()
	_rebuild_cards()
	_refresh()


func _panel(rect: Rect2, fn: Callable) -> DrawPanel:
	var p := DrawPanel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.fn = fn
	add_child(p)
	return p


func _button(text: String, color: Color, rect: Rect2, cb: Callable, parent: Control = null) -> PxButton:
	var b := PxButton.new(text, color, rect.size)
	b.position = rect.position
	b.pressed.connect(cb)
	(parent if parent else self).add_child(b)
	return b


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Px.BG
	bg.size = Vector2(360, 640)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	hud = _panel(Rect2(0, 0, 360, 30), _draw_hud)
	field = FieldView.new()
	field.position = Vector2(0, 32)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	field.set_state(g.st)
	tells_panel = _panel(Rect2(4, 226, 352, 38), _draw_tells)
	hand_layer = Control.new()
	hand_layer.size = Vector2(360, 640)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)
	hand_info = _panel(Rect2(4, 360, 352, 16), _draw_hand_info)
	bet_panel = _panel(Rect2(8, 378, 344, 5 * ROW_H + 4), _draw_bets)
	bet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bet_panel.gui_input.connect(_on_bet_input)
	stake_panel = _panel(Rect2(8, 490, 344, 22), _draw_stake)
	preview_panel = _panel(Rect2(8, 514, 344, 14), _draw_preview)
	btn_minus = _button("-", Px.ROYAL, Rect2(120, 490, 26, 22), _on_stake.bind(-0.5))
	btn_plus = _button("+", Px.ROYAL, Rect2(150, 490, 26, 22), _on_stake.bind(0.5))
	btn_max = _button("MAX", Px.ROYAL, Rect2(180, 490, 44, 22), _on_max)
	btn_nobet = _button("NO BET", Px.DIM, Rect2(284, 490, 68, 22), _on_nobet)
	btn_draw = _button("DRAW", Px.GOLD, Rect2(8, 532, 166, 28), _on_draw)
	btn_stand = _button("STAND PAT", Px.ROYAL, Rect2(180, 532, 172, 28), _on_stand)
	btn_show = _button("SHOWDOWN", Px.GOLD, Rect2(8, 532, 344, 28), _on_show)
	btn_next = _button("NEXT", Px.GOLD, Rect2(8, 532, 344, 28), _on_next)
	result_panel = _panel(Rect2(4, 564, 352, 74), _draw_result)
	overlay = _panel(Rect2(0, 0, 360, 640), _draw_overlay)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_new = _button("NEW RUN", Px.GOLD, Rect2(100, 380, 160, 34), _on_new_run)
	btn_new.visible = false


# ------------------------------------------------------------------ cards
func _rebuild_cards() -> void:
	for v in my_views + def_views:
		v.queue_free()
	my_views = []
	def_views = []
	for i in 5:
		var v := QCardView.new(g.mine[i], "mine", i)
		v.position = Vector2(8 + i * 70, 268)
		v.tapped.connect(_on_hand_tapped)
		hand_layer.add_child(v)
		my_views.append(v)
		var d := QCardView.new(g.theirs[i], "theirs", i)
		d.position = Vector2(7 + i * 69, 168)
		hand_layer.add_child(d)
		def_views.append(d)
	_sync_cards()


func _sync_cards() -> void:
	for i in 5:
		my_views[i].marked = marked.has(i)
		var show_all: bool = g.phase == "RESULT" or g.phase == "OVER"
		def_views[i].face_up = show_all or (g.phase == "BET" and g.face_up.has(i))


# ------------------------------------------------------------------ drawing
func _spot(yl: float) -> String:
	var n := int(round(yl))
	if n > 50:
		return "OWN %d" % (100 - n)
	if n == 50:
		return "MIDFIELD"
	return "OPP %d" % n


func _draw_hud(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 30), Color("14247a"))
	c.draw_rect(Rect2(0, 29, 360, 1), Px.ROYAL)
	Px.text(c, 6, 0, "CHIPS", 0, Px.DIM)
	Px.text(c, 6, 12, "%.1f" % g.bankroll, 3, Px.GOLD if g.bankroll >= QGame.START_BANKROLL else Px.RED)
	var dn: String = ["", "1ST", "2ND", "3RD", "4TH"][int(g.st.down)]
	Px.text_center(c, 190, 4, "%s & %d" % [dn, int(round(g.st.distance))], 2, Px.FG)
	Px.text_center(c, 190, 14, _spot(g.st.yardline_to_opponent_goal), 1, Px.DIM)
	Px.text_right(c, 354, 1, "DRIVE %d" % g.drive_no, 0, Px.DIM)
	Px.text_right(c, 354, 14, "TD %d" % g.tds, 0, Px.GOLD)


## Cards left by rank, from what the player has seen since the last shuffle (green = richer than average, red = thinner).
func _draw_tracker(c: Control) -> void:
	var labels := ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
	var expected := float(QGame.DECKS * 4) * float(g.shoe_left()) / float(QGame.DECKS * 52)
	for i in 13:
		var left := g.rank_left(i + 2)
		var ratio := float(left) / maxf(1.0, expected)
		var col := Px.GREEN if ratio > 1.2 else (Px.RED if ratio < 0.8 else Px.FG)
		var x := 6.0 + i * 26.0
		Px.text(c, x, 19, labels[i] + ":", 0, Px.DIM)
		Px.text(c, x + Px.text_width(labels[i] + ":", 0) + 1, 19, str(left), 0, col)


func _draw_tells(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 352, 38), Px.PANEL, Px.LINE)
	Px.text_right(c, 346, 3, "SHOE %d" % g.shoe_left(), 0, Px.DIM)
	match g.phase:
		"DRAW":
			Px.text(c, 6, 2, "DEFENSE HOLDS 5 CARDS", 1, Px.GOLD)
			_draw_tracker(c)
		"BET":
			var x := 6.0
			Px.text(c, x, 2, "TELLS:", 1, Px.GOLD)
			x += 44
			for i in g.face_up:
				var cd: Dictionary = g.theirs[i]
				var style: String = QGame.STYLE_OF_SUIT[cd.suit]
				var t := "%s %s" % [cd.label, style]
				Px.text(c, x, 2, t, 1, QCardView.STYLE_COLORS[style])
				x += Px.text_width(t, 1) + 12
			_draw_tracker(c)
		_:
			if last_res.is_empty():
				return
			var style: String = last_res.style
			Px.text(c, 6, 2, "DEFENSE LEAD: %s %s" % [last_res.their_lead.label, style], 1, QCardView.STYLE_COLORS[style])
			Px.text(c, 6, 19, "%s: %s" % [style, STYLE_NOTES[style]], 0, Px.DIM)


func _draw_hand_info(c: Control) -> void:
	var e: Dictionary = g.my_eval
	var lead: Dictionary = g.my_lead()
	var line := "%s x%.1f   LEAD %s %s" % [Poker.CAT_NAMES[int(e.cat)], g.my_mult(), lead.label, lead.name]
	Px.text(c, 2, 0, line, 1, Px.GREEN)


func _draw_bets(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 344, 5 * ROW_H + 4), Px.PANEL, Px.LINE)
	if g.phase == "DRAW":
		Px.text_center(c, 172, 44, "BETS OPEN AFTER THE DRAW", 1, Px.DIM)
		Px.text_center(c, 172, 62, "tap up to 3 cards to swap, then DRAW", 0, Px.DIM)
		return
	for k in 5:
		var y := 2 + k * ROW_H
		var sel: bool = g.bet.line == k
		if sel:
			c.draw_rect(Rect2(2, y, 340, ROW_H - 1), Color(Px.GOLD, 0.2))
			c.draw_rect(Rect2(2, y, 340, ROW_H - 1), Px.GOLD, false, 1.0)
		var col := Px.GOLD if sel else Px.FG
		Px.text(c, 8, y + 3, Lines.NAMES[k], 1, col)
		Px.text(c, 108, y + 3, ">= %d YDS" % g.line_threshold(k), 1, Px.ROYAL)
		Px.text(c, 180, y + 3, "HOUSE %2.0f%%" % (g.line_house_p(k) * 100.0), 1, Px.DIM)
		Px.text_right(c, 338, y + 3, "PAYS %.2f:1" % g.line_payout(k), 1, Px.GREEN)


func _draw_stake(c: Control) -> void:
	Px.text(c, 0, 4, "STAKE", 1, Px.DIM)
	var s := "%.1f" % stake
	Px.text(c, 52, 3, s, 2, Px.GOLD)
	Px.text(c, 230, 4, "MAX %.1f" % g.max_stake(), 0, Px.DIM)


func _draw_preview(c: Control) -> void:
	if g.phase != "BET":
		return
	if g.bet.line < 0 or g.bet.stake <= 0.0:
		Px.text(c, 0, 0, "NO BET: ANTE ONLY. Pick a line to see what the stake wins and loses.", 0, Px.DIM)
		return
	var s: float = g.bet.stake
	var win: float = s * g.line_payout(g.bet.line)
	var x := 0.0
	var parts := [["WIN HAND + CLEAR  %+.1f" % win, Px.GREEN], ["WIN HAND + MISS  %+.1f" % -s, Px.RED], ["LOSE HAND  REFUND", Px.DIM]]
	for i in parts.size():
		Px.text(c, x, 0, parts[i][0], 0, parts[i][1])
		x += Px.text_width(parts[i][0], 0) + (14 if i < parts.size() - 1 else 0)
		if i < parts.size() - 1:
			Px.text(c, x - 10, 0, "|", 0, Px.LINE)


func _draw_result(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 352, 74), Px.PANEL, Px.LINE)
	var y := 4
	if not last_res.is_empty() and g.phase in ["RESULT", "OVER"]:
		var r := last_res
		var head := ""
		var col := Px.GOLD
		if r.win == 1:
			head = "YOU WIN: %s beats %s" % [Poker.CAT_NAMES[int(r.my_cat)], Poker.CAT_NAMES[int(r.their_cat)]]
			col = Px.GREEN
		elif r.win == -1:
			head = "DEFENSE WINS: %s beats %s" % [Poker.CAT_NAMES[int(r.their_cat)], Poker.CAT_NAMES[int(r.my_cat)]]
			col = Px.RED
		else:
			head = "PUSH: identical hands"
		Px.text(c, 6, y, head, 1, col)
		var bet_txt := ""
		if r.win == 1 and r.bet.line >= 0 and r.bet.stake > 0.0:
			bet_txt = "  BET %s %+.1f" % ["CLEARED" if r.cleared else "MISSED", r.bet_delta]
		elif r.voided and r.bet.line >= 0:
			bet_txt = "  BET REFUNDED"
		Px.text(c, 6, y + 16, "%s %+d YDS  ANTE %+.1f%s" % [r.event, r.yards, r.ante_delta, bet_txt], 1, Px.FG)
		var tot_col := Px.GREEN if r.delta >= 0 else Px.RED
		Px.text_right(c, 346, y + 16, "%+.1f" % r.delta, 1, tot_col)
		y += 34
	else:
		Px.text(c, 6, y, "RECENT", 1, Px.GOLD)
		y += 18
	for line in g.log.slice(0, 4) if g.phase == "BET" or g.phase == "DRAW" else g.log.slice(1, 3):
		Px.text(c, 6, y, String(line).to_upper(), 0, Px.DIM)
		y += 13


func _draw_overlay(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(30, 200, 300, 250), Px.PANEL, Px.RED)
	Px.text_center(c, 180, 222, "BUSTED", 3, Px.RED)
	Px.text_center(c, 180, 262, "%d TOUCHDOWNS  %d SNAPS" % [g.tds, g.history.size()], 1, Px.FG)
	Px.text_center(c, 180, 286, "Your chips ran out.", 1, Px.DIM)


# ------------------------------------------------------------------ state refresh
func _refresh() -> void:
	var phase := g.phase
	stake = clampf(stake, 0.5, maxf(0.5, g.max_stake()))
	btn_draw.visible = phase == "DRAW"
	btn_stand.visible = phase == "DRAW"
	btn_draw.set_label("DRAW %d" % marked.size() if marked.size() > 0 else "DRAW 0")
	btn_draw.disabled = marked.is_empty()
	btn_show.visible = phase == "BET"
	for b in [btn_minus, btn_plus, btn_max, btn_nobet]:
		b.visible = phase == "BET"
	btn_next.visible = phase == "RESULT"
	if phase == "RESULT":
		btn_next.set_label("NEXT DRIVE" if last_res.get("drive_over", false) else "NEXT DOWN")
	overlay.visible = phase == "OVER"
	btn_new.visible = phase == "OVER"
	for p in [hud, tells_panel, hand_info, bet_panel, stake_panel, preview_panel, result_panel, overlay]:
		p.queue_redraw()
	_sync_cards()


# ------------------------------------------------------------------ input
func _on_hand_tapped(i: int) -> void:
	if g.phase != "DRAW":
		return
	if marked.has(i):
		marked.erase(i)
	elif marked.size() < 3:
		marked.append(i)
	_refresh()


func _on_draw() -> void:
	if g.phase != "DRAW":
		return
	g.draw(marked)
	marked = []
	_rebuild_cards()
	_refresh()


func _on_stand() -> void:
	marked = []
	_on_draw_with([])


func _on_draw_with(idx: Array) -> void:
	g.draw(idx)
	_rebuild_cards()
	_refresh()


func _on_bet_row(k: int) -> void:
	if g.phase != "BET" or k < 0 or k > 4:
		return
	if g.bet.line == k:
		g.set_bet(-1, 0.0)
	else:
		g.set_bet(k, stake)
	_refresh()


func _on_bet_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_on_bet_row(int((e.position.y - 2) / ROW_H))


func _on_stake(delta: float) -> void:
	stake = clampf(stake + delta, 0.5, maxf(0.5, g.max_stake()))
	if g.bet.line >= 0:
		g.set_bet(g.bet.line, stake)
	_refresh()


func _on_max() -> void:
	stake = maxf(0.5, g.max_stake())
	if g.bet.line >= 0:
		g.set_bet(g.bet.line, stake)
	_refresh()


func _on_nobet() -> void:
	g.set_bet(-1, 0.0)
	_refresh()


func _on_show() -> void:
	if g.phase != "BET":
		return
	last_res = g.showdown()
	field.set_state(g.st)
	_refresh()


func _on_next() -> void:
	if g.phase != "RESULT":
		return
	g.next()
	marked = []
	field.set_state(g.st)
	_rebuild_cards()
	_refresh()


func _on_new_run() -> void:
	g = QGame.new()
	marked = []
	last_res = {}
	stake = 2.0
	field.set_state(g.st)
	_rebuild_cards()
	_refresh()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	if e.keycode == KEY_ENTER or e.keycode == KEY_SPACE:
		match g.phase:
			"DRAW":
				_on_stand() if marked.is_empty() else _on_draw()
			"BET":
				_on_show()
			"RESULT":
				_on_next()
	elif e.keycode >= KEY_1 and e.keycode <= KEY_5:
		var i: int = e.keycode - KEY_1
		if g.phase == "DRAW":
			_on_hand_tapped(i)
		elif g.phase == "BET":
			_on_bet_row(i)
