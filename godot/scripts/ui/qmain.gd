class_name QMain
extends Control
## Game screen. Flow per down: DRAW (tap up to 3 cards to swap) -> BET (read the 2 face-up defense cards and pick which
## card runs the play, then SNAP) -> showdown -> the wheel decides the yards. Yardage is the only currency.

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
var suspense := false                       # the beat between the flip and the verdict
var suspense_t := 0.0
var focus_idx := -1                          # the card whose info shows in the bet panel while drawing
var detail: CardDetail
var btn_info: PxButton
var versus: VersusFx
var stage := ""                             # showdown beats: flip -> spin -> hold
var pre_st: Dictionary = {}
var _wheel_key := ""
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
var result_panel: DrawPanel
var overlay: DrawPanel
var hand_layer: Control
var btn_draw: PxButton
var btn_stand: PxButton
var btn_show: PxButton
var btn_next: PxButton
var btn_new: PxButton
var my_views: Array = []
var def_views: Array = []
var marked: Array = []
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
	field.goal_label = "GOAL"
	field.set_process(true)
	field.set_state(g.st)
	tells_panel = _panel(Rect2(4, 226, 352, 38), _draw_tells)
	hand_layer = Control.new()
	hand_layer.size = Vector2(360, 640)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)
	hand_info = _panel(Rect2(4, 360, 352, 16), _draw_hand_info)
	bet_panel = _panel(Rect2(8, 378, 344, 150), _draw_bets)
	bet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel = WheelView.new(146)
	wheel.position = Vector2(10, 380)
	wheel.mouse_filter = Control.MOUSE_FILTER_STOP
	wheel.visible = false
	wheel.gui_input.connect(_on_wheel_input)
	add_child(wheel)
	btn_draw = _button("DRAW", Px.GOLD, Rect2(8, 532, 166, 28), _on_draw)
	btn_stand = _button("STAND PAT", Px.ROYAL, Rect2(180, 532, 172, 28), _on_stand)
	btn_show = _button("SNAP", Px.GOLD, Rect2(8, 532, 344, 28), _on_show)
	btn_next = _button("NEXT", Px.GOLD, Rect2(8, 532, 344, 28), _on_next)
	result_panel = _panel(Rect2(4, 564, 352, 74), _draw_result)
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
	if not old.is_empty():
		Sfx.play("swoosh")
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
	var holding := suspense and not last_res.is_empty() and not pre_st.is_empty()      # keep the pre-snap numbers until the verdict
	var stt: Dictionary = pre_st if holding else g.st
	var tds_now: int = g.tds - (1 if holding and last_res.event == "TOUCHDOWN" else 0)
	var yards_now: int = g.yards_total - (int(last_res.yards) if holding else 0)
	c.draw_rect(Rect2(0, 0, 360, 30), Color("14247a"))
	c.draw_rect(Rect2(0, 29, 360, 1), Px.ROYAL)
	Px.text(c, 6, 0, "TOUCHDOWNS", 0, Px.DIM)
	Px.text(c, 6, 12, str(tds_now), 3, Px.GOLD)
	Px.text_center(c, 190, 3, _spot(stt.yardline_to_opponent_goal), 2, Px.FG)
	Px.text_center(c, 190, 15, "%d YDS TO GOAL" % int(round(stt.yardline_to_opponent_goal)), 0, Px.DIM)
	Px.text_right(c, 354, 1, "DRIVE %d/%d" % [g.drive_no, QGame.DRIVES], 0, Px.DIM)
	Px.text_right(c, 354, 14, "%+d YDS" % yards_now, 0, Px.GOLD if yards_now >= 0 else Px.RED)


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
	Px.box(c, Rect2(0, 0, 344, 150), Px.PANEL, Px.LINE)
	if g.phase == "DRAW":
		if focus_idx < 0 or focus_idx > 4:
			Px.text_center(c, 172, 40, "THE WHEEL OPENS AFTER THE DRAW", 1, Px.DIM)
			Px.text_center(c, 172, 62, "tap up to 3 cards to swap, then DRAW", 0, Px.DIM)
			Px.text_center(c, 172, 78, "tap a card to mark it and read its play. Tap (i) or hold for the full card.", 0, Px.DIM)
			return
		_draw_focus(c, g.mine[focus_idx])
		return
	var x0 := 158.0
	var spun: bool = not last_res.is_empty() and (suspense and stage in ["spin", "hold"] or g.phase in ["RESULT", "OVER"]) and last_res.spin_kind != "none"
	if spun:
		var gain: bool = last_res.spin_kind == "gain"
		var col := Px.GREEN if gain else Px.RED
		Px.text(c, x0, 6, "WIN WHEEL" if gain else "LOSS WHEEL", 2, col)
		Px.text(c, x0, 24, "yards x %s hand" % ("YOUR" if gain else "THEIR"), 1, Px.DIM)
		Px.text(c, x0, 44, "x%.1f" % last_res.mult, 3, Px.GOLD)
		Px.text(c, x0 + 70, 50, "%s" % Poker.CAT_NAMES[int(last_res.my_cat if gain else last_res.their_cat)], 0, Px.DIM)
		if wheel_done or (g.phase in ["RESULT", "OVER"] and not suspense):
			Px.text(c, x0, 78, "%d x %.1f" % [last_res.spin, last_res.mult], 2, Px.FG)
			Px.text(c, x0, 98, "%+d YDS" % last_res.yards, 3, col)
		else:
			Px.text(c, x0, 84, "spinning...", 1, Px.DIM)
			Px.text(c, x0, 122, "tap the wheel to skip", 0, Px.LINE)
		return
	if not last_res.is_empty() and g.phase in ["RESULT", "OVER"] and last_res.spin_kind == "none":
		Px.text(c, x0, 6, "NO SPIN", 2, Px.DIM)
		Px.text(c, x0, 28, "TURNOVER: you lost by %d+ hand classes." % QGame.PICK_SIX_GAP if last_res.turnover else "Identical hands: nothing moves.", 0, Px.FG)
		return
	# before the snap: the wheel shows this play's odds if you win, and a quick reminder of the multipliers
	Px.text(c, x0, 4, "IF YOU WIN", 1, Px.GOLD)
	var mine_cat: int = int(g.my_eval.cat)
	var short := ["HIGH CARD", "PAIR", "TWO PAIR", "TRIPS", "STRAIGHT", "FLUSH", "FULL HOUSE", "QUADS", "STR FLUSH", "5 OF KIND"]
	for i in 10:
		var x := x0 + (i / 5) * 96.0
		var y := 22.0 + (i % 5) * 12.0
		var me := i == mine_cat
		if me:
			c.draw_rect(Rect2(x - 3, y, 92, 12), Color(Px.GOLD, 0.22))
		Px.text(c, x, y, short[i], 0, Px.GOLD if me else Px.DIM)
		Px.text_right(c, x + 86, y, "x%.1f" % Poker.MULT[i], 0, Px.GREEN if me else Px.FG)
	Px.text(c, x0, 80, "YOUR HAND  x%.1f" % g.my_mult(), 1, Px.GREEN)
	Px.text(c, x0, 98, "WIN: gain wheel x YOUR hand", 0, Px.FG)
	Px.text(c, x0, 110, "LOSE: loss wheel x THEIR hand", 0, Px.FG)
	Px.text(c, x0, 122, "%d+ classes down = turnover" % QGame.PICK_SIX_GAP, 0, Px.DIM)
	Px.text(c, x0, 134, "wedges = this play's odds", 0, Px.LINE)


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




