extends SceneTree
## Captures one down mid-animation: deal, lift, discard/redeal, defense flips, showdown suspense and verdict.
##   godot --path godot --resolution 540x960 -s tests/anim_shots.gd -- <out_dir>

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
	await _wait(0.45)
	_shot("a1_deal_mid")
	await _wait(1.3)
	q._on_hand_tapped(1)
	q._on_hand_tapped(3)
	await _wait(0.3)
	_shot("a2_lift")
	q._on_draw()
	await _wait(0.3)
	_shot("a3_redeal_mid")
	await _wait(1.6)
	_shot("a4_bet")
	q._on_bet_row(2)
	q._on_show()
	await _wait(0.3)
	_shot("a5_suspense")
	await _wait(1.0)
	_shot("a6_verdict")
	await _wait(1.5)
	_shot("a7_settled")
	print("result: ", q.last_res.get("event"), " delta ", q.last_res.get("delta"), " bank ", q.g.bankroll, " shown ", q.shown_bank)
	quit()
