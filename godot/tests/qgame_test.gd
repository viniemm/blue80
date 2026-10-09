extends SceneTree
## Headless rules and economy check for the card-betting game:
##   godot --headless --path godot -s tests/qgame_test.gd
## Plays thousands of snaps through QGame with a few betting policies and checks invariants.

func _policy_none(g: QGame) -> void:
	g.set_bet(-1, 0.0)


func _policy_flat(g: QGame) -> void:
	g.set_bet(2, minf(2.0, g.max_stake()))


## Cheats by peeking at the hidden style: an upper bound on what reading the defense can earn.
func _policy_informed(g: QGame) -> void:
	var lead := g.my_lead()
	var th := DefContext.apply(lead.theta, g.hidden_style())
	var m := g.my_mult()
	var best := -1
	var best_ev := 0.0
	for k in 5:
		var ev := g.lines.ev_per_chip(YardCurve.survival(th, g.lines.threshold(lead, k)), lead, k, m)
		if ev > best_ev:
			best_ev = ev
			best = k
	if best < 0:
		g.set_bet(-1, 0.0)
		return
	var s := YardCurve.survival(th, g.lines.threshold(lead, best))
	g.set_bet(best, minf(0.5 * g.lines.kelly(s, lead, best, m) * g.bankroll, g.max_stake()))


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
		counts[g.style_of(ev.lead)] += 1
		kept += 1
	var out := {}
	for k in counts:
		out[k] = float(counts[k]) / kept if kept > 0 else 0.25
	return out


## What a quant does without cheating: price each line against the posterior over styles.
func _policy_analyst(g: QGame) -> void:
	var post := _posterior(g, 150)
	var lead := g.my_lead()
	var m := g.my_mult()
	var best := -1
	var best_ev := 0.0
	var best_s := 0.0
	for k in 5:
		var s := 0.0
		for style in post:
			s += float(post[style]) * YardCurve.survival(DefContext.apply(lead.theta, style), g.lines.threshold(lead, k))
		var ev := g.lines.ev_per_chip(s, lead, k, m)
		if ev > best_ev:
			best_ev = ev
			best = k
			best_s = s
	if best < 0:
		g.set_bet(-1, 0.0)
		return
	g.set_bet(best, minf(0.5 * g.lines.kelly(best_s, lead, best, m) * g.bankroll, g.max_stake()))


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
	print("\n=== QGame economy check (12,000 snaps per policy, identical hands, style strength %.1f, vig %.0f%%) ===" % [QGame.STYLE_STRENGTH, QGame.VIG * 100.0])
	_run("draw only, no bets", _policy_none, 12000)
	_run("flat MEDIUM x2", _policy_flat, 12000)
	_run("analyst (2 face-up cards)", _policy_analyst, 12000)
	_run("informed (peeks style)", _policy_informed, 12000)
	quit()
