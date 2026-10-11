class_name QMain
extends Control
## Game screen against the computer. Drives alternate: when you have the ball you pick the PLAY, when the computer has it
## you pick the DEFENSIVE CALL (the suit of the card you call with is your style). Flow per down: DRAW (tap up to
## MAX_DISCARDS cards to swap) -> BET (read the face-up tells, then explicitly select a card from your made hand and
## press SNAP in the middle of the wheel) -> showdown -> the wheel decides the yards. Yardage is the only currency.

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
const SUIT_NAMES := ["RUN", "RPO", "PASS", "SHOT"]
const SHOE_POS := Vector2(330, 36)         # where dealt cards fly in from

signal exit_requested

var g: QGame
var paused := false
var committed := false
var fx_layer: Control
var suspense := false                       # the beat between the snap and the verdict
var suspense_t := 0.0
var focus_idx := -1                          # the card whose info shows in the bottom panel while drawing
var detail: CardDetail
var btn_info: PxButton
var versus: VersusFx
var stage := ""                             # showdown beats: flip -> spin -> hold
var pre_st: Dictionary = {}
var wheel: WheelView
var wheel_slices: Array = []
var wheel_done := false
var flip_base := 0.9                         # delay before the face-up computer cards turn over
var _wheel_key := ""
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
var call_panel: DrawPanel
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
	field.attack_left = not g.player_off
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
	btn_show = _button("SNAP", Px.GOLD, Rect2(52, 441, 62, 24), _on_show)    # in the hole of the wheel
	call_panel = _panel(Rect2(8, 532, 344, 28), _draw_call)
	btn_draw = _button("DRAW", Px.GOLD, Rect2(8, 532, 166, 28), _on_draw)
	btn_stand = _button("STAND PAT", Px.ROYAL, Rect2(180, 532, 172, 28), _on_stand)
	btn_next = _button("NEXT", Px.GOLD, Rect2(8, 532, 344, 28), _on_next)
	result_panel = _panel(Rect2(4, 564, 352, 74), _draw_result)
	fx_layer = Control.new()
	fx_layer.size = Vector2(360, 640)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	overlay = _panel(Rect2(0, 0, 360, 640), _draw_overlay)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_new = _button("NEW GAME", Px.GOLD, Rect2(100, 372, 160, 34), _on_new_run)
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
	btn_restart = _button("RESTART GAME", Px.ROYAL, Rect2(90, 304, 180, 32), _on_new_run)
	btn_quit = _button("MAIN MENU", Px.ROYAL, Rect2(90, 346, 180, 32), _on_exit)
	for b in [btn_resume, btn_restart, btn_quit]:
		b.visible = false


# ------------------------------------------------------------------ cards
## Card width so the whole hand fits one row: up to 64 px, narrower as the hand grows (7 cards = 49 px).
func _card_w() -> int:
	var n := QGame.HAND_SIZE
	return mini(64, int((356.0 - (n - 1) * 2.0) / float(n)))


func _row_x0() -> float:
	var n := QGame.HAND_SIZE
	return (360.0 - (n * _card_w() + (n - 1) * 2.0)) / 2.0


func _slot_mine(i: int) -> Vector2:
	return Vector2(_row_x0() + i * (_card_w() + 2), 268)


func _slot_def(i: int) -> Vector2:
	return Vector2(_row_x0() + i * (_card_w() + 2) + 1, 160)


func _new_mine(i: int, delay: float) -> QCardView:
	var v := QCardView.new(g.mine[i], "mine", i, _card_w())
	v.call_word = "PLAY" if g.player_off else "CALL"
	v.tapped.connect(_on_hand_tapped)
	v.inspected.connect(_on_inspect)
	v.hovered.connect(_on_hover)
	hand_layer.add_child(v)
	v.place(_slot_mine(i))
	v.deal_in(SHOE_POS, delay, true)
	return v


