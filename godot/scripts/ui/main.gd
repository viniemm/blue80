extends Control
## Blue 80 card drive: assembles the views and runs the snap sequence.

class DrawPanel extends Control:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


const HAND_Y := 388
const SLICE_MIN := 0.5

var D: Dictionary
var drive: Drive
var field: FieldView
var wheel: WheelView
var hud: DrawPanel
var jokers_panel: DrawPanel
var curve_panel: DrawPanel
var info_panel: DrawPanel
var result_panel: DrawPanel
var def_panel: DrawPanel
var log_panel: DrawPanel
var ticker_panel: DrawPanel
var overlay: DrawPanel
var btn_discard: PxButton
var btn_snap: PxButton
var btn_fg: PxButton
var btn_punt: PxButton
var btn_next: PxButton
var card_views: Dictionary = {}
var hand_layer: Control

var selected_uid := -1
var preview: Dictionary = {}
var discard_mode := false
var marked: Array = []
var busy := false
var total_points := 0
var drive_no := 1
var actual_tier := 0
var def_text := ""
var result_text := ""
var result_color := Px.FG
var ticker_text := ""
var ticker_color := Px.GOLD
var hint_text := "TAP A CARD, THEN SNAP"


func _ready() -> void:
	D = GameData.load_all()
	drive = Drive.new(D)
	drive.new_drive(false)
	_build_ui()
	_rebuild_hand()
	_select(drive.hand[0].uid)


func _panel(rect: Rect2, fn: Callable) -> DrawPanel:
	var p := DrawPanel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.fn = fn
	add_child(p)
	return p


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
	ticker_panel = _panel(Rect2(0, 32 + 90, 360, 30), _draw_ticker)
	jokers_panel = _panel(Rect2(0, 154, 360, 46), _draw_jokers)
	curve_panel = _panel(Rect2(4, 204, 216, 106), _draw_curve)
	wheel = WheelView.new()
	wheel.position = Vector2(226, 204)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wheel)
	result_panel = _panel(Rect2(222, 338, 136, 16), _draw_result)
	info_panel = _panel(Rect2(4, 314, 216, 54), _draw_info)
	def_panel = _panel(Rect2(0, 370, 360, 16), _draw_def)
	hand_layer = Control.new()
	hand_layer.size = Vector2(360, 640)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)

	btn_discard = PxButton.new("DISCARD", Px.ROYAL, Vector2(104, 30))
	btn_discard.position = Vector2(4, 502)
	btn_discard.pressed.connect(_on_discard)
	add_child(btn_discard)
	btn_snap = PxButton.new("SNAP", Px.GOLD, Vector2(140, 30))
	btn_snap.position = Vector2(112, 502)
	btn_snap.pressed.connect(_on_snap)
	add_child(btn_snap)
	btn_fg = PxButton.new("FG", Px.GREEN, Vector2(46, 30))
	btn_fg.position = Vector2(258, 502)
	btn_fg.pressed.connect(_on_kick.bind("FG"))
	add_child(btn_fg)
	btn_punt = PxButton.new("PUNT", Px.DIM, Vector2(48, 30))
	btn_punt.position = Vector2(308, 502)
	btn_punt.pressed.connect(_on_kick.bind("PNT"))
	add_child(btn_punt)
	log_panel = _panel(Rect2(4, 540, 352, 96), _draw_log)

	overlay = _panel(Rect2(0, 0, 360, 640), _draw_overlay)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_next = PxButton.new("NEXT DRIVE", Px.GOLD, Vector2(160, 34))
	btn_next.position = Vector2(100, 380)
	btn_next.pressed.connect(_on_next_drive)
	btn_next.visible = false
	add_child(btn_next)
	_refresh_buttons()


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
	var st := drive.state
	var dn: String = ["", "1ST", "2ND", "3RD", "4TH"][int(st.down)]
	Px.text(c, 6, 7, "%s & %d" % [dn, int(round(st.distance))], 3, Px.GOLD)
	Px.text_center(c, 214, 7, _spot(st.yardline_to_opponent_goal), 1, Px.FG)
	Px.text_right(c, 354, 1, "DRIVE %d" % drive_no, 0, Px.DIM)
	Px.text_right(c, 354, 14, "PTS %d" % total_points, 0, Px.GOLD)


