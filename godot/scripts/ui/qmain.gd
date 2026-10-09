class_name QMain
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

signal exit_requested

var g: QGame
const SHOE_POS := Vector2(330, 36)         # where dealt cards fly in from

var paused := false
var committed := false
var fx_layer: Control
var shown_bank := QGame.START_BANKROLL      # the chip counter ticks toward the real bankroll
var bank_hold := 0.0
var suspense := false                       # the beat between the flip and the verdict
var suspense_t := 0.0
var focus_idx := -1                          # the card whose info shows in the bet panel while drawing
var detail: CardDetail
var btn_info: PxButton
var stage := ""                             # showdown beats: flip -> spin -> hold
var pre_st: Dictionary = {}
var wheel_layer: Control
var wheel_panel: DrawPanel
var wheel: WheelView
var wheel_slices: Array = []
var wheel_done := false
var flip_base := 0.9                         # delay before the face-up defense cards turn over
var pause_panel: DrawPanel
var btn_menu: PxButton
var btn_resume: PxButton
var btn_restart: PxButton
var btn_quit: PxButton
var btn_new_menu: PxButton
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


func _init() -> void:
	size = Vector2(360, 640)


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
	field.show_plate = true
	field.goal_label = "+%d" % int(QGame.TD_BONUS)
	field.set_process(true)
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
	wheel_layer = Control.new()
	wheel_layer.size = Vector2(360, 640)
	wheel_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	wheel_layer.visible = false
	wheel_layer.gui_input.connect(_on_wheel_input)
	add_child(wheel_layer)
	wheel_panel = DrawPanel.new()
	wheel_panel.size = Vector2(360, 640)
	wheel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_panel.fn = _draw_wheel_panel
	wheel_layer.add_child(wheel_panel)
	wheel = WheelView.new(168)
	wheel.position = Vector2(96, 236)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_layer.add_child(wheel)
	fx_layer = Control.new()
	fx_layer.size = Vector2(360, 640)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	overlay = _panel(Rect2(0, 0, 360, 640), _draw_overlay)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_new = _button("NEW RUN", Px.GOLD, Rect2(100, 372, 160, 34), _on_new_run)
	btn_new.visible = false
	btn_new_menu = _button("MAIN MENU", Px.ROYAL, Rect2(100, 414, 160, 30), _on_exit)
	btn_new_menu.visible = false
	btn_menu = _button("MENU", Px.ROYAL, Rect2(252, 5, 50, 20), _on_pause)
	btn_info = _button("INFO", Px.ROYAL, Rect2(302, 357, 50, 18), _on_info)
	detail = CardDetail.new()
	add_child(detail)
	pause_panel = _panel(Rect2(0, 0, 360, 640), _draw_pause)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	btn_resume = _button("RESUME", Px.GOLD, Rect2(90, 262, 180, 32), _on_pause)
	btn_restart = _button("RESTART RUN", Px.ROYAL, Rect2(90, 304, 180, 32), _on_new_run)
	btn_quit = _button("MAIN MENU", Px.ROYAL, Rect2(90, 346, 180, 32), _on_exit)
	for b in [btn_resume, btn_restart, btn_quit]:
		b.visible = false


# ------------------------------------------------------------------ cards
func _slot_mine(i: int) -> Vector2:
	return Vector2(8 + i * 70, 268)


func _slot_def(i: int) -> Vector2:
	return Vector2(7 + i * 69, 168)


func _new_mine(i: int, delay: float) -> QCardView:
	var v := QCardView.new(g.mine[i], "mine", i)
	v.tapped.connect(_on_hand_tapped)
	v.inspected.connect(_on_inspect)
	v.hovered.connect(_on_hover)
	hand_layer.add_child(v)
	v.place(_slot_mine(i))
	v.deal_in(SHOE_POS, delay, true)
	return v


## A full new deal: the old cards fly off to the left, ten new ones fly in from the shoe.
func _rebuild_cards() -> void:
	var old: Array = my_views + def_views
	for k in old.size():
		old[k].fly_out(Vector2(-90, old[k].position.y), k * 0.02)
	my_views = []
	def_views = []
	var base := 0.25 if not old.is_empty() else 0.0
	for i in 5:
		var d := QCardView.new(g.theirs[i], "theirs", i)
		hand_layer.add_child(d)
		d.place(_slot_def(i))
		d.deal_in(SHOE_POS, base + i * 0.07, false)
		def_views.append(d)
	for i in 5:
		my_views.append(_new_mine(i, base + 0.35 + i * 0.07))
	_sync_cards()