## A full new deal: the old cards fly off to the left, new ones fly in from the shoe.
func _rebuild_cards() -> void:
	var old: Array = my_views + def_views
	if not old.is_empty():
		Sfx.play("swoosh")
	for k in old.size():
		old[k].fly_out(Vector2(-90, old[k].position.y), k * 0.02)
	my_views = []
	def_views = []
	var base := 0.25 if not old.is_empty() else 0.0
	var n := QGame.HAND_SIZE
	for i in n:
		var d := QCardView.new(g.theirs[i], "theirs", i, _card_w(), not g.player_off)
		hand_layer.add_child(d)
		d.place(_slot_def(i))
		d.deal_in(SHOE_POS, base + i * 0.05, false)
		def_views.append(d)
	for i in n:
		my_views.append(_new_mine(i, base + 0.3 + i * 0.05))
	_sync_cards()


func _sync_cards() -> void:
	var picking: bool = g.phase == "BET" and not suspense
	for i in QGame.HAND_SIZE:
		my_views[i].marked = marked.has(i)
		my_views[i].highlight = g.phase != "DRAW" and i == g.play_idx
		my_views[i].eligible = picking and g.eligible().has(i) and i != g.play_idx
		my_views[i].dimmed = picking and not g.eligible().has(i)
	var show_all: bool = g.phase == "RESULT" or g.phase == "OVER"
	var n := 0
	for i in QGame.HAND_SIZE:
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
	var me := g.tds
	var cpu := g.cpu_tds
	if holding and last_res.event == "TOUCHDOWN":
		if last_res.player_off:
			me -= 1
		else:
			cpu -= 1
	c.draw_rect(Rect2(0, 0, 360, 30), Color("14247a"))
	c.draw_rect(Rect2(0, 29, 360, 1), Px.ROYAL)
	Px.text(c, 6, 0, "YOU", 0, Px.ROYAL)
	Px.text(c, 6, 12, str(me), 3, Px.GOLD)
	Px.text(c, 50, 0, "CPU", 0, Px.RED)
	Px.text(c, 50, 12, str(cpu), 3, Px.GOLD)
	Px.text_center(c, 190, 3, _spot(stt.yardline_to_opponent_goal), 2, Px.FG)
	Px.text_center(c, 190, 15, "%d YDS TO GOAL" % int(round(stt.yardline_to_opponent_goal)), 0, Px.DIM)
	Px.text_right(c, 354, 1, "DRIVE %d/%d" % [g.drive_no, QGame.total_drives()], 0, Px.DIM)
	Px.text_right(c, 354, 14, "OFFENSE" if g.player_off else "DEFENSE", 0, Px.GREEN if g.player_off else Px.RED)


## Cards left by rank, from what the player has seen since the last shuffle (green = richer than average, red = thinner).
func _draw_tracker(c: Control) -> void:
	if not bool(Save.setting("counter", true)):
		return
	var labels := ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
	var expected := float(QGame.DECKS * 4) * float(g.shoe_left()) / float(QGame.DECKS * 52)
	for i in 13:
		var left := g.rank_left(i + 2)
		var ratio := float(left) / maxf(0.5, expected)
		var col := Px.GREEN if ratio > 1.2 else (Px.RED if ratio < 0.8 else Px.FG)
		var x := 6.0 + i * 26.0
		Px.text(c, x, 19, labels[i] + ":", 0, Px.DIM)
		Px.text(c, x + Px.text_width(labels[i] + ":", 0) + 1, 19, str(left), 0, col)