func _row(c: Control, y: float, label: String, text: String, col: Color) -> void:
	Px.text(c, 6, y + 1, label, 0, Px.DIM)
	Px.text(c, 38, y, text, 1, col)




func _draw_result(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 352, 74), Px.PANEL, Px.LINE)
	if not last_res.is_empty() and g.phase in ["RESULT", "OVER"] and not suspense:
		var r := last_res
		var mine: String = Poker.CAT_NAMES[int(r.my_cat)]
		var theirs: String = Poker.CAT_NAMES[int(r.their_cat)]
		var evt: String = r.event
		# row 1: who won the hand
		if r.win == 1:
			_row(c, 3, "HAND", "WON   %s beats %s" % [mine, theirs], Px.GREEN)
		elif r.win == -1:
			_row(c, 3, "HAND", "LOST  %s loses to %s" % [mine, theirs], Px.RED)
		else:
			_row(c, 3, "HAND", "TIED  identical hands", Px.DIM)
		Px.text_right(c, 346, 4, "x%.1f vs x%.1f" % [r.my_mult, r.their_mult], 1, Px.DIM)
		# row 2: the wheel and the multiplier
		var spin_txt := "NO SPIN"
		var scol := Px.DIM
		if r.spin_kind == "gain":
			spin_txt = "WHEEL %d x %.1f = +%d YDS" % [r.spin, r.mult, r.yards]
			scol = Px.GREEN
		elif r.spin_kind == "loss":
			spin_txt = "WHEEL %d x %.1f = %d YDS" % [r.spin, r.mult, r.yards]
			scol = Px.RED
		elif r.turnover:
			spin_txt = "NO SPIN   turnover"
			scol = Px.RED
		_row(c, 19, "SPIN", spin_txt, scol)
		# row 3: where that leaves the drive
		var nxt := ""
		var ncol := Px.FG
		match evt:
			"TOUCHDOWN":
				nxt = "TOUCHDOWN!"
				ncol = Px.GOLD
			"PICK SIX", "TURNOVER":
				nxt = "TURNOVER"
				ncol = Px.RED
			"SAFETY":
				nxt = "SAFETY"
				ncol = Px.RED
			"TURNOVER ON DOWNS":
				nxt = "SHORT ON 4TH DOWN: TURNOVER"
				ncol = Px.RED
			"PUSH":
				nxt = "REPLAY THE DOWN"
			_:
				var dn: String = ["", "1ST", "2ND", "3RD", "4TH"][int(g.st.down)]
				nxt = ("FIRST DOWN, " if evt == "FIRST DOWN" else "") + "%s & %d" % [dn, int(round(g.st.distance))]
				ncol = Px.GOLD if evt == "FIRST DOWN" else Px.FG
		_row(c, 35, "NEXT", nxt, ncol)
		var net: int = r.yards
		_row(c, 51, "NET", "%+d YDS" % net if net != 0 else "NO CHANGE", Px.GREEN if net > 0 else (Px.RED if net < 0 else Px.DIM))
	else:
		var y := 4
		var head := "SHOWDOWN..." if suspense else "RECENT"
		if g.phase == "BET" and not suspense:
			var lead: Dictionary = g.my_lead()
			Px.text(c, 6, 4, "YOUR PLAY", 0, Px.DIM)
			Px.text(c, 6, 15, "%s  %s" % [lead.label, lead.name], 3, Px.GOLD)
			var hint := "tap another gold-edged card to switch the play (or press P)" if g.eligible().size() > 1 else "only this card can run this hand"
			Px.text(c, 6, 38, hint, 0, Px.DIM)
			Px.text(c, 6, 52, "see its strengths and routes with INFO", 0, Px.DIM)
			return
		Px.text(c, 6, y, head, 1, Px.GOLD)
		y += 18
		for line in g.log.slice(0, 4) if g.phase == "BET" or g.phase == "DRAW" else g.log.slice(1, 3):
			Px.text(c, 6, y, String(line).to_upper(), 0, Px.DIM)
			y += 13



