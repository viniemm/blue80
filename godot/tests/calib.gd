extends SceneTree
## Headless calibration: godot --headless --path godot -s tests/calib.gd
## Calibration targets: IZS ~+5.6, SLN ~78% complete / +8, 4VT ~+14 vs Cover 3 Match.

func _init() -> void:
	var D := GameData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var st := {"period": 1, "clock_seconds": 900, "down": 1, "distance": 10.0, "yardline_to_opponent_goal": 75.0,
			"possession_team": "EAST"}
	for def_code in ["C3M", "ZB0", "PRV", "GLS"]:
		print("== vs ", def_code)
		for code in ["IZS", "PWO", "SLN", "MSH", "SAL", "4VT", "PAB"]:
			var n := 1500
			var total := 0.0
			var neg := 0
			var counts := {}
			for i in n:
				var r: Dictionary = Sim.resolve_play(st, D.plays[code], D.defense[def_code], D.east, D.west, D.matrix, {}, rng)
				total += r.result.yards
				if r.result.yards < 0:
					neg += 1
				counts[r.result.outcome] = counts.get(r.result.outcome, 0) + 1
			var summary := {}
			for k in counts:
				summary[k] = snappedf(counts[k] / float(n), 0.001)
			print("%s mean %+.1f neg %d%%  %s" % [code, total / n, 100 * neg / n, summary])
	quit()
