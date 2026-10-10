extends SceneTree
## Headless rules check: plays whole runs (QGame.DRIVES drives each) with a few play-selection strategies.
##   godot --headless --path godot -s tests/qgame_test.gd -- <runs per policy>
## Reports touchdowns and net yards per run and how drives end, so the wheel, the multipliers and the drive count can be
## tuned. There is no bet: the only decisions are the draw and which card of the made hand runs the play.

var _arng := RandomNumberGenerator.new()


## Always runs the default lead card.
func _policy_auto(_g: QGame) -> void:
	pass


## Cheats: picks the card with the best average yards against the real hidden style. An upper bound on reading the defense.
func _policy_informed(g: QGame) -> void:
	_pick(g, {g.hidden_style(): 1.0})


## Style odds from the two face-up cards, conditioning on the hand being won, then picks the best card on average.
func _policy_analyst(g: QGame) -> void:
	var vis: Array = g.face_up.map(func(i): return g.theirs[i])
	var unseen: Array = g.unseen_pool()
	var counts := {"BLITZ": 0.0, "ZONE": 0.0, "MAN": 0.0, "BALANCED": 0.0}
	var kept := 0.0
	for s in 120:
		var picks: Array = []
		while picks.size() < 3:
			var i := _arng.randi_range(0, unseen.size() - 1)
			if not picks.has(i):
				picks.append(i)
		var ev := Poker.evaluate(vis + [unseen[picks[0]], unseen[picks[1]], unseen[picks[2]]])
		if ev.score >= g.my_eval.score:
			continue
		counts[QGame.STYLE_OF_SUIT[ev.lead_suit]] += 1.0
		kept += 1.0
	var post := {}
	for k in counts:
		post[k] = counts[k] / kept if kept > 0.0 else 0.25
	_pick(g, post)


func _pick(g: QGame, weights: Dictionary) -> void:
	var best := g.play_idx
	var best_v := -1e9
	for i in g.eligible():
		var v := 0.0
		for style in weights:
			v += float(weights[style]) * YardCurve.mean(DefContext.apply(g.mine[i].theta, style))
		if v > best_v:
			best_v = v
			best = i
	g.set_play(best)


func _run(label: String, policy: Callable, runs: int) -> void:
	var tds := 0
	var yards := 0
	var snaps := 0
	var wins := 0
	var drives := 0
	var ends := {}
	var tds_hist := {}
	for r in runs:
		var g := QGame.new(1000 + r)
		while g.phase != "OVER":
			g.draw(Poker.discards(g.mine))
			policy.call(g)
			var res := g.showdown()
			snaps += 1
			wins += 1 if res.win == 1 else 0
			if res.drive_over:
				drives += 1
				ends[res.event] = int(ends.get(res.event, 0)) + 1
			if g.phase == "RESULT":
				g.next()
		tds += g.tds
		yards += g.yards_total
		tds_hist[g.tds] = int(tds_hist.get(g.tds, 0)) + 1
	print("%s  TD/run %.2f   net yds/run %+.0f   snaps/run %.1f   win hand %.1f%%" % [
		label.rpad(22), float(tds) / runs, float(yards) / runs, float(snaps) / runs, 100.0 * wins / snaps])
	var parts: Array = []
	for k in ends:
		parts.append("%s %.0f%%" % [k, 100.0 * ends[k] / drives])
	print("    drives end: %s" % ", ".join(parts))
	var keys := tds_hist.keys()
	keys.sort()
	print("    TDs per run: %s" % ", ".join(keys.map(func(k): return "%d:%d" % [k, tds_hist[k]])))


func _init() -> void:
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 400
	print("\n=== QGame run check (%d runs per policy, %d drives) ===" % [n, QGame.DRIVES])
	_run("default play", _policy_auto, n)
	_run("analyst (reads tells)", _policy_analyst, n)
	_run("informed (peeks style)", _policy_informed, n)
	quit()