func _draw_ticker(c: Control) -> void:
	if ticker_text == "":
		return
	c.draw_rect(Rect2(0, 0, 360, 30), Color(0, 0, 0, 0.85))
	c.draw_rect(Rect2(0, 0, 360, 1), ticker_color)
	Px.text_center(c, 180, 7, ticker_text, 3, ticker_color)


func _draw_jokers(c: Control) -> void:
	for i in 3:
		var x := 4 + i * 119
		var id: String = drive.jokers[i]
		var j: Dictionary = Cards.JOKERS[id]
		Px.box(c, Rect2(x, 2, 114, 42), Px.PANEL2, Px.GOLD.darkened(0.4))
		c.draw_rect(Rect2(x + 4, 8, 4, 4), Px.GOLD)
		Px.text(c, x + 11, 4, j.name, 1, Px.GOLD)
		Px.text(c, x + 5, 22, j.text, 0, Px.DIM)
		if j.get("when", "") != "":
			var active := false
			if j.when == "late_down":
				active = drive.state.down >= 3
			else:
				active = drive.state.yardline_to_opponent_goal <= 20.0
			Px.text_right(c, x + 110, 29, "ON" if active else "WAIT", 0, Px.GREEN if active else Px.LINE)


func _draw_curve(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 216, 106), Px.PANEL, Px.LINE)
	Px.text(c, 6, 3, "DEFENSE PLAYS ONE OF", 1, Px.GOLD)
	var probs: Dictionary = preview.get("curve", {}).get("tier_probs", {})
	for t in range(1, 6):
		var y := 21 + (t - 1) * 16
		var p: float = float(probs.get(t, 0.0))
		if actual_tier == t:
			c.draw_rect(Rect2(3, y - 1, 210, 15), Color(Px.GOLD, 0.25))
			c.draw_rect(Rect2(3, y - 1, 210, 15), Px.GOLD, false, 1.0)
		Px.text(c, 7, y, str(t), 1, Px.DIM)
		Px.text(c, 18, y, String(D.tier_labels[str(t)]).to_upper(), 1, Px.FG)
		var w := int(p * 92.0)
		c.draw_rect(Rect2(82, y + 2, 92, 9), Px.LINE.darkened(0.3))
		c.draw_rect(Rect2(82, y + 2, w, 9), Px.GOLD)
		Px.text_right(c, 210, y, "%d%%" % int(round(p * 100.0)), 1, Px.GOLD)


func _draw_info(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 216, 54), Px.PANEL, Px.LINE)
	if preview.is_empty():
		return
	Px.text(c, 6, 3, "EXP %+.1f YDS  1ST %d%%  TO %d%%" % [preview.mean, int(round(preview.p_fd * 100.0)),
			int(round(preview.p_to * 100.0))], 1, Px.GREEN)
	var y := 19
	for cb in preview.combos.slice(0, 2):
		Px.text(c, 6, y, cb.name, 1, Px.GOLD)
		Px.text(c, 12 + Px.text_width(cb.name, 1), y + 2, String(cb.text).left(28), 0, Px.DIM)
		y += 15
	if preview.combos.is_empty():
		var why: Array = preview.curve.reasons
		Px.text(c, 6, 19, "NO COMBO", 1, Px.DIM)
		if not why.is_empty():
			Px.text(c, 6, 35, String(why[0]).to_upper().left(36), 0, Px.DIM)


func _draw_result(c: Control) -> void:
	if result_text != "":
		Px.text_center(c, 68, 1, result_text, 1, result_color)


func _draw_def(c: Control) -> void:
	if def_text != "":
		Px.text_center(c, 180, 1, def_text, 1, Px.GOLD)
	else:
		Px.text_center(c, 180, 1, hint_text, 1, Px.DIM)


