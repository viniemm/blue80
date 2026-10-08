class_name Sim
extends RefCounted
## One-play resolution graph: pocket, routes, target selection, pass/run resolvers, yardage, special teams, rules.
## Everything is plain Dictionaries loaded from JSON. `tilt` is the hook cards and jokers use to reshape odds:
##   run_fit, pressure, sep_short, sep_deep, sep_all, comp_logit, int_logit,
##   fumble_mult, run_yards_mult, yac_mult   (all optional, default neutral)

const ROUTE_TIMINGS := {
	"SCREEN": 1.1, "FLAT": 1.3, "SLANT": 1.5, "HITCH": 1.6, "QUICK_OUT": 1.7, "CROSSER": 2.2, "DIG": 2.4,
	"CURL": 2.3, "OUT": 2.5, "CORNER": 2.9, "POST": 3.1, "GO": 3.2, "SEAM": 2.8, "WHEEL": 3.0, "HAIL_MARY": 3.8,
}
const RUN_CONCEPTS := ["ZONE_RUN", "GAP_POWER", "OPTION_VEER", "DRAW_TRAP", "QB_KNEEL"]


# ------------------------------------------------------------------ players
static func rt(p: Dictionary, key: String, default_val: float = 50.0) -> float:
	var v = p.get("ratings", {}).get(key)
	if v == null:
		return default_val
	return clampf(float(v), 0.0, 99.0)


static func z(p: Dictionary, key: String) -> float:
	return (rt(p, key) - 50.0) / 25.0


static func dummy(position: String, name: String) -> Dictionary:
	return {"player_id": name.to_lower(), "display_name": name, "position": position, "ratings": {}}


static func build_team(players: Array) -> Dictionary:
	var t := {"qb": null, "rb": null, "ol": [], "dl": [], "secondary": [], "eligibles": [], "k": null, "p": null}
	for p in players:
		var pos: String = p.position
		if pos == "QB":
			if t.qb == null:
				t.qb = p
		elif pos == "RB":
			if t.rb == null:
				t.rb = p
			t.eligibles.append(p)
		elif pos in ["OT", "OG", "C"]:
			t.ol.append(p)
		elif pos in ["EDGE", "IDL"]:
			t.dl.append(p)
		elif pos == "LB":
			t.dl.append(p)
			t.secondary.append(p)
		elif pos in ["CB_BOUNDARY", "CB_FIELD", "CB_NICKEL", "S_FREE", "S_STRONG"]:
			t.secondary.append(p)
		elif pos in ["WR_X", "WR_Z", "WR_SLOT", "TE"]:
			t.eligibles.append(p)
		elif pos == "K":
			if t.k == null:
				t.k = p
		elif pos == "P":
			if t.p == null:
				t.p = p
	if t.qb == null: t.qb = dummy("QB", "Quarterback")
	if t.rb == null: t.rb = dummy("RB", "Running Back")
	return t


static func is_run(call: Dictionary) -> bool:
	return RUN_CONCEPTS.has(call.concept)


# ------------------------------------------------------------------ scheme matrix
static func scheme_mod(matrix: Dictionary, concept: String, coverage: String) -> Dictionary:
	var key := concept + "|" + coverage
	if matrix.has(key):
		return matrix[key].duplicate()
	return {"variance_multiplier": 1.0, "pressure_log_odds_delta": 0.0, "separation_delta": 0.0,
			"turnover_log_odds_delta": 0.0, "run_fit_log_odds_delta": 0.0}


static func index_matrix(data: Dictionary) -> Dictionary:
	var out := {}
	for m in data.modifiers:
		var key: String = m.concept + "|" + m.defense
		if not out.has(key):          # first match wins
			out[key] = m
	return out