func _lead_index() -> int:
	return g.play_idx


func _sync_cards() -> void:
	var lead := _lead_index() if g.phase != "DRAW" else -1
	for i in 5:
		my_views[i].marked = marked.has(i)
		my_views[i].highlight = i == lead
		var picking: bool = g.phase == "BET"
		my_views[i].eligible = picking and g.eligible().has(i) and g.eligible().size() > 1
		my_views[i].dimmed = picking and not g.eligible().has(i)
	var show_all: bool = g.phase == "RESULT" or g.phase == "OVER"
	var n := 0
	for i in 5:
		var up: bool = show_all or (g.phase == "BET" and g.face_up.has(i))
		if up != def_views[i]._flip_target:
			def_views[i].flip_to(up, (flip_base if g.phase == "BET" else 0.1) + n * 0.14)
			n += 1


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
	Px.text(c, 6, 12, "%.1f" % shown_bank, 3, Px.GOLD if shown_bank >= QGame.START_BANKROLL else Px.RED)
	Px.text_center(c, 190, 3, _spot(g.st.yardline_to_opponent_goal), 2, Px.FG)
	Px.text_center(c, 190, 15, "%d YDS TO GOAL" % int(round(g.st.yardline_to_opponent_goal)), 0, Px.DIM)
	Px.text_right(c, 354, 1, "DRIVE %d" % g.drive_no, 0, Px.DIM)
	Px.text_right(c, 354, 14, "TD %d" % g.tds, 0, Px.GOLD)


## Cards left by rank, from what the player has seen since the last shuffle (green = richer than average, red = thinner).
func _draw_tracker(c: Control) -> void:
	if not bool(Save.setting("counter", true)):
		return
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
	Px.text_right(c, 346, 3, "WILD %d   SHOE %d" % [g.wild_left(), g.shoe_left()], 0, Px.DIM)
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
				var style: String = g.style_of(cd)
				var t := "%s %s" % [cd.label, style]
				Px.text(c, x, 2, t, 1, QCardView.STYLE_COLORS[style])
				x += Px.text_width(t, 1) + 12
			_draw_tracker(c)
		_:
			if last_res.is_empty() or suspense:
				return
			var style: String = last_res.style
			Px.text(c, 6, 2, "DEFENSE LEAD: %s %s" % [last_res.their_lead.label, style], 1, QCardView.STYLE_COLORS[style])
			Px.text(c, 6, 19, "%s: %s" % [style, STYLE_NOTES[style]], 0, Px.DIM)


func _draw_hand_info(c: Control) -> void:
	var e: Dictionary = g.my_eval
	var lead: Dictionary = g.my_lead()
	var line := "%s x%.1f" % [Poker.CAT_NAMES[int(e.cat)], g.my_mult()]
	Px.text(c, 2, 0, line, 1, Px.GREEN)
	var x := 2.0 + Px.text_width(line, 1) + 12.0
	if g.phase == "DRAW":
		Px.text(c, x, 0, "tap (i) on a card for its play", 0, Px.DIM)
		return
	var tail := "PLAY %s %s" % [lead.label, lead.name]
	Px.text(c, x, 0, tail, 1, Px.GOLD)
	x += Px.text_width(tail, 1) + 10.0
	var info: Dictionary = lead.get("info", {})
	if not info.is_empty() and g.phase == "BET":
		Px.text(c, x, 2, "+" + info.strong, 0, Px.GREEN)
		Px.text(c, x + Px.text_width("+" + info.strong, 0) + 6, 2, "-" + info.weak, 0, Px.RED)