func _draw_tells(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 352, 38), Px.PANEL, Px.LINE)
	Px.text_right(c, 346, 3, "WILD %d   SHOE %d" % [g.wild_left(), g.shoe_left()], 0, Px.DIM)
	match g.phase:
		"DRAW":
			Px.text(c, 6, 2, "THE CPU HOLDS %d CARDS" % QGame.HAND_SIZE, 1, Px.GOLD)
			_draw_tracker(c)
		"BET":
			var x := 6.0
			Px.text(c, x, 2, "TELLS:", 1, Px.GOLD)
			x += 44
			for i in g.face_up:
				var cd: Dictionary = g.theirs[i]
				var t := ""
				var col := Px.FG
				if g.player_off:                                  # its cards are style tells: the suit is the defense style
					var style: String = g.style_of(cd)
					t = "%s %s" % [cd.label, style]
					col = QCardView.STYLE_COLORS[style]
				else:                                             # its cards are plays: you see what each one fears
					var info: Dictionary = cd.get("info", {})
					t = "%s %s" % [cd.label, cd.name]
					if not info.is_empty():
						t += " -%s" % QCardView.STYLE_SHORT[info.weak]
				Px.text(c, x, 2, t, 1, col)
				x += Px.text_width(t, 1) + 10
			_draw_tracker(c)
		_:
			if last_res.is_empty() or suspense:
				return
			var style: String = last_res.style
			var who := "CPU" if last_res.player_off else "YOUR"
			Px.text(c, 6, 2, "%s DEFENSE: %s" % [who, style], 1, QCardView.STYLE_COLORS[style])
			Px.text(c, 6, 19, "%s: %s" % [style, STYLE_NOTES[style]], 0, Px.DIM)


func _draw_hand_info(c: Control) -> void:
	var e: Dictionary = g.my_eval
	var line := "%s x%.1f" % [Poker.CAT_NAMES[int(e.cat)], g.my_mult()]
	Px.text(c, 2, 0, line, 1, Px.GREEN)
	var x := 2.0 + Px.text_width(line, 1) + 12.0
	if g.phase == "DRAW":
		Px.text(c, x, 0, "tap (i) on a card for its play", 0, Px.DIM)
		return
	if not g.has_selection():
		Px.text(c, x, 0, "select a gold card below" if g.phase == "BET" else "", 0, Px.GOLD)
		return
	var lead: Dictionary = g.my_lead()
	var tail := "%s %s %s" % ["PLAY" if g.player_off else "CALL", lead.label, lead.name]
	Px.text(c, x, 0, tail, 1, Px.GOLD)
	x += Px.text_width(tail, 1) + 10.0
	var info: Dictionary = lead.get("info", {})
	if not info.is_empty() and g.phase == "BET":
		Px.text(c, x, 2, "+" + info.strong, 0, Px.GREEN)
		Px.text(c, x + Px.text_width("+" + info.strong, 0) + 6, 2, "-" + info.weak, 0, Px.RED)