func _draw_overlay(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(30, 200, 300, 254), Px.PANEL, Px.GOLD)
	Px.text_center(c, 180, 222, "RUN COMPLETE", 3, Px.GOLD)
	Px.text_center(c, 180, 262, "%d TOUCHDOWN%s" % [g.tds, "" if g.tds == 1 else "S"], 1, Px.FG)
	Px.text_center(c, 180, 286, "%+d NET YARDS" % g.yards_total, 1, Px.GREEN if g.yards_total >= 0 else Px.RED)
	Px.text_center(c, 180, 310, "%d DRIVES   %d SNAPS" % [QGame.DRIVES, g.history.size()], 1, Px.DIM)
	if g.best_cat >= 0:
		Px.text_center(c, 180, 330, "BEST HAND WON: %s" % Poker.CAT_NAMES[g.best_cat], 0, Px.DIM)



func _draw_pause(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(60, 200, 240, 196), Px.PANEL, Px.GOLD)
	Px.text_center(c, 180, 222, "PAUSED", 3, Px.GOLD)
	Px.text_center(c, 180, 246, "TD %d   DRIVE %d/%d   %+d YDS" % [g.tds, g.drive_no, QGame.DRIVES, g.yards_total], 0, Px.DIM)


# ------------------------------------------------------------------ state refresh
func _refresh() -> void:
	var phase := g.phase
	btn_draw.visible = phase == "DRAW"
	btn_stand.visible = phase == "DRAW"
	btn_draw.set_label("DRAW %d" % marked.size() if marked.size() > 0 else "DRAW 0")
	btn_draw.disabled = marked.is_empty()
	btn_show.visible = phase == "BET"
	btn_next.visible = phase == "RESULT" and not suspense
	btn_next.shine = btn_next.visible
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
	wheel.visible = (phase == "BET" or phase == "RESULT") and not paused
	if phase == "BET" and not suspense:
		_preview_wheel()
	for p in [hud, tells_panel, hand_info, bet_panel, result_panel, overlay]:
		p.queue_redraw()
	_sync_cards()