func _draw_bets(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 344, 5 * ROW_H + 4), Px.PANEL, Px.LINE)
	if g.phase == "DRAW":
		if focus_idx < 0 or focus_idx > 4:
			Px.text_center(c, 172, 30, "BETS OPEN AFTER THE DRAW", 1, Px.DIM)
			Px.text_center(c, 172, 50, "tap up to 3 cards to swap, then DRAW", 0, Px.DIM)
			Px.text_center(c, 172, 66, "tap a card to mark it and read its play. Tap (i) or hold for the full card.", 0, Px.DIM)
			return
		_draw_focus(c, g.mine[focus_idx])
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


## Compact play card for the focused hand card, shown where the bets will appear.
func _draw_focus(c: Control, card: Dictionary) -> void:
	var info: Dictionary = card.info
	var form: Dictionary = Deck52.data().formations.get(info.formation, {})
	var tcol: Color = CardDetail.TIER_COLORS.get(card.tier, Px.FG)
	Px.text(c, 8, 4, "%s %s" % [card.label, card.name], 2, tcol)
	Px.text_right(c, 336, 5, "%s  %s" % [form.get("label", ""), "" if card.get("joker", false) else card.suit_name], 0, Px.DIM)
	var y := 20
	for line in Px.wrap(info.summary, 326, 1).slice(0, 2):
		Px.text(c, 8, y, line, 1, Px.FG)
		y += 14
	Px.text(c, 8, 52, "STRONG vs", 0, Px.GREEN)
	Px.text(c, 62, 52, info.strong, 0, QCardView.STYLE_COLORS[info.strong])
	Px.text(c, 112, 52, "WEAK vs", 0, Px.RED)
	Px.text(c, 156, 52, info.weak, 0, QCardView.STYLE_COLORS[info.weak])
	var x := 8.0
	for st in DefContext.STYLES:
		var m := YardCurve.mean(DefContext.apply(card.theta, st))
		Px.text(c, x, 70, st.substr(0, 3), 0, QCardView.STYLE_COLORS[st])
		Px.text(c, x + 24, 70, "%.1f" % m, 0, Px.FG)
		x += 62.0
	Px.text_right(c, 336, 52, "avg yds by defense below", 0, Px.DIM)
	Px.text(c, 8, 88, "Tapping marks it for the swap. Tap (i) or hold for the full card.", 0, Px.DIM)


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


func _row(c: Control, y: float, label: String, text: String, col: Color) -> void:
	Px.text(c, 6, y + 1, label, 0, Px.DIM)
	Px.text(c, 38, y, text, 1, col)


func _draw_result(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 352, 74), Px.PANEL, Px.LINE)
	if not last_res.is_empty() and g.phase in ["RESULT", "OVER"] and not suspense:
		var r := last_res
		var mine: String = Poker.CAT_NAMES[int(r.my_cat)]
		var theirs: String = Poker.CAT_NAMES[int(r.their_cat)]
		var yards: int = r.yards
		var evt: String = r.event
		# row 1: who won the hand
		if r.win == 1:
			_row(c, 3, "HAND", "WON   %s beats %s" % [mine, theirs], Px.GREEN)
		elif r.win == -1:
			_row(c, 3, "HAND", "LOST  %s loses to %s" % [mine, theirs], Px.RED)
		else:
			_row(c, 3, "HAND", "TIED  identical hands", Px.DIM)
		Px.text_right(c, 346, 4, "ANTE %+.1f" % r.ante_delta, 1, Px.GREEN if r.ante_delta >= 0 else Px.RED)
		# row 2: what the play did, in plain words
		var play := ""
		var pcol := Px.FG
		if r.win == 0:
			play = "NO PLAY"
			pcol = Px.DIM
		elif r.win == 1:
			play = "GAINED %d YDS" % yards if yards > 0 else ("LOST %d YDS" % -yards if yards < 0 else "NO GAIN")
			pcol = Px.GREEN if yards > 0 else (Px.RED if yards < 0 else Px.DIM)
		else:
			play = "DEFENSE: %s  %d YDS" % [evt, yards]
			pcol = Px.RED
		var extra := ""
		if evt == "TOUCHDOWN":
			extra = "  TOUCHDOWN  +%d CHIPS" % int(QGame.TD_BONUS)
			pcol = Px.GOLD
		elif evt == "FIRST DOWN":
			extra = "  FIRST DOWN"
		elif evt in ["TURNOVER ON DOWNS", "SAFETY"] or r.turnover:
			extra = "  " + ("TURNOVER" if evt != "TURNOVER ON DOWNS" else "SHORT ON 4TH DOWN")
		_row(c, 19, "PLAY", play + extra, pcol)
		# row 3: the bet, with the line it needed
		var bet_txt := "NONE"
		var bcol := Px.DIM
		if r.bet.line >= 0 and r.bet.stake > 0.0:
			var need: int = g.lines.threshold(r.my_lead, r.bet.line)
			if r.win == 1:
				bet_txt = "%s %+.1f   needed %d+ YDS, got %d" % ["CLEARED" if r.cleared else "MISSED", r.bet_delta, need, yards]
				bcol = Px.GREEN if r.cleared else Px.RED
			else:
				bet_txt = "REFUNDED   (needs a won hand to play)"
		_row(c, 35, "BET", bet_txt, bcol)
		var tot_col := Px.GREEN if r.delta >= 0 else Px.RED
		_row(c, 51, "NET", "%+.1f CHIPS" % r.delta, tot_col)
	else:
		var y := 4
		var head := "SHOWDOWN..." if suspense else "RECENT"
		if g.phase == "BET" and g.eligible().size() > 1:
			head = "CHOOSE YOUR PLAY: tap a gold-edged card (or press P)"
		Px.text(c, 6, y, head, 1, Px.GOLD)
		y += 18
		for line in g.log.slice(0, 4) if g.phase == "BET" or g.phase == "DRAW" else g.log.slice(1, 3):
			Px.text(c, 6, y, String(line).to_upper(), 0, Px.DIM)
			y += 13