## The bottom panel: the wheel sits at its left, text and reminders at its right.
func _draw_bets(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 344, 150), Px.PANEL, Px.LINE)
	if g.phase == "DRAW":
		if focus_idx < 0 or focus_idx >= QGame.HAND_SIZE:
			Px.text_center(c, 172, 40, "THE WHEEL OPENS AFTER THE DRAW", 1, Px.DIM)
			Px.text_center(c, 172, 62, "tap up to %d cards to swap, then DRAW" % QGame.MAX_DISCARDS, 0, Px.DIM)
			Px.text_center(c, 172, 78, "tap a card to mark it and read its play. Tap (i) or hold for the full card.", 0, Px.DIM)
			return
		_draw_focus(c, g.mine[focus_idx])
		return
	var x0 := 158.0
	var spun: bool = not last_res.is_empty() and (suspense and stage in ["spin", "hold"] or g.phase in ["RESULT", "OVER"]) and last_res.spin_kind != "none"
	if spun:
		_draw_spin_text(c, x0)
		return
	if not last_res.is_empty() and g.phase in ["RESULT", "OVER"] and last_res.spin_kind == "none":
		Px.text(c, x0, 6, "NO SPIN", 2, Px.DIM)
		Px.text(c, x0, 28, "TURNOVER: a hand %d+ classes higher." % QGame.PICK_SIX_GAP if last_res.turnover else "Identical hands: nothing moves.", 0, Px.FG)
		return
	if not g.player_off:
		# you are on defense: the suit of your call sets the style
		Px.text(c, x0, 4, "YOUR DEFENSE", 1, Px.GOLD)
		Px.text(c, x0, 22, "The SUIT of the card you call with", 0, Px.FG)
		Px.text(c, x0, 34, "is your defensive style:", 0, Px.FG)
		for i in 4:
			var style: String = QGame.STYLE_OF_SUIT[i]
			Px.text(c, x0, 52 + i * 14, "%s" % SUIT_NAMES[i], 1, Px.DIM)
			Px.text(c, x0 + 48, 52 + i * 14, "= %s" % style, 1, QCardView.STYLE_COLORS[style])
		Px.text(c, x0, 112, "Their face-up cards show what they", 0, Px.DIM)
		Px.text(c, x0, 124, "fear (-): call the style they hate.", 0, Px.DIM)
		Px.text(c, x0, 136, "A joker calls BALANCED.", 0, Px.LINE)
		return
	if not g.has_selection():
		Px.text(c, x0, 4, "SELECT A PLAY", 2, Px.GOLD)
		Px.text(c, x0, 24, "Tap one of the gold-edged", 0, Px.FG)
		Px.text(c, x0, 36, "cards. Your best five cards", 0, Px.FG)
		Px.text(c, x0, 48, "are the ones you may run.", 0, Px.FG)
		Px.text(c, x0, 70, "The wheel shows the play's", 0, Px.DIM)
		Px.text(c, x0, 82, "odds once you choose, and", 0, Px.DIM)
		Px.text(c, x0, 94, "SNAP unlocks.", 0, Px.DIM)
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


func _draw_spin_text(c: Control, x0: float) -> void:
	var gain: bool = last_res.spin_kind == "gain"
	var off_you: bool = last_res.player_off
	var good_for_me: bool = gain == off_you                      # their gain is bad for you, their loss is good
	var col := Px.GREEN if good_for_me else Px.RED
	var head := ("WIN WHEEL" if gain else "LOSS WHEEL") if off_you else ("THEIR GAIN" if gain else "THEIR LOSS")
	Px.text(c, x0, 6, head, 2, col)
	var owner := "YOUR" if (gain == off_you) else "THEIR"       # the hand whose multiplier applies
	Px.text(c, x0, 24, "yards x %s hand" % owner, 1, Px.DIM)
	Px.text(c, x0, 44, "x%.1f" % last_res.mult, 3, Px.GOLD)
	Px.text(c, x0 + 70, 50, "%s" % Poker.CAT_NAMES[int(last_res.my_cat if owner == "YOUR" else last_res.their_cat)], 0, Px.DIM)
	if wheel_done or (g.phase in ["RESULT", "OVER"] and not suspense):
		Px.text(c, x0, 78, "%d x %.1f" % [last_res.spin, last_res.mult], 2, Px.FG)
		Px.text(c, x0, 98, "%+d YDS" % last_res.yards, 3, col)
	else:
		Px.text(c, x0, 84, "spinning...", 1, Px.DIM)
		Px.text(c, x0, 122, "tap the wheel to skip", 0, Px.LINE)


## Compact play card for the focused hand card, shown where the wheel will appear.
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


