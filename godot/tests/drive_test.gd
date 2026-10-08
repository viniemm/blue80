extends SceneTree
## Headless drive smoke test: godot --headless --path godot -s tests/drive_test.gd

func _init() -> void:
	var D := GameData.load_all()
	var drive := Drive.new(D, 7)
	var endings := {}
	var points := 0
	var plays := 0
	var combo_counts := {}
	var n := 300
	for d in n:
		drive.new_drive(d > 0)
		var guard := 0
		while not drive.over and guard < 40:
			guard += 1
			var st: Dictionary = drive.state
			var out: Dictionary
			if st.down == 4:
				out = drive.kick("FG" if st.yardline_to_opponent_goal <= 38.0 else "PNT")
			else:
				# occasionally discard to exercise that path
				if drive.can_discard() and drive.rng.randf() < 0.1:
					drive.discard([drive.hand[0].uid, drive.hand[1].uid])
				var card: Dictionary = drive.hand[drive.rng.randi_range(0, drive.hand.size() - 1)]
				out = drive.play_card(card)
			for c in out.combos:
				combo_counts[c.name] = int(combo_counts.get(c.name, 0)) + 1
			plays += 1
			assert(drive.hand.size() <= Drive.HAND_SIZE)
		var title: String = drive.summary.get("title", "?")
		endings[title] = int(endings.get(title, 0)) + 1
		points += int(drive.summary.get("points", 0))
	print("drives: %d  avg plays: %.1f  avg points: %.2f" % [n, float(plays) / n, float(points) / n])
	print("endings: ", endings)
	print("combos: ", combo_counts)
	# preview sanity
	drive.new_drive(true)
	var card: Dictionary = drive.hand[0]
	var t0 := Time.get_ticks_msec()
	var pv := drive.preview(card)
	print("preview ", card.name, " took ", Time.get_ticks_msec() - t0, " ms: ", pv.slices, " mean ", snappedf(pv.mean, 0.1))
	print("curve: ", pv.curve.tier_probs)
	quit()
