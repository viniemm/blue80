extends SceneTree
## Card info: a hand with a joker, the focus panel while drawing, play selection while betting, and the full card popup.
##   godot --path godot --resolution 540x960 -s tests/cards_shots.gd -- <out_dir>

var out_dir := "user://"


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _init() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out_dir = OS.get_cmdline_user_args()[0]
	var q: QMain = load("res://scenes/quant.tscn").instantiate()
	root.add_child(q)
	await _wait(1.5)
	var all := Deck52.build_all()
	# two aces, a joker, a seven and a three: the joker makes trips, so the aces and the joker may all be played
	q.g.mine = [all[13 + 12], all[26 + 12], all[52], all[39 + 5], all[2]]
	q.g.my_eval = Poker.evaluate(q.g.mine)
	q.g.play_idx = q.g.my_eval.lead_idx
	print("hand: ", Poker.CAT_NAMES[q.g.my_eval.cat], "  eligible ", q.g.eligible(), "  wild as ", q.g.my_eval.wild)
	q._rebuild_cards()
	await _wait(1.6)
	q._on_hover(3)
	await _wait(0.2)
	_shot("c1_draw_focus")
	q._on_stand()
	await _wait(2.0)

	await _wait(0.3)
	_shot("c2_bet_choose")
	var other: int = q.g.eligible()[0] if q.g.eligible()[0] != q.g.play_idx else q.g.eligible()[1]
	q._on_hand_tapped(other)
	await _wait(0.4)
	_shot("c3_play_changed")
	# a real tap on the (i) badge of card 0 must open the popup
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(54, 58)
	q.my_views[0]._gui_input(ev)
	ev = ev.duplicate()
	ev.pressed = false
	q.my_views[0]._gui_input(ev)
	print("badge tap opened popup: ", q.detail.visible, " card ", q.detail.card.get("name"))
	q.detail.visible = false
	q._on_inspect(2)
	await _wait(0.3)
	_shot("c4_joker_detail")
	q.detail.visible = false
	q._on_inspect(0)
	await _wait(0.3)
	_shot("c5_ace_detail")
	quit()