# ------------------------------------------------------------------ pocket
static func assign_blocker(rusher: Dictionary, ol: Array, protection: String) -> Dictionary:
	if ol.is_empty():
		return {}
	var tackles := ol.filter(func(p): return p.position == "OT")
	var guards := ol.filter(func(p): return p.position == "OG")
	var centers := ol.filter(func(p): return p.position == "C")
	var lt: Dictionary = tackles[0] if tackles.size() > 0 else ol[0]
	var rt_: Dictionary = tackles[1] if tackles.size() > 1 else (tackles[0] if tackles.size() > 0 else ol[ol.size() - 1])
	var lg: Dictionary = guards[0] if guards.size() > 0 else lt
	var rg: Dictionary = guards[1] if guards.size() > 1 else (guards[0] if guards.size() > 0 else rt_)
	var c: Dictionary = centers[0] if centers.size() > 0 else lg
	if rusher.position == "EDGE":
		return lt if ("left" in rusher.display_name.to_lower() or "1" in rusher.player_id) else rt_
	if rusher.position == "IDL" or rusher.position == "LB":
		if protection == "SLIDE_LEFT": return lg
		if protection == "SLIDE_RIGHT": return rg
		return c
	return ol[0]


static func pocket(ol: Array, rushers: Array, protection: String, qb: Dictionary, pressure_delta: float,
		rng: RandomNumberGenerator, play_cap: float = 4.5) -> Dictionary:
	if rushers.is_empty():
		return {"arrives": false, "time": play_cap, "severity": 0.0, "rusher": "", "text": "Clean pocket"}
	var p0 := 0.90
	if protection == "MAX_PROTECT": p0 = 0.94
	elif protection == "SCREEN_RELEASE": p0 = 0.35
	var prot_delta := 0.0
	if protection == "MAX_PROTECT": prot_delta = 0.3
	elif protection == "SCREEN_RELEASE": prot_delta = -0.6
	var best_t := 999.0
	var best: Dictionary = {}
	var best_block: Dictionary = {}
	for r in rushers:
		var blocker := assign_blocker(r, ol, protection)
		var a_block := rt(blocker, "pass_block") if not blocker.is_empty() else 40.0
		var p_hold := MathX.matchup_probability(p0, a_block, rt(r, "pass_rush"), -pressure_delta + prot_delta, 0.0, 2.5)
		var t := MathX.sample_lognormal_time(p_hold, rng, 2.5, 0.45)
		if t < best_t:
			best_t = t
			best = r
			best_block = blocker
	var esc := 0.25 * z(qb, "mobility") + 0.15 * z(qb, "pocket_awareness")
	var eff := maxf(0.8, best_t + esc)
	var arrives := eff < play_cap
	var sev := 0.0
	var text := "Clean pocket held"
	if arrives:
		sev = clampf((play_cap - eff) / (play_cap - 1.2), 0.1, 1.0)
		text = "%s beat %s at %.2fs" % [best.display_name, best_block.get("display_name", "protection"), eff]
	return {"arrives": arrives, "time": eff, "severity": sev, "rusher": best.display_name if arrives else "", "text": text}


# ------------------------------------------------------------------ routes / separation
static func route_time(route: String, depth: float) -> float:
	var base: float = ROUTE_TIMINGS.get(route.to_upper(), 2.2)
	return snappedf(base + maxf(0.0, (depth - 5.0) * 0.05), 0.01)


static func map_eligible(eid: String, eligibles: Array) -> Dictionary:
	var l := eid.to_lower()
	for p in eligibles:
		if p.player_id.to_lower() == l:
			return p
	var want := ""
	if "wr_x" in l: want = "WR_X"
	elif "wr_z" in l: want = "WR_Z"
	elif "slot" in l: want = "WR_SLOT"
	elif "te" in l: want = "TE"
	elif "rb" in l: want = "RB"
	if want != "":
		for p in eligibles:
			if p.position == want:
				return p
	return eligibles[0] if not eligibles.is_empty() else dummy("WR_X", "Receiver")


static func assign_defender(receiver: Dictionary, secondary: Array) -> Dictionary:
	if secondary.is_empty():
		return dummy("CB_FIELD", "Defender")
	var cbs := secondary.filter(func(p): return p.position in ["CB_BOUNDARY", "CB_FIELD", "CB_NICKEL"])
	var safeties := secondary.filter(func(p): return p.position in ["S_FREE", "S_STRONG"])
	var lbs := secondary.filter(func(p): return p.position == "LB")
	match receiver.position:
		"WR_X", "WR_Z":
			if not cbs.is_empty():
				return cbs[0] if receiver.position == "WR_X" else (cbs[1] if cbs.size() > 1 else cbs[0])
		"WR_SLOT":
			var nickel := cbs.filter(func(p): return p.position == "CB_NICKEL")
			if not nickel.is_empty(): return nickel[0]
			if not safeties.is_empty(): return safeties[0]
		"TE":
			if not lbs.is_empty(): return lbs[0]
			if not safeties.is_empty(): return safeties[safeties.size() - 1]
		"RB":
			if not lbs.is_empty(): return lbs[lbs.size() - 1]
	return secondary[0]