func _draw_log(c: Control) -> void:
	Px.box(c, Rect2(0, 0, 352, 96), Px.PANEL, Px.LINE)
	var y := 5
	for line in drive.log.slice(0, 6):
		Px.text(c, 6, y, String(line).to_upper(), 1, Px.FG if y == 5 else Px.DIM)
		y += 15


func _draw_overlay(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.78))
	if drive.summary.is_empty():
		return
	var s := drive.summary
	Px.box(c, Rect2(30, 190, 300, 250), Px.PANEL, Px.GOLD)
	Px.text_center(c, 180, 212, s.title, 3, Px.GOLD)
	Px.text_center(c, 180, 250, "+%d POINTS" % s.points if s.points > 0 else "NO POINTS", 3, Px.GREEN if s.points > 0 else Px.DIM)
	Px.text_center(c, 180, 290, "%d PLAYS   %d YARDS" % [s.plays, s.yards], 1, Px.FG)
	Px.text_center(c, 180, 322, "TOTAL %d" % total_points, 3, Px.FG)


# ------------------------------------------------------------------ hand & selection
func _rebuild_hand() -> void:
	for v in card_views.values():
		v.queue_free()
	card_views = {}
	for i in drive.hand.size():
		var card: Dictionary = drive.hand[i]
		var v := CardView.new(card)
		v.position = Vector2(5 + i * 70, HAND_Y + 8)
		v.tapped.connect(_on_card_tapped)
		hand_layer.add_child(v)
		card_views[card.uid] = v
	_sync_cards()


func _sync_cards() -> void:
	for uid in card_views:
		var v: CardView = card_views[uid]
		v.selected = (uid == selected_uid) and not discard_mode
		v.marked = discard_mode and marked.has(uid)
		var y := HAND_Y + (0 if v.selected else 8)
		v.position.y = y


func _select(uid: int) -> void:
	selected_uid = uid
	var card := _card_by_uid(uid)
	if card.is_empty():
		return
	preview = drive.preview(card)
	field.set_play(D.plays[card.code])
	wheel.set_slices(preview.slices)
	result_text = ""
	actual_tier = 0
	def_text = ""
	_sync_cards()
	_redraw_all()


func _card_by_uid(uid: int) -> Dictionary:
	for c in drive.hand:
		if c.uid == uid:
			return c
	return {}


func _redraw_all() -> void:
	for p in [hud, jokers_panel, curve_panel, info_panel, result_panel, def_panel, log_panel, ticker_panel, overlay]:
		p.queue_redraw()
	_refresh_buttons()


func _refresh_buttons() -> void:
	var st := drive.state
	btn_snap.disabled = busy or drive.over or discard_mode
	btn_discard.disabled = busy or drive.over or (not drive.can_discard() and not discard_mode)
	if discard_mode:
		btn_discard.set_label("CONFIRM %d" % marked.size() if marked.size() > 0 else "CANCEL")
		hint_text = "TAP UP TO 3 CARDS TO SWAP"
	else:
		btn_discard.set_label("DISCARD %d" % drive.discards_left)
		hint_text = "TAP A CARD, THEN SNAP"
	var fourth: bool = int(st.down) == 4 and not drive.over
	btn_fg.visible = fourth
	btn_punt.visible = fourth
	btn_fg.disabled = busy
	btn_punt.disabled = busy
	def_panel.queue_redraw()


# ------------------------------------------------------------------ input
func _on_card_tapped(card: Dictionary) -> void:
	if busy or drive.over:
		return
	if discard_mode:
		if marked.has(card.uid):
			marked.erase(card.uid)
		elif marked.size() < Drive.MAX_DISCARD:
			marked.append(card.uid)
		_sync_cards()
		_refresh_buttons()
	else:
		_select(card.uid)


func _on_discard() -> void:
	if busy or drive.over:
		return
	if not discard_mode:
		discard_mode = true
		marked = []
	else:
		if marked.size() > 0:
			drive.discard(marked)
		discard_mode = false
		marked = []
		_rebuild_hand()
		_select(drive.hand[0].uid)
		return
	_sync_cards()
	_refresh_buttons()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	if e.keycode == KEY_ENTER or e.keycode == KEY_SPACE:
		_on_snap()
	elif e.keycode >= KEY_1 and e.keycode <= KEY_5 and not busy:
		var i: int = e.keycode - KEY_1
		if i < drive.hand.size():
			_on_card_tapped(drive.hand[i])
	elif e.keycode == KEY_D:
		_on_discard()


