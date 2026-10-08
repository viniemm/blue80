class_name DefenseCurve
extends RefCounted
## Gaussian probability curve over the 5 aggression tiers; its center moves with the situation.


static func target_tier(st: Dictionary, run_lean: float) -> Array:
	var mu := 3.0
	var why: Array = []
	if st.distance <= 2.0:
		mu += 1.2
		why.append("Short yardage: crowding the line")
	elif st.distance <= 4.0:
		mu += 0.6
		why.append("Short yardage: aggressive")
	elif st.down == 1:
		pass
	elif st.distance >= 15.0:
		mu -= 1.6
		why.append("Very long yardage: sitting deep")
	elif st.distance >= 10.0:
		mu -= 1.0
		why.append("Long yardage: backing off")
	elif st.distance >= 7.0:
		mu -= 0.4
		why.append("Medium-long: lean to coverage")
	var yl: float = st.yardline_to_opponent_goal
	if yl <= 3.0:
		mu += 1.0
		why.append("Goal line: everyone up")
	elif yl <= 10.0:
		mu += 0.5
		why.append("Red zone: less to defend deep")
	elif yl <= 20.0:
		mu += 0.2
	if absf(run_lean) >= 0.15:
		mu += 0.8 * run_lean
		why.append("They have seen " + ("runs" if run_lean > 0 else "passes"))
	return [clampf(mu, 1.0, 5.0), why]


static func compute(st: Dictionary, D: Dictionary, run_lean: float, sigma: float) -> Dictionary:
	var tm := target_tier(st, run_lean)
	var mu: float = tm[0]
	var raw := {}
	var total := 0.0
	for t in range(1, 6):
		var v := exp(-pow(float(t) - mu, 2.0) / (2.0 * sigma * sigma))
		raw[t] = v
		total += v
	var per_tier := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for code in D.defense_order:
		per_tier[int(D.defense[code].tier)] += 1
	var weights := {}
	var wsum := 0.0
	for code in D.defense_order:
		var tier := int(D.defense[code].tier)
		var w: float = float(raw[tier]) / total / float(per_tier[tier])
		weights[code] = w
		wsum += w
	var tier_probs := {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0}
	for code in weights:
		weights[code] = float(weights[code]) / wsum
		tier_probs[int(D.defense[code].tier)] += float(weights[code])
	return {"weights": weights, "tier_probs": tier_probs, "mean_tier": mu, "reasons": tm[1]}


static func sample(weights: Dictionary, order: Array, rng: RandomNumberGenerator) -> String:
	var u := rng.randf()
	var acc := 0.0
	for code in order:
		acc += float(weights[code])
		if u <= acc:
			return code
	return order[order.size() - 1]
