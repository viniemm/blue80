class_name Evaluator
extends RefCounted
## Monte Carlo odds for the outcome wheel: simulates a play many times and tallies outcome categories.

const ORDER := ["INTERCEPTION", "FUMBLE", "LOSS", "FIELD_GOAL_MISSED", "NO_GAIN", "PUNT", "GAIN", "BIG_GAIN",
		"FIELD_GOAL_GOOD", "TOUCHDOWN"]


static func categorize(r: Dictionary) -> String:
	match r.outcome:
		"FIELD_GOAL_GOOD":
			return "FIELD_GOAL_GOOD"
		"FIELD_GOAL_MISSED":
			return "FIELD_GOAL_MISSED"
		"PUNT", "TOUCHBACK":
			return "PUNT"
		"INTERCEPTION":
			return "INTERCEPTION"
		"FUMBLE":
			return "FUMBLE"
	if r.touchdown:
		return "TOUCHDOWN"
	if r.yards < 0:
		return "LOSS"
	if r.yards == 0 or r.outcome in ["INCOMPLETE", "THROWAWAY"]:
		return "NO_GAIN"
	return "BIG_GAIN" if r.yards >= 10 else "GAIN"


## defense_weights: {code: weight}. Simulations are split across defenses in proportion to weight.
static func evaluate(st: Dictionary, call: Dictionary, D: Dictionary, defense_weights: Dictionary, tilt: Dictionary,
		n: int, rng: RandomNumberGenerator) -> Dictionary:
	var cum: Array = []
	var codes: Array = D.defense_order
	var acc := 0.0
	for c in codes:
		acc += float(defense_weights[c])
		cum.append(acc)
	var counts := {}
	var total_yards := 0.0
	var first_downs := 0
	var turnovers := 0
	var sacks := 0
	for i in n:
		var u: float = (float(i) + 0.5) / float(n)
		var idx := 0
		while idx < cum.size() - 1 and u > float(cum[idx]):
			idx += 1
		var res: Dictionary = Sim.resolve_play(st, call, D.defense[codes[idx]], D.east, D.west, D.matrix, tilt, rng)
		var r: Dictionary = res.result
		var cat := categorize(r)
		counts[cat] = int(counts.get(cat, 0)) + 1
		total_yards += float(r.yards)
		first_downs += 1 if r.first_down else 0
		turnovers += 1 if r.turnover else 0
		sacks += 1 if r.outcome == "SACK" else 0
	var slices: Array = []
	for cat in ORDER:
		if counts.has(cat):
			slices.append({"category": cat, "pct": snappedf(100.0 * float(counts[cat]) / float(n), 0.1)})
	return {"slices": slices, "mean": total_yards / float(n), "p_fd": float(first_downs) / float(n),
			"p_to": float(turnovers) / float(n), "p_sack": float(sacks) / float(n)}
