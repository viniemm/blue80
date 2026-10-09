class_name Lines
extends RefCounted
## The five yardage lines. Each is a probability level (0.9 .. 0.1). For a card, the yard threshold of a line is
## where that card's own public curve crosses the level, and the payout is fair for that curve minus the vig.
## So with no hidden information the house is exact, and the only edge comes from what the house cannot see.
## mode "rank" prices from the average curve of cards sharing a rank instead (a dumber house, used for comparison).

const P := [0.90, 0.75, 0.50, 0.25, 0.10]
const NAMES := ["CHECKDOWN", "SHORT", "MEDIUM", "LONG", "HAIL MARY"]

var vig := 0.15            # the house shades every payout by this fraction
var mode := "card"
var thr := {}              # key -> [yard threshold per line]
var base := {}             # key -> [house probability of clearing that threshold]


func _init(cards: Array, vig_value: float = 0.15, mode_value: String = "card") -> void:
	vig = vig_value
	mode = mode_value
	if mode == "rank":
		for rank in range(2, 15):
			_price(rank, cards.filter(func(c): return c.rank == rank))
	else:
		for c in cards:
			_price(c.id, [c])


func _price(key: int, group: Array) -> void:
	var t_arr: Array = []
	var b_arr: Array = []
	for k in P.size():
		var best_t := 0
		var best_d := 9.0
		var best_s := 0.0
		# thresholds strictly increase across lines so no two lines are the same bet; CHECKDOWN may sit below zero
		var first_t := -30 if k == 0 else int(t_arr[k - 1]) + 1
		for t in range(first_t, 90):
			var s := 0.0
			for c in group:
				for style in DefContext.STYLES:
					s += YardCurve.survival(DefContext.apply(c.theta, style), t)
			s /= float(group.size() * DefContext.STYLES.size())
			var d := absf(s - float(P[k]))
			if d < best_d:
				best_d = d
				best_t = t
				best_s = s
		t_arr.append(best_t)
		b_arr.append(best_s)
	thr[key] = t_arr
	base[key] = b_arr


func _key(c: Dictionary) -> int:
	return c.rank if mode == "rank" else c.id


func threshold(c: Dictionary, k: int) -> int:
	return thr[_key(c)][k]


func house_p(c: Dictionary, k: int) -> float:
	return base[_key(c)][k]


## Net win per chip staked on line k for card c (before the hand multiplier): fair odds shaded by the vig.
func odds(c: Dictionary, k: int) -> float:
	return (1.0 / house_p(c, k) - 1.0) * (1.0 - vig)


## Expected profit per chip: the true chance `s` of clearing, hand multiplier `m` applied to a win.
func ev_per_chip(s: float, c: Dictionary, k: int, m: float) -> float:
	return s * odds(c, k) * m - (1.0 - s)


## Kelly fraction of bankroll for that bet (0 when there is no edge).
func kelly(s: float, c: Dictionary, k: int, m: float) -> float:
	var b := odds(c, k) * m
	return maxf(0.0, (b * s - (1.0 - s)) / b)