## The strip under the wheel: what is being called. It tells you to choose until you have.
func _draw_call(c: Control) -> void:
	if g.phase != "BET" and not suspense:
		return
	Px.box(c, Rect2(0, 0, 344, 28), Px.PANEL, Px.GOLD if g.has_selection() else Px.LINE)
	if not g.has_selection():
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		Px.text_center(c, 172, 10, "SELECT A PLAY" if g.player_off else "SELECT YOUR DEFENSIVE CALL", 2, Color(Px.GOLD, blink))
		return
	var card: Dictionary = g.my_lead()
	var info: Dictionary = card.get("info", {})
	if g.player_off:
		Px.text(c, 8, 1, "PLAY CALLED", 0, Px.DIM)
		var fam: String = "WILD" if card.get("joker", false) else card.suit_name
		Px.text(c, 8, 11, "%s %s" % [card.label, card.name], 1, Px.GOLD)
		Px.text(c, 8 + Px.text_width("%s %s" % [card.label, card.name], 1) + 10, 12, fam, 0, Px.FG)
		if not info.is_empty():
			Px.text_right(c, 336, 12, "+%s  -%s" % [info.strong, info.weak], 0, Px.GREEN)
	else:
		var style: String = g.style_in_play()
		Px.text(c, 8, 1, "DEFENSIVE CALL", 0, Px.DIM)
		Px.text(c, 8, 11, style, 1, QCardView.STYLE_COLORS[style])
		Px.text(c, 8 + Px.text_width(style, 1) + 10, 12, "via %s %s" % [card.label, card.name], 0, Px.FG)


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
		var off_you: bool = r.player_off
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
		var who := "" if off_you else "THEY "
		if r.spin_kind == "gain":
			spin_txt = "%sWHEEL %d x %.1f = +%d YDS" % [who, r.spin, r.mult, r.yards]
			scol = Px.GREEN if off_you else Px.RED
		elif r.spin_kind == "loss":
			spin_txt = "%sWHEEL %d x %.1f = %d YDS" % [who, r.spin, r.mult, r.yards]
			scol = Px.RED if off_you else Px.GREEN
		elif r.turnover:
			spin_txt = "NO SPIN   turnover"
			scol = Px.RED if off_you else Px.GREEN
		_row(c, 19, "SPIN", spin_txt, scol)
		# row 3: where that leaves the drive
		var nxt := ""
		var ncol := Px.FG
		match evt:
			"TOUCHDOWN":
				nxt = "TOUCHDOWN! %s" % ("YOU SCORE" if off_you else "THE CPU SCORES")
				ncol = Px.GOLD if off_you else Px.RED
			"PICK SIX", "TURNOVER":
				nxt = "TURNOVER"
				ncol = Px.RED if off_you else Px.GREEN
			"SAFETY":
				nxt = "SAFETY"
				ncol = Px.RED if off_you else Px.GREEN
			"TURNOVER ON DOWNS":
				nxt = "STOPPED ON 4TH DOWN"
				ncol = Px.RED if off_you else Px.GREEN
			"PUSH":
				nxt = "REPLAY THE DOWN"
			_:
				var dn: String = ["", "1ST", "2ND", "3RD", "4TH"][int(g.st.down)]
				nxt = ("FIRST DOWN, " if evt == "FIRST DOWN" else "") + "%s & %d" % [dn, int(round(g.st.distance))]
				ncol = Px.GOLD if evt == "FIRST DOWN" else Px.FG
		_row(c, 35, "NEXT", nxt, ncol)
		var net: int = r.yards
		var good: bool = (net > 0) == off_you
		_row(c, 51, "NET", ("%+d YDS" % net if off_you else "THEY %+d YDS" % net) if net != 0 else "NO CHANGE", Px.DIM if net == 0 else (Px.GREEN if good else Px.RED))
	else:
		var y := 4
		var head := "SHOWDOWN..." if suspense else "RECENT"
		if g.phase == "BET" and not suspense:
			Px.text(c, 6, 4, "YOUR HAND" if g.has_selection() else "SELECT BELOW", 0, Px.DIM)
			if g.has_selection():
				var lead: Dictionary = g.my_lead()
				Px.text(c, 6, 15, "%s  %s" % [lead.label, lead.name], 3, Px.GOLD)
				var hint := "tap another gold card to switch (or press P)" if g.eligible().size() > 1 else "only this card can be called"
				Px.text(c, 6, 38, hint, 0, Px.DIM)
				Px.text(c, 6, 52, "see its strengths and routes with INFO", 0, Px.DIM)
			else:
				Px.text(c, 6, 15, "NO CARD SELECTED", 3, Px.RED)
				Px.text(c, 6, 38, "SNAP stays locked until you choose.", 0, Px.DIM)
			return
		Px.text(c, 6, y, head, 1, Px.GOLD)
		y += 18
		for line in g.log.slice(0, 4) if g.phase == "BET" or g.phase == "DRAW" else g.log.slice(1, 3):
			Px.text(c, 6, y, String(line).to_upper(), 0, Px.DIM)
			y += 13


