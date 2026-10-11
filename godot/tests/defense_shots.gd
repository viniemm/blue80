extends SceneTree
## Forces the computer to have the ball and plays one down on defense, screenshotting each step.
##   godot --path godot --resolution 540x960 -s tests/defense_shots.gd -- <out_dir>

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
	await _wait(1.0)
	q.g.player_off = false
	q.g._new_drive()
	q.field.attack_left = true
	q.field.set_state(q.g.st)
	q._rebuild_cards()
	q._refresh()
	await _wait(1.8)
	_shot("d1_draw")
	q._on_stand()
	await _wait(2.2)
	_shot("d2_choose")
	q._on_hand_tapped(q.g.eligible()[0])
	await _wait(0.4)
	_shot("d3_selected")
	q._on_show()
	await _wait(1.0)
	_shot("d4_versus")
	await _wait(3.6)
	_shot("d5_wheel")
	await _wait(3.0)
	_shot("d6_result")
	print("result: ", q.last_res.get("event"), " yards ", q.last_res.get("yards"), " off_you ", q.last_res.get("player_off"))
	quit()
