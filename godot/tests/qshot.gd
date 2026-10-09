extends SceneTree
## Plays one down of the betting game through the real UI and screenshots each phase.
##   godot --path godot --resolution 540x960 -s tests/qshot.gd -- <out_dir>

func _init() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var scene: Control = load("res://scenes/quant.tscn").instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame
	_save("%s/q1_draw.png" % out_dir)
	scene._on_hand_tapped(1)
	scene._on_hand_tapped(3)
	await process_frame
	scene._on_draw()
	await process_frame
	scene._on_bet_row(2)
	scene._on_stake(1.0)
	await process_frame
	_save("%s/q2_bet.png" % out_dir)
	scene._on_show()
	await process_frame
	await process_frame
	_save("%s/q3_result.png" % out_dir)
	print("result: ", scene.last_res.get("event"), " yards ", scene.last_res.get("yards"), " delta ", scene.last_res.get("delta"))
	quit()


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
