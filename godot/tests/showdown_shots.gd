extends SceneTree
## Plays downs until one hand is won, then captures the wheel spin, the landing, the field animation and the result panel.
##   godot --path godot --resolution 540x960 -s tests/showdown_shots.gd -- <out_dir>

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
	await _wait(1.6)
	for attempt in 12:
		q._on_stand()
		await _wait(1.4)
		q._on_bet_row(2)
		q._on_stake(1.0)
		q._on_show()
		await _wait(0.6)
		_shot("s0a_versus_in" if q.last_res.win == 1 else "s0a_versus_loss_in")
		await _wait(0.9)
		_shot("s0b_versus_stamp" if q.last_res.win == 1 else "s0b_versus_loss_stamp")
		if q.last_res.win == 1:
			await _wait(1.7)
			_shot("s1_wheel_spin")
			await _wait(1.9)
			_shot("s2_wheel_landed")
			await _wait(1.4)
			_shot("s3_field_moving")
			await _wait(1.2)
			_shot("s4_banner")
			await _wait(2.0)
			_shot("s5_settled")
			print("win: ", q.last_res.event, " yards ", q.last_res.yards, " delta ", q.last_res.delta)
			quit()
			return
		await _wait(2.4)
		if attempt == 0:
			_shot("s0_loss_result")
		if q.g.phase == "RESULT":
			q._on_next()
		await _wait(1.0)
	print("no win in 12 tries")
	quit()