static func separation(receiver: Dictionary, defender: Dictionary, read: Dictionary, coverage: String,
		available_time: float, sep_delta: float, rng: RandomNumberGenerator) -> Dictionary:
	var depth_raw = read.get("depth_yards")
	var dev := route_time(read.route, 10.0 if depth_raw == null else float(depth_raw))
	var depth: float = float(depth_raw) if depth_raw != null else dev * 4.5
	var cov_mod := 0.0
	match coverage:
		"COVER_0_BLITZ": cov_mod = 0.5
		"COVER_1_MAN": cov_mod = 0.2
		"COVER_2_ZONE": cov_mod = -0.2 if depth > 15.0 else 0.1
		"COVER_4_QUARTERS": cov_mod = -0.4 if depth > 12.0 else 0.0
		"PREVENT": cov_mod = -0.8 if depth > 15.0 else 0.5
	var mean_sep := 1.8 \
		+ 0.6 * (z(receiver, "route_running") - z(defender, "coverage")) \
		+ 0.4 * (z(receiver, "speed") - z(defender, "speed")) \
		+ 0.3 * (z(receiver, "release") - z(defender, "recognition")) \
		+ cov_mod + sep_delta
	mean_sep = maxf(0.2, mean_sep)
	var sep := maxf(0.1, mean_sep + rng.randfn(0.0, 0.6))
	return {
		"player_id": receiver.player_id, "display_name": receiver.display_name, "read_order": int(read.order),
		"route": read.route, "depth_yards": snappedf(depth, 0.1), "separation": snappedf(sep, 0.01),
		"contested": sep < 1.3, "viable": available_time >= 0.0, "defender_name": defender.display_name,
		"text": "%s (%s, %.1f yds) sep %.2f vs %s" % [receiver.display_name, read.route, depth, sep, defender.display_name],
	}


# ------------------------------------------------------------------ target selection
static func target_score(t: Dictionary, qb: Dictionary, aggressiveness: float) -> float:
	var s: float = 1.4 * t.separation
	s += 1.0 * (1.0 / t.read_order)
	s += 0.5 * (0.5 + 0.2 * z(qb, "decision_making"))
	var risk := (1.5 if t.contested else 0.0) + maxf(0.0, (t.depth_yards - 12.0) * 0.05)
	s -= 1.2 * risk * (1.2 - 0.6 * aggressiveness)
	return s


static func select_target(targets: Array, qb: Dictionary, call: Dictionary, rng: RandomNumberGenerator):
	var viable := targets.filter(func(t): return t.viable)
	if viable.is_empty():
		return null
	var logits: Array = []
	var avg_sep := 0.0
	for t in viable:
		logits.append(target_score(t, qb, call.aggressiveness))
		avg_sep += t.separation
	avg_sep /= viable.size()
	var away: float = 0.5 - 1.5 * call.aggressiveness
	if avg_sep < 0.8:
		away += 1.2
	var items: Array = viable.duplicate()
	items.append(null)
	logits.append(away)
	return MathX.softmax_sample(items, logits, rng)


