extends SceneTree
## Headless rules check: plays whole games against the computer (drives alternate) with a few selection strategies.
##   godot --headless --path godot -s tests/qgame_test.gd -- <games per policy>
## Reports your touchdowns against the computer's, how often you win, and how drives end, so the wheel, the
## multipliers and the config (data/config.json) can be tuned.


## Selects the default lead card of your best hand (what the game used to preselect).
func _policy_auto(g: QGame) -> void:
	g.set_play(int(g.my_eval.lead_idx))


## Cheats: on offense picks the card with the best average yards against the computer's hidden style; on defense
## calls the style that most reduces the computer's chosen play.
func _policy_informed(g: QGame) -> void:
	var best := int(g.my_eval.lead_idx)
	var best_v := -1e9
	for i in g.eligible():
		var c: Dictionary = g.mine[i]
		var v := 0.0
		if g.player_off:
			v = YardCurve.mean(DefContext.apply(c.theta, QGame.STYLE_OF_SUIT[g.their_eval.lead_suit]))
		else:
			var style: String = QGame.STYLE_OF_SUIT[c.suit] if c.suit < 4 else "BALANCED"
			v = -YardCurve.mean(DefContext.apply(g.theirs[g.cpu_idx].theta, style))
		if v > best_v:
			best_v = v
			best = int(i)
	g.set_play(best)


func _run(label: String, policy: Callable, games: int) -> void:
	var my_tds := 0
	var cpu_tds := 0
	var wins := 0
	var ties := 0
	var snaps := 0
	var hands_won := 0
	var drives := 0
	var ends := {}
	for r in games:
		var g := QGame.new(1000 + r)
		while g.phase != "OVER":
			g.draw(Poker.discards(g.mine, QGame.MAX_DISCARDS))
			policy.call(g)
			var res := g.showdown()
			snaps += 1
			hands_won += 1 if res.win == 1 else 0
			if res.drive_over:
				drives += 1
				ends[res.event] = int(ends.get(res.event, 0)) + 1
			if g.phase == "RESULT":
				g.next()
		my_tds += g.tds
		cpu_tds += g.cpu_tds
		match g.outcome():
			"WIN": wins += 1
			"TIE": ties += 1
	print("%s  TD you %.2f vs cpu %.2f   win %.0f%% tie %.0f%%   snaps/game %.1f   hands won %.1f%%" % [
		label.rpad(20), float(my_tds) / games, float(cpu_tds) / games, 100.0 * wins / games, 100.0 * ties / games,
		float(snaps) / games, 100.0 * hands_won / snaps])
	var parts: Array = []
	for k in ends:
		parts.append("%s %.0f%%" % [k, 100.0 * ends[k] / drives])
	print("    drives end: %s" % ", ".join(parts))


func _init() -> void:
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 300
	print("\n=== QGame check (%d games per policy, %d decks, %d-card hands, %d drives each) ===" % [n, QGame.DECKS, QGame.HAND_SIZE, QGame.DRIVES_PER_SIDE])
	_run("default lead card", _policy_auto, n)
	_run("informed (peeks)", _policy_informed, n)
	quit()