# ------------------------------------------------------------------ the snap
func _on_snap() -> void:
	if busy or drive.over or discard_mode:
		return
	var card := _card_by_uid(selected_uid)
	if card.is_empty():
		return
	busy = true
	_refresh_buttons()
	var slices: Array = preview.slices.duplicate(true)
	var out := drive.play_card(card)
	await _present(out, slices)


func _on_kick(kind: String) -> void:
	if busy or drive.over or int(drive.state.down) != 4:
		return
	busy = true
	_refresh_buttons()
	field.set_play(D.plays["FG" if kind == "FG" else "PNT"])
	var pv := drive.preview_kick(kind)
	var slices: Array = pv.slices.duplicate(true)
	var out := drive.kick(kind)
	await _present(out, slices)


func _present(out: Dictionary, slices: Array) -> void:
	var r: Dictionary = out.result
	ticker_text = ""
	result_text = ""
	actual_tier = int(out.def.tier)
	def_text = "DEFENSE: %s (TIER %d)" % [String(out.def.name).to_upper(), actual_tier]
	field.reveal(actual_tier)
	_redraw_all()
	await get_tree().create_timer(0.5).timeout
	var cat: String = out.cat
	var have := false
	for s in slices:
		if s.category == cat:
			have = true
	if not have:
		slices.append({"category": cat, "pct": SLICE_MIN})
		slices.sort_custom(func(a, b): return Evaluator.ORDER.find(a.category) < Evaluator.ORDER.find(b.category))
	await wheel.spin_to(slices, cat)
	result_text = "%s %+d" % [WheelView.LABELS.get(cat, cat), r.yards] if cat not in ["PUNT", "FIELD_GOAL_GOOD", "FIELD_GOAL_MISSED"] \
		else String(WheelView.LABELS.get(cat, cat))
	result_color = WheelView.COLORS.get(cat, Px.FG)
	_redraw_all()
	field.animate(out)
	await field.anim_done
	var bad: bool = r.turnover or cat == "LOSS"
	var good: bool = r.touchdown or r.first_down or cat in ["BIG_GAIN", "FIELD_GOAL_GOOD"]
	if r.touchdown:
		ticker_text = "TOUCHDOWN!"
	elif r.outcome == "INTERCEPTION":
		ticker_text = "INTERCEPTED!"
	elif r.outcome == "FUMBLE":
		ticker_text = "FUMBLE!"
	elif r.first_down:
		ticker_text = "FIRST DOWN +%d" % r.yards
	elif cat == "FIELD_GOAL_GOOD":
		ticker_text = "FIELD GOAL IS GOOD!"
	elif cat == "FIELD_GOAL_MISSED":
		ticker_text = "NO GOOD!"
	elif r.outcome in ["PUNT", "TOUCHBACK"]:
		ticker_text = "PUNT"
	else:
		ticker_text = "%s %+d" % [String(r.outcome), r.yards]
	ticker_color = Px.RED if bad else (Px.GREEN if good else Px.GOLD)
	_redraw_all()
	await get_tree().create_timer(0.9).timeout
	ticker_text = ""
	if drive.over:
		total_points += int(drive.summary.points)
		overlay.visible = true
		btn_next.visible = true
		busy = false
		_redraw_all()
		return
	field.set_state(drive.state)
	busy = false
	discard_mode = false
	marked = []
	_rebuild_hand()
	_select(drive.hand[0].uid)
	_redraw_all()


func _on_next_drive() -> void:
	overlay.visible = false
	btn_next.visible = false
	drive_no += 1
	drive.new_drive(true)
	field.set_state(drive.state)
	actual_tier = 0
	def_text = ""
	result_text = ""
	discard_mode = false
	marked = []
	_rebuild_hand()
	_select(drive.hand[0].uid)
	_redraw_all()
