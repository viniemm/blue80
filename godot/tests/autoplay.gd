extends SceneTree
## Plays a whole drive through the real UI and screenshots key moments.
##   godot --path godot -s tests/autoplay.gd -- <out_dir>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 4:
		await process_frame
	var shots := 0
	var guard := 0
	while not scene.drive.over and guard < 14:
		guard += 1
		var st: Dictionary = scene.drive.state
		# prefer a card that makes a combo, to show it off
		var pick: Dictionary = scene.drive.hand[0]
		for c in scene.drive.hand:
			if not scene.drive.combos_for(c).is_empty():
				pick = c
				break
		scene._select(pick.uid)
		await process_frame
		if not scene.drive.combos_for(pick).is_empty() and shots < 1:
			_save("%s/auto_combo.png" % out_dir)
			shots += 1
		if int(st.down) == 4:
			_save("%s/auto_4th.png" % out_dir)
			await scene._on_kick("FG" if st.yardline_to_opponent_goal <= 38.0 else "PNT")
		else:
			await scene._on_snap()
	await create_timer(0.3).timeout
	_save("%s/auto_over.png" % out_dir)
	print("drive over: ", scene.drive.summary, " plays ", guard)
	quit()


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