func _draw_overlay(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(30, 200, 300, 254), Px.PANEL, Px.RED)
	Px.text_center(c, 180, 222, "BUSTED", 3, Px.RED)
	Px.text_center(c, 180, 262, "%d TOUCHDOWNS  %d SNAPS" % [g.tds, g.history.size()], 1, Px.FG)
	Px.text_center(c, 180, 286, "PEAK %.1f CHIPS" % g.peak, 1, Px.GOLD)
	Px.text_center(c, 180, 310, "Your chips ran out.", 1, Px.DIM)
	if g.best_cat >= 0:
		Px.text_center(c, 180, 330, "BEST HAND WON: %s" % Poker.CAT_NAMES[g.best_cat], 0, Px.DIM)


func _draw_pause(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(60, 200, 240, 196), Px.PANEL, Px.GOLD)
	Px.text_center(c, 180, 222, "PAUSED", 3, Px.GOLD)
	Px.text_center(c, 180, 246, "CHIPS %.1f   DRIVE %d" % [g.bankroll, g.drive_no], 0, Px.DIM)


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
	btn_next.visible = phase == "RESULT" and not suspense
	if phase == "RESULT":
		btn_next.set_label("NEXT DRIVE" if last_res.get("drive_over", false) else "NEXT DOWN")
	var busted: bool = phase == "OVER" and not suspense
	overlay.visible = busted
	btn_new.visible = busted
	btn_new_menu.visible = busted
	btn_menu.visible = phase != "OVER"
	btn_info.visible = phase == "BET"
	pause_panel.visible = paused
	for b in [btn_resume, btn_restart, btn_quit]:
		b.visible = paused
	if phase == "OVER" and not committed:
		commit_run()
	for p in [hud, tells_panel, hand_info, bet_panel, stake_panel, preview_panel, result_panel, overlay]:
		p.queue_redraw()
	_sync_cards()


# ------------------------------------------------------------------ input
func _on_hand_tapped(i: int) -> void:
	if paused or detail.visible:
		return
	if g.phase == "BET":
		if g.eligible().has(i):
			g.set_play(i)                              # choose which card in the made hand runs the play
			_refresh()
		return
	if g.phase != "DRAW":
		return
	focus_idx = i
	if marked.has(i):
		marked.erase(i)
	elif marked.size() < 3:
		marked.append(i)
	_refresh()


func _on_hover(i: int) -> void:
	if g.phase == "DRAW" and focus_idx != i:
		focus_idx = i
		bet_panel.queue_redraw()


func _on_inspect(i: int) -> void:
	if g.phase in ["DRAW", "BET", "RESULT"] and not paused:
		detail.show_card(g.mine[i])