func _draw_overlay(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	var result := g.outcome()
	var col := Px.GREEN if result == "WIN" else (Px.RED if result == "LOSS" else Px.GOLD)
	Px.box(c, Rect2(30, 200, 300, 254), Px.PANEL, col)
	Px.text_center(c, 180, 222, "GAME OVER", 3, Px.GOLD)
	Px.text_center(c, 180, 256, "YOU WIN" if result == "WIN" else ("YOU LOSE" if result == "LOSS" else "TIE GAME"), 3, col)
	Px.text_center(c, 180, 286, "YOU %d   -   CPU %d" % [g.tds, g.cpu_tds], 2, Px.FG)
	Px.text_center(c, 180, 310, "%+d NET YARDS ON OFFENSE" % g.yards_total, 1, Px.GREEN if g.yards_total >= 0 else Px.RED)
	Px.text_center(c, 180, 328, "%d DRIVES   %d SNAPS" % [QGame.total_drives(), g.history.size()], 1, Px.DIM)
	if g.best_cat >= 0:
		Px.text_center(c, 180, 346, "BEST HAND WON: %s" % Poker.CAT_NAMES[g.best_cat], 0, Px.DIM)


func _draw_pause(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.8))
	Px.box(c, Rect2(60, 200, 240, 196), Px.PANEL, Px.GOLD)
	Px.text_center(c, 180, 222, "PAUSED", 3, Px.GOLD)
	Px.text_center(c, 180, 246, "YOU %d  CPU %d   DRIVE %d/%d" % [g.tds, g.cpu_tds, g.drive_no, QGame.total_drives()], 0, Px.DIM)


# ------------------------------------------------------------------ state refresh
func _refresh() -> void:
	var phase := g.phase
	btn_draw.visible = phase == "DRAW"
	btn_stand.visible = phase == "DRAW"
	btn_draw.set_label("DRAW %d" % marked.size() if marked.size() > 0 else "DRAW 0")
	btn_draw.disabled = marked.is_empty()
	var snap_up: bool = phase == "BET" and not suspense and not paused
	btn_show.visible = snap_up
	btn_show.disabled = not g.has_selection()                 # unselectable until a play is chosen
	btn_next.visible = phase == "RESULT" and not suspense
	btn_next.shine = btn_next.visible
	if phase == "RESULT":
		btn_next.set_label("NEXT DRIVE" if last_res.get("drive_over", false) else "NEXT DOWN")
	var finished: bool = phase == "OVER" and not suspense
	overlay.visible = finished
	btn_new.visible = finished
	btn_new_menu.visible = finished
	btn_menu.visible = phase != "OVER"
	btn_info.visible = phase == "BET" and g.has_selection()
	pause_panel.visible = paused
	for b in [btn_resume, btn_restart, btn_quit]:
		b.visible = paused
	if phase == "OVER" and not committed:
		commit_run()
	wheel.visible = (phase == "BET" or phase == "RESULT") and not paused
	if phase == "BET" and not suspense:
		_preview_wheel()
	for p in [hud, tells_panel, hand_info, bet_panel, call_panel, result_panel, overlay]:
		p.queue_redraw()
	_sync_cards()