# ------------------------------------------------------------------ input
func _on_hand_tapped(i: int) -> void:
	if paused or detail.visible:
		return
	if g.phase == "BET":
		if g.eligible().has(i):
			if i != g.play_idx:
				Sfx.play("select")
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
	if not idx.is_empty():
		Sfx.play("swoosh")
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





func _on_show() -> void:
	if g.phase != "BET":
		return
	pre_st = g.st.duplicate(true)
	last_res = g.showdown()
	suspense = true
	stage = "flip"
	suspense_t = 2.1                              # the defense cards flip, then the versus banner plays out
	_refresh()
	_show_versus()


## Banner comparing the two hands, ending in a WIN / LOSS stamp.
func _show_versus() -> void:
	if versus != null and is_instance_valid(versus):
		versus.queue_free()
	var r := last_res
	var gap: int = int(r.their_cat) - int(r.my_cat)
	var note := ""
	if r.win == 1:
		note = "the wheel spins a gain, x%.1f for your hand" % r.my_mult
	elif r.win == -1:
		var how := ("same hand, higher cards") if gap <= 0 else ("beaten by %d hand class%s" % [gap, "" if gap == 1 else "es"])
		note = "%s: %s" % [how, "TURNOVER, no spin" if r.turnover else "the wheel spins a loss, x%.1f for theirs" % r.their_mult]
	else:
		note = "identical hands, nobody moves"
	versus = VersusFx.new(Poker.CAT_NAMES[int(r.my_cat)], Poker.multiplier(int(r.my_cat)), Poker.CAT_NAMES[int(r.their_cat)],
			Poker.multiplier(int(r.their_cat)), int(r.win), note)
	fx_layer.add_child(versus)


## A won hand puts the play's curve on a wheel and spins it: the randomness made visible.