func _on_info() -> void:
	if g.phase in ["BET", "RESULT"] and not paused:
		detail.show_card(g.my_lead())


func _on_draw() -> void:
	if g.phase != "DRAW":
		return
	_do_draw(marked.duplicate())


func _on_stand() -> void:
	if g.phase == "DRAW":
		_do_draw([])


## Discards fly off, replacements fly in from the shoe and flip, then two defense cards turn face-up.
func _do_draw(idx: Array) -> void:
	var before: Array = g.theirs.duplicate()
	flip_base = 0.75 if not idx.is_empty() else 0.35
	g.draw(idx)
	marked = []
	var n := 0
	for i in idx:
		var old: QCardView = my_views[i]
		old.fly_out(Vector2(-90, old.position.y), n * 0.05)
		my_views[i] = _new_mine(i, 0.12 + n * 0.1)
		n += 1
	for i in 5:
		if before[i] != g.theirs[i]:                  # the AI swapped this one: a quick rattle, still face-down
			def_views[i].set_card(g.theirs[i])
			def_views[i].shake(2.0)
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
	pre_st = g.st.duplicate(true)
	last_res = g.showdown()
	suspense = true
	stage = "flip"
	suspense_t = 0.9
	bank_hold = 99.0
	_refresh()


## A won hand puts the play's curve on a wheel and spins it: the randomness made visible.
func _start_wheel() -> void:
	stage = "spin"
	wheel_done = false
	var lead: Dictionary = last_res.my_lead
	var th := DefContext.apply(lead.theta, last_res.style)
	wheel_slices = WheelView.slices_for(th, int(round(pre_st.yardline_to_opponent_goal)))
	wheel.set_slices(wheel_slices)
	wheel.marks = []
	var b: Dictionary = last_res.bet
	if b.line >= 0 and b.stake > 0.0:
		wheel.marks = [wheel.fraction_for(g.lines.threshold(lead, int(b.line)))]
	wheel_layer.visible = true
	wheel_panel.queue_redraw()
	wheel.landed.connect(_on_wheel_landed, CONNECT_ONE_SHOT)
	wheel.spin_to(wheel_slices, WheelView.category_for(wheel_slices, int(last_res.yards), bool(last_res.turnover)), 2.8)


func _on_wheel_landed() -> void:
	wheel_done = true
	stage = "hold"
	suspense_t = 1.3
	wheel_panel.queue_redraw()


func _on_wheel_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if stage == "spin":
			wheel.skip()
		elif stage == "hold":
			suspense_t = 0.0


func _draw_wheel_panel(c: Control) -> void:
	if last_res.is_empty():
		return
	var lead: Dictionary = last_res.my_lead
	var style: String = last_res.style
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(24, 160, 312, 352), Px.PANEL, Px.GOLD)
	Px.text_center(c, 180, 172, "THE SNAP", 2, Px.GOLD)
	Px.text_center(c, 180, 190, "%s  %s" % [lead.label, lead.name], 1, Px.FG)
	Px.text_center(c, 180, 208, "vs %s defense" % style, 1, QCardView.STYLE_COLORS[style])
	var b: Dictionary = last_res.bet
	if b.line >= 0 and b.stake > 0.0:
		Px.text_center(c, 180, 414, "YOUR LINE: %s  %d+ YDS  STAKE %.1f" % [Lines.NAMES[int(b.line)], g.lines.threshold(lead, int(b.line)), b.stake], 0, Px.GOLD)
		Px.text_center(c, 180, 428, "gold tick = your line. Land past it to clear.", 0, Px.DIM)
	else:
		Px.text_center(c, 180, 414, "NO BET: ante only", 0, Px.DIM)
	Px.text_center(c, 180, 428 if b.line < 0 else 442, "wedges are sized by this play's real odds", 0, Px.DIM)
	if wheel_done:
		var yards: int = last_res.yards
		var col := Px.GREEN if yards > 0 else (Px.RED if yards < 0 or last_res.turnover else Px.FG)
		var head := "TURNOVER" if last_res.turnover else ("%+d YDS" % yards if yards != 0 else "NO GAIN")
		Px.text_center(c, 180, 462, head, 3, col)
		if b.line >= 0 and b.stake > 0.0:
			Px.text_center(c, 180, 486, ("BET CLEARED %+.1f" if last_res.cleared else "BET MISSED %+.1f") % last_res.bet_delta, 1, Px.GREEN if last_res.cleared else Px.RED)
	else:
		Px.text_center(c, 180, 478, "tap to skip", 0, Px.LINE)