# ------------------------------------------------------------------ run fit
static func run_fit(call: Dictionary, def: Dictionary, ol: Array, front: Array, runner: Dictionary,
		fit_delta: float, rng: RandomNumberGenerator) -> Dictionary:
	var avg_block := 50.0
	if not ol.is_empty():
		avg_block = 0.0
		for p in ol: avg_block += rt(p, "run_block")
		avg_block /= ol.size()
	var avg_def := 50.0
	if not front.is_empty():
		avg_def = 0.0
		for p in front: avg_def += rt(p, "run_defense")
		avg_def /= front.size()
	var box_delta := (7.0 - float(def.box_count)) * 0.35
	var vision := z(runner, "vision")
	var patience := z(runner, "gap_patience")
	var p_clean := MathX.matchup_probability(0.55, avg_block, avg_def, fit_delta + box_delta, 0.0, 2.5)
	var p_loss := 0.04 + (1.0 - p_clean) * 0.20 + (0.05 if def.box_count >= 8 else 0.0)
	var p_break := 0.01 + p_clean * 0.06 + (0.05 if def.box_count <= 6 else 0.0) + 0.02 * vision
	var p_cut := 0.04 + p_clean * 0.14 + 0.03 * patience
	var p_stuff := 0.08 + (1.0 - p_clean) * 0.45
	var p_design := maxf(0.1, p_clean * 0.75)
	var probs := MathX.normalize_joint([p_loss, p_stuff, p_design, p_cut, p_break])
	var lanes := ["BACKFIELD_LOSS", "STUFFED_LINE", "DESIGNED_LANE", "CUTBACK_LANE", "BREAKAWAY_LANE"]
	var logits: Array = probs.map(func(p): return log(maxf(p, 1e-9)))
	var lane: String = MathX.softmax_sample(lanes, logits, rng)
	var texts := {
		"BACKFIELD_LOSS": "The front penetrated into the backfield (box %d)." % def.box_count,
		"STUFFED_LINE": "No clean gap; %s met at the line." % runner.display_name,
		"DESIGNED_LANE": "The line opened the designed gap for %s." % runner.display_name,
		"CUTBACK_LANE": "%s cut back against the flow." % runner.display_name,
		"BREAKAWAY_LANE": "MASSIVE HOLE! %s is into the secondary!" % runner.display_name,
	}
	return {"lane": lane, "text": texts[lane], "probs": probs}