# ------------------------------------------------------------------ input
func _on_hand_tapped(i: int) -> void:
	if paused or detail.visible:
		return
	if g.phase == "BET" and not suspense:
		if g.eligible().has(i):
			if i != g.play_idx:
				Sfx.play("select")
			g.set_play(i)                              # explicitly choose which card of the made hand to use
			_refresh()
		return
	if g.phase != "DRAW":
		return
	focus_idx = i
	if marked.has(i):
		marked.erase(i)
	elif marked.size() < QGame.MAX_DISCARDS:
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
	if g.phase in ["BET", "RESULT"] and not paused and g.has_selection():
		detail.show_card(g.my_lead())


func _on_draw() -> void:
	if g.phase != "DRAW":
		return
	_do_draw(marked.duplicate())


func _on_stand() -> void:
	if g.phase == "DRAW":
		_do_draw([])


## Discards fly off, replacements fly in from the shoe and flip, then the computer's face-up cards turn over.
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
	for i in QGame.HAND_SIZE:
		if before[i] != g.theirs[i]:                  # the computer swapped this one: a quick rattle, still face-down
			def_views[i].set_card(g.theirs[i])
			def_views[i].shake(2.0)
	_refresh()


func _on_show() -> void:
	if g.phase != "BET" or suspense or not g.has_selection():
		return
	pre_st = g.st.duplicate(true)
	last_res = g.showdown()
	suspense = true
	stage = "flip"
	suspense_t = 2.1                              # the cards flip, then the versus banner plays out
	_refresh()
	_show_versus()


## Banner comparing the two hands, ending in a WIN / LOSS stamp (from your side).
func _show_versus() -> void:
	if versus != null and is_instance_valid(versus):
		versus.queue_free()
	var r := last_res
	var gap: int = absi(int(r.their_cat) - int(r.my_cat))
	var note := ""
	if r.win == 0:
		note = "identical hands, nobody moves"
	elif r.turnover:
		note = "%s by %d classes: TURNOVER, no spin" % ["you win" if r.win == 1 else "they win", gap]
	else:
		var how := "same class, higher cards" if gap == 0 else "by %d class%s" % [gap, "" if gap == 1 else "es"]
		note = "%s %s: %s wheel x%.1f" % ["you win" if r.win == 1 else "they win", how, "gain" if r.spin_kind == "gain" else "loss", r.mult]
	versus = VersusFx.new(Poker.CAT_NAMES[int(r.my_cat)], Poker.multiplier(int(r.my_cat)), Poker.CAT_NAMES[int(r.their_cat)],
			Poker.multiplier(int(r.their_cat)), int(r.win), note)
	fx_layer.add_child(versus)


## The wheel for this snap: the real curve against the real hidden style, win or loss. It lives in the bottom panel.
func _start_wheel() -> void:
	if versus != null and is_instance_valid(versus):
		versus.finish()
	stage = "spin"
	wheel_done = false
	_wheel_key = ""
	var play: Dictionary = last_res.play
	var th := DefContext.apply(play.theta, last_res.style)
	if last_res.spin_kind == "gain":
		var goal := _wheel_goal(float(pre_st.yardline_to_opponent_goal), float(last_res.mult))
		wheel_slices = WheelView.slices_for([th], goal)
	else:
		wheel_slices = WheelView.loss_slices_for([th])
	wheel.set_slices(wheel_slices)
	wheel.visible = true
	bet_panel.queue_redraw()
	wheel.landed.connect(_on_wheel_landed, CONNECT_ONE_SHOT)
	wheel.spin_to(wheel_slices, WheelView.category_for(wheel_slices, int(last_res.spin)), 2.8)


## Wheel yards that would carry the ball into the end zone once the hand multiplier is applied.
func _wheel_goal(yards_left: float, mult: float) -> int:
	return maxi(1, int(ceil(yards_left / maxf(mult, 0.1))))


