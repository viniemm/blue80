extends SceneTree
## Math lab for the card/betting design. Run headless:
##   godot --headless --path godot -s tests/quant_lab.gd
## Question it answers: with an exact house (prices each card's public curve), where does a quantitative
## player's edge come from, and how much is better information worth?

var cards: Array
var rng := RandomNumberGenerator.new()
var rng_hand := RandomNumberGenerator.new()   # paired streams: every strategy sees the same hands and styles
var rng_bet := RandomNumberGenerator.new()
var rng_read := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 2024
	cards = Deck52.build()
	_section_pricing(Lines.new(cards, 0.15, "card"), Lines.new(cards, 0.15, "rank"))
	for strength in [1.0, 2.0]:
		DefContext.strength = strength
		print("\n################ defense style strength %.1f ################" % strength)
		var exact := Lines.new(cards, 0.15, "card")
		_section_context(exact)
		_section_info_value(exact)
		_section_vig_sweep()
	quit()


func _pad(s: Variant, n: int) -> String:
	return str(s).rpad(n)


func _pct(x: float) -> String:
	return "%5.1f%%" % (x * 100.0)


# ------------------------------------------------------------------ 1. pricing models, no hidden info
func _section_pricing(exact: Lines, by_rank: Lines) -> void:
	print("\n=== HOUSE PRICING MODELS ===")
	print("exact house (prices each card's own curve, averaged over defense styles): an uninformed bettor's")
	print("  edge is zero on every line by construction, so there is no lookup table to memorize.")
	var tot := 0.0
	for c in cards:
		var best := -9.0
		for k in 5:
			best = maxf(best, YardCurve.survival(c.theta, by_rank.threshold(c, k)) / by_rank.house_p(c, k) - 1.0)
		tot += best
	print("dumber house (prices by rank only): knowing the play family alone is worth a best-line edge of %+.1f%%" % (100.0 * tot / cards.size()))
	print("  (e.g. 'runs clear SHORT, shots clear HAIL MARY'), which would make the game solvable.")
	print("\nExample thresholds under the exact house (yards a card must gain to clear each line):")
	for idx in [0, 12, 28, 38, 51]:
		var c: Dictionary = cards[idx]
		var row := ""
		for k in 5:
			row += " %s>=%2d" % [Lines.NAMES[k].substr(0, 4), exact.threshold(c, k)]
		print("  %s%s %s%s" % [_pad(c.label, 3), _pad(c.suit_name, 5), _pad(c.name, 14), row])


# ------------------------------------------------------------------ 2. what a hidden style does to the lines
func _section_context(exact: Lines) -> void:
	print("\n=== EDGE CREATED BY A HIDDEN DEFENSE STYLE (exact house, averaged over 52 cards, before vig) ===")
	print("%s CHECKDOWN   SHORT  MEDIUM    LONG HAILMARY | best-line edge" % _pad("style", 9))
	for style in DefContext.STYLES:
		var edge := [0.0, 0.0, 0.0, 0.0, 0.0]
		var best_tot := 0.0
		for c in cards:
			var th := DefContext.apply(c.theta, style)
			var best := -9.0
			for k in 5:
				var e := YardCurve.survival(th, exact.threshold(c, k)) / exact.house_p(c, k) - 1.0
				edge[k] += e
				best = maxf(best, e)
			best_tot += best
		var row := ""
		for k in 5:
			row += "%7.0f%% " % (100.0 * edge[k] / cards.size())
		print("%s %s| %+5.1f%%" % [_pad(style, 9), row, 100.0 * best_tot / cards.size()])


# ------------------------------------------------------------------ poker + betting simulation
func _shuffled() -> Array:
	var d := cards.duplicate()
	for i in range(d.size() - 1, 0, -1):
		var j := rng_hand.randi_range(0, i)
		var t = d[i]
		d[i] = d[j]
		d[j] = t
	return d


func _draw(hand: Array, deck: Array, pos: int) -> int:
	for i in Poker.discards(hand):
		hand[i] = deck[pos]
		pos += 1
	return pos


func _duel() -> Dictionary:
	var deck := _shuffled()
	var a: Array = deck.slice(0, 5)
	var b: Array = deck.slice(5, 10)
	var pos := _draw(a, deck, 10)
	pos = _draw(b, deck, pos)
	var ea := Poker.evaluate(a)
	var eb := Poker.evaluate(b)
	return {"ea": ea, "eb": eb, "win": 1 if ea.score > eb.score else (-1 if ea.score < eb.score else 0)}


