class_name PaytableScreen
extends PxScreen
## Reference tables: hand multipliers, card tiers (computed from the real curves) and the five lines.

const TIERS := [
	["BRONZE", "2-6", Color("cd7f32")],
	["SILVER", "7-10", Color("c0c8d8")],
	["GOLD", "J Q K", Color("ffcc33")],
	["PLATINUM", "A", Color("e8f0ff")],
]

var _tier_stats := {}


func _ready() -> void:
	set_card_alpha(0.18)
	var sums := {}
	for c in Deck52.build():
		var s: Dictionary = sums.get(c.tier, {"n": 0, "mean": 0.0, "sd": 0.0})
		s.n += 1
		s.mean += YardCurve.mean(c.theta)
		s.sd += YardCurve.stdev(c.theta)
		sums[c.tier] = s
	for k in sums:
		_tier_stats[k] = {"mean": sums[k].mean / sums[k].n, "sd": sums[k].sd / sums[k].n}
	add_back("MENU")



func _paint() -> void:
	banner("PAYTABLE")
	var y := 50.0
	Px.text(self, 14, y, "HAND MULTIPLIERS", 2, Px.GOLD)
	y += 18.0
	for i in range(Poker.CAT_NAMES.size() - 1, -1, -1):
		Px.text(self, 20, y, Poker.CAT_NAMES[i], 1, Px.FG)
		Px.text_right(self, 340, y, "x%.1f" % Poker.MULT[i], 1, Px.GREEN if i >= 4 else Px.DIM)
		y += 15.0
	y += 8.0
	Px.text(self, 14, y, "CARD TIERS", 2, Px.GOLD)
	Px.text_right(self, 262, y + 1, "AVG YDS", 0, Px.DIM)
	Px.text_right(self, 340, y + 1, "SPREAD", 0, Px.DIM)
	y += 18.0
	for t in TIERS:
		Px.text(self, 20, y, t[0], 1, t[2])
		Px.text(self, 100, y, t[1], 1, Px.DIM)
		var st: Dictionary = _tier_stats.get(t[0], {"mean": 0.0, "sd": 0.0})
		Px.text_right(self, 262, y, "%.1f" % st.mean, 1, Px.FG)
		Px.text_right(self, 340, y, "%.1f" % st.sd, 1, Px.DIM)
		y += 15.0
	y += 8.0
	Px.text(self, 14, y, "THE WHEEL", 2, Px.GOLD)
	y += 18.0
	Px.text(self, 20, y, "WIN: the gain wheel x YOUR multiplier.", 1, Px.GREEN)
	Px.text(self, 20, y + 15, "LOSE: the loss wheel x THEIR multiplier.", 1, Px.RED)
	Px.text(self, 20, y + 30, "%d+ classes down is a turnover, no spin." % QGame.PICK_SIX_GAP, 1, Px.DIM)
