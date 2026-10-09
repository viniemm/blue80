extends SceneTree
## Expected yards per card (mean over the four defense styles), plus bet EV per chip at x1.0 with no style read.
func _init() -> void:
	DefContext.strength = QGame.STYLE_STRENGTH
	var cards := Deck52.build()
	var lines := Lines.new(cards, QGame.VIG, "card")
	print("E[yards] by rank x suit (avg over defense styles)")
	print("rank   " + "   ".join(Deck52.SUITS.map(func(s): return s.rpad(5))))
	for r in range(2, 15):
		var row := "%-5s" % Deck52.RANK_LABELS[r - 2]
		for s in 4:
			var th: Dictionary = cards[s * 13 + r - 2].theta
			var m := 0.0
			for st in DefContext.STYLES:
				m += YardCurve.mean(DefContext.apply(th, st)) / 4.0
			row += "  %6.2f" % m
		print(row)
	print("\nstyle effect on E[yards], avg over all cards")
	for st in DefContext.STYLES:
		var m := 0.0
		for c in cards:
			m += YardCurve.mean(DefContext.apply(c.theta, st)) / 52.0
		print("  %-9s %.2f" % [st, m])
	print("\nblind EV per chip by line (x1.0 hand), avg per tier; and with the style known (best line)")
	for tier in ["BRONZE", "SILVER", "GOLD", "PLATINUM"]:
		var sums := [0.0, 0.0, 0.0, 0.0, 0.0]
		var best := 0.0
		var n := 0
		for c in cards:
			if c.tier != tier:
				continue
			n += 1
			var bb := 0.0
			for k in 5:
				var blind := 0.0
				var informed := 0.0
				for st in DefContext.STYLES:
					var s := YardCurve.survival(DefContext.apply(c.theta, st), lines.threshold(c, k))
					var ev := lines.ev_per_chip(s, c, k, 1.0)
					blind += ev / 4.0
					informed = maxf(informed, 0.0)
				sums[k] += blind
			for st in DefContext.STYLES:
				var bk := 0.0
				for k in 5:
					bk = maxf(bk, lines.ev_per_chip(YardCurve.survival(DefContext.apply(c.theta, st), lines.threshold(c, k)), c, k, 1.0))
				bb += bk / 4.0
			best += bb
		print("%-9s blind: %s   style-known best: %+.3f" % [tier, " ".join(sums.map(func(x): return "%+.3f" % (x / n))), best / n])
	quit()
