extends SceneTree
## Exercises discard mode through the UI, then plays to the drive-over overlay.
##   godot --path godot -s tests/discard_test.gd -- <out_dir>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 4:
		await process_frame
	var before: Array = scene.drive.hand.map(func(c): return c.uid)
	scene._on_discard()
	assert(scene.discard_mode)
	scene._on_card_tapped(scene.drive.hand[1])
	scene._on_card_tapped(scene.drive.hand[2])
	scene._on_card_tapped(scene.drive.hand[3])
	scene._on_card_tapped(scene.drive.hand[4])      # 4th mark must be refused (max 3)
	assert(scene.marked.size() == 3)
	await process_frame
	_save("%s/disc_mode.png" % out_dir)
	scene._on_discard()                              # confirm
	await process_frame
	var after: Array = scene.drive.hand.map(func(c): return c.uid)
	var kept := 0
	for u in after:
		if before.has(u):
			kept += 1
	print("discards left: ", scene.drive.discards_left, "  hand size: ", after.size(), "  cards kept: ", kept)
	assert(scene.drive.discards_left == 1 and after.size() == 5)
	# play out the drive quickly by forcing a punt
	scene.drive.state.down = 4
	scene.drive.state.yardline_to_opponent_goal = 60.0
	scene._refresh_buttons()
	await scene._on_kick("PNT")
	await create_timer(0.3).timeout
	_save("%s/disc_over.png" % out_dir)
	print("overlay visible: ", scene.overlay.visible, " next button: ", scene.btn_next.visible, " summary: ", scene.drive.summary)
	scene._on_next_drive()
	await process_frame
	print("new drive hand: ", scene.drive.hand.size(), " drive_no ", scene.drive_no, " discards ", scene.drive.discards_left)
	quit()


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
