extends SceneTree
## Compares each family's bronze plays (and each tier) against real football per-play averages.
##   godot --headless --path godot -s tests/fit_check.gd
const TARGET := {"RUN": 4.3, "RPO": 5.2, "PASS": 6.0, "SHOT": 6.7}


func _stats(th: Dictionary) -> Dictionary:
	var med := 0
	for t in range(-5, 80):
		if YardCurve.survival(th, t) < 0.5:
			med = t - 1 if t > -5 else t
			break
	return {"mean": YardCurve.mean(th), "med": med, "le0": 1.0 - YardCurve.survival(th, 1), "ge10": YardCurve.survival(th, 10),
			"ge20": YardCurve.survival(th, 20), "sd": YardCurve.stdev(th), "to": float(th.p_to)}


func _avg(cards: Array) -> Dictionary:
	var out := {"mean": 0.0, "med": 0.0, "le0": 0.0, "ge10": 0.0, "ge20": 0.0, "sd": 0.0, "to": 0.0}
	var n := 0
	for c in cards:
		for st in DefContext.STYLES:
			var s := _stats(DefContext.apply(c.theta, st))
			for k in out:
				out[k] += float(s[k])
			n += 1
	for k in out:
		out[k] /= n
	return out


func _row(label: String, s: Dictionary, target: String = "") -> void:
	print("%-14s mean %5.2f  med %4.1f  <=0 %4.1f%%  10+ %4.1f%%  20+ %4.1f%%  sd %5.1f  TO %.1f%% %s" % [
		label, s.mean, s.med, 100.0 * s.le0, 100.0 * s.ge10, 100.0 * s.ge20, s.sd, 100.0 * s.to, target])


func _init() -> void:
	DefContext.strength = QGame.STYLE_STRENGTH
	var cards := Deck52.build()
	print("bronze (ranks 2-6) per family, averaged over defense styles")
	var all_b: Array = []
	for fam in Deck52.SUITS:
		var sel := cards.filter(func(c): return c.suit_name == fam and c.tier == "BRONZE")
		all_b.append_array(sel)
		_row(fam, _avg(sel), "(target mean %.1f)" % TARGET[fam])
	_row("ALL BRONZE", _avg(all_b), "(target mean 5.5)")
	print("\nby tier, all families")
	for tier in ["BRONZE", "SILVER", "GOLD", "PLATINUM"]:
		_row(tier, _avg(cards.filter(func(c): return c.tier == tier)))
	print("\nby tier x family mean yards")
	for tier in ["BRONZE", "SILVER", "GOLD", "PLATINUM"]:
		var row := "%-9s" % tier
		for fam in Deck52.SUITS:
			row += "  %s %5.1f" % [fam, _avg(cards.filter(func(c): return c.suit_name == fam and c.tier == tier)).mean]
		print(row)
	quit()
