extends SceneTree
## Headless rules and economy check for the card-betting game:
##   godot --headless --path godot -s tests/qgame_test.gd
## Plays thousands of snaps through QGame with a few betting policies and checks invariants.

func _policy_none(g: QGame) -> void:
	g.set_bet(-1, 0.0)


func _policy_flat(g: QGame) -> void:
	g.set_bet(2, minf(2.0, g.max_stake()))


## Best (card, line) for a policy: tries every card that may be the play and every line, using `true_s` for the
## chance of clearing. Returns {idx, line, s, ev}.
func _best(g: QGame, true_s: Callable, choose: bool = true) -> Dictionary:
	var best := {"idx": g.play_idx, "line": -1, "s": 0.0, "ev": 0.0}
	var m := g.bet_mult()
	for i in (g.eligible() if choose else [g.play_idx]):
		var c: Dictionary = g.mine[i]
		for k in 5:
			var s: float = true_s.call(c, k)
			var ev := g.lines.ev_per_chip(s, c, k, m)
			if ev > float(best.ev):
				best = {"idx": i, "line": k, "s": s, "ev": ev}
	return best


func _place(g: QGame, b: Dictionary) -> void:
	g.set_play(int(b.idx))
	if int(b.line) < 0:
		g.set_bet(-1, 0.0)
		return
	var c := g.my_lead()
	g.set_bet(int(b.line), minf(0.5 * g.lines.kelly(float(b.s), c, int(b.line), g.bet_mult()) * g.bankroll, g.max_stake()))


## Cheats by peeking at the hidden style: an upper bound on what reading the defense can earn.
func _policy_informed(g: QGame) -> void:
	var style := g.hidden_style()
	_place(g, _best(g, func(c, k): return YardCurve.survival(DefContext.apply(c.theta, style), g.lines.threshold(c, k))))


var _arng := RandomNumberGenerator.new()


## Style odds given the 2 visible defense cards, conditioning on the hand being won (the bet only matters then).
func _posterior(g: QGame, n: int) -> Dictionary:
	var vis: Array = g.face_up.map(func(i): return g.theirs[i])
	var unseen: Array = g.unseen_pool()            # copies left in the shoe from the player's point of view
	var counts := {"BLITZ": 0, "ZONE": 0, "MAN": 0, "BALANCED": 0}
	var kept := 0
	for s in n:
		var picks: Array = []
		while picks.size() < 3:
			var i := _arng.randi_range(0, unseen.size() - 1)
			if not picks.has(i):
				picks.append(i)
		var hand: Array = vis + [unseen[picks[0]], unseen[picks[1]], unseen[picks[2]]]
		var ev := Poker.evaluate(hand)
		if ev.score >= g.my_eval.score:
			continue
		counts[QGame.STYLE_OF_SUIT[ev.lead_suit]] += 1
		kept += 1
	var out := {}
	for k in counts:
		out[k] = float(counts[k]) / kept if kept > 0 else 0.25
	return out


## What a quant does without cheating: price each card and line against the posterior over styles.
func _policy_analyst(g: QGame) -> void:
	var post := _posterior(g, 150)
	_place(g, _best(g, func(c, k):
		var s := 0.0
		for style in post:
			s += float(post[style]) * YardCurve.survival(DefContext.apply(c.theta, style), g.lines.threshold(c, k))
		return s))


## Same pricing as the analyst but with a uniform prior (no read of the face-up cards): the hand-strength-only strategy.
func _policy_no_read(g: QGame) -> void:
	_place(g, _best(g, func(c, k):
		var s := 0.0
		for style in DefContext.STYLES:
			s += 0.25 * YardCurve.survival(DefContext.apply(c.theta, style), g.lines.threshold(c, k))
		return s, false))


## Reads the face-up cards but always runs the default play (no choosing).
func _policy_read_only(g: QGame) -> void:
	var post := _posterior(g, 150)
	_place(g, _best(g, func(c, k):
		var s := 0.0
		for style in post:
			s += float(post[style]) * YardCurve.survival(DefContext.apply(c.theta, style), g.lines.threshold(c, k))
		return s, false))


func _run(name: String, policy: Callable, rounds: int) -> void:
	var g := QGame.new(7)
	var total := 0.0
	var snaps := 0
	var busts := 0
	var drives := 0
	var tds := 0
	var turnovers := 0
	var wins := 0
	var events := {}
	for i in rounds:
		if g.phase == "OVER":
			busts += 1
			g = QGame.new(7 + i)
		# draw by heuristic, like the AI
		g.draw(Poker.discards(g.mine))
		assert(g.phase == "BET" and g.face_up.size() == 2)
		policy.call(g)
		var before := g.bankroll
		var r := g.showdown()
		assert(not r.is_empty())
		assert(absf((g.bankroll - before) - r.delta) < 1e-6 * maxf(1.0, absf(before)))
		assert(r.bet_delta == 0.0 or r.win == 1)         # a bet only settles when you win the hand
		total += r.delta
		snaps += 1
		wins += 1 if r.win == 1 else 0
		turnovers += 1 if r.turnover else 0
		events[r.event] = int(events.get(r.event, 0)) + 1
		if r.drive_over:
			drives += 1
			tds += 1 if r.event == "TOUCHDOWN" else 0
		if g.phase == "RESULT":
			g.next()
	print("%s  %+.3f chips/snap   win hand %.1f%%   drives %d (TD %.0f%%)   busts %d" % [
		name.rpad(22), total / snaps, 100.0 * wins / snaps, drives, 100.0 * tds / maxi(1, drives), busts])
	print("    events: %s" % str(events))


func _init() -> void:
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 12000
	if OS.get_cmdline_user_args().size() > 1:
		QGame.bet_k = float(OS.get_cmdline_user_args()[1])
	print("\n=== QGame economy check (%d snaps per policy, identical hands, style strength %.1f, vig %.0f%%) ===" % [n, QGame.STYLE_STRENGTH, QGame.VIG * 100.0])
	_run("draw only, no bets", _policy_none, n)
	_run("flat MEDIUM x2", _policy_flat, n)
	_run("hand strength only", _policy_no_read, n)
	_run("+ read face-up cards", _policy_read_only, n)
	_run("+ choose the play", _policy_analyst, n)
	_run("informed (peeks style)", _policy_informed, n)
	quit()