# ------------------------------------------------------------------ yardage
static func sack_loss(qb: Dictionary, rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	var base := 3.0 + 8.0 * pow(u, 0.8)
	return -MathX.rint(maxf(1.0, minf(14.0, base - 0.5 * z(qb, "mobility"))))


static func run_yards(lane: String, runner: Dictionary, yl_to_goal: float, variance: float, yards_mult: float,
		rng: RandomNumberGenerator) -> int:
	var speed_bonus := z(runner, "speed") * 1.5
	var tackle := z(runner, "tackle_breaking") * 1.2
	var u := rng.randf()
	var uc := clampf(u, 0.02, 0.98)
	var yards := 3
	match lane:
		"BACKFIELD_LOSS": yards = -MathX.rint(1.0 + 3.0 * pow(u, 0.7))
		"STUFFED_LINE": yards = MathX.rint(u * 2.0)
		"DESIGNED_LANE": yards = MathX.rint(MathX.gamma_ppf(uc, 2.5, 1.8 * variance) + 1.0 + 0.3 * speed_bonus + 0.3 * tackle)
		"CUTBACK_LANE": yards = MathX.rint(MathX.gamma_ppf(uc, 3.0, 2.5 * variance) + 2.0 + 0.5 * speed_bonus + 0.5 * tackle)
		"BREAKAWAY_LANE": yards = MathX.rint(MathX.gamma_ppf(uc, 2.0, 8.0 * variance) + 10.0 + speed_bonus + tackle)
	if yards > 0:
		yards = MathX.rint(yards * yards_mult)
	return mini(int(yl_to_goal), yards)


static func scramble_yards(qb: Dictionary, yl_to_goal: float, rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	var y := 0
	if u < 0.75:
		y = MathX.rint(2.0 + 5.0 * u + 0.8 * z(qb, "mobility"))
	else:
		y = MathX.rint(8.0 + 12.0 * u + z(qb, "speed") + z(qb, "mobility"))
	return mini(int(yl_to_goal), maxi(-2, y))


static func yac_yards(receiver: Dictionary, t: Dictionary, yl_to_goal: float, yac_mult: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var u := rng.randf()
	var speed := z(receiver, "speed")
	var yac := z(receiver, "yac")
	var free := maxf(0.0, t.separation * 0.9)
	var p_miss := 0.12 + 0.08 * yac
	var text := ""
	var out := 0
	if t.contested:
		out = MathX.rint(u * 1.5)
	elif u < p_miss:
		var bonus := MathX.gamma_ppf(clampf(u / p_miss, 0.02, 0.98), 2.2, 3.0)
		out = MathX.rint(free + bonus + 0.5 * speed + 0.5 * yac)
		text = "%s broke a tackle for %d YAC!" % [receiver.display_name, out]
	else:
		out = MathX.rint(free + 1.5 * u + 0.3 * yac)
	out = MathX.rint(maxf(0.0, out) * yac_mult)
	var remaining := maxi(0, int(yl_to_goal - t.depth_yards))
	return {"yac": mini(remaining, maxi(0, out)), "text": text}


# ------------------------------------------------------------------ pass outcome
static func pass_outcome(target, pr: Dictionary, qb: Dictionary, mod: Dictionary,
		tilt: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ex: Array = []
	if pr.arrives:
		ex.append(pr.text)
		var evasion := z(qb, "pocket_awareness") * 0.4 + z(qb, "mobility") * 0.4
		var p_sack := MathX.sigmoid(-0.9 + 1.2 * pr.severity - 0.7 * evasion)
		var p_scr := 0.05
		if rt(qb, "mobility") >= 65.0:
			p_scr = MathX.sigmoid(-2.4 + 0.8 * z(qb, "scramble_decision"))
		var p_throw := maxf(0.05, 1.0 - p_sack - p_scr)
		var n := MathX.normalize_joint([p_sack, p_scr, p_throw])
		var d := rng.randf()
		if d < n[0]:
			ex.append("Sacked by %s!" % pr.rusher)
			return {"outcome": "SACK", "target": null, "ex": ex}
		elif d < n[0] + n[1]:
			ex.append("%s escaped the pocket and scrambled!" % qb.display_name)
			return {"outcome": "SCRAMBLE", "target": null, "ex": ex}
		ex.append("%s threw a hurried pass under pressure." % qb.display_name)
	if target == null:
		ex.append("%s found nobody open and threw it away." % qb.display_name)
		return {"outcome": "THROWAWAY", "target": null, "ex": ex}
	var acc := 0.0
	if target.depth_yards <= 8.0: acc = z(qb, "short_accuracy")
	elif target.depth_yards <= 18.0: acc = z(qb, "intermediate_accuracy")
	else: acc = z(qb, "deep_accuracy")
	var press_pen: float = -0.55 * pr.severity if pr.arrives else 0.0
	var comp_logit: float = 0.65 + 0.85 * (target.separation - 1.5) + 0.45 * acc - 0.045 * target.depth_yards \
		+ press_pen + float(tilt.get("comp_logit", 0.0))
	var risk: float = 1.0 * (1.5 - target.separation) if target.contested else -0.4
	var depth_risk := maxf(0.0, (target.depth_yards - 15.0) * 0.045)
	if target.route == "HAIL_MARY":
		depth_risk += 1.6
	var int_logit: float = -3.7 + risk + depth_risk + (0.5 * pr.severity if pr.arrives else 0.0) \
		+ mod.get("turnover_log_odds_delta", 0.0) + 0.35 * (1.0 - z(qb, "decision_making")) + float(tilt.get("int_logit", 0.0))
	var p_comp := clampf(MathX.sigmoid(comp_logit), 0.05, 0.95)
	var p_int := clampf(MathX.sigmoid(int_logit), 0.005, 0.35)
	var p_inc := maxf(0.05, 1.0 - p_comp - p_int)
	var n2 := MathX.normalize_joint([p_comp, p_int, p_inc])
	ex.append(target.text)
	var d2 := rng.randf()
	if d2 < n2[1]:
		ex.append("INTERCEPTED! Picked off by %s." % target.defender_name)
		return {"outcome": "INTERCEPTION", "target": target, "ex": ex}
	elif d2 < n2[1] + n2[0]:
		ex.append("COMPLETE to %s for %.1f air yards." % [target.display_name, target.depth_yards])
		return {"outcome": "COMPLETE", "target": target, "ex": ex}
	ex.append("Incomplete; broken up by %s." % target.defender_name)
	return {"outcome": "INCOMPLETE", "target": target, "ex": ex}


# ------------------------------------------------------------------ special teams
static func field_goal(yl_to_goal: float, kicker, rng: RandomNumberGenerator) -> Dictionary:
	var dist := yl_to_goal + 17.0
	var acc := z(kicker, "kick_accuracy") if kicker != null else 0.0
	var power := z(kicker, "kick_power") if kicker != null else 0.0
	var p := MathX.sigmoid(3.8 - 0.095 * (dist - 25.0) + 0.4 * acc + 0.3 * power)
	if rng.randf() < p:
		return {"outcome": "FIELD_GOAL_GOOD", "yards": 0, "text": "Good from %d yards! (%.0f%%)" % [dist, p * 100.0]}
	return {"outcome": "FIELD_GOAL_MISSED", "yards": 0, "text": "MISSED from %d yards! (%.0f%%)" % [dist, p * 100.0]}


static func punt(yl_to_goal: float, punter, rng: RandomNumberGenerator) -> Dictionary:
	var power := z(punter, "punt_power") if punter != null else 0.0
	var gross := MathX.rint(44.0 + 12.0 * rng.randf() + 2.0 * power)
	var u2 := rng.randf()
	var ret := MathX.rint(u2 * 8.0) if u2 > 0.4 else 0
	var net := maxi(15, gross - ret)
	if yl_to_goal - gross <= 0:
		return {"outcome": "TOUCHBACK", "yards": int(yl_to_goal - 20), "text": "Touchback."}
	return {"outcome": "PUNT", "yards": net, "text": "Punt: %d net yards." % net}


# ------------------------------------------------------------------ rules
static func clock_runoff(outcome: String, period: int, clock: int, rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	if outcome in ["INCOMPLETE", "THROWAWAY", "FIELD_GOAL_GOOD", "FIELD_GOAL_MISSED", "PUNT", "TOUCHBACK"]:
		return MathX.rint(5.0 + 3.0 * u)
	if clock <= 120 and period in [2, 4]:
		return MathX.rint(12.0 + 8.0 * u)
	return MathX.rint(32.0 + 8.0 * u)


## Applies NFL rules. Returns {state, result}; result carries points_scored / possession_change for the game layer.
static func apply_rules(st: Dictionary, outcome: String, yards: int, extra: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ex: Array = extra.get("ex", []).duplicate()
	var turnover := false
	var touchdown := false
	var first_down := false
	var safety := false
	var change := false
	var points := 0
	match outcome:
		"FIELD_GOAL_GOOD":
			points = 3
			change = true
		"FIELD_GOAL_MISSED", "TOUCHBACK", "INTERCEPTION", "FUMBLE":
			turnover = true
			change = true
		"PUNT":
			change = true
		_:
			var new_yl: float = st.yardline_to_opponent_goal - yards
			if new_yl <= 0.0:
				touchdown = true
				points = 7
				change = true
				ex.append("TOUCHDOWN!")
			elif new_yl >= 100.0:
				safety = true
				turnover = true
				change = true
				ex.append("SAFETY!")
			elif yards >= st.distance:
				first_down = true
				ex.append("FIRST DOWN!")
			elif st.down == 4:
				turnover = true
				change = true
				ex.append("Turnover on downs.")
	var elapsed := clock_runoff(outcome, st.period, st.clock_seconds, rng)
	var s := st.duplicate()
	s.clock_seconds = maxi(0, st.clock_seconds - elapsed)
	if not change:
		s.yardline_to_opponent_goal = maxf(0.5, st.yardline_to_opponent_goal - yards)
		if first_down:
			s.down = 1
			s.distance = minf(10.0, s.yardline_to_opponent_goal)
		else:
			s.down = st.down + 1
			s.distance = maxf(0.5, st.distance - yards)
	var result := {
		"outcome": outcome, "yards": yards, "turnover": turnover, "touchdown": touchdown, "first_down": first_down,
		"safety": safety, "possession_change": change, "points_scored": points, "ex": ex,
		"target_name": extra.get("target_name", ""), "air_yards": extra.get("air_yards", 0.0),
		"clock_used": elapsed,
	}
	return {"state": s, "result": result}


# ------------------------------------------------------------------ the coordinator
static func fumble_lost(p: float, yards: int, yl_to_goal: float, rng: RandomNumberGenerator) -> bool:
	if yards >= yl_to_goal:
		return false
	return rng.randf() < p


static func resolve_play(st: Dictionary, call: Dictionary, def: Dictionary, off: Dictionary, deff: Dictionary,
		matrix: Dictionary, tilt: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var qb: Dictionary = off.qb
	var rb: Dictionary = off.rb
	var yl: float = st.yardline_to_opponent_goal
	var mod := scheme_mod(matrix, call.concept, def.coverage)
	var pressure_delta: float = mod.pressure_log_odds_delta + def.get("pressure_delta", 0.0) + float(tilt.get("pressure", 0.0))
	var fit_delta: float = mod.run_fit_log_odds_delta + def.get("run_fit_delta", 0.0) + float(tilt.get("run_fit", 0.0))
	var fumble_mult := float(tilt.get("fumble_mult", 1.0))

	match call.concept:
		"QB_KNEEL":
			return apply_rules(st, "RUN", -1, {"ex": ["%s took a knee." % qb.display_name]}, rng)
		"QB_SPIKE":
			return apply_rules(st, "INCOMPLETE", 0, {"ex": ["%s spiked the ball." % qb.display_name]}, rng)
		"FIELD_GOAL":
			var fg := field_goal(yl, off.k, rng)
			return apply_rules(st, fg.outcome, fg.yards, {"ex": [fg.text]}, rng)
		"PUNT":
			var pt := punt(yl, off.p, rng)
			return apply_rules(st, pt.outcome, pt.yards, {"ex": [pt.text]}, rng)

	if is_run(call):
		var fit := run_fit(call, def, off.ol, deff.dl, rb, fit_delta, rng)
		var yards := run_yards(fit.lane, rb, yl, mod.variance_multiplier, float(tilt.get("run_yards_mult", 1.0)), rng)
		var outcome := "RUN"
		var ex: Array = [fit.text]
		if fumble_lost((0.012 + (0.006 if def.box_count >= 8 else 0.0)) * fumble_mult, yards, yl, rng):
			outcome = "FUMBLE"
			ex.append("FUMBLE! %s loses the ball!" % rb.display_name)
		return apply_rules(st, outcome, yards, {"ex": ex}, rng)

	# pass play
	var rushers: Array = deff.dl.duplicate()
	rushers.sort_custom(func(a, b): return rt(a, "pass_rush") > rt(b, "pass_rush"))
	rushers = rushers.slice(0, 4 + def.get("blitzers", []).size())
	var pr := pocket(off.ol, rushers, call.protection, qb, pressure_delta, rng)
	var first_reads: Array = call.read_progression.slice(0, 2)
	var release := 3.0
	if not first_reads.is_empty():
		release = 0.4
		var sum_t := 0.0
		for r in first_reads:
			sum_t += route_time(r.route, float(r.depth_yards) if r.get("depth_yards") != null else 10.0)
		release += sum_t / first_reads.size()
	if pr.arrives and pr.time >= release:
		pr = {"arrives": false, "time": pr.time, "severity": 0.0, "rusher": "", "text": "Ball out before pressure."}
	var avail: float = pr.time if pr.arrives else 4.5
	var targets: Array = []
	for read in call.read_progression:
		var receiver := map_eligible(read.eligible_id, off.eligibles)
		var defender := assign_defender(receiver, deff.secondary)
		var d: float = float(read.depth_yards) if read.get("depth_yards") != null else 10.0
		var sd: float = mod.separation_delta + float(tilt.get("sep_all", 0.0))
		if d <= 10.0:
			sd += def.get("short_sep_delta", 0.0) + float(tilt.get("sep_short", 0.0))
		elif d > 15.0:
			sd += def.get("deep_sep_delta", 0.0) + float(tilt.get("sep_deep", 0.0))
		targets.append(separation(receiver, defender, read, def.coverage, avail - 0.05 * d, sd, rng))
	var selected = select_target(targets, qb, call, rng)
	var po := pass_outcome(selected, pr, qb, mod, tilt, rng)
	var outcome2: String = po.outcome
	var yards2 := 0
	var air := 0.0
	match outcome2:
		"SACK": yards2 = sack_loss(qb, rng)
		"SCRAMBLE": yards2 = scramble_yards(qb, yl, rng)
		"COMPLETE":
			air = selected.depth_yards
			var rec := map_eligible(selected.player_id, off.eligibles)
			var ya := yac_yards(rec, selected, yl, float(tilt.get("yac_mult", 1.0)), rng)
			if ya.text != "":
				po.ex.append(ya.text)
			yards2 = mini(int(yl), MathX.rint(air + ya.yac))
	var fp = {"COMPLETE": 0.007, "SACK": 0.05}.get(outcome2)
	if fp != null and fumble_lost(fp * fumble_mult, yards2, yl, rng):
		outcome2 = "FUMBLE"
		po.ex.append("FUMBLE! The ball is stripped!")
	return apply_rules(st, outcome2, yards2, {"ex": po.ex, "target_name": selected.display_name if selected != null else "", "air_yards": air}, rng)