## The verdict lands: the field moves, the lead card reacts, the chip delta floats up, big results get confetti.
func _fx_result() -> void:
	suspense = false
	stage = ""
	bank_hold = 0.0
	wheel_layer.visible = false
	var r := last_res
	field.animate_result(pre_st, g.st, r)
	_refresh()
	var lead: QCardView = my_views[_lead_index()]
	var good: bool = r.delta >= 0.0
	if r.win == 1:
		lead.pop()
		lead.flash(Px.GOLD)
	elif r.win == -1:
		lead.shake(6.0)
		lead.flash(Px.RED)
	var evt: String = r.event
	_float("%+.1f" % r.delta, Px.GREEN if good else Px.RED, 3, 316)
	if evt == "TOUCHDOWN":
		_float("TOUCHDOWN  +%d CHIPS" % int(QGame.TD_BONUS), Px.GOLD, 2, 292)
		fx_layer.add_child(Burst.new(Vector2(336, 110), 70, [Px.GOLD, Color.WHITE, Px.RED, Px.ROYAL], 230.0))
		fx_layer.add_child(Burst.new(Vector2(180, 300), 40, [Px.GOLD, Color.WHITE], 190.0))
		_shake_screen(3.0)
	elif r.cleared and r.bet.line >= 3:
		fx_layer.add_child(Burst.new(Vector2(180, 380), 28, [Px.GOLD, Px.GREEN, Color.WHITE], 150.0))
	if evt in ["SACKED", "FUMBLE", "PICK SIX", "SAFETY"]:
		_shake_screen(5.0)


func _float(text: String, color: Color, s: int, y: float) -> void:
	var f := FloatText.new(text, color, s)
	f.position = Vector2(0, y)
	fx_layer.add_child(f)


func _shake_screen(mag: float) -> void:
	var tw := create_tween()
	for i in 8:
		tw.tween_property(self, "position", Vector2((mag if i % 2 == 0 else -mag) * (1.0 - i / 8.0), (-mag if i % 3 == 0 else mag) * 0.5 * (1.0 - i / 8.0)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _process(delta: float) -> void:
	if suspense:
		suspense_t -= delta
		if suspense_t <= 0.0:
			if stage == "flip" and last_res.win == 1:
				_start_wheel()
			elif stage != "spin":
				_fx_result()
	if bank_hold > 0.0:
		bank_hold -= delta
	elif absf(shown_bank - g.bankroll) > 0.001:
		var diff := absf(g.bankroll - shown_bank)
		shown_bank = move_toward(shown_bank, g.bankroll, maxf(3.0, diff * 6.0) * delta)
		hud.queue_redraw()


func _on_next() -> void:
	if g.phase != "RESULT" or suspense:
		return
	g.next()
	marked = []
	field.set_state(g.st)
	_rebuild_cards()
	_refresh()


func commit_run() -> void:
	if not committed:
		committed = true
		Save.commit_run(g)


func _on_pause() -> void:
	paused = not paused
	_refresh()
	pause_panel.queue_redraw()


func _on_exit() -> void:
	paused = false
	_refresh()
	exit_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		commit_run()


func _on_new_run() -> void:
	commit_run()
	committed = false
	paused = false
	g = QGame.new()
	marked = []
	last_res = {}
	suspense = false
	stage = ""
	wheel_layer.visible = false
	shown_bank = g.bankroll
	stake = 2.0
	field.set_state(g.st)
	_rebuild_cards()
	_refresh()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	if e.keycode == KEY_ESCAPE and g.phase != "OVER":
		_on_pause()
		return
	if paused or detail.visible:
		return
	if e.keycode == KEY_P and g.phase == "BET":
		var el: Array = g.eligible()
		g.set_play(el[(el.find(g.play_idx) + 1) % el.size()])
		_refresh()
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