## Before the snap the wheel shows the selected play's odds if you win, averaged over the four defense styles. With no
## selection (or on defense, where you cannot see their play) the ring stays empty.
func _preview_wheel() -> void:
	var key := "none"
	if g.player_off and g.has_selection():
		key = "%d|%d|%.0f" % [g.play_idx, g.drive_no * 10 + int(g.st.down), g.st.yardline_to_opponent_goal]
	if key == _wheel_key:
		return
	_wheel_key = key
	if key == "none":
		wheel.set_slices([])
	else:
		var lead: Dictionary = g.my_lead()
		var thetas: Array = []
		for st in DefContext.STYLES:
			thetas.append(DefContext.apply(lead.theta, st))
		wheel_slices = WheelView.slices_for(thetas, _wheel_goal(float(g.st.yardline_to_opponent_goal), g.my_mult()))
		wheel.set_slices(wheel_slices)
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


## The verdict lands: the field moves, the played card reacts, the yards float up, big results get confetti.
func _fx_result() -> void:
	suspense = false
	stage = ""
	if versus != null and is_instance_valid(versus):
		versus.finish()
	var r := last_res
	field.animate_result(pre_st, g.st, r)
	_refresh()
	var off_you: bool = r.player_off
	if g.has_selection():
		var lead: QCardView = my_views[g.play_idx]
		if r.win == 1:
			lead.pop()
			lead.flash(Px.GOLD)
		elif r.win == -1:
			lead.shake(6.0)
			lead.flash(Px.RED)
	var evt: String = r.event
	match evt:
		"TOUCHDOWN": Sfx.play("touchdown" if off_you else "lose")
		"FIRST DOWN": Sfx.play("first_down" if off_you else "turnover")
		"PICK SIX", "SAFETY", "TURNOVER ON DOWNS": Sfx.play("turnover" if off_you else "first_down")
	var net: int = r.yards
	var good: bool = (net > 0) == off_you
	if g.phase == "OVER":
		Sfx.play("win" if g.outcome() == "WIN" else "lose", 0.8)
	elif net != 0:
		Sfx.play("chip_up" if good else "chip_down", 0.35)
	var label := ("%+d YDS" % net if off_you else "THEY %+d YDS" % net) if net != 0 else "NO CHANGE"
	_float(label, Px.DIM if net == 0 else (Px.GREEN if good else Px.RED), 3, 316)
	if evt == "TOUCHDOWN":
		_float("TOUCHDOWN!" if off_you else "CPU TOUCHDOWN", Px.GOLD if off_you else Px.RED, 2, 292)
		var ez_x := 336.0 if off_you else 24.0
		fx_layer.add_child(Burst.new(Vector2(ez_x, 110), 70, [Px.GOLD, Color.WHITE, Px.RED, Px.ROYAL], 230.0))
		if off_you:
			fx_layer.add_child(Burst.new(Vector2(180, 300), 40, [Px.GOLD, Color.WHITE], 190.0))
		_shake_screen(3.0)
	elif r.win == 1 and absi(net) >= 25:
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
			if stage == "flip" and last_res.spin_kind != "none":
				_start_wheel()
			elif stage != "spin":
				_fx_result()
	if g.phase == "BET":
		call_panel.queue_redraw()                  # the SELECT prompt blinks


func _on_next() -> void:
	if g.phase != "RESULT" or suspense:
		return
	var drive_over: bool = last_res.get("drive_over", false)
	g.next()
	marked = []
	focus_idx = -1
	field.attack_left = not g.player_off
	field.set_state(g.st)
	_rebuild_cards()
	_refresh()
	if drive_over:                                    # the ball changes sides
		_float("YOUR BALL: OFFENSE" if g.player_off else "CPU BALL: YOU DEFEND", Px.GOLD if g.player_off else Px.RED, 2, 292)


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
	focus_idx = -1
	_wheel_key = ""
	field.attack_left = not g.player_off
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
	if e.keycode == KEY_P and g.phase == "BET" and not suspense:
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
	elif e.keycode >= KEY_1 and e.keycode <= KEY_9:
		var i: int = e.keycode - KEY_1
		if i < QGame.HAND_SIZE:
			_on_hand_tapped(i)