## mode: none | medium | blind | informed.  accuracy = chance an informed bettor reads the style correctly
## (otherwise a random style). Returns chips per hand (ante layer + betting layer) and the bet rate.
func _run(mode: String, accuracy: float, rounds: int, ln: Lines, fixed_stake: bool = true) -> Array:
	var last := 0.0
	var sumsq := 0.0
	var chips := 0.0
	var bets := 0
	var bankroll := 100.0
	rng_hand.seed = 11
	rng_bet.seed = 22
	rng_read.seed = 33
	for i in rounds:
		sumsq += (chips - last) * (chips - last)
		last = chips
		var r := _duel()
		if r.win == -1:
			chips -= Poker.MULT[r.eb.cat]
			continue
		if r.win == 0:
			continue
		var m: float = Poker.MULT[r.ea.cat]
		chips += m
		if mode == "none":
			continue
		var lead: Dictionary = r.ea.lead
		var true_style: String = DefContext.STYLES[rng_bet.randi_range(0, 3)]
		var th_true := DefContext.apply(lead.theta, true_style)
		var believed: String = true_style if rng_read.randf() < accuracy else DefContext.STYLES[rng_read.randi_range(0, 3)]
		var th_believed := DefContext.apply(lead.theta, believed)
		var pick := -1
		var stake := 0.0
		if mode == "medium":
			pick = 2
			stake = 2.0
		else:
			var best_ev := 0.0
			for k in 5:
				var s: float = ln.house_p(lead, k) if mode == "blind" else YardCurve.survival(th_believed, ln.threshold(lead, k))
				var ev := ln.ev_per_chip(s, lead, k, m)
				if ev > best_ev:
					best_ev = ev
					pick = k
			if pick >= 0:
				var s2: float = ln.house_p(lead, pick) if mode == "blind" else YardCurve.survival(th_believed, ln.threshold(lead, pick))
				stake = 2.0 if fixed_stake else minf(0.5 * ln.kelly(s2, lead, pick, m) * bankroll, 20.0)
		if pick >= 0 and stake > 0.0:
			bets += 1
			var y: int = YardCurve.sample(th_true, rng_bet).yards
			chips += stake * ln.odds(lead, pick) * m if y >= ln.threshold(lead, pick) else -stake
	sumsq += (chips - last) * (chips - last)
	var mean := chips / rounds
	return [mean, float(bets) / rounds, sqrt(maxf(0.0, sumsq / rounds - mean * mean))]


func _section_info_value(exact: Lines) -> void:
	print("\n=== WHAT IS READING THE DEFENSE WORTH? (30k hands, vig %.0f%%, FIXED 2-chip stake, paired hands) ===" % (exact.vig * 100.0))
	var base: float = _run("none", 0.0, 30000, exact)[0]
	print("(chips per hand gained from betting, above the no-bet baseline; only the choice of line differs)")
	for row in [["flat MEDIUM, no reading", "medium", 0.0], ["best line from house price only (blind)", "blind", 0.0]]:
		var res := _run(row[1], row[2], 30000, exact)
		print("%s %+.3f   (bets on %s)" % [_pad(row[0], 40), res[0] - base, _pct(res[1])])
	for acc in [0.25, 0.5, 0.75, 1.0]:
		var res := _run("informed", acc, 30000, exact)
		print("%s %+.3f   (bets on %s)" % [_pad("reads cleanly %3.0f%% (else guesses; eff. %2.0f%%)" % [acc * 100.0, (acc + (1.0 - acc) * 0.25) * 100.0], 40), res[0] - base, _pct(res[1])])
	print("(a bettor who never reads is guessing among 4 styles = 25% effective accuracy)")
	print("\nKelly sizing (risk-aware stake), return per unit of risk (mean / sd of chips per hand):")
	for row in [["no bets", "none", 0.0], ["blind (hand strength only)", "blind", 0.0], ["reads 50%", "informed", 0.5], ["reads 100%", "informed", 1.0]]:
		var res := _run(row[1], row[2], 30000, exact, false)
		print("%s mean %+.3f  sd %.2f  ratio %+.3f" % [_pad(row[0], 30), res[0], res[2], res[0] / maxf(0.0001, res[2])])


func _section_vig_sweep() -> void:
	print("\n=== VIG SWEEP (15k hands, fixed stake; gain per hand over no bets) ===")
	for v in [0.05, 0.10, 0.15, 0.25]:
		var ln := Lines.new(cards, v, "card")
		var base: float = _run("none", 0.0, 15000, ln)[0]
		var blind: float = float(_run("blind", 0.0, 15000, ln)[0]) - base
		var half: float = float(_run("informed", 0.5, 15000, ln)[0]) - base
		var full: float = float(_run("informed", 1.0, 15000, ln)[0]) - base
		print("vig %2.0f%%:  blind %+.3f   reads 50%% %+.3f   reads 100%% %+.3f" % [v * 100.0, blind, half, full])