## The wheel for this snap: the real curve against the real hidden style, win or loss. It lives in the bottom panel.
func _start_wheel() -> void:
	if versus != null and is_instance_valid(versus):
		versus.finish()
	stage = "spin"
	wheel_done = false
	_wheel_key = ""
	var lead: Dictionary = last_res.my_lead
	var th := DefContext.apply(lead.theta, last_res.style)
	if last_res.spin_kind == "gain":
		var goal := _wheel_goal(float(pre_st.yardline_to_opponent_goal), float(last_res.mult))
		wheel_slices = WheelView.slices_for([th], goal)
	else:
		wheel_slices = WheelView.loss_slices_for([th])
	wheel.set_slices(wheel_slices)
	wheel.marks = []
	wheel.visible = true
	bet_panel.queue_redraw()
	wheel.landed.connect(_on_wheel_landed, CONNECT_ONE_SHOT)
	wheel.spin_to(wheel_slices, WheelView.category_for(wheel_slices, int(last_res.spin)), 2.8)


## Wheel yards that would carry the ball into the end zone once the hand multiplier is applied.
func _wheel_goal(yards_left: float, mult: float) -> int:
	return maxi(1, int(ceil(yards_left / maxf(mult, 0.1))))


## Before the snap the wheel shows this play's odds if you win, averaged over the four defense styles.
func _preview_wheel() -> void:
	var key := "%d|%d|%.0f" % [g.play_idx, g.drive_no * 10 + int(g.st.down), g.st.yardline_to_opponent_goal]
	if key == _wheel_key:
		return
	_wheel_key = key
	var lead: Dictionary = g.my_lead()
	var thetas: Array = []
	for st in DefContext.STYLES:
		thetas.append(DefContext.apply(lead.theta, st))
	wheel_slices = WheelView.slices_for(thetas, _wheel_goal(float(g.st.yardline_to_opponent_goal), g.my_mult()))
	wheel.set_slices(wheel_slices)
	wheel.marks = []
	bet_panel.queue_redraw()



func _on_wheel_landed() -> void:
	Sfx.play("land")
	wheel_done = true
	stage = "hold"
	suspense_t = 1.3
	bet_panel.queue_redraw()


func _on_wheel_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if stage == "spin":
			wheel.skip()
		elif stage == "hold":
			suspense_t = 0.0



## The verdict lands: the field moves, the lead card reacts, the chip delta floats up, big results get confetti.

func _fx_result() -> void:
	suspense = false
	stage = ""
	if versus != null and is_instance_valid(versus):
		versus.finish()
	var r := last_res
	field.animate_result(pre_st, g.st, r)
	_refresh()
	var lead: QCardView = my_views[_lead_index()]
	if r.win == 1:
		lead.pop()
		lead.flash(Px.GOLD)
	elif r.win == -1:
		lead.shake(6.0)
		lead.flash(Px.RED)
	var evt: String = r.event
	match evt:
		"TOUCHDOWN": Sfx.play("touchdown")
		"FIRST DOWN": Sfx.play("first_down")
		"PICK SIX", "SAFETY", "TURNOVER ON DOWNS": Sfx.play("turnover")
	var net: int = r.yards
	if g.phase == "OVER":
		Sfx.play("win" if g.tds > 0 else "lose", 0.8)
	elif net > 0:
		Sfx.play("chip_up", 0.35)
	elif net < 0:
		Sfx.play("chip_down", 0.35)
	_float("%+d YDS" % net if net != 0 else "NO CHANGE", Px.GREEN if net > 0 else (Px.RED if net < 0 else Px.DIM), 3, 316)
	if evt == "TOUCHDOWN":
		_float("TOUCHDOWN!", Px.GOLD, 2, 292)
		fx_layer.add_child(Burst.new(Vector2(336, 110), 70, [Px.GOLD, Color.WHITE, Px.RED, Px.ROYAL], 230.0))
		fx_layer.add_child(Burst.new(Vector2(180, 300), 40, [Px.GOLD, Color.WHITE], 190.0))
		_shake_screen(3.0)
	elif r.win == 1 and int(r.yards) >= 25:
		fx_layer.add_child(Burst.new(Vector2(180, 380), 28, [Px.GOLD, Px.GREEN, Color.WHITE], 150.0))
	if evt in ["PICK SIX", "SAFETY"]:
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
